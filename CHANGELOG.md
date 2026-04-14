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

## [1.2.0] - 2026-04-14

One-command install. `npx @followin/skills setup` now copies the skill files **and** writes the MCP server config in a single step — users only need to paste their Followin API key when prompted.

### Added
- **`setup` command** — one-stop install: copies skill files, prompts for the API key (hidden TTY input), merges `followin-mcp` + `premium-mcp` into the client's MCP config without clobbering existing entries, and validates the connection
- **`configure` command** — MCP config only (skip the skill-file copy)
- **`--api-key, -k KEY`** flag and **`FOLLOWIN_API_KEY`** env var for non-interactive installs (CI, dotfile bootstraps)
- **`--no-validate`** flag to skip the post-config connection check
- **`--no-skills` / `--no-mcp`** flags for `setup` to run only one half
- **New client presets** with auto MCP config: `claude-desktop`, `cursor`, `windsurf` — each writes to the correct platform-specific config path
- Connection validator using Node's built-in `https` module (6s timeout) — no extra dependencies
- Plaintext API key files are written with `chmod 600` (owner-only)

### Changed
- README quickstart now leads with `npx @followin/skills setup` as the recommended one-command install; manual install / configure are demoted to an "advanced" subsection
- `clients` command now shows which features (`skills` / `mcp`) each preset supports and the exact paths it will write
- CLI help output updated with the new commands and flags

---

## [1.1.2] - 2026-04-14

### Changed
- README: simplify MCP server table — drop the parenthetical capability descriptions next to the server names

---

## [1.1.1] - 2026-04-14

### Changed
- README: publish the public MCP server URLs (`mcp.followin.io`, `premium-mcp.followin.io`) directly so users only need an API key — no more "contact the team for URLs"
- README: add a copy-paste-ready JSON config snippet that works across Claude Code, Claude Desktop, Cursor, Windsurf, and Cline

---

## [1.1.0] - 2026-04-14

Multi-platform install support. The npm package is now useful beyond Claude Code: install to OpenCode/OpenClaw with a preset, to any directory with `--target`, or get the source path with `path` to adapt skills for Cursor/Windsurf/Cline/Continue.dev manually.

### Added
- `--client` flag on `install` / `uninstall` with presets: `claude-code` (default), `claude-code-project`, `opencode`
- `--target DIR` flag for explicit target directory (any path on any OS)
- `path` command — prints the bundled skill source dir, useful for `cp $(npx @followin/skills path)/*.md ...` workflows
- `clients` command — lists all available `--client` presets
- Multi-platform Setup section in README covering Claude Code, Claude Desktop, Cursor, Windsurf, Cline, Continue.dev, OpenCode, OpenClaw
- Better CLI help output and error messages

### Changed
- README restructured: skill install and MCP setup are now separate steps with a clear "what's portable" preamble
- Default install destination still `~/.claude/commands/`, behavior unchanged for existing users

---

## [1.0.0] - 2026-04-13

First stable public release. 13 production-ready skills covering crypto trading, macro analysis, and US stock intelligence, with full bilingual (Chinese / English) support. Published to npm as `@followin/skills`.

### Added
- **Bilingual trigger support** — all 13 skills accept both Chinese and English trigger phrases (e.g., `BTC macro` = `BTC宏观`)
- **npm package distribution** — install via `npx @followin/skills install`
- **Comprehensive Skill User Guide** — README rewritten as a bilingual reference doc
- **Skill Routing Guide** — clarifies how similar-sounding requests route to different skills
- **Quick Reference table** — side-by-side EN / CN trigger phrases for all skills
- **Scoring layer details** for Skill 08 (BTC Macro) and Skill 09 (Gold Macro) — 4/5-layer weights and contradiction detection
- **Indicator mapping table** for Skill 12 (Macro Analyzer) — 7 major indicators with FRED series / bullish sectors / bearish sectors / key ETFs
- **Signal threshold table** for Skill 13 (Divergence Scan) — exact market cap, move size, and article count thresholds
- **Technical Notes** section documenting confirmed MCP tool behaviors (e.g., `^VIX` cannot be batched, `DXUSD` needs batch endpoint, FRED `sort_order` requirement)

### Changed
- `not_trigger` fields expanded with English equivalents to prevent routing collisions
- Repository moved from `Apatheticco/Followin-crypto-skills` to `Followin-AI/Followin-Skills`

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
