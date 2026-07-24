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
| 刷新 | 当日已出晨报后，盘中任意时刻 | 步骤 1、3、4 增量（`time_range` 缩到 4h） | 200-400 字增量补丁贴 |

- **晨報**＝全流程 7 步：美股昨夜已收盘，出完整「收盘复盘 + 今日看点」六段结构（见第 3 节）。
- **開盤前瞻**＝只跑步骤 1、7：美股尚未开盘，精简输出三点——今晚开盘關注 / 盘前异动快照（引用快照自带的 `extendedHoursQuote` 字段，标注「盤前」）/ 今晚数据几点，约 300 字 2-3 点。与晨报同一 skill、共用触发词组（"早報"/"開盤前瞻"，含简体形式），路由到同一份调用序列，只是只跑其中两步。
- **刷新**＝步骤 1、3、4 增量：`time_range` 收窄到 4h，只出「新增」内容，已在当日早报出现过的条目不重复，产出 200-400 字增量补丁贴（"午间更新：新增 XX 两件事"）。**无当日晨报 baseline 时拒绝刷新，先提示运营"请先跑晨报"**。小时级增量一律只用当次调用返回的即时快照做判断，不要另外去拉小时级历史——`metrics()` 的 `time_range < 1d` 有已知 bug，会返回一个月前的旧数据而非当日窗口（镜像 N-10：metrics time_range <1d 返一个月前旧数据 bug；小时级用 interval 参数或只用实时快照）。

## 2. 调用序列（实测额度 ≈7/天）

调用序列：

| 步骤 | 调用 | 额度 |
|---|---|---|
| 1 | `news(空 query, asset_type="tradfi", time_range="24h")` 热点趋势榜 | 0（实测） |
| 2 | （按需）对头条事件 `news(query="<核心名词×2>", time_range="24h")` 补细节，≤3 次 | 0（实测） |
| 3 | `metrics(query="most active stocks", asset_type="tradfi")` 异动榜——**弃用 biggest gainers/losers**（trend-scout v1.8.0 实测：上游缺 marketCap 且全是仙股）；**2026-07-22 回归实测更正**：该 board 行本身也不带 marketCap 字段（10/10 行仅有 price/change/name/symbol），需对候选 ticker 另发一次批量 `metrics(query="<TICKER1> <TICKER2> ...", asset_type="tradfi")` 补 snapshot 取 marketCap 后再套用 ≥$1B 过滤（≤10 个一批；query 串批量会静默丢部分 ticker，需核对 `meta.filters_applied.keywords` 是否齐全，缺的单独补查） | 2 |
| 4 | `signal(query="consensus", asset_type="tradfi", time_range="24h")` 无 categories 一次拿全：喊单榜+多空比+内部人大额动向 | 1 |
| 5 | `metrics(query="earnings calendar", asset_type="tradfi", date_from=今日, date_to=明日, limit=100)` 当日财报名单，按 c2 同款规则过滤 + 重点标的日期二次核实（见 c2）；**limit 必须调大并做交叉验证，见下方 N-17** | 1 |
| 6 | `metrics(query="economic calendar upcoming releases")` 当日宏观数据发布（2026-07-22 回归实测确认可用：query 路径能路由，返回调用当下自然日的日历，满足"当日"需求；date_from/date_to 不影响窗口宽度，传或不传都只回传锚定日当天，见 c2 关于多日窗口限制的记载） | 1 |
| 7 | 大盘指数 ^GSPC ^IXIC ^DJI ^VIX（trend-scout 实测可用）+ 过滤后重点股快照，按批量降级梯执行（§2 调用形态铁律） | 1-4 |

调用形态铁律（本序列全程通用）：

> **调用形态铁律（2026-07-20 起生效，trend-scout v1.11.1 实测 + 2026-07-22 复现）**：`keywords/categories/sources` 等数组参数在当前环境会被序列化成字符串遭 schema 拒（连环 -32602）。所有调用规范以 **query 自然语言/空格拼串为主写法**（服务端自解析成 keywords，meta 可验证），数组形式仅作"标准客户端若可传数组"的备选注记。批量降级梯：① keywords 数组批量（≤10，B-31）→ ② query 串批量（crypto 实测可行，tradfi 多 ticker 可能被路由到 fundamentals，实现时验证）→ ③ 单 ticker 并行、每批 ≤4 路（SSE 红线）。另：Followin session 每 5-8 次调用可能短挂，重试 1 次即恢复，还不行让运营 `/mcp restart followin`。

每步 query 主形态调用示例：

```
1. news(query="", asset_type="tradfi", time_range="24h")
   # 趋势模式：空 query 传 asset_type 是可用例外（红线 1 + N-1），quota=0

2. news(query="<核心名词1> <核心名词2>", time_range="24h")
   # 搜索模式：不要传 asset_type（红线 1，加了会返 0 篇且不报错），≤3 次，按需

3. metrics(query="most active stocks", asset_type="tradfi")
   # 异动榜；返回行不带 marketCap（2026-07-22 回归实测更正原 N-9 记载），先用候选 ticker 批量 metrics(query="<TICKER…>", asset_type="tradfi") 补一次 snapshot 取 marketCap，再套三重过滤见第 4 节

4. signal(query="consensus", asset_type="tradfi", time_range="24h")
   # 不带 categories 一次拿全 4 类（喊单/多空比/内部人/实盘），仍计 1 额度

5. metrics(query="earnings calendar", asset_type="tradfi", date_from="<今日>", date_to="<明日>")

6. metrics(query="economic calendar upcoming releases")
   # 宏观日历，非个股查询不传 asset_type；query 严禁带"本周"（红线 10，会返历史而非前瞻）；2026-07-22 实测确认：不带 date_from/date_to 时默认即返回当天日历（当日已发布+待发布混排），满足 c1"当日"需求即可，date_from/date_to 传了也不会扩大窗口（见 c2 关于多日窗口限制的记载）

7. metrics(query="^GSPC ^IXIC ^DJI ^VIX", asset_type="tradfi")
   # 大盘四指数一次批量；过滤后重点股快照另按批量降级梯逐批补（单批 ≤4 路，SSE 红线）
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

- **异动榜三重过滤**：异动榜客户端过滤：marketCap ≥$1B + 剔杠杆 ETF（name 含 2X/3X/Long/Short/Bull/Bear/Daily/Leveraged）+ 仙股 <$5（红线 9 与 trend-scout 双重依据）。（N-9：gainers/losers 榜上游缺 marketCap 且全是仙股，禁用；改用 `most active stocks`——但 2026-07-22 回归实测发现该 board 本身也不带 marketCap（原 N-9"回传行自带 marketCap"记载有误，此处更正），须另发一次批量 snapshot 补 marketCap 才能套用 ≥$1B 过滤，红线 9 的过滤清单继续沿用）
- **代币化+加密噪音白名单剔除**：趋势榜内容含代币化股票与加密混排（实测 SKHYx、LAB 代币），按"美股正股白名单"原则剔除。（来源：c1 本次实测命中 SKHYx、LAB）
- **news 搜索不传 asset_type、趋势可传**：news 搜索模式不传 asset_type（红线 1）；趋势模式（空 query）可传，见新 caveat N-1。（N-1：news 趋势模式［空 query］传 asset_type="tradfi" 可用且 0 额度；"news 不传 asset_type" 红线仅适用搜索模式；实体搜索［query="NVDA Nvidia"］实测也 0 额度）
- **内部人 transactionDate=昨日，只认 S-Sale/P-Purchase**：步骤 4 的内部人行按 N-6 客户端过滤 transactionDate=昨日，且只认 S-Sale/P-Purchase（F-InKind/M-Exempt 剔除）。（N-6：insider/congress 行无视 time_range，7d 窗口可能返回 2020 年记录；客户端按 transactionDate 过滤为强制要求，Dev 待修。F-InKind/M-Exempt 是缴税代扣/豁免行使，非主动交易，对外只认 S-Sale 当卖出、P-Purchase 当买入）
- **财报日历会漏掉当天最重要的美股（N-17，2026-07-23 实测）**：当日 30 条返回被印度/欧洲/OTC 小票占满，而同一时刻 `fundamentals.next_earnings_estimate` 明确显示 AAL 当天发财报，该股却不在日历返回里。补救三步：① `limit` 至少 100；② 客户端只留无交易所后缀的美股 symbol 并剔除优先股（含 `-P` 字样，如 DLR-PJ）；③ **对当日涨跌榜/热点里出现的标的，用其 `next_earnings_estimate.date` 交叉验证是否等于今天**——日历漏了但个股字段有，这是唯一能补回大票的路径。宁可在贴文里承认"今日财报名单可能不全"，也不能把小票名单当成当天全貌。
- **指数快照会出现重复行（N-18，2026-07-23 实测）**：query 串 `"^GSPC ^IXIC ^DJI ^VIX"` 被解析成 5 个 keywords（多出一个裸 `VIX`），返回里 ^VIX 出现两条完全相同的行。写贴文前必须按 `symbol` 去重，否则"大盤一眼"会把同一个指数写两次。
- **原油用 BZUSD/USO**：原油如需引用：用 BZUSD/USO——CLUSD 被 trend-scout 实测 402（与红线 6 冲突，实现时复核后回写 SSOT）。（N-11：指数类 ^GSPC ^IXIC ^DJI ^VIX 可用；^DXY/CLUSD/NGUSD 为 402 Special Endpoint 禁调，与红线 6 的 CLUSD 记载冲突，实现时复核后统一 SSOT——复核完成前一律避开 CLUSD）
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
