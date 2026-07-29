# Changelog

All notable changes to Followin Skills are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Entries are dated; the 1.x version numbers below the fold belonged to the retired npm package.
## 2026-07-29 — 新增独立 Skill：美股盘前自选追踪

- **新增 [`Premarket Tracker/`](./Premarket%20Tracker/premarket-watchlist-automation.md)**：
  根据自选股、持仓、时区与时间创建或更新盘前周期任务；无自动化能力时降级为即时报告。
- 报告固定覆盖市场背景、单票异动/催化、持仓对应计划、组合相关性风险、来源与刷新条件。
- 对齐 Followin 当前工具路由：结构化行情/研报走 `metrics`，一般社媒热度走 `news(twitter)`，
  `twitter` 只处理命名账号/指定推文，`signal` 省略 categories 做 fanout，`subscription` 明确为拉取式未读箱。
- 新增盘前数据边界：美东 04:00 前不把最近收盘或实时快照称为真实盘前成交；休市日明确标注。

## 2026-07-29 — 新增 `Research Signal/`：研报信号三件套

- **新增 [`Research Signal/`](./Research%20Signal/)**（3 个 Skill，独立目录）：
  **r1 跨源印证信号卡**（研报候选 × 共识/市场/KOL 与内部人/基本面四维对撞，3 额度，输出校准读法不给买卖建议）、
  **r2 口径审计器**（只审结论的地基：基准是谁 / 口径边界 / 自陈偏差，可复用 r1 返回 0 额度）、
  **r3 催化剂时间线**（`detail.catalysts[].time_std` 归一后按精度分桶，补 N-22 财报日历判废留下的前瞻腿缺口）。
- **⚠️ 明确不做研报扫描器**，理由是数据可见性而非实现难度。库内四族信号（错位/时钟/信念/水分）建立在状态层全量折叠之上，
  **实测只有水分族（TP 离散）能干净地搬到 MCP 侧**，已并入 r1 当检查项；错位族与信念族因只有 3–5 家可见而不成立。
  （停覆信号最初判为"MCP 无对应字段"，**同日第二轮实测推翻**——见下方 N-43。）
- **caveats 登记表新增 N-37 ~ N-41 共 5 条**（含 request_id 与复现方式）：
  研报榜 `time_range` 完全无效（24h/3d/7d 逐字相同，实为全量累计榜）、钻取硬顶 `report_limit=10` 且 `limit`/`time_range` 双双失效、
  榜单 `net_direction` 被连带污染不可当方向共识、`signal()` 的 kol_call 可能整个缺失目标 ticker 自己的行（须回读 `content`）、
  `catalysts[].time_std.sort` 格式 ≥6 种且含 `"9999"` 哨兵。
- **⚠️ 顺带发现一处对外表述错误**：`Community Skill/c3_research-hot` 把研报榜称为「本週研報熱點 / 過去 7 天」，
  而该榜实为建库以来累计（N-37）。**c3 文案待修，本次未改动**。
- **正面发现（省额度）**：`metrics(query="<T> analyst ratings price target")` 一次调用即返回
  `consensus_price` + `analyst_grades` + `beat_miss` + `eps_trend` + `next_earnings_estimate` + `valuation_block` + `market.snapshot`，
  跨源印证的维度 1 + 维度 4 + 价格腿一次拿全。

### 同日第二轮：端到端实跑（INTC / GOOGL / F）修 6 个规格缺陷

把三支 Skill 的客户端规格**写成脚本对真数据实跑**，并刻意换标的（NVDA 是写规格时的样本，自测等于过拟合）。暴露并修正：

- **N-42（新）**：N-3 的「机构+标题+日期」去重**去不掉「快评 + 完整版」**——GS 对 INTC 同日发两篇同 TP、标题不同的报告，5 家被读成 7 家。追加「同机构+同日+同 TP 强制合并」。
- **N-33 同季判据修正**：`beat_miss.date`（公布日）与 `latest_quarter.date`（财季结束日）**天然不等**，朴素比日期会把每个正常样本判成"不同季"，**作废掉本该生效的 N-29 GAAP 错位检测**。改用 N-34 的 `gap < 90 天`。INTC 实测 gap=26 天 → 检测生效，抓出 `epsActual 0.42`(非GAAP,+100%) vs `latest_quarter.eps −2.16`(GAAP 净亏 110 亿) 的反号。
- **N-41 改写**：初版按单标的（NVDA 20 条）写的 `time_std` 归一规则，换标的后**覆盖率仅 77%**。按三标的 **60 条**重写：`sort` **10 种形态**（新增 ISO datetime / `YYYY-QN` / `YYYY-FQN` / 开区间 / 语义后缀）、`type` **22 种取值**（不是 12 种）含三组同义异写。**最大的坑是精度降级**：初版只防 `type=year`，被 `type=quarter` 打穿——`sort="2026-09-30"` 被渲染成"9 月 30 日"，实为"Q3 末某时"，凭空造精确度。
- **N-43（新）**：`revision_summary.list_changes[]` **字段确实存在**，此前写"MCP 无此字段、停覆信号做不了"是**错误断言**。实测只见 `initiate`/`add`，未见停覆类 action → 改为「样本内未出现，机制上可能支持」。
- **N-44（新）**：`subject_reports` 数量**日间剧变**——N-19 记的「GOOGL subject=0」（07-23）在 **07-29 复测为 6**；同日 **F 才是 subject=0** 且只返回 3 篇。判定逻辑仍成立，**但举的例子已过期**。
- **r2 四轴分类不可规则化**：写成正则跑 INTC 7 篇**错 4 篇**（Bernstein "强是靠 mix/ASP 不是销量" 这条教科书级口径边界被判成 🟢）。改为 LLM 语义判断 + 校准样本库，正则降级为召回提示。
- **另两条**：`valuation_block.dcf` 亏损期给荒谬值（INTC `2.95` vs 现价 `86.57`，差 29 倍）且无失效标注 → 列入不可引用；`rating_action` 全 `reiterate` ≠ 无修正（INTC 大摩 75→84 +12%、伯恩斯坦 100→110 +10%），两者须分开读。
- **顺带**：r1 的水分族检查首次真触发——INTC TP 84–200 离散 **2.38x**，并抓出真多空对决（同日 HSBC Buy $200 vs 大摩 Equal-weight $84，后者低于当时股价 3%）。

### 同日第三轮：输出层加解读要求

原三支的输出模板偏字段陈列——r1 只有末尾的「净信号」算解读，r2/r3 基本是把 caveat 和时间桶排出来就完了。三支统一补两层：

- **【🔎 领读】置顶**（三支都加）：2–4 句判断，写在最前不是最后补。回答"最该停下看哪条、哪些看着显眼其实可忽略"。
- **r1**：每个数据块后强制配一句「所以」——对撞不是把四维读数并列，是指出**它们矛盾在哪、谁该让位于谁**。
- **r2 新增【🧩 交叉读法】**：只有把几篇放一起才看得出的东西。三问——地基强弱与结论激进程度是否倒挂（⚠️**最该警惕：目标价越高、地基越薄**）／几篇的 caveat 是否指向同一盲区（⇒"市场整体在盲区里定价"）／哪些结论跨过可疑地基还站得住。
- **r3 新增【🧩 分布读法】**：**催化剂的疏密与远近本身就是读数**。四问——近 90 天有无真检验点（近乎为零＝短期不由自身事件驱动，这是硬判断不是"没找到"）／重心在近处还是全堆远期／谁被多家独立点名（＝这批研报的公共押注）／已过期桶的兑现率。
- 三支硬要求各配一张 **❌复述 / ✅解读对照表**，例句全部取自 INTC 实跑的真句子。判别标准：**把数字换成别的数，这话还成立吗——成立是复述，不成立才是解读**。

**修正后已用同一脚本复验**：去重 INTC 7→6→**5 家**（N-42 生效）｜同季判据 INTC/NVDA gap=26/24 天 → 闸1 均正确生效｜催化剂归一 **77% → 97%**（58/60），精度降级拦下 8 条假精确日期。
⚠️ **连带修正一处自伤的数字**：r3 原写"只有 10% 精确到日"——那是坏归一器造成的假象（23% 被误扔进待锚定桶）。修好后真实分布为**日 40% / 月 17% / 季 17% / 半年 8% / 年 15% / 待锚定 3%**，README 与 Skill 正文均已改。「不是日历」的结论不变（仍有 60% 粗于日级）。

## 2026-07-29 — 新增独立 Skill：财报季超预期扫描

- **新增 [`Earnings Screener/`](./Earnings%20Screener/earnings-season-screener.md)**（根目录独立 Skill，不属于任何 bundle）：
  无需指定 ticker 的财报季发现器。异动榜 + 新闻反向捞双腿发现 → 四道业绩硬闸 → Top N 逐字稿深扫 →
  业绩闸与关键词闸叠加判定。含反向关键词减分与 GAAP 口径错位检测。
- **⚠️ 废弃市场级财报日历**：实测其等效 `ORDER BY date ASC, symbol ASC LIMIT 50` 且 `limit` 入参不被尊重，
  按字母序截断导致 GOOGL/MSFT/NVDA/TSLA 在密集日必然出局；客户端五种杠杆全部无效。
  受影响的 `Base Skill/02`、`Community Skill/c1`、`c2` 已改为「关注池 + `next_earnings_estimate` 核实」，
  并写入对外发布铁律：只能写「我们盯的这几家」，严禁写「今日/本周财报一览」。
- **caveats 登记表新增 N-22 ~ N-36 共 15 条**，另作废 N-2、结案 N-11、强化 N-28。
  其中多条修正了此前的错误定性（如 N-23 从"批量截断"拆分为"截断 + 上游字典缺失"两种独立故障）。
- **原油符号全面改写**：`CLUSD` 返 0 结果、`BZUSD` 静默丢弃、`OIL` alias 返回 ETN，只剩 `USO` 可用。
- `mover` 榜从 `biggest gainers/losers` 改为 `most active stocks`（前者实测返回垃圾数据）。

## [Unreleased]

### Ideas
- On-chain data skill (Glassnode / CryptoQuant integration)
- Polymarket API integration to replace web search for FedWatch probabilities
- Deribit options data skill for implied expectations layer

---

## [2026-07-24] — `skills-community/` → `Community Skill/`

### Changed
- **`Base Skill/Skill/` flattened to `Base Skill/`** — the nested "Skill" folder was redundant; both bundles now keep their .md files at the top of their own folder. Install command: `cp "Base Skill"/*.md ~/.claude/commands/`.
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
