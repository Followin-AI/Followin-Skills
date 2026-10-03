---
name: Community Daily Brief (c1 — 社群美股早報·晨晚雙時段)
description: 美股新手社群每日早報。晨報（台北早晨）=昨夜收盘复盘+今日看点六段结构；開盤前瞻（台北21:00前后）=盘前三段精简版；刷新=盘中增量补丁。产出直接可贴社群的繁体贴文。仅供运营使用。
trigger: 早報、晨報、跑早报、社群早报、開盤前瞻、开盘前瞻、刷新、community daily brief
not_trigger: 宏观深度日报（走 macro-morning-brief）、热点扫描（c5）、研报（c3）、温度计（c4）、标的速查（c6）、週報（c2）
mcp: mcp__followin__metrics, mcp__followin__news, mcp__followin__signal
args: mode(晨報|開盤前瞻|刷新，默认晨報)
---

# c1 每日早报——社群美股早报（晨/晚双时段）

本 skill 仅供社群运营人员触发使用（群成员不直接交互）。三种模式共用同一套数据源与调用序列：晨报＝完整六段早报，開盤前瞻＝晨报的精简前瞻版，刷新＝盘中增量补丁。默认 mode=晨報（见 frontmatter `args`）。

## 1. 模式路由表

| 模式 | 触发时机（台北视角） | 执行步骤 | 产出长度 |
|---|---|---|---|
| 晨報 | 台北早晨跑，美股昨夜已收盘 | 全流程步骤 1-7 | ≤1000 字，六段结构（S-4） |
| 開盤前瞻 | 台北 21:00 前后跑，美股开盘前约 30 分钟 | 只跑步骤 1、7 | 约 300 字，2-3 点 |
| 刷新 | 当日已出晨报后，盘中任意时刻 | 步骤 1、3、4 增量（`time_range` 仍用 24h——4h 窗口实测返 0 篇，同 c5 记载；增量靠客户端按 published_ts 过滤） | 200-400 字增量补丁贴 |

- **晨報**＝全流程 7 步：美股昨夜已收盘，出完整「收盘复盘 + 今日看点」六段结构（见第 3 节）。
- **開盤前瞻**＝只跑步骤 1、7：美股尚未开盘，精简输出三点——今晚开盘關注 / 盘前异动快照（引用快照自带的 `extendedHoursQuote` 字段，标注「盤前」）/ 今晚数据几点，约 300 字 2-3 点。与晨报同一 skill、共用触发词组（"早報"/"開盤前瞻"，含简体形式），路由到同一份调用序列，只是只跑其中两步。
- **刷新**＝步骤 1、3、4 增量：`time_range` 收窄到 4h，只出「新增」内容，已在当日早报出现过的条目不重复，产出 200-400 字增量补丁贴（"午间更新：新增 XX 两件事"）。**无当日晨报 baseline 时拒绝刷新，先提示运营"请先跑晨报"**。小时级增量一律只用当次调用返回的即时快照做判断，不要另外去拉小时级历史——`metrics()` 的 `time_range < 1d` 有已知 bug，会返回一个月前的旧数据而非当日窗口（镜像 N-10：metrics time_range <1d 返一个月前旧数据 bug；小时级用 interval 参数或只用实时快照）。

## 2. 调用序列（实测额度 ≈9/天）

调用序列：

| 步骤 | 调用 | 额度 |
|---|---|---|
| 1 | `news(query="", asset_type="tradfi", time_range="24h")` 热点趋势榜 | 0（实测） |
| 2 | （按需）对头条事件 `news(query="<核心名词×2>", asset_type="tradfi", time_range="24h")` 补细节，≤3 次 | 0（实测） |
| 3 | `metrics(query="most active stocks", asset_type="tradfi")` 异动榜（要涨跌幅榜可另调 `query="biggest gainers"` / `"biggest losers"`，2026-10-01 实测数据已恢复正常，但仍以仙股为主）。三张榜的行都只有 symbol / name / price / change / changesPercentage 五个字段，**不带 marketCap 和 exchange**，需对候选 ticker 另发一次 `metrics(keywords=[≤5 个 ticker], query="行情", asset_type="tradfi")` 补快照取 marketCap 后再套用 ≥$1B 过滤（**≤5 个一批**，超出会在 `meta.warnings` 里报 `keyword_count_over_max`） | 2 |
| 4 | `signal(categories=["kol_call"], query="consensus", asset_type="tradfi", time_range="24h")` 喊单榜 + 多空比；内部人大额动向**另调** `signal(categories=["insider_trading"], asset_type="tradfi", limit=50)`（不带 time_range，客户端按 transactionDate 过滤）——2026-10-01 实测：不传 categories 只返喊单一类；两类合在一次调用里再带 `time_range="24h"`，内部人整类静默消失 | 2 |
| 5 | 当日财报两条腿：① 关注池逐批 `metrics(keywords=[≤5 个 ticker], query="next earnings date", asset_type="tradfi")`，取 `next_earnings_estimate.date` = 今日的；② 市场级日历 `metrics(query="earnings calendar", asset_type="tradfi", country="US", date_from=<今日>, date_to=<今日>)` 补关注池外的名字（2026-10-01 实测已恢复可用，但带 `status:"partial"`，覆盖不保证全）。做法与铁律见 c2 第 2 节 | 关注池数 ÷5 ＋ 1 |
| 6 | `metrics(query="economic calendar upcoming releases", country="US")` 当日宏观数据发布（**`country="US"` 必传**——2026-10-01 实测不传返回的是韩国 / 印度 / 博茨瓦纳的事件）| 1 |
| 7 | 大盘指数 `metrics(keywords=["^GSPC","^IXIC","^DJI","^VIX"], query="行情", asset_type="tradfi")` + 过滤后重点股快照（同样走 keywords 数组，≤5 个一批） | 1-4 |

调用形态铁律（本序列全程通用）：

> **调用形态（2026-10-01 实测，取代 2026-07-20 的"数组被拒、只能 query 串"铁律）**：`metrics` / `signal` 的入参分工是 **`keywords` 数组放标的、`query` 放意图词、`categories` 指定类别**。纯美股代码写进 query 串目前仍能被解析，但指数会多解析出一个重复项（`"^GSPC ^IXIC ^DJI ^VIX"` → 多一个 `VIX`，返回 `status:"partial"`），`*USD` 商品代码写进 query 串会**整批返空且不报错**——所以标的一律走数组。每次调用最多 5 个 keywords，超出或解析不了的项写在 `meta.warnings`（`keyword_count_over_max` / `kw_not_canonical`），**调用后读一遍 `meta.warnings`**，有缺口分批补。单批并行 ≤4 路（SSE 红线）。客户端不接受数组入参（报 `-32602`）时，美股代码与指数可退回 query 串，商品代码没有可用的 query 串写法。另：Followin session 每 5-8 次调用可能短挂，重试 1 次即恢复，还不行让运营 `/mcp restart followin`。

每步 query 主形态调用示例：

```
1. news(query="", asset_type="tradfi", time_range="24h")
   # 趋势模式，quota=0

2. news(query="<核心名词1> <核心名词2>", asset_type="tradfi", time_range="24h")
   # 搜索模式；2026-10-01 实测传 asset_type="tradfi" 正常返回（旧"加了返 0 篇"已不复现）。
   # 要权威报道可加 sources=["media"], sort_by="relevance"。≤3 次，按需

3. metrics(query="most active stocks", asset_type="tradfi")
   # 异动榜；返回行不带 marketCap / exchange，先用候选 ticker 批量
   # metrics(keywords=[≤5 个], query="行情", asset_type="tradfi") 补快照取 marketCap，再套过滤见第 4 节

4. signal(categories=["kol_call"], query="consensus", asset_type="tradfi", time_range="24h")
   # 喊单聚合（总帖数 / 多空比 / top_calls），1 额度
   signal(categories=["insider_trading"], asset_type="tradfi", limit=50)
   # 内部人全市场最新申报，1 额度；不带 time_range，客户端按 transactionDate 过滤

5. 对关注池逐批（≤5 只）：metrics(keywords=["<T1>",…,"<T5>"], query="next earnings date", asset_type="tradfi")
   # 取 next_earnings_estimate.date = 今日的
   metrics(query="earnings calendar", asset_type="tradfi", country="US", date_from="<今日>", date_to="<今日>")
   # 市场级日历补漏；status 恒为 partial，不能当"当日全貌"

6. metrics(query="economic calendar upcoming releases", country="US")
   # 宏观日历；country="US" 必传；query 严禁带"本周"（红线 10，会返历史而非前瞻）

7. metrics(keywords=["^GSPC","^IXIC","^DJI","^VIX"], query="行情", asset_type="tradfi")
   # 大盘四指数一次批量；快照没有涨跌幅字段，自算 change ÷ previousClose × 100
```

## 3. 产出模板

六段骨架（≤1000 字）：

1. **大盤一眼**：三大指数 ETF 昨收涨跌 + 一句话定调（盘前跑则引用快照自带的 extendedHoursQuote 标注"盤前"）
2. **昨夜三件事**：每件 = 发生了什么 + 受影响标的怎么走 + "为什么和你有关"白话一句
3. **推特風向**：24h 喊单最热标的 + 多空比一行；内部人昨日有大额真买入（P-Purchase）则加一行
4. **漲跌榜看點**：过滤后各取 2-3 只，涨跌原因一句
5. **今日看什麼**：当日财报（谁、市场在赌什么）+ 当日宏观数据（几点、为什么重要）
6. 今日名詞卡 + 免责声明

长度按 S-4 镜像：晨报≤1000 字；開盤前瞻/刷新 200-400 字（前瞻约 300 字，仅含六段中的第 1、第 5 段内容，对应只跑的步骤 1、7）。

第 7 段互动钩子（S-3 镜像，可选）：只出现在 c1/c5，**一天最多一次**——晨报/開盤前瞻/刷新三种产出算同一天的份额，当天已用过一次后其余产出不再加；问题必须无立场、不诱导买卖方向。

以下是 T-2 样例（2026-07-22 已核可，逐字收录作为示例输出。实际产出照此排版：纯文字＋emoji，不套 markdown 加粗/标题/表格，层级靠 emoji ＋ 空行 ＋「｜」——S-9 镜像）：

```
📌 每日早報｜7/22（二）

大盤一眼：三大指數 ETF 昨收 →（一句話定調；盤前跑則引用 extendedHoursQuote 標注「盤前」）

昨夜三件事：
1️⃣ 輝達披露持股 Nebius 9.3%，NBIS 暴漲 17%，AI 算力鏈全線跟漲｜為什麼和你有關：一句白話
2️⃣ 存儲板塊集體反彈，SNDK +13%（AI 伺服器吃記憶體）｜…
3️⃣ GM 財報超預期上調全年指引，盤中 +3.6%｜…

推特風向：24h 喊單最熱 = MU（9 帖全多）、SPCX、NBIS；整體多空比 12:1，情緒偏熱

漲跌榜看點：過濾後各取 2-3 只，漲跌原因一句

今日看什麼：今天 LVS 財報（市場在賭什麼一句）；本週四黃仁勳與三星/SK 掌門圓桌（美東+台北雙時間）

今日名詞：（一張卡）
⚠️ 以上整理自公開研報與市場數據，僅做資訊分享，不構成投資建議。
```

## 4. 防坑镜像（逐条，来源编号见括号）

- **异动榜过滤**：客户端过滤 = marketCap ≥$1B + 剔杠杆 ETF（name 匹配 `ETF|ETN|UltraPro|Ultra|Leveraged|\dX|Bull|Bear|Daily`）；价格 <$5 的仙股闸只在市值拿不到时兜底（实测会误杀 GRAB 这类低价大市值票）。三张榜（most active / gainers / losers）的行都**不带 marketCap 和 exchange**（2026-10-01 实测只有 symbol / name / price / change / changesPercentage），须另发一次批量快照补 marketCap 才能套 ≥$1B 过滤。涨跌幅榜 2026-10-01 实测数据已恢复正常（旧"禁用"撤销，N-111），但榜首仍多为仙股，过滤照做。
- **代币化+加密噪音白名单剔除**：趋势榜内容含代币化股票与加密混排（实测 SKHYx、LAB 代币），按"美股正股白名单"原则剔除。（来源：c1 本次实测命中 SKHYx、LAB）
- **news 的 asset_type**：趋势模式（空 query）与搜索模式都可传 `asset_type="tradfi"`，均 0 额度（2026-10-01 实测搜索模式传了正常返回，旧"加了返 0 篇"不再复现，N-112）。需要权威报道时加 `sources=["media"], sort_by="relevance"`。⚠️ 宽主题词搜索传 tradfi 时可能带 `asset_type_no_matching_keyword` 提示，属正常。
- **内部人 transactionDate=昨日，只认 S-Sale/P-Purchase**：步骤 4 的内部人行客户端过滤 transactionDate=昨日，且只认 `formType=="4"` 的 S-Sale / P-Purchase（F-InKind / M-Exempt 是缴税代扣 / 豁免行使，剔除；2026-10-01 实测榜首常是 `formType:"3"`、`transactionType` 为空的新任董事初始申报，同样剔除）。**不要给内部人调用带 time_range**：实测带 `7d` 返回 `status:"partial"`，与喊单合并调用再带 `24h` 时内部人整类静默消失。
- **市场级财报日历已恢复，但只能当补漏腿（N-114，2026-10-01 实测）**：`metrics(query="earnings calendar", asset_type="tradfi", country="US", date_from, date_to)` 现在返回无后缀美股代码（实测 10-01~10-08 返回 AYI / MKC / NKE / STZ / LEVI 等）并支持 cursor 翻页，7 月"只返回字母前段"的问题（N-22）不再复现。但响应恒带 `status:"partial"`（部分标的缺国别档案，country 过滤无法完全执行），**覆盖不保证全**——主腿仍是关注池 + `next_earnings_estimate` 核实，做法见 c2 第 2 节。
  🔒 **对外发布铁律**：贴文写「今天我们盯的这几家发财报」，**严禁写「今日财报一览」**——日历是 partial 的，把它当"当天全貌"的任何变体都是错的。
- **指数走 keywords 数组，别写进 query 串（N-18，2026-10-01 复测）**：query 串 `"^GSPC ^IXIC ^DJI ^VIX"` 仍被解析成 5 个 keywords（多出一个裸 `VIX`）、^VIX 出现两条相同的行、`status:"partial"`；`keywords=["^GSPC","^IXIC","^DJI","^VIX"]` 数组写法返回干净的 4 行。若客户端只能发 query 串，写贴文前按 `symbol` 去重。
- **原油走 `CLUSD` / `BZUSD`，必须用 keywords 数组（N-106，2026-10-01 实测）**：`metrics(keywords=["CLUSD","BZUSD"], query="行情", asset_type="tradfi")` 直接返回 WTI 与布油期货价，不必再用 USO 代理。⚠️ **商品代码写进 query 串整批返空且不报错**（实测 `query="GCUSD CLUSD BZUSD ESUSD 行情"` → 0 结果、`status:"ok"`），黄金 `GCUSD`、白银 `SIUSD`、美元指数 `DXUSD` 同理只能走数组。`OIL` / `GOLD` 别名仍会解析成同名美股，不要用。
- **S-7 五铁律（全文镜像，五条均对本 skill 生效）**：
  - 铁律1 单源：地缘/政策/监管大消息 ≥2 独立信源才当事实，否则标「消息尚待確認」。
  - 铁律2 价格：当前价/涨跌幅只引本次 MCP 返回值；新闻与 KOL 转述的百分比是二手，必经快照核实。
  - 铁律3 禁凑数：无大事就写「今日平靜」，禁陈货硬凑。
  - 铁律4 时间：宏观/财报时间标 美东+台北 双时区；禁按惯例推算日期。
  - 铁律5 时效：引用行情标「截至 XX:XX」；>12h 旧闻不得当"实时热点"。

## 5. 发前自检

S-12 清单（逐字，每篇产出前逐项过）：

> 繁体✓ 大白话✓ 字数✓ 名词卡✓ 免责✓ 多空平衡✓ 单源标注✓ 价格可回溯✓

额度哨兵（内部提醒，不进对外贴文）：

> **额度哨兵**：每次模块跑完读一次 `meta.quota`（每个返回都带，实测），`remaining/limit < 15%` 时在产出末尾附一行内部提醒（不进对外贴文）："⚠️ 本月額度剩 N 次，按當前節奏約可跑 X 天，考慮降頻或升級"。额度见底导致日更断档比任何单篇内容缺失都伤运营。
