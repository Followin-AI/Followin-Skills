# Changelog

All notable changes to Followin Skills are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Entries are dated; the 1.x version numbers below the fold belonged to the retired npm package.

## [Unreleased]

### Ideas
- On-chain data skill (Glassnode / CryptoQuant integration)
- Polymarket API integration to replace web search for FedWatch probabilities
- Deribit options data skill for implied expectations layer

---

## [2026-07-24] — `skills-community/` → `Community Skill/`

### Changed
- Bundle folders now named symmetrically: **`Base Skill/` + `Community Skill/`**, shared assets in `references/`. Future scenario bundles get their own top-level folder — one repo as the shelf, folders as the products (decided against a repo split: both bundles share the caveats SSOT, and split copies are how `skills-v2/` rotted).
- Install command in the community README is now `cp "Community Skill"/*.md ~/.claude/commands/` (folder name contains a space).

---

## [2026-07-24] — Directory layout: `.claude/` → `Base Skill/` + top-level `references/`

### Changed
- **`.claude/commands/` → `Base Skill/Skill/`** — the base bundle now lives in a visible, product-named folder instead of a hidden dotdir, mirroring `skills-community/`.
- **`.claude/references/` → top-level `references/`** — the caveats SSOT and post-style guide serve both bundles, so shared assets moved out from under any single bundle's folder.
- Install source path is now `cp "Base Skill/Skill"/*.md ~/.claude/commands/` (note the quotes — the folder name contains a space). The target stays `~/.claude/commands/`.
- All repo-internal path references swept (READMEs, skill authority pointers, community README, 样张集, caveats header). `~/.claude/…` consumer-install paths are untouched.

### Note
- Cloning the repo and opening it in Claude Code **no longer auto-loads the skills** — `.claude/commands/` was Claude Code's convention path for project-local commands. Copy the files into your own `~/.claude/commands/` (or your project's `.claude/commands/`) as the README describes.

---

## [2026-07-24] — Remove Macro Analyzer (07); flagship count 7 → 6

### Removed
- **Root slimmed: `package.json` and `.mcp.json.example` deleted.** package.json had no function left after the installer retirement (no bin/scripts/deps; `private: true`) — its one remaining job, the MIT declaration, moved to a proper `LICENSE` file. The example file was a third copy of the 10-line MCP config both READMEs carry inline. Installer-era changelog entries (1.0.0–1.6.0, ~215 lines) collapsed into a stub pointing at git history; Node block dropped from `.gitignore`.
- **`07_macro-analyzer` deleted** — same criterion that removed Breaking News: its analysis layer (indicator → sector impact) is model-native reasoning. What made it look skill-worthy was the FRED series_id translation dictionary it hosted — but that is reference data, not workflow, and the caveats SSOT (red line 3) already pointed at it from outside the skill.

### Changed
- **Terminology: the individual-trader bundle is now 基础 Skill / Base skills** (was 旗舰 / Flagship) in both READMEs. Historical changelog entries keep the old term.
- **The 21-entry 中英文 → FRED series_id dictionary moved to the caveats SSOT as Appendix A**, with two dangerous entries corrected in transit: `BAMLH0A0HYM2` (credit spread) marked unusable per B-33 — a direct keywords query silently returns M2SL instead — and `CLUSD` flagged 402 per N-11 with `BZUSD`/`USO` as the working alternatives. The old table listed both with no warning.
- Red line 3 now points to Appendix A; `02`/`03` intent-routing rows that sent macro-impact queries to `macro-analyzer` now state there is no dedicated skill — the model calls `metrics`+`news` directly.

### Fixed
- **`04_btc-macro-dashboard` carried a v2-era row** telling readers to query FRED with natural language (`metrics(query="<指标中文或英文>")` / "不再维护 series_id 映射") — contradicting red line 3, the skill's own execution steps, and its own anti-pattern demo at line 181. Now uses the keywords form.
- **Stale renumbering leftovers the previous sweep missed** (`转 08_BTC宏观看盘` / `09_黄金监控看盘` inside 07's routing table — moot after deletion; `-v2` command headings in 01/02/03/06).
- **Dangling v1-skill references in frontmatter descriptions**: 02 routed "今天有哪些财报" to 情报中心 and 03 routed "有什么异常" to 热点舆情/代币舆情聚合 — all three were v1 skills deleted in `bd978a6`. 03 additionally contradicted itself by claiming "有什么异常" in its ✅-routing row while its description excluded it; resolved in favor of exclusion.

---

## [2026-07-24] — Flagship skills renumbered 01–07 ⚠️ breaking

### Removed
- **`02_breaking-news` (Breaking News Analysis) deleted.** It was the last skill with no MCP dependency — pure prompt-level analysis that the model does without a skill file.

### Changed
- **All flagship skills renumbered into recommended-onboarding order, and the `_v2` filename suffix dropped** (it no longer distinguished anything once `skills-v2/` was removed). Anyone who copied these into `~/.claude/commands/` should delete the old files before copying the new ones — otherwise both sets will be live and compete for the same triggers.

  | New | Old | Skill |
  |---|---|---|
  | `01_multi-agent-stock-analysis` | `14_…_v2` | Multi-Agent Stock Analysis |
  | `02_us-stock-earnings-report` | `11_…_v2` | US Stock Earnings Report |
  | `03_us-stock-divergence-scan` | `13_…_v2` | US Stock Divergence Scan |
  | `04_btc-macro-dashboard` | `08_…_v2` | BTC Macro Dashboard |
  | `05_gold-macro-dashboard` | `09_…_v2` | Gold Macro Dashboard |
  | `06_macro-morning-brief` | `10_…_v2` | Macro Morning Brief |
  | `07_macro-analyzer` | `12_…_v2` | Macro Analyzer |

- `.claude/references/14_agent-prompts.md` → `01_agent-prompts.md`, matching its owning skill.
- Cross-references swept: skill-to-skill citations, the caveats SSOT header and its B-33 rollback instructions, and both READMEs' skill tables and routing guides.

### Fixed
- **Dangling route to a deleted skill.** `06_macro-morning-brief` sent crypto-daily requests to "Skill 04 crypto-daily-brief" — that skill was deleted back in `bd978a6`, and after renumbering `04` is the BTC Macro Dashboard, so the pointer had become actively wrong. It now states plainly that this repo has no crypto-daily skill.
- **Duplicate caveat entries removed.** N-22/N-23/N-24, added earlier the same day, restated N-4 (signal fanout quota), N-5 (kol_call `source_url` splitting), and N-8 (array-param serialization) — all already registered on 2026-07-22. The 2026-07-24 re-verifications were merged into the original entries instead, including a correction: N-4's "fanout 全 4 类" returned only three categories in this run because `trader_position` had no rows for the ticker, so consumers must key off what actually comes back rather than assuming all four.

---

## [2026-07-24] — Repository cleanup

### Removed
- **npm installer retired.** Deleted `bin/cli.js` and the `bin` / `postinstall` / `files` /
  `publishConfig` fields from `package.json`; the package is now marked `private`. Setup moved to
  [followin.io/en/mcp](https://followin.io/en/mcp). The published `@followin/skills@1.6.0` is
  unaffected but is no longer the recommended install path.
- **`skills-v2/` deleted.** It was a stale duplicate of `.claude/commands/` carrying instructions
  that later testing disproved — notably `metrics(query=…)` for FRED series (a confirmed semantic
  trap) and a live `BAMLH0A0HYM2` call that silently returns M2SL instead (B-33). `.claude/commands/`
  is now the single authoritative copy.
- **`mcp-testing/` deleted** — abandoned scaffold: 11 personas defined, 2 run reports, 9 empty
  directories, last touched 2026-05-27.
- **`docs/superpowers/` deleted** — internal plans, specs, and regression logs, not intended as
  public documentation.
- **`USER_GUIDE.md` deleted** — merged into `README.md` / `README.zh-CN.md`. Its pricing table had
  drifted from the current credit-based model; the READMEs now link to the official pricing page
  rather than restating numbers that go stale.

### Fixed
- **READMEs rewritten to match the actual inventory.** Both language versions claimed 13 skills and
  documented six (01, 03, 04, 05, 06, 07) that were deleted back in `bd978a6`, while omitting skill
  14 entirely. They now document the 8 skills that exist, plus the 6-module community bundle.
- **Stale "Technical Notes" removed** — documented the v1 MCP surface (`finance_tool_quote`,
  `fred_get_series`, `search_finance_news`, …), none of which exists on the current
  `metrics` / `news` / `signal` / `twitter` / `subscription` toolset.
- **`.mcp.json.example` updated** to the single merged `followin` server at
  `https://mcp.followin.io/v2/sse`, replacing the retired two-server `followin-mcp` + `premium-mcp`
  layout with API keys in the query string.

---

## 1.0.0 – 1.6.0 (2026-03-23 → 2026-04-15) — npm installer era

Seven releases of the retired `@followin/skills` installer (multi-client setup presets,
MCP auto-config, install-layout changes). Removed from this file along with the installer —
the full entries remain in git history:

```bash
git log --follow -p -- CHANGELOG.md
```
