#!/usr/bin/env python3
"""
推文数据分析脚本
用于批量处理推文数据，筛选高表现推文，计算互动率。

支持的输入格式：
1. api    —— Twitter API v2 JSON 导出（public_metrics.snake_case）**或** Followin MCP
             user_tweets 导出（顶层 camelCase viewCount/likeCount + results 外层）——两种都认
2. archive —— Twitter 官方数据归档 (tweets.js)，无 views → 退化为绝对互动数
3. csv    —— 手动整理

用法：
    python tweet_analyzer.py --input tweets.json --format api
    python tweet_analyzer.py --input tweets.js --format archive
    python tweet_analyzer.py --input tweets.csv --format csv
"""

import json
import csv
import sys
import argparse
from datetime import datetime
from pathlib import Path


def _pick(item, metrics, *names):
    """两种命名都认，防静默降级。

    Twitter API v2 导出：public_metrics.{like_count,impression_count,...}（snake_case，嵌套）。
    Followin MCP / twitterapi.io：{likeCount,viewCount,...}（camelCase，顶层）。
    只认一种的话，喂另一种数据 → 全读成 0 → viewCount 明明在却静默降级成绝对互动数排序
    （SKILL 推荐用本脚本"首次建库"，而建库数据大概率来自 MCP，正好踩这个坑）。
    """
    for n in names:
        v = metrics.get(n)
        if v is None:
            v = item.get(n)
        if v is not None:
            try:
                return int(v)
            except (ValueError, TypeError):
                pass
    return 0


def load_api_json(filepath):
    """加载推文 JSON —— 兼容 Twitter API v2 与 Followin MCP 两种字段命名"""
    with open(filepath, 'r', encoding='utf-8') as f:
        data = json.load(f)

    tweets = []
    # Followin MCP 外层是 results[0].data.tweets[]；Twitter API v2 是 data[]
    if isinstance(data, dict):
        r = data.get('results')
        if isinstance(r, list) and r and isinstance(r[0], dict):
            items = r[0].get('data', {}).get('tweets', [])
        else:
            items = data.get('data', data)
    else:
        items = data

    for item in items:
        metrics = item.get('public_metrics', {})
        tweets.append({
            'id': item.get('id', ''),
            'text': item.get('text', ''),
            'created_at': item.get('created_at') or item.get('createdAt', ''),
            'likes': _pick(item, metrics, 'like_count', 'likeCount'),
            'retweets': _pick(item, metrics, 'retweet_count', 'retweetCount'),
            'replies': _pick(item, metrics, 'reply_count', 'replyCount'),
            'quotes': _pick(item, metrics, 'quote_count', 'quoteCount'),
            # impressions 默认 0（默认 1 会算出 16200% 并标成互动率）；MCP 叫 viewCount
            'impressions': _pick(item, metrics, 'impression_count', 'viewCount'),
            'retweeted_tweet': item.get('retweeted_tweet'),  # 非空 = 转推（结构判据，比 text 前缀稳）
        })
    return tweets


def load_archive_js(filepath):
    """加载 Twitter 官方数据归档格式 (tweets.js)"""
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    # tweets.js 格式: window.YTD.tweets.part0 = [...]
    json_start = content.index('[')
    data = json.loads(content[json_start:])

    tweets = []
    for item in data:
        tweet = item.get('tweet', item)
        tweets.append({
            'id': tweet.get('id', ''),
            'text': tweet.get('full_text', tweet.get('text', '')),
            'created_at': tweet.get('created_at', ''),
            'likes': int(tweet.get('favorite_count', 0)),
            'retweets': int(tweet.get('retweet_count', 0)),
            'replies': 0,  # 归档格式不含评论数
            'quotes': 0,
            'impressions': 0,  # 归档格式不含印象数
        })
    return tweets


def _int(row, *keys):
    """从 CSV 行里取整数。

    `row.get(k, 0)` 在「列存在但单元格为空」时返回 ''，默认值永不生效，
    int('') 直接抛 ValueError —— 而 CSV 的定位就是"手动整理"，空格是常态。
    """
    for k in keys:
        v = (row.get(k) or '').strip().replace(',', '')
        if v:
            try:
                return int(float(v))
            except ValueError:
                pass
    return 0


def load_csv(filepath):
    """加载 CSV 格式"""
    tweets = []
    with open(filepath, 'r', encoding='utf-8') as f:
        reader = csv.DictReader(f)
        for row in reader:
            tweets.append({
                'id': row.get('id') or '',
                'text': row.get('text') or row.get('content') or '',
                'created_at': row.get('created_at') or row.get('date') or '',
                'likes': _int(row, 'likes', 'like_count'),
                'retweets': _int(row, 'retweets', 'retweet_count'),
                'replies': _int(row, 'replies', 'reply_count'),
                'quotes': _int(row, 'quotes', 'quote_count'),
                'impressions': _int(row, 'impressions', 'impression_count'),
            })
    return tweets


def drop_retweets(tweets):
    """剔除纯转推。

    转推的 text 以 'RT @' 开头（官方归档的 full_text 同样如此）。
    这一步必须在打分之前做，且必须对所有输入格式统一生效——
    转推的互动数是别人的，混进来会霸占 S 级榜首，进而被写进素材库当成
    "你自己的可复用爆款句式"，再喂给写作环节。
    """
    def is_rt(t):
        # 首选结构判据：retweeted_tweet 非空（API 格式带；archive/csv 无此字段则为 None）
        if t.get('retweeted_tweet') is not None:
            return True
        # 回退 text 前缀：'RT @user:' 标准形态 / 'RT@user:' 无空格变体
        s = t.get('text', '').lstrip()
        return s.startswith('RT @') or s.startswith('RT@')

    kept = [t for t in tweets if not is_rt(t)]
    return kept, len(tweets) - len(kept)


def calculate_engagement(tweet):
    """计算互动率（%）或——没有印象数时——绝对互动数。

    返回 (值, 是否为百分比)。调用方必须据此决定单位，
    否则会把绝对互动数打印成 "12.00%"。
    """
    total_engagement = tweet['likes'] + tweet['retweets'] + tweet['replies'] + tweet['quotes']

    if tweet['impressions'] > 0:
        return total_engagement / tweet['impressions'] * 100, True
    else:
        # 没有印象数（官方归档格式就是这样）时，退化为绝对互动数排序
        return total_engagement, False


def analyze_tweets(tweets):
    """分析推文，按互动率排序，分级"""
    # 计算互动率
    for tweet in tweets:
        tweet['engagement_total'] = tweet['likes'] + tweet['retweets'] + tweet['replies'] + tweet['quotes']
        tweet['engagement_rate'], tweet['rate_is_pct'] = calculate_engagement(tweet)

    # 🔴 混合输入：分组各自排序，不整批降级、也不跨单位混排。
    #
    # 两种错法都试过：
    #  ① 跨单位混排 → 1620（绝对数）和 6.60（百分比）比大小，S 级由"哪条缺 impressions"决定
    #  ② 整批降级为绝对数 → 在**主用例上必然触发**（API v2 的 impression_count 只对
    #     2022-12 之后的推有值，而本脚本自陈用途是"首次建库"= 全量历史），
    #     于是 ER 分级静默失效，退化成"粉丝多的时期赢"——正是 SKILL.md §6 明令禁止的
    #     「按 ER 分级不按绝对数」。
    #
    # 正解是承认这是两个不可比的群体：各自按自己的口径分级，报告里分开列。
    has_imp = [x for x in tweets if x['rate_is_pct']]
    no_imp = [x for x in tweets if not x['rate_is_pct']]
    if has_imp and no_imp:
        for cohort in (has_imp, no_imp):
            _grade_cohort(cohort)
        # 有 impressions 的排前面（它们的口径才是 ER），组内已各自排好
        return has_imp + no_imp

    return _grade_cohort(tweets)


def _grade_cohort(tweets):
    """在同一口径的群体内排序并打 S/A/B+ 级。"""

    tweets.sort(key=lambda x: x['engagement_rate'], reverse=True)

    total = len(tweets)
    if total == 0:
        return tweets

    avg_rate = sum(t['engagement_rate'] for t in tweets) / total
    top_10_threshold = tweets[max(0, int(total * 0.1) - 1)]['engagement_rate'] if total >= 10 else 0
    top_25_threshold = tweets[max(0, int(total * 0.25) - 1)]['engagement_rate'] if total >= 4 else 0

    for i, tweet in enumerate(tweets):
        percentile = (1 - i / total) * 100
        if percentile >= 90:
            tweet['grade'] = 'S'
        elif percentile >= 75:
            tweet['grade'] = 'A'
        elif tweet['engagement_rate'] >= avg_rate * 1.5:
            tweet['grade'] = 'B+'
        else:
            tweet['grade'] = '-'

    return tweets


def output_report(tweets, output_path=None, rt_dropped=0):
    """输出分析报告。返回 True = 有产物，False = 无数据。"""
    total = len(tweets)
    if total == 0:
        # 仍然要落文件 + 非零退出码：静默 exit 0 且不产文件，
        # 会让自动化调用看起来成功而实际什么都没有
        msg = (f"# 推文分析报告\n\n**没有可分析的推文。**\n\n"
               f"- 输入剔除转推 {rt_dropped} 条后剩 0 条\n"
               f"- 若 rt_dropped 等于输入总数，说明输入全是转推\n")
        print(msg)
        if output_path:
            with open(output_path, 'w', encoding='utf-8') as f:
                f.write(msg)
            with open(output_path.replace('.md', '.json'), 'w', encoding='utf-8') as f:
                json.dump([], f)
            print(f"（空报告已写入 {output_path}）")
        return False

    # 单位不能猜：没有印象数的输入（官方归档 / 2022-12 之前的推）算出来的是绝对互动数
    n_pct = sum(1 for x in tweets if x.get('rate_is_pct'))
    is_pct = n_pct == total
    is_mixed = 0 < n_pct < total
    unit = '%' if is_pct else ''
    metric_name = '互动率' if is_pct else ('两种口径混合' if is_mixed else '绝对互动数')

    avg_rate = sum(t['engagement_rate'] for t in tweets) / total
    s_tier = [t for t in tweets if t['grade'] == 'S']
    a_tier = [t for t in tweets if t['grade'] == 'A']

    report = []
    report.append(f"# 推文分析报告")
    report.append(f"")
    report.append(f"**分析时间**：{datetime.now().strftime('%Y-%m-%d %H:%M')}")
    report.append(f"**总推文数**：{total}（已剔除转推 {rt_dropped} 条）")
    if is_mixed:
        report.append(f"**排序口径**：{metric_name}（分组分级，见下方说明；不给跨组平均值）")
    else:
        report.append(f"**平均{metric_name}**：{avg_rate:.2f}{unit}")
    report.append(f"**S级推文**：{len(s_tier)} 条（Top 10%）")
    report.append(f"**A级推文**：{len(a_tier)} 条（Top 25%）")
    if is_mixed:
        report.append(f"")
        report.append(f"> 🔴 **本批数据有两种口径，已分组独立分级，两组之间不可比。**"
                      f"{n_pct} 条带 impressions（按互动率 % 分级）、{total - n_pct} 条不带"
                      f"（只能按绝对互动数分级）。API v2 的 `impression_count` 只对 2022-12 之后的推有值，"
                      f"全量历史导出必然混两种。**跨组比较 S/A 级没有意义**——"
                      f"下面每条都标了自己的口径。")
    elif not is_pct:
        report.append(f"")
        report.append(f"> 🔴 **本次排序口径是绝对互动数，不是互动率。**"
                      f"输入数据没有印象数（impressions），无法算百分比。"
                      f"绝对值排序会系统性偏向粉丝量增长后的近期推文——"
                      f"跨期对比无效，只能用来在同一批数据内部挑相对好的。")
    report.append(f"")

    report.append(f"## 🏆 S级推文（必须入库）")
    report.append(f"")
    for t in s_tier[:20]:  # 最多展示20条
        text_preview = t['text'][:80].replace('\n', ' ')
        _u = '%' if t.get('rate_is_pct') else ''
        _m = '互动率' if t.get('rate_is_pct') else '绝对互动数'
        report.append(f"### [{t['grade']}] {_m} {t['engagement_rate']:.2f}{_u}")
        report.append(f"**内容**：{text_preview}...")
        report.append(f"**数据**：❤️ {t['likes']} | 🔄 {t['retweets']} | 💬 {t['replies']} | 📊 总互动 {t['engagement_total']}")
        report.append(f"**发布时间**：{t['created_at']}")
        report.append(f"")

    report.append(f"## ⭐ A级推文")
    report.append(f"")
    for t in a_tier[:20]:
        text_preview = t['text'][:80].replace('\n', ' ')
        _u = '%' if t.get('rate_is_pct') else ''
        report.append(f"- **[{t['grade']}] {t['engagement_rate']:.2f}{_u}** — {text_preview}...")

    report_text = '\n'.join(report)

    if output_path:
        with open(output_path, 'w', encoding='utf-8') as f:
            f.write(report_text)
        print(f"报告已保存到：{output_path}")
    else:
        print(report_text)

    # 同时输出 JSON 格式（供素材库使用）
    vault_entries = [t for t in tweets if t['grade'] in ('S', 'A')]
    json_path = output_path.replace('.md', '.json') if output_path else None
    if json_path:
        with open(json_path, 'w', encoding='utf-8') as f:
            json.dump(vault_entries, f, ensure_ascii=False, indent=2)
        print(f"JSON 数据已保存到：{json_path}")

    return True


def main():
    parser = argparse.ArgumentParser(description='推文数据分析工具')
    parser.add_argument('--input', '-i', required=True, help='输入文件路径')
    parser.add_argument('--format', '-f', choices=['api', 'archive', 'csv'], default='api', help='输入文件格式')
    parser.add_argument('--output', '-o', help='输出报告路径（.md）')

    args = parser.parse_args()

    loaders = {
        'api': load_api_json,
        'archive': load_archive_js,
        'csv': load_csv,
    }

    print(f"加载数据：{args.input}（格式：{args.format}）")
    tweets = loaders[args.format](args.input)
    print(f"加载了 {len(tweets)} 条推文")

    # 统一在这里剔转推——放在 loader 里就要写三遍，漏一个格式就前功尽弃
    tweets, rt_dropped = drop_retweets(tweets)
    print(f"剔除转推 {rt_dropped} 条，进入打分 {len(tweets)} 条")

    tweets = analyze_tweets(tweets)
    ok = output_report(tweets, args.output, rt_dropped=rt_dropped)
    if not ok:
        sys.exit(2)   # 无产物必须给非零退出码


if __name__ == '__main__':
    main()
