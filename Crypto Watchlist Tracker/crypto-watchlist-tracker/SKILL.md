---
name: crypto-watchlist-tracker
description: "使用 Followin MCP 每天早晚或按需跟踪用户自选币，整合项目与新闻事件、实时价格、技术面、推特 KOL 观点和交易员仓位。适用于‘每天早晚跟踪我的自选币’‘创建币圈自选监控’‘更新我的币圈雷达’或‘crypto watchlist report’；不用于执行交易或没有自选币列表的泛市场早报。 Track a user-supplied crypto watchlist twice daily or on demand with Followin MCP."
---

# Crypto Watchlist Tracker｜币圈自选每日跟踪

## 中文说明

这个 Skill 用 Followin MCP 跟踪用户指定的币种，并在每天早上 09:00、晚上 21:00 生成简洁早报和晚报。没有指定时区时默认使用 `Asia/Shanghai`，币圈周末也照常更新。

每期重点回答：

- 这个币在上一期之后发生了哪些项目公告、新闻、安全、上币、解锁、监管或资金事件；
- 当前价格、24 小时变化和技术面是否出现明显过热、转弱或拐点；
- 最近推特上有哪些值得看的 KOL 分析，观点依据和成立条件是什么；
- KOL 说法与交易员真实的开仓、加仓、减仓、平仓行为是否一致；
- 接下来 12 小时最值得验证的两三个条件是什么。

默认输出是适合手机阅读的早报/晚报，不机械罗列 RSI、EMA、MACD 等全部指标。只有出现极端或方向变化时才点出一两个关键指标。KOL 栏目通常挑选 2–3 条有数据、逻辑或明确条件的推文，过滤交易所推广、复制文案、无依据喊单和无关同名词。

正文直接讲事实和观点，只在结尾统一写一次 `数据来源：Followin MCP`。原始推文可以保留账号和链接，方便用户查看上下文。这个 Skill 只做信息跟踪，不执行下单，也不承诺收益。

调用示例：

```text
用 $crypto-watchlist-tracker 跟踪 HYPE。
每天早上 9 点和晚上 9 点更新，时区 Asia/Shanghai。
重点关注项目事件、价格变化、优秀推特 KOL 分析和交易员仓位变化。
```

以下为英文技术执行规范，供 Agent 和英文用户使用。

Use Followin MCP to maintain a focused crypto watchlist and produce two evidence-backed updates per day. The default schedule is 09:00 and 21:00 in the user's timezone; if the timezone is unknown, use `Asia/Shanghai` and state the assumption.

This skill monitors information. It never places exchange orders, promises returns, or turns one indicator, post, or trader position into a direct buy/sell instruction.

## Inputs and defaults

Collect only what is needed to start:

- `watchlist`: required symbols or project names. Normalize aliases to canonical symbols and keep the user's display order. Process at most 10 assets per report; if more are supplied, ask the user to choose a top 10 or split them into named lists.
- `timezone`: default `Asia/Shanghai`.
- `schedule`: default daily at `09:00` and `21:00`, including weekends because crypto trades continuously.
- `official_accounts`: optional mapping of symbol to official X handle or other named project account. Do not guess an official handle.
- `destination`: default to the current task/thread.

Do not block setup for missing optional accounts. Start with symbol-level Followin coverage and label the official-account section unavailable where necessary.

## Choose the operating mode

- **Schedule setup or update**: when the user asks for recurring monitoring, read [references/scheduling.md](references/scheduling.md). Use the client's native automation/task capability; do not emit pretend automation syntax. Search for an existing task with the same purpose and update it instead of creating duplicates.
- **Morning run**: at or near 09:00, cover the previous successful run through now; without a known baseline, use the latest 12 hours. Emphasize overnight developments and the next 12-hour watchpoints.
- **Evening run**: at or near 21:00, use the same delta rule. Emphasize the day's developments and overnight risks.
- **On-demand run**: use a user-specified window; otherwise use 12 hours and label it an immediate snapshot.

If the user explicitly asks for a 早报 or 晚报 away from its slot (for example “早报” at 22:00), use that template with the 12-hour on-demand window and label it an immediate snapshot rather than “overnight”.

If automation is unavailable, run one report immediately and say that no recurring task was created.

**Time zones.** Followin times are UTC: `news.published_ts` is epoch milliseconds, `trader_position.event_time` ends in `Z`, hourly candle `date` strings and daily indicator dates are UTC without a suffix. Convert to the user's timezone before comparing with the report window or printing a time; a daily indicator dated today covers the UTC day, i.e. from 08:00 Asia/Shanghai.

## Followin data workflow

Followin is the primary evidence layer. Explicitly use `asset_type="crypto"` for `metrics` and `signal`. `news` entity searches also accept `asset_type="crypto"` (re-tested against production on 2026-10-01; the earlier zero-result behaviour no longer reproduces), so pass it to keep same-name equities out — but it does not remove plain-word matches (2026-10-08 实测：`HYPE Hyperliquid` still returned a Seeking Alpha “AI drug discovery hype” stock article with `entity_filter_applied:true`), so the relevance check in step 2 still applies. Batch no more than five symbols per structured call and compare returned symbols with the requested batch: a watchlist symbol missing from a batch response is usually silent (`status:"ok"`, no warning).

### 1. Market and technical state

For each batch of up to five watchlist assets:

1. Call `metrics` for the live market snapshot with `verbosity="detail"` (for example `keywords=["BTC","ETH","SOL","HYPE","SUI"], query="行情", asset_type="crypto", verbosity="detail"`). 2026-10-08 实测：the crypto snapshot carries `change_percent_24h` only at `detail`; at the default `standard` it has just `price` and `volume_24h`. `as_of` is `null` in both, so record the call time as the snapshot time. `volume_24h` is in base-asset units (BTC 16,331 = coins, not USD); convert with `price` before quoting a dollar volume. Keep `query` to a plain intent word: an English query such as “price quote 24h change” also pulled ten hourly candles per asset plus a `default_fanout_fallback` warning.
2. Call `metrics` for at least 30 days of price/technical context. Inspect trend, momentum, heat, and volatility indicators such as RSI, moving averages, MACD, ATR, and Bollinger Bands when available.
3. Use the latest dated value for each indicator. Never combine values from different dates without saying so. The latest daily value is computed on the still-open UTC candle, so a “cross” or “reversal” seen only in today's value is intraday and should be worded that way.

Put the symbols in `keywords` and only the intent in `query` (for example `keywords=["BTC","SOL"], query="技术指标"`, `asset_type="crypto"`). Pass `limit=2`: 2026-10-08 实测 `limit` now trims each indicator series to the latest N observations (it did not on 2026-10-01), and two points are enough to see a direction change. Each asset still carries a ~40 KB `price_data` string (about 721 hourly rows) that `limit` does not trim — five assets in one call returned ~200 K characters — so request two or three assets per technical call, or process the result with a script instead of reading it into context.

Sanity-check the indicator set before using it (2026-10-08 实测):

- If `close_50_sma`, `close_200_sma`, and `boll` (the 20-day middle band) are identical or nearly so, the long averages were computed on too short a history (HYPE returned 90.0413 for all three). Label the 50/200-day averages `历史不足，不可用` for that asset and do not write any long-term moving-average break. If only `close_200_sma` equals `close_50_sma`, the 200-day alone is unavailable. A Binance-kline `price_data` header (`Binance kline data … Interval: 1d`) also shows the history length (2026-10-08 实测 HYPE: `Total records: 15`, first row 2026-09-24). The hourly header (`Crypto price data …`) does not: its `Total records` counts hourly rows over a fixed 30-day window — 2026-10-09 实测 HYPE switched to that form and showed `Total records: 721` while its 50-day, 200-day, and `boll` values were still identical (89.615). Do not fill the gap from a non-Followin source.
- The same short history also invalidates the shorter indicators: with fewer than 50 daily bars, MACD (26/9) is `历史不足` — 20–49 bars included, labelled the same way as the band and the long averages; with fewer than 20, so is the 20-day Bollinger band (`boll`, `boll_ub`, `boll_lb`). Count the bars from `Total records` only when the header is the Binance daily-kline form **and** its first data row is later than the header's start date (`from <date>`); the daily `price_data` only spans the latest ~30 days, so a coin with a long history shows `Total records: 31` with the first row equal to the start date — that number is the window, not the history (2026-10-09 实测：BTC / ETH / SOL / SUI all returned the daily form with `Total records: 31`, first row 2026-09-09 = start date, while their 50- and 200-day values were distinct; HYPE returned the daily form again with `Total records: 16`, first row 2026-09-24, and 50 = 200 = `boll` = 89.615). Otherwise rely on the equality checks — when `close_200_sma` equals `close_50_sma`, treat the history as under 50 bars (MACD `历史不足`); when `close_50_sma` also equals `boll`, treat it as under 20 bars. For such an asset, write no MACD reversal or Bollinger breakout and skip the MACD/band parts of the trend label. HYPE on 2026-10-08 had 15 bars, so all three were unavailable.
- `mfi` is returned on a 0–1 scale although its description uses 80/20 thresholds; multiply by 100 before comparing.
- The `price_data` header shows the source (“Binance kline data … Interval: 1d” vs hourly “Crypto price data”); it can differ from the snapshot's `provenance`, so do not mix its prices with the snapshot price. 2026-10-08 实测：BTC, ETH, and SOL got the hourly form — closes only, no high/low, last row 00:00 UTC although retrieved at 15:08 UTC — while HYPE and SUI got Binance daily klines (SUI's retrieved an hour before the call). Do not take a day's range from `price_data`.

If a requested snapshot field such as 24-hour change or source timestamp is absent, mark that field unavailable. Do not substitute a daily-close calculation unless the returned candle timestamps define an exact 24-hour interval.

Do not use `metrics time_range` shorter than one day to infer a rolling intraday window. For the current state use the live snapshot; for intraday candles use an explicit interval when the task genuinely needs them.

Translate indicators into three separate labels rather than one opaque score:

- **Trend**: strong / improving / range / weakening, based on price relative to available moving averages plus MACD direction. Default reading: price above both the 50- and 200-day averages with `macdh` positive and rising = strong; `macdh` negative and falling, or price newly below the 50-day = weakening; price back above the 50-day with `macdh` rising = improving; price oscillating around the 50-day or the 20-day middle band = range. When the long averages are unavailable, judge from the 20-day band and MACD only and say so; when those are also `历史不足`, give no trend label and write `历史不足，趋势不可判`.
- **Heat**: cool / neutral / hot / extreme. Treat RSI 70 as hot and 80 as extreme, but note that strong crypto trends can remain overbought. On the downside treat RSI ≤30 as oversold and ≤20 as extreme, and say “oversold” rather than “cool” when it matters.
- **Volatility**: normal / elevated / extreme, using ATR and recent range only when available. Fixed thresholds when a day's high–low range is at hand: above 1.5× ATR = elevated, above 2.5× ATR = extreme; otherwise normal. Take the range as the rolling 24-hour high–low from one `metrics` call for the whole batch with `interval="1hour"`, `limit=24`, `query="K线"`, `asset_type="crypto"` (2026-10-08 实测：five assets = 120 rows, small; without `interval` a daily-candle query still returned hourly rows). Compare it with the latest `atr`. Without a range, mark volatility unavailable — do not default to normal.

These labels are primarily for internal synthesis. In the visible brief, summarize the technical state in one natural sentence. Mention at most one or two indicator values only when they are exceptional or decision-relevant, such as overbought/oversold RSI, a major moving-average break, a MACD reversal, an ATR spike, or a Bollinger breakout. Never print a mechanical indicator inventory.

### 2. News, events, and project developments

Run one `news` search per asset using its canonical symbol and project name, with the report window, `sort_by="relevance"`, and a bounded result count (for example `query="HYPE Hyperliquid", asset_type="crypto", time_range="12h", sort_by="relevance", limit=15`). The mixed-source result may include media, X, Telegram, and indexed project material; `limit` applies separately to `articles` and `social`.

Do not use `sort_by="time"` with a small `limit` for the window scan. 2026-10-08 实测：`sort_by="time", limit=10` over a 12-hour window returned BTC and ETH articles from only the last ~50 minutes (13:21–14:08 UTC), so every earlier event in the window was missed; `sort_by="relevance"` over the same window (tested with `sources=["twitter"]` for BTC and HYPE) spread across the full 12 hours. Use `time` only for a short “what just happened” check. If a quiet asset's results all fall inside the window and below the limit, the window was covered; if a busy asset fills the limit, say coverage may be partial.

Keep only items about the asset itself: the title or body must name the project or `$TICKER` as the subject. Drop plain-word and passing mentions (HYPE matched “AI hype” stock articles; a SOL search returned an unrelated privacy-startup funding item).

Classify each retained item as one of:

- official/project: protocol releases, governance, tokenomics, unlocks, burns, treasury actions, partnerships, listings, delistings;
- market event: regulation, ETF/flow, exchange policy, macro spillover;
- security: exploit, bridge/wallet issue, chain halt, exchange warning;
- narrative/social: a material change in attention or positioning, not ordinary chatter.

When `official_accounts` contains a named X handle, use `twitter` only for that account's raw timeline and filter posts to the report window. Do not use raw Twitter as a substitute for the general news search.

Deduplicate by canonical/source URL first, then collapse multiple articles about the same underlying event. Prefer the original project/exchange/regulator statement; retain a secondary article only when it adds independently useful facts. Keep event time separate from publication time.

Say “Followin覆盖来源内的更新”, never “全网所有新闻”. Absence of returned coverage is not proof that nothing happened.

### 3. KOL calls

Call `kol_call` only for BTC and ETH when they are on the watchlist; skip it for every other asset and leave the structured KOL line out of that asset's report (do not write `样本过小` for an asset that was not queried). Volume is too thin elsewhere to clear the 5-post threshold: two 2026-10-08 runs returned 5 posts in 24 hours for the whole five-asset batch, none for SOL, HYPE, or SUI. Call `signal` with category `kol_call`, query `consensus`, `keywords` holding only BTC and/or ETH, and a fixed `time_range="24h"` — not the report window. The KOL upstream covers only the latest 24 hours (N-117), and a 12-hour window left most assets with no sample. State this separately from the report window, e.g. `喊单：近 24 小时`. Report:

- bullish, bearish, and neutral counts;
- distinct source/post count after deduplication by `source_url`;
- representative reasoning from higher-quality sources when returned;
- whether the sample is balanced, one-sided, or too small. Fixed threshold: fewer than 5 distinct posts for the asset in the 24-hour window = too small; say so instead of naming a direction.

Read the crypto aggregate carefully (2026-10-08 实测):

- The consensus response is one aggregate for the whole batch. Per-asset numbers live only in `top_calls` rows (`symbol`, `bullish_count`, `bearish_count`, `mention_count`; no neutral field, so neutral = mention − bullish − bearish). `top_calls` holds at most five rows and non-watchlist symbols can take slots (`XAUt` appeared for a BTC/ETH/SOL/HYPE/SUI batch, so it can for a BTC/ETH batch too). 2026-10-08 实测 the aggregate now also carries `neutral_count`, but for the whole batch (4 = BTC 3 + XAUt 1), so per-asset neutral is still derived from `top_calls`. A watchlist asset missing from `top_calls` has zero calls only when fewer than five rows came back; otherwise its count is unknown.
- Crypto detail rows (`query="detail"`, `concise` and `standard` alike) carry `content`, `symbol`, `username`, `published_ts` but no `direction` and no `source_url`; the post URL sometimes appears at the end of `content`. Take direction only from `top_calls`, and deduplicate by `username` + `published_ts`.
- Volume is thin outside BTC: a 12-hour window returned 3 posts for the five-asset batch, and 24 hours returned 5 (BTC 3, ETH 1, XAUt 1; none for SOL, HYPE, SUI).

One post can fan out into multiple symbol rows, and short aliases can retrieve longer symbols such as `ETHFI` for `ETH`. Verify every returned row's canonical `symbol` against the requested asset and discard non-matches. If an aggregate contains non-matching symbols and cannot be recomputed safely, call the detail view, filter exact-symbol rows, and aggregate those rows; otherwise mark the asset-specific KOL sample unavailable. Deduplicate retained posts by `source_url`, or by author plus timestamp plus normalized content when no URL is returned. Do not call a one-sided sample “market consensus” without its sample size.

Also search `news` with `sources=["twitter"]` over the report window (not the 24-hour KOL window) for broader KOL analysis that may not be classified as a structured call. Search both the exact ticker and project name — one query such as `"$HYPE Hyperliquid"` with `sort_by="relevance"` covers both — then use `twitter` with `tweets_by_ids` to verify the full text, author, timestamp, engagement, and direct link for the final candidates. The mixed-source search in step 2 already returns these posts in its `social` bucket: 2026-10-08 实测 a separate `sources=["twitter"]` search over the same 12-hour window returned the same posts for HYPE and SUI (15/15) and 13 of 15 for SOL. Read candidates from that bucket and run the Twitter-only search only when it holds no usable exact-asset post.

Take the handle and link from the `tweets_by_ids` result (`author.userName`, `url`), never from the `news` row. 2026-10-08 实测：a `news` row showed `kol_info.name:"calebfranzen"` and a `twitter.com/CalebFranzen/status/…` URL, but the tweet's real author was `milkroaddaily` promoting a video about Caleb Franzen. The same status ID can even carry different handles in two `news` calls (status `2108188656296927509` showed `crypto_mckenna` in the mixed search and `hansonbirringer` in the Twitter-only search; the real author is `HansonBirringer`). `tweets_by_ids` can drop an ID silently (7 requested, 6 returned, no warning): compare the returned `id`s with the request and treat a missing one as unverified. Both `news` content and `tweets_by_ids` text can render a cashtag as a chain reference (`hyperliquid:native`, `solana:<address>`, `ethereum:0x…`); write it back as the ticker when summarizing. `tweets_by_ids` draws on a separate, much smaller Twitter quota (`limit` 10,000 vs the main pool, shared with every other Twitter use; two runs a day across several lists add up quickly), so verify posts for at most three assets per run. Pick assets with a material new event first — only a spot-ETF single-day net inflow or outflow of at least $100 M, or a token unlock of at least 0.5% of circulating supply; partnerships, regulatory action, security incidents, listings and delistings do not count here — then fill any remaining slots by largest absolute 24-hour move. Followin has no structured ETF-flow or circulating-supply field (2026-10-09 实测 `metrics(keywords=["HYPE","SUI"], query="circulating supply market cap", asset_type="crypto")` → empty `results` with a `no_match` warning), so read both figures from the news search: the flow from a SoSoValue or Farside daily total (write which US trading day it covers — 2026-10-09 北京上午 only the 10-07 BTC/ETH totals were published, −$484.9 M and −$161 M), the unlock share from a report that states the percentage of circulating supply. When no returned item states the figure, that asset does not count as a material-event asset; do not compute a percentage from memory. When no asset meets either threshold, rank all by absolute 24-hour move. If more than three assets have material events, rank those by absolute 24-hour move. Batch their final candidates into one `tweets_by_ids` call. For other assets, do not quote a handle or link in `KOL 怎么看`; mention a view only as unverified context or leave it out.

Select two or three posts per high-attention asset when useful. Prefer original posts that contain a thesis plus data, reasoning, a time horizon, or a falsifiable condition. Aim for viewpoint diversity: fundamental/flow, technical/conditional, and risk/positioning where available. Exclude referral or exchange promotions, copied ATH commentary, pure price targets, self-congratulation, unrelated word matches, and claims whose supporting detail is not present. Do not rank a post solely by follower count or engagement. Preserve disclosures such as “holding HYPE” and distinguish a KOL opinion from verified market data.

Keep structured `kol_call` consensus and curated X analysis separate. A missing structured consensus does not prohibit a `KOL 怎么看` section when the broader Twitter search yields strong exact-asset analysis.

### 4. Trader positions and new actions

Call `signal` with category `trader_position` for the watchlist batch and `limit=50`: `limit` is per group, defaults to 10 sorted by rating, and the group rollup is recomputed on the truncated rows without any warning (N-171). Retrieve the current active posture without forcing a short time filter — `time_range` silently drops stale legs and recomputes the rollup (N-171) — then use each position leg's `event_time` to identify actions inside the report window.

An asset with no active legs is simply absent from the batch response — no group, no warning, `status:"ok"` (2026-10-08 实测：SOL and SUI dropped out of a five-asset batch). Write “当前榜上没有交易员仓位”, not “交易员没有仓位”.

For each asset, keep these concepts separate:

- current active long/short legs;
- gross and net reported notional;
- long/short notional ratios;
- distinct-trader agreement;
- new `open`, `add`, `reduce`, or `close` actions during the window;
- material trader quality context, including tier, overall sample, recent performance, and whether the asset is a stated focus or caution symbol.

A trader may hold simultaneous long and short legs. Count position legs for exposure, but count that person once for agreement and treat a two-sided trader as hedged/abstaining from the directional vote. Exclude null notional from dollar sums while retaining the leg count. All notional is bot-reported, not inferred margin.

Lead with distinct-trader agreement. Quote the notional ratio or `net_direction` only when no leg in the group has null notional and no single leg exceeds half of gross notional; otherwise say the dollar split is dominated by one position or incomplete. 2026-10-08 实测 ETH：three of four traders short, yet `net_direction:"long"` / long ratio 0.83 because one $1.0 M long outweighed the rest and two of the four legs had null notional. Fixed threshold: fewer than 3 distinct traders = sample too small; report it as such rather than as a direction. Apply the same wording to a trivially small gross notional (HYPE returned one $100 leg as “100% long”).

Before quoting trader quality, apply the profile checks in the caveat register (N-59 group): treat `pnl_ratio_infinite=true` or `pnl_ratio` above 100 as unverifiable rather than strong (one tier-A profile showed a last-30-day ratio of 985,510), quote `n_trades` with any win rate, flag `current_symbol_caution=true`, and flag leverage ≥10x.

Do not equate “currently long” with “newly bought”. `action` is the leg's latest action at `event_time`, which can be days old. Write “still long but reducing” only when that `reduce` falls inside the report window; an older one is “still long; last action was a reduce on <date>”, not a new development.

### 5. Optional watchlist inbox

When available, `subscription` can store the watchlist and surface unread KOL-call counts at zero quota cost. It is a pull-based inbox, not server push. Actual post content still comes from `signal`.

Ask the user before any `subscription` call and proceed only on a clear yes. `set` is a persistent write to the user's watchlist, and `list` is not read-only either: it folds pending updates into `shown`, changing the unread state. One consent at schedule setup covers the recurring runs it names; never `delete` without a separate request. Without consent, skip this step — the report does not depend on it. Acknowledge unread counts only after the report has presented those updates.

## Synthesis rules

Read [references/report-format.md](references/report-format.md) before writing the final report.

- Default to a concise morning or evening brief, not a research report. A single-asset report should normally fit on one phone screen.
- Separate facts from interpretation through wording, but do not add bulky `Facts` and `AI interpretation` subsections when a short sentence is clear.
- Compare the current report with the previous successful report in the same task when available. State what is new, what changed direction, and what remained unchanged. Without a baseline, label the run “initial snapshot”.
- Highlight cross-source alignment and divergence: price vs news, KOL speech vs real positioning, active direction vs add/reduce actions, and project event vs price confirmation.
- Rank events by impact and freshness, not by article count.
- Merge duplicate coverage into one event and keep no more than three important developments per asset by default.
- Attribute the report once in the footer with `数据来源：Followin MCP`. Do not prefix individual facts or bullets with “Followin MCP显示/收录”. Mention a source inline only when distinguishing an official statement from secondary coverage, identifying supplemental non-Followin data, or explaining a material data gap. Do not clutter the brief with downstream media domains or raw links; preserve source URLs and request IDs for traceability when the user asks.
- If a required leaf is missing, mark it unavailable; do not backfill it with old values or uncited memory.
- Include the effective window and timezone in one compact line. Surface sample sizes or timestamp problems only when they affect the conclusion. Keep Followin request IDs internally and show them only when the user asks, a data-quality problem needs diagnosis, or auditability is required.
- Keep the report useful for decisions, but phrase next steps as observation/validation conditions rather than trade instructions.

## Failure and stopping rules

- If Followin is unavailable or authentication fails, say which sections could not be refreshed and stop. Do not manufacture a partial “current” report from memory.
- Retry one transient/session failure once. If the same call fails again, mark that leaf unavailable and continue with independent successful leaves.
- If an array parameter is rejected by an older host serializer, fall back to canonical symbols in the query, keep batches at five or fewer, and verify `meta.filters_applied.keywords` before using the result.
- Never expose an API key, authorization header, or secret in reports, logs, commits, or GitHub content.

The repository-wide MCP caveat register remains the single source of truth: [references/followin-mcp-caveats.md](../../references/followin-mcp-caveats.md).
