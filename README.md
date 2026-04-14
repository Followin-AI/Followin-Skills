# Followin Skill User Guide

13 AI agent skills for crypto trading, macro analysis, and market intelligence — powered by **Followin MCP** and **Premium MCP**.

All skills support both **Chinese and English** triggers and output in the language you use.

## What's portable across AI tools

The package has two layers:

1. **MCP servers** (Followin MCP + Premium MCP) — these provide the underlying data and tools, and work in **any MCP-compatible AI client**: Claude Code, Claude Desktop, Cursor, Windsurf, Cline, Continue.dev, OpenCode, OpenClaw, and so on.
2. **Skill files** (the 13 markdown files in `.claude/commands/`) — written in Claude Code's slash-command format. They drop in directly to Claude Code and other clients that read the same format. For tools that use a different rule/command format, the markdown bodies are still fully portable — just paste the relevant fields into your tool's native format.

## Setup

Setup has two parts: **install the skill files** (your AI tool reads them as slash commands or prompts) and **configure the MCP servers** (the data backend). The npm package handles the first part on any OS; the second part is a one-time client-side config.

### Step 1 — Install skill files

#### Quick path (Claude Code, OpenCode, OpenClaw)

```bash
# Claude Code (default)
npx @followin/skills install

# Claude Code, project-local
npx @followin/skills install --client claude-code-project

# OpenCode / OpenClaw
npx @followin/skills install --client opencode

# Any other directory
npx @followin/skills install --target ~/path/to/your/skills/
```

Run `npx @followin/skills clients` to see all built-in presets, or `npx @followin/skills` for the full CLI help. Upgrade with the same command; remove with `uninstall`.

Works on macOS, Linux, and Windows — all you need is Node.js 16+.

#### Cursor / Windsurf / Cline / Continue.dev / other tools

These tools use their own rule/command formats, so the skill files won't drop in directly. Two ways to bring the skills over:

**(a) Adapt to native format.** Get the source location with:
```bash
npx @followin/skills path
# prints: /path/to/.../node_modules/@followin/skills/.claude/commands
```
Then open each `.md`, copy the instructions from the body, and paste into your tool's command/rule format:
- **Cursor** → `.cursor/rules/*.mdc` (frontmatter: `description`, `globs`, `alwaysApply`)
- **Windsurf** → `.windsurf/rules/*.md` or `.windsurfrules`
- **Cline** → "Custom Instructions" in settings (one big block, or per-task)
- **Continue.dev** → `slashCommands` in `config.yaml`

**(b) Use as on-demand system prompt.** Once the MCPs are connected, paste the relevant skill body as a one-shot prompt: *"Behave like the BTC Macro Dashboard skill: \<paste skill content\>"*. Works in any tool with sufficient context window.

The Followin/Premium MCPs do all the heavy data lifting, so even without the skill scaffolding the model can answer most queries directly once it has the tools — the skill files mainly provide structured prompts, output formatting, and routing logic.

### Step 2 — Configure the MCP servers

Both servers are SSE-based and hosted by Followin. **You only need an API key** — contact the Followin team to get one. The server URLs are public:

| Server | URL |
|---|---|
| **Followin MCP** | `https://mcp.followin.io/sse` |
| **Premium MCP** | `https://premium-mcp.followin.io/sse` |

#### Config snippet (Claude Code, Claude Desktop, Cursor, Windsurf, Cline)

These clients all use the same JSON shape. Replace `YOUR_API_KEY_HERE` with your key and paste into the appropriate config file:

```json
{
  "mcpServers": {
    "followin-mcp": {
      "type": "sse",
      "url": "https://mcp.followin.io/sse?api_key=YOUR_API_KEY_HERE",
      "headers": {
        "X-API-Key": "YOUR_API_KEY_HERE"
      }
    },
    "premium-mcp": {
      "type": "sse",
      "url": "https://premium-mcp.followin.io/sse?api_key=YOUR_API_KEY_HERE",
      "headers": {
        "X-API-Key": "YOUR_API_KEY_HERE"
      }
    }
  }
}
```

#### Where the config file lives

| Client | Config file location |
|---|---|
| **Claude Code** | `~/.claude/settings.json` or project-level `.mcp.json` |
| **Claude Desktop** | `~/Library/Application Support/Claude/claude_desktop_config.json` (macOS) / `%APPDATA%\Claude\claude_desktop_config.json` (Windows) |
| **Cursor** | `~/.cursor/mcp.json` (or Settings → Features → MCP Servers) |
| **Windsurf** | `~/.codeium/windsurf/mcp_config.json` |
| **Cline** (VS Code) | Cline panel → MCP Servers (gear icon) — paste the same JSON |
| **Continue.dev** | `~/.continue/config.yaml` — convert the JSON to the YAML `mcpServers:` shape |
| **OpenCode / OpenClaw** | client config file (check your distribution's docs) |
| Any other MCP host | wherever your client reads MCP server definitions |

> **Note:** The API key is sent twice (once as a query param `?api_key=...` and once as a header `X-API-Key`) for compatibility across clients — some MCP hosts strip query params, others strip headers. Including both ensures it works everywhere.

The repo also ships a ready-to-edit `.mcp.json.example` you can copy as `.mcp.json` for project-level configs.

### Step 3 — Restart your client

Most clients cache MCP servers and slash commands at startup. Restart after configuration.

---

## Followin MCP — Crypto News & Sentiment

Followin MCP connects to the Followin crypto intelligence platform, providing:

- **Trending Topics** — Top 10 hot topics with heat scores, related tokens, and price movements
- **Trending Feed** — Popular news articles and tweets ranked by engagement
- **Token-level Content** — Key events, news, and community buzz filtered by specific token
- **Token KOL Opinions** — Twitter KOL views and analysis on specific tokens
- **Daily Digest** — Curated daily content from multiple media/KOL/institutional sources
- **Keyword Search** — Search articles, news flashes, and tweets with type filtering and time range
- **Intel Center** — Structured data channels: token unlocks, macro data, listing/delisting, project events, volume anomalies, funding rates

Built on these capabilities, 5 skills:

### 01 Followin Intel Center

One-stop query for market event data: token unlocks, macro economic releases, exchange listing/delisting announcements, project events, volume anomalies, and funding rates. Filter precisely by the dimension you care about.

**How to ask:**
- `Any large token unlocks this week`
- `What coins got listed recently`
- `Which tokens have abnormal funding rates`
- `Intel center overview` — top 1-2 items from each of the 6 channels

**6 data channels:**

| Channel | What it covers |
|---------|---------------|
| Token Unlock | Unlock dates, amounts, % of market cap, risk level |
| Macro | CPI/PPI/rates releases, policy moves, trade policy |
| Listing/Delisting | Exchange listing & delisting announcements |
| Project Events | Security incidents, protocol updates, corporate moves |
| Volume Anomaly | Volume spike multiples, alert prices, abnormal moves |
| Funding Rate | Funding rate data, short squeeze risk, sector breakdown |

### 02 Breaking News Analysis

Paste a crypto news headline or article, get back which tokens are affected, whether it's bullish or bearish, how strong the impact is, and for how long. No MCP dependency — pure AI analysis with optional web search verification.

**How to ask:**
- Paste a news snippet + `Analyze this news`
- `Analyze news impact`
- `Is this bullish or bearish`

**Two modes:**
- **Flash mode** — short news (1-3 sentences): quick bull/bear call with key targets
- **Deep mode** — long article or explicit request: full causal chain, second-order effects, historical parallels

Every bull/bear call includes a **counter-argument** — what conditions would invalidate the thesis.

### 03 Trending News & Topics

What is the market paying attention to right now? Cross-references the trending topic rankings with trending articles/tweets to find **multi-platform resonance** — topics that appear in both sources get top priority.

**How to ask:**
- `What's hot today`
- `Trending news today`
- `Hot topics today`
- `What's the market focused on`

**Two modes:**
- **Overview** (default) — full landscape of current hot events
- **Focused** — specify a token or topic: `Any news on ETH`, `What's happening in the AI sector`

Events are ranked by importance (macro/regulatory > sector-wide > single project), with resonance topics always on top.

### 04 Crypto Daily Brief

Generates a ready-to-publish daily crypto market briefing. Pulls from trending topics + daily digest sources, filters past 12 hours, selects 8-10 most important events, cross-validates, and outputs in a punchy editorial style.

**How to ask:**
- `Crypto daily`
- `Crypto morning brief`
- `Give me a daily brief`

**Key rules:**
- Item #1 is always BTC price action in editorial tone (not cold data)
- At least 2-3 macro/AI items guaranteed (won't be crowded out by altcoin noise)
- ~1/3 of items include a one-line editorial comment
- Altcoins outside top 10 by market cap limited to 2-3 items max

> Want macro/US stock morning brief instead? Say `morning brief` or `US stock daily` — that routes to Skill 10.

### 05 Token Buzz & Views

Specify a token, get a 4-dimension snapshot: news flashes, in-depth articles, Twitter KOL opinions, and community discussions — all in one query.

**How to ask:**
- `Any news on BTC`
- `What's happening with ETH`
- `SOL community discussion` — single dimension only
- `HYPE articles`

> Want KOL trading strategy views on a token? Say `What are KOL calls on BTC` — that routes to Skill 06 (Trading Strategy).

---

## Premium MCP — Trading Strategy & Macro Analysis

Premium MCP aggregates professional data sources:

- **Top Trader Positions** — Real-time CEX contract trader positions (direction, leverage, size)
- **On-chain Whales** — Hyperliquid on-chain verifiable whale positions (entry price, liquidation price, exact size)
- **KOL Call Orders** — KOL publicly shared trading strategies (entry/target/stop)
- **TG Channel Aggregation** — 70+ Telegram channels across 10 categories
- **Crypto Real-time Prices** — Batch USD prices for crypto assets
- **FRED Macro Data** — Federal Reserve economic database (rates, inflation, employment, GDP, yields)
- **Financial Market Data** — US stock/ETF/index/forex/commodity quotes, financial statements, earnings Beat/Miss, analyst estimates, key ratios, insider trading, economic calendar, treasury yields, gainers/losers
- **31 Financial Media Search** — Keyword search across Reuters, Bloomberg, CNBC, WSJ, FT and more
- **Twitter Data** — User tweets, search, follow relationships, Spaces

Built on these capabilities, 8 skills:

### 06 Trading Strategy & Signal

Three data sources cross-validated: CEX trader real positions + Hyperliquid on-chain whales + KOL public calls. Core principle: **money talks louder than tweets** — real positions always outweigh verbal calls.

**How to ask:**
- `Can I trade SOL` — full 3-source cross-validation
- `What are traders doing` — overview of all active positions
- `What are KOL calls on ETH` — KOL calls only
- `Whale positions` — on-chain positions only
- `Who's longing` / `Who's shorting`

**Signal classification:**
| Signal Type | Meaning | Confidence |
|-------------|---------|------------|
| Resonance | Traders + KOL same direction | Highest |
| Trader-only | Traders positioned, KOL silent | High |
| Contradiction | Traders vs KOL opposite directions | Caution (trust traders) |
| KOL-only | KOL calling, no trader follow-through | Lower |

### 07 TG Channel Intel

Extracts intelligence from 70+ Telegram channels, clusters by topic, distills views, identifies consensus and disagreements. Channels are quality-graded (high/medium), with high-quality channel views shown first. Supports Chinese, English, Korean, and Vietnamese language channels.

**10 channel categories:** Macro Analysis, Market Structure, Project Research, Narrative Tracking, Trading Signals, Live Trading, On-chain Data, Meme/New Launches, Cross-market, News Aggregation

**How to ask:**
- `What's TG talking about` — full overview
- `TG discussion` / `TG intel`
- `What are Telegram channels saying about BTC` — focused on a token
- `What are trading channels saying` — filtered by category

**Auto-routing by user profile:**

| You are... | Say | Channels queried |
|---|---|---|
| Contract trader | `What are trading channels saying` | Trading Signals, Live Trading, Market Structure |
| Macro focused | `TG macro views` | Macro Analysis, Cross-market |
| Info tracker | `TG latest updates` | News Aggregation, Narrative Tracking |
| Project researcher | `Any projects worth looking at on TG` | Project Research |
| On-chain analyst | `Any on-chain activity on TG` | On-chain Data |
| Meme trader | `Any new memes on TG` | Meme/New Launches |
| Everything | `What's TG talking about` | All categories |

### 08 BTC Macro Dashboard

Quantitative 0-100 macro environment score for BTC based on 15 indicators across 4 layers: global liquidity (35%), market environment (30%), crypto-native capital flows (25%), and economic data pulse (10%). Score of 50 is neutral; above 50 bullish, below 50 bearish.

**4-layer scoring:**
- **Layer 1 — Liquidity Direction (35%):** Net liquidity trend, Fed policy, FedWatch probabilities, M2 trend
- **Layer 2 — Market Environment (30%):** DXY, Nasdaq, VIX, real rates (TIPS), yield curve, gold
- **Layer 3 — Crypto-native Capital (25%):** BTC spot ETF flows, stablecoin market cap trend
- **Layer 4 — Economic Data Pulse (10%):** CPI/PCE surprise, employment surprise

Includes **contradiction detection** — flags when different layers point in opposite directions.

**How to ask:**
- `BTC macro` / `BTC macro dashboard`
- `BTC macro score` — quick score only
- `How is BTC macro`

> Heavy MCP usage: pulls 10+ FRED series, multiple market quotes, DeFiLlama API, and web searches. Not recommended for high-frequency use.

### 09 Gold Macro Dashboard

Quantitative 0-100 macro environment score for gold based on 15 indicators across 5 layers: real rates & monetary policy (40%), USD & FX (15%), central bank buying & physical demand (25%), safe-haven demand (15%), and economic data pulse (5%).

**Key difference from BTC dashboard:**
- Gold's #1 driver is **real interest rates** (TIPS yield), not liquidity
- **VIX scoring is reversed**: VIX spike = bullish for gold (safe haven), bearish for BTC (risk-off)
- **Central bank buying** is a structural factor unique to gold (not in BTC dashboard)
- **COT positioning is a contrarian indicator**: extreme net longs = bearish (overcrowded)

**How to ask:**
- `Gold macro` / `Gold macro dashboard`
- `Gold macro score` — quick score only
- `How is gold macro`

> Heavy MCP usage: pulls 8+ FRED series, market quotes, and web searches for FedWatch/COT/ETF/central bank data. Not recommended for high-frequency use.

### 10 Macro Morning Brief

Daily macro financial morning briefing: full-spectrum treasury yields, VIX, crude oil, USD index, economic calendar, media hot topics, market gainers/losers — one report to grasp the macro landscape before market open.

**How to ask:**
- `Morning brief` / `Morning briefing`
- `Macro morning brief`
- `US stock daily` / `Macro daily`
- `Financial morning brief`

**Report sections:**
1. Macro Environment table (10Y/2Y yields, spread, VIX, Brent crude, USD index)
2. Economic Calendar (US events, filtered from full global data)
3. Top 3 Media Hot Topics (with sentiment and representative articles)
4. Watchlist Movers (configurable via `watchlist` parameter)
5. Market Gainers/Losers (filtered for market cap > $500M)
6. Sentiment Distribution and overall market mood

> Heavy MCP usage: 8-9 parallel data pulls + multi-round news searches. Best used once during pre-market hours.

### 11 US Stock Earnings Report

Three-dimensional single-stock earnings analysis: financial Beat/Miss + media sentiment + macro backdrop. Covers income statement trends, Adjusted vs GAAP EPS, analyst forward estimates, key ratios, price momentum, and 14-day media coverage.

**How to ask:**
- `AAPL earnings` / `TSLA earnings report`
- `Show me NVDA earnings`
- `Earnings analysis MSFT`

**Key features:**
- **Beat/Miss uses Adjusted EPS** from the `earnings` endpoint (not GAAP)
- **Trend table shows both** Adjusted EPS and GAAP EPS side by side
- **Forward PEG** calculated from analyst estimates
- **Price momentum** across 7 timeframes (1D to 1Y)
- **Media sentiment** from 31 financial media sources (Claude-inferred)
- **Macro cross-check** based on sector (e.g., Tech gets 10Y yield + VIX)

> Heavy MCP usage: 7+ parallel data calls per stock. Use during earnings season for quick single-stock reviews.

### 12 Macro Analyzer

When a macro indicator drops, what sectors and ETFs are affected? Full chain: FRED data trend -> sector ETF actual performance -> media interpretation. Built-in mappings for 20+ common indicators.

**How to ask:**
- `CPI impact` / `NFP impact`
- `Rate impact` / `GDP impact`
- `Tariff impact`
- `Macro analysis` / `Indicator analysis`

**Built-in indicator mappings:**

| Indicator | FRED Series | Bullish Sectors | Bearish Sectors | Key ETFs |
|-----------|-------------|-----------------|-----------------|----------|
| CPI | CPIAUCSL | Energy, Materials, Real Estate | Technology, Consumer Disc. | XLE, XLB, XLK, XLY, TIP |
| Non-Farm Payrolls | PAYEMS | Consumer Disc., Financials | Utilities, Real Estate | XLY, XLF, XLU, XLRE |
| Fed Rate | FEDFUNDS | Financials | Real Estate, Utilities, Tech | XLF, XLRE, XLU, XLK |
| 10Y Yield | DGS10 | Financials | Tech, Real Estate, Utilities | XLF, XLK, XLRE, TLT |
| WTI Crude | DCOILWTICO | Energy | Airlines, Transportation | XLE, JETS, USO |
| Unemployment | UNRATE | Staples, Utilities | Consumer Disc., Financials | XLP, XLU, XLY, XLF |
| GDP | GDPC1 | Industrials, Consumer Disc. | Utilities | SPY, QQQ, IWM |

**Two verification modes:**
- **Real-time** (data < 7 days old): ETF moves reflect market's reaction to actual data
- **Expectation** (data > 7 days old): ETF moves reflect market pricing next release

### 13 US Stock Divergence Scan

Batch scans the US stock market for inconsistencies between price action, insider trading, and media coverage. Surfaces signals that most investors miss.

**4 signal types:**

| Signal | What it detects | Threshold |
|--------|----------------|-----------|
| **Silent Buy** | Insider purchase > $100K + media coverage <= 2 articles | Any market cap |
| **Sentiment Mismatch** | Price direction opposite to media sentiment | Market cap > $1B, price change > 5% |
| **Unreported Drop** | Large-cap crash with almost no media coverage | Market cap > $1B, drop > 8%, articles <= 3 |
| **Unreported Surge** | Significant rally with almost no media coverage | Market cap > $500M, gain > 20%, articles <= 2 |

**How to ask:**
- `Divergence scan` / `US stock divergence scan`
- `Silent moves` / `Silent buy`
- `Anomaly signals`
- `Unreported drop` / `Unreported surge`

**Process:** Pulls gainers/losers + insider trading -> filters by market cap -> cross-checks with 31 financial media sources -> flags divergences. Stocks with multiple signals flagged prominently.

> Heaviest MCP usage of all skills: requires market cap filtering for each candidate + individual news searches. Not recommended for frequent use.

---

## Quick Reference

| I want to know... | Say (English) | Say (Chinese) | Skill |
|---|---|---|---|
| What happened in crypto today | `Crypto daily` | `出个日报` | 04 |
| What's the market focused on | `What's hot today` | `今天有什么热点` | 03 |
| News about a specific token | `Any news on BTC` | `BTC有什么新闻` | 05 |
| What traders & KOLs are doing | `What are traders doing` | `策略信号` | 06 |
| What TG channels are saying | `What's TG talking about` | `TG上在聊什么` | 07 |
| Token unlocks / listings this week | `Any token unlocks this week` | `本周有什么解锁` | 01 |
| Impact of a breaking news | Paste news + `Analyze this` | 粘贴新闻 + `分析一下` | 02 |
| BTC macro environment score | `BTC macro` | `BTC宏观` | 08 |
| Gold macro environment score | `Gold macro` | `黄金宏观` | 09 |
| Daily macro/US stock briefing | `Morning brief` | `宏观早报` | 10 |
| Single stock earnings review | `AAPL earnings` | `AAPL财报` | 11 |
| Impact of a macro data release | `CPI impact` | `CPI影响` | 12 |
| Unusual signals in US stocks | `Divergence scan` | `美股背离扫描` | 13 |

---

## Skill Routing Guide

Some requests sound similar but route to different skills. Here's how routing works:

| You say | Routes to | Why |
|---------|-----------|-----|
| `Any news on ETH` | 05 Token Buzz | Asking for news about a specific token |
| `What are KOL calls on ETH` | 06 Trading Strategy | Asking for trading strategy/direction |
| `What's hot today` | 03 Trending News | Asking for market-wide hot events |
| `Crypto daily` | 04 Crypto Daily Brief | Generating a daily briefing |
| `Morning brief` | 10 Macro Morning Brief | Macro/US stock morning briefing |
| `TG views on BTC` | 07 TG Channel Intel | Explicitly mentions TG/Telegram |
| `CPI impact` | 12 Macro Analyzer | Analyzing a specific macro indicator |
| `Divergence scan` | 13 Divergence Scan | Scanning for price/media divergences |
| `AAPL earnings` | 11 Earnings Report | Single stock earnings analysis |

---

## Technical Notes

**MCP tool behaviors confirmed through testing:**
- `finance_tool_quote` with `^VIX` and `^IXIC` — cannot be batched, must call individually
- `finance_tool_batch_quote_short` — use for `DXUSD` (quote returns 402), supports comma-separated symbols
- `finance_tool_stable_request` — required for `profile`, `analyst-estimates`, `stock-price-change` (schema not fixed)
- `finance_tool_insider_trading_search` — the only working insider trading endpoint; `stable_request` path `insider-trading` returns 404
- `fred_get_series` — `limit` must be integer (not string); use `sort_order: "desc"` for latest data first
- `search_finance_news` — does not support compound keywords; search each concept separately; `users` must be array type
- `finance_tool_economic_calendar` — returns ~2.4MB of global data; needs post-processing to filter US events
