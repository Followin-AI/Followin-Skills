---
name: Research Supply-Chain Read-Through (r4 — 研报产业链读穿)
description: 单标的产业链关联图。回答"这批研报把我的标的放在什么位置上、它的上下游谁在被改价、为什么被点名"。三层产出：关系边（为什么提到它）+ 同链修正（链上谁被改了目标价）+ 跨标的催化剂。数据来自 mention 报告，与 r1 共用同一次调用。
trigger: 产业链、上下游、读穿、关联标的、谁受益、链上还有谁、被谁提到、供应链视角、supply chain、read-through
not_trigger: 这个目标价能信吗（→ r1）、研报口径（→ r2）、催化剂时间线（→ r3）、研报榜（→ Community c3）、财报季扫描（→ Earnings Screener）
mcp: mcp__followin__metrics
args: ticker(必填)
---

# /r4-supply-chain-readthrough $ARGUMENTS

**别人的研报里，你的标的被放在什么位置上。**

> **版本**：v1.0 ｜ **实测验证于 2026-07-29**（NVDA / INTC / GOOGL / 2330.TW 四标的交叉验证）
>
> ⚠️ 本 Skill 的设计**被实测推翻过两次**，两条都写在下面的「⛔ 两个反直觉前提」里。
> 不先读那节就照直觉用，会得出系统性错误的结论。

## 参数

| 参数 | 必填 | 默认 | 说明 |
|------|------|------|------|
| ticker | ✅ | — | 单个标的。**本 Skill 不做批量**——产出高度依赖当次 mention 报告的构成 |

## ⛔ 两个反直觉前提（先读这节）

### 前提 1：产业链信息全在 `mention_reports` 里，不在 `subject_reports` 里

实测 30 篇 subject 报告，`revision_summary.by_name[]` **几乎恒为 1 条**（就是标的自己）。
跨标的修正、关系边、方向判定——**全部来自 mention 报告**，也就是那些"主题是别人、只顺带提到你"的报告。

**含义**：本 Skill 消费的正是 r1 明确禁止用于评级统计的那部分数据（N-19/N-39）。这不矛盾——
**mention 数据不能当评级票，但可以当叙事关系图**。这是它唯一的正当用法。

### 前提 2：⚠️ **查"枢纽票"拿不到产业链——这条与直觉完全相反**

原设计是"查台积电这类枢纽，收割整条链"。**实测证伪**：

| 标的 | 榜单位置 | subject | mention | 关系边 | 真链修正 | 对手方 |
|---|---|---|---|---|---|---|
| **2330.TW 台积电** | 第 4（70 篇 / 17 家）| **10** | **0** | **0** | **0** | 3 |
| INTC | 第 6 | 7 | 3 | 3 | **16** | **16** |
| NVDA | 第 1（125 篇 / 23 家）| 6 | 4 | 4 | 6 | 9 |
| GOOGL | 第 2 | 6 | 4 | 4 | 5 | 5 |

**根因**：**10 篇硬顶是 subject 与 mention 共享的**（N-38）。台积电的专题报告太多，10 个名额全被 subject 占满，
mention 一篇都挤不进来——而产业链信息全在 mention 里。

**所以：被专题覆盖淹没的标的，恰恰拿不到产业链视角。**
真正高产的是**有覆盖但没刷满 10 篇**的标的（INTC 型）。

> 📌 **不要用榜单排名挑标的跑本 Skill。** 榜单排名越高，越可能是 2330.TW 那种"全是 subject、零 mention"的形态。
> **产出多少只能跑完才知道**，跑之前先看 `mention_report_returned_count`——为 0 就直接走降级分支。

---

## 执行流水线（1 额度）

### 步骤 1 · 拉报告

```
metrics(query="<TICKER> research reports", verbosity="detail", asset_type="tradfi")
```

同 r1 步骤 1 的全部铁律（红线 12 研报意图词 ／ N-38 不传 `time_range`·`limit` ／ N-21 假阴性警告别重试）。

> ✅ **与 r1/r2/r3 同源**：本轮跑过任一支的话，**直接复用返回，0 额度**。

**先看 `mention_report_returned_count`**：

- **= 0** → 走**降级分支**（见步骤 5），只能从 subject 报告的 `detail.catalysts[]` 里捞跨标的节点，产出很少。照实说明。
- **≥ 1** → 正常流程。

### 步骤 2 · ⛔ 汇编闸：把「同框噪音」和「真产业链」分开

**这是本 Skill 最重要的一道闸。不加这道闸，输出会系统性错误。**

实测：查 NVDA 拿到 12 条带 old→new 的跨标的修正，内容是——
**印尼棕榈油（Triputra Agro −7.4%）、印度银行（IDFC First +11.8%、Bank of Baroda −6.7%）、印度钢铁、印尼制药、韩国船舶（Hanwha Ocean −16%）**。

**这些跟英伟达毫无关系。** 它们只是恰好和 NVDA 出现在同一份《Asia Morning News & Research Views》里。

**闸的规则**——看 `subject_name` 与 `report_type`：

| 形态 | 判定 | `by_name` 怎么用 |
|---|---|---|
| `subject_name` 是**汇编标题**：含 `morning news` / `portfolio` / `quant` / `weekly` / `daily` / `views` 等<br>实测样例：`"Asia Morning News and Research Views"`、`"Asia Quant + Fundamental Portfolio for 2H26"` | 🚫 **同框噪音** | **整个丢弃。** 同一份晨报里的名字之间没有产业链关系 |
| `subject_name` 是**具体公司或具体产业主题**<br>实测样例：`"Global AI memory strategic partnerships"`、`"Taiwan mature-node foundries and semiconductor design"`、`"Nokia"`、`"Apple Inc."` | ✅ **真产业链** | 全部可用 |

**闸的效果（实测）**：NVDA 30 条噪音 / 6 条真链；INTC **0 条噪音 / 16 条真链**；GOOGL 17 条噪音 / 5 条真链。
**不加闸，NVDA 的输出里 83% 是无关名字。**

> ⚠️ **关键词表是启发式，不是白名单。** 遇到新的汇编标题形态要补进去。
> 判别原则：**这份报告有没有一个统一的研究主题？** 有 → 里面的名字彼此相关；没有（只是"今天的一堆事"）→ 不相关。
>
> ✅ **无论闸判成什么，`mention_context.rationale` 永远保留**——见步骤 3。汇编报告的 rationale 照样是真信息，
> 被丢弃的只是它的 `by_name` 名单。

### 步骤 3 · 关系边：为什么这份报告提到我的标的

取每篇 mention 报告的 `mention_context`：`{mention_direction, mention_rating, rationale, context_snippet}`。

**`rationale` 是本 Skill 质量最高的字段**——实测它给的是**机制描述，不是标签**：

- *"NVIDIA is Nokia's development partner for the open, programmable, O-RAN-compliant AI-RAN platform."*
- *"Google's resilient Chrome traffic supports continued TAC payments to Apple."*
- *"Intel Foundry is seeing improving customer interest because TSMC leading-edge capacity is tight."*
- *"Intel is a potential 3nm collaboration partner for UMC, but Bernstein considers a joint project unlikely because UMC lacks 7nm and 5nm capabilities."*

每一条都是一条 **A → B 的因果边**，带方向（`mention_direction`：`beneficiary` / `negative` / `neutral`）。
这些边合起来就是"这批研报眼里，你的标的嵌在什么结构里"。

> ⚠️ **`mention_rating` 常为 `"Not rated"` 或 `None`** —— 顺带提到不等于给评级。**绝不能标成机构评级**（N-39）。
> ⚠️ 注意上面第 4 条：rationale **自带否定**（"Bernstein 认为不太可能"）。**别只读前半句**，方向要以整句为准。

### 步骤 4 · 同链修正 + 跨标的催化剂

**同链修正**：过闸后的 `by_name[]`。

| 字段 | 实测覆盖率 | 说明 |
|---|---|---|
| `ticker` / `name` | 96/96 | 恒有 |
| `rating_action` | 94/96 | 恒有，但多为 `reiterate` |
| `new_target_price` | 89/96 | 常有 |
| **`old_target_price` + `change_pct`** | **25/96（26%）** | **只有四分之一带真修正**——有 old→new 的才叫"被改价"，只有 new 的是"当前目标价" |

**两类要分开写**，别混成一句"N 家被改价"：
- **真修正**（带 old→new）：实测 INTC 拿到 UMC **47→88（+87.2%）**、VSMC **94→146（+55.3%）**、Novatek **370→480（+29.7%）**
- **当前价位**（只有 new）：实测查 INTC 白拿 NVDA `TP 315`、AVGO `TP 550`、AAPL `TP 350`、SK hynix、三星、美光、铠侠

> ✅ **顺带白拿别人的目标价** 是本 Skill 的一个实用副产品：查一只票，拿到整条链上多只票的当前目标价——
> **但它们来自 mention 层，是那家机构的单点读数，不是那些票的共识**。引用时必须标明出处报告。

**跨标的催化剂**：`detail.catalysts[]` 里 `security ≠ ticker` 的条目（subject 与 mention 两个桶都扫）。
实测产出稳定在 **4–7 条/标的**，且 **`mention_count = 0` 时它是唯一的产出来源**。

> ⛔ **`security` 字段需要清洗，它不保证是 ticker**（2026-07-29 实测新增）：
> - **可能是板块名**：实测 `"AI SEMICONDUCTOR SUPPLY CHAIN"`（Nomura，查 2330.TW）——不是代码，别去查行情
> - **可能是逗号分隔的多值**：实测 `"373220.KS, 006400.KS"`——需拆分
> - 清洗规则：含空格且无 `.` 后缀 → 判为板块名，单列；含 `,` → 拆分成多条

时间归一直接复用 [r3 的完整归一表](./r3_catalyst-timeline.md)（N-41：10 种 `sort` 形态 + 按 `type` 语义降级）。

### 步骤 5 · 降级分支（`mention_report_returned_count == 0`）

实测 2330.TW 就是这个形态。此时：

- 关系边 **0 条**、同链修正 **0 条** —— 照实写"本次无 mention 报告，拿不到关系边"
- 唯一产出是 subject 报告里的跨标的催化剂（2330.TW 实测 4 条：MSI/华硕 RTX Spark 上市、ASML EUV 分配、两条 AI 半导体板块级）
- **必须解释原因**：不是"这只票没有产业链"，是**它的专题报告太多，把 10 篇名额占满了**（前提 2）

---

## 输出：产业链关联图

```
🔗 <TICKER> 研报产业链读穿 · <日期>
可见 N 篇（subject M / mention K）｜关系边 E 条｜同链修正 R 条｜跨标的催化剂 C 条
⚠️ 汇编报告已过闸，丢弃 X 条同框噪音

【🔎 领读】（先写这段）
<2–4 句判断。这批研报把该标的放在什么结构位置上？它是被当成需求方、供给方、
 还是替代威胁？链上正在发生的最大变化是什么？必须是判断，不是"共 N 条边"。>

【① 关系边】研报为什么提到它（带方向）
🟢 受益｜〔机构〕《报告主题》
    <rationale 原文一句> → <读法：这条边的实际含义>
🔴 受损｜…
⚪ 中性｜…

【② 同链修正】这条链上谁被改了价
· 真修正（带 old→new）
  2303.TW 联电    47→88   (+87.2%)  reiterate Underperform  〔Bernstein《台湾成熟制程》〕
  5347.TWO VSMC   94→146  (+55.3%)  reiterate Market-Perform
· 当前价位（只有 new，非修正）
  NVDA TP 315 ｜ AVGO TP 550 ｜ AAPL TP 350   〔Bernstein《全球AI内存伙伴关系》〕
  ⚠️ 单家读数，非共识

【③ 跨标的催化剂】链上其他节点的时间
· 2026-10｜ASML｜供应商财报｜EUV 分配披露〔Morgan Stanley〕
· 板块级：AI 半导体供应链｜供给与定价｜零部件与材料短缺支撑供应商定价〔Nomura〕
  ⚠️ security 字段是板块名不是代码

【🧩 结构读法】（不可省）
· **方向是否一致**：多篇把它判成同一方向 → 这批研报的共同叙事；方向分裂 → 说明分歧在哪
· **它在链上的位置**：被当成需求方（下游拉动）还是供给方（上游受益）？位置决定了它对什么敏感
· **修正的方向和它自己对得上吗**：链上邻居被大幅上调而它没有（或反之）= 值得追问的错位

【口径声明】
· 关系边与同链修正**全部来自 mention 层**——是"别人报告里顺带提到"，**不是对本标的的评级**
· 已丢弃 X 条汇编报告的同框噪音（同一份晨报里的名字之间没有产业链关系）
· old→new 覆盖率实测仅 26%，"当前价位"不等于"被改价"
· 上游硬顶 10 篇且 subject/mention 共享名额，本图不代表完整产业链
```

**⛔ 硬要求**：

**1. 解读优先于陈列。** 关系边和修正表是证据，【领读】和【结构读法】才是产品。

| ❌ 复述 | ✅ 解读 |
|---|---|
| "3 条关系边，2 条中性 1 条受益" | "**三家都把英特尔当'台积电产能紧张的溢出受益者'看**——这意味着它的代工叙事目前是**借来的**，靠对手吃紧而不是自己变强" |
| "UMC 目标价 47→88，+87.2%" | "**同一份报告把联电目标价抬了 87% 却仍给 Underperform**——分析师承认自己此前低估得离谱，但依然不看好。这种'大幅上修 + 维持看空'是估值重置，不是观点转向" |
| "顺带拿到 NVDA TP 315、AVGO TP 550" | "这两个价来自同一份 AI 内存报告——**说明这家机构把英特尔和英伟达放在同一张供需表里算**，而不是当作竞争对手" |

**2. 汇编闸不可省。** 不过闸的输出里可能 80%+ 是无关名字（实测 NVDA 30/36）。

**3. mention 数据绝不标成评级。** 这是 N-39 的红线，本 Skill 是消费 mention 数据的唯一场景，更要守住。

**4. rationale 要读全句。** 实测存在"A 是 B 的潜在伙伴，**但分析师认为不太可能**"这种自带否定的边。

**5. 产出为零时照实说，并解释原因。** `mention=0` 是结构性的（专题挤满名额），不是"这票没有产业链"。

## 额度

单次 = **1 额度**。与 r1/r2/r3 共用同一次研报调用时 **0 额度**。

## 已知边界

| 边界 | 性质 | 处置 |
|---|---|---|
| **`detail.affected_names` 计数有、内容永远没有** | 上游缺失（N-65）| 实测 **30/30 篇**：`detail_sections.affected_names` 报了 1–31 的计数，但 `detail` 里**从不包含该字段**。最理想的产业链名单（Nomura 那篇标了 31 个名字）**一个都拿不到**。本 Skill 只能用 `by_name` + `mention_context` + `catalysts` 三个替代面 |
| **枢纽票反而没产出** | 结构性（N-66）| 前提 2。跑之前先看 `mention_report_returned_count`，为 0 走降级分支 |
| 汇编报告制造同框噪音 | 数据特性（N-67）| 步骤 2 的闸；关键词表需持续补充 |
| `old_target_price` 覆盖率仅 26% | 数据特性 | 真修正与当前价位分开写 |
| `catalysts[].security` 非规范 ticker | 数据特性 | 步骤 4 的清洗规则（板块名 / 逗号多值）|
| 跨标的以亚太股为主 | 数据特性 | 实测 47 个跨标的 ticker 里大半是 `.KS`/`.T`/`.TW`/`.NS`/`.JK`。**对只做美股的用户，多数不可直接交易**——但作为供应链信号仍有效，须标明市场 |
| 产出量不可预测 | 结构性 | 实测关系边 0–4 条、真链修正 0–16 条。**不承诺产量**，跑完才知道 |
