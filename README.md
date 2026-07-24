# Followin Skills

**English** | [简体中文](./README.zh-CN.md)

> **Setup has moved** — the official way to connect Followin MCP is now **[followin.io/en/mcp](https://followin.io/en/mcp)** (API key on signup, ~5 minute setup, docs [here](https://followin.io/en/mcp/docs)). The npm installer that used to live in this repo is retired; this repo is now the skill files themselves.

AI agent skills for crypto trading, macro analysis, and US stock intelligence — powered by **Followin MCP**.

Skills trigger in both **Chinese and English**, and answer in whichever language you ask in.

---

## What's in here

| Bundle | Files | For |
|---|---|---|
| **[`.claude/commands/`](./.claude/commands/)** | 8 skills | Individual traders / analysts — macro dashboards, earnings, divergence scans, multi-agent analysis |
| **[`skills-community/`](./skills-community/)** | 6 skills | Community operators — ready-to-post briefs, weeklies, hot-takes for a retail US-stock community (Traditional Chinese output) |
| **[`.claude/references/`](./.claude/references/)** | 4 files | Shared single-source-of-truth: official routing primer, MCP call red-lines, agent prompts, post style |

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

Restart your client after editing. See [`.mcp.json.example`](./.mcp.json.example) for a project-local template.

**3. Install the skill files** (optional) — copy what you want into your client's command directory:

```bash
cp .claude/commands/*.md ~/.claude/commands/
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
- **Structured broker research (研报) goes through `metrics`, not `news`.** `news(sources=["research"])` is for raw research-source *article* discovery; report cards, target prices, and thesis/catalyst fields come from `metrics(categories=["fundamentals"])`.
- **Omitting `categories` on `signal()` fans out** to insider trading + 13F institutional + KOL calls for a single quota unit — cheaper than three filtered calls returning the same data.

Full call red-lines and the known-issues register live in [`.claude/references/followin-mcp-caveats.md`](./.claude/references/followin-mcp-caveats.md).

---

## Flagship skills (8)

| # | Skill | Ask it | MCP tools |
|---|---|---|---|
| **02** | [Breaking News Analysis](./.claude/commands/02_breaking-news.md) | Paste a news snippet + `Analyze this` | none (web search optional) |
| **08** | [BTC Macro Dashboard](./.claude/commands/08_btc-macro-dashboard_v2.md) | `BTC macro` · `BTC 宏观` | `metrics` |
| **09** | [Gold Macro Dashboard](./.claude/commands/09_gold-macro-dashboard_v2.md) | `Gold macro` · `黄金宏观` | `metrics` |
| **10** | [Macro Morning Brief](./.claude/commands/10_macro-morning-brief_v2.md) | `Morning brief` · `宏观早报` | `metrics` `news` |
| **11** | [US Stock Earnings Report](./.claude/commands/11_us-stock-earnings-report_v2.md) | `AAPL earnings` · `AAPL 财报` | `metrics` `news` |
| **12** | [Macro Analyzer](./.claude/commands/12_macro-analyzer_v2.md) | `CPI impact` · `CPI 影响` | `metrics` `news` |
| **13** | [US Stock Divergence Scan](./.claude/commands/13_us-stock-divergence-scan_v2.md) | `Divergence scan` · `美股背离扫描` | `metrics` `news` `signal` |
| **14** | [Multi-Agent Stock Analysis](./.claude/commands/14_multi-agent-stock-analysis_v2.md) | `Should I buy NVDA` · `全面分析 NVDA` | `metrics` `news` `signal` |

### 02 — Breaking News Analysis

Paste a crypto headline or article; get which tokens are affected, bullish or bearish, how strong, and for how long. Short input gets a flash call; long input or an explicit ask gets the full causal chain and second-order effects. Every call includes the counter-argument — what would invalidate it. No MCP dependency.

### 08 / 09 — BTC & Gold Macro Dashboards

Score the current macro environment 0–100 with a layered breakdown, so "how's the backdrop" gets a number instead of a vibe. Both pull FRED series and market snapshots through `metrics`.

### 10 — Macro Morning Brief

Daily macro/US-stock briefing aggregating three sources: macro data, news, and unusual moves. Takes an optional `watchlist`. (This is the macro/equities brief — not a crypto daily.)

### 11 — US Stock Earnings Report

Three-dimensional single-stock earnings review: financial Beat/Miss + media sentiment + macro backdrop. Requires a specific ticker or company name.

### 12 — Macro Analyzer

Full chain from an indicator move to sector impact. Needs both an indicator *and* an impact/interpretation intent — `CPI is out, what does it mean for the market` routes here; `what is CPI` does not.

### 13 — US Stock Divergence Scan

Finds inconsistencies between price, insider trading, and media coverage — the silent movers. Takes `scope` and `days`.

### 14 — Multi-Agent Stock Analysis

19 virtual analysts (8 legendary investors + 5 modern masters + 6 quant analysts) score independently, a risk manager constrains position size, and a portfolio manager makes the call — 21 agents total. Modeled on the ai-hedge-fund architecture. Analyst personas live in [`.claude/references/14_agent-prompts.md`](./.claude/references/14_agent-prompts.md).

---

## Community bundle (6)

A separate bundle for **community operators** running a US-stock community for beginners. Output is ready-to-paste Traditional Chinese posts. Full operator handbook — module index, weekly cadence, quota budget, pinned-post templates — in **[`skills-community/README.md`](./skills-community/README.md)**.

| # | Module | Output |
|---|---|---|
| **c1** | Daily Brief | Morning report · pre-open preview · intraday refresh |
| **c2** | Weekly | Last week's expectations vs. reality + this week's calendar |
| **c3** | Research Hot | Weekly research-report leaderboard + deep-dive notes |
| **c4** | Social Pulse | Sentiment × real positions × insiders thermometer, or market-wide signal roundup |
| **c5** | Hot Take | Event scan menu + 300–500 word flash post + earnings quick-read |
| **c6** | Ticker Check | Internal triage memo — is this ticker worth writing about? *(not for posting)* |

---

## Routing

Similar-sounding requests go to different skills:

| You say | Routes to | Why |
|---|---|---|
| `Morning brief` / `宏观早报` | 10 Macro Morning Brief | Macro/US-stock daily briefing |
| `CPI impact` / `CPI 影响` | 12 Macro Analyzer | A specific indicator + impact intent |
| `BTC macro` / `BTC 宏观` | 08 BTC Dashboard | Asset-specific macro score |
| `Divergence scan` / `背离扫描` | 13 Divergence Scan | Price/media/insider inconsistency |
| `AAPL earnings` / `AAPL 财报` | 11 Earnings Report | Named ticker + earnings |
| `Should I buy NVDA` / `NVDA 值不值得买` | 14 Multi-Agent | Named ticker + buy/sell decision |

Each skill's frontmatter carries explicit `trigger` and `not_trigger` lists — that's what keeps neighbours from stealing each other's queries.

---

## Maintenance discipline

`.claude/references/followin-mcp-caveats.md` is the **single source of truth** for MCP call red-lines and known upstream issues. Skills mirror the relevant caveats inline; **on conflict, the reference file wins.**

When MCP behavior changes: edit the reference file first, then sweep the inline mirrors in the affected skills. The register also records the rollback action for each issue, so workarounds can be removed once upstream ships a fix.

---

## Pricing & support

Plans, credit allowances, and rate limits: **[followin.io/en/mcp](https://followin.io/en/mcp)** · docs at [followin.io/en/mcp/docs](https://followin.io/en/mcp/docs).

Bugs and feature requests: [GitHub Issues](https://github.com/Followin-AI/Followin-Skills/issues).

MIT licensed.
