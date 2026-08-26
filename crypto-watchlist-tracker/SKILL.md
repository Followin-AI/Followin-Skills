---
name: crypto-watchlist-tracker
description: "Track a user-supplied crypto watchlist twice daily or on demand with Followin MCP, combining project/news events, live prices, technicals, KOL calls, and trader positions. Use for requests such as ‘每天早晚跟踪我的自选币’, ‘创建币圈自选监控’, ‘更新我的币圈雷达’, or ‘crypto watchlist report’. Do not use for order execution or a general market brief with no watchlist."
---

# Crypto Watchlist Tracker

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

If automation is unavailable, run one report immediately and say that no recurring task was created.

## Followin data workflow

Followin is the primary evidence layer. Explicitly use `asset_type="crypto"` for `metrics` and `signal`. For entity-search `news` calls, omit `asset_type` to preserve recall. Batch no more than five symbols per structured call and compare returned symbols with the requested batch.

### 1. Market and technical state

For each batch of up to five watchlist assets:

1. Call `metrics` for the live market snapshot: price, 24-hour change, 24-hour volume, and source timestamp.
2. Call `metrics` for at least 30 days of price/technical context. Inspect trend, momentum, heat, and volatility indicators such as RSI, moving averages, MACD, ATR, and Bollinger Bands when available.
3. Use the latest dated value for each indicator. Never combine values from different dates without saying so.

If a requested snapshot field such as 24-hour change or source timestamp is absent, mark that field unavailable. Do not substitute a daily-close calculation unless the returned candle timestamps define an exact 24-hour interval.

Do not use `metrics time_range` shorter than one day to infer a rolling intraday window. For the current state use the live snapshot; for intraday candles use an explicit interval when the task genuinely needs them.

Translate indicators into three separate labels rather than one opaque score:

- **Trend**: strong / improving / range / weakening, based on price relative to available moving averages plus MACD direction.
- **Heat**: cool / neutral / hot / extreme. Treat RSI 70 as hot and 80 as extreme, but note that strong crypto trends can remain overbought.
- **Volatility**: normal / elevated / extreme, using ATR and recent range only when available.

These labels are primarily for internal synthesis. In the visible brief, summarize the technical state in one natural sentence. Mention at most one or two indicator values only when they are exceptional or decision-relevant, such as overbought/oversold RSI, a major moving-average break, a MACD reversal, an ATR spike, or a Bollinger breakout. Never print a mechanical indicator inventory.

### 2. News, events, and project developments

Run one `news` search per asset using its canonical symbol and project name, with the report window, `sort_by="time"`, and a bounded result count. The mixed-source result may include media, X, Telegram, and indexed project material.

Classify each retained item as one of:

- official/project: protocol releases, governance, tokenomics, unlocks, burns, treasury actions, partnerships, listings, delistings;
- market event: regulation, ETF/flow, exchange policy, macro spillover;
- security: exploit, bridge/wallet issue, chain halt, exchange warning;
- narrative/social: a material change in attention or positioning, not ordinary chatter.

When `official_accounts` contains a named X handle, use `twitter` only for that account's raw timeline and filter posts to the report window. Do not use raw Twitter as a substitute for the general news search.

Deduplicate by canonical/source URL first, then collapse multiple articles about the same underlying event. Prefer the original project/exchange/regulator statement; retain a secondary article only when it adds independently useful facts. Keep event time separate from publication time.

Say “Followin覆盖来源内的更新”, never “全网所有新闻”. Absence of returned coverage is not proof that nothing happened.

### 3. KOL calls

Call `signal` with category `kol_call`, query `consensus`, the watchlist batch, and the report window. Report:

- bullish, bearish, and neutral counts;
- distinct source/post count after deduplication by `source_url`;
- representative reasoning from higher-quality sources when returned;
- whether the sample is balanced, one-sided, or too small.

One post can fan out into multiple symbol rows, and short aliases can retrieve longer symbols such as `ETHFI` for `ETH`. Verify every returned row's canonical `symbol` against the requested asset and discard non-matches. If an aggregate contains non-matching symbols and cannot be recomputed safely, call the detail view, filter exact-symbol rows, and aggregate those rows; otherwise mark the asset-specific KOL sample unavailable. Deduplicate retained posts by `source_url`, or by author plus timestamp plus normalized content when no URL is returned. Do not call a one-sided sample “market consensus” without its sample size.

Also search `news` with `sources=["twitter"]` over the report window for broader KOL analysis that may not be classified as a structured call. Search both the exact ticker and project name, then use `twitter` with `tweets_by_ids` to verify the full text, author, timestamp, engagement, and direct link for the final candidates.

Select two or three posts per high-attention asset when useful. Prefer original posts that contain a thesis plus data, reasoning, a time horizon, or a falsifiable condition. Aim for viewpoint diversity: fundamental/flow, technical/conditional, and risk/positioning where available. Exclude referral or exchange promotions, copied ATH commentary, pure price targets, self-congratulation, unrelated word matches, and claims whose supporting detail is not present. Do not rank a post solely by follower count or engagement. Preserve disclosures such as “holding HYPE” and distinguish a KOL opinion from verified market data.

Keep structured `kol_call` consensus and curated X analysis separate. A missing structured consensus does not prohibit a `KOL 怎么看` section when the broader Twitter search yields strong exact-asset analysis.

### 4. Trader positions and new actions

Call `signal` with category `trader_position` for the watchlist batch. Retrieve the current active posture without forcing a short time filter, then use each position leg's `event_time` to identify actions inside the report window.

For each asset, keep these concepts separate:

- current active long/short legs;
- gross and net reported notional;
- long/short notional ratios;
- distinct-trader agreement;
- new `open`, `add`, `reduce`, or `close` actions during the window;
- material trader quality context, including tier, overall sample, recent performance, and whether the asset is a stated focus or caution symbol.

A trader may hold simultaneous long and short legs. Count position legs for exposure, but count that person once for agreement and treat a two-sided trader as hedged/abstaining from the directional vote. Exclude null notional from dollar sums while retaining the leg count. All notional is bot-reported, not inferred margin.

Do not equate “currently long” with “newly bought”. A long position with a `reduce` action is explicitly “still long but reducing”.

### 5. Optional watchlist inbox

When available, use `subscription` to store the watchlist and surface unread KOL-call counts at zero quota cost. It is a pull-based inbox, not server push. Actual post content still comes from `signal`. Acknowledge unread counts only after the report has presented those updates.

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

The repository-wide MCP caveat register remains the single source of truth: [references/followin-mcp-caveats.md](../references/followin-mcp-caveats.md).
