---
name: Research Cross-Source Signal Card (r1 — 研报跨源印证信号卡)
description: 单标的研报信号旗舰。把卖方研报的结论当「有偏候选」，再用 Followin 四维活数据（共识 / 市场 / KOL 与内部人 / 基本面）对撞印证，铸成一张校准后的信号卡。输出不是买卖建议，只回答三问：锚哪个价、背离什么性质、盯什么反向信号。必须点名标的才触发。
trigger: 研报信号、印证一下XX的研报、XX研报靠不靠谱、跨源印证、信号卡、研报校准、这个目标价能信吗、research signal、cross-source
not_trigger: 研报榜/本周研报（→ Community c3）、单纯问目标价（→ Base 02）、催化剂日历（→ r3）、只想看报告口径（→ r2）、财报季扫描（→ Earnings Screener）、背离扫描（→ Base 03）
mcp: mcp__followin__metrics, mcp__followin__signal, mcp__followin__news
args: ticker(必填), window(可选，默认 30d，仅用于客户端过滤报告日期)
---

# /r1-cross-source-signal-card $ARGUMENTS

**研报库单独不产信号，只产候选。信号是候选被跨源印证或证伪的那一刻才铸成的。**

> **版本**：v1.0 ｜ **实测验证于 2026-07-29**（NVDA 全链路实跑）
>
> ⚠️ 本文所有 ⚠️ 与阈值都是实测结果或明确标注的拍脑袋值，不是推断。MCP 行为会变。
> 通用红线见 [`references/followin-mcp-caveats.md`](../references/followin-mcp-caveats.md)，本文内联的是镜像，冲突以该文件为准。
>
> **隔一段时间再用，先花两分钟自查这 3 条**：
> ① `metrics(query="NVDA research reports", verbosity="detail", asset_type="tradfi")` → `report_limit` 仍是 10 = 未修（N-38）
> ② 同上调用传 `time_range="7d"` 与 `time_range="30d"`，`event_id` 逐个相同 = 未修（N-38）
> ③ `signal(query="NVDA", asset_type="tradfi")` → kol_call 里有没有 `symbol=="NVDA"` 的行；没有 = N-40 仍在

## 参数

| 参数 | 必填 | 默认 | 说明 |
|------|------|------|------|
| ticker | ✅ | — | 单个美股代码。**本 Skill 不做批量**——四维对撞每标的 3 额度，且需逐份读报告论点 |
| window | 否 | 30d | 报告新鲜度窗口，**纯客户端过滤**（服务端 `time_range` 对研报路径无效，见 N-37/N-38）|

## 为什么必须跨源

单篇卖方研报**系统性偏多**，所以它只是有偏候选。这解释了一个反直觉结论：**同一批 9 篇同机构研报不能自成信号**——一家之言构成的是「假共识」。真共识、真背离，只能从跨源对撞里来。

MCP 侧还额外叠了一层削弱：**每票最多看得到 10 篇、去重后常只剩 3–5 家机构**（N-38 + N-42；实测 NVDA 3 家、INTC 5 家、GOOGL 5 家）。所以本 Skill 的研报侧读数**天然是下界**，这一点必须写进每张信号卡。

## 意图路由

| 用户说的 | 走哪 |
|---------|------|
| 印证 XX 的研报、这个目标价能信吗、研报信号 | ✅ 本 Skill |
| 本周研报榜、谁被提得最多 | ❌ 转 `Community Skill/c3_research-hot`（⚠️ 并提醒它是累计榜不是周榜，N-37）|
| 这份报告哪里没说清、口径边界 | ❌ 转 [`r2_research-caveat-audit`](./r2_research-caveat-audit.md) |
| 接下来有什么催化剂 | ❌ 转 [`r3_catalyst-timeline`](./r3_catalyst-timeline.md) |
| XX 财报分析 | ❌ 转 `Base Skill/02_us-stock-earnings-report` |

---

## 执行流水线（4 步 · 3 额度）

🔒 全程美股：**除 `news()` 外所有调用必带 `asset_type="tradfi"`**（红线 1）
🔒 **数组参数全域被拒（N-8）**：`keywords`/`categories`/`sources` 一律走 query 串
🔒 **SSE 并发 ≤4**（红线 2）：本流水线 4 路可一批发，但步骤 1 的返回 ~70KB，建议 1 单发、2-4 并发

### 步骤 1 · 候选层：拉研报（1 额度）

```
metrics(query="<TICKER> research reports", verbosity="detail", asset_type="tradfi")
```

> ⚠️ **query 必须含研报意图词**（红线 12）。只放报告标题或"半导体/AI"这类话题词**不会路由到研报路径**，会静默掉进 CORE fundamentals 全家桶，且照常计 1 额度。
> ⚠️ **不要传 `time_range` / `limit`**（N-38）：两者均被忽略，传了只会让人误以为控住了窗口。新鲜度过滤在客户端用 `report_date` 做。
> ⚠️ **`meta.warnings` 会误报 `default_fanout_fallback`**（N-21）——**这是假阴性，不要据此重试**，重试白烧 1 额度。以 `results.fundamentals.research_reports` 是否存在为准。

**返回结构**：`subject_reports`（主题报告，核心研究对象就是这支股）+ `mention_reports`（提及报告，主题是别的，只是点了名）。**恒 10 篇上限**。

**拿到后必须做的四步清洗**，顺序不能反：

1. **机构名归一**（N-38）：`"Morgan Stanley"` 与 `"Morgan Stanley & Co. LLC"` 是同一家。同理 `"BofA Securities"` / `"B of A Securities"`、`"Citi Research"` / `"Citigroup"`。**不归一直接去重，同一家会被算成两家，虚增覆盖度。**
2. **按「机构 + 标题 + 日期」去重**（N-3）：同一份报告可双 `event_id` 重复入库。实测 NVDA 6 条 subject 去重后**只剩 3 条**。
3. ⚠️ **再去一次「快评 + 完整版」重复**（N-42，2026-07-29 实测新增）：**N-3 那条去不掉它**——标题不同所以三元组不同，但实质是同一份研究。
   **判据：同机构 + 同日 + 同 TP，即使标题不同也须合并**（保留信息更全的一篇）。
   实测 INTC：Goldman Sachs 2026-07-23 两篇同为 TP 150——《…First Take: Strong quarter across the board…》与《…Strong quarter across the board, with margin upside…》，前者是盘后快评、后者是完整版。不合并会把 GS 算成两家。
   **跨日变体也要看**：Citi 07-23《2Q26 Earnings Quick Take》与 07-24《Transformation in Progress》同为 TP 130，是同一事件的快评+深度。跨日时不强制合并，但**按机构取最新一篇**即可自然消解。
4. **按 `report_date` 过滤到 window 内**，并记下被滤掉几篇。
5. **分层**：只有 `subject_reports` 能用于评级/目标价统计（N-19）。`mention_reports` 只能当叙事背景，**其 `mention_context.rationale` 可引用为"某行业报告里被点名的理由"，但绝不能标成"机构评级"**。
   ⚠️ **`subject_reports=0` 是真实分支，必须处理**：实测 F(Ford) 返回 `report_returned_count=3`，**全部是 mention，subject 为 0**。
   此时**不出信号卡**——候选层不成立。降级输出："本标的近期无专题研究，只在 N 份行业报告里被点名"，附 `mention_context.rationale`。
   ⚠️ 但 **N-19 的「GOOGL subject=0」是时点现象不是恒定特性**：2026-07-23 实测 GOOGL subject=0，**2026-07-29 复测 subject=6**（Barclays/MS/Bernstein/Citi×2/GS）。**每次当场看返回，不要照抄历史结论。**

**候选强度读数**（全部标成下界）：

| 读数 | 取自 | 表述铁律 |
|---|---|---|
| 可见机构数 | 去重后 `subject_reports` 的 institution 基数 | 写"**可见 N 家**"，绝不写"N 家" |
| 目标价区间 | `target_price.new` 集合 | 必带家数；单均值禁用 |
| **TP 离散比** | `max(TP) / min(TP)` | **>1.8x 告警**（水分族阈值，沿用库内口径）|
| 评级动作分布 | `rating_action` 计数 | 区分 `reiterate`（维持）与真上调/下调 |
| 修正明细 | `revision_summary.by_name[]` | 带 `old_target_price` → `new_target_price` + `change_pct` 才算真修正 |

> ⚠️ **`rating_current` 也不归一**：实测同时出现 `"Buy"` / `"BUY"` / `"Attractive"` / `"Overweight; Top Pick"`。映射成多/中/空三档再计数。
>
> ✅ **顺带白拿**：本步返回**自带 `market.snapshot` 实时行情**（含 price / marketCap / yearHigh / priceAvg50 / priceAvg200）。上行空间就地算，**不要再花额度查现价**。
>
> ✅ **顺带白拿**：`detail.catalysts[]` 里 `security` 字段**可以不等于查询 ticker**（N-41）——查 NVDA 会顺带拿到竞品 AMD 的事件日。这些交给 [r3](./r3_catalyst-timeline.md) 消费，本 Skill 只取与本标的相关的。

### 步骤 2 · 维度 1 + 维度 4 + 价格腿：一次拿全（1 额度）

```
metrics(query="<TICKER> analyst ratings price target", asset_type="tradfi")
```

**这一个调用同时返回**（2026-07-29 实测）：`consensus_price` + `analyst_grades`（20 行）+ `beat_miss` + `eps_trend` + `latest_quarter` + `next_earnings_estimate` + `valuation_block` + `market.snapshot`。

> ⚠️ **query 里不要加会撞 ticker 的英文词**（N-14）：`beat` / `miss` / `hold` / `buy` / `now` / `all` 都会被当成 ticker 抽取（实测 `BEAT` 撞上仙股 HeartBeam $0.55）。调用后核对 `meta.filters_applied.keywords` 只有目标 ticker。

**维度 1 · 共识对撞**——研报的目标价是不是全街最高的孤儿？

| 判据 | 阈值 | 说明 |
|---|---|---|
| 孤儿告警 | 研报 TP > `targetMedian × 1.3` **或** 研报 TP ≥ `targetHigh × 0.95` | ⚠️ **这两个阈值是拍的，未回测**。定 1.3 的唯一依据是 SNDK 历史案例（伯恩斯坦 $3000 vs 中位 $1585 = +78%，是公认的孤儿）。用的时候把原始百分比也写出来，别只给结论 |
| **⛔ 孤儿的反向检查** | **可见家数里 ≥2 家同时触发孤儿告警 → 判定反转** | **不是研报激进，是 `consensus_price` 中位滞后**。实测 INTC 5 家里 GS 150(+36%) 与 HSBC 200(+82%) 双双触发——而 INTC 刚 beat-and-raise、研报 TP 已上调，中位 110 还没跟上。此时应写"共识中位可能滞后于最新一轮修正"，**不是"两家都在放卫星"** |
| 家数 | 由 `analyst_grades` 按 `gradingCompany` 去重估算 | ⚠️ `consensus_price` **无家数字段**（N-16）。用 grades 估算时**必须注明是估算**。实测 INTC 20 条 grades / **17 家**，覆盖面远超研报侧的 5 家 |

**两个实测样例，读数完全相反**（都是 2026-07-29）：

- **NVDA｜共识内**：研报 TP = 288/300/350，全街中位 300、区间 218–500 → 最高的 BofA 350 仅高于中位 +16.7% 且远低于 targetHigh → **不是孤儿**。离散比 350/288 = **1.22x，无水分告警**。
- **INTC｜孤儿 + 水分双告警**：研报 TP = 84/110/130/150/200（5 家），全街中位 110、区间 60–200 → HSBC 200 **正好等于 targetHigh**（+82% vs 中位）、GS 150（+36%）→ 两家触发孤儿，按上面的反向检查判为**中位滞后**。
  离散比 200/84 = **2.38x 🚨 水分告警**——而且它顺带抓出**真多空对决**：同一天（07-24）HSBC Buy $200（对现价 +131%）vs Morgan Stanley Equal-weight $84（对现价 **−3%**）。这正是水分族"一条告警两个用途"的实例。

> ⚠️ **`rating_action` 全是 reiterate ≠ 没有修正——两者必须分开读。**
> 实测 INTC 5 家 `rating_action` **全是 reiterate**（评级没变），但 `revision_summary` 里有**两家真上调 TP**：Morgan Stanley 75→84（**+12%**）、Bernstein 100→110（**+10%**）。
> **"维持评级 + 上调目标价" = 信念增强**，只看 `rating_action` 会把它读成"什么都没发生"。
>
> ✅ **交叉验证的两种形态**：
> · NVDA：研报 6 篇全 `reiterate` × `analyst_grades` 20 行全 `maintain` → 两源一致指向**当前无人变心**。
> · INTC：研报全 `reiterate` × grades 19 maintain + **1 upgrade**（Goldman Sachs 2026-06-25 **Sell→Neutral**）→ grades 抓到了研报窗口外的真动作。**grades 的覆盖面和回溯深度都优于研报侧，别只看研报。**

**维度 4 · 基本面锚**——研报的假设比现实激进多少？

用 `beat_miss` + `eps_trend`，但**必须先过三道数据完整性闸，且顺序是 2 → 3 → 1**：

**闸 2 · null 伪装成极端真值（N-33）**：`revenueActual` 为 null 时服务端**把 null 当 0 做减法**，输出 `revenue_surprise_pct: -100`。**见到 −100 一律先当缺失查证**（真实世界营收归零几乎不可能）。

**闸 3 · 同季确认** ⚠️ **判据已于 2026-07-29 实测修正，别按直觉比日期**：

> `beat_miss.date` 是**财报公布日**，`latest_quarter.date` 是**财季结束日**——**这两个日期天然就不相等**。直接比日期会把每一个正常样本都判成"不同季"，从而**作废掉本该生效的闸 1**。
>
> **正确判据 = 复用 N-34 的 gap**：`gap = beat_miss.date − latest_quarter.date`，**gap < 90 天 = 同季**（90 天 = 一个完整财季，N-34 已用 42 样本验过这个分界）。
> 实测 INTC：公布日 2026-07-23、财季结束 2026-06-27 → **gap = 26 天 < 90 → 同季**，闸 1 生效。若按朴素比日期则判为不同季，闸 1 被误作废。
> gap ≥ 90 天才标"口径无法核对"并作废闸 1——跨季比对会让一盈一亏的相邻两季产生假阳性。

**闸 1 · GAAP 口径错位（N-29）**：`beat_miss.epsActual` 与 `latest_quarter.eps` **反号即判定口径错位**。
实测 INTC：`epsActual 0.42`（非 GAAP，对预期 **+100%**）与 `latest_quarter.eps −2.16` / `netIncome −$110.33 亿`（GAAP 巨亏）**同处一个返回，无任何字段标明口径**。
反号时强制标注"该超预期为非 GAAP 口径"，**营收 surprise（INTC +11.7%）才是可信主锚**。

> ⛔ **`valuation_block.dcf` 在亏损期会给出荒谬值，一律不引用**（2026-07-29 实测新增）。
> INTC：`dcf = 2.95` vs 现价 `86.57`——**相差 29 倍**。亏损公司的现金流折现模型直接崩掉，而返回里没有任何字段标注它失效。
> **自检**：`dcf` 偏离现价超过 5 倍即判为失效，不进任何输出。本 Skill 全程不使用该字段。

### 步骤 3 · 维度 3：谁在反着做（1 额度）

```
signal(query="<TICKER>", asset_type="tradfi")
```

> ✅ **不传 `categories` 会 fanout 全 4 类且只计 1 额度**（N-4，省额度利器）。但**不要假定四类恒在**——按实际返回的 key 判断（`trader_position` 常因该标的当时无持仓行而缺席）。

**三类各自的读法与陷阱**：

| 类别 | 读什么 | ⚠️ 陷阱 |
|---|---|---|
| `kol_call` | 方向 + `kol_info.tier`/`signal_level`（A 级 / L1-L2 才进人眼）| **N-40 死穴：目标 ticker 自己的行可能整个不在返回里。** 实测查 NVDA 返 8 行，**无一行 `symbol=="NVDA"`**，而原帖 `"BUY: - $NVDA …"` 明明把它列在首位。**必须回读 `content`，不能只信 `symbol` 字段**；再按 `source_url` 去重（N-5：一帖按提及裂多行）|
| `insider_trading` | 只认 `formType=="4"` 的 `P-Purchase`（买）与 `S-Sale`（卖）| `G-Gift` / `F-InKind` / `M-Exempt` **不是主动交易**（赠与、缴税代扣），剔除。`formType=="3"` 是首次申报，非交易。<br>**国会交易与公司内部人混在同一个 key 下**，按 `provenance` 分开（`congress` / `corporate_insider`）。<br>⚠️ `time_range` 被无视（N-6），客户端按 `transactionDate` 强制过滤。<br>⚠️ **同一份 PTR 披露会裂成多行**：实测 Cleo Fields 一份 PDF 出 3 行（`assetDescription` 为 `"NVIDIA Corporation"` / `"(1)"` / `"(2)"`，link 与日期完全相同）。**按 (姓名, 日期) 去重算人数，按行算笔数**，否则 1 位议员会被报成 3 位 |
| `institutional` | 绝对持仓 | ⛔ **申报季内禁引任何环比**（N-7）。实测 NVDA `investorsHolding` 2497 vs 上期 6234、`ownershipPercentChange −63.77%`、`putCallRatioChange +178%`——**全是回补未完成造成的残缺假信号**，不是真的机构跑了 |

**判定**：基本面/研报看多 × A 级 KOL 或内部人反向 → **分裂**，这是信号卡里最该顶出来的一行。

### 步骤 4 · 维度 2：背离是什么性质（0 额度）

```
news(query="<公司名> <TICKER>")
```

> ⚠️ **news 不传 `asset_type`**（红线 1 唯一例外：加了返 0 结果）。实体搜索 **0 额度**（N-1）。
> ⚠️ **query 三原则**（红线 5）：2-3 个核心名词、不中英混搭、不写"影响/解读/分析"等元词。
> ⚠️ **无匹配时不返空，返语义兜底的不相关内容**（红线 11）。更狠的是 **N-35 召回黑洞**：实测 `"Bloom Energy BE"` 与 `"Bloom Energy"` 返回**逐字相同的 12 条**兜底内容，0 条目标公司内容。**判别：返回里一条都不含目标公司名或 ticker 即判召回失败，记缺口不重试**（同 query 重试与换措辞均无效）。

价格用步骤 1 白拿的 `market.snapshot`，**不额外调用**。

**背离性质三分**（这一步是整张卡的关键，读法完全相反）：

| 性质 | 判据 | 读法 |
|---|---|---|
| **轮动错杀** | 跌但 news 里找不到针对该公司论点的负面事实；同板块同向 | 逻辑没被否，研报候选仍有效 |
| **逻辑被否** | news 里有直接击中研报核心论点的事实（订单取消、指引下修、竞品夺单）| 候选作废，别再锚研报 TP |
| **尚不可判** | news 召回失败，或有报道但与论点无关 | **诚实写"不可判"**，不要为了叙事完整硬圆 |

> 判"同板块同向"需要 peers 快照。如需要：`metrics(query="<T1> <T2> <T3> 行情", asset_type="tradfi")`，**每批 ≤5 只**（N-23a：传 8 只静默截断到 5），含 `CL`/`GC`/`BABA` 等影子代码时**按 4 只装**（N-36）。这会额外花 1 额度，非必需步骤。

---

## 输出：信号卡

固定五段。**净信号不是「买入/卖出」**——只回答三个问题。

```
📇 <TICKER> 研报跨源印证信号卡 · <日期>

【🔎 领读】（先写这段，不是最后补）
<2–4 句。这张卡最该停下来看的是哪一条、为什么；以及哪些看着显眼其实可忽略。
 必须是判断，不是概括。>

【候选层】研报怎么说
可见 N 家机构（去重后）｜目标价 $X–$Y（中位 $Z）｜较现价 $P 上行 A%–B%
离散比 R×（>1.8x 才告警）｜评级动作：n 维持 / n 上调 / n 下调
最新一篇：<机构> <日期>《<标题>》——<thesis 一句话>

【四维对撞】
① 共识：研报最高 TP $X vs 全街中位 $Z（+A%）、区间 $L–$H → 孤儿 / 不是孤儿
② 市场：现价 $P，日内 ±A% → 轮动错杀 / 逻辑被否 / 尚不可判（依据：<news 事实或"召回失败">）
③ KOL·内部人：<A 级 KOL 方向> ｜内部人 n 买 n 卖（仅 Form4 P/S）｜国会 n 人 n 笔
   → 一致 / 分裂 / 无数据
④ 基本面：营收超预期 A%（主锚）｜EPS 口径：GAAP 一致 / ⚠️非 GAAP 错位 ｜EPS 趋势 <方向>

【净信号】
· 锚哪个价：<共识中位还是研报 TP，为什么>
· 背离什么性质：<三分之一，附依据>
· 盯什么反向信号：<具体到可观测的事件/数据，不是"关注市场变化">

【口径声明】（强制，不可省）
· 研报侧只看得到 N 篇（上游硬顶 10 篇），去重后 M 家 —— **家数是下界，不是全街覆盖**
· 分析师家数由 analyst_grades 去重估算，consensus_price 本身不提供家数
· <若有>news 召回失败，维度 2 判定不成立
· <若有>13F 环比因申报季回补未完成，未引用
```

**⛔ 硬要求**：

**1. 解读优先于陈列——这是本 Skill 的成品标准，不是加分项。**

数据块（候选层 / 四维）是**证据**，【领读】和【净信号】才是**产品**。只吐表不算完成。

判别标准很简单：**把数字换成别的数，这句话还成立吗？** 成立就是复述，不成立才是解读。

| ❌ 复述 | ✅ 解读 |
|---|---|
| "5 家机构目标价 84–200，中位 130" | "**目标价从比现价还低 3% 到高 131% 都有，这不是分歧，是五家人在看五门不同的生意**——买方在赌代工翻身，卖方在算 PC 周期" |
| "评级动作 5/5 维持" | "评级零变化但两家偷偷把目标价抬了 10–12%。**真正的读数是'没人敢改立场，但有人在改价'**" |
| "EPS 超预期 100%，GAAP 每股亏 2.16" | "同一份财报，一个口径超预期一倍、另一个口径单季亏 110 亿。**这里能吵一年，所以别锚 EPS，锚营收**" |
| "内部人 1 笔卖出，国会 1 笔买入" | "高管在 $118 卖，现价 $86.6。**他卖在了高点——这条比任何目标价都硬**" |

**2. 每个数据块后面都要有一句「所以」。** 光把四维读数排出来不算对撞——对撞是指出**它们互相矛盾在哪、谁该让位于谁**。

**3. 异常主动顶出。** 口径错位、孤儿告警、水分告警、KOL 反向——命中任何一条，必须进【领读】，不能埋在表格里等人自己找。

**4. 不给买卖建议、不给仓位。** 输出是"值得进一步研究的校准读法"。

**5. 跨源打架时明说，不硬圆。** 四维里任一维是"无数据"或"不可判"，照写。**"不可判"本身是有用的解读**，硬凑一个结论才是失职。

**6. 价格只引本次 MCP 返回值**（红线：新闻与 KOL 转述的百分比是二手，必经快照核实）。

## 额度哨兵

每次跑完读一次 `meta.quota`（每个返回都带）。`remaining/limit < 15%` 时在产出末尾附一行内部提醒（不进对外内容）：`⚠️ 本月额度剩 N 次，按当前节奏约可跑 X 天`。

单次完整跑 = **3 额度**（研报 1 + fundamentals 1 + signal 1；news 0）。加 peers 快照则 4。

## 已知边界

| 边界 | 性质 | 处置 |
|---|---|---|
| 只看得到 10 篇 / 去重后 3–5 家 | 上游硬顶（N-38）| 所有家数标下界；**不做需要全覆盖的信号（错位族/信念族）**。实测去重后：NVDA 3 家、INTC 5 家、GOOGL 5 家 |
| 孤儿阈值 1.3× / 0.95× | **拍的，未回测** | 同时输出原始百分比 + 跑「≥2 家同时触发则判中位滞后」的反向检查 |
| 榜单 `net_direction` 不可用 | 连带污染（N-39）| 本 Skill 全程不读榜单方向，只读钻取后的 `subject_reports` |
| **停止覆盖信号：未证实，不是做不了** | ⚠️ **2026-07-29 修正此前的错误断言**：`revision_summary.list_changes[]` **字段确实存在**（结构 `{action, list, security}`），此前写"MCP 无此字段"是错的 | 实测三标的只见到 `action` 为 `initiate`（Bernstein 07-27 组合名单）与 `add`（J.P. Morgan 加入 Positive Catalyst Watch），**未见到停覆类 action**。→ 表述为"**样本内未出现，机制上可能支持**"，出现时按库内时钟族读法处理；**不承诺一定能抓到** |
| 方向翻转（错位族）做不了 | 需同机构前后比对，而只有 3–5 家可见、`rating_history` 只带 TP 不带 rating | 不做。**但 `revision_summary` 的 old→new TP 是可用的替代**（实测 INTC 两家真上调），已并入候选强度 |
| `subject_reports=0` | 真实分支（实测 F 全 mention）| 不出信号卡，降级为 mention 叙事。**且该状态会变**——GOOGL 07-23 为 0、07-29 为 6 |
