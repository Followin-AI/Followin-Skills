# Changelog

All notable changes to Followin Skills are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Ideas
- On-chain data skill (Glassnode / CryptoQuant integration)
- Polymarket API integration to replace web search for FedWatch probabilities
- Deribit options data skill for implied expectations layer

---

## [1.0.0] - 2026-04-14

First stable public release of `@followin/skills` — 13 production-ready Claude skills for crypto trading, macro analysis, and US stock intelligence, plus a one-command installer that auto-configures Followin MCP and Premium MCP across multiple AI clients.

> **Note on versioning**: an earlier set of 1.x.x iterations (1.0.0 → 1.3.0) was published on the same day while the installer story was being shaped. Those versions were unpublished from npm and consolidated into this single 1.0.0 release. The pre-1.0 history below (0.1.0 → 0.3.0) reflects the original skill-by-skill development.

### Skills (13)

**5 Followin MCP skills** — crypto news & sentiment:
- `01_followin-intel-center` — token unlocks / macro / listings / events / volume / funding
- `02_breaking-news` — news impact analysis (bull/bear + counter-argument)
- `03_trending-news-topics` — multi-platform hot topic resonance
- `04_crypto-daily-brief` — ready-to-publish daily crypto briefing
- `05_token-buzz-views` — per-token 4-dimension snapshot (news / articles / KOL / community)

**8 Premium MCP skills** — trading & macro:
- `06_trading-strategy-signal` — CEX traders + on-chain whales + KOL calls cross-validation
- `07_tg-channel-intel` — 70+ Telegram channels across 10 categories
- `08_btc-macro-dashboard` — 0-100 BTC macro score, 4 layers, 15 indicators
- `09_gold-macro-dashboard` — 0-100 gold macro score, 5 layers, 15 indicators
- `10_macro-morning-brief` — daily US pre-open macro briefing
- `11_us-stock-earnings-report` — single-stock earnings (Beat/Miss + media + macro)
- `12_macro-analyzer` — macro indicator impact analysis with 20+ built-in mappings
- `13_us-stock-divergence-scan` — price / insider / media divergence scanning

All skills support both **Chinese and English** triggers and output in the user's input language. `not_trigger` fields prevent routing collisions across similar-sounding queries.

### One-command installer

```bash
npx @followin/skills setup
```

Copies the 13 skill files, prompts for the Followin API key (hidden TTY input), merges `followin-mcp` + `premium-mcp` into the target client's MCP config (preserving existing entries), and validates the connection — all in one step.

**Supported clients:**

| Client | Skills | MCP auto-config |
|---|---|---|
| Claude Code (global) — default | ✅ `~/.claude/commands` | ✅ `~/.claude/settings.json` |
| Claude Code (project-local) | ✅ `<cwd>/.claude/commands` | ✅ `<cwd>/.mcp.json` |
| Cursor | ✅ `<cwd>/.cursor/rules/*.mdc` (auto-converted) | ✅ `~/.cursor/mcp.json` |
| Windsurf | ✅ `<cwd>/.windsurf/rules/*.md` (auto-converted) | ✅ `~/.codeium/windsurf/mcp_config.json` |
| Claude Desktop | — (no stable filesystem skill format yet) | ✅ `~/Library/Application Support/Claude/claude_desktop_config.json` (macOS) / `%APPDATA%\Claude\...` (Windows) |
| OpenCode / OpenClaw | ✅ `~/.config/opencode/command` | — |

For Cursor and Windsurf the CLI converts each Claude Code skill file on the fly into the target client's native rule format (Cursor `.mdc` with `description` + `alwaysApply: false`; Windsurf `.md` with `trigger: model_decision` + `description`). Frontmatter conversion uses JSON-encoded YAML scalars to handle Chinese punctuation, quotes, and special chars cleanly.

### CLI commands

- `setup` — one-stop install (skills + MCP + validation)
- `install` — copy skill files only
- `configure` — write MCP config only
- `uninstall` — remove bundled skills from a target dir
- `list` — show bundled skills
- `path` — print the source dir of bundled skill files (useful for `cp $(npx @followin/skills path)/*.md ~/wherever/`)
- `clients` — show all available client presets and the paths they write

### Flags

- `--client, -c NAME` — target client (default: `claude-code`)
- `--target, -t DIR` — override skill install dir
- `--api-key, -k KEY` — pass API key non-interactively (also via `FOLLOWIN_API_KEY` env var)
- `--no-validate` — skip the post-config connection check
- `--no-skills` / `--no-mcp` — `setup` half-flow toggles

### MCP servers

Both servers are SSE-based and hosted by Followin. **Public URLs:**
- Followin MCP: `https://mcp.followin.io/sse`
- Premium MCP: `https://premium-mcp.followin.io/sse`

The API key is sent both as `?api_key=` query param and `X-API-Key` header for cross-client compatibility (some MCP hosts strip query params, others strip headers). Configuration files containing the key are written with `chmod 600` (owner-only).

**Followin MCP** provides: trending topics, trending feed, token-level content, KOL opinions, daily digest, keyword search, intel center (6 structured data channels).

**Premium MCP** provides: top trader positions, on-chain whales, KOL call orders, TG channel aggregation (70+ channels), crypto realtime prices, FRED macro data, financial market data (US stocks / ETFs / forex / commodities / financials / earnings / insider trading / economic calendar / treasury yields), 31 financial media search, Twitter data.

### Documentation

- Comprehensive bilingual Skill User Guide in README
- Skill Routing Guide — how similar-sounding requests route to different skills
- Quick Reference table — side-by-side EN / CN trigger phrases
- Scoring layer details for Skill 08 (BTC Macro) and Skill 09 (Gold Macro)
- Indicator mapping table for Skill 12 (Macro Analyzer)
- Signal threshold table for Skill 13 (Divergence Scan)
- Technical Notes documenting confirmed MCP tool behaviors

### Distribution

- Published to npm as `@followin/skills` (scoped public package)
- Repository: `Followin-AI/Followin-Skills` on GitHub (moved from `Apatheticco/Followin-crypto-skills`)
- Zero runtime dependencies — pure Node.js (built-ins only)
- Requires Node.js 16+ — works on macOS, Linux, Windows

---

## [0.3.0] - 2026-04-10

### Added
- 4 new macro / US stock skills:
  - `10_macro-morning-brief` — daily US market pre-open report
  - `11_us-stock-earnings-report` — single-stock earnings analysis
  - `12_macro-analyzer` — macro indicator impact analysis
  - `13_us-stock-divergence-scan` — price / insider / media divergence scanning

### Changed
- All skill names standardized to English (file names and display names)
- Skill file naming convention: `NN_skill-name.md` (numbered prefix)

---

## [0.2.0] - 2026-04-02

### Added
- `08_btc-macro-dashboard` — BTC macro environment 0-100 scoring
- `09_gold-macro-dashboard` — Gold macro environment 0-100 scoring

### Fixed
- KOL trading strategy routing — `KOL怎么看BTC` now correctly routes to Trading Strategy skill instead of Token Buzz

---

## [0.1.0] - 2026-03-23

### Added
- Initial 7 crypto trading & intelligence skills:
  - `01_followin-intel-center` — Intel center queries (unlocks / macro / listings / events / volume / funding)
  - `02_breaking-news` — News impact analysis
  - `03_trending-news-topics` — Market hot topic detection
  - `04_crypto-daily-brief` — Daily crypto market briefing
  - `05_token-buzz-views` — Per-token news / KOL / community aggregation
  - `06_trading-strategy-signal` — Trader positions + whales + KOL cross-validation
  - `07_tg-channel-intel` — 70+ Telegram channels intelligence
- MCP server configuration for Followin MCP and Premium MCP
- Initial README with skill catalog

---

## Version Guidelines

**Pre-1.0 (0.x.x)** — the project was still evolving; APIs and skill lineup could shift between minor versions without formal deprecation. Any 0.x release should be treated as "use at your own risk for stability".

**1.0.0 and beyond** — stable release. The rules below apply:

**MAJOR (x.0.0)** — Breaking changes
- Removing a skill or renaming its trigger in a way that breaks existing user prompts
- Changing MCP tool dependencies in a way that requires re-configuration
- Restructuring the install path (e.g., moving files out of `.claude/commands/`)

**MINOR (1.x.0)** — Backward-compatible additions
- New skill added
- New trigger phrases added (English / synonyms)
- New sections or data dimensions in existing skills
- New MCP tool dependencies that don't break existing usage

**PATCH (1.0.x)** — Backward-compatible fixes
- Bug fixes in skill logic (wrong MCP params, parsing errors)
- Documentation corrections (typos, clarifications)
- Trigger phrase adjustments that don't remove existing phrases
