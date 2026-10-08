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
| 晨報 | 台北早晨跑，美股昨夜已收盘（**美东当日 09:30 开盘后不跑晨報，改走刷新**——开盘后指数快照是盘中价，「昨收」不成立） | 全流程步骤 1-7 | ≤1000 字，六段结构（S-4） |
| 開盤前瞻 | 台北 21:00 前后跑，美股开盘前约 30 分钟 | 只跑步骤 1、6、7（财报沿用当日晨報步骤 5 的结果，不重跑） | 约 300 字，2-3 点 |
| 刷新 | 当日已出晨报后，盘中任意时刻 | 步骤 1、3、4 增量（`time_range` 仍用 24h——4h 窗口实测返 0 篇，同 c5 记载；增量靠客户端按 published_ts 过滤） | 200-400 字增量补丁贴 |

- **晨報**＝全流程 7 步：美股昨夜已收盘，出完整「收盘复盘 + 今日看点」六段结构（见第 3 节）。
- **開盤前瞻**＝只跑步骤 1、6、7：美股尚未开盘，精简输出三点——今晚开盘關注 / 盘前异动快照（用快照的 `extendedHoursQuote` 自算盤前價，口径见第 4 节「快照时间点与盤前價」，标注「盤前 美東 HH:MM」）/ 今晚数据几点（步骤 6；财报沿用当日晨報步骤 5 的结果），约 300 字 2-3 点。与晨报同一 skill、共用触发词组（"早報"/"開盤前瞻"，含简体形式），路由到同一份调用序列，只是只跑其中三步。
- **刷新**＝步骤 1、3、4 增量：`time_range` 仍用 24h，客户端按 `published_ts` 晚于当日晨報生成时间过滤，只出「新增」内容，已在当日早报出现过的条目不重复，产出 200-400 字增量补丁贴（"午间更新：新增 XX 两件事"）。**无当日晨报 baseline 时拒绝刷新，先提示运营"请先跑晨报"**。小时级增量一律只用当次调用返回的即时快照做判断，不要另外去拉小时级历史——`metrics()` 的 `time_range < 1d` 有已知 bug，会返回一个月前的旧数据而非当日窗口（镜像 N-10：metrics time_range <1d 返一个月前旧数据 bug；小时级用 interval 参数或只用实时快照）。

## 2. 调用序列（晨報额度 ≈6-10＋⌈关注池/5⌉；開盤前瞻 2-3；刷新 2-3）

> 额度按下表逐步加总：常见情况 6-10＋⌈关注池/5⌉（数据少的日子最低约 6）；另调涨跌幅榜、补快照用满 3 批时上探到约 14＋⌈关注池/5⌉（关注池 10 只＝常见 8-12、上限约 16）。2026-10-08 起市场级财报日历腿停用（见第 4 节），上限比旧版少 4。開盤前瞻＝步骤 1（0）＋6（1）＋7（1-2）；刷新＝步骤 1（0）＋3 的异动榜（1，沿用晨報已补的市值）＋4 的喊单（1）。

**窗口口径（2026-10-05 实测）**：「昨夜」＝上一个美股常规交易日收盘（美东 16:00）前后。步骤 1、2 的 `time_range`：周二至周五用 `24h`，**周一用 `72h`；台北前一天（＝美东当天）美股休市时用 `96h`**（例：美东周一休市 → 台北周二那一跑用 96h。按台北日期判断，不要理解成「美东首个交易日」）——周一盘前用 24h，趋势榜只剩周一当天 3 条、周五非农整条不见，改 72h 才出现。步骤 4 的喊单上游只有 24h、改不了，周一跑时贴文写「近一日（多為週末討論）」。下文凡写「昨日」，一律指上一个美股交易日。

调用序列：

| 步骤 | 调用 | 额度 |
|---|---|---|
| 1 | `news(query="", asset_type="tradfi", time_range=<窗口口径>)` 热点趋势榜（通常只有 3-5 条，`limit` 调大也不会变多，2026-10-05 实测；只用来发现题目，见第 4 节） | 0（实测） |
| 2 | （按需）对头条事件 `news(query="<核心名词×2>", time_range=<窗口口径>)` 补细节，≤3 次 | 0（实测） |
| 3 | 三张榜一律 `metrics(query="most active stocks", asset_type="tradfi", limit=30, verbosity="concise")` 异动榜（不传 `limit` 只返 10 行，2026-10-05 实测；要涨跌幅榜可另调 `query="biggest gainers"` / `"biggest losers"`，同样带 `limit=30`，仍以仙股为主，且榜首可能是合股造成的假涨幅，见第 4 节）。三张榜的行都只有 symbol / name / price / change / changesPercentage 五个字段，**不带 marketCap 和 exchange**：先按第 4 节「异动榜过滤」预筛，预筛后把各张榜的行合并、按代码去重，**先只留 `|changesPercentage| ≥ 3%` 的行，再按 `price` 从高到低取前 15 只**（三张榜合计 15 个名额，不再每张榜固定前 5——高价股多是大盘股，这样 ARGX 这类大盘股会先补到快照；2026-10-08 实测按旧的"每榜涨跌幅前 5"，市值 $500 亿的 ARGX −12.8% 排在跌幅榜第 6、补不到快照），再发 `metrics(keywords=[≤5 个 ticker], query="行情", categories=["market"], asset_type="tradfi")` 补快照取 marketCap，套用 ≥$1B 过滤（**≤5 个一批、最多 3 批**，超出会在 `meta.warnings` 里报 `keyword_count_over_max`）。只调了 most active 时名额照样按价格分，不必凑满 15 | 2-4（另调涨跌幅榜 +2） |
| 4 | `signal(categories=["kol_call"], query="consensus", asset_type="tradfi", time_range="24h")` 喊单榜 + 多空比；内部人大额动向**另调** `signal(categories=["insider_trading"], asset_type="tradfi", sort_by="amount", limit=50)`（不带 time_range，客户端按 `filingDate` 过滤，窗口与「大额」口径见第 4 节）——2026-10-01 实测：不传 categories 只返喊单一类；两类合在一次调用里再带 `time_range="24h"`，内部人整类静默消失 | 2 |
| 5 | 当日财报：① **主腿**＝关注池逐批 `metrics(keywords=[≤5 个 ticker], query="next earnings date", asset_type="tradfi")`，取 `next_earnings_estimate.date` = 今日的（顺带返回的当日 `earnings_calendar` 块不看——市场级日历已停用，见第 4 节）；② **补漏**＝1 次新闻搜索 `news(query="earnings preview what to expect report before the bell", sources=["media"], time_range=<窗口口径>, limit=30, sort_by="relevance", verbosity="concise")`（**不传 `asset_type`**，N-145；0 额度）。**query 要写成"财报预告"而不是"今天发财报"**：晨報在台北早晨跑＝美东前一晚，原文里的 "today" 指的是已经过去的那一天，搜 `"earnings report today"` 只会拿到已发完的公司（2026-10-08 实测美东 10:43 跑，28 条全是已发布的 PEP / HELE 结果与 APLD / LEVI / RGP 电话会，没有一条是还没发的公司）；预告式 query 同一窗口能拿到 PEP「Thursday before market open」的前一天预告、CNBC「Thursday's big stock stories」和 DAL / JPM / TFC 等预告。**必须带 `sort_by="relevance"`**——默认按时间排，30 条只覆盖最近约 5 小时（同次实测 05:20→10:35 美东），前一天下午发的预告进不来（N-167）。从标题 / 正文里挑**原文写明在美东今日发布**（"before the bell / after the close" ＋ 日期或星期）的关注池外公司，按推算出来的日期不算（铁律 4）；预告只写了公司名、截断的正文里看不到日期的，可以放进下面的核实调用，由 `next_earnings_estimate.date` 确认。已在上一交易日发完的公司归「昨夜大事」素材，不进「今日看什麼」。挑出的名字（≤5）发 1 次 `metrics(keywords=[≤5], query="行情 next earnings date", categories=["market","fundamentals"], asset_type="tradfi")` 核实——同一次调用同时给快照（`exchange` / `marketCap`）和 `next_earnings_estimate`：`next_earnings_estimate.date` = 今日（或 `fiscal_quarters[].earnings_surprise.report_date` = 今日，公司发完后 `next_earnings_estimate` 会跳到下一季，2026-10-08 实测 PEP 当天发完即变成 2027-02-02）、`exchange` 属于 NYSE / NASDAQ / AMEX 且 `marketCap ≥ $1B` 才留，最多写 3 家；没挑出名字就不发这次核实。贴文照旧写「我們盯的這幾家」，覆盖不保证全。做法与铁律见 c2 第 2 节 | ⌈关注池/5⌉ ＋ 0-1 |
| 6 | `metrics(query="economic calendar", country="US", sort_by="hot", date_from=<今日>, date_to=<今日>)` 当日宏观数据发布（**`country="US"` 必传**——2026-10-01 实测不传返回的是韩国 / 印度 / 博茨瓦纳的事件；**`sort_by="hot"` 必传**——不传按时间排，国债拍卖、官员讲话会把 CPI / 非农挤出 50 行，N-128）。筛选：`impact=="High"` 全留，Medium 只留 `estimate` 非空的 | 1 |
| 7 | 大盘指数 `metrics(keywords=["^GSPC","^IXIC","^DJI","^VIX"], query="行情", categories=["market"], asset_type="tradfi")` + 过滤后重点股快照（同样走 keywords 数组，≤5 个一批）；美东 04:00-09:30 或 16:00-20:00 跑时另取 `metrics(keywords=["SPY","QQQ","DIA"], query="行情", categories=["market"], asset_type="tradfi")` 读延长时段报价（指数没有 `extendedHoursQuote`）。**步骤 7 的指数快照最先发，当作行情源探针**，见下方「数据源故障」 | 1-4 |

调用形态铁律（本序列全程通用）：

> **调用形态（2026-10-01 实测，取代 2026-07-20 的"数组被拒、只能 query 串"铁律）**：`metrics` / `signal` 的入参分工是 **`keywords` 数组放标的、`query` 放意图词、`categories` 指定类别**。纯美股代码写进 query 串目前仍能被解析，但指数会多解析出一个重复项（`"^GSPC ^IXIC ^DJI ^VIX"` → 多一个 `VIX`，返回 `status:"partial"`），`*USD` 商品代码写进 query 串会**整批返空且不报错**——所以标的一律走数组。每次调用最多 5 个 keywords，超出或解析不了的项写在 `meta.warnings`（`keyword_count_over_max` / `kw_not_canonical`），**调用后读一遍 `meta.warnings`**，有缺口分批补；warnings 不够，还要拿请求代码与返回行 `symbol` 做差集——与期货根同名的代码会被静默改写（2026-10-08 实测 `NG`→`NG=F`、`CORN`→`CORN`+`ZC=F` 多占一个名额，原标的都不返回，`filters_applied.keywords` 里能看到改写后的值）。**快照调用一律加 `categories=["market"]`**：只写 `query="行情"` 时是否附带基本面块不稳定（2026-10-05 实测同样写法，SPY / QQQ / DIA / NVDA / MU 一批多返回 `profile_block` + `shares_float`、体积翻倍，NKE 一批没有）。单批并行 ≤4 路（SSE 红线）。客户端不接受数组入参（报 `-32602`）时，美股代码与指数可退回 query 串，商品代码没有可用的 query 串写法。另：Followin session 每 5-8 次调用可能短挂，重试 1 次即恢复，还不行让运营 `/mcp restart followin`。

> **数据源故障（2026-10-05 实测）**：行情、K 线、三张涨跌榜、内部人（以及已停用的市场级财报日历）都走同一个上游，它挂掉时返回 `status:"degraded"` + `warnings[].severity=="source_dead"`（如 `fmp_batch_quote_error` / `fmp_quote_error`，HTTP 403），**而且照样扣额度**。所以：① 步骤 7 的指数快照最先发，报 source_dead 就重试 1 次；仍失败则跳过步骤 3 和所有补快照批次（同属一个上游，发了也是白扣），步骤 5 补漏的核实调用也不发（新闻里挑出的名字标「待核實」或不写）。② 凡 source_dead 的段落按「缺数据」处理，**不是「没有」**——大盤一眼、漲跌榜写「行情數據暫缺」，内部人这一行直接省略，**不能写「未見大額買賣」**。③ 快照类 source_dead 时整篇不对外发，只给运营出内部降级稿，并提醒报给 dev。趋势榜、新闻搜索、喊单、经济日历、关注池财报日不受影响，可以照跑。

每步 query 主形态调用示例：

```
1. news(query="", asset_type="tradfi", time_range="24h")   # 周一改 "72h"，节后第一天 "96h"
   # 趋势模式，quota=0；通常只有 3-5 条，只用来发现题目

2. news(query="<核心名词1> <核心名词2>", time_range="24h")   # 窗口同步骤 1
   # 搜索模式；2026-10-01 实测传 asset_type="tradfi" 正常返回（旧"加了返 0 篇"已不复现）。
   # 要权威报道可加 sources=["media"], sort_by="relevance"。≤3 次，按需

3. metrics(query="most active stocks", asset_type="tradfi", limit=30, verbosity="concise")
   # 异动榜；不传 limit 只返 10 行。返回行不带 marketCap / exchange，按第 4 节预筛后各榜合并去重、按 price 从高到低取前 15，
   # metrics(keywords=[≤5 个], query="行情", categories=["market"], asset_type="tradfi") 补快照取 marketCap（≤3 批），再套过滤

4. signal(categories=["kol_call"], query="consensus", asset_type="tradfi", time_range="24h")
   # 喊单聚合（总帖数 / 多空比 / top_calls），1 额度
   signal(categories=["insider_trading"], asset_type="tradfi", sort_by="amount", limit=50)
   # 内部人全市场最新申报，1 额度；按金额降序（N-137）；不带 time_range，客户端按 filingDate 过滤

5. 对关注池逐批（≤5 只）：metrics(keywords=["<T1>",…,"<T5>"], query="next earnings date", asset_type="tradfi")
   # 取 next_earnings_estimate.date = 今日的；顺带返回的 earnings_calendar 块不用（市场级日历已停用）
   news(query="earnings preview what to expect report before the bell", sources=["media"], time_range="24h", limit=30, sort_by="relevance", verbosity="concise")
   # 关注池外补漏，0 额度；不传 asset_type（N-145）；窗口同步骤 1；写"预告"不写"today"，带 relevance；只挑原文写明美东今日发布的公司
   metrics(keywords=[≤5], query="行情 next earnings date", categories=["market","fundamentals"], asset_type="tradfi")
   # 有候选才发，1 额度：一次拿快照（exchange / marketCap）+ next_earnings_estimate / report_date 核日期；不能当"当日全貌"

6. metrics(query="economic calendar", country="US", sort_by="hot", date_from="<今日>", date_to="<今日>")
   # 宏观日历；country="US" 与 sort_by="hot" 必传；query 只写 economic calendar，不写事件名、不写"本周"（N-129 / 红线 10）；date 字段是 UTC

7. metrics(keywords=["^GSPC","^IXIC","^DJI","^VIX"], query="行情", categories=["market"], asset_type="tradfi")
   # 大盘四指数一次批量；快照没有涨跌幅字段，自算 change ÷ previousClose × 100；逐行读 as_of（^VIX 可能是下一日凌晨的值）
   metrics(keywords=["SPY","QQQ","DIA"], query="行情", categories=["market"], asset_type="tradfi")
   # 仅盘前跑时需要：指数没有 extendedHoursQuote，盤前價用这三只 ETF 自算，口径见第 4 节
```

## 3. 产出模板

六段骨架（≤1000 字；标题下先放「一句話先懂」，≤40 字，S-3 镜像）：

1. **大盤一眼**：三大指數昨收漲跌（取步骤 7 的指数快照，自算 change÷previousClose）+ 一句话定调；^VIX 逐行读 `as_of`，晚于上一常规收盘的标「截至 X/X 美東 HH:MM」，不当成昨收；美东 04:00-09:30 跑则加一行 SPY / QQQ / DIA 盤前價（标「盤前 美東 HH:MM」），美东 16:00-20:00 跑（台北早晨通常落在这段）则标「盤後 美東 HH:MM」，口径见第 4 节
2. **昨夜 1-3 件事**（不足 3 件不硬凑，铁律 3）：每件 = 发生了什么 + 受影响标的怎么走 + "为什么和你有关"白话一句
3. **推特風向**：近一日喊单最热标的 + 多空比一行（周一跑写「近一日（多為週末討論）」）；内部人近 3 个交易日申报的大额真买入（P-Purchase，「大额」口径见第 4 节）则加一行，写明「X 日交易、Y 日申報」；**只写 P-Purchase，大额 S-Sale 不进晨報**（高管卖股多为例行减持，单拿出来写容易被读成利空）
4. **漲跌榜看點**：过滤后各取 2-3 只，涨跌原因一句
5. **今日看什麼**：当日财报（谁、市场在赌什么）+ 当日宏观数据（几点、为什么重要）
6. 今日名詞卡 + 免责声明

长度按 S-4 镜像：晨报≤1000 字；開盤前瞻/刷新 200-400 字（前瞻约 300 字，仅含六段中的第 1、第 5 段内容，对应只跑的步骤 1、6、7，财报沿用当日晨報）。

第 7 段互动钩子（S-3 镜像，可选）：只出现在 c1/c5，**一天最多一次**——晨报/開盤前瞻/刷新三种产出算同一天的份额，当天已用过一次后其余产出不再加；问题必须无立场、不诱导买卖方向。

以下是 T-2 样例（2026-07-22 已核可；2026-10-05 按实跑修订三处：补「一句話先懂」、大盤一眼改用指数、"昨夜三件事"改为 1-3 件。实际产出照此排版：纯文字＋emoji，不套 markdown 加粗/标题/表格，层级靠 emoji ＋ 空行 ＋「｜」——S-9 镜像）：

```
📌 每日早報｜7/22（二）

一句話先懂：（≤40 字，今天最重要的一件事）

大盤一眼：三大指數昨收 →（一句話定調；有延長時段報價則加 SPY / QQQ / DIA，標注「盤前／盤後 美東 HH:MM」）

昨夜大事（1-3 件，不足不硬湊；沒有就寫「今日平靜」）：
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

- **异动榜过滤**：分两步。① **预筛（补市值前，客户端）**：剔基金类——name 命中 `\bETFs?\b|\bETNs?\b|ProShares|Direxion|Leverage Shares|GraniteShares|Tradr|Defiance|T-Rex|MicroSectors|iPath|SPDR|iShares|Vanguard|Invesco (QQQ|DB)|Grayscale|Teucrium|\b(Bitcoin|Ether(eum)?|Crypto|Gold|Silver|Platinum|Palladium|Oil|Gas|Gasoline|Agriculture|Commodity|Index) (Funds?|Trust|Shares)\b`（不区分大小写）的一律剔除（2026-10-08 定稿：拿当日三张榜 90 行真实名称 + 补测的商品 / 加密基金跑过，0 漏网、0 误杀。中段发行商名接住名字里不带 ETF 的杠杆单股基金，如「Direxion Daily PLTR Bull 2X Shares」「ProShares - Ultra PLTR」「Invesco QQQ Trust, Series 1」；末段「品种词 + Fund/Trust/Shares」紧挨着才命中，接住旧版漏掉的 Fidelity Wise Origin Bitcoin Fund（FBTC）、Invesco DB Agriculture Fund（DBA）、United States Brent Oil Fund / 12 Month Oil Fund（BNO / USL）、Sprott Physical Silver Trust（PSLV），同时放过 North European Oil Royalty Trust 这类特许权信托（中间隔着 Royalty）。不要放宽成 `Invesco`，会误杀 Invesco Ltd 本身；`Teucrium` 未能实测——CORN 会被改写成玉米期货 `ZC=F`，取不到名称。已知代价：MV Oil Trust 这类名字直接叫「Oil Trust」的小型特许权信托会被误剔，它们市值都不到 $1B，本来也过不了市值闸）；剔 SPAC——代码 5 个字母且以 U / W / R 结尾、**并且**名称含 `Acquisition Corp` / `Units?` 的剔除（单位 / 权证 / 认股权，口径同 Base Skill 03；2026-10-08 跌幅榜第 1 名 CCAQU −39%、第 30 名 ALISU 都是 SPAC 单位，不剔会占掉补快照名额）（普通 ETF 也不算个股看点，所以不必再区分杠杆 / 反向；RWM 叫 ProShares - Short Russell2000，靠 ProShares 命中；QQQ 叫 Invesco QQQ Trust，名字里没有 ETF）；剔仙股——price <$5 的剔除（GRAB 这类低价大市值票靠关注池或新闻再捞回来）；剔疑似合股——`changesPercentage ≥ 200` 的直接剔（等价于前收 < 现价/3，榜单行自带 `change` 就能判，不必等补快照，免得假涨幅占掉补快照名额）。**旧版的杠杆 / 反向词 `UltraPro|Ultra|Leveraged|\dX|Bull|Bear|Daily|Short|Inverse|Target` 不再单独当剔除条件**：单独命中会误杀 Target Corp（TGT）、Ultra Clean（UCTT）、Daily Journal 这类正常公司；也不要用 `Fund|Trust` 判基金，会误杀 Northern Trust 和名字带 Trust 的 REIT。预筛后各张榜合并去重，先只留 `|changesPercentage| ≥ 3%` 的行（活跃榜里涨跌 1% 的高价股不该占名额：2026-10-08 回放时 NVDA −1.1%、BAC −1.1% 进了前 15，把 CIFR −6.4% 挤掉），再按 `price` 从高到低取前 15 只补快照（名额分配见第 2 节步骤 3；2026-10-08 按此回放当日三张榜，15 个名额依次是 ARGX / NVDA / PLTR / SPCX / MANE / HAE / INTC / BAC / SMCI / IREN / PCRX / BUUU / WOLF / HELE / APLD，ARGX 排第一；同日美东 10:43 按现行规则复跑，三张榜换了一批行：正则剔掉 17 行基金类〔含新出现的 Daily Target 2X Long RIOT ETF、Breakwave Tanker Shipping ETF〕、0 漏网 0 误杀，SPAC 单位 CCAQU 被剔，15 个名额是 ARGX / PLTR / GKOS / MANE / HAE / RPGL / IREN / PCRX / URGN / CMG / BUUU / LQDA / HELE / CIFR / RZAI，补市值后 11 只过 $1B，4 个名额落在 $10 亿以下的票上；排第 16 的 SECZ〔市值约 $18 亿、+9.4%〕因名额用完没补到）。② **补市值后**：marketCap ≥$1B 才留；快照里 `dayLow < price/3`（或预筛漏掉的 `previousClose < price/3`）的视为**疑似合股 / 拆股，直接剔除**（2026-10-05 实测涨幅榜前四 SCNX +2141%、VIVK +1501%、GUTS +984%、CMND +699% 全是合股前后价格拼出来的假涨幅，SCNX 快照 `previousClose` 0.1771、`dayLow` 0.1358、`price` 3.97；现价都在 $3 以上，仙股闸挡不住——N-111 说的"已恢复正常"对这类行不成立；2026-10-08 三张榜最高涨幅 +50%，没有合股样本，补快照的 13 只里 `dayLow < price/3` 也无一误触）。三张榜默认不含 price <$1 的行（`include_penny_stocks` 默认 false，2026-10-08 实测榜内最低价 $1.05）。三张榜（most active / gainers / losers）的行都**不带 marketCap 和 exchange**（2026-10-01 实测只有 symbol / name / price / change / changesPercentage），须另发批量快照补 marketCap。三张榜都要传 `limit=30`（不传只返 10 行，2026-10-05 实测）；每张榜最多约 30 行（`limit=50` 也只回 31 行，N-138），跌得不够极端的大盘股不在榜上——只能写"榜内可见"，不能写"今日最大跌幅"。
- **代币化+加密噪音白名单剔除**：趋势榜内容含代币化股票与加密混排（实测 SKHYx、LAB 代币），按"美股正股白名单"原则剔除。（来源：c1 本次实测命中 SKHYx、LAB）
- **news 的 asset_type**：只在趋势模式（空 query）传 `asset_type="tradfi"`；**搜索模式不传**——2026-10-05 实测传了召回下降（PTC 并购 8→2 条、路透 / 彭博 / WSJ 全丢；MU 20→17），宽主题词照样混进加密文章（N-145）。两种模式都 0 额度。需要权威报道时加 `sources=["media"], sort_by="relevance"`。
- **趋势榜只用来发现题目**（2026-10-05 实测）：趋势榜通常只有 3-5 条（24h 返 3 条；72h 加 `limit=20` 也只返 4 条），三件事的素材主要靠步骤 2 补搜。趋势条目自带 AI 写的「操盤指南」段落，**不得引用**（S-6）；里面的数字（如"12 月加息概率 67.3%""盤前漲 36%"）一律回快照或日历核实，核实不了就不写或标「消息尚待確認」。
- **内部人按申报日筛，只认 S-Sale/P-Purchase**：步骤 4 的内部人行客户端过滤 `filingDate` 落在**含上一个美股交易日在内的最近 3 个交易日**（例：台北 10-09 早晨跑＝美东 10-08 晚上，上一个交易日是 10-08 → 10-06 / 10-07 / 10-08 申报的都算；**日期按美东算，不按台北日期**——Form 4 美东 22:00 前提交都记当天，台北早晨跑时能看到美东当天的申报。不在台北早晨跑时（如美东盘中），美东当天已出的申报同样算，2026-10-08 美东 10:43 复跑时返回的 7 行 Form 4 全部是 10-08 申报，按台北日期套窗口会一行不剩），`transactionDate` 可以更早——迟报的大额买入也算（2026-10-08 实测 COE 的 CEO 9-17~9-25 分 4 笔买入约 3,230 万美元、10-08 才申报，按交易日筛会被漏掉）；贴文写「X 日交易、Y 日申報」（多笔写区间，如「9/17-9/25 交易、10/8 申報」），让读者知道这不是昨天的事。且只认 `formType=="4"` 的 S-Sale / P-Purchase（F-InKind / M-Exempt 是缴税代扣 / 豁免行使，剔除；2026-10-01 实测榜首常是 `formType:"3"`、`transactionType` 为空的新任董事初始申报，同样剔除）。**不要给内部人调用带 time_range**：实测带 `7d` 返回 `status:"partial"`，与喊单合并调用再带 `24h` 时内部人整类静默消失。**覆盖只有最近约 1 个申报日、最多 50 条**，同一公司多笔申报会挤占名额（N-137）——`status:"ok"` 且没筛出东西时写"最近申報中未見大額買賣"，不写"昨日无内部人交易"；返回 `source_dead` 时这一行直接省略（见第 2 节「数据源故障」）。**「大额」＝ securitiesTransacted × price ≥ $1M（同一申报人同一份申报——`url` 相同——的多行合并计算），且该公司市值 ≥ $1B**（2026-10-05 实测唯一的 P-Purchase 是 VCIG $1.62 × 193,349 股 ≈ 31 万美元，属仙股，不够格）。`price` 为 0 的行算不出金额，不进本段（2026-10-08 实测 TXTM 5,565 万股 P-Purchase 标价 0）。过金额闸的行再查市值：并进步骤 7 的重点股快照批次，不单独发。混在里面的国会议员交易带 `_chamber` 字段（senate / house），交易日期滞后 2~4 周，`sort_by="amount"` 时按金额区间排进来，50 条里约占一半到九成（2026-10-05 约一半；2026-10-08 美东 10:10 跑占 46 条，Form 4 只剩 4 条——但 ≥$1M 的 Form 4 行金额高于议员区间，会排在最前，不影响本段）——**带 `_chamber` 的行不进本段**。2026-10-08 实测：申报窗口内的 P-Purchase 有 TSM 高管 17 笔（每笔几十股、合计不到 2 万美元）、UXIN（仙股）与 COE（合并约 3,230 万美元，金额过闸；美东 10:43 复跑补快照，市值仅约 6,300 万美元，过不了市值闸）——当天这一行按规则写「最近申報中未見大額買賣」。
- **市场级财报日历已停用（2026-10-08 拍板）**：按代码字母序排，`limit=50` 翻 4 页（5 次调用含核对）只排到 N 开头，O-Z 开头的公司永远看不到，当日实测只核出 1 家（NRIX）（N-148）。关注池外的当日财报改由步骤 5 的 1 次新闻搜索补漏：2026-10-08 美东 10:10 实测 `query="earnings report today"` 返回 29 条、0 额度，抓到 PEP（盘前发）、HELE、LEVI、APLD（后两家 10-07 盘后发）——PEP 在日历里排在第 4 页之后，根本翻不到；但这几家**在取数时都已经发完**，换到台北早晨（美东前一晚）跑，这个 query 拿到的只会是前一天的结果，所以 query 已改成预告式（见第 2 节步骤 5）。同批混有下周银行股的财报前瞻（GS / WFC / JPM / TFC）和海外公司（TCS、7&i、Tesco），所以只认原文写明美东今日发布的。2026-10-08 美东 10:43 复跑对照外部财报日历：当天美股盘前发的有 PEP、HELE、TLRY、ANGO、BYRN、NovaGold（NG）等，市值 ≥$1B 的只有 PEP（HELE $6.5 亿、TLRY $4.0 亿、ANGO $4.6 亿），补漏腿抓到了 PEP 和 HELE；NovaGold 核实时 `NG` 被静默改写成天然气期货 `NG=F`、整行不返回（N-159），这种核实不了的不写进贴文。补漏只是补漏，主腿仍是关注池 + `next_earnings_estimate` 核实。
  🔒 **对外发布铁律**：贴文写「今天我们盯的这几家发财报」，**严禁写「今日财报一览」**——关注池 + 新闻补漏都覆盖不全，把它当"当天全貌"的任何变体都是错的。
- **经济日历（N-128~N-130，2026-10-03 实测）**：一律 `query="economic calendar"` + `country="US"` + `sort_by="hot"`。不带 `sort_by` 时按时间排，一天几十行国债拍卖、EIA 周报、官员讲话就把 50 行占满；query 写事件名会被拆成股票代码（`Non Farm Payrolls` → FARM，返回 0 行）；传 `keywords` 被静默忽略。事件名写死（N-130）：利率决议 `Fed Interest Rate Decision`、核心 CPI `Core Inflation Rate MoM`、核心 PCE `Core PCE Price Index MoM`、非农 `Non Farm Payrolls`、失业率 `Unemployment Rate`；`CPI (…)` / `Inflation Rate (…)` 是指数点位行，别当成 CPI 读数。`date` 是 UTC。
- **指数走 keywords 数组，别写进 query 串（N-18，2026-10-01 复测）**：query 串 `"^GSPC ^IXIC ^DJI ^VIX"` 仍被解析成 5 个 keywords（多出一个裸 `VIX`）、^VIX 出现两条相同的行、`status:"partial"`；`keywords=["^GSPC","^IXIC","^DJI","^VIX"]` 数组写法返回干净的 4 行。若客户端只能发 query 串，写贴文前按 `symbol` 去重。
- **快照时间点与盤前價（2026-10-05 实测）**：① 同一次指数快照里各行时间点可能不同——周一盘前取数，^GSPC / ^IXIC / ^DJI 的 `as_of` 是上周五收盘，^VIX 的 `as_of` 却是周一 07:04 美东，算出来的 +6.1% 是周一凌晨的变动、不是昨收。**每行先读 `as_of`**，晚于上一常规收盘的单独标「截至 X/X 美東 HH:MM」。② `extendedHoursQuote` 只有 `bidPrice` / `askPrice` / `timestamp` / `volume`，**没有成交价、没有涨跌**；三大指数都没有这个字段，SPY / QQQ / DIA 和多数大型股有，部分中小型股（MXL / XRPN / IART）没有；**美东 09:30-16:00 常规时段整个字段消失**（2026-10-08 美东 10:10 实测 SPY / QQQ / DIA / NVDA / PLTR 都没有，query 写明 `extended hours quote` 也一样），所以刷新模式写不出盤前價。**盤前／盤後價 =(bidPrice+askPrice)/2，对快照 `price`（上一常规收盘）自算涨跌**；按 `timestamp` 落在美东 04:00-09:30 标「盤前」、16:00-20:00 标「盤後」（台北早晨 08:00 ≈ 美东前一日 20:00，此时是盤後报价，标盤前就错了），写「美東 HH:MM」（取 `timestamp`，毫秒）；买卖价差 >0.5% 的不引用；没有该字段的写不出盤前價，不要拿新闻里的盘前涨幅顶替（铁律 2）。
- **关注池财报日要再确认一次**：`next_earnings_estimate.date` 偶有明显不合理的值（2026-10-05 实测 TSLA 返回 2027-02-03，像是跳过了一季），日期落在未来 7 天内的，用新闻再核一次再写进「今日看什麼」；`next_earnings_estimate.date` 距上次 `report_date` 超过 120 天的（像跳了一季），同样用新闻核一次，真实的近期财报可能被它静默漏掉。
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
