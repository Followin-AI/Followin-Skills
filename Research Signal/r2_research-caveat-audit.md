---
name: Research Caveat Audit (r2 — 研报口径审计器)
description: 拆一份（或一个标的的一批）卖方研报的口径，回答三件不会被媒体转述抄走的事：结论的基准是谁、数字的口径边界在哪、报告自己承认了什么偏差。输出可信度分档 + 高危表述清单，可独立跑，也可当 r1 信号卡的降权器。不复述结论，只审结论的地基。
trigger: 口径审计、这份研报靠谱吗、基准是谁、口径边界、研报可信度、自陈偏差、报告哪里没说、审一下研报、caveat audit、research audit
not_trigger: 研报讲了什么/帮我总结研报（→ Community c3）、跨源印证信号卡（→ r1）、催化剂（→ r3）、财报分析（→ Base 02）
mcp: mcp__followin__metrics
args: ticker(必填), focus(可选：报告标题关键词，只审匹配的那几篇)
---

# /r2-research-caveat-audit $ARGUMENTS

**研报库不做速度，做口径。**

> **版本**：v1.0 ｜ **实测验证于 2026-07-29**（NVDA 10 篇全量字段统计）
>
> **这支 Skill 存在的理由**（2026-07-22 实测定档）：研报端到端**落后公开新闻 1–4 天**，且卖方结论数日内即被媒体转述——同一篇伯恩斯坦韩国出口报告被 Investing.com 搬走，数字全对得上。
> **速度赛道不可能赢。** 真正不可替代的是结论背后不会被转述的三样：**①基准是谁 ②口径边界 ③自陈偏差**。本 Skill 只做这三样。

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
| 这个目标价能信吗（要跨源印证）| ❌ 转 [`r1_cross-source-signal-card`](./r1_cross-source-signal-card.md) |
| 接下来有什么催化剂 | ❌ 转 [`r3_catalyst-timeline`](./r3_catalyst-timeline.md) |

---

## 执行流水线（1 额度）

### 步骤 1 · 拉报告（1 额度）

```
metrics(query="<TICKER> research reports", verbosity="detail", asset_type="tradfi")
```

同 r1 步骤 1 的全部铁律：query 必带研报意图词（红线 12）／不传 `time_range`·`limit`（N-38 均无效）／`default_fanout_fallback` 警告是假阴性别重试（N-21）／机构名先归一再按「机构+标题+日期」去重（N-38 + N-3）。

> ✅ **与 r1 同源**：若本轮已跑过 r1，**直接复用它步骤 1 的返回，0 额度**。r2 用的字段（`key_caveat` / `coverage_flag` / `consensus_diff` / `content_truncated` / `novelty` / `detail.caveats` / `detail.risks`）r1 全都已经拉回来了。

### 步骤 2 · 四轴拆解（纯客户端，0 额度）

**⛔ 第一件事：把「报告没说」和「我们没抽到」分开。** 混淆这两者会把抽取窗口的限制说成报告的缺陷。

| 轴 | 取自 | 回答什么 |
|---|---|---|
| **① 基准是谁** | `key_caveat` + `detail.caveats[]` + `thesis` | 这个结论建立在什么之上？管理层口径 / 独立调研 / 建模估算 / 二手新闻 / 根本不是研究 |
| **② 口径边界** | `key_caveat` + `consensus_diff` + `detail.estimates[]` + `detail.data_points[]` | 数字覆盖到哪、没覆盖到哪？"强"是强在哪个口径上？和谁比的？ |
| **③ 自陈偏差** | `key_caveat` + `consensus_diff` 里的自我否定表述 | 报告自己承认了什么局限、什么数字对不上？ |
| **④ 抽取侧缺口** | `coverage_flag.completeness` + `coverage_flag.missing` + `content_truncated` | ⚠️ **这一轴是关于「我们看到了多少」，不是关于报告质量。单列，不进可信度打分。** |

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

**③ 自陈偏差**（🔴，本 Skill 最典型的产出）

| 原文 | 读法 |
|---|---|
| *"The report presents two upside figures for the same $150 target: Exhibit 4 shows 41.6%, while the page 4 snapshot shows 49.7% based on a $100.23 closing price."* | **同一个目标价，报告里两处算出两个上行幅度。** 而且 41.6% 隐含的现价与 49.7% 隐含的 $100.23 对不上——引用任一个都可能错 |
| *"Exhibit 6 is labeled as a Morgan Stanley-versus-consensus comparison, but the extracted rows contain values and percentage differences that do not reconcile; a reliable explicit consensus differential cannot be determined."* | **报告自己那张"我们 vs 共识"的表，数字对不上。** 任何引用该表差额的说法都不成立 |

> **媒体转述绝不会带上③里的任何一条**——这就是本 Skill 的全部价值所在。

### 步骤 3 · 高危表述扫描（纯客户端，0 额度）

扫 `thesis` / `novelty` / `detail.key_points[]` / `detail.data_points[]`，抓**三类最容易出问题的表述**。

> 依据：外部核验首轮抽 6 条，**3 条有问题——全部是报告本身的推断/表述问题，不是抽取错误**。内部校验器抓不到这类，只能靠这三条规则 + 人核。

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
可见 N 篇（去重后 M 家）｜上游硬顶 10 篇

【🔎 领读】（先写这段）
<2–4 句。这批报告的地基整体牢不牢？最该警惕的是哪一篇、为什么？
 必须是判断，不是"共 N 篇，其中 X 篇有问题"这种统计。>

【逐篇地基】
<机构> <日期>《<标题>》
  ① 基准：<管理层口径 / 独立调研 / 建模估算 / 第三方数据>——<原文一句>
  ② 口径边界：<和谁比、同口径吗、覆盖到哪>
  ③ 自陈偏差：<报告自己承认的局限，无则写"未自陈">
  可信度：🟢可直接引用 / 🟡引用须带限定 / 🔴地基有问题，别引结论

【高危表述】（跨全部报告汇总）
⚠️ 代理指标推断：<N 条，逐条列 + 代理链条>
⚠️ 绝对表述：<N 条，逐条列，标"待外部核验">
⚠️ 缺集中度限定：<N 条，标缺哪个限定>

【🧩 交叉读法】（**本 Skill 最有价值的一段，不可省**）
逐篇列完之后必须回答这三问——它们只有把几篇放在一起才看得出来：

· **地基强弱和结论激进程度对得上吗？**
  ⚠️ 最该警惕的形态是 **目标价越高、地基越薄**。给最高价的那家如果同时是"方法论不在本报告"
  或"信息源是管理层"，这个组合本身就是最强的降权信号——比任何单条 caveat 都硬。

· **几篇的 caveat 是不是指向同一个薄弱点？**
  多家不约而同回避同一件事（都不披露某项数据、都用同一个代理指标），说明那不是某家偷懒，
  **是这件事本身外部看不到**。此时"研报没说清"要读成"**整个市场在这个盲区里定价**"。

· **哪些结论跨过了可疑地基还站得住？**
  不是所有结论都建立在薄地基上。明确点出哪几条是硬的（有披露数据支撑）、哪几条只是转述。

【抽取侧缺口】（关于我们看到了多少，不是报告质量）
· content_truncated：N/M 篇被截断
· completeness 分布：high N 篇 / medium N 篇 / low N 篇
· 上游只给 10 篇，本标的实际被 X 篇研报覆盖（榜单口径，累计非窗口）
```

**可信度分档规则**（三档，只看①②③，**不看④**）：

| 档 | 条件 |
|---|---|
| 🟢 可直接引用 | 基准是独立调研或披露数据；口径边界清晰；无自陈偏差 |
| 🟡 引用须带限定 | 基准是管理层口径或建模估算；**或**口径边界不清 | 
| 🔴 别引结论 | 报告自陈数据对不上；**或**核心论点建立在未验证的代理指标上 |

**⛔ 硬要求**：

**1. 每条 caveat 都要配「读法」，不许只贴原文。** 原文是证据，读法才是产品。

| ❌ 贴原文 | ✅ 配读法 |
|---|---|
| "Q2 client strength was driven by favorable mix and ASP rather than unit growth" | "**'业绩强'的口径是卖得更贵，不是卖得更多。** 涨价能撑一个季度，撑不了一年——这条决定了这次 beat 能不能线性外推" |
| "directs readers to a separate publication for full valuation methodology" | "**全场最高价 $200 的算法不在这份报告里。** 你能看到结论，看不到它怎么来的" |
| "not a product of J.P. Morgan's Research Department" | "**这根本不是研报，是销售台评论**——不受研究部合规约束、没有评级体系。它长得和研报一模一样，这才是危险的地方" |

**2. 【交叉读法】不可省。** 逐篇列完只是半成品；本 Skill 的核心价值在**把几篇放在一起才看得出来的东西**——尤其"最激进的那家地基最薄"这种形态。

**3. 绝不把「我们没抽到」写成「报告没说」。** `content_truncated` 实测 **20/20 全为 True**——不区分的话每份报告都会被误判成不完整。

**4. 不复述结论。** 用户要结论去 c3；本 Skill 只出地基。

**5. 未自陈 ≠ 没问题**，只是这份报告没说。照写"未自陈"，不要推断成"无偏差"。

## 已知边界与待确认

| 项 | 性质 | 处置 |
|---|---|---|
| **四轴分类无法规则化** | **2026-07-29 实测：正则版 7 篇错 4 篇** | 必须由模型读原文语义判断，关键词只作召回提示。上面的校准样本库是唯一可靠的锚 |
| `coverage_flag.missing` 的作用域不明 | **待向 Dev 确认**：文案写的是 *"The report does not disclose…"*（指报告），但同一条记录 `content_truncated` 为 True（说明只抽了一部分）。**究竟是"报告没披露"还是"抽取到的部分没披露"，从数据本身判不出来** | 在澄清前，一律按"抽取侧缺口"处理（④轴），**不计入报告可信度打分**。这是保守侧错——宁可少扣分，不可把抽取限制栽给报告 |
| `completeness` 取值域未穷举 | 实测 20 篇（NVDA 10 + INTC 10）只见 `high`(8+) / `medium`(2+) | `low` 是否存在待观察；出现时按 🔴 提示人核 |
| `content_truncated` 实测 **20/20 全为 True** | 数据特性 | 恒为真 ⇒ **零判别力**，只能单列进④轴。若拿它扣分，每份报告都会被判不完整 |
| 内部校验器抓不到报告自身的推断错误 | 已知（外部核验首轮 3/6 命中全属此类）| 靠步骤 3 三类规则 + 步骤 4 外部核验，**不承诺自动化能兜住** |
| 只能审可见的 10 篇，且不一定给满 | 上游硬顶（N-38）| 审计结论标下界。实测 F 只返回 3 篇且全是 mention |
| `subject_reports=0` 时仍可审 | 实测 F 全 mention | mention 报告同样带 `key_caveat` / `coverage_flag` / `consensus_diff`，**照样可审**——F 的两条 🔴 基准问题就出自 mention 报告 |
