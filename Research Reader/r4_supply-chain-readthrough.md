---
name: Research Supply-Chain Read-Through (r4 — 研报产业链读穿)
description: 单标的产业链关联图。回答"这批研报把我的标的放在什么位置上、它的上下游谁在被改价、为什么被点名"。三层产出：关系边（为什么提到它）+ 同链修正（链上谁被改了目标价）+ 跨标的催化剂。数据来自 mention 报告，近 30 天窗口单独调用（不与 r1 共用）。
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
| ticker | ✅ | — | 单个标的。**本 Skill 不做批量**——产出高度依赖当次 mention 报告的构成。<br>⚠️ **双重上市标的（ADR / 本地股 / H+A 股）的研报按代码分桶、互不展开**（2026-10-05 实测）：专题报告挂本地代码（如 `2330.TW`），产业链提及挂 ADR / 美股代码（如 `TSM`）。**本 Skill 用 ADR / 美股代码跑；r1 用本地代码跑。** 两边都要时各跑一次 |

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

> 🔄 **2026-10-05 复测：2330.TW 的"零 mention"是代码选择造成的。** 同日查 `TSM`（ADR）得 **subject 0 / mention 26**（翻 3 页至尽头）；查 `2330.TW` 得 subject 10 / mention 0（首页）。两边报告互不重叠，解析层不会把一个展开成另一个。
> 台积电这类双重上市枢纽，**换 ADR 代码就能拿到整条链**——见参数表的说明。

**根因**：**10 篇单页硬顶是 subject 与 mention 共享的**（N-38）。台积电的专题报告太多，首页 10 个名额全被 subject 占满，
🔄 **2026-08-12 起可解**：翻页即可取到被挤到后面的 mention（N-81），本节的"空手"结论仅适用于只取首页的情况。原文照录——
mention 一篇都挤不进来——而产业链信息全在 mention 里。

**所以：被专题覆盖淹没的标的，恰恰拿不到产业链视角。**
真正高产的是**有覆盖但没刷满 10 篇**的标的（INTC 型）。

> 📌 **不要用榜单排名挑标的跑本 Skill。** 榜单排名越高，越可能是 2330.TW 那种"全是 subject、零 mention"的形态。
> **产出多少只能跑完才知道**，跑之前先看 `mention_report_returned_count` 与 `has_more`——为 0 且还有下一页就**先翻页**，翻到尽头仍为 0 才走降级分支（步骤 1）。

---

## 执行流水线（每页 1 额度，最多 5 页）

### 步骤 1 · 拉报告

```
metrics(keywords=["<TICKER>"], query="research reports", verbosity="detail", asset_type="tradfi", time_range="30d")
```

> ⛔ **`time_range="30d"` 不要与 `date_from` / `date_to` 同传**（同传时绝对区间优先、`time_range` 被静默丢弃，N-153）。翻页带同一组参数加 `cursor`。

> 🔴 **取数前先认块（N-86，2026-08-12 实测）**：解析层会静默扩展出额外候选 ticker，**每个候选都是一个平级结果块，顺序不保证主匹配在前**（实测 `ASML.AS` 的 `[0]` 是空块、数据在 `[1]`）。
> ① ⛔ **禁止用 `research_reports[0]` 取数**　② 逐块比对 `query_ticker` == 本次标的，**只认相等的块**　③ ⛔ **禁止用 `meta.total` 判条数**（它数的是块）

同 r1 步骤 1 的全部铁律（红线 12 研报意图词 ／ N-38 部分修复：`time_range` 已于 2026-08-03 生效可传，`limit` 单页仍被 10 硬顶，但 **2026-08-12 起返回体带 `meta.pagination["fundamentals.research_reports"].next_cursor`，可翻页枚举完**（N-81 销案）——**没翻页才需要把家数标下界** ／ N-21 假阴性警告别重试）。
🔴 **本 Skill 尤其要翻页**：产业链读穿依赖 mention 层，而 mention 常被 subject 挤到首页之外。

> ⚠️ **加 30 天窗口**（2026-10-08 用户拍板）：不加窗口时旧 subject 排在最前、白占页数——实测 NVDA subject 21 篇里 19 篇早于 30 天前，占掉第 1、2 页；同时刻加 `time_range="30d"` 首页即为 subject 2 + mention 8。代价是 30 天前的 mention 不再取（旧写法实测 TSM 26 篇跨 06-30~09-22，22 篇早于 9 月）。
> 表头仍写报告日期跨度，每条边、每条修正都标 `report_date`，催化剂按步骤 4 分「未来 / 已过期」。

> ⚠️ **`verbosity="detail"` 不能省**（2026-10-08 实测 NVDA）：`concise` 下整个 `detail` 块不返回（没有 `catalysts`），`revision_summary.by_name` 还会被截短（Bernstein《AI Value Chain》detail 7 行、concise 5 行，无截断标记）。每页约 83–96K 字符，会落盘，用脚本按字段解析。

> ⚠️ **不能复用 r1/r2/r3 的首页**：它们的步骤 1 不传窗口，与本 Skill 参数不同（游标也绑参数），本 Skill 首页照样计 1 额度。

**先看 `mention_report_returned_count` 与 `meta.pagination["fundamentals.research_reports"].has_more`**（⚠️ 键名本身含点，不是 `meta.pagination.has_more`——N-142；2026-10-08 实测 AVGO 同）：

- **还有下一页**（`has_more: true`）→ 带 `cursor=<同一对象里的 next_cursor>` 原参数重查，**每页 1 额度**（实测 TSM 3 页到尽头 = 3 额度）。mention 为 0 时也先翻，不要直接降级
- **停翻条件（按日期下限，先到者为准）**：① `has_more: false`（到尽头）；② 本页 mention 最旧一篇的 `report_date` **早于今天 − 30 天**；③ **已满 5 页**。只看 mention 的日期——subject 排在前面，不能拿它判断（N-142）；**本页没有 mention 时 ② 不适用，接着翻**（2026-10-08 实测 NVDA：前 2 页全是 subject、日期 08-27~07-08，拿 subject 日期判 ② 会在第 1 页就误停）
- **翻到尽头（或到页数上限）后 mention 仍为 0** → 走**降级分支**（见步骤 5），只能从 subject 报告的 `detail.catalysts[]` 里捞跨标的节点，产出很少。照实说明，并写明是「近 30 天无 mention」。
- **mention ≥ 1** → 正常流程。口径声明写「已翻 P 页 / 共 N 篇」；因 ② 停的写「已翻 P 页，mention 已覆盖近 30 天」，因 ③ 停的写「已翻 5 页，未到尽头，mention 只覆盖近 N 天（<最早 mention 日期> 之后）」——被大量提及的票接受这个结果，照实写
- ⚠️ **没翻到尽头时，缺的是更早的 mention**：分页是 subject 全部排完、再按日期倒序排 mention（N-142）。2026-10-08 实测 AVGO：首页 subject 6 + mention 4，3 页拿到 mention 24 篇、只覆盖 09-18~10-05，第 3 页仍 `has_more: true`——旧的 3 页上限对被大量提及的票只够两周半，所以改成按日期下限。口径声明写明 mention 的日期下限
- ⚠️ **加了窗口，被大量提及的票 5 页仍到不了 30 天前**（2026-10-08 实测 NVDA）：不加窗口时 5 页拿到 mention 29 篇、只覆盖 09-28~10-07；加窗口能省出约 2 页 subject，但单 09-24~09-27 就有 ≥10 篇 mention，近 30 天估计 80 篇以上。按 ③ 停，写「mention 只覆盖近 N 天」，**不要写成"近 30 天"**

### 步骤 1.5 · 自身别名集（SELF）

⛔ **不做这步，标的自己会被当成"链上邻居"。** 实测查 TSM（2026-10-05）：`by_name` 里出现 `2330.TW`（高盛 2750→3000，+9.1%）与 `TSM` 自己的行，`catalysts[].security` 里出现 `2330.TW`；
高盛 07-03 一篇 `subject_name` 就是 "Taiwan Semiconductor Manufacturing Company" 的**台积电公司报告**，因为挂在本地代码上，查 ADR 时被标成 `match_type: mention`。

- 用 `mention_context.mention_name` / `mention_ticker`、`by_name[].name` 归并出本标的的全部代码（ADR / 本地股 / H+A 股），记为 **SELF**（例：`{TSM, 2330.TW}`）。
  `detail.affected_names.items[]` 的 `_name_alias_ambiguous` 直接给出同一公司的多地代码（2026-10-08 实测：`["2330.TW","TSM"]`、`["6758.T","SONY"]`、`["2303.TW","UMC"]`、`["3711.TW","ASX"]`），可用来补全 SELF 和步骤 4 的多地上市合并。单一上市标的（如 AVGO）SELF 只有自己，**照样要筛**——实测 AVGO 的 `by_name` 里有 2 行 `AVGO`、mention 报告的 `catalysts` 里有 2 条 `AVGO`
- 后文所有「≠ ticker」**一律改成「∉ SELF」**
- `subject_name` 指向本标的公司的 mention 报告（ADR / 本地错位漏入）**不进关系边**，其评级与目标价单列进【本标的单家读数】

### 步骤 2 · ⛔ 汇编闸：把「同框噪音」和「真产业链」分开

**这是本 Skill 最重要的一道闸。不加这道闸，输出会系统性错误。**

实测：查 NVDA 拿到 12 条带 old→new 的跨标的修正，内容是——
**印尼棕榈油（Triputra Agro −7.4%）、印度银行（IDFC First +11.8%、Bank of Baroda −6.7%）、印度钢铁、印尼制药、韩国船舶（Hanwha Ocean −16%）**。

**这些跟英伟达毫无关系。** 它们只是恰好和 NVDA 出现在同一份《Asia Morning News & Research Views》里。

**闸的规则**——看 `subject_name`、`report_title` 与过闸后 `by_name` 的行业分布：

| 形态 | 判定 | `by_name` 怎么用 |
|---|---|---|
| `subject_name` 或 `report_title` 是**汇编标题**：含 `morning news` / `portfolio` / `quant` / `weekly` / `daily` / `views` / `roundup` / `cross-sector` / `monitor` / `fund positioning` / `hedge fund positioning` / `conviction` / `selloff` / `newsletter` / `equity strategy` / `tech strategy` / `end of week` / `market intelligence` 等，**或跨行业的 `sector keys`**<br>**或**标题是「系列名 - 议题 A; 议题 B」这种**多个互不相关议题拼成的一篇**（2026-10-08 实测 NVDA：J.P. Morgan《China Tech & APAC Internet - read-through from four China stimulus scenarios; cooling components update》，中国刺激政策与台湾散热件同篇；同系列 09-29 一篇同理）<br>**或** `by_name` 横跨 ≥3 个互不相关行业（如银行 + 制药 + 半导体；实测 BofA《European Equity Strategy》的保险 / 公用事业 / 化工 / 矿业）<br>实测样例：`"Asia Morning News and Research Views"`、`"Asia Quant + Fundamental Portfolio for 2H26"`、`"Global and Asian cross-sector research roundup"`、`"Hedge fund positioning and the AI trade"`、`"AI infrastructure selloff opportunities"`、`"APAC Tech Strategy: Sector Keys September 2026 v4"`（UBS，正文 200+ 页）、`"End of Week Market Intelligence: here comes AI..."`（高盛周度策略，2026-10-08 实测） | 🚫 **同框噪音** | **整个丢弃。** 同一份晨报 / 选股篮子里的名字之间没有产业链关系 |
| **单一行业的定期汇编**——`subject_name` 是一个行业覆盖范围而不是研究命题：周报（如 `"North America Semiconductors Weekly"`）、单行业 `Sector Keys`（`"Asia Semiconductors: Sector Keys"`）、`Tearsheet`、`SemiBytes`、路演纪要（`"Notes from the road"`）、行业追踪 / 月度前瞻（`"Global Semicap Tracker"`、`"Taiwan ODM/Brands: 3-month preview"`）、整个板块重排评级（`"Re-assessing sector positioning … our preferred names"`）| ⚠️ **部分保留** | 只保留 rationale / context_snippet 里点名的公司（实测 Amkor 封装边是真链；2026-10-08 AVGO：UBS 亚洲半导体 Sector Keys 的 16 行只留被点名的联发科；2026-10-08 NVDA：伯恩斯坦 Semicap Tracker 12 行只留 Advantest），其余丢弃。rationale 只点名本标的时等于全丢。**例外：带真修正（old 与 new 均有值且 old ≠ new）的行一律保留进同链修正**，即使 rationale 没点名，标注「来自 <机构>《<汇编 / 行业追踪标题>》」（2026-10-08 用户拍板；实测 NVDA 高盛《Taiwan ODM/Brands》的纬创 281→295、英业达 56→61）；只有当前价位、没有变动的行仍丢弃 |
| `subject_name` 是**具体公司或具体产业主题**<br>实测样例：`"Global AI memory strategic partnerships"`、`"Taiwan mature-node foundries and semiconductor design"`、`"Nokia"`、`"Apple Inc."` | ✅ **真产业链** | 全部可用 |

> ⚠️ **主题具体、名单却是选股表的篇，人工判**（2026-10-08 AVGO）：伯恩斯坦《China Next Winners》主题是 NPO / SuperPod，rationale 点名 H3C、锐捷，`by_name` 却是大立光 / 舜宇 / 台达 / 广达——按"有没有统一研究主题"的原则降为 ⚠️ 部分保留。
> 曾试过机械的 `by_name ∩ rationale` 交集判据（2026-10-08 拍板、同日撤销）：它把伯恩斯坦 Apple Tracker（苹果 / 台积电 / 大立光等 6 行）、UBS《Global I/O Semiconductors》（弘塑 5000→4300 真修正）这类真名单也一并丢掉，AVGO 真修正从 3 条降到 2 条，得不偿失。

> ⛔ **`report_type` 不作判据**（2026-10-05 实测）：同为 `tracker`，高盛对冲基金持仓监测是噪音（SNOW / TMO / AXSM / NRG），伯恩斯坦 Apple 供应链追踪却是真链（立讯 / 大立光 / 索尼 / 存储）。

**闸的效果（实测）**：NVDA 30 条噪音 / 6 条真链；INTC **0 条噪音 / 16 条真链**；GOOGL 17 条噪音 / 5 条真链。
**不加闸，NVDA 的输出里 83% 是无关名字。**
2026-10-05 TSM：旧关键词表只拦下 3 篇 / 14 行，**漏放 3 篇 / 39 行**（综合周报的 MUFG / 瑞幸 / 中银、抛售篮子的 HOOD / 肿瘤药 AKTS / CCJ）——上表的新增关键词与行业分布判据就是为这三篇补的。
2026-10-08 AVGO：10-05 版关键词表命中 3 篇，三篇 `by_name` 都是空的——**一行都没拦到**；UBS《APAC Tech Strategy: Sector Keys》v2 / v3 / v4 与《Asia Semiconductors: Sector Keys》漏放 23 行（大立光 Buy→Sell 降级出现 3 次、信骅 / 矽力 / 家登……），`sector keys` / `strategy` 两类就是为这几篇补的。
`positioning` 收窄为 `fund positioning` / `hedge fund positioning`：裸词会误伤 UBS《APAC Tech: Positioning for the AI and memory upcycle》这类主题报告（2026-10-08 实测），它的去留按"有没有统一研究主题"判断。2026-10-08 NVDA 又见三篇：J.P. Morgan《Humanoid Robot: Re-assessing sector positioning…》（板块重排 → ⚠️，只留 Orbbec）、巴克莱《Positioning for AI Disruption》、UBS《APAC Tech: Positioning for the AI and memory upcycle》（主题报告 → ✅）——裸词会把三篇一起丢。

> ⚠️ **同一系列的多个版本只算一篇**（2026-10-08 实测）：UBS《Sector Keys September 2026》**v2 / v3 / v4** 分别在 09-22 / 09-23 / 09-28 入库，rationale 几乎相同（v3、v4 都是"Google TPU CoWoS 1.62→2.82 万片/月"），`by_name` 里的大立光降级重复三次。
> 按「机构 + 去掉版本号 / 日期后的标题」归并，**只留最新一版**——关系边、同链修正、催化剂都按归并后计数。

> ⚠️ **关键词表是启发式，不是白名单。** 遇到新的汇编标题形态要补进去。
> 判别原则：**这份报告有没有一个统一的研究主题？** 有 → 里面的名字彼此相关；没有（只是"今天的一堆事"）→ 不相关。
>
> ✅ **无论闸判成什么，`mention_context.rationale` 永远保留**——见步骤 3。汇编报告的 rationale 照样是真信息，
> 被丢弃的只是它的 `by_name` 名单。
>
> ⛔ **闸同样作用于这篇的 `detail.catalysts[]`**（2026-10-08 实测）：🚫 篇的跨标的催化剂只计数、不进③（与 r3 的"同框"桶同一口径）；⚠️ 篇只留点名公司的，**`security` 缺失的也算同框**（它没点名任何公司）。
> 2026-10-08 NVDA：可见 mention 催化剂 58 条，同框 11 条（🚫 3 篇 6 条：中国五中全会、中央经济工作会议、FOMC 纪要……；⚠️ 篇 5 条：OpenAI 融资、东京电子财报、鸿海出货……）。
> 不过闸的话，AVGO 可见 60 条催化剂里有 20 条同框（SK 海力士回购、世芯 Trainium、欧洲 AI 资本开支……）会混进"链上其他节点的时间"。

### 步骤 3 · 关系边：为什么这份报告提到我的标的

取每篇 mention 报告的 `mention_context`：`{mention_direction, mention_rating, rationale, context_snippet}`。

**`rationale` 是本 Skill 质量最高的字段**——实测它给的是**机制描述，不是标签**：

- *"NVIDIA is Nokia's development partner for the open, programmable, O-RAN-compliant AI-RAN platform."*
- *"Google's resilient Chrome traffic supports continued TAC payments to Apple."*
- *"Intel Foundry is seeing improving customer interest because TSMC leading-edge capacity is tight."*
- *"Intel is a potential 3nm collaboration partner for UMC, but Bernstein considers a joint project unlikely because UMC lacks 7nm and 5nm capabilities."*

每一条都是一条 **A → B 的因果边**，带方向（`mention_direction`：`beneficiary` / `negative` / `neutral` / `competitor`）。
这些边合起来就是"这批研报眼里，你的标的嵌在什么结构里"。

> ⚠️ **`competitor` 是 2026-10-05 实测新增的方向值**（高盛 2Q 前瞻：台积电自有 CoWoS / COUPE 被当成 Amkor、GF 的竞争参照）。读作"**被当作竞争参照或替代威胁**"，模板里单列 🟠，不并进 🔴。
> ⚠️ **竞争关系不一定标成 `competitor`**（2026-10-08 实测 AVGO 24 篇里一条 `competitor` 都没有）：UBS 写"云客户想找博通的替代者"标 `negative`，伯恩斯坦写"博通是与联发科竞争的 ASIC 供应商"标 `beneficiary`，UBS 写"对手联发科拿到出货份额"标 `neutral`。
> rationale 里出现 competitor / alternative / share gain 的，按方向值归桶，**读法里点明竞争关系**，【结构读法】按竞争线索汇总。
> ⚠️ **关系边只从 `mention_context` 取**。`detail.affected_names` 是报告主题的名单（与 `by_name` 同性质），不是"与本标的的关系"——见「已知边界」。

> ⚠️ **`mention_rating` 多数篇不存在**（2026-10-05 实测 TSM 26 篇里 20 篇缺这个键——是键缺失，不是 `None`；2026-10-08 AVGO 24 篇里 18 篇缺、NVDA 29 篇里 27 篇缺）。顺带提到不等于给评级。
> **值为 `"Not rated"` 的视同缺失**（2026-10-08 实测 Nomura 2 篇）——那是"这家没覆盖"，不是一个评级，不进【本标的单家读数】。
> **同一机构多篇给同一读数的只写最新一篇**（实测伯恩斯坦 09-21 / 09-22 / 10-05 三篇都是 Outperform $575），括注篇数。
> **存在时**配合 `matched_asset_target_price`（N-79），是该机构在行业报告里顺带给本标的的**单家评级 / 目标价**（实测巴克莱 Overweight $650、伯恩斯坦 Outperform $430、高盛 Buy $600）——
> 列入【本标的单家读数】并标"行业报告口径、非共识"，**绝不进任何评级统计、绝不写成"机构评级共识"**（N-39）。
> ⚠️ 注意上面第 4 条：rationale **自带否定**（"Bernstein 认为不太可能"）。**别只读前半句**，方向要以整句为准。

### 步骤 4 · 同链修正 + 跨标的催化剂

**同链修正**：过闸后的 `by_name[]`，**剔除 `ticker ∈ SELF` 的行**（步骤 1.5）。

| 字段 | 实测覆盖率 | 说明 |
|---|---|---|
| `ticker` | **不恒有**（2026-10-05 实测）| 无 `ticker` 的行多为行业 / 市场 / 因子名（`"Taiwan market"`、`"Asia price momentum factor"`、行业框架名），**丢弃**；只有 `name` + `ticker`、**既无 `rating_action` 也无 TP** 的行是"提及名单"（实测花旗一篇 15 行），**不进同链修正** |
| `name` | 96/96 | 恒有 |
| `rating_action` | 94/96 | 常有，但多为 `reiterate`。⚠️ **是自由文本不是枚举**（2026-10-08 实测：`"downgrade from Buy to Sell; page 207"`、`"upgrade to Buy recently; action date and prior rating unavailable"`、`"not covered"`、`"reaffirmed as Top Pick in the research view"`）——含 `upgrade` / `downgrade` 的在所在行**标出评级变动**（没有 old TP 也要标，它不是"维持"；2026-10-08 NVDA 另见 `"recent downgrade to Neutral; prior rating and date not supplied"`，同样标）；含 `initiate` / `assume coverage` 的标"新覆盖"（实测 J.P. Morgan 接手散热件 3 家），同样不是"维持"；`not covered` 的行丢弃 |
| `new_target_price` | 89/96 | 常有 |
| **`old_target_price` + `change_pct`** | **25/96（26%）** | **只有四分之一带真修正**——有 old→new 的才叫"被改价"，只有 new 的是"当前目标价" |

**两类要分开写**，别混成一句"N 家被改价"：
- **真修正**（old 与 new 均有值**且 old ≠ new**）：实测 INTC 拿到 UMC **47→88（+87.2%）**、VSMC **94→146（+55.3%）**、Novatek **370→480（+29.7%）**
- **当前价位**（只有 new，**或 old == new**——实测 ASML 2500→2500、GOOGL 425→425 带 `change_pct: 0`，那是维持不是修正）：实测查 INTC 白拿 NVDA `TP 315`、AVGO `TP 550`、AAPL `TP 350`、SK hynix、三星、美光、铠侠
- **既无 old 也无 new 的行不进同链修正**，带不带 `rating_action` 都一样（2026-10-08 实测摩根士丹利《Powering AI》5 行比特币矿企全是 `reiterate`、无目标价——两类都装不下，只是名单）

> ⚠️ **同一公司多地上市的行合并为一条**（ADR / 本地股 / H+A 股），展示主上市代码，其余括注——实测 UMC / `2303.TW`、中芯 H / A、华虹 H / A、Sony / `6758.T` 各出现两行，不合并会把"R 条修正"数虚高。
> ⚠️ **同一机构对同一标的的同一读数只写一次**（取最新一篇，括注其余出处）：2026-10-08 实测伯恩斯坦大立光 5150 出现在两篇、UBS 联发科 7300 出现在两篇。不同机构的读数照常分列。
> **同一机构前后读数不同的，只写最新一篇**（2026-10-08 实测 NVDA：高盛 09-29 SpaceX 220→220、10-05 220→230，写后者）。机构名先归并再比（`UBS` 与 `UBS Securities LLC` 是一家，N-164）。

> ✅ **顺带白拿别人的目标价** 是本 Skill 的一个实用副产品：查一只票，拿到整条链上多只票的当前目标价——
> **但它们来自 mention 层，是那家机构的单点读数，不是那些票的共识**。引用时必须标明出处报告。

**跨标的催化剂**：`detail.catalysts[]` 里 `security ∉ SELF` 的条目（subject 与 mention 两个桶都扫），**所在篇须过步骤 2 的闸**（🚫 篇只计入"同框 N 条"）。
**`mention_count = 0` 时它是唯一的产出来源**。
⚠️ **detail 下每篇只返回前 2 条**（2026-10-05 实测；`detail_sections.catalysts` 是全量计数，TSM 26 篇可见 52 / 全量 181）——**跨标的催化剂是抽样，不是全量**，口径声明写「每篇可见 2 / 共 N」。原"4–7 条/标的"的产量记载已不适用。

> ⛔ **`security` 字段需要清洗，它不保证是 ticker**（2026-07-29 实测新增，2026-10-05 补充新形态）：
> - **可能是板块名**：实测 `"AI SEMICONDUCTOR SUPPLY CHAIN"`（Nomura，查 2330.TW）、`"Korea/Taiwan AI and momentum exposures"`——不是代码，别去查行情
> - **可能是逗号分隔的多值**：实测 `"373220.KS, 006400.KS"`——需拆分
> - **可能是单个公司名或篮子代码**：实测 `"Wistron"`、`"Ibiden"`、`"GSTHHVIP"`（高盛篮子）；**也可能整个缺失**（TSM 实测 8 条；2026-10-08 AVGO 可见 60 条里 16 条缺失，过闸后剩 3 条）
> - **代码格式不一**：实测催化剂写 `981.HK`、`by_name` 写 `0981.HK`；`GOOG` 与 `GOOGL` 混用
> - 清洗规则（按序）：① 缺失 → 「未指明标的」桶　② 含 `,` → 拆分成多条　③ 含空格或 `/` → 板块名，单列　④ 不匹配 `^[A-Z0-9]{1,6}(\.[A-Z]{1,3})?$` → 视为公司名，用同篇 `by_name` / `affected_names` 的 name→ticker 回填，回填不到标「代码待查」　⑤ 港股代码补零到 4 位；同类股（`GOOG` / `GOOGL`）合并

时间归一直接复用 [r3 的完整归一表](./r3_catalyst-timeline.md)（N-41：`sort` 形态 + 按 `type` 语义降级）——**`time_std.type` 的归一以 r3 为准**（2026-10-05 实测出现 r3 表外的新 `type` 值，由 r3 统一补）。
归一后按 r3 步骤 8 分「**未来 / 已过期**」两桶：**已过期的不进③主列表**，只在口径声明里记条数（实测 TSM 可见约 41 条，约 30 条已过期）。

### 步骤 5 · 降级分支（`mention_report_returned_count == 0`）

实测 2330.TW 就是这个形态。此时：

- 关系边 **0 条**、同链修正 **0 条** —— 照实写"本次无 mention 报告，拿不到关系边"
- 唯一产出是 subject 报告里的跨标的催化剂（2330.TW 实测 4 条：MSI/华硕 RTX Spark 上市、ASML EUV 分配、两条 AI 半导体板块级）
- **必须解释原因**：不是"这只票没有产业链"，是**它的专题报告太多，把 10 篇名额占满了**（前提 2）
- **双重上市标的先换代码再降级**：查的是本地代码（如 `2330.TW`）时，改用 ADR / 美股代码（如 `TSM`）重跑一次——实测后者 mention 26 篇（参数表）

---

## 输出：产业链关联图

```
🔗 <TICKER> 研报产业链读穿 · <日期>
可见 N 篇（近 30 天窗口；subject M / mention K，<已翻 P 页至尽头 ／ 已翻 P 页未到尽头，mention 只覆盖近 N 天>）｜报告日期跨度 <最早>~<最晚>
关系边 E 条｜同链修正：真修正 R 条（合并多地上市后）/ 当前价位 Q 条｜跨标的催化剂 C 条（未来 C1 / 已过期 C2）
⚠️ 汇编报告已过闸，丢弃 X 篇汇编报告的 Y 条名单｜SELF = {<本标的全部代码>}

【🔎 领读】（先写这段）
<2–4 句判断。这批研报把该标的放在什么结构位置上？它是被当成需求方、供给方、
 还是替代威胁？链上正在发生的最大变化是什么？必须是判断，不是"共 N 条边"。>

【① 关系边】研报为什么提到它（带方向）
🟢 受益｜〔机构 report_date〕《报告主题》
    <rationale 原文一句> → <读法：这条边的实际含义>
🔴 受损｜…
🟠 竞争｜…（mention_direction = competitor：被当作竞争参照或替代威胁）
⚪ 中性｜…

【② 同链修正】这条链上谁被改了价（已剔除 SELF、已合并多地上市）
· 真修正（old→new 且 old ≠ new）
  2303.TW 联电    47→88   (+87.2%)  reiterate Underperform  〔Bernstein《台湾成熟制程》〕
  5347.TWO VSMC   94→146  (+55.3%)  reiterate Market-Perform
  3231.TW 纬创   281→295  (+5.0%)   reiterate              〔Goldman Sachs《Taiwan ODM/Brands》·⚠️ 行业追踪篇〕
· 当前价位（只有 new，或 old == new，非修正；rating_action 含 upgrade / downgrade 的标出）
  NVDA TP 315 ｜ AVGO TP 550 ｜ AAPL TP 350   〔Bernstein《全球AI内存伙伴关系》〕
  ⚠️ 单家读数，非共识

【③ 跨标的催化剂】链上其他节点的时间（只列未过期、所在篇已过闸；已过期 C2 条只计数）
· 2026-10｜ASML｜供应商财报｜EUV 分配披露〔Morgan Stanley〕
· 板块级：AI 半导体供应链｜供给与定价｜零部件与材料短缺支撑供应商定价〔Nomura〕
  ⚠️ security 字段是板块名不是代码
· 未指明标的：<event>〔机构〕（security 缺失）
另有同框 N 条（🚫 篇）、待锚定 N 条（sort = 9999）

【本标的单家读数】（有 mention_rating / matched_asset_target_price 或 SELF 错位漏入时才写）
  〔机构 report_date〕<评级> <目标价>   ⚠️ 行业报告口径，非专题、非共识，不进任何评级统计

【🧩 结构读法】（不可省）
· **方向是否一致**：多篇把它判成同一方向 → 这批研报的共同叙事；方向分裂 → 说明分歧在哪
· **它在链上的位置**：被当成需求方（下游拉动）还是供给方（上游受益）？位置决定了它对什么敏感
· **修正的方向和它自己对得上吗**：链上邻居被大幅上调而它没有（或反之）= 值得追问的错位

【口径声明】
· 关系边与同链修正**全部来自 mention 层**——是"别人报告里顺带提到"，**不是对本标的的评级**
· 已丢弃 X 篇汇编报告的 Y 条名单（同一份晨报 / 选股篮子里的名字之间没有产业链关系）；同系列多版本已归并为最新一版（归并 V 篇）
· old→new 覆盖率实测仅 26%，"当前价位"不等于"被改价"
· 单页 10 篇且 subject/mention 共享名额（<已翻 P 页至尽头 ／ 已翻 P 页未到尽头，mention 只覆盖 <最早 mention 日期> 之后 ／ 仅取首页>）；未翻到尽头时本图不代表完整产业链
· detail 下每篇催化剂仅可见 2 条（可见 C / 共 N），是抽样不是全量
· 报告日期跨度 <最早>~<最晚>；双重上市标的只查了 <本次代码>，<另一代码> 上的报告未纳入
```

**⛔ 硬要求**：

**1. 解读优先于陈列。** 关系边和修正表是证据，【领读】和【结构读法】才是产品。

| ❌ 复述 | ✅ 解读 |
|---|---|
| "3 条关系边，2 条中性 1 条受益" | "**三家都把英特尔当'台积电产能紧张的溢出受益者'看**——这意味着它的代工叙事目前是**借来的**，靠对手吃紧而不是自己变强" |
| "UMC 目标价 47→88，+87.2%" | "**同一份报告把联电目标价抬了 87% 却仍给 Underperform**——分析师承认自己此前低估得离谱，但依然不看好。这种'大幅上修 + 维持看空'是估值重置，不是观点转向" |
| "顺带拿到 NVDA TP 315、AVGO TP 550" | "这两个价来自同一份 AI 内存报告——**说明这家机构把英特尔和英伟达放在同一张供需表里算**，而不是当作竞争对手" |

**2. 汇编闸不可省。** 不过闸的输出里可能 80%+ 是无关名字（实测 NVDA 30/36）。

**3. mention 数据绝不标成评级共识。** 这是 N-39 的红线，本 Skill 是消费 mention 数据的唯一场景，更要守住。
唯一的例外出口是【本标的单家读数】：`mention_rating` / `matched_asset_target_price` 存在时，可写成"〔机构〕在行业报告里给 Overweight / TP $650"，**必须标行业报告口径、非共识，且不进任何评级统计**。

**4. rationale 要读全句。** 实测存在"A 是 B 的潜在伙伴，**但分析师认为不太可能**"这种自带否定的边。

**5. 产出为零时照实说，并解释原因。** `mention=0` 是结构性的（专题挤满名额），不是"这票没有产业链"。

## 额度

**每页 1 额度，最多 5 额度**（停翻条件见步骤 1：到尽头 / mention 最旧一篇早于 30 天前 / 满 5 页，先到者为准；实测 TSM 翻 3 页到尽头 = 3 额度）。首页不能复用 r1/r2/r3 的返回（参数不同，见步骤 1）。

## 已知边界

| 边界 | 性质 | 处置 |
|---|---|---|
| ~~`detail.affected_names` 计数有、内容永远没有~~ ✅ **已修（2026-08-12，N-65 销案）** | 上游已补 | 现返回 `{items:[{name, ticker, direction, rating, context_snippet}], total, truncated}`（实测 BofA 一篇 `total:17, truncated:true`——截断如实标注）。⚠️ **2026-10-05 实测：detail 下每篇 `items` 恒截到 5 条**（TSM 26 篇全量 515 / 可见 121），`limit` 不影响。它是**报告主题名单**（与 `by_name` 同性质，**须过步骤 2 的闸**——实测综合周报的 `affected_names` 里是 NetEase / Tencent），**不是本标的的关系边**——关系边仍以 `mention_context` 为唯一来源；`affected_names` 只用于给 `by_name` 补 `direction` 与 `context_snippet`，以及步骤 4 的公司名→代码回填 |
| **枢纽票首页没产出** | 结构性（N-66，🔄 可绕过）| 前提 2。① 双重上市的先换 ADR / 美股代码（实测 `2330.TW` mention 0 → `TSM` mention 26）；② 跑之前先看 `mention_report_returned_count` 与 `has_more`，为 0 **先翻页**（`meta.pagination["fundamentals.research_reports"].next_cursor`，每页 1 额度，最多 5 页）；翻到尽头仍为 0 才走降级分支 |
| 本标的自己混进"链上邻居" | 数据特性（2026-10-05 实测）| 步骤 1.5 的 SELF 集；`by_name` 与 `catalysts` 一律按「∉ SELF」筛 |
| 汇编报告制造同框噪音 | 数据特性（N-67）| 步骤 2 的闸（关键词 + 行业分布 + 人工判主题）；关键词表需持续补充；`report_type` 不作判据；闸同时作用于 `by_name` 与 `catalysts`；同系列多版本（v2 / v3 / v4）归并为最新一版 |
| `old_target_price` 覆盖率仅 26% | 数据特性 | 真修正（old ≠ new）与当前价位分开写；多地上市合并 |
| `catalysts[].security` 非规范 ticker | 数据特性 | 步骤 4 的五步清洗（缺失 / 逗号多值 / 板块名 / 公司名回填 / 代码格式归一）|
| detail 下嵌套列表被截断 | 接口行为（2026-10-05 实测）| 每篇 `affected_names` 5 条、`catalysts` 2 条、`key_points` 3 条；`detail_sections` 是全量计数。按抽样口径表述 |
| 跨标的以亚太股为主 | 数据特性 | 实测 47 个跨标的 ticker 里大半是 `.KS`/`.T`/`.TW`/`.NS`/`.JK`。**对只做美股的用户，多数不可直接交易**——但作为供应链信号仍有效，须标明市场 |
| 产出量不可预测 | 结构性 | 实测关系边 0–4 条、真链修正 0–16 条；2026-10-08 AVGO 3 页未到尽头即得关系边 22 条（归并后）、真修正 3 条；同日 NVDA 5 页未到尽头得关系边 29 条、真修正 10 条。**不承诺产量**，跑完才知道 |
