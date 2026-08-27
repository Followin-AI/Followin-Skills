# Followin Skills

**English** | [简体中文](./README.zh-CN.md)

> **Setup has moved** — the official way to connect Followin MCP is now **[followin.io/en/mcp](https://followin.io/en/mcp)** (API key on signup, ~5 minute setup, docs [here](https://followin.io/en/mcp/docs)). The npm installer that used to live in this repo is retired; this repo is now the skill files themselves.

AI agent skills for crypto trading, macro analysis, and US stock intelligence — powered by **Followin MCP**.

Skills trigger in both **Chinese and English**, and answer in whichever language you ask in.

---

## What's in here

| Bundle | Files | For |
|---|---|---|
| **[`Base Skill/`](./Base%20Skill/)** | 6 skills | Individual traders / analysts — multi-agent analysis, earnings, divergence scans, macro dashboards |
| **[`Community Skill/`](./Community%20Skill/)** | 6 skills | Community operators — ready-to-post briefs, weeklies, hot-takes for a retail US-stock community (Traditional Chinese output) |
| **[`Earnings Screener/`](./Earnings%20Screener/)** | 1 standalone skill | Earnings-season discovery — belongs to no bundle, usable on its own (incl. a [folder README](./Earnings%20Screener/): methodology mapping + rejected alternatives) |
| **[`Trader Diligence/`](./Trader%20Diligence/)** | 1 skill | Live perp positions of tracked traders — **who is actually long/short with real money, and can you trust their record**. Six gates against the most misleading fields (stale/ghost positions, duplicate names, net direction, win rate, profit factor, unpriced exposure). Does not compute returns (incl. a [folder README](./Trader%20Diligence/)) |
| **[`Premarket Tracker/`](./Premarket%20Tracker/)** | 1 standalone skill | US-stock premarket watchlist tracking — scheduled or immediate reports based on tickers, positions, and timezone |
| **[`Crypto Watchlist Tracker/`](./Crypto%20Watchlist%20Tracker/)** | 1 standalone skill | Twice-daily crypto watchlist tracking — events, market/technical data, KOL calls, and trader positions at 09:00/21:00 |
| **[`Feed Manager/`](./Feed%20Manager/)** | 1 skill | **Reads the stock accounts you follow, so you stop forgetting what they said.** Every day their tweets become a brief, then get filed into a running note per ticker and per sector — "who was bullish at $85 three weeks ago" takes five seconds. Trades you report get logged with a *why* and dated review prompts. Three checks catch silent gaps: an account never pulled, a pull that didn't reach far enough back, something pulled but never written down. **No number goes in without a source** (incl. a [folder README](./Feed%20Manager/)) |
| **[`Research Reader/`](./Research%20Reader/)** | 5 skills | Which ticker to read, then reading sell-side research on it — can you trust the call, how far, what date to watch next, who else gets pulled in (incl. a [folder README](./Research%20Reader/) and [sample outputs](./docs/研报投研台样张.md)) |
| **[`Twitter Workflow/`](./Twitter%20Workflow/)** | 7 skills | Daily Twitter ops for a crypto/macro/US-stock content account — scan → topic → draft → engage → review, MCP-driven, human confirms every publish (incl. a [folder README](./Twitter%20Workflow/)) |
| **[`references/`](./references/)** | 4 files | Shared single-source-of-truth: official routing primer, MCP call red-lines, agent prompts, post style |

Everything is plain Markdown. There is no build step and no runtime dependency beyond the MCP server.

---

## Setup

**1. Get an API key** — sign up at [followin.io/en/mcp](https://followin.io/en/mcp).

**2. Connect the MCP server.** The official endpoint is a **Streamable HTTP** transport at `https://mcp.followin.io/v2/mcp`, authenticated with an `x-api-key` header.

Claude Code:

```bash
claude mcp add followin https://mcp.followin.io/v2/mcp --scope user --transport http --header "x-api-key: YOUR_API_KEY_HERE"
```

Other clients — paste into the config file below, replacing `YOUR_API_KEY_HERE`:

```json
{
  "mcpServers": {
    "followin": {
      "type": "http",
      "url": "https://mcp.followin.io/v2/mcp",
      "headers": { "x-api-key": "YOUR_API_KEY_HERE" }
    }
  }
}
```

> **Legacy SSE endpoint.** Older clients that don't speak Streamable HTTP can still use `"type": "sse"` with `https://mcp.followin.io/v2/sse` (same header). Verified working as of 2026-07-24, but the Streamable HTTP endpoint above is the officially documented one — prefer it for new setups.

| Client | Config file |
|---|---|
| Claude Code | `~/.claude.json` (global) or `<project>/.mcp.json` |
| Claude Desktop | `~/Library/Application Support/Claude/claude_desktop_config.json` · `%APPDATA%\Claude\claude_desktop_config.json` |
| Cursor | `~/.cursor/mcp.json` |
| Windsurf | `~/.codeium/windsurf/mcp_config.json` (use `serverUrl` instead of `url`) |
| Cline | Cline panel → MCP Servers (gear icon) |
| Continue.dev | `~/.continue/config.yaml` (convert JSON to YAML) |

Restart your client after editing.

**3. Install the skill files** (optional) — copy what you want into your client's command directory:

```bash
cp "Base Skill"/*.md ~/.claude/commands/
```

Skills are written in Claude Code's slash-command format (YAML frontmatter + Markdown body). They drop straight into Claude Code and OpenCode. For Cursor / Windsurf / Cline, copy each body into that tool's native rule format — the Markdown is fully portable.

> **You can skip step 3 entirely.** Once the MCP is connected, the model can answer most queries from the tools alone. The skills add tested call sequences, scoring rubrics, and output templates on top.

---

## The MCP: 5 tools

| Tool | Covers |
|---|---|
| **`metrics`** | Prices & quotes (crypto / US equities / ETFs / indices / FX / commodities), OHLCV history, technical indicators, FRED macro series, economic calendar, US-stock fundamentals (financials, valuation, peers, analyst ratings, Beat/Miss, EPS estimates), and **structured broker research reports** (report cards, target prices, thesis / catalysts / caveats) |
| **`news`** | Four-source aggregation — `media` / `twitter` / `telegram` / `research` — with trending mode, multi-language originals, and 100+ crypto TG channels auto-classified into 10 topic buckets |
| **`signal`** | KOL calls, top-trader & whale positions, insider trading (Form 4 + Senate + House), 13F institutional holdings |
| **`twitter`** | Advanced search, user profiles & timelines, follow-graph checks, full thread context, regional trends |
| **`subscription`** | Watchlist inbox for KOL-call symbols — subscribe, list, check unread (pull-based; no server push) |

**Conventions that matter:**

- US stocks are `asset_type="tradfi"`, crypto is `asset_type="crypto"` — always explicit. The one exception is `news()`, which should not receive it at all.
- **Structured broker research (研报) goes through `metrics`, not `news`.** `news(sources=["research"])` is for raw research-source *article* discovery; report cards, target prices, and thesis/catalyst fields come from `metrics` with an explicit research intent in the query (e.g. `query="<T> research reports"` — red line 12; array params like `categories=[...]` are rejected by the schema, N-8).
- **Omitting `categories` on `signal()` fans out** to insider trading + 13F institutional + KOL calls for a single quota unit — cheaper than three filtered calls returning the same data.

Full call red-lines and the known-issues register live in [`references/followin-mcp-caveats.md`](./references/followin-mcp-caveats.md).

---

## Base skills (6)

Numbered in recommended onboarding order — 01 is the deepest dive, 06 the lightest.

| # | Skill | Ask it | MCP tools |
|---|---|---|---|
| **01** | [Multi-Agent Stock Analysis](./Base%20Skill/01_multi-agent-stock-analysis.md) | `Should I buy NVDA` · `全面分析 NVDA` | `metrics` `news` `signal` |
| **02** | [US Stock Earnings Report](./Base%20Skill/02_us-stock-earnings-report.md) | `AAPL earnings` · `AAPL 财报` | `metrics` `news` `signal` |
| **03** | [US Stock Divergence Scan](./Base%20Skill/03_us-stock-divergence-scan.md) | `Divergence scan` · `美股背离扫描` | `metrics` `news` `signal` |
| **04** | [BTC Macro Dashboard](./Base%20Skill/04_btc-macro-dashboard.md) | `BTC macro` · `BTC 宏观` | `metrics` |
| **05** | [Gold Macro Dashboard](./Base%20Skill/05_gold-macro-dashboard.md) | `Gold macro` · `黄金宏观` | `metrics` |
| **06** | [Macro Morning Brief](./Base%20Skill/06_macro-morning-brief.md) | `Morning brief` · `宏观早报` | `metrics` `news` |

### 01 — Multi-Agent Stock Analysis

19 virtual analysts (8 legendary investors + 5 modern masters + 6 quant analysts) score independently, a risk manager constrains position size, and a portfolio manager makes the call — 21 agents total. Modeled on the ai-hedge-fund architecture. Its 11-call sequence covers the full official due-diligence orchestration. Analyst personas live in [`references/01_agent-prompts.md`](./references/01_agent-prompts.md).

### 02 — US Stock Earnings Report

Three-dimensional single-stock earnings review: financial Beat/Miss + media sentiment + macro backdrop, plus broker research and a signal fanout (insiders / 13F / KOL calls). Requires a specific ticker or company name.

### 03 — US Stock Divergence Scan

Finds inconsistencies between price, insider trading, and media coverage — the silent movers. Takes `scope` and `days`.

### 04 / 05 — BTC & Gold Macro Dashboards

Score the current macro environment 0–100 with a layered breakdown, so "how's the backdrop" gets a number instead of a vibe. Both pull FRED series and market snapshots through `metrics`.

### 06 — Macro Morning Brief

Daily macro/US-stock briefing aggregating three sources: macro data, news, and unusual moves. Takes an optional `watchlist`. This is the macro/equities brief — there is no crypto daily skill in this repo.



---

## Standalone skill — Earnings Season Screener

**Each earnings season, out of the hundreds of US companies that just reported, it finds the few that both
beat Wall Street's expectations by a wide margin *and* had management say on the call that they can't make
the product fast enough — and hands you the actual quotes.**

Doing this by hand means first sifting the numbers for genuine beats, then reading each company's earnings-call
transcript — 40,000+ words apiece — for lines like "backlog into next year", "capacity can't keep up",
"pricing still has room". Nobody gets through more than a handful a quarter.

**No ticker required — it goes and finds them.** Two discovery legs (most-active board + recent earnings
coverage) → verify how far each actually beat → read the full transcript for the best few →
**only names clearing both the numbers gate and the language gate make the list**.

Two things a human pass usually skips: **looking for the counter-evidence too** — one measured name hit all
seven positive classes while the same CFO, in the same call, raised CapEx guidance sharply and disclosed
inventory write-downs; and **checking which earnings figure you're reading** — the upstream payload carries two
different EPS conventions with nothing marking which is which, and one name showed a "+100% beat" while the
same data carried an **$11B GAAP net loss**.

⚠️ **Every parameter is backed by a measured counter-example** — including ones that were overturned: the gate
arithmetic was once internally inconsistent and wasted transcript quota; the transcript-lag threshold was set at
60 days before slow-reporting Chinese ADRs refuted it, forcing 90. See [`CHANGELOG.md`](./CHANGELOG.md).

---

## Standalone skill — Premarket Watchlist Tracker

Give the agent a watchlist, current positions, and premarket time. It uses Followin MCP to assemble market context, ticker-level moves, major news, broker research, and public signals, then returns conditional plans appropriate to empty, long, short, or options positions.

Clients with automation support create or update a recurring task; other clients run the same report once. Before 04:00 ET, prices are labeled as last-close/realtime snapshots rather than true premarket trades, and market holidays are called out explicitly. Install with:

```bash
cp "Premarket Tracker/premarket-watchlist-automation.md" ~/.claude/commands/
```

See [`Premarket Tracker/README.md`](./Premarket%20Tracker/) for usage.

---

## Standalone skill — Crypto Watchlist Tracker

Give the skill a crypto watchlist and timezone. At 09:00 and 21:00 it refreshes Followin-covered project/news events, live price and 24-hour data, RSI/MACD/moving averages/ATR/Bollinger Bands, KOL calls, current trader positions, and new open/add/reduce/close actions during the report window.

Automation-capable clients create or update two recurring tasks; other clients run one report immediately. Each successful run compares against the previous report and surfaces only meaningful changes. Install:

```bash
cp -R "Crypto Watchlist Tracker/crypto-watchlist-tracker" ~/.codex/skills/
```

See [`Crypto Watchlist Tracker/README.md`](./Crypto%20Watchlist%20Tracker/) for usage.

---

## Research Reader (5 skills)

**You hold a ticker and want to know what the sell-side actually thinks of it.**

A report's *conclusion* is no secret — the financial press reprints it within days, digits intact. The hard part is everything around it:
whether five targets spanning 2.4× is disagreement or five people modeling different things; that the most bullish report keeps its
valuation method in a *different* publication; that "strong results" means strong on price, not on units. That lives in the body text,
and reading five reports for it costs you an afternoon.

| # | Module | What it does |
|---|---|---|
| **r0** | Coverage Radar | **The discovery leg — needs no ticker.** "Who is the sell-side writing about this week" on a true 7-day window (default), with cumulative contrast and a mandatory subject/mention probe so you don't walk into r1 empty-handed |
| **r1** | Cross-Source Readout | A report says "$350 target" — should you believe it? Collides the call against street consensus, price action, KOL/insider positioning, and last quarter's actuals. No buy/sell — three answers only: **which price to anchor, what kind of selloff this is, what would change your mind.** |
| **r2** | Caveat Audit | Ignores the conclusion, audits its foundation: was this analyst research or **management talking on a non-deal roadshow**? Is that benchmark chart measured or modeled? What does the report itself admit doesn't reconcile? |
| **r3** | Catalyst Timeline | Future checkpoints named inside reports — product ramps, competitor events, financing dates. **None of these exist in a public earnings calendar.** Bucketed by precision; vague stays labeled vague. |
| **r4** | Supply-Chain Read-Through | Where other people's reports place your ticker — who mentions it, as beneficiary or casualty, **and why**, plus **who else on that chain just got repriced**. Measured: one INTC query also yielded UMC's target raised 87%, VSMC 55%. |

r1–r4 **share one research-report call**, so r2/r3/r4 are free once you've run r1. A full pass on one ticker costs 3 billable calls. Install:

```bash
cp "Research Reader"/*.md ~/.claude/commands/
```

⚠️ **It won't pick stocks for you** — every skill needs a ticker to start. For discovery use the Earnings Screener or the Divergence Scan.
⚠️ At most 10 reports come back per ticker, often 3–5 institutions after dedup. **Any "N institutions think X" is a floor, not the street** — all four are required to say so in their output.

Full write-up in **[`Research Reader/README.md`](./Research%20Reader/README.md)**; real sample outputs from one live INTC run in **[`docs/研报投研台样张.md`](./docs/研报投研台样张.md)**.

---

## Twitter Workflow (7 skills)

**Daily Twitter operations for a crypto/macro/US-stock content account.** Turns the daily grind — scan sources → pick topics → draft → engage → weekly review — into a pipeline: data pulled live from Followin MCP, decisions run on preset rules, **drafts stop at final copy — you press publish**.

| Skill | Trigger | What it does |
|---|---|---|
| **twitter-ops** | "跑一轮" | Orchestrator — chains the pipeline, auto/manual mode switch, stops at checkpoints. **"Human confirms every publish" lives here.** |
| **trend-scout** | "扫一下热点" | Pulls list / news / TG money-flow / on-chain in parallel → structured brief. **Live-data zone and narrative zone are hard-separated** — hard numbers stay hard numbers. |
| **topic-engine** | "今天发什么" | Topics → writable angles, scored on timeliness/differentiation/credibility. **Layer-B check**: pulls benchmark accounts' recent tweets — did they already post your angle? (cut or re-angle if so). |
| **tweet-composer** | "帮我写推文" | Drafts: single / thread / long-form-to-thread. Char budget, 6-dimension fact-check, pre-publish gate. |
| **engagement** | "看看我评论区" | Both directions — **Outbound** comments on high-engagement posts, **Inbound** triages your own comment section. |
| **performance-review** | "这周数据怎么样" | Weekly review: industry baseline, north-star, content-type effectiveness, hit/miss attribution; files top posts into a content vault. |
| **competitor-watch** | "竞对在发什么" | Benchmark-account monitoring — learn their moves, see where you sit. |

Install (skill directories, not commands):

```bash
cp -rn "Twitter Workflow/skills/"* ~/.claude/skills/    # -n = don't clobber same-named skills
```

⚠️ **No Twitter list?** `config.md` ships an example public list to get you running, but it's an *example not a default* (~17% off-topic content, ownership not yours) — swap in your own after one test run.
⚠️ **Fills stop the pipeline.** On first "跑一轮" it detects the template config and halts, telling you what to fill — you don't need to memorize the config table.

Full write-up in **[`Twitter Workflow/README.md`](./Twitter%20Workflow/README.md)**. Five of the seven (trend-scout / topic-engine / tweet-composer / performance-review / engagement) carry end-to-end live-run records (N-47~N-58); twitter-ops and competitor-watch are orchestration-level and have no independent N-series record yet in [`references/followin-mcp-caveats.md`](./references/followin-mcp-caveats.md).

---

## Feed Manager (1 skill)

**You follow a dozen people who talk about stocks. This reads them for you every day and remembers what they said.**

It is not a trend finder — it only reads the accounts *you* name. It strips the jokes and the ads, sorts what's left by ticker and by sector, and **keeps adding to the same notes day after day**, so "who was bullish at $85 three weeks ago" takes five seconds instead of an hour of scrolling. Every line carries the UTC timestamp, the account, and a link back to the original tweet.

| Layer | What you get |
|---|---|
| **Daily brief** | Two-zone: state zone overwrites to latest, event stream appends per batch — multiple pulls a day merge cleanly |
| **Per-ticker / per-sector notes** | Price history, who said what and when, **bear cases kept separately and never deleted**, your own position log |
| **Decision loop** | Every trade records *why* + 1w/1m/3m review prompts; lessons feed back into the pre-trade checklist |
| **Weekly** | Holdings & sector evolution, KOL behavior, account-quality review, **your own decision-quality review** |

Three checks run automatically, because the ways this goes wrong are all silent. **Did we pull every account?** — a coverage table marks each one pulled / empty / failed, so none can quietly go missing. **Did we get all their tweets?** — one API call returns 20 items, which won't cover a wide window, so the script warns when a pull didn't reach back far enough. **Did everything we pulled get written down?** — a hook checks the files before letting you end the session. On top of that, one rule everywhere: **every number must trace to a data source or a stated principle. No basis, no number.**

Install (skill directory, not a command):

```bash
cp -rn "Feed Manager/skills/"* ~/.claude/skills/
```

⚠️ **Zero-config trial**: say "run a quick brief on these 5 accounts" with the built-in starters — nothing is written to disk. ⚠️ The 5 starters lean semiconductors with **no bear voice**; add 1–2 skeptics before real use — an all-bull roster is the most dangerous blind spot.

**Boundaries**: this is the "your list" lens. Market-wide KOL chatter → `Community Skill/c4_social-pulse`; real money positions → `Trader Diligence`.

Full write-up in **[`Feed Manager/README.md`](./Feed%20Manager/README.md)**. Main chain verified end-to-end on live data; the two subagent paths and the weekly are template-verified only.

---

## Community bundle (6)

A separate bundle for **community operators** running a US-stock community for beginners. Output is ready-to-paste Traditional Chinese posts. Full operator handbook — module index, weekly cadence, quota budget, pinned-post templates — in **[`Community Skill/README.md`](./Community%20Skill/README.md)**.

| # | Module | Output |
|---|---|---|
| **c1** | Daily Brief | Morning report · pre-open preview · intraday refresh |
| **c2** | Weekly | This week's market tone + main threads + next week's confirmed calendar (600–800 chars, Traditional Chinese) |
| **c3** | Research Hot | Weekly research-report leaderboard + deep-dive notes |
| **c4** | Social Pulse | Sentiment × real positions × insiders thermometer, or market-wide signal roundup |
| **c5** | Hot Take | Event scan menu + 300–500 word flash post + earnings quick-read |
| **c6** | Ticker Check | Internal triage memo — is this ticker worth writing about? *(not for posting)* |

---

## Routing

Similar-sounding requests go to different skills:

| You say | Routes to | Why |
|---|---|---|
| `Should I buy NVDA` / `NVDA 值不值得买` | 01 Multi-Agent | Named ticker + buy/sell decision |
| `AAPL earnings` / `AAPL 财报` | 02 Earnings Report | Named ticker + earnings |
| `Divergence scan` / `背离扫描` | 03 Divergence Scan | Price/media/insider inconsistency |
| `BTC macro` / `BTC 宏观` | 04 BTC Dashboard | Asset-specific macro score |
| `Morning brief` / `宏观早报` | 06 Macro Morning Brief | Macro/US-stock daily briefing |
| `earnings screener` / `财报季扫描` | [Earnings Season Screener](./Earnings%20Screener/earnings-season-screener.md) (standalone) | **No-ticker discovery**; a named ticker routes to Base Skill 02 |
| `Premarket watchlist` / `每天盘前跟踪我的自选` | [Premarket Tracker](./Premarket%20Tracker/premarket-watchlist-automation.md) (standalone) | Watchlist + positions + recurring or immediate premarket report |
| `Crypto watchlist report` / `每天早晚跟踪我的自选币` | [Crypto Watchlist Tracker](./Crypto%20Watchlist%20Tracker/) (standalone) | Crypto watchlist + project events + market/technical data + KOL/trader signals + 09:00/21:00 updates |
| `Can I trust this target` / `研报解读` | [r1 Cross-Source Readout](./Research%20Reader/r1_cross-source-readout.md) | Report call + four-way collision; "what does the report say" routes to c3 |
| `Is this report solid` / `基准是谁` | [r2 Caveat Audit](./Research%20Reader/r2_research-caveat-audit.md) | Audits the foundation, never restates the conclusion |
| `What catalysts are next` / `接下来盯什么` | [r3 Catalyst Timeline](./Research%20Reader/r3_catalyst-timeline.md) | Report-named checkpoints; "when does X report earnings" does **not** route here (calendar is unusable — caveats N-22) |
| `Who is long SNDK` / `谁在做 SNDK` · `钱在挤哪` | [Live Position Diligence](./Trader%20Diligence/live-position-diligence.md) | Real-money perp positions + trader track record, with six gates (ghost-position filter first). **Not** a copy-trade ledger |
| `Who is the sell-side covering` / `谁被研报提得最多` | [r0 Coverage Radar](./Research%20Reader/r0_coverage-radar.md) | **No-ticker discovery** for research; default 7d window + cumulative contrast, mandatory subject/mention probe, no direction |
| `Gold macro` / `黄金宏观` | 05 Gold Dashboard | Asset-specific macro score (gold) |
| `Where do other reports place my ticker` / `产业链读穿` | [r4 Supply-Chain Read-Through](./Research%20Reader/r4_supply-chain-readthrough.md) | Cross-ticker mentions + who else on the chain got repriced |
| `run KOL watch` / `跑一下 KOL` | [Feed Manager](./Feed%20Manager/README.md) | Your own roster → daily brief + running archive. Market-wide KOL chatter routes to c4; real-money positions to Trader Diligence |
| `CPI impact` / `CPI 影响` | *(no dedicated skill)* | Indicator interpretation is model-native — the model calls `metrics`+`news` directly; the FRED series dictionary lives in the caveats reference (Appendix A) |

Each skill's frontmatter carries explicit `trigger` and `not_trigger` lists — that's what keeps neighbours from stealing each other's queries.

---

## Maintenance discipline

`references/followin-mcp-caveats.md` is the **single source of truth** for MCP call red-lines and known upstream issues. Skills mirror the relevant caveats inline; **on conflict, the reference file wins.**

When MCP behavior changes: edit the reference file first, then sweep the inline mirrors in the affected skills. The register also records the rollback action for each issue, so workarounds can be removed once upstream ships a fix.

---

## Pricing & support

Plans, credit allowances, and rate limits: **[followin.io/en/mcp](https://followin.io/en/mcp)** · docs at [followin.io/en/mcp/docs](https://followin.io/en/mcp/docs).

Bugs and feature requests: [GitHub Issues](https://github.com/Followin-AI/Followin-Skills/issues).

MIT licensed.
