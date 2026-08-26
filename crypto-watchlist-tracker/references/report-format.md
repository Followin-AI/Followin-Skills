# Report format

Use this structure for scheduled and on-demand reports. Keep the default report compact enough to scan on a phone; expand a coin only when a material event or conflicting signal deserves it.

## Header

State:

- report mode: morning / evening / on demand;
- effective start and end time with timezone;
- watchlist;
- whether this is an initial snapshot or a delta from the previous successful report.

## 1. Portfolio-level summary

Start with a table containing one row per asset:

| Asset | Price / 24h | Trend | Heat | New events | KOL | Trader action | Attention |
|---|---:|---|---|---|---|---|---|

`Attention` is `high`, `medium`, or `low`, based on the combination of event impact, price displacement, and genuinely new KOL/trader actions. It is a research priority, not a bullish/bearish recommendation.

Then give no more than three cross-asset observations, such as:

- strongest relative move and whether it has event support;
- clearest KOL/position divergence;
- highest near-term risk from security, unlock, listing, or extreme heat.

## 2. Per-asset card

For every watchlist asset, include the following labels. Omit empty subfields only after stating that the corresponding leaf returned no usable data.

### `<SYMBOL>｜<project name>`

**Market data.** Current price, 24-hour change, volume, data source and timestamp.

**Technical state.** Trend / heat / volatility labels, followed by the actual latest RSI, available moving averages, MACD direction, ATR, and the most relevant recent range or Bollinger position. Do not invent support or resistance where history was not returned.

**New events and project developments.** Deduplicated events ordered by impact. For each: what happened, event/publication time, source type, why it matters, and whether the price has confirmed the event so far.

**KOL calls.** Bullish / bearish / neutral counts, deduplicated post count, representative reasoning, and sample-size warning.

**Trader positions.** Current long/short posture, reported gross/net notional and ratios, distinct-trader agreement, plus only the `open/add/reduce/close` actions whose `event_time` falls inside the report window. Mention trader history only when it changes how the position should be interpreted.

**AI interpretation.** Two or three sentences explaining whether price, events, KOL speech, and real positioning align or conflict. Mark this explicitly as inference.

**Next 12 hours.** Up to three validation conditions: an official follow-up, a price/volume condition grounded in returned data, a change in trader actions, or a KOL consensus shift. Do not give an order or promised target.

## 3. Changes since the previous report

When a prior successful report exists, list only meaningful deltas:

- new event or official update;
- technical label change;
- KOL direction/count change;
- new trader action or net-direction change;
- an earlier event receiving or losing price confirmation.

Do not repeat unchanged old articles. If no prior report is available, write `初始快照：暂无上一期可比基线。`

## 4. Data quality and sources

End with:

- Followin tools actually used;
- request IDs;
- missing leaves, stale timestamps, alias uncertainty, or small samples;
- `以上为Followin覆盖来源内的研究更新，不代表全网信息完备；仅供研究参考，不构成投资建议。`

## Morning/evening emphasis

- **09:00 morning**: lead with overnight events, official updates, Asia-session moves, and the next 12-hour catalysts.
- **21:00 evening**: lead with what changed since morning, events that gained or lost price confirmation, and overnight security, unlock, and listing risks.
