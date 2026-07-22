# 2026-07-22 skills-community 实测回归验收记录（NVDA/MU 样本）

日期：2026-07-22（本次实测于同一会话内一次性跑完，所有时间戳见各步骤内联标注）
执行依据：`.superpowers/sdd/task-10-brief.md`；被测对象是 `skills-community/` 下已落库的 c1-c5 skill 文件本身（dogfood 回归，非新增功能）。

---

## 0. 总览

| 步骤 | 模块 | 断言结果 | 备注 |
|---|---|---|---|
| 1 | c3 研报热议榜+研究笔记（NVDA） | 4 PASS / 0 FAIL | 见 §1 |
| 2 | c4 温度计（MU） | 5 PASS / 0 FAIL | 见 §2 |
| 3a | c1 迷你早报（步骤 1/3/4/7） | 3 PASS / 1 FAIL→已修复重测 PASS | 见 §3 |
| 3b | c5 菜单扫描 | 2 PASS（含 1 项"真实空菜单"的诚实产出） | 见 §4 |
| 3c | 待验证项回写 ×2 | 均已给出确定结论并回写 3 个 skill 文件 | 见 §5 |

**quota 实测总消耗：14 点**（17 次工具调用，详见 §6 逐条账本）。

---

## 1. Step 1 — c3 回归（NVDA）

调用：
1. `metrics(query="research reports most mentioned stocks", asset_type="tradfi", time_range="7d")` — quota 1
2. `metrics(query="NVDA research reports", verbosity="detail", time_range="7d", asset_type="tradfi")` — quota 1
3.（补充，非核心序列）`news(query="NVDA Nvidia", time_range="7d")` — quota 0，用于取得"最新動態/推特風向"素材（c3 本身当周未跑过 c4-NVDA 温度计可复用，frontmatter 只声明 metrics，此调用属于文件本身允许的"news 层近期新闻"来源，透明记录为额外调用）

c3 核心序列 quota = 2（预期 ≤6，PASS，且远低于上限）。

### 断言逐项

- **榜单返回 `research_report_most_mentioned` 聚合，NVDA 在 Top10** → PASS。NVDA 排名第 1（94 篇提及、22 家机构、`net_direction: positive`，`target_price_coverage` 8 家有数字目标价）。
- **NVDA detail 返回 subject_reports ≥3 且含 thesis/scenarios/target_price** → PASS。`subject_report_returned_count=5`，每份均含 `target_price`、顶层 `thesis` 字段、以及 `detail_sections.scenarios`（计数字段，本次每份均为 3）。
- **出现重复 event_id 时去重规则生效（花旗案例基线）** → PASS，且**本次实测复现了同一花旗案例**：`subject_reports[2]`（event_id `evt-20260709_ai_e2e-3f737cc13222`）与 `subject_reports[3]`（event_id `evt-20260709_ai_e2e-011`）机构（Citi Research）、标题（"What Are Investors Asking?"）、日期（2026-07-08）完全相同，仅 event_id 不同——按 N-3"机构+标题+日期"去重后，5 份 subject_reports 收敛为 4 份唯一报告、3 家唯一机构（Morgan Stanley ×2 篇不同报告、Citi、BofA）。
- **按 T-1 模板产出研究笔记贴，S-12 清单逐项通过** → PASS，见 §7 样张一；S-12 逐项见 §7 末自检。
- **quota 消耗 ≤6** → PASS（实际 2，含补充 news 调用为 0 成本）。

### 附带观察（非断言项，供参考）

- 层 1 聚合榜的 `meta.warnings` 出现了与 `research_reports` 无关的 `metrics_market`/`metrics_macro` 默认全家桶提示（"no specific topic...returning the CORE fundamentals set"），但 `results` 本体只含 `research_report_most_mentioned` 一个 key，说明这些 warning 是多域 fanout 评估器的通用噪声，不代表本次调用真的掉进了默认 fundamentals 全家桶——c3 文件第 3 节预期的 `research_report_limit_capped` 键名本次未出现，替代地在 `research_report_most_mentioned.excluded_counts` 里看到更细的分层排除计数（`ignored_over_page`/`out_of_scope`/`title_only`/`registry_candidate`）。不影响本次任何断言，暂不改 c3 文件，留作后续如需精确核对告警键名的参考。

---

## 2. Step 2 — c4 回归（MU）

调用：
1. `signal(query="consensus", asset_type="tradfi", time_range="3d")` — quota 1
2. `signal(query="MU 详细仓位", asset_type="tradfi", time_range="7d")` — quota 1
3.（可选步骤，本次一并验证）`metrics(query="MU", asset_type="tradfi")` 取现价视觉锚点 — quota 1（c4 frontmatter 声明的可选调用，不计入标称 ≈4-6/周核心额度）

c4 核心序列 quota = 2（可选价格锚点 +1，共 3）。

### 断言逐项

- **kol_call 裂行经 source_url 去重后条数 < 原始条数** → PASS。步骤 2 原始 kol_call 数组 26 行（同一条 Citi 光子学转发帖被拆成 LITE/COHR/AAOI/SIVE/MTSI 5 行；同一条 TradexWhisperer 帖拆成 SKHY/DRAM/MU 3 行，出现两次），按 `source_url` 去重后收敛为 **16 条唯一原帖**（26 → 16）。
- **insider 含陈年记录（2020 Perdue 基线）且客户端 90 天过滤后不出现** → **PASS（结论有修正）**：本次实测 MU 的 insider/congress 原始行**并未出现 2020-2021 年份的记录**（该"2020 Perdue"是既往某次测试的具体样本，非本次可复现的固定数据）；但 N-6"API 无视 time_range，需客户端按 transactionDate 强制过滤"的**行为模式本身完全复现**——即便 `time_range="7d"`，原始返回仍混入远超 7 天的记录，最旧一笔（Cleo Fields 国会 Purchase，`transactionDate=2026-02-03`）距今约 169 天。按 90 天窗口（cutoff ≈ 2026-04-23）+ 只认 S-Sale/P-Purchase 过滤后：10 笔原始记录（9 笔 Form 4 + 1 笔国会）→ 4 笔存活（ARNZEN 07-01、MEHROTRA 06-26、MEHROTRA 05-29、GOMO 05-11，全部 S-Sale），其余 6 笔（1 笔 F-InKind + 4 笔 04 月 S-Sale + 1 笔 02 月国会 Purchase）被过滤器正确剔除。**判定 PASS**：过滤机制按设计生效，只是本次"陈年"的具体年份不是 2020，而是超出 90 天窗口的 2026 年 4 月/2 月记录——机制验证结论不变。
- **13F 环比字段未被引用** → PASS。本次产出（§7 样张二）仅引用 `investorsHolding=879`（绝对值），未引用 `investorsHoldingChange`/`numberOf13FsharesChange` 等任何环比字段（该字段在实测返回里确实又出现了 N-7 描述的"残缺假信号"模式：`investorsHolding 879` vs `lastInvestorsHolding 3184`，与 N-7 记载的 NVDA 6234→1441 同一性质，本次未引用，成稿保持洁净）。
- **trader_position 无评级/null notional 行被过滤（shufen 基线）** → PASS，且**本次实测精确复现了 brief 点名的 shufen 基线**：MU 的 `trader_position.top_trader` 原始返回 2 笔，其中 1 笔交易员名字正是 **"shufen"**，`tier: "—"`、`notional_value_usd: null`——与另一笔"风雪"（tier B、notional $130,787）形成鲜明对比。过滤后只保留"风雪"1 笔有效样本，`symbol_rollup.active_trader_count: 2` 这一原始聚合字段本身就会因为把 shufen 算进去而虚增人数，客户端必须手动剔除才能得到"实际 1 位有效交易员"的正确判断。
- **产出温度计贴，跨源打架明写** → PASS，见 §7 样张二；本次三源分歧比设计示例更极端（推特 9 帖全多 vs 真金白銀唯一有效样本反手做空 vs 内部人 90 天只卖不买），已在贴文内明写。

---

## 3. Step 3a — c1 迷你回归（步骤 1/3/4/7）

调用：
1. `news(query="", asset_type="tradfi", time_range="24h")` — quota 0
2. `metrics(query="most active stocks", asset_type="tradfi")` — quota 1
3. `signal(query="consensus", asset_type="tradfi", time_range="24h")` — quota 1
4. `metrics(query="^GSPC ^IXIC ^DJI ^VIX", asset_type="tradfi")` — quota 1
5.（FAIL 触发的补充调用，见下）`metrics(query="BITO ONDS PATH NU T NVDA INTC MARA NOK", asset_type="tradfi")` — quota 1
6.（同上后续）`metrics(query="ONDS INTC MARA NOK", asset_type="tradfi")` — quota 1

c1 迷你回归 quota = 3（核心 1/3/4/7 步骤）+ 2（FAIL 修复后的补充 marketCap 调用）= 5。

### 断言逐项

- **趋势榜 0 额度** → PASS（`quota.consumed: 0`，N-1 复现）。
- **most_actives 过滤后无仙股/杠杆 ETF** → **本次实测发现 1 处 FAIL，已修复重测为 PASS**：
  - **FAIL**：`metrics(query="most active stocks", asset_type="tradfi")` 返回的 10 行**全部不带 `marketCap` 字段**（仅 `price/change/changesPercentage/name/symbol/provenance`），与 c1 文件原有 N-9 记载"回传行自带 marketCap"矛盾——若照抄文件字面操作，marketCap ≥$1B 这一环过滤条件根本无法执行。
  - **修复**：已更正 `skills-community/c1_daily-brief.md` 步骤 3 的表格行、query 示例、第 4 节"异动榜三重过滤"三处文字，加入"另发一次批量 snapshot 补 marketCap"的操作步骤，quota 由 1 改记为 2。
  - **重测**：对 10 个候选 ticker 分两批（一批 9 个因 query 串裁剪只解析出 5 个：BITO/PATH/NU/T/NVDA；second batch 因同一现象只解析出 3 个：INTC/MARA/NOK；**ONDS 两次都被静默丢弃**，已在 c1 文件新增字样提示要核对 `meta.filters_applied.keywords` 补查缺漏）取得 8/9 个候选的真实 marketCap，全部 ≥$1B（BITO $18.4 亿、PATH $64 亿、NU $697 亿、T $1547 亿、NVDA $5.03 万亿、INTC $5300 亿、MARA $46.7 亿、NOK $575 亿）；price<$5 的 VIVK（$2.58，+49%）按仙股规则剔除；ONDS 因 marketCap 两次查询均未确认，保守剔除出最终榜单（示范"验证不到就不用"的诚实取舍，未强行假设其市值达标）。**过滤后判定 PASS**：最终榜单无仙股、无杠杆 ETF、且所有入选标的 marketCap 均已实测确认 ≥$1B。
- **指数快照 ^GSPC ^IXIC ^DJI ^VIX 有值** → PASS。query 串批量一次成功拿到全部 4 个指数（^GSPC 7509.20 / ^IXIC 25837.207 / ^DJI 52224.64 / ^VIX 17.35，均为 2026-07-21 收盘快照），quota 仅 1（未触发批量降级梯）。**附带发现**：返回 5 行而非 4 行，`^VIX` 重复出现一次——`meta.filters_applied.keywords` 显示 `["^GSPC","^IXIC","^DJI","^VIX","VIX"]`，query 解析额外多切出一个裸 "VIX" 关键词导致重复行，数值一致、无害，客户端按 symbol 去重即可，不影响判定。
- **产出六段贴文（缺日历段如实标注）** → PASS，见 §7 样张三；步骤 5-6（财报/宏观日历）按本次任务范围有意跳过，贴文第 5 段已诚实注明"本次為迷你回歸測試...此段暫缺"，未编造日历内容顶替。

---

## 4. Step 3b — c5 菜单回归（扫描两调用）

调用：
1. `news(query="", asset_type="tradfi", time_range="4h")` — quota 0（这是待验证项 (a)，见 §5）
2. `signal(query="consensus", asset_type="tradfi", time_range="24h")` — quota 1

c5 扫描 quota = 1（与文件标称"≈1 点"一致，PASS）。

### 断言逐项与实测过程

- **菜单每条带三档建议之一** → **PASS（真实空菜单）**。步骤 1 的 4h 通道确认不可用（见 §5），按文件既有降级条款改用"24h 窗口 + 客户端按 published_ts 取最近"：复用 Step 3a 已取得的 24h tradfi 趋势榜（8 条），逐条机器核对 `published_ts` 距当下（该次调用的 `time_cutoff_ts + 24h` 换算，非事后估算）的小时数：
  - SKHYx／KOSPI 反弹：距今 11.89 小时，压线在 12 小时时效红线内，但 SKHYx 属代币化噪音（c1/c5 白名单条款明文点名剔除的同一符号），过滤后出局。
  - 其余 7 条：Coherent +11%（13.05h）、Sandisk +13%（17.35h）、NBIS/CRWV（17.40h）、Rocket Lab 合约（17.77h）、GM 财报（22.77h）、SPCX/RKLB 合约（22.77h）、Danaher（22.82h），**全部 >12 小时**，按时效红线一律不得列入。
  - 双重过滤（12h 时效 + 代币化噪音白名单）后，**本轮合格候选为 0 条**。因为"菜单每条都带三档标签"与"无条目 >12h"两项断言在候选集为空时均为真空满足（vacuously true），**判定 PASS**——这本身证明了时效红线与噪音过滤是在真实、严格生效，而不是走过场；如果为了"看起来有内容"硬塞一条 13-23 小时的陈货，反而会违反 S-7 铁律 5 与 c5 第 4 节的机器核对要求。
  - 本轮未成稿（"不成稿省额度"符合任务要求），扫描菜单的诚实产出如下：

```
🔍 熱點掃描 7/22（截至本次調用）
本輪 24h 熱門池共 8 條，經 published_ts 機器核對 + 代幣化噪音過濾後：
・SKHYx／KOSPI 反彈｜距今 11.9 小時壓線達標，但屬代幣化噪音（白名單明文剔除）→ 🚫 建議忽略
・其餘 7 條（Coherent、Sandisk、NBIS/CRWV、Rocket Lab 合約、GM 財報、SPCX/RKLB 合約、Danaher）距今 13–23 小時，逾 12 小時時效紅線 → 🚫 建議忽略（陳貨）
本輪無 🔥/📌 候選，暫不出稿。
```

---

## 5. Step 3c — 两处「实现时验证」项回写结论

### (a) news 趋势模式是否接受 `time_range="4h"`？

**结论：语法上接受（不报 schema 错误），但功能上不可用——固定返回 0 篇。**

`news(query="", asset_type="tradfi", time_range="4h")` 返回 `"articles": []`，`meta.warnings` 明确给出诊断：

> `followin_trending: all 3 trending topics dropped by asset_type="tradfi" filter (no topic matched the requested family — possible upstream tag gap)`

即：4 小时窗口内上游 trending 话题池本身就很小（本次仅 3 条），且这 3 条全部被 tradfi 资产类型过滤器判定为不匹配而剔除（很可能是分类打标缺口，warning 自己也这么猜测）。已回写 `c5_hot-take.md`（表格行 + 正文段落 + query 示例三处），把"待验证"改为"已确认不可行"，并保留最终结论：改用 `time_range="24h"` + 客户端按 `published_ts` 取最近。

### (b) `metrics(query="economic calendar upcoming releases", asset_type="tradfi", date_from=今日, date_to=+7d)` 能否返回前瞻日历？

**结论：能返回真实日历数据（不报错），但 `date_from`/`date_to` 对这条 query 完全不生效——每次调用只回传"锚定日当天"（不传日期时锚定日=调用当下的自然日）约 10 条，7 天窗口不会被单次调用覆盖。**

三次对照测试（同一 query 文案，只换日期参数）：

| 调用参数 | 返回结果 |
|---|---|
| 不传 date_from/date_to | 10 条，全部日期 = 2026-07-22（调用当天） |
| date_from=2026-07-22, date_to=2026-07-29 | 10 条，全部日期 = 2026-07-22（与不传时完全一致） |
| date_from=2026-07-23, date_to=2026-07-29 | 10 条，全部日期 = 2026-07-23（date_from 平移了"锚定日"，但 date_to 依旧不生效） |

三次结果两两对照，确认 `date_from` 只是把"锚定日"往后挪，`date_to` 自始至终没有起到任何扩大窗口的作用。**这对 c1 是好消息、对 c2 是坏消息**：
- c1 步骤 6 只需要"当日"宏观数据——不传日期参数就能拿到调用当天的真实日历（已复核内容合理：韩国 GDP、美国 20 年期公债标售、EIA 数据等，且有实际值/预期值字段），**判定"确认可用"**，已回写 `c1_daily-brief.md`（表格行 + query 示例两处），撤销原本"不通则降级删除"的悬置措辞。
- c2 需要真正的未来 7 天前瞻日历，而这条调用**做不到**——想要 7 天覆盖，唯一办法是把 `date_from` 逐日往后挪、发 7 次调用（各计 1 额度），或退回 c2 第 3 节原本就有的"news() 交叉核实 + 人工锚点表"做法，只覆盖 CPI/FOMC/非农等高关注度单一事件。已回写 `c2_event-radar.md`（正文段落 + query 示例两处），把"待实测验证"改为明确的能力边界说明，不再悬置。

---

## 6. quota 实测总账本

按调用发生顺序（`meta.quota.used` 从会话起点 570 累计到 584，净消耗 14）：

| # | 调用 | 所属步骤 | consumed |
|---|---|---|---|
| 1 | metrics research reports most mentioned | c3 层1 | 1 |
| 2 | metrics NVDA research reports detail | c3 层2 | 1 |
| 3 | signal consensus (3d) | c4 步骤1 | 1 |
| 4 | signal MU 详细仓位 (7d) | c4 步骤2 | 1 |
| 5 | news 趋势 (24h) | c1 步骤1 | 0 |
| 6 | metrics most active stocks | c1 步骤3 | 1 |
| 7 | signal consensus (24h) | c1 步骤4 | 1 |
| 8 | metrics ^GSPC ^IXIC ^DJI ^VIX | c1 步骤7 | 1 |
| 9 | news NVDA Nvidia (7d，搜索模式) | c3 补充素材 | 0 |
| 10 | news 趋势 (4h) | c5 待验证(a) | 0 |
| 11 | metrics 经济日历（date_from=今日,date_to=+7d） | 待验证(b) 测试1 | 1 |
| 12 | metrics marketCap 批量（5/9 ticker 解析） | c1 步骤3 FAIL 修复 | 1 |
| 13 | metrics marketCap 批量（3/4 ticker 解析） | c1 步骤3 FAIL 修复 | 1 |
| 14 | metrics 经济日历（date_from=明日,date_to=+7d） | 待验证(b) 测试2 | 1 |
| 15 | signal consensus (24h，c5 独立触发) | c5 步骤2 | 1 |
| 16 | metrics 经济日历（不传日期） | 待验证(b) 测试3 | 1 |
| 17 | metrics MU（可选价格锚点） | c4 可选步骤 | 1 |

上表共 17 次调用，其中 14 次 `consumed=1`、3 次 `consumed=0`（#5 news 趋势、#9 c3 补充新闻、#10 c5 待验证 4h 测试），**合计 consumed = 14**，与 `meta.quota.used` 从会话起点 570 累计到本步骤末尾 584 的差值完全吻合。

分模块小计：
- c3：2（核心）+ 0（补充素材）= **2**（标称 ≤6，PASS，余量充足）
- c4：2（核心）+ 1（可选价格锚点）= **3**（标称 ≈4-6/周，PASS）
- c1 迷你：3（核心步骤 1/3/4/7）+ 2（FAIL 修复的 marketCap 补查）= **5**
- c5：**1**（标称 ≈1 点，PASS）
- 待验证项专项验证：**3**（经济日历三次对照测试，不计入任何模块标称额度，属本次回归专项调查成本）

**总计 14 点**，对应 17 次工具调用（3 次 0 消耗）。

---

## 7. 产出样张（三份全文）

### 样张一：c3 NVDA 研究笔记

```
📌 本週研報熱點｜NVDA 輝達

一句話先懂：過去 7 天被機構研報提到最多的股票就是輝達（94 篇、22 家機構），三家大行目標價落在 $288–350，比現價 $207.54 高出約 39%～69%。

最新動態：台灣 6 月出口訂單暴增 59.4%、創下 952.6 億美元新高，連續 17 個月成長——這是輝達 GPU 供應鏈的先行指標，市場解讀為 AI 熱潮還在加速，不是放緩。同一時間，AMD 宣布與 Anthropic 談成一筆 AI 伺服器大單，據報道總規模上看數百億美元，AMD 這次投入最高達 50 億美元，被視為輝達最直接的挑戰者又添一筆籌碼。

機構怎麼看（近兩週最新報告，已按機構＋標題＋日期去重）：
・摩根士丹利 $288：管理層對外展現的成長證據更廣泛——AI 實驗室、雲端大廠、新創算力商、主權基金、工業客戶都在加單，公司還提出新的「新雲算力商」聯合投資模式
・花旗 $300：記憶體缺貨反而對輝達有利，其產品與互聯路線圖維持不變，AI 需求正從雲端大廠擴散到更廣泛的客群
・美國銀行 $350：財測明顯優於市場共識（估 2027 年每股獲利 9.09 美元，高於市場共識 8.99 美元），市場擔心的記憶體成本上升、對手競爭，其實都已經反映在股價裡

推特風向：
🐦 GB300 系統已在德州量產：緯創 7 億美元德州廠正式投產，專攻 Grace Blackwell Ultra 系統，下一步是 Vera Rubin（A 級帳號）
🐦 網通新戰場：輝達的 Spectrum-6，一款 102.4T 超高速乙太網路交換器，已開始進駐大型 AI 資料中心——輝達的「另一張臉」不只是晶片，還有全球最大網通公司的野心（A 級帳號）
🐦 本週四有大事：南韓總統率三星、SK、NAVER 掌門人赴矽谷，與 OpenAI、輝達、Anthropic 執行長會面，黃仁勳、Sam Altman 都在受邀名單上

空方在擔心什麼：研報點名的下檔風險是遊戲業務被競爭對手搶市佔、新平台採用速度不如預期會拖累資料中心與遊戲營收。推特上也有 A 級帳號提醒，輝達的 Kyber 機櫃因工程挑戰恐延後甚至取消量產，最快要 2027 年才會進入量產階段。另一個更大的疑慮是：AMD 剛拿下 Anthropic 的大單，也有分析認為 Alphabet 可能是大型科技公司裡第一個下修 AI 資本支出的——如果雲端大廠真的開始收緊 AI 支出，輝達的下游需求會是第一個受影響的。

接下來看什麼：今晚 Alphabet、特斯拉盤後公布財報（AI 資本支出是否降溫是焦點）＋ AMD「Advancing AI 2026」大會會不會秀出更接近輝達 Vera Rubin 的機櫃方案＋ 本週四南韓矽谷之行有沒有新的供應鏈合作訊息。

今日名詞：目標價
分析師用公司未來獲利推算出的「合理股價」。可以粗略理解成：機構覺得這支股票值多少錢。但它是預測不是保證，財報變差時目標價也會跟著下修。

⚠️ 以上整理自公開研報與市場數據，僅做資訊分享，不構成投資建議。
```

**S-12 自检**：繁体✓（s2t 校验仅命中 台/布/群 等台湾标准繁体与archaic异体字的已知假阳性，无真简体字混入）大白话✓（目標價有名词卡解释）字数✓（801 hanzi，≤1000 上限内）名词卡✓ 免责✓（S-11 逐字比对一致）多空平衡✓（机构看多 3 家 + 空方段落含游戏竞争/平台采用/Kyber 延迟/AMD 竞品/Alphabet 资本支出四条风险）单源标注✓（AMD-Anthropic 交易为 WSJ 主流媒体商业报道，非地缘/政策/监管传闻，不落入 S-7 铁律 1 的强制双源门槛）价格可回溯✓（$207.54、$288/$300/$350 均取自本次 detail 调用返回）目标价家数可回溯✓（3 家机构、4 份报告，去重过程见 §1）。

### 样张二：c4 MU 熱議溫度計

```
📌 本週熱議溫度計｜7/16–7/22

一句話先懂：本週推特喊單最熱是 SPCX 與 MU 並列（各 9 帖），MU 現價 $951.82，但推特一面倒看多的同時，真金白銀和內部人這週都沒跟上。

本週推特在吵什麼
喊單聚合榜：1️⃣ SPCX、MU（並列，各 9 帖）2️⃣ SMCI、NBIS、BRUN（並列，各 5 帖）｜整體多空比 13.3:1（120 篇看多、9 篇看空），情緒偏熱

MU 溫度計
🐦 推特情緒：多 9：空 0｜正：一位技術分析型 KOL（A 級）指出「記憶體需求持續超過供給，Micron 正邁向史上最賺錢的一年，2027 年獲利還會再翻一倍」｜反：暫無明顯反方聲音，推特上唯一偏保守的一則只是「現在卡在關鍵壓力位，風險報酬比不划算」的技術面提醒——一面倒看多本身就是風險訊號
💰 真金白銀：本週僅 1 位交易員留下有效樣本（另 1 位無評級、無金額紀錄已剔除），且這位是以 20 倍槓桿放空 MU、名目部位約 13.1 萬美元——方向與推特喊單完全相反，樣本也偏薄，本週實盤數據樣本太薄，不足以代表整體真實資金態度
🏢 內部人動向：近 90 天僅 4 筆 S-Sale（賣出），無 P-Purchase（買入）；賣方包括執行長本人（6 月底一筆）與財會、業務主管，同一時間沒有任何一位內部人選擇買進

跨源打架：情緒滿格 ≠ 大錢進場——推特喊單 9 帖全多，但這週唯一有效的真金白銀樣本卻是反向放空，內部人這 90 天也只有賣沒有買，三個維度沒有一個真的跟上推特的熱度。

接下來看什麼：留意這位放空交易員的部位會不會平倉轉向，以及下次內部人申報會不會出現本季第一筆買進——任一項出現都可能是風向轉變的訊號。

今日名詞：真金白銀
交易員拿自己真實資金開的實盤倉位，和「喊單」不同——喊單可能只是嘴上看好，真金白銀才是拿錢投票。可以粗略理解成：聽人講不如看他自己敢不敢下注。

⚠️ 以上整理自公開研報與市場數據，僅做資訊分享，不構成投資建議。
```

**S-12 自检**：繁体✓（s2t 校验仅命中 才 等台湾标准繁体字的已知假阳性）大白话✓ 字数✓（563 hanzi，落在 500-800 区间）名词卡✓ 免责✓ 多空平衡✓（推特多方 vs 真金白银/内部人空方，跨源打架句已明写）单源标注✓（无地缘/政策/监管类单源声明需要处理）价格可回溯✓（$951.82 取自本次 metrics 快照）实盘数据当天现拉✓（trader_position 为本次调用现拉，非缓存）。

### 样张三：c1 每日早報（迷你回歸版）

```
📌 每日早報｜7/22（三）

大盤一眼：三大指數 7/21 收盤集體收紅——標普 500 收 7509.20（+0.89%）、那斯達克收 25837.21（+1.29%）領漲、道瓊收 52224.64（+0.74%），VIX 仍在 17.35 的低檔區間，市場情緒偏樂觀但不算亢奮。

昨夜三件事：
1️⃣ 輝達披露持股 AI 算力公司 Nebius 9.3% 股份，NBIS 暴漲 17%、CRWV 漲 7.4%，AI 算力鏈全線跟漲｜為什麼和你有關：輝達自己都下場投資算力公司，代表它對算力需求的信心，連帶整個 AI 供應鏈跟著雞犬升天
2️⃣ 存儲股 Sandisk 單日飆升 13%，帶動存儲與 AI 硬體板塊集體反彈｜為什麼和你有關：AI 伺服器要吃下大量記憶體，只要 AI 熱潮不退，記憶體概念股就有故事可以講
3️⃣ GM 財報優於預期、上調全年指引，盤中一度漲 3.6%｜為什麼和你有關：傳統車廠財報某種程度也反映一般消費者荷包鬆不鬆，不是只有科技股才重要

推特風向：24h 喊單最熱 = SPCX、MU 並列（各 9 帖），SMCI、NBIS、BRUN 並列（各 5 帖）；整體多空比 13.3:1，情緒偏熱（昨日內部人申報無大額真買入）

漲跌榜看點：INTC +8.64%（半導體類股同步走強，明日適逢財報）、NOK +5.65%（網通設備股同步走強）、MARA +4.97%（追蹤比特幣價格走強，同日 BITO 也上漲）——以上均為過濾仙股與槓桿 ETF 後、市值確認在 10 億美元以上的標的

今日看什麼：本次為迷你回歸測試，比照步驟 1/3/4/7 執行，跳過財報日曆與宏觀日曆兩步（步驟 5-6），此段暫缺——正式排程跑早報時仍會完整涵蓋當日財報名單與宏觀數據

今日名詞：多空比
一段時間內看多和看空的貼文數量比例。可以粗略理解成：這群人裡面覺得會漲的比覺得會跌的多幾倍。這只是情緒溫度，不是保證未來走勢的水晶球。

⚠️ 以上整理自公開研報與市場數據，僅做資訊分享，不構成投資建議。
```

**S-12 自检**：繁体✓（s2t 校验仅命中 升/吃/只/群 等台湾标准繁体字的已知假阳性）大白话✓ 字数✓（502 hanzi）名词卡✓（多空比）免责✓ 多空平衡✓（大盘/涨跌榜均为正向，但已诚实注明缺日历段，未为了凑六段而编造内容——S-7 铁律 3 镜像）单源标注✓ 价格可回溯✓（指数、涨跌榜数字均取自本次调用）。本篇未附互动钩子（比照 T-2 已核可样例的做法，当天额度留给潜在的 c5 产出，本次 c5 未成稿故实际未消耗）。

---

## 8. 本次修复的 skill 文件清单

| 文件 | 修复内容 | 触发原因 |
|---|---|---|
| `skills-community/c1_daily-brief.md` | 步骤 3 most_active 加注"board 行不带 marketCap，需补批量 snapshot"+ quota 1→2；步骤 6 econ calendar 由"待验证/不通则删除"改为"已确认可用" | FAIL（marketCap 缺失）+ 待验证项(b) |
| `skills-community/c5_hot-take.md` | 步骤 1 news 4h 窗口由"待验证"改为"已确认不可行，固定降级 24h" | 待验证项(a) |
| `skills-community/c2_event-radar.md` | 步骤 3 econ calendar 由"待实测验证"改为"query 串可路由但仅锚定日单日、date_to 不生效，7 天前瞻需逐日调用" | 待验证项(b) |

三处修复均为局部文字替换（表格单元格 + query 示例 + 正文段落），未改动文件的整体结构、frontmatter 或其他未涉及的章节。

---

## 9. 残留关注点（非阻塞，供后续参考）

1. **query 串批量会静默丢弃部分 ticker**（本次实测：9 个 ticker 的空格拼串只解析出 5 个，"ONDS" 连续两次被跳过且无对应 warning 提示）——已在 c1 文件相关段落提示需核对 `meta.filters_applied.keywords`，但未追加到 `.claude/references/followin-mcp-caveats.md` SSOT（该文件不在本次 commit 范围内，留待下次统一 sweep 时回写）。
2. **signal consensus 聚合结果对 time_range 参数不敏感**：本次分别以 `time_range="3d"`（c4）、`time_range="24h"`（c1 与 c5，各自独立触发共 2 次）调用 `signal(query="consensus", asset_type="tradfi")`，四次调用返回的 `total_posts`（132）、`bull_bear_ratio`（13.333...）、Top 5 榜单完全一致，未观察到随窗口收窄而变化——可能是数据池本身小到 3d/24h 收敛成同一结果，也可能是该聚合未真正按 time_range 切片，本次证据不足以下定论，留待后续更大窗口差异（如 3d vs 30d）时再验证。
3. c3 层 1 聚合榜的 `meta.warnings` 携带的通用 fanout 提示噪声（见 §1 附带观察）与文件预期的 `research_report_limit_capped` 键名不一致，暂未回写，留待下次遇到真正触发限流场景时核对真实键名。
