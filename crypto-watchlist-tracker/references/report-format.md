# Morning and evening brief format

The default deliverable is a compact daily brief, not a full research report. Optimize for a phone screen and write in the user's language.

## Single-asset morning brief

```text
# <ASSET> 早报｜<DATE>
更新：<END TIME AND TIMEZONE>｜覆盖：<WINDOW>｜<INITIAL OR DELTA>

一句话：<what matters most this morning>

## 隔夜重点
- <event and why it matters>
- <event and why it matters>

## 盘面与资金
<current price and 24h move when reliable; one natural technical conclusion; KOL/trader or flow change>

## KOL 怎么看
- <@handle and direct link>：<thesis plus its key evidence or condition>
- <@handle and direct link>：<a distinct or opposing angle>

## 今天关注
- <validation condition>
- <validation condition>

数据来源：Followin MCP（<tools used>）<short material data gap if any>
仅供研究参考，不构成投资建议。
```

## Single-asset evening brief

Use the same compact shape, with these labels:

- headline: `<ASSET> 晚报｜<DATE>`;
- `一句话`: what changed during the day;
- `今天发生了什么`: only new or materially updated events since the morning report;
- `盘面与资金`: current move, one technical conclusion, and new KOL/trader actions;
- `KOL 怎么看`: two or three new, high-signal X views only when useful;
- `今晚关注`: up to three overnight validation conditions.

Do not repeat unchanged morning items except when their price confirmation has materially changed.

## Multiple assets

Start with `自选概览`, using one natural line per asset:

```text
- BTC：<price/move>｜<state>｜<main new event or signal>
- ETH：<price/move>｜<state>｜<main new event or signal>
```

Expand only high-attention assets under `重点币种`. Do not force a large table or a full card for every symbol.

## Compression rules

- Lead with one plain-language conclusion.
- Keep no more than three event bullets per asset and merge duplicate coverage of the same event.
- Write technical analysis as one sentence. Mention no more than one or two numbers, and only when an indicator is exceptional or marks a meaningful change. Never list every RSI, EMA, SMA, MACD, ATR, and Bollinger value.
- Keep `KOL 怎么看` to two or three selected X posts. Summarize the thesis and its evidence or condition rather than quoting the post at length. Link the handle or original post because the user's purpose is to inspect the KOL view. Prefer one fundamental/flow view, one conditional technical view, and one risk/positioning view when strong examples exist; never manufacture balance from weak posts.
- Keep structured KOL consensus and trader positions in `盘面与资金`. If those leaves have no reliable exact-symbol sample, state the gap briefly without narrating the full filtering process; curated X analysis can still appear separately.
- State `数据来源：Followin MCP` once in the footer. Write the body naturally and never repeat “Followin MCP显示/收录” before each fact. Add an inline source label only for official-versus-secondary distinctions, supplemental non-Followin data, or a material data gap. Do not append downstream media links or outlet-by-outlet citations by default.
- Put material limitations in the `数据` footer as one short clause. Hide request IDs and implementation diagnostics unless the user asks or a failure needs investigation.
- Keep next-step language observational. Do not provide orders or promised price targets.

## Technical exceptions worth surfacing

Examples include:

- RSI entering or leaving an extreme zone;
- price crossing a major long-term moving average;
- MACD direction reversing rather than merely remaining positive or negative;
- ATR or realized range expanding sharply;
- price breaking or rejecting a Bollinger boundary.

If none of these is material, write only a conclusion such as `趋势仍偏强，暂未出现明显技术面拐点`.

## Source footer

Use a compact footer such as:

`数据来源：Followin MCP（metrics / news / signal），覆盖 21:00–09:00；交易员仓位暂无覆盖。`

Always end with:

`仅供研究参考，不构成投资建议。`
