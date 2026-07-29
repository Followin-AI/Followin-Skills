# 设计说明 — 财报季超预期扫描

> **验证时点：2026-07-27 ~ 2026-07-29。** 本文记录的架构选型与实测依据均基于当时的 Followin MCP 行为。
> MCP 会变——Skill 正文顶部附了 5 条自查调用，隔一段时间再用请先跑一遍。

- **方法论出处**：散户选股四步法（财报季 → 挨个看业绩大增公司 → 扫「供不应求/高景气/超预期」关键词 → 2+3 叠加则重点关注）
- **Skill 本体**：[`earnings-season-screener.md`](./earnings-season-screener.md)
- **调用红线与已知上游问题**：[`../references/followin-mcp-caveats.md`](../references/followin-mcp-caveats.md)（N 系列登记表）
- **版本历史与每一版的实测反例**：见仓库根目录 [`CHANGELOG.md`](../CHANGELOG.md)

## 这份文档记什么

架构为什么长这样、什么方案被否决、验收标准是什么。**逐版缺陷清单不在这里**——那是 CHANGELOG 的职责，
两处记同一件事必然漂移。

一句话概括演进：初版设计把**市场级财报日历**作为发现腿①，实现前的探针实测直接否决了它（等效
`ORDER BY date ASC, symbol ASC LIMIT 50` 且不尊重 `limit`，GOOGL 这类票在密集日必然出局），
换成**异动榜 + 新闻反向捞**双腿。架构本质未变——仍是「双腿发现 → 业绩硬闸 → Top N 逐字稿深扫 → 双闸叠加判定」，
只是腿①换了数据源，而选择双腿混合方案的理由（覆盖面）因此得以保留。

---

## 1. 背景与目标

原始思路是 A 股语境的人肉流程：财报季逐份翻业绩大增公司的财报/交流纪要，找高景气表述。本 Skill 把它自动化为美股版一条龙扫描器，数据面全部走 Followin MCP。

**2026-07-27 实测结论**（本设计的事实基础）：

| 步骤 | MCP 能力 | 实测状态 |
|---|---|---|
| 财报日历 | `metrics` + `date_from/to`，过去日期 `epsActual/revenueActual` 回填 | ✅ 可用，但全球混排字母序、美股大票被埋（N-17），limit=100 实返 50 |
| 业绩大增 | `beat_miss` 块给 EPS/营收 surprise %（GOOGL 7/22 Q2 实测：营收 +2.8%，EPS +217% 被一次性损益扭曲） | ✅ 单股完整 |
| 关键词扫描 | **电话会完整逐字稿**随 fundamentals 一次调用返回（GOOGL 实测 ~56KB） | ✅ 全链路最强一环 |
| 新闻反向发现 | `news` 搜 "earnings beat raised guidance" **0 额度**，能捞出超预期报道（实测 Vodafone/AZN/SLB），混有印度/港股/加密噪音 | ✅ 可作发现层第二条腿 |
| 数组参数 | `keywords/categories/sources` 传数组被拒（N-8 未修复） | ⚠️ 全程走 query 串 |

**与现有 Skill 的边界**：Base Skill 02 是"点名 ticker 的单股财报分析"，明确不覆盖"泛问今天有哪些财报"；本 Skill 是无 ticker 的发现器，互补不抢词。

## 2. 定位与触发

- 一句话：扫过去 N 天（默认 7）已发布的美股财报，输出"业绩大增 × 电话会高景气关键词"叠加候选榜。
- 触发词：`财报季扫描`、`超预期扫描`、`earnings screener`、`谁业绩大增`、`本周财报超预期`
- not_trigger：点名 ticker 的财报分析（→ 02）、背离扫描（→ 03）、宏观早报（→ 06）
- 参数：`days`（回看天数，默认 7）、`top`（逐字稿深扫上限，默认 5）
- 运行模式：一条龙，单次触发跑完全流水线。**建议独立会话跑**（Top 5 逐字稿 ~250KB 上下文）。

## 3. 数据流水线（方案 C：双腿混合，已确认）

### Step 1 发现·腿①（日历硬筛，1 额度）

```
metrics(asset_type="tradfi", query="earnings calendar",
        date_from=<today - days>, date_to=<today>, limit=100)
```

客户端过滤：
- symbol 纯大写字母无后缀（正则 `^[A-Z]+$`），剔优先股 `-P` / 权证 `-WS`
- `epsActual` 或 `revenueActual` 非空（已发布）
- N-17 红线：名单可能不全，**如实标注**；对当周已知 mega-cap 财报用 `next_earnings_estimate.date` 抽查交叉验证

### Step 2 发现·腿②（新闻反向，0 额度）

三组固定 query 各一次（不传 `sources`、不传 `asset_type`——N-8 数组被拒 + 02 实测 news 带 tradfi 返 0）：

```
news(query="earnings beat raised guidance", time_range="<days>d", limit=10)
news(query="record quarterly revenue results", time_range="<days>d", limit=10)
news(query="earnings surprise stock surges", time_range="<days>d", limit=10)
```

从标题/正文抽美股 ticker（`NASDAQ:`/`NYSE:`/`$TICKER` 模式）；剔噪音：`.NS`/`.HK`/`.L` 后缀、A 股、加密内容。

### Step 3 合并去重（0 额度）

两腿并集 → 候选池（预期 8-15 个）。腿②发现但腿①没有的照收（这是对 N-17 的对冲）。

### Step 4 业绩硬闸验证（每候选 1 次，约 8-10 额度）

每候选：

```
metrics(asset_type="tradfi", query="<TICKER> 财报")   # N-14：中文意图词，避开 beat/miss 等撞 ticker 英文词
```

取 `beat_miss` 块。另对候选池批量拉行情快照（query 串 ≤6 个 ticker 一批，**调用后核对 `meta.filters_applied.keywords`，静默丢失的单独补调**——N-12）拿 marketCap 与财报日以来涨跌。

**闸门**：
- 营收 surprise ≥ +2%（主锚）
- EPS surprise ≥ +5%；若 EPS surprise > 100% 或与营收严重背离且无经营性解释 → 判为 GAAP 一次性扭曲，以营收为准并标注
- 市值 ≥ $2B
- N-15 红线：**财报当晚**的公司 `beat_miss` 仍是上一季数据 → 改用 `news` 原文验证并标注数据源降级

### Step 5 逐字稿深扫（Top N，≤5 额度）

幸存者按营收 surprise 降序取 Top N：

```
metrics(asset_type="tradfi", query="<TICKER> earnings call transcript")
```

Claude 全文扫关键词库（第 4 节），每命中记录：类别、原文摘录、发言人、语境（管理层主动陈述 vs 分析师问答被动确认）。

降级路径：逐字稿缺失（中小票可能没有）→ 改用 `news` 研报/媒体原文扫关键词，输出中标注"降级来源"。

### Step 6 终榜（0 额度）

按第 5 节口径打分输出。

**成本合计**：约 15-18 次额度/跑；上下文大头为 Top N 逐字稿。

## 4. 关键词库

| 类别（截图原词） | Transcript 检测表述 |
|---|---|
| 产品供不应求 | sold out · supply cannot meet demand · capacity constrained · allocation · backlog growing |
| 行业高景气度上行 | industry tailwinds · secular growth · up-cycle · structural demand |
| 市场超预期拓展 | expanding faster than expected · TAM expansion · new market traction |
| 新品上市持续超预期 | new product exceeded expectations · ramp ahead of schedule · strong adoption |
| 产品价格中枢持续上涨 | pricing power · price increases · ASP up · favorable pricing |
| 供给偏紧 | supply tight · lead times extended · constrained supply |
| 需求旺盛 | robust demand · record demand · demand outpacing supply |

**反向词（减分项，防确认偏误）**：pricing pressure · demand softening · inventory correction · guidance cut / lowered outlook

检测原则：语义匹配而非字面 grep——同义表述算命中，但必须能给出原文摘录；引用时保留发言人与语境。

## 5. 打分与判定（0-100）

### 业绩闸（40 分）

- 营收 surprise：≥+2% → 8 ｜ ≥+5% → 14 ｜ ≥+10% → 20
- EPS surprise：≥+5% → 8 ｜ ≥+15% → 14 ｜ ≥+30% → 20；判定为 GAAP 扭曲时该项得分 ÷2 并标注

### 关键词闸（40 分）

- 每命中一个类别 +5（7 类满 35），封顶 40
- 权重：管理层主动陈述 ×1.0，问答被动确认 ×0.6
- 命中带量化数字佐证：该类别 +1
- 反向词：每类别 −5，下限 0

### 盘面确认（20 分）

财报日至今涨幅：≥+5% → 20 ｜ +2~5% → 14 ｜ 0~+2% → 8 ｜ −2~0% → 4 ｜ <−2% → 0（并标注"可能未 price in，也可能市场看到了财报之外的东西"）

### 判定

- 业绩闸 ≥24 **且** 关键词闸 ≥20 → 🎯 重点关注（即截图第 4 步"满足 2+3"）
- 仅过单闸 → 👀 观察
- 双闸都不过 → 淘汰（不进终榜明细，计入统计）

## 6. 输出模板

```
## 🔍 财报季超预期扫描 — 过去 [N] 天（[date_from] ~ [date_to]）

候选池 [X] 个（日历腿 [a] + 新闻腿 [b]，去重后）→ 业绩硬闸幸存 [Y] 个 → 深扫 Top [N]

### 终榜
| # | Ticker | 公司 | 财报日 | 营收 Surprise | EPS Surprise | 关键词命中 | 盘面 | 总分 | 判定 |

### 🎯 [TICKER] — [公司名]（总分 XX）
业绩：营收 $XXB（+X.X% vs 预期）｜EPS $X.XX（+X.X%）[GAAP 扭曲标注]
关键词命中（[n]/7 类）：
- [类别]：「原文摘录」— [发言人]（[主动陈述/问答确认]）
一句话 thesis：[综合判断]

### 数据缺口
- [日历腿不全 / 未深扫候选 / 逐字稿降级 等如实列出]

> ⚠️ 本扫描是"值得进一步研究"的线索，不是投资建议。
```

## 7. 已知坑规避（caveats 内联镜像，冲突时以 references/followin-mcp-caveats.md 为准）

| # | 规避动作 |
|---|---|
| N-8 | 数组参数全走 query 串 |
| N-12 | 批量 query 串后核对 `meta.filters_applied.keywords`，缺失单独补调 |
| N-14 | query 用中文意图词（"财报"），禁 beat/miss/call 等撞 ticker 英文词；调用后核对解析结果 |
| N-15 | 财报当晚公司 beat_miss 滞后一季 → news 原文验证 + 标注 |
| N-17 | 日历漏美股大票 → 双腿对冲 + mega-cap 抽查 + 如实标注名单不全 |
| N-18/N-3 | 输出前按 symbol / 机构+标题+日期 去重 |
| N-21 | 研报/fundamentals 调用的 `default_fanout_fallback` warning 是误报，以 payload 为准不重试 |

## 8. 验收标准（原型转正前提）

财报季实跑 ≥1 次端到端，满足：

1. 候选池 ≥5 个美股标的，且当周 mega-cap 财报无缺席（抽查验证）
2. Top N 逐字稿全部拿到，或有明确降级标注
3. 终榜每个 🎯 标的都有可核对的原文摘录（类别 + 发言人）
4. 单次会话跑完不爆上下文
5. 额度消耗 ≤20 次/跑

转正动作：补双语 trigger/not_trigger、caveats 指针换仓库路径、README 路由表加行、与 02/03 的抢词测试。
