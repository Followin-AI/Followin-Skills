---
name: Research Cross-Source Readout (r1 — 研报跨源印证读数卡)
description: 单标的研报解读旗舰。把卖方研报的结论当「有偏候选」，再用 Followin 四维活数据（共识 / 市场 / KOL 与内部人 / 基本面）对撞印证，铸成一张校准后的读数卡。输出不是买卖建议，只回答三问：锚哪个价、背离什么性质、盯什么反向信号。必须点名标的才触发。
trigger: 印证一下XX的研报、XX研报靠不靠谱、跨源印证、读数卡、研报校准、这个目标价能信吗、research readout、cross-source
not_trigger: 研报榜/本周研报（→ Community c3）、单纯问目标价（→ Base 02）、催化剂日历（→ r3）、只想看报告口径（→ r2）、财报季扫描（→ Earnings Screener）、背离扫描（→ Base 03）
mcp: mcp__followin__metrics, mcp__followin__signal, mcp__followin__news
args: ticker(必填), window(可选，默认「本季财报日起、最短 21 天、最长 45 天」，取不到财报日退回 30d；只作用于研报 report_date；步骤 1 不传 time_range、取回后客户端过滤，以便记下窗口外被滤掉的篇目)
---

# /r1-cross-source-readout $ARGUMENTS

**研报库单独不产信号，只产候选。信号是候选被跨源印证或证伪的那一刻才铸成的。**

> **版本**：v1.1 ｜ **实测验证于 2026-07-29**（NVDA 全链路实跑）｜ **调用形态与字段名 2026-10-01 按生产端复测更新**（逐调用复测，未重跑全链路）｜ **2026-10-05 MU 全链路实跑后修订**（候选层窗口分支、闸 1 判据、内部人窗口、背离判据、口径声明）｜ **2026-10-08 NVDA / ACN 全链路复跑后修订**（signal 带 `limit=50`、单家候选按带 TP 家数计、同日不同 TP 去重、窗口内见尽判据、只有行业报告点名时出简版卡）｜ **2026-10-08 用户拍板**：窗口改为本季财报日起最长 45 天、背离触发改为日内 / 超额回撤 / 近 20 日三条 ｜ **2026-10-08 ACN / AVGO 复跑后修订**（回撤正负号与百分点口径、同行怎么挑、模板 ② 改基准、`consensus_diff` 缺该行假设时的取法、国会人数按姓名计）｜ **2026-10-08 用户拍板第二批**：窗口最短 21 天、背离第 2 条须近 20 日在跌、新增「个股独立跑输」、孤儿告警两条同时满足
>
> ⚠️ 本文所有 ⚠️ 与阈值都是实测结果或明确标注的拍脑袋值，不是推断。MCP 行为会变。
> 通用红线见 [`references/followin-mcp-caveats.md`](../references/followin-mcp-caveats.md)，本文内联的是镜像，冲突以该文件为准。
>
> **隔一段时间再用，先花两分钟自查这 3 条**：
> ① `metrics(keywords=["NVDA"], query="research reports", verbosity="detail", asset_type="tradfi")` → 看 `meta.pagination` 在不在。**在 = 翻页能力健在（N-81 已修）**；不在 = 出现回退，记回 SSOT。`report_limit` 单页是 10 属正常，不再是缺陷
> ② 同上调用传 `time_range="7d"` 与 `time_range="30d"`，返回**应不同**且 meta 带 `time_scope`/`date_from`（time_range 腿 2026-08-03 已修，N-38 部分销案）；逐个相同 = 出现回退，记回 SSOT
> ③ `signal(keywords=["NVDA"], categories=["kol_call","insider_trading","institutional","trader_position"], asset_type="tradfi")` → kol_call 里有没有 `symbol=="NVDA"` 的行；没有 = N-40 仍在。**不传 categories 现在返回空（`no_match`）——2026-10-01 实测，N-4 已失效**

## 参数

| 参数 | 必填 | 默认 | 说明 |
|------|------|------|------|
| ticker | ✅ | — | 单个美股代码。**本 Skill 不做批量**——四维对撞每标的 3 额度，且需逐份读报告论点 |
| window | 否 | 本季财报日起，最短 21 天、最长 45 天 | 报告新鲜度窗口，**只作用于研报**（内部人窗口另定，见步骤 3）。**起点 = 步骤 2 的 `earnings_surprise.report_date`**（含当日），早于今天 −45 天时截到 −45 天，**晚于今天 −21 天时提前到 −21 天**（2026-10-08 用户拍板：ACN 10-01 发财报、10-08 跑时窗口只有 7 天 1 篇；提前后纳入的财报前报告按步骤 1 的「财报前研究」规则标注）；取不到财报日（闸 0 缺失等）时退回 30d。**理由**（2026-10-08 实测 NVDA）：卖方报告扎堆在财报后几天，30d 按日历一刀切会把这一波整批切到窗口外——NVDA 08-26 财报后 08-26~08-27 有 5 家出报告，30d 窗口（09-08 起）只剩 Citi 一家，按财报日起算则是 5 家 $300–400；窗口按财报周期切，读到的才是「消化完本季财报后的立场」。最长 45 天是为了财报已过很久时不把陈旧报告算进来。**服务端 `time_range` 腿已于 2026-08-03 修复**（`date_from`/`date_to` 可用、`time_scope` 字段透明），窗口过滤可服务端做；**本 Skill 仍在客户端按 `report_date` 过滤**——窗口外的 subject 要作为「窗口外背景」列出（见步骤 1 清洗第 4 条），服务端过滤会把它们直接丢掉。但 `report_limit:10` **单页**硬顶与机构名不归一仍在（N-38 部分修复；**翻页能力已于 2026-08-12 补上**，见 N-81）|

## 为什么必须跨源

单篇卖方研报**系统性偏多**，所以它只是有偏候选。这解释了一个反直觉结论：**同一批 9 篇同机构研报不能自成信号**——一家之言构成的是「假共识」。真共识、真背离，只能从跨源对撞里来。

MCP 侧还额外叠了一层削弱：**每票最多看得到 10 篇、去重后常只剩 3–5 家机构**（N-38 + N-62；实测 NVDA 3 家、INTC 5 家、GOOGL 5 家）。所以本 Skill 的研报侧读数**天然是下界**，这一点必须写进每张读数卡。

## 意图路由

| 用户说的 | 走哪 |
|---------|------|
| 印证 XX 的研报、这个目标价能信吗 | ✅ 本 Skill |
| 本周研报榜、谁被提得最多 | ❌ 转 `Community Skill/c3_research-hot`（c3 已是 7d 真周榜，N-37 已修复销案）|
| 这份报告哪里没说清、口径边界 | ❌ 转 [`r2_research-caveat-audit`](./r2_research-caveat-audit.md) |
| 接下来有什么催化剂 | ❌ 转 [`r3_catalyst-timeline`](./r3_catalyst-timeline.md) |
| XX 财报分析 | ❌ 转 `Base Skill/02_us-stock-earnings-report` |

---

## 执行流水线（4 步 · 3 额度；个股距高点 ≥10% 且近 20 日在跌，或判「轮动错杀」时，另加同行快照 1 额度）

🔒 全程美股：**所有调用必带 `asset_type="tradfi"`**，`news()` 也带（2026-10-01 实测正常返回，旧例外已撤销）
📌 **入参分工（2026-10-01 实测，N-105）**：标的放 `keywords` 数组、意图词放 `query`、信号类别放 `categories`、新闻来源放 `sources`。客户端不接受数组入参（报 `-32602`）时，metrics 可退回 `query="<TICKER> …"` 拼串
🔒 **SSE 并发 ≤4**（红线 2）：本流水线 4 路可一批发，但步骤 1 的返回 ~70–100KB（2026-10-05 实测 MU 约 10 万字符，超出工具输出上限会被写进本地文件，用脚本解析），建议 1 单发、2-4 并发

### 步骤 1 · 候选层：拉研报（1 额度）

```
metrics(keywords=["<TICKER>"], query="research reports 行情", verbosity="detail", asset_type="tradfi")
```

> 📌 **调用形态（2026-10-01 实测）**：标的放 `keywords` 数组、意图词放 `query`。query 里的"行情"是为了在同一次调用里多拿 `market.snapshot`——研报调用已不再自动附带快照。客户端不接受数组入参（报 `-32602`）时可退回 `query="<TICKER> research reports"`（实测返回一致，但没有快照）。

> 🔴 **取数前先认块（N-86，2026-08-12 实测）**：解析层会静默扩展出额外候选 ticker，**每个候选都是一个平级结果块，顺序不保证主匹配在前**（实测 `ASML.AS` 的 `[0]` 是空块、数据在 `[1]`）。
> ① ⛔ **禁止用 `research_reports[0]` 取数**　② 逐块比对 `query_ticker` == 本次标的，**只认相等的块**　③ ⛔ **禁止用 `meta.total` 判条数**（它数的是块）

> ⚠️ **query 必须含研报意图词**（红线 12）。只放报告标题或"半导体/AI"这类话题词**不会路由到研报路径**，会静默掉进 CORE fundamentals 全家桶，且照常计 1 额度。
> ⚠️ **`time_range` 已于 2026-08-03 修复生效，可传**（`date_from`/`date_to`/`time_scope` 字段透明）。
> ⚠️ `limit` 单页仍被 10 硬顶，但 **2026-08-12 起返回体带 `meta.pagination.next_cursor`，可翻页枚举完**（N-81 销案）——**没翻页才需要把家数标下界**。翻完了就可以直接写家数，不必再标下界。
> ⚠️ **subject 排在 mention 前面**（2026-10-05 实测 MU）：首页 4 subject + 6 mention，subject 按日期倒序排完才轮到 mention（mention 里有比 subject 更新的日期）；带 cursor 的第 2 页 0 subject + 10 mention、仍 `has_more`。所以**首页 `mention_report_returned_count>0` 时，subject 大概率已全部给出**，家数统计可省翻页（单样本，口径声明里写「subject 已见尽、mention 未翻完」）。翻页页不带 `market.snapshot`。
> 　**首页全是 subject 时**（2026-10-08 实测 NVDA：首页 10 subject + 0 mention，第 2 页仍 10 subject + 0 mention、日期 08-20~07-08 接着倒序）：只要首页**最旧一篇 subject 已早于窗口起点**，窗口内的 subject 就已见尽，**窗口内家数不必翻页**；翻页只会多出窗口外背景（NVDA 第 2 页多出 HSBC 08-20 TP 325→360）。口径声明写「窗口内 subject 已见尽、窗口外未翻完」。
> ⚠️ **`meta.warnings` 会误报 `default_fanout_fallback`**（N-21）——**这是假阴性，不要据此重试**，重试白烧 1 额度。以 `results.fundamentals.research_reports` 是否存在为准。

**返回结构**：`subject_reports`（主题报告，核心研究对象就是这支股）+ `mention_reports`（提及报告，主题是别的，只是点了名）。**至多 10 篇**——`report_returned_count` 不保证等于 10，有货才给（N-64，实测 F 只返回 3 篇）。

> 📌 **卡片字段名（2026-10-05 实测）**：标题在 `report_title`（没有 `title`）；目标价在 `matched_asset_target_price.new`（查询标的自己的价）与 `report_subject_target_price.new`（报告主体的价）——旧的 `target_price` 已移除（N-79）。⚠️ **mention 卡的 `report_subject_target_price` 是别家主体的价**（实测 MU 第 2 页里有 SK Hynix 3,000,000 韩元），绝不能混进本标的 TP 集合。
> ⚠️ **`detail` 下的列表是截断的**（2026-10-05 实测）：每篇的 `caveats` / `risks` / `key_points` / `catalysts` / `affected_names` 只给前 1 / 2 / 3 / 2 / 5 条，全量条数在 `detail_sections`。引用这些列表时写「前 n 条（共 N 条）」，不要把看到的条数当全量。
> ⚠️ **双重上市标的按代码分桶**（2026-10-05 实测）：TSM 只有 mention、2330.TW 只有 subject。查 ADR 得到 `subject=0` 时，先用本地代码再查一次，再判「无专题研究」。

**拿到后必须做的五步清洗**，顺序不能反：

1. **机构名归一**（N-38）：`"Morgan Stanley"` 与 `"Morgan Stanley & Co. LLC"` 是同一家。同理 `"BofA Securities"` / `"B of A Securities"`、`"Citi Research"` / `"Citigroup"`。**不归一直接去重，同一家会被算成两家，虚增覆盖度。**
2. **按「机构 + 标题 + 日期」去重**（N-3）：同一份报告可双 `event_id` 重复入库。实测 NVDA 6 条 subject 去重后**只剩 3 条**。
3. ⚠️ **再去一次「快评 + 完整版」重复**（N-62，2026-07-29 实测新增）：**N-3 那条去不掉它**——标题不同所以三元组不同，但实质是同一份研究。
   **判据：同机构 + 同日 + 同 TP，即使标题不同也须合并**（保留信息更全的一篇）。
   实测 INTC：Goldman Sachs 2026-07-23 两篇同为 TP 150——《…First Take: Strong quarter across the board…》与《…Strong quarter across the board, with margin upside…》，前者是盘后快评、后者是完整版。不合并会把 GS 算成两家。
   **跨日变体也要看**：Citi 07-23《2Q26 Earnings Quick Take》与 07-24《Transformation in Progress》同为 TP 130，是同一事件的快评+深度。跨日时不强制合并，但**按机构取最新一篇**即可自然消解。
   ⚠️ **同机构同日、TP 不同**（2026-10-08 实测 NVDA）：Goldman Sachs 08-26《First Take: Solid quarter…》TP 285，同日完整版《Strong 2027 outlook…》TP 300、`matched_asset_target_price.old`=285——快评之后当天就改了价。上面的判据（同 TP）合并不了它，「取最新一篇」又因同日分不出先后。**取 `old` 等于另一篇 `new` 的那篇（后发版）**，另一篇丢弃；两篇都没有 `old`、分不出先后时，仍只算 1 家，TP 写成「$A / $B（同日两版）」，口径声明里注明。
4. **按 `report_date` 过滤到 window 内**（起点要等步骤 2 拿到财报日才定；过滤在客户端做，不影响步骤 1 的调用），并记下被滤掉几篇。财报当天的报告计入窗口，但标题含 Preview / 前瞻的仍按财报前研究处理、不计入。窗口外的 subject **按机构取最新一篇**，列为「窗口外背景（日期）」，不进区间 / 中位 / 离散比计算；窗口内已有该机构的报告时不再列它的旧篇（旧价已体现在 `matched_asset_target_price.old` 里）。实测 AVGO（2026-10-08，财报 09-02）：窗口内 GS 09-02 TP 525→540、Bernstein 09-03 TP 550→575；窗口外背景只列 J.P. Morgan 07-27 TP 580、Morgan Stanley 07-14 TP 502，Bernstein 08-19 / GS 08-18 Preview 不列。
5. **分层**：只有 `subject_reports` 能用于评级/目标价统计（N-19）。`mention_reports` 只能当叙事背景，**其 `mention_context.rationale` 可引用为"某行业报告里被点名的理由"，但绝不能标成"机构评级"**。
   ⚠️ **`subject_reports=0` 是真实分支，必须处理**：实测 F(Ford) 返回 `report_returned_count=3`，**全部是 mention，subject 为 0**。
   此时**出「简版卡」**（格式见「输出」一节）：不含【候选层】，步骤 2–4 照跑，四维对撞里能做的维度（共识、市场、KOL·内部人、基本面）照写；【领读】首句固定写「**本标的近期无专题研究，以下不含研报候选层**」。行业报告点名单独一行列作背景，附 `mention_context.rationale`。
   📌 点名背景可用的两个字段（2026-10-08 实测 ACN：9 篇全 mention、`has_more:false`）：`mention_context.mention_direction`（`beneficiary` / `negative` / `competitor`，2026-10-08 实测 AVGO 另见 `neutral`）按篇计数，写「n 篇看作受益、m 篇看作受损」；`mention_context.mention_rating`（如 GS 10-02 行业报告里标 ACN `"Buy"`、MS 07-16 标 `"Equal-weight"`）只写成「该行业报告顺带标注的评级」，**不进评级统计**——它是行业组的转引，不是这只票的专题结论。⚠️ 别和 `rating_current` 混：后者是报告主角的评级（实测 Bernstein 09-14 的 `rating_current:"Outperform"` 是给 Capgemini 的）。
   ⚠️ 但 **N-19 的「GOOGL subject=0」是时点现象不是恒定特性**：2026-07-23 实测 GOOGL subject=0，**2026-07-29 复测 subject=6**（Barclays/MS/Bernstein/Citi×2/GS）。**每次当场看返回，不要照抄历史结论。**

> ⚠️ **窗口内可见 <2 家时**（2026-10-05 实测 MU：首页 4 篇 subject，30d 窗口内只剩 UBS 09-23 一篇）——**家数按带 `matched_asset_target_price.new` 的机构计**，没有 TP 的 subject 只列名、不算（2026-10-08 实测 NVDA：窗口内 Citi 09-28 TP 315 + UBS 09-28 回购快评，后者无 TP、无评级、`stance_normalized:null`，按机构数是 2 家，按 TP 只有 1 家）：候选层标「**单家候选**」，离散比写「不适用」，【候选层】只填这一家，窗口外背景照第 4 步列出。窗口内 0 家、窗口外有 subject 时同样出卡，但【领读】第一句写明「窗口内无专题研究」——这和第 5 步的 `subject=0`（全库都没有）不是一回事。
> ⚠️ **TP 落在全街区间外 = 大概率已过时**：任一研报 TP 落在步骤 2 `consensus_price` 的 `[targetLow, targetHigh]` 之外，标「该 TP 大概率已被后续修正（研报库滞后）」，不作锚。实测 MU：Citi Research 08-07 TP 1,150 < 全街最低 1,200，而 `analyst_grades` 里 Citigroup 09-23 又有一次维持评级。
> ⚠️ **财报前研究**：`report_date` 早于步骤 2 `earnings_surprise.report_date` 的报告一律标「**财报前研究，论点未经本季财报检验**」，并写进【领读】。实测 MU 9/30 发财报，10/5 研报库窗口内唯一一篇是 UBS 09-23 的财报前瞻——财报刚发的几天里这是常态，此时财报后的真动作只能从 `analyst_grades` 看。

**候选强度读数**（全部标成下界）：

| 读数 | 取自 | 表述铁律 |
|---|---|---|
| 可见机构数 | 去重后 `subject_reports` 的 institution 基数 | 写"**可见 N 家**"，绝不写"N 家" |
| 目标价区间 | subject 卡的 `matched_asset_target_price.new` 集合（N-79：旧 `target_price` 已移除；mention 卡的 `report_subject_target_price` 是别家主体的价，禁用）| 必带家数；单均值禁用 |
| **TP 离散比** | `max(TP) / min(TP)` | **>1.8x 告警**（水分族阈值，沿用库内口径）；窗口内 <2 家写「不适用」|
| 评级动作分布 | `rating_action` 按前缀词归类后计数 | 区分 `reiterate`（维持）与真上调/下调。⚠️ 值是自由文本复合串（实测 `"reiterate Buy"`、`"reiterate Buy; remove Upside 90-Day Catalyst Watch"`），按开头的 reiterate / upgrade / downgrade / initiate 归类，分号后的名单动作单独读 `list_changes` |
| 修正明细 | `revision_summary.by_name[]` | 带 `old_target_price` → `new_target_price` + `change_pct` 才算真修正。⚠️ 没有 `old` 时看同机构更早一篇：实测 NVDA Citi 09-28 TP 315 无 `old`，同机构 08-26 那篇是 300——写「较该行 08-26 的 $300 上调 5%（跨篇推算）」，不写成「无修正」 |
| 研报侧假设 | subject 卡的 `consensus_diff` | 原文摘「该行 EPS / 营收假设较共识 ±X%」，供维度 4 用（实测 MU：UBS CY27/28 EPS 比共识高 28.8% / 63.7%，Citi FY27/28 比共识低 12.7% / 15.5%）。⚠️ 该键可能整个缺席（2026-10-08 实测 NVDA Citi / UBS 09-28 两篇公司快评都没有，`coverage_flag.missing` 写明「no explicit consensus comparison」）：写「该行未给共识对比」，不要拿窗口外的旧卡顶替。⚠️ **该键可能只讲「本季实际 vs 共识」，不是该行假设**（2026-10-08 实测 AVGO：GS 09-02 写的是「FY3Q26 EPS 高于 Street 2.3%」，Bernstein 09-03 写的是本季 beat 与 FY4Q26 指引）：此时改用 `detail.estimates.eps`（该行分财年 EPS）对步骤 2 `analyst_estimates` 同一财年的 `epsAvg` 自算，并注明口径——实测 Bernstein FY27/28 EPS 18.63 / 31.54 对共识 19.30 / 30.65 = −3.5% / +2.9%；GS 20.20 / 34.25 是**剔除股权激励**的经营 EPS，对共识 +4.7% / +11.7% 要标「口径不同，偏高部分不全是激进」。共识缺该财年（N-134 ④）时写「共识无该财年」 |

> ⚠️ **评级用 `stance_normalized`**（实测见过 `positive` / `neutral`，行业报告为 null；**无评级的公司快评也是 null，且 `rating_action` / `rating_current` 两个键整个缺席**——2026-10-08 实测 NVDA UBS 09-28，这类篇不计入评级动作分布）计数，不再手工映射 `rating_current`——后者不归一（实测同时出现 `"Buy"` / `"BUY"` / `"Attractive"` / `"Overweight; Top Pick"`），只在 `stance_normalized` 缺失时才映射成多/中/空三档。
>
> ✅ **顺带拿**：query 带"行情"时，本步返回里有 `market.snapshot`（price / previousClose / change / marketCap / yearHigh / yearLow）。⚠️ **快照字段随 `verbosity` 变**（2026-10-05 实测）：本步是 `detail`，快照**另带** `changePercentage` / `priceAvg50` / `priceAvg200`；步骤 2（默认 standard）**不带**，需自算 `change ÷ previousClose × 100`。上行空间就地算，**不要再花额度查现价**。非交易时段返回的是上一常规收盘（`_quote_session:"regular_inactive"`）；盘前盘后另有 `extendedHoursQuote{bidPrice, askPrice, timestamp}`，引用时注明「盘前 / 盘后报价」，不与收盘价混写。
>
> ✅ **顺带白拿**：`detail.catalysts[]` 里 `security` 字段**可以不等于查询 ticker**（N-41）——查 NVDA 会顺带拿到竞品 AMD 的事件日。这些交给 [r3](./r3_catalyst-timeline.md) 消费，本 Skill 只取与本标的相关的。⚠️ 每篇只给前 2 条，全量条数看 `detail_sections.catalysts`。

### 步骤 2 · 维度 1 + 维度 4 + 价格腿：一次拿全（1 额度）

```
metrics(keywords=["<TICKER>"], query="行情 分析师评级 目标价 历史走势", asset_type="tradfi", limit=21)
```

> 📌 **query 带「历史走势」、`limit=21`**（2026-10-08 实测 ACN，仍 1 额度）：同一次调用多回 `market.history` 21 行日线（含当天盘中那一行），供背离第 3 条算近 20 个交易日涨跌。`analyst_grades` 会因此报 `parameter_partial`（「capped at 20 rows」）、`status:"partial"`，属正常，不要重试（2026-10-08 实测 ACN / AVGO：warning 照报，grades 实际回了 21 行）。
> ⚠️ **当天那一行的 `close` 不等于快照价**（2026-10-08 实测 ACN 盘中：history 当天 `close` 199.26，同一返回的快照 `price` 195.51，差 1.9%）。日内涨跌与近 20 日都用**本步**快照的 `price`（与 history 同一次返回），不要换成步骤 1 那份快照（两者相差几秒到几十秒，ACN 实测 195.07 vs 195.51），也不要用 history 当天行的 `close`。

**这一个调用同时返回**（2026-10-01 实测）：`consensus_price` + `analyst_grades` + `analyst_estimates` + `eps_trend` + `fiscal_quarters[0]`（内含 `earnings_surprise` 与 `financial_statement`，只有最新一季）+ `next_earnings_estimate` + `market.snapshot`。

> ⚠️ **字段已换代（N-109）**：旧的 `beat_miss` / `latest_quarter` 两个 block 不存在了。对应关系：`beat_miss.epsActual` → `fiscal_quarters[0].earnings_surprise.actual_eps`；`beat_miss.date` → `earnings_surprise.report_date`；`latest_quarter.eps` → `fiscal_quarters[0].financial_statement.eps`（基本 EPS；GAAP 稀释在 `epsDiluted`，闸 1 用后者）；`latest_quarter.date` → `financial_statement.period_end`。本调用不再返回 `valuation_block`（要 DCF 得把"DCF"写进 query，本 Skill 不用）。`analyst_grades` 的行数受 `limit` 控制、封顶 20，本步传 `limit=21` 是为了 history 多拿一行，grades 照样是 20 行上下。

> ⚠️ **query 里不要加会撞 ticker 的英文词**（N-14）：`beat` / `miss` / `hold` / `buy` / `now` / `all` 都会被当成 ticker 抽取（实测 `BEAT` 撞上仙股 HeartBeam $0.55）。调用后核对 `meta.filters_applied.keywords` 只有目标 ticker。

**维度 1 · 共识对撞**——研报的目标价是不是全街最高的孤儿？

| 判据 | 阈值 | 说明 |
|---|---|---|
| 孤儿告警 | 研报 TP > `targetMedian × 1.3` **且** 研报 TP ≥ `targetHigh × 0.95`（2026-10-08 用户拍板：两条同时满足才告警，原为「或」）| ⚠️ **这两个阈值是拍的，未回测**。改「且」的起因：AVGO Bernstein 575 只比中位 517.5 高 11.1%，仅因 ≥ 600×0.95 = 570 就告警。定 1.3 的唯一依据是 SNDK 历史案例（伯恩斯坦 $3000 vs 中位 $1585 = +78%，是公认的孤儿）。用的时候把原始百分比也写出来，别只给结论 |
| **⛔ 孤儿的反向检查** | **可见家数里 ≥2 家同时触发孤儿告警 → 判定反转** | **不是研报激进，是 `consensus_price` 中位滞后**。实测 INTC 5 家里 GS 150(+36%) 与 HSBC 200(+82%) 双双触发——而 INTC 刚 beat-and-raise、研报 TP 已上调，中位 110 还没跟上。此时应写"共识中位可能滞后于最新一轮修正"，**不是"两家都在放卫星"**。⚠️ 这个样例按旧的「或」判据成立；按 2026-10-08 起的「且」判据，GS 150 低于 200×0.95 = 190、不再触发，只剩 HSBC 一家告警，反向检查不成立 |
| 家数 | 由 `analyst_grades` 按 `gradingCompany` 去重估算 | ⚠️ `consensus_price` **无家数字段**（N-16）。用 grades 估算时**必须注明是估算**。实测 INTC 20 条 grades / **17 家**，覆盖面远超研报侧的 5 家 |

**两个实测样例，读数完全相反**（都是 2026-07-29）：

- **NVDA｜共识内**：研报 TP = 288/300/350，全街中位 300、区间 218–500 → 最高的 BofA 350 仅高于中位 +16.7% 且远低于 targetHigh → **不是孤儿**。离散比 350/288 = **1.22x，无水分告警**。
- **INTC｜孤儿 + 水分双告警**：研报 TP = 84/110/130/150/200（5 家），全街中位 110、区间 60–200 → HSBC 200 **正好等于 targetHigh**（+82% vs 中位）、GS 150（+36%）→ 两家触发孤儿，按上面的反向检查判为**中位滞后**（旧「或」判据下的读数；按现行「且」判据只有 HSBC 触发，读作 HSBC 一家孤儿）。
  离散比 200/84 = **2.38x 🚨 水分告警**——而且它顺带抓出**真多空对决**：同一天（07-24）HSBC Buy $200（对现价 +131%）vs Morgan Stanley Equal-weight $84（对现价 **−3%**）。这正是水分族"一条告警两个用途"的实例。

> ⚠️ **`rating_action` 全是 reiterate ≠ 没有修正——两者必须分开读。**
> 实测 INTC 5 家 `rating_action` **全是 reiterate**（评级没变），但 `revision_summary` 里有**两家真上调 TP**：Morgan Stanley 75→84（**+12%**）、Bernstein 100→110（**+10%**）。
> **"维持评级 + 上调目标价" = 信念增强**，只看 `rating_action` 会把它读成"什么都没发生"。
>
> ✅ **交叉验证的两种形态**：
> · NVDA：研报 6 篇全 `reiterate` × `analyst_grades` 20 行全 `maintain` → 两源一致指向**当前无人变心**。
> · INTC：研报全 `reiterate` × grades 19 maintain + **1 upgrade**（Goldman Sachs 2026-06-25 **Sell→Neutral**）→ grades 抓到了研报窗口外的真动作。**grades 的覆盖面和回溯深度都优于研报侧，别只看研报。**

**维度 4 · 基本面锚**——研报的假设比现实激进多少？

两头都要摆出来：**研报侧假设**取步骤 1 subject 卡的 `consensus_diff`（写成「该行 EPS / 营收假设较共识 ±X%」），**现实侧**用 `fiscal_quarters[0].earnings_surprise` + `eps_trend` + `next_earnings_estimate`。只摆现实侧回答不了「研报激进多少」——实测 MU：UBS 的 TP 只比全街中位高 8%，激进全在 EPS 假设上（CY27/28 比共识高 28.8% / 63.7%）。

现实侧**必须先过四道数据完整性闸，且顺序是 0 → 2 → 3 → 1**：

**闸 0 · 超预期块在不在**（2026-10-01 新增）：财报刚发的头几天，`fiscal_quarters[0]` 可能只有 `financial_statement` 而**整个 `earnings_surprise` 缺失**（实测 MU 9/30 盘后发财报，10/1 查到新一季的报表数字，但没有预期值；**10/5 复查已补齐**，缺失窗口不超过 5 天）。缺失即标"超预期数据未更新"，下面三道闸全部跳过，不要拿上一季的数顶替。

**闸 2 · null 伪装成极端真值（N-33）**：`actual_revenue` 为 null 时服务端**把 null 当 0 做减法**，输出 `revenue_surprise_pct: -100`。**见到 −100 一律先当缺失查证**（真实世界营收归零几乎不可能）。

**闸 3 · 同季确认** ⚠️ **判据已于 2026-07-29 实测修正，别按直觉比日期**：

> `earnings_surprise.report_date` 是**财报公布日**，`financial_statement.period_end` 是**财季结束日**——**这两个日期天然就不相等**。直接比日期会把每一个正常样本都判成"不同季"，从而**作废掉本该生效的闸 1**。
>
> **正确判据 = 复用 N-34 的 gap**：`gap = earnings_surprise.report_date − financial_statement.period_end`，**gap < 90 天 = 同季**（90 天 = 一个完整财季，N-34 已用 42 样本验过这个分界）。
> 实测 INTC：公布日 2026-07-23、财季结束 2026-06-27 → **gap = 26 天 < 90 → 同季**，闸 1 生效。若按朴素比日期则判为不同季，闸 1 被误作废。
> gap ≥ 90 天才标"口径无法核对"并作废闸 1——跨季比对会让一盈一亏的相邻两季产生假阳性。

**闸 1 · GAAP 口径错位（N-29）**：`earnings_surprise.actual_eps` 与 `financial_statement.epsDiluted`（GAAP 稀释 EPS）**差的绝对值 >0.01 即判定口径错位**（容差只为吸收舍入；2026-10-05 复测：NVDA 2.22 vs 2.46，MU 33.42 vs 32.87）——服务端始终不标 basis。`epsDiluted` 为 null 时退回 `eps` 比，并标「按基本 EPS 比对」。
**速判**：`actual_eps > financial_statement.eps`（基本）时**必为非 GAAP**——稀释 EPS 恒 ≤ 基本 EPS（实测 MU 33.42 > 33.36，与新闻里公司指引「非 GAAP EPS 31±1」吻合）。

> ⚠️ **GAAP 侧用 `epsDiluted`，不用 `financial_statement.eps`**（N-134 ③，2026-10-03 实测）：`eps` 是**基本** EPS。拿它比，哪怕超预期本身就是 GAAP 口径，基本与稀释之间的差也会让这道闸误判"口径错位"。下文 NVDA / INTC 的示例数字当时取自 `eps` 字段（基本 EPS），只用来说明错位的形态。

> ⚠️ **2026-08-05 判据放宽**：原文写「**反号**即判定」，那是照 INTC 定的（`+0.42` vs `−2.16`，一正一负很扎眼）。**实测 NVDA 是同号不同值**——`actual_eps 1.87` vs `financial_statement.eps 2.40`，同一个季度、都为正、差 **28%**，按旧判据**这道闸不会触发**。
> **同号错位比反号更危险**：反号一眼看得出不对劲，同号会被当成同一个数直接混用。

- **反号**（如 INTC）：强制标注"该超预期为非 GAAP 口径"，**营收 surprise（INTC +11.7%）才是可信主锚**
- **同号不等**（如 NVDA）：两条序列都可用，但**严禁跨序列组合**——
  · 要和 `next_earnings_estimate.epsEstimated` 比 → 只能用 `actual_eps`（NVDA：`1.87 → 2.08` 是 **+11%**，与营收 +12.6% 吻合）
  · 要看历史趋势 → 只能用 `eps_trend`（与 `financial_statement.eps` 基本 EPS 同值，**不是** `epsDiluted`；2026-10-05 实测 MU 两者都是 33.36、NVDA 都是 2.47）
  · ⛔ 绝不允许「上季 2.40 → 下季预期 2.08」（伪装成利润下滑 13%）或「实际 2.40 vs 预期 1.76 超预期 6.3%」（该式算出来是 +36%，自己就不成立）

✅ **自检**：任何两个 EPS 放进同一句话前，先确认来自同一字段族。三个族：{`actual_eps`, `estimated_eps`, `next_earnings_estimate.epsEstimated`}（市场口径）｜{`financial_statement.eps`, `eps_trend`}（GAAP 基本）｜{`epsDiluted`}（GAAP 稀释），族间不混用。

> ⛔ **`valuation_block.dcf` 在亏损期会给出荒谬值，一律不引用**（2026-07-29 实测新增）。
> INTC：`dcf = 2.95` vs 现价 `86.57`——**相差 29 倍**。亏损公司的现金流折现模型直接崩掉，而返回里没有任何字段标注它失效。
> **自检**：`dcf` 偏离现价超过 5 倍即判为失效，不进任何输出。本 Skill 全程不使用该字段。

### 步骤 3 · 维度 3：谁在反着做（1 额度）

```
signal(keywords=["<TICKER>"], categories=["kol_call","insider_trading","institutional","trader_position"], asset_type="tradfi", limit=50)
```

> 🔴 **必须带 `limit=50`**（2026-10-08 实测，N-151 在本 Skill 的后果）：`limit` 按类别分别生效、默认 10。不带时 NVDA 的 `insider_trading` 10 行只覆盖 09-16~09-21 六天，**国会交易一行都没有**；带 50 后覆盖到 06-26，近 90 天里有 7 行国会交易、25 笔 S-Sale。照默认跑，「内部人近 90 天」「国会近 90 天 0 人」都是错的。仍只计 1 额度，返回约 5.5 万字符（超出工具输出上限会落盘，用脚本解析）。
> ⚠️ **必须显式传 `categories`**（2026-10-01 实测，N-113）：只传 ticker 不传 categories 现在返回空（`status:"degraded"` + `no_match`），旧的"不传即 fanout 四类"（N-4）已失效。显式列出四类一次调用**仍只计 1 额度**。**不要假定四类恒在**——按实际返回的 key 判断（`trader_position` 在多数美股上没有数据，实测 MU / SNDK / ACN 均缺席；`kol_call` 也会整个缺席，实测 ACN）。`trader_position` 有数据时只作旁证：它是 `stock_perp` 永续合约仓位、不是正股，`profile.tier` 与喊单同一门槛（A 级含 `A+` 才进卡）（实测 NVDA 只有 1 个 D 级账户、$2.4 万多单）。
> ⚠️ **不要带 `time_range`**：13F 是季度数据，带窗口会被整类拒绝；喊单上游只覆盖最近 24 小时，传 7d 也只有 24h 的帖子。

**三类各自的读法与陷阱**：

| 类别 | 读什么 | ⚠️ 陷阱 |
|---|---|---|
| `kol_call` | 方向 + `kol_info.tier`/`signal_level`（A 级（含 `A+`）/ L1-L2 才进人眼）。方向计数在 `source_url` 去重后**再按 `username` 去重**，写「n 人 m 帖」——实测 MU 5 帖里 4 帖出自同一人，按帖数算会把一个人的观点放大成 4 条 | **N-40 死穴：目标 ticker 自己的行可能整个不在返回里。** 实测查 NVDA 返 8 行，**无一行 `symbol=="NVDA"`**，而原帖 `"BUY: - $NVDA …"` 明明把它列在首位（2026-10-01 复测：查 MU 的返回里混着 NBIS / NOW / CTKB 的行，keywords 不会把喊单过滤干净）。**必须回读 `content`，不能只信 `symbol` 字段**；再按 `source_url` 去重（N-5：一帖按提及裂多行）|
| `insider_trading` | 只认 `formType=="4"` 的 `P-Purchase`（买）与 `S-Sale`（卖）| `A-Award` / `G-Gift` / `F-InKind` / `M-Exempt` **不是主动交易**（授予、赠与、缴税代扣），剔除（实测 MU 财报日 9/30 有三笔董事 `A-Award`，`price:0`）。`formType=="3"` 是首次申报，非交易。<br>**国会交易与公司内部人混在同一个 key 下**：有 `_chamber` 字段（`house` / `senate`）、没有 `formType` 的行是国会交易，方向看 `type`（`Purchase` / `Sale`），日期用 `transactionDate`，披露滞后看 `disclosureDate`。⚠️ 不能按 `provenance` 分——2026-10-05 实测两类都是 `"fmp"`。<br>⚠️ 不传 `time_range`，客户端按 `transactionDate` 强制过滤（N-6）。**内部人与国会默认 90 天窗口**（与研报 window 解耦），模板写「近 90 天」。实测 MU：30 天内 0 买 0 卖，90 天内 3 人 4 笔卖出——窗口不定，结论就跟着变。<br>⚠️ **先核覆盖再下「近 90 天」**：返回按申报日倒序、受 `limit` 截断，取最早一行的 `transactionDate`，晚于 90 天起点就改写「近 N 天（返回只覆盖到 <日期>）」。实测 ACN（2026-10-08）：默认 10 行全是 10-05 / 09-05 两批 `A-Award`、一行国会都没有；带 50 后 50 行仍只覆盖到 08-01（月度授予 `A-Award` 占掉大半），近 68 天里内部人 1 笔 68 股 `S-Sale`，国会 3 人（2 买 1 卖）——写「近 68 天（返回只覆盖到 08-01）」，不写「近 90 天」。<br>⚠️ **同一份 PTR 披露会裂成多行**：实测 Cleo Fields 一份 PDF 出 3 行（`assetDescription` 为 `"NVIDIA Corporation"` / `"(1)"` / `"(2)"`，link 与日期完全相同）。**按 (姓名, 日期) 去重算人数，按行算笔数**，否则 1 位议员会被报成 3 位。⚠️ 去重后**人数再按姓名计**：同一议员不同日期的多份申报仍是 1 人（2026-10-08 实测 AVGO：David Taylor 07-24 / 08-26、Rick Allen 07-14 / 08-12 各买两次，是 2 人 4 笔，按 (姓名, 日期) 计会报成 4 人） |
| `institutional` | 绝对持仓（`holders[].shares` / `ownership_percent`）| ⛔ **申报季内禁引任何环比**（N-7）。实测 NVDA `investorsHolding` 2497 vs 上期 6234、`ownershipPercentChange −63.77%`、`putCallRatioChange +178%`——**全是回补未完成造成的残缺假信号**，不是真的机构跑了（这些是旧字段名，现已不存在）。<br>⚠️ **2026-10-05 实测现行结构**：`*_change_percent` 字段恒为 0，不可用；环比只用 `shares_change` 绝对值，且**仅当 `report_period` + 45 天（13F 申报截止）已过**——按 `report_period` 判，不按日历判「是不是申报季」。<br>⚠️ **`report_period` + 45 天未过时，连绝对持仓也不引用**（2026-10-08 实测 ACN：已切到 `2026-09-30`，只回 1 家 ROXBURY FINANCIAL、shares 0——新季度只有零星早报机构，拿它排名会得出「ACN 没有机构持仓」）。此时维度 3 的 13F 写「新季度申报未完成，不引用」。NVDA 同日仍停在 `2026-06-30`、50 家，可用。<br>⚠️ **同一 `cik` 可出多行**（实测 MU 里 SUSQUEHANNA 两行、股数不同；NVDA 里 SUSQUEHANNA 与 JANE STREET 各两行，`shares_change` 一正一负），先按 `cik` 合并再排名。这类做市商可能是正股与期权分行，返回里没有 put / call 字段分不出来，合并后也不进「谁在加减仓」的叙事 |

**判定**：基本面/研报看多 × A 级 KOL 或内部人反向 → **分裂**，这是读数卡里最该顶出来的一行。

### 步骤 4 · 维度 2：背离是什么性质（0 额度）

```
news(query="<公司名> <TICKER>", sources=["media"], sort_by="relevance", time_range="7d")
```

> ✅ **news 搜索可以传 `sources` / `sort_by`，但不传 `asset_type`**：2026-10-05 实测传 tradfi 召回下降（PTC 8→2、MU 20→17）且挡不住加密噪音（N-145）。找"有没有击中论点的事实"用 `sources=["media"], sort_by="relevance"`（默认按时间排，最新的未必最相关）。实体搜索 **0 额度**（N-1）。
> ⚠️ **query 三原则**（红线 5）：2-3 个核心名词、不中英混搭、不写"影响/解读/分析"等元词。
> ⚠️ **无匹配时不返空，返语义兜底的不相关内容**（红线 11）。更狠的是 **N-35 召回黑洞**：实测 `"Bloom Energy BE"` 与 `"Bloom Energy"` 返回**逐字相同的 12 条**兜底内容，0 条目标公司内容。**判别：返回里一条都不含目标公司名或 ticker 即判召回失败，记缺口不重试**（同 query 重试与换措辞均无效）。

价格用步骤 1 / 步骤 2 一并返回的 `market.snapshot`，**不额外调用**。

**背离性质三分**（这一步是整张卡的关键，读法完全相反）：

**先判有没有背离**，三条满足任一才进三分；都不满足，维度 2 写「无背离」：
1. **日内跌幅 ≥2%**：`change ÷ previousClose`（步骤 2 快照不带涨跌幅，自算）
2. **相对同行的超额回撤 ≥10 个百分点**：（个股距 `yearHigh` 的回撤）−（基准距 `yearHigh` 的回撤），**回撤按正数计**（`1 − price ÷ yearHigh`），结果为正 = 比同行跌得多，只有正值 ≥10 才触发，**且必须同时满足近 20 个交易日在跌（第 3 条算出的涨跌 <0）**（2026-10-08 用户拍板：AVGO 近 20 日 +2.9%，只因距 52 周高的累计回撤跑输同行就触发，背离会常驻）。**基准取同行快照里同细分行业 2–3 只的回撤中位数**；行业 ETF 只作参考并列写出——宽基或相邻行业 ETF 与细分同行走势经常分叉，拿 ETF 当基准会误触发（见下）。个股自己距高点 <10%，或近 20 日不跌（≥0）时，这条不可能触发，不必为它取同行快照——先用步骤 2 的日线算近 20 日，再决定要不要花这 1 额度
3. **近 20 个交易日跌幅 ≥8%**：步骤 2 的 `market.history`，最新一行（盘中用快照价）对第 21 行的 `close` 自算——⛔ 不要用行内 `changePercent`，那是收盘对开盘（N-131）

> ⚠️ **为什么不再用「距 52 周高 ≥10%」**（2026-10-08 实测 ACN）：ACN 当天 +4.5%、10-01 财报日 +15.8%，距 52 周高仍有 −29.4%，旧判据照样触发，可三分全是按「在跌」写的，套不上。同行普遍 −30% 以上（CTSH −31.8%、IBM −32.8%、EPAM −50.2%、INFY −64.5%）——这是整个 IT 服务被重新定价，不是 ACN 自己的背离。
> ⚠️ **为什么基准用同行中位、不用 ETF**：同一天软件 ETF IGV 距高点只有 −6.4%，拿它当基准 ACN 的超额回撤是 +23.0 个百分点，第 2 条仍会误触发；换成 IT 服务同行（CTSH −31.8%、IBM −32.8%、EPAM −50.2%）的中位 32.8%，超额回撤是 29.4 − 32.8 = −3.4 个百分点（比同行跌得少），不触发——这才是"整个 IT 服务被重新定价"的正确读法。ETF 的数照写，作参考。
> ✅ **2026-10-08 复跑 ACN（新判据）不再误触发**：日内 −0.6%、近 20 日 +9.9%（195.51 vs 09-10 收盘 177.91）、距高点 32.8%；同行 CTSH 36.9%、IBM 34.5%、EPAM 52.3%（INFY 66.2%），超额回撤 −4.1 个百分点；只有拿 IGV（6.4%）当基准才会是 +26.5。
> 📌 **同行怎么挑**（2026-10-08 用户确认维持此做法）：按研报论点依赖的那块业务挑，不按大行业。`metrics(keywords=["<TICKER>"], query="peers 同行", categories=["fundamentals"], asset_type="tradfi")` 的 `stock_peers` 可作候选池（2026-10-08 实测：ACN 给出 CTSH / EPAM / IBM / INFY / CGEMY / GIB 等 IT 服务同业，可直接用；AVGO 给出 ADI / TXN / QCOM / SWKS 等模拟与射频芯片，漏掉 NVDA / AMD，不能照搬），但它另计 1 额度、不带 `yearHigh`，回撤仍要靠同行快照。**卡里写明选了哪几只、为什么**，并做一次换人自检：去掉任一只或换成候选池里另一只，第 2 条会不会翻转——会翻转就在依据里写「触发依赖同行选择」。实测 AVGO（距高点 25.0%）：MRVL 16.3%、NVDA 2.7%、AMD 3.3%、ANET 0.4%，取 MRVL / NVDA / AMD 中位 3.3% → 超额 +21.6 个百分点；只拿定制芯片直接对手 MRVL → +8.7（这里只比回撤；AVGO 当天近 20 日 +2.9%，按「近 20 日在跌」条件第 2 条整体不触发）。
> ⚠️ 2% / 10% / 8% 三个阈值都是拍的，未回测，用的时候把原始百分比一起写出来。

| 性质 | 判据 | 读法 |
|---|---|---|
| **轮动错杀** | 跌但 news 里找不到针对该公司论点的负面事实；同板块同向（**必须有同行快照佐证**，没取同行快照最高只能判「尚不可判」）| 逻辑没被否，研报候选仍有效 |
| **逻辑被否** | news 里有直接击中研报核心论点的事实（订单取消、指引下修、竞品夺单）| 候选作废，别再锚研报 TP |
| **个股独立跑输** | 只由第 2 条触发（第 1、3 条都不满足），同行未同向下跌（同行快照当日多数没跌，或同行中位距高点远小于个股），news 里也没有击中论点的事实（有就判「逻辑被否」）| **相对同行持续跑输，不是短期错杀，也不是逻辑被否**。研报候选不作废，但别用「板块拖累」解释它；领读写清「跑输同行 X 个百分点、近 20 日 −Y%」，把与研报风险项对得上的报道列出来，作为「为什么跑输」的待查线索，不当结论 |
| **尚不可判** | news 召回失败，或有报道但与论点无关 | **诚实写"不可判"**，不要为了叙事完整硬圆 |

> 📌 「个股独立跑输」是 2026-10-08 用户拍板新增，替代原先这种情形落「尚不可判」的写法。起因是 AVGO（距高点 25.0%，同行 MRVL / NVDA / AMD 中位 3.3%，超额 +21.6 个百分点，NVDA / AMD / ANET 都在高点附近；news 只有为 Anthropic / OpenAI 提供融资的报道，对应 Bernstein 写的「financing constraints」风险）。⚠️ AVGO 当天近 20 日 +2.9%，按第 2 条新加的「近 20 日在跌」条件已不触发，那天应判「无背离」，这里只借它说明形态。

> 判「轮动错杀」与算超额回撤（背离第 2 条）**必须**取同行快照（+1 额度）：`metrics(keywords=["<T1>","<T2>","<T3>","<行业ETF>"], query="行情", categories=["market"], asset_type="tradfi")`，**每批 ≤5 只**（超出的写在 `meta.warnings` 的 `keyword_count_over_max`），含 `CL`/`GC`/`BABA` 等影子代码时**按 4 只装**（N-36）。不带 `categories=["market"]` 会顺带返回各家 `profile_block`，白占体积（2026-10-05 实测）。
> **同行 = 同细分行业 2–3 只 + 1 只宽基行业 ETF，两者分开写**。两者可能反向——实测 10/2：存储股 WDC −10.22%、STX −10.21%、SNDK −3.79%，而半导体 ETF SOXX +2.16%，MU −2.05%。此时应写「存储板块被单独卖」，不是「半导体板块在跌」。

---

## 输出：读数卡

固定五段（只有行业报告点名时用文末的简版卡）。**净信号不是「买入/卖出」**——只回答三个问题。

```
📇 <TICKER> 研报跨源印证读数卡 · <日期>

【🔎 领读】（先写这段，不是最后补）
<2–4 句。这张卡最该停下来看的是哪一条、为什么；以及哪些看着显眼其实可忽略。
 必须是判断，不是概括。>

【候选层】研报怎么说
可见 N 家机构（<window> 窗口内，去重后）｜目标价 $X–$Y（中位 $Z）｜较现价 $P 上行 A%–B%
   <单家候选时：目标价 $X（仅 1 家，无区间 / 中位）>
离散比 R×（>1.8x 才告警；<2 家写「不适用」）｜评级动作：n 维持 / n 上调 / n 下调
最新一篇：<机构> <日期>《<report_title>》——<thesis 一句话>  <若早于本季财报：⚠️ 财报前研究>
<若有>窗口外背景：<机构> <日期> TP $X（<old→new>）<若落在全街区间外：大概率已过时，不作锚>

【四维对撞】
① 共识：研报最高 TP $X vs 全街中位 $Z（+A%）、区间 $L–$H → 孤儿 / 不是孤儿
② 市场：现价 $P，日内 ±A%，近 20 日 ±C%，距 52 周高 −B%（同行中位 −M%，超额 ±F 个百分点；行业 ETF −E% 仅参考）→ 无背离 / 轮动错杀 / 逻辑被否 / 个股独立跑输 / 尚不可判
   （依据：同行 <T1 距高 −x%、T2 −y%、T3 −z%，为什么选它们；<若翻转>触发依赖同行选择>｜行业 ETF <距高 −e%>｜<news 事实或"召回失败">）
   <个股距高点 <10% 或近 20 日 ≥0 时不取同行快照，括号里只写「距高 <10%」或「近 20 日未跌」，第 2 条不适用>
③ KOL·内部人：<A 级 KOL n 人 m 帖，方向> ｜内部人近 90 天 n 买 n 卖（仅 Form4 P/S）｜国会近 90 天 n 人 n 笔（买 a / 卖 b）
   <返回没覆盖满 90 天时两处都改写「近 N 天（返回只覆盖到 <日期>）」>
   → 一致 / 分裂 / 无数据
④ 基本面：研报侧假设 <机构 EPS 较共识 ±X%>｜营收超预期 A%（主锚）｜EPS 口径：GAAP 一致 / ⚠️非 GAAP 错位（actual_eps vs epsDiluted）｜EPS 趋势 <方向>

【净信号】
· 锚哪个价：<共识中位还是研报 TP，为什么>
· 背离什么性质：<三分之一，附依据>
· 盯什么反向信号：<具体到可观测的事件/数据，不是"关注市场变化">

【口径声明】（强制，不可省）
· 研报侧可见 N 篇（单页 10 篇，<已翻页至尽头 ／ subject 已见尽、mention 未翻完 ／ 窗口内 subject 已见尽、窗口外未翻完 ／ 仅取首页>），去重后 M 家；<window> 窗口滤掉 K 篇 subject —— **仅取首页时家数是下界，不是全街覆盖**
· 分析师家数由 analyst_grades 去重估算，consensus_price 本身不提供家数
· <若有>news 召回失败，维度 2 判定不成立
· <若有>13F 环比未引用（report_period + 45 天未过，或只有 *_change_percent 恒 0 字段）；新季度申报未完成时绝对持仓也不引用
· <若有>引用的 caveats / risks / catalysts 等列表为截断后的前 n 条（全量见 detail_sections）
```

**简版卡**（`subject_reports=0`、只有行业报告点名时用；步骤 2–4 照跑，额度同完整跑）：

```
📇 <TICKER> 跨源读数卡（简版）· <日期>

【🔎 领读】
本标的近期无专题研究，以下不含研报候选层。<再 1–3 句判断：四维里哪条最该看>

【行业报告点名】（背景，不是候选）
<N 篇（<window> 窗口内 n 篇）｜窗口内 n 篇看作受益、m 篇看作受损（全部 N 篇：a 受益 / b 受损 / c 其他）｜最新一篇：<机构> <日期>——<rationale 一句>>

【四维对撞】
① 共识：现价 $P vs 全街中位 $Z（±A%）、区间 $L–$H｜分析师 grades 窗口内（同研报窗口）<n 维持 / n 上调 / n 下调>，其中财报日之前的升 / 降级单独标出（无研报 TP，不做孤儿判断）
② 市场：同完整卡
③ KOL·内部人：同完整卡
④ 基本面：营收超预期 A%（主锚）｜EPS 口径 ...｜EPS 趋势 <方向>（无研报侧假设）

【净信号】
· 锚哪个价：<只能锚共识中位，写明为什么不锚别的>
· 背离什么性质 / 盯什么反向信号：同完整卡

【口径声明】
· 研报库内无本标的专题研究（已翻页至尽头 / 仅取首页），行业报告点名不进评级统计
· 其余同完整卡
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

单次完整跑 = **3 额度**（研报 1 + fundamentals 1 + signal 1；news 0）。加 peers 快照则 4（个股距 52 周高 ≥10% 且近 20 日在跌、要算超额回撤时，或判「轮动错杀」时，都必加）。

## 已知边界

| 边界 | 性质 | 处置 |
|---|---|---|
| 单页 10 篇 / 去重后 3–5 家 | 上游单页硬顶（N-38）| **可翻页补全**（N-81，每页各 1 额度）。仅取首页时所有家数标下界；**需要全覆盖的信号（错位族/信念族）必须先翻完再做**。实测首页去重后：NVDA 3 家、INTC 5 家、GOOGL 5 家 |
| 孤儿阈值 1.3× 且 0.95× | **拍的，未回测**（2026-10-08 起两条同时满足才告警） | 同时输出原始百分比 + 跑「≥2 家同时触发则判中位滞后」的反向检查 |
| 榜单方向字段不可用 | 连带污染（N-39；字段 2026-08-04 改名为 `mention_impact`）| 本 Skill 全程不读榜单方向，只读钻取后的 `subject_reports`。⚠️ **也不读 `mention_reports[].rating_current`**——那是报告自己主角的评级 |
| **停止覆盖信号：未证实，不是做不了** | ⚠️ **2026-07-29 修正此前的错误断言**：`revision_summary.list_changes[]` **字段确实存在**（结构 `{action, list, security}`），此前写"MCP 无此字段"是错的 | 实测三标的只见到 `action` 为 `initiate`（Bernstein 07-27 组合名单）与 `add`（J.P. Morgan 加入 Positive Catalyst Watch），**未见到停覆类 action**。→ 表述为"**样本内未出现，机制上可能支持**"，出现时按库内时钟族读法处理；**不承诺一定能抓到**。<br>⚠️ **`remove` 已出现，但不是停覆**（2026-10-05 实测 MU）：Citi Research 08-03 `{action:"remove", list:"Upside 90-Day Catalyst Watch"}`，同篇维持 Buy、TP 1,400 不变——这是移出催化剂观察名单，读作「短期信心下降」，不能写成「停止覆盖」 |
| 方向翻转（错位族）做不了 | 需同机构前后比对，而只有 3–5 家可见、`rating_history` 只带 TP 不带 rating | 不做。**但 `revision_summary` 的 old→new TP 是可用的替代**（实测 INTC 两家真上调），已并入候选强度 |
| `subject_reports=0` | 真实分支（实测 F / ACN 全 mention）| 出简版卡（不含候选层，四维照做），行业报告点名只作背景。**且该状态会变**——GOOGL 07-23 为 0、07-29 为 6 |
