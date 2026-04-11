# Claude Crypto Skills

13 Claude Code Skills for crypto trading, macro analysis, and market intelligence — powered by Followin MCP and Premium MCP.

## Setup

1. Copy `.mcp.json.example` to `.mcp.json` and fill in your API key
2. Place the skill files from `.claude/commands/` into your `~/.claude/commands/` directory
3. Restart Claude Code

---

## Followin MCP — Crypto News & Sentiment

The Followin MCP connects to the Followin crypto information platform and provides the following data capabilities:

- **Trending Topic Ranks** — Top 10 trending topics with heat scores, related tokens, and price movements
- **Trending Feeds** — Ranked lists of hot news flashes and articles
- **Home Feed** — Latest news flashes and in-depth articles, with importance filtering
- **Per-Token Content** — Key events, news, and community discussion for a specific token
- **Per-Token KOL Views** — Twitter KOL opinions and analysis on a specific token
- **Daily Briefing Picks** — Curated daily content
- **Keyword Search** — Search articles, news flashes, and tweets across the platform with type and date filters
- **Intel Center** — Structured data channels: token unlocks, macro economics, listing/delisting, project events, price/volume anomalies, capital flow

5 Skills are built on top of these capabilities:

### 01 Followin Intel Center

One-stop query for market event data: token unlocks, macro economic data, listing/delisting announcements, project events, price/volume anomalies, and funding rates. Filter precisely by the dimension you care about — no need to scroll through the entire feed.

**How to ask:**
- `Any large unlocks this week?`
- `What tokens were recently listed on exchanges?`
- `Which tokens have abnormal funding rates?`
- `Intel center overview` — pulls the most important 1-2 items from each of the 6 channels

### 02 Breaking News Analysis

Paste a piece of crypto news and get an instant read on which tokens it affects, whether it's bullish or bearish, and how big the impact is. Built for snap judgment after seeing breaking news. No MCP data — pure AI analysis.

**How to ask:**
- Paste a news snippet, then say `analyze how this news affects tokens`
- `Is this bullish or bearish?`

### 03 Trending News & Topics

What is the market paying attention to right now? Pulls from trending topic ranks and hot feeds, cross-validates across sources, and highlights topics with multi-source resonance.

**How to ask:**
- `What's hot today?`
- `What is the market focused on?`
- `Any overnight bombshells?`
- `What's going on with ETH lately` — focus on a specific token or topic

### 04 Crypto Daily Brief

Generates a publish-ready daily crypto market briefing. Filters the most important 8-10 events from the past 12 hours using trending topics and daily picks — conversational, opinionated, gets you up to speed in 1 minute.

**How to ask:**
- `Give me a daily brief`
- `Crypto morning brief`
- `Daily`

> Want a macro/US stock morning brief? Say `macro morning brief` or `US stock daily` — that goes to a different Skill.

### 05 Token Buzz & Views

Pick a token and get its news flashes, in-depth articles, Twitter KOL views, and community discussion in one shot. Built for when you want a comprehensive look at what's been happening with a specific token.

**How to ask:**
- `Any news on BTC?`
- `What's going on with ETH lately?`
- `What is the SOL community discussing?` — single dimension only
- `HYPE related articles`

> Want to see how KOLs are trading a specific token? Say `how are KOLs viewing BTC` — that goes to the Strategy & Signal Skill.

---

## Premium MCP — Trading Strategy & Macro Analysis

The Premium MCP aggregates multiple professional data sources and provides the following capabilities:

- **Top Trader Live Positions** — Real-time position data from elite perpetual traders (direction, leverage, size)
- **On-Chain Whales** — On-chain verifiable whale and known-trader positions (entry, liquidation, exact size)
- **KOL Call Strategies** — Trading strategies publicly posted by KOLs (entry / target / stop)
- **Telegram Channel Aggregation** — Message aggregation from 70+ Telegram channels across 10 categories (macro, trading signals, live trading, etc.)
- **Crypto Real-Time Prices** — Batch USD spot prices for cryptocurrencies
- **Macroeconomic Data** — Fed economic database covering rates, inflation, employment, GDP, treasury yields, and hundreds of other series
- **Financial Market Data** — US equities / ETFs / indices / forex / commodities real-time quotes, financial statements (income / balance sheet / cash flow), earnings beat/miss, analyst estimates, key ratios, insider trading, economic calendar, treasury yields, gainers/losers, stock screener, and more
- **31 Financial News Sources** — Keyword search across major financial outlets like Reuters, Bloomberg, CNBC, WSJ, FT
- **Twitter Data** — User tweets, search, follow relationships, Spaces, etc.

8 Skills are built on top of these capabilities:

### 06 Trading Strategy & Signal

Three-source cross-validation: CEX trader live positions + Hyperliquid on-chain whales + KOL public calls. Core principle: real-money positions are always more credible than verbal calls.

**How to ask:**
- `Can I trade SOL?` — full three-source cross-validation
- `What opportunities are there now?`
- `How are KOLs viewing ETH?` — KOL calls only
- `What are the big traders doing?` — live positions only
- `What are whales building positions in today?`

### 07 TG Channel Intel

Pulls market intel from 70+ Telegram channels — clusters by topic, extracts viewpoints, identifies consensus and disagreement. Channels are quality-tiered (high / medium), with high-quality channel views shown first. Supports channels in Chinese, English, Korean, and Vietnamese — for example, `what are the Korean channels talking about today`.

**10 channel categories:** Macro Research, Market Structure, Project Research, Narrative Tracking, Trading Signals, Live Trading, On-Chain Data, Meme Hunting, Cross-Market, News Aggregation

**Auto-routing by user persona:**

| You are | How to ask | What you'll see |
| --- | --- | --- |
| Active trader | `what are trading channels saying` | Trading Signals, Live Trading, Market Structure |
| Macro-focused | `macro view on TG` | Macro Research, Cross-Market |
| News follower | `latest TG buzz` | News Aggregation, Narrative Tracking |
| Project researcher | `any projects worth looking at` | Project Research |
| On-chain watcher | `any on-chain action` | On-Chain Data |
| Meme player | `any new memes` | Meme Hunting |
| Not sure / all | `what's TG talking about` | All categories |

You can also focus on a specific ticker: `how is TG viewing BTC`

### 08 BTC Macro Dashboard

Based on global liquidity, monetary policy, market environment, crypto-native flows, and economic data, returns a 0-100 composite score for BTC's current macro environment. 50 is neutral, above 50 is bullish, below 50 is bearish.

> ⚠️ Heavy MCP usage: pulls multiple macro series + market quotes + economic calendar. Not recommended for high-frequency triggering.

**How to ask:**
- `BTC macro`
- `BTC macro dashboard`
- `How is BTC's macro environment?`

### 09 Gold Macro Dashboard

Based on real interest rates, monetary policy, dollar index, central bank gold purchases, and risk sentiment, returns a 0-100 composite score for gold's current macro environment.

> ⚠️ Heavy MCP usage: pulls multiple macro series + market quotes + web search. Not recommended for high-frequency triggering.

**How to ask:**
- `Gold macro`
- `Gold macro dashboard`
- `How is gold's macro environment?`

### 10 Macro Morning Brief

Daily macro & financial morning brief: full-curve treasury yields, VIX, oil, dollar, economic calendar, media headlines, gainers/losers — one report covers the full pre-open macro picture.

> ⚠️ Heavy MCP usage: aggregates multi-source market data + economic calendar + multiple news searches. Best used once per morning session.

**How to ask:**
- `Macro morning brief`
- `US stock daily`
- `morning brief`

### 11 US Stock Earnings Report

Three-dimensional single-stock earnings analysis: income statement + EPS beat/miss + analyst estimates + key ratios + media sentiment + macro backdrop. Built for getting through a stock's latest quarter quickly during earnings season.

> ⚠️ Heavy MCP usage: per stock pulls financial statements + analyst data + media coverage + macro backdrop. MCP call count is significant.

**How to ask:**
- `Help me look at AAPL earnings`
- `TSLA earnings`
- `NVDA earnings analysis`

### 12 Macro Analyzer

What sectors and ETFs does a macro indicator affect after release? Full-chain validation: FRED data trend → sector ETF actual performance → media interpretation. Built-in mapping for 20 common indicators.

**How to ask:**
- `CPI impact`
- `NFP analysis`
- `Rate impact`
- `Tariff analysis`
- `GDP analysis`

### 13 US Stock Divergence Scan

Batch scan of US stock market for divergences between price, insider trading, and media coverage. Four signal types:

- **Silent Buy** — Large insider buying with no media coverage
- **Sentiment Mismatch** — Price action and media sentiment moving in opposite directions
- **Unreported Drop** — Large-cap sharp drop with no coverage
- **Unreported Surge** — Notable rally with no attention

> ⚠️ Heavy MCP usage: per candidate ticker requires market-cap filter + media cross-validation. One of the highest MCP call counts. Not recommended for high-frequency triggering.

**How to ask:**
- `US stock divergence scan`
- `Any anomaly signals?`
- `US stock silent moves`

---

## Quick Reference

| I want to know... | Say |
|---|---|
| What happened in crypto today | `give me a daily brief` |
| What the market is focused on right now | `what's hot today` |
| What's going on with BTC / ETH / SOL | `any news on BTC` |
| What direction big traders & KOLs are taking | `strategy signal` or `can I trade SOL` |
| What TG channels are discussing | `what's TG talking about` |
| Any unlocks / listings this week | `any unlocks this week` |
| Impact of a piece of news | paste news + `analyze` |
| BTC macro environment score | `BTC macro` |
| Gold macro environment score | `gold macro` |
| Today's US stock / macro picture | `macro morning brief` |
| A specific stock's earnings | `help me look at AAPL earnings` |
| Impact of a CPI release | `CPI impact` |
| US stock anomaly signals | `US stock divergence scan` |
