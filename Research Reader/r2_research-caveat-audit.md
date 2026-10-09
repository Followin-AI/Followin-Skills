---
name: Research Caveat Audit (r2 — 研报口径审计器)
description: 拆一份（或一个标的的一批）卖方研报的口径，回答三件不会被媒体转述抄走的事：结论的基准是谁、数字的口径边界在哪、报告自己承认了什么偏差。输出可信度分档 + 高危表述清单，可独立跑，也可当 r1 读数卡的降权器。不复述结论，只审结论的地基。
trigger: 口径审计、这份研报靠谱吗、基准是谁、口径边界、研报可信度、自陈偏差、报告哪里没说、审一下研报、caveat audit、research audit
not_trigger: 研报讲了什么/帮我总结研报（→ Community c3）、跨源印证读数卡（→ r1）、催化剂（→ r3）、财报分析（→ Base 02）
mcp: mcp__followin__metrics
args: ticker(必填), focus(可选：报告标题关键词，只审匹配的那几篇)
---

# /r2-research-caveat-audit $ARGUMENTS

**研报库不做速度，做口径。**

> **版本**：v1.1 ｜ 实测验证于 2026-07-29（NVDA 10 篇全量字段统计）｜ **2026-10-05 端到端复测**（NVDA，首页 + 第 2 页 + 30d 窗口）｜ **2026-10-08 换标的复测**（META，首页 + 第 2 页 + 30d 窗口，20 篇）｜ **2026-10-08 拍板后复跑**（MSFT，按新翻页口径 2 页 2 额度，subject 13 + mention 7）｜ **2026-10-09 第三轮拍板后复跑**（NVDA，`29d0140a` / `00ad0b37` 2 页 2 额度：两页全是 subject、第 2 页最旧 07-08 早于下限 07-11 → 因 90 天下限停页，subject 20 篇（下限内 18 篇 / 8 家），mention 未取到；GS 08-26 First Take 两篇 key_caveat 均为书目缺失 → 🟡，旧规则下会给 🟢（可见范围内））
>
> **这支 Skill 存在的理由**（2026-07-22 实测定档）：研报端到端**落后公开新闻 1–4 天**，且卖方结论数日内即被媒体转述——同一篇伯恩斯坦韩国出口报告被 Investing.com 搬走，数字全对得上。
> **速度赛道不可能赢。** 真正不可替代的是结论背后不会被转述的三样：**①基准是谁 ②口径边界 ③自陈与自相矛盾**。本 Skill 只做这三样。

## 参数

| 参数 | 必填 | 默认 | 说明 |
|------|------|------|------|
| ticker | ✅ | — | 美股代码 |
| focus | 否 | — | 报告标题关键词。**上游无按 event_id/标题取单份的入参**（红线 12），只能全量拉回来后客户端筛 |

## 一句话方法论

媒体能转述的是**结论**（"大摩给 288"）。转述不走的是：这个 288 建立在**管理层路演口径**上、AMD 的对比数字是**建模估算而非实测基准**、以及报告自己在 Exhibit 6 里**数字对不上**。

**本 Skill 不复述结论，只审结论的地基。**

## 意图路由

| 用户说的 | 走哪 |
|---------|------|
| 这份研报靠谱吗、基准是谁、哪里没说清 | ✅ 本 Skill |
| 研报讲了什么、帮我总结 | ❌ 转 `Community Skill/c3_research-hot` |
| 这个目标价能信吗（要跨源印证）| ❌ 转 [`r1_cross-source-readout`](./r1_cross-source-readout.md) |
| 接下来有什么催化剂 | ❌ 转 [`r3_catalyst-timeline`](./r3_catalyst-timeline.md) |

---

## 执行流水线（1–N 额度，通常 ≤3）

### 步骤 1 · 拉报告（1–N 额度，通常 ≤3：首页 1 + subject 翻页每页 1，翻到 90 天下限为止）

```
metrics(keywords=["<TICKER>"], query="research reports", verbosity="detail", asset_type="tradfi")
```

> 📦 **返回体积与游标位置（2026-10-05 实测）**：单页 `detail` 返回约 **85–90K 字符**（NVDA 首页 88,589 / 第 2 页 82,169），会超过工具输出上限被落盘——**用脚本按字段解析，不要整段读进上下文**。翻页游标在 `meta.pagination["fundamentals.research_reports"].next_cursor`（**键名本身含点**，不是 `meta.pagination.next_cursor`）；带 `cursor` 重查时 query / keywords / verbosity / limit 须与首页完全一致。

> 📄 **翻页口径（2026-10-08 定，2026-10-09 加 90 天下限）**：**subject 翻到尽头或 90 天下限，mention 只取 1 页**。
> · 首页 `has_more=false` 或首页已出现 mention → 停（1 额度）
> · 首页全是 subject、`has_more=true`，但首页最旧一篇 subject 已早于今天 −90 天 → 停（1 额度），按下面「因下限停页」写
> · 首页全是 subject 且 `has_more=true` → 带 cursor 翻下一页，直到某页出现 mention、`has_more=false`，**或该页最旧一篇 subject 的 `report_date` 早于今天 −90 天**（下限）——三者先到为准（通常 ≤3 额度；每页 +1，头部写实际额度）
> · 因下限停页时：那一页里早于下限的 subject 照常审，头部写"subject 翻到 90 天下限（<日期>），更早的未取"，subject 家数只算 90 天内全量；这时多半没带出 mention，写"mention 未取到（停在 90 天下限）"，**不为 mention 单独翻页**
> · 下限的由来：不传窗口时 subject 随库龄只增不减（2026-10-08 实测 MSFT 07-16 起 10 周 13 篇、NVDA 10-05 已 19 篇），不设下限的话额度会随库龄线性上涨
> · mention **只用 subject 见尽的那一页带出来的**（按日期倒序，就是最新的一批），不为 mention 单独翻页；产出头部写明"mention 只取 1 页，has_more=<值>"，mention 侧结论一律是下界

> 🔴 **取数前先认块（N-86，2026-08-12 实测）**：解析层会静默扩展出额外候选 ticker，**每个候选都是一个平级结果块，顺序不保证主匹配在前**（实测 `ASML.AS` 的 `[0]` 是空块、数据在 `[1]`）。
> ① ⛔ **禁止用 `research_reports[0]` 取数**　② 逐块比对 `query_ticker` == 本次标的，**只认相等的块**　③ ⛔ **禁止用 `meta.total` 判条数**（它数的是块）

同 r1 步骤 1 的全部铁律：query 必带研报意图词（红线 12）／`time_range` 已于 2026-08-03 修复可传，`limit` 单页仍被 10 硬顶，但 **2026-08-12 起返回体带 `meta.pagination.next_cursor`，可翻页枚举完**（N-81 销案）——按上方翻页口径，subject 家数是 90 天内全量，**mention 只取 1 页、标下界**（N-38 部分修复）／`default_fanout_fallback` 警告是假阴性别重试（N-21）／机构名先归一再按「机构+标题+日期」去重（N-38 + N-3）。

> ⚠️ **快评 + 完整版合并要补一条（2026-10-05 实测）**：r1 的「同机构 + 同日 + 同 TP」判据**漏掉"快评后完整版当天上调 TP"**——实测 GS 2026-08-26《First Take: Solid quarter…》TP 285，同日完整版 TP 285→300，TP 不同所以不会被合并。追加：**同机构 + 同日 + 任一篇标题含 First Take / Quick Take → 计家数时合并，以非快评那篇为准**；逐篇地基里快评可保留，但须注"已被同日完整版取代，别引其 TP"。
> 同批另见 N-3 复现：GS 两篇标题 / 日期 / TP 逐字相同、`event_id` 不同——服务端"按 event_id 去重"去不掉这种，客户端三元组去重照做。
> 标题含 **(Erratum) / Correction** 的勘误版同理：原稿也在库里时合并、以勘误版为准（2026-10-08 实测 Nomura 10-05《…(Erratum)》，`key_caveat` 自述"replaces an earlier note"）。

> 🔴 **排序与新鲜度（2026-10-05 实测）**：不传窗口时 `time_scope:"all_available_reports"`，且排序是 **subject 整层在前、各层内按 `report_date` 倒序**——NVDA 第 2 页要先排完到 07-07 的 9 篇 subject，才出现 09-28 的 mention。即**subject 满一页时，首页不会出现比 subject 更新的 mention**。实测 NVDA 首页最新一篇 08-27（距今 39 天），同时刻 `time_range="30d"` 返回 subject 0 / mention 10（09-24~09-28）。
> **subject 不足一页时反过来**（2026-10-08 实测 META）：首页 = subject 6 篇（07-02~09-24）+ 尾部直接接上最新 mention 4 篇（10-05~10-07）；第 2 页 subject 0、mention 10。所以：
> · **首页已出现 mention ⇒ subject 已见尽**，subject 侧不用再翻页；按翻页口径 mention 也不再翻
> · 30d 补查**不必跑**——META 的 30d 首页（subject 1 + mention 9）全部已在前两页里
> ① 产出头部**必须写报告日期区间与 `time_scope`**（模板已留位；subject 与 mention 混在一页时**两层的区间分开写**）
> ② 最新 subject 距今 **>21 天**时，【领读】第一句必须写"本批地基审计的是 <日期> 前的报告"
> ③ 不再单独补 30d：subject 翻到尽头的那一页自带最新一批 mention，已覆盖原先补 30d 的用途

> ✅ **与 r1 同源**：若本轮已跑过 r1，**直接复用它步骤 1 的返回，0 额度**。r2 用的字段（`key_caveat` / `coverage_flag` / `consensus_diff` / `content_truncated` / `novelty` / `detail.caveats` / `detail.risks`）r1 全都已经拉回来了。

### 步骤 2 · 四轴拆解（纯客户端，0 额度）

**⛔ 第一件事：把「报告没说」和「我们没抽到」分开。** 混淆这两者会把抽取窗口的限制说成报告的缺陷。

**0 号分流：先给 `key_caveat` 定性**（2026-10-05 实测新增）——`key_caveat` 不一定是报告的 caveat，有两类要先剔出去：

| 形态 | 实测原文 | 处置 |
|---|---|---|
| **抽取流程备注** | *"The supplied filename is rendered in English to comply with the output language requirement."*、*"Evidence comes from the supplied AI page-by-page digest; source references use its PDF page numbering."*（NVDA 30d 窗口 10 篇里占 6 篇）；*"Historical recommendations on page 4 are part of the non-research appendix and are excluded from revision and rating_history."*（2026-10-08 实测 DB 09-25，**不含上述字样**）| 含 filename / output language / page-by-page digest / supplied 字样，**或说的是抽取器怎么处理（提到 revision / rating_history 等字段名、"excluded from"）** → 归④轴、**不进打分**。该篇①②③改从标题 / `novelty` / `thesis` / `consensus_diff` / `detail.estimates.adjustments` 推断（实测 GS 09-20 的"管理层路演"基准只在标题《NDR Meetings…》和 novelty "NDR feedback indicates…" 里），并注"key_caveat 被流程备注占位"；`coverage_flag.missing` 只作线索、不计分（见已知边界） |
| **书目信息缺失** | *"The report does not provide a prior target price, prior report date…"*（GS 08-26 First Take ×2、BofA 07-07）；*"The research body does not state an explicit current equity rating or rating change…"*（2026-10-08 实测 UBS 10-01）| 只说缺前次 TP / 前次日期 / 评级或评级变动的 → 归④轴、**不计分**。别读成"地基薄" |
| **报告类型声明** | *"This is a cross-asset strategy study without company ratings, target prices…"*（Barclays 09-30）、*"The presentation is a multi-stock strategy review, not an explicit initiation or rating-change announcement."*（UBS 09-29）（2026-10-08 实测）| 不计分；①基准写"非个股研究，本标的只是论据之一" |
| **字段缺失** | 整篇没有 `key_caveat`，`detail.caveats` 与 `detail_sections.caveats` 也都不存在（2026-10-08 实测 META 20 篇中 1 篇：JPM 07-02）| ①③没有信源 → 写"key_caveat 未返回"进④轴，**不写"未自陈"**；该篇最高 🟡 |

> 2026-10-08 META 20 篇里 `key_caveat` 是流程备注的 **0 篇**；流程备注改出现在 `coverage_flag.missing` 尾部（*"The filename is rendered in English to comply with the English-only output requirement"*，2/20）——那本来就归④轴，不用另剔。
> **但 0 号分流不能省**：2026-10-08 MSFT 20 篇里 `key_caveat` 又有 3 篇是流程备注（GS 09-20、UBS 10-01 的 filename 句 + DB 09-25 的新形态），出现与否随批次变。

> 🔴 **mention 篇先认"这条 caveat 说的是谁"（2026-10-08 实测）**：mention 报告的 `key_caveat`、`rating_current`、`report_subject_target_price` 都属于**报告自己的主标的**，不是本标的——META 查询里 Nomura 的 Buy 是给 3406.TW 的、JPM 的 Overweight 是给 TSMC 的、GS 的 Buy 是给 SPCX 的；BofA 两份周报、Bernstein 数据中心报告的③b（指数回报、2030 年 IT-GW 两处对不上）都和 META 无关。本标的的东西只有 `mention_context`（一句话 + `mention_direction`）和 `matched_asset_target_price`（多数为 null，偶有值：Bernstein 10-01 给 META 800）。所以：
> ① mention 篇先判 `key_caveat` 是否涉及本标的；**不涉及 → 不进本标的打分**，④轴记"N 篇 caveat 指向报告主标的"
> ② mention 篇只审 `mention_context` 那一句的基准（"is believed by BofA to be the customer" 是推测、"modeled capex" 是建模、"benchmark score" 是第三方跑分），逐篇地基**压成一行**
> ③ ⛔ 不许把 mention 篇的 `rating_current` / `report_subject_target_price` 当本标的的评级 / TP
> ④ mention 篇的③b（报告内数字对不上）若与本标的的那句同出一个模型（2026-10-08 实测 MSFT：Bernstein 10-01 的 2030 年 IT-GW 149 vs 160，MSFT 的 "modeled capex" 是同一模型的输入）→ 判**部分涉及、不计分**，在④轴注明，该篇 `mention_context` 那一行加"所在模型内部有数字对不上"

| 轴 | 取自 | 回答什么 |
|---|---|---|
| **① 基准是谁** | `key_caveat` + `thesis`（`detail.caveats[]` 见下方截顶说明）| 这个结论建立在什么之上？管理层口径 / 独立调研 / 建模估算 / 二手新闻 / 根本不是研究 |
| **② 口径边界** | `key_caveat` + `consensus_diff` + **`detail.estimates.adjustments`**（倍数 / 假设变动）+ `detail.data_points[]` | 数字覆盖到哪、没覆盖到哪？"强"是强在哪个口径上？和谁比的？ |
| **③ 自陈与自相矛盾** | `key_caveat` + `consensus_diff` 里的自我否定表述 + `detail.scenarios` 里抽取器的对不上标注（2026-10-08 实测 MS 09-16 熊市情景 *"labels valuation approximately 11x in the heading and approximately 12x in the narrative"*，只出现在这里）| 拆两项：**③a 报告自陈的局限**（报告自己写的）／**③b 报告内部数字对不上**（抽取器检出、未经人核——措辞写"抽取时发现报告内…"，**不许写"报告自己承认"**）|
| **④ 抽取侧缺口** | `coverage_flag.completeness` + `coverage_flag.missing` + `content_truncated` + `detail_sections` 截顶比 + 0 号分流剔出的两类 | ⚠️ **这一轴是关于「我们看到了多少」，不是关于报告质量。单列，不进可信度打分。** |

> 🔴 **`detail` 数组固定截顶（2026-10-05 实测）**：`detail.caveats` **只返回 1 条，且与 `key_caveat` 逐字相同**（实测 20/20）；真实条数在 `detail_sections.caveats`（实测 2–4；2026-10-08 META 3–8，20 篇里 19 篇仍是 1 条 = `key_caveat`）。`risks` / `key_points` / `data_points` / `catalysts` / `chart_takeaways` 同样截顶（2 / 3 / 3 / 2 / 2，对 `detail_sections` 的 5–8 / 8 / 12–15 / 5–6 / 3–7）。**改 `limit`、query 加 caveats/risks 字样都取不全**。因此：
> ① ①③轴实际只有 `key_caveat` 一条信源；
> ② `detail_sections.caveats > 1` 的报告，"未自陈"一律写成「**仅见 1/N 条 caveat**」；
> ③ 步骤 3 的扫描覆盖率（如 "key_points 3/8、data_points 3/12"）写进④轴。
> 另：`detail.estimates` 是对象 `{adjustments, eps, growth, revenue}` 不是数组；**`adjustments` 是②轴最有用的一格**（实测 BofA 倍数 27x→22x、MS 22x→20x 只出现在这里；2026-10-08 META：JPM 09-24 TP 820→920 只靠倍数 23x→26x、"no explicit earnings or revenue estimate revisions" 也只在这里）。
> ⚠️ **`detail_sections` 计数 ≥1 不保证字段返回（2026-10-08 实测 META 20 篇）**：`consensus_diff` 8 篇整个缺失（`detail_sections.consensus_diff` 却都是 1）、`detail.scenarios` 5 篇缺失（sections 都是 3）。缺失时写"consensus_diff 未返回"进④轴，**不写"报告没和共识比"**。
> 2026-10-08 MSFT 20 篇同形态更重：`consensus_diff` 9 篇缺失；`detail.estimates` **整个缺失** 2 篇（DB 09-25、UBS 10-02，sections 都是 4）、有 `estimates` 但没有 `adjustments` 2 篇（GS 09-20、MS 09-16）——**最新 3 篇 subject 的②轴都拿不到 `adjustments`**；`scenarios` 缺失 4 篇、只回一部分 2 篇（GS 09-20 只有 base）。缺哪格写哪格"未返回"。

> ⛔ **这四轴不能用关键词规则做，必须由模型读 `key_caveat` 原文语义判断。**
> **2026-07-29 实测**：把上表写成正则规则跑 INTC 7 篇，**7 篇里错了 4 篇**——
> Bernstein 那条教科书级的口径边界（"强是靠 mix 和 ASP 不是销量"）**被判成 🟢 可直接引用**；
> Morgan Stanley 的"尚未成为正式指引"**被误判成 🔴**。
> 关键词只能用作**召回提示**（哪些篇值得细看），**分档必须靠语义**。下面的样本库是校准用的，不是匹配表。

### 校准样本库（全部为 2026-07-29 实测原文，逐条给出正确分档与读法）

**① 基准是谁**

| 原文（`key_caveat`）| 分档 | 读法 |
|---|---|---|
| *"This material is Specialist Sales commentary and says it is not a product of J.P. Morgan's Research Department."* | 🔴 | **这根本不是研究报告**，是销售台的评论。不受研究部合规约束、无评级体系。**本轮最硬的一条**——它长得跟研报一模一样 |
| *"This is a weekly industry tracker based largely on summarized third-party news items rather than a formal valuation note."* | 🔴 | **二手新闻汇编**。里面的"观点"是别人的新闻，不是这家机构的研究判断 |
| *"The report is based substantially on management commentary from an investor NDR."* | 🟡 | 信息源是**管理层路演**。管理层说"增速在加快"当然会这么说；**卖方转述一遍不构成第二个信源** |
| *"The quick take was published before the scheduled earnings call, so management commentary … was still pending."* | 🟡 | **电话会前发的快评**，管理层还没开口。结论只基于财报数字 |
| *"The report directs readers to a separate publication for full valuation methodology and detailed risks."* | 🟡 | **估值方法和风险不在这份报告里**。目标价怎么来的，本文没交代 |

**② 口径边界**

| 原文 | 分档 | 读法 |
|---|---|---|
| *"Q2 client strength was driven substantially by favorable mix and ASP rather than unit growth."* | 🟡 | **"强"的口径是产品结构和售价，不是卖得更多。** 同一个"强"字，投资含义完全不同——这条最容易被转述抹平 |
| *"AMD throughput comparisons are modeled estimates rather than disclosed independent benchmark results."* | 🟡 | 那张"完胜竞品"的对比图是**分析师自己建模算的**，不是跑分。换个假设结论可能翻转 |
| *"Intel does not disclose external foundry engagements because of customer sensitivity."* | 🟡 | 代工客户**公司不披露** → 任何关于代工订单的推断都是外部推测 |
| *"Management's CY2027 capital-spending and free-cash-flow outlook was not yet presented as a firm forecast."* | 🟡 | 那个 CY2027 数字**不是正式指引**，是会上随口提的量级。当指引引用就错了 |
| *"The $14B-$18B opportunity is a hypothetical scenario based on Apple Watch-like adoption and a $400 ASP, rather than a formal incremental revenue forecast embedded in the financial model."*（2026-10-08 实测 Jefferies META）| 🟡 | 标题级的 "$140–180 亿眼镜生意" **没进它自己的财务模型**，是类比 Apple Watch 的假设情景。TP 不靠它——转述成"Jefferies 预测"就错了 |

**③ 自陈与自相矛盾**（本 Skill 最典型的产出）

> ⚠️ 下面两条都属 **③b（抽取器在报告里检出的数字不一致）**，不是报告自己承认的——转述时写"抽取时发现报告内两处对不上"。2026-10-05 NVDA 复测同形态再现：GS 08-26 *"Exhibit 4 shows 37.6% base-case upside, while the price-target summary shows 43.1% upside from the August 26 close of $209.66"*；MS 08-27 摘要表营收 $81.615B vs 正文 $96.221B（只影响该表 → 按下方分档规则降为 🟡）。
> ③a 的实测例：HSBC 08-20 *"The USD500bn financing framework does not represent USD500bn of incremental NVIDIA revenue…"*——报告自己给自己的数字打折。

| 原文 | 读法 |
|---|---|
| *"The report presents two upside figures for the same $150 target: Exhibit 4 shows 41.6%, while the page 4 snapshot shows 49.7% based on a $100.23 closing price."* | **同一个目标价，报告里两处算出两个上行幅度。** 而且 41.6% 隐含的现价与 49.7% 隐含的 $100.23 对不上——引用任一个都可能错 |
| *"Exhibit 6 is labeled as a Morgan Stanley-versus-consensus comparison, but the extracted rows contain values and percentage differences that do not reconcile; a reliable explicit consensus differential cannot be determined."* | **报告自己那张"我们 vs 共识"的表，数字对不上。** 任何引用该表差额的说法都不成立 |

> **媒体转述绝不会带上③里的任何一条**——这就是本 Skill 的全部价值所在。

### 步骤 3 · 高危表述扫描（纯客户端，0 额度）

扫 `thesis` / `novelty` / `detail.key_points[]` / `detail.data_points[]`，抓**三类最容易出问题的表述**。

> 依据：外部核验首轮抽 6 条，**3 条有问题——全部是报告本身的推断/表述问题，不是抽取错误**。内部校验器抓不到这类，只能靠这三条规则 + 人核。
>
> ⚠️ **扫描覆盖不全（2026-10-05 实测）**：`key_points` 只返回 3/8、`data_points` 3/12–15（见步骤 2 截顶说明），本步实际只扫到约三分之一。**覆盖比写进④轴**，"未发现高危表述"只能写成"在可见的 N/M 条里未发现"。

| 类别 | 特征 | 为什么危险 | 处置 |
|---|---|---|---|
| **代理指标推断** | 用 A 的数据推 B 的结论（出口数据推某产品需求、行业产能推单一公司份额）| 代理与目标之间的映射常常没被验证。实测反例：韩国海关 multichip memory 数据**没拆 HBM**，拿它推 HBM 需求就是错的 | 标出代理链条，问"这个映射报告验证过吗" |
| **绝对表述** | 含「首次 / 唯一 / 从未 / 没有迹象 / 全部 / 无一」| 绝对表述只要一个反例就崩，而卖方极少穷举。实测靠自陈偏差才判出「海力士无 HBM4」那条推断错在哪 | 逐条列出，标为**待外部核验** |
| **缺集中度限定的大额数字** | 单一大额数字（合同额 / TAM / 订单）不带客户集中度、时间分摊、确认口径 | "$97 亿合同"可能是五年、可能单一客户、可能含选择权 | 标出缺哪个限定 |

### 步骤 4 · 外部核验（可选 · Tier-3 · 0 MCP 额度）

对步骤 3 抓出的**绝对表述**与**代理指标推断**，用 `WebSearch` 找独立信源对照。

> 这是研报库周报的固定动作（§7.14），**不是本 Skill 的必跑步骤**——单标的即时查询时通常跳过，做深度审计或要对外引用时才跑。
> ⚠️ 找不到反证 ≠ 结论成立。写"未找到独立信源"，不要写"已核实"。

---

## 输出：口径审计卡

```
🔍 <TICKER> 研报口径审计 · <日期>
可见 N 篇（去重后 M 家）｜报告日期 subject <最早>~<最新> ／ mention <最早>~<最新>｜time_scope=<值>｜额度 <实际次数>｜subject <已翻至尽头 ／ 翻到 90 天下限 <日期>>（共 K 页）｜mention 只取 1 页，has_more=<true/false>（mention 侧为下界）
<最新 subject 距今 >21 天时加一行：⚠️ 本批地基审计的是 <日期> 前的报告>

【🔎 领读】（先写这段）
<2–4 句。这批报告的地基整体牢不牢？最该警惕的是哪一篇、为什么？
 必须是判断，不是"共 N 篇，其中 X 篇有问题"这种统计。>

【逐篇地基】
<机构> <日期>《<标题>》
  ① 基准：<管理层口径 / 独立调研 / 建模估算 / 第三方数据>——<原文一句>
  ② 口径边界：<和谁比、同口径吗、覆盖到哪>
  ③ 自陈与自相矛盾：③a <报告自己承认的局限> ／ ③b <抽取时发现报告内对不上的数字>
     无则写"未自陈（仅见 1/N 条 caveat）"
  可信度：🟢可直接引用 / 🟢（可见范围内） / 🟡引用须带限定 / 🔴地基有问题，别引结论

【高危表述】（跨全部报告汇总）
⚠️ 代理指标推断：<N 条，逐条列 + 代理链条>
⚠️ 绝对表述：<N 条，逐条列，标"待外部核验">
⚠️ 缺集中度限定：<N 条，标缺哪个限定>

【🧩 交叉读法】（**本 Skill 最有价值的一段，不可省**）
逐篇列完之后必须回答这三问——它们只有把几篇放在一起才看得出来：

· **地基强弱和结论激进程度对得上吗？**
  ⚠️ 最该警惕的形态是 **目标价越高、地基越薄**。给最高价的那家如果同时是"方法论不在本报告"
  或"信息源是管理层"，这个组合本身就是最强的降权信号——比任何单条 caveat 都硬。
  📌 TP 取 `matched_asset_target_price.new`（旧字段 `target_price` 已拆分，N-79）。**同机构多篇只取最新一篇**（同 r1 步骤 4）。
  📌 **TP 的目标年份 / EPS 基年不同就不能直接比高低**（2026-10-08 实测 META：JPM 07-12 $725 = Dec-2026 目标、21x 2027E；
     JPM 09-24 $920 = Dec-2027 目标、26x 2028E；DB / Jefferies 是 23x FY27）——比激进程度看「倍数 × 哪一年 EPS」，
     从 `detail.data_points` / `estimates.adjustments` / `scenarios` 里取，取不到就写"目标期限未抽到"。
  📌 先按最近一次财报日（标题含 Preview / Recap / Quick Take，或 `2Q26` 式季度标签，或 `key_caveat` / `novelty` 提到 earnings call 可判）
     把报告分成"财报前 / 财报后"两组，**组内再比激进程度**——财报前的 TP 没吃到财报信息，跨组比高低会误判。
     （META 无一篇标题带 Preview / Recap，靠 Bernstein 07-29《Meta 2Q26…》+ key_caveat "The earnings call…" 才定出 07-29；都判不出就写"财报日未定"、不分组）
  📌 `matched_asset_target_price.old` ≠ 同机构上一篇可见报告的 `new` ⇒ **中间有一篇库里没有**（META：JPM 07-12 Neutral $725 → 09-24 "reiterate" Overweight、old $820，
     那次评级上调 + TP 上调不在库里）。写进④轴；`rating_action:"reiterate"` 只是相对那篇缺失的报告而言。
  📌 最高价的方法论在返回字段里看不到时，先看 `detail_sections.caveats` 是否 >1：是 → 写"未抽到"，不写"报告没给"。

· **几篇的 caveat 是不是指向同一个薄弱点？**
  多家不约而同回避同一件事（都不披露某项数据、都用同一个代理指标），说明那不是某家偷懒，
  **是这件事本身外部看不到**。此时"研报没说清"要读成"**整个市场在这个盲区里定价**"。

· **哪些结论跨过了可疑地基还站得住？**
  不是所有结论都建立在薄地基上。明确点出哪几条是硬的（有披露数据支撑）、哪几条只是转述。

【抽取侧缺口】（关于我们看到了多少，不是报告质量）
· content_truncated：N/M 篇被截断
· completeness 分布：high N 篇 / medium N 篇 / low N 篇
· detail 截顶：caveats 每篇仅见 1/N 条；高危扫描覆盖 key_points 3/8、data_points 3/12（按实际填）
· key_caveat 被流程备注占位 N 篇 ／ 书目缺失类 N 篇 ／ 类型声明 N 篇 ／ 字段缺失 N 篇（0 号分流剔出，不计分）
· mention 篇 caveat 指向报告主标的 N 篇（不进本标的打分）；与本标的同一模型、部分涉及 N 篇（不计分，逐条列）；consensus_diff 未返回 N 篇
· 库里缺的中间报告：<机构 old TP 对不上上一篇可见 new 的，逐条列>
· 覆盖面：subject <全量 ／ 90 天内全量>（K 页）；mention 只取 1 页，has_more=<true/false>；榜单口径覆盖数需 r0（本轮未取）
```

**可信度分档规则**（三档，🟢 分两级；只看①②③，**不看④**）：

| 档 | 条件 |
|---|---|
| 🟢 可直接引用 | 基准是独立调研或披露数据；口径边界清晰；**且 `detail_sections.caveats` 所示的全部 caveat 都已读到、均不涉及①③**。`key_caveat` 未返回或被 0 号分流剔出的篇同样不适用（`detail_sections.caveats` 为 1 时那唯一一条就是被剔出的那条），最高 🟡，见下一行 |
| 🟢（可见范围内） | 前两条同上；**可见的 caveat 不涉及①③，但只见 1/N 条**（截顶下的常态）。必须带括注，写"仅见 1/N 条 caveat"——硬要求 5：未自陈 ≠ 没问题。`key_caveat` 未返回、或被 0 号分流剔出（书目缺失 / 流程备注 / 类型声明）的篇不适用——没有真实 caveat 可看，最高 🟡（2026-10-09 定；MSFT 按此 🟢（可见范围内）0/13，原给的 Citi 07-30、GS 07-29 两篇 key_caveat 都是书目缺失类）|
| 🟡 引用须带限定 | 基准是管理层口径或建模估算；**或**口径边界不清；**或** ③b 只涉及辅助表格（注"引用该表前核对正文"）| 
| 🔴 别引结论 | ③b 涉及**目标价、上行幅度或核心预测**；**或**核心论点建立在未验证的代理指标上 |

> 📌 可见那条 caveat 本身是**②轴口径限定**的（"beat 部分来自投资收益""分部调整只是重分类"这类），按校准样本库 ② 全部 🟡 给 🟡、引用时带上那条限定——**不给 🟢（可见范围内）**（2026-10-08 实测 MSFT：Barclays / MS / Bernstein 共 4 篇属此类）。
> 📌 代理指标只撑起核心论点**其中一条腿**、其余腿有披露数据时给 🟡，并注"单引那条腿就是 🔴"（实测 Bernstein 08-10：容量增速那条用总物业面积代理，租约起租期 / 采购承诺两条是披露数据）。

**⛔ 硬要求**：

**1. 每条 caveat 都要配「读法」，不许只贴原文。** 原文是证据，读法才是产品。

| ❌ 贴原文 | ✅ 配读法 |
|---|---|
| "Q2 client strength was driven by favorable mix and ASP rather than unit growth" | "**'业绩强'的口径是卖得更贵，不是卖得更多。** 涨价能撑一个季度，撑不了一年——这条决定了这次 beat 能不能线性外推" |
| "directs readers to a separate publication for full valuation methodology" | "**全场最高价 $200 的算法不在这份报告里。** 你能看到结论，看不到它怎么来的" |
| "not a product of J.P. Morgan's Research Department" | "**这根本不是研报，是销售台评论**——不受研究部合规约束、没有评级体系。它长得和研报一模一样，这才是危险的地方" |

**2. 【交叉读法】不可省。** 逐篇列完只是半成品；本 Skill 的核心价值在**把几篇放在一起才看得出来的东西**——尤其"最激进的那家地基最薄"这种形态。

**3. 绝不把「我们没抽到」写成「报告没说」。** `content_truncated` 实测**累计 49/49 全为 True**（07-29 的 20 篇 + 2026-10-05 复测 NVDA 首页 10 篇去掉 1 篇重复 + 2026-10-08 META 20 篇）——不区分的话每份报告都会被误判成不完整。

**4. 不复述结论。** 用户要结论去 c3；本 Skill 只出地基。

**5. 未自陈 ≠ 没问题**，只是这份报告没说。照写"未自陈"，不要推断成"无偏差"。

## 已知边界与待确认

| 项 | 性质 | 处置 |
|---|---|---|
| **四轴分类无法规则化** | **2026-07-29 实测：正则版 7 篇错 4 篇** | 必须由模型读原文语义判断，关键词只作召回提示。上面的校准样本库是唯一可靠的锚 |
| `coverage_flag.missing` 的作用域不明 | **待向 Dev 确认**：文案写的是 *"The report does not disclose…"*（指报告），但同一条记录 `content_truncated` 为 True（说明只抽了一部分）。**究竟是"报告没披露"还是"抽取到的部分没披露"，从数据本身判不出来** | 在澄清前，一律按"抽取侧缺口"处理（④轴），**不计入报告可信度打分**。这是保守侧错——宁可少扣分，不可把抽取限制栽给报告 |
| `completeness` 取值域未穷举 | 实测 20 篇（NVDA 10 + INTC 10）只见 `high`(8+) / `medium`(2+)；2026-10-05 复测 NVDA 首页 high 9 / medium 1；2026-10-08 META 20 篇 high 16 / medium 4，仍无 `low` | `low` 是否存在待观察；出现时按 🔴 提示人核 |
| `content_truncated` 实测**累计 49/49 全为 True** | 数据特性（2026-10-05、2026-10-08 复测仍成立）| 恒为真 ⇒ **零判别力**，只能单列进④轴。若拿它扣分，每份报告都会被判不完整 |
| `detail` 数组固定截顶 | **2026-10-05 实测**：caveats 恒 1 条（= `key_caveat`）、risks 2、key_points 3、data_points 3；改 `limit` / query 无效 | 见步骤 2 截顶说明；①③轴只有一条信源，"未自陈"写成"仅见 1/N 条"，🟢 只能给到「🟢（可见范围内）」 |
| `key_caveat` 被流程备注 / 书目缺失占位 | **2026-10-05 实测**：30d 窗口 10 篇里 6 篇是流程备注 | 步骤 2 的 0 号分流先剔出，归④轴 |
| 不传窗口时 subject 整层在前 | **2026-10-05 实测**：首页全是 subject，最新可能已是一个多月前；**2026-10-08 实测** subject 不足一页（META 6 篇）时首页尾部即接最新 mention | 头部写日期区间 + `time_scope`；>21 天领读首句声明；不再补 30d——首页全是 subject 时按翻页口径翻到出现 mention 为止（2026-10-08 实测 MSFT：首页 subject 10，第 2 页 subject 3 + mention 7） |
| mention 篇字段的归属 | **2026-10-08 实测**：`key_caveat` / `rating_current` / `report_subject_target_price` 属报告主标的（META 14 篇 mention 里多数如此）| 见步骤 2 mention 规则：只审 `mention_context`，不涉及本标的的 caveat 不计分 |
| 内部校验器抓不到报告自身的推断错误 | 已知（外部核验首轮 3/6 命中全属此类）| 靠步骤 3 三类规则 + 步骤 4 外部核验，**不承诺自动化能兜住** |
| 单页只有 10 篇，且不一定给满 | 上游单页硬顶（N-38）| **subject 翻到尽头或 90 天下限、mention 只取 1 页**（N-81 + 2026-10-08 翻页口径 + 2026-10-09 下限）。mention 侧结论标下界。实测 F 首页只返回 3 篇且全是 mention |
| `subject_reports=0` 时仍可审 | 实测 F 全 mention | mention 报告同样带 `key_caveat` / `coverage_flag` / `consensus_diff`，**照样可审**——F 的两条 🔴 基准问题就出自 mention 报告。但先判 caveat 说的是不是本标的（见上一行）|
