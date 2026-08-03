#!/usr/bin/env python3
"""
filter_tweets.py — Stock KOL Watch Step 3 固化脚本（framework v1.6）

把 mcp__followin__twitter(action="user_tweets") 的 tool-result dump 过滤成
窗口内 digest（markdown），供日报提炼。取代每批重写的内联 Python。换别的 tweet MCP 时只需改 find_tweets()/parse_dt() 对应字段。

用法:
    python3 scripts/filter_tweets.py \
        --cutoff 2026-06-10T02:12:00Z \
        --out /tmp/digest_0610b2.txt \
        /path/to/tool-results/mcp-followin-twitter-1781087*.txt

行为（实战定型）:
  - 递归扫 JSON 找 tweet 对象（有 text/full_text + createdAt/created_at 即算）
  - 每个文件按 author.userName 多数票识别主账号（并行调用顺序可能错位）
  - 只保留: 主账号本人 + createdAt >= cutoff + 去重（**跨文件共享 seen**，同账号被重试/
    分页成多个 dump 时不重复；无 tweet id 的源退回 作者+时间+正文 指纹，不会静默丢推）
  - 每条输出: UTC + 本地双时间戳 + [RT @x]/[QT @x: 摘要]/[reply] 标记 + 原推 URL + 全文
    （本地时区默认取本机；跨时区跑用 --tz-offset 8 --tz-label SGT 显式指定）
  - stderr 打印每账号 in-window 计数（直接喂 Step 2 覆盖表）

schema 变了 → 改这个脚本，不要回退到内联重写。
"""

import argparse
import json
import sys
import time
from datetime import datetime, timedelta, timezone
from collections import Counter
from pathlib import Path

DT_FORMATS = (
    "%a %b %d %H:%M:%S %z %Y",       # X API classic
    "%Y-%m-%dT%H:%M:%S.%fZ",
    "%Y-%m-%dT%H:%M:%SZ",
    "%Y-%m-%dT%H:%M:%S%z",           # ISO 带偏移，如 2026-07-27T08:00:00+08:00
    "%Y-%m-%d %H:%M:%S",
)


def parse_dt(s):
    if not s:
        return None
    for fmt in DT_FORMATS:
        try:
            d = datetime.strptime(s, fmt)
            return d if d.tzinfo else d.replace(tzinfo=timezone.utc)
        except ValueError:
            continue
    return None


def parse_cutoff(s):
    d = parse_dt(s)
    if d is None:
        sys.exit(f"bad --cutoff: {s!r} (want e.g. 2026-06-10T02:12:00Z)")
    return d


def find_tweets(obj, out, in_tweet=False):
    """递归收集疑似 tweet 的 dict，并标记它是不是嵌在另一条推文里（RT/QT 的被引原文）。
    ⚠️ 必须区分：自引（QT 自己旧推）时嵌套推文的 author 也等于主账号，
    不区分就会把旧推当成本窗口新推，也会让窗口回溯检查失效。"""
    if isinstance(obj, dict):
        if ("text" in obj or "full_text" in obj) and (
            "createdAt" in obj or "created_at" in obj
        ):
            obj["_nested"] = in_tweet
            out.append(obj)
            in_tweet = True
        for v in obj.values():
            find_tweets(v, out, in_tweet)
    elif isinstance(obj, list):
        for v in obj:
            find_tweets(v, out, in_tweet)


def author_of(t):
    return (t.get("author") or {}).get("userName") or t.get("screen_name")


def local_ts(d, offset_hours, label):
    """第二时戳。offset_hours=None → 用本机本地时区。"""
    if offset_hours is None:
        loc = d.astimezone()
        return f"{label} {loc.strftime('%m-%d %H:%M')}"
    return f"{label} {(d + timedelta(hours=offset_hours)).strftime('%m-%d %H:%M')}"


def dedupe_key(t, author):
    """去重键。⚠️ 没有 id 时不能全用 None——否则同账号的无 id 推文会被当成重复静默丢光。"""
    tid = t.get("id") or t.get("id_str") or t.get("rest_id") or t.get("tweet_id")
    if tid:
        return f"id:{tid}"
    text = (t.get("text") or t.get("full_text") or "")[:120]
    created = t.get("createdAt") or t.get("created_at") or ""
    return f"fallback:{author}|{created}|{text}"


def nested(t, *keys):
    """取嵌套推文。⚠️ 同一 API 家族里 snake_case 和 camelCase 都出现过——两种都查，
    只查一种会静默丢掉全部 RT/QT 标记（实测 followin 用的是 retweeted_tweet/quoted_tweet）。"""
    for k in keys:
        v = t.get(k)
        if isinstance(v, dict) and v:
            return v
    return None


def mark_of(t):
    mark = ""
    rt = nested(t, "retweeted_tweet", "retweetedTweet", "retweeted_status")
    qt = nested(t, "quoted_tweet", "quotedTweet")
    if rt or t.get("type") == "retweet":
        mark = f"[RT @{author_of(rt or {}) or '?'}]"
    elif qt or t.get("is_quote_status"):
        qa = author_of(qt or {}) or "?"
        qtext = ((qt or {}).get("text") or "")[:160].replace("\n", " ")
        self_mark = "自引 " if qa == author_of(t) else ""
        mark = f"[{self_mark}QT @{qa}: {qtext}]"
    if t.get("isReply") or t.get("in_reply_to_status_id") or t.get("inReplyToId"):
        mark = "[reply]" + mark
    return mark


def process_file(path, cutoff, seen):
    """返回 (main_author, rows)；rows = [(dt, text, mark, url), ...] 时间正序。
    seen 由调用方跨文件共享——同一账号被重试/分页成多个 dump 时不重复计。"""
    try:
        data = json.loads(Path(path).read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as e:
        print(f"  !! {path}: {e}", file=sys.stderr)
        return None, []
    tweets = []
    find_tweets(data, tweets)
    counts = Counter(a for a in (author_of(t) for t in tweets) if a)
    if not counts:
        return None, []
    main = counts.most_common(1)[0][0]
    rows, own_dts = [], []
    for t in tweets:
        if author_of(t) != main:
            continue
        if t.get("_nested"):
            continue          # 被引原文只作 [QT] 标记里的上下文，不当独立新推重复出一条
        cd = parse_dt(t.get("createdAt") or t.get("created_at"))
        if cd:
            own_dts.append(cd)   # 含窗口外——用来判断这份 dump 有没有回溯到 cutoff
        key = dedupe_key(t, main)
        if key in seen:
            continue
        seen.add(key)
        if not cd or cd < cutoff:
            continue
        text = (t.get("text") or t.get("full_text") or "").strip()
        tid = t.get("id") or t.get("id_str") or t.get("rest_id") or t.get("tweet_id")
        url = t.get("url") or t.get("twitterUrl") or (
            f"x.com/{main}/status/{tid}" if tid else "(无 tweet id)")
        rows.append((cd, text, mark_of(t), url))
    rows.sort(key=lambda r: r[0])
    # 本文件里该账号最早一条（含窗口外）——调用方按账号跨文件取最小值判断回溯是否够
    return main, rows, (min(own_dts) if own_dts else None)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--cutoff", required=True,
                    help="窗口下界 UTC, e.g. 2026-06-10T02:12:00Z（取自 $VAULT/_last-pull.md）")
    ap.add_argument("--out", required=True, help="digest 输出路径")
    ap.add_argument("--tz-offset", type=float, default=None,
                    help="第二时戳的 UTC 偏移小时数（如 8 / -5）。不给 = 用本机本地时区")
    ap.add_argument("--tz-label", default=None,
                    help="第二时戳标签（如 SGT / EST）。不给 = 本机时区缩写")
    ap.add_argument("files", nargs="+", help="tool-result dump 文件（可 glob 展开）")
    args = ap.parse_args()

    label = args.tz_label or (
        f"UTC{args.tz_offset:+g}" if args.tz_offset is not None else (time.tzname[0] or "LOCAL")
    )

    cutoff = parse_cutoff(args.cutoff)
    chunks = []
    summary = []
    seen = set()          # 跨文件共享：同账号被重试/分页成多个 dump 时不重复
    merged = {}           # 主账号 → 累计条数（同账号多文件合并成一行覆盖表）
    earliest = {}         # 主账号 → 跨全部 dump 的最早一条（判断回溯够不够，翻页后自动消警）
    for f in args.files:
        main_author, rows, first_dt = process_file(f, cutoff, seen)
        if main_author is None:
            summary.append((f"?({Path(f).name})", 0))
            continue
        if first_dt and (main_author not in earliest or first_dt < earliest[main_author]):
            earliest[main_author] = first_dt
        merged[main_author] = merged.get(main_author, 0) + len(rows)
        chunks.append(f"\n\n########## @{main_author} ({len(rows)} in-window) ##########")
        for cd, text, mark, url in rows:
            chunks.append(
                # UTC 必须带日期：本地自然日窗口必然跨两个 UTC 日（如 CST 08-03 00:00 = 08-02 16:00Z），
                # 只写 HH:MMZ 会让"22:09Z 是昨天还是今天"无法判断，违反"数据带源可回头验证"。
                f"\n--- {cd.strftime('%m-%d %H:%MZ')} / {local_ts(cd, args.tz_offset, label)} {mark} {url}\n{text}"
            )
    summary.extend(merged.items())

    Path(args.out).write_text("\n".join(chunks) + "\n", encoding="utf-8")
    print(args.out)
    print("--- in-window counts（喂覆盖表）---", file=sys.stderr)
    for name, n in sorted(summary, key=lambda x: -x[1]):
        print(f"  {name}: {n}", file=sys.stderr)
    warns = sorted((n, d) for n, d in earliest.items() if d > cutoff)
    if warns:
        print("\n🚨 窗口未回溯到 cutoff —— 这些账号有推文被静默漏掉，必须翻页补拉"
              f"（cutoff={cutoff.strftime('%Y-%m-%dT%H:%M:%SZ')}）：", file=sys.stderr)
        for name, first_dt in warns:
            print(f"  ⚠️ @{name}: 已拉到的最早一条 {first_dt.strftime('%Y-%m-%dT%H:%M:%SZ')} 仍晚于 cutoff"
                  f" → 用 next_cursor 再拉一页，连同已有 dump 一起重跑本脚本", file=sys.stderr)


if __name__ == "__main__":
    main()
