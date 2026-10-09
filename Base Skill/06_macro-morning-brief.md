---
name: Macro Morning Brief
description: 每日财经早报（宏观/美股维度）— 宏观+新闻+异动三源聚合晨间简报。触发词：宏观日报、宏观早报、美股早报、美股日报、morning brief、morning briefing、今日市场。纯"日报"/"加密日报"不在本 Skill 范围内（本仓库无加密日报 Skill）。
trigger: 宏观日报、宏观早报、美股早报、美股日报、morning brief、morning briefing、今日市场、每日财经简报、macro morning brief、US stock daily、macro daily、financial morning brief
not_trigger: 策略信号、KOL、喊单、热点、加密日报、加密早报、日报、BTC宏观、黄金宏观、财报、earnings、strategy、KOL calls、trending、crypto daily、crypto brief、BTC macro、gold macro、earnings report、背离扫描/divergence（→03）
mcp: mcp__followin__metrics, mcp__followin__news
args: watchlist
---

# /morning-brief

每日财经早报 — 宏观、新闻、异动三源聚合（Followin MCP 版）

## 意图路由

| 用户说的 | 走哪个 |
|---|---|
| 宏观日报 / 宏观早报 / 美股日报 / 美股早报 / morning brief / 今日市场 | ✅ 本 Skill |
| 日报 / 加密日报 / 加密早报 | ❌ 不在本 Skill 范围——如实告知，并建议改问宏观/美股早报，或直接用 `news()` 趋势模式（空 query + `asset_type="crypto"`）|

## 参数

- `watchlist`（可选）：空格或逗号分隔的 ticker。**没传就跳过 Watchlist 板块**，不要自己猜一份名单。

> 🔗 **通用调用红线 + 已知问题登记**：`~/.claude/references/followin-mcp-caveats.md`（仓库内 `references/`）。本文的调用写法于 **2026-10-03 实跑验证**，2026-10-08 美东盘中复跑；与登记表冲突时，以日期更新的一方为准。

## 调用约定（2026-10-03 实测）

`metrics` 的入参分工是：**`keywords` 数组放标的 / series_id，`query` 放意图词**。

- **不要把标的塞进 query 串**：query 串解析会静默丢掉 `DXUSD` / `CLUSD` / `BZUSD` 这类 `*USD` 商品代码（不报错、不返数据），还会让 `^VIX` 返回重复行。数组写法没有这些问题。
- **每次调用最多 5 个 keywords**。超出或解析不了的项会写进 `meta.warnings`——每次调用后读一遍，并以"请求清单与返回 `symbol` 的差集"为准判断缺口（warning 偶有误报）。
- FRED 指标带 `categories=["macro"]`；美股行情带 `asset_type="tradfi"`。
- `news()` 搜索（query 非空）**不传 `asset_type`**：传 `"tradfi"` 召回大降、也挡不住加密噪音（N-145）。`sources=["media"]`、`sort_by="relevance"` 照传；news 调用不耗额度。
- **经济日历必须带 `country="US"` 和 `sort_by="hot"`**：不带 `sort_by` 时按时间排，50 行只覆盖一两天；带上后高重要度事件排在前面。日历的 `date` 是 **UTC**。带 `sort_by="hot"` 时 High 行全部排在 Medium 之前（2026-10-08 实测 30 行里前 22 行是 High），首页一出现 Medium 就说明 High 已取完。**但 Medium 会跨页**，而下面的筛选规则要留"有预期值的 Medium"，所以 `has_more:true` 时第 4 路继续用 `next_cursor` 翻，翻到出现第一行 `Low` 为止（2026-10-08 实测 7 天窗口：第 1 页 22 行 High + 8 行 Medium，第 2 页前 11 行 Medium、之后全是 Low；`Core PPI MoM`、费城联储制造业指数、9 月预算余额这几行带预期值的 Medium 都在第 2 页，不翻就漏）。第 4 路因此通常是 2 次调用。
- 如果客户端不接受数组入参（报 `-32602`）：FRED 指标退回 `query="<series_id>"` 单个直查；美股 ticker 退回 `query="<T1> <T2> 行情"`；`*USD` 商品代码没有可用的 query 串写法，标"数据不可用"。
- **运行时段决定报价标注**：先把运行时刻换算成美东时间，再定整篇的口径（2026-10-08 实测）：
  - 美东 20:00 至次日 09:30（夜间 / 盘前）：快照 `price` 是上一常规收盘，标"最近收盘"。**`CLUSD` / `BZUSD` / `DXUSD` 例外**：它们夜盘照常交易，快照是当刻价，`change` 是相对上一结算的夜盘变动，不是上一交易日的涨跌，"数据时点"标"夜盘 美东 HH:MM"（2026-10-09 美东 21:41 实测 WTI `as_of` 为当刻、日变化 −0.75%，而同日媒体写的是 10-08 白天"油价大涨"）。第 9 路选题第 4 条（原油）因此在美股收盘后到次日开盘前跳过，见第 9 路规则。
  - 09:30–16:00（盘中）：快照和三张榜都是盘中数据，标"盘中 美东 HH:MM"（取 `as_of`）；"日变化"是相对昨收的盘中变动，不是昨日涨跌，榜单一节标题加"（盘中）"。2026-10-08 美东 10:08 跑，指数、VIX、原油、榜单全是当刻数据。
  - 16:00–20:00（盘后）：`price` 是当日收盘，标"今日收盘"。
  - **不要依赖 `_quote_session`**：2026-10-08 实测所有快照行（含 NVDA / AAPL）都没有这个字段。一律逐行读 `as_of`——同一批里各行时间点可能不同（盘前跑时 `^VIX` 的 `as_of` 会落在当天凌晨，算出来的不是昨收涨跌，N-150；美元指数的 `as_of` 也常比同批晚报十几分钟），与同批不一致的行单独标"截至 美东 HH:MM"。
  - **盘前 / 盘后价**：快照带 `extendedHoursQuote` 时取 (bidPrice+askPrice)/2 对 `price` 自算，标"盘前 / 盘后 美东 HH:MM"（指数没有这个字段，N-150）；没有就不写，**不拿新闻里的盘前涨幅顶替**。

## 执行步骤

### Step 1: 数据拉取（每批 ≤4 路并行）

**额度**（news 不扣）：Batch 1 共 5 次（第 4 路翻页多扣 1 次，2026-10-09 用户确认接受）+ Batch 2 共 4 次 + 补市值 ≤4 次 + watchlist ⌈只数/5⌉ 次，合计约 13＋⌈watchlist/5⌉；有疑似收购候选时再加日线 1 次（每 5 只 1 次）。

> **数据源故障（2026-10-05 实测，N-156）**：行情快照、三张涨跌榜走同一个上游，挂掉时返回 `status:"degraded"` + `warnings[].severity=="source_dead"`（HTTP 403），**而且照样扣额度**。所以：① Batch 1 的第 3 路（三大指数）先单独发，当行情源探针；source_dead 就重试 1 次，仍失败则第 2 路、第 6–8 路和 Batch 4 全部跳过（发了也是白扣）。② 凡 source_dead 的段落按"缺数据"写，**不是"没有"**——大盘表对应格写"数据不可用（行情源故障）"，榜单一节和 Watchlist 一节写"行情数据暂缺"，**不能写"榜单内无大市值极端异动"或"无异动"**；数据缺口里注明，并提醒报给 dev。③ 经济日历、新闻不受影响，照跑；第 9 路选题规则里依赖行情的第 2–4 条跳过。

**Batch 1：宏观与大盘**
```
1. metrics(keywords=["DGS2","DGS10"], categories=["macro"], limit=5)                       # 利差用：两者同一天，FRED 比行情晚 1~2 个交易日
2. metrics(keywords=["^VIX","DXUSD","CLUSD","BZUSD","^TNX"], query="行情", asset_type="tradfi")   # VIX / 美元指数 / WTI / 布油 / 10 年期收益率（当日）
3. metrics(keywords=["^GSPC","^IXIC","^DJI"], query="行情", asset_type="tradfi")           # 三大指数
4. metrics(query="economic calendar", country="US", date_from="<今天>", date_to="<今天+7天>", sort_by="hot", limit=30)   # 未来 7 天
```
- **10 年期收益率的头条数字用 `^TNX`**（与 VIX、原油同一天）；FRED 的 `DGS10` 比行情晚 1~2 个交易日（2026-10-08 美东上午实测最新只到 10-06），只用来和 `DGS2` 算利差，并在表里注明日期。实测 10-02 `^TNX` 为 +4bp，而 FRED 最新一天（10-01）是 −5bp，方向相反——混用会选错新闻题。

**Batch 2：上一交易日数据 + 榜单**
```
5. metrics(query="economic calendar", country="US", date_from="<最近交易日>", date_to="<最近交易日>", limit=50)   # 上一交易日已发布数据的 actual / estimate
6. metrics(query="biggest gainers",    asset_type="tradfi", limit=30)
7. metrics(query="biggest losers",     asset_type="tradfi", limit=30)
8. metrics(query="most active stocks", asset_type="tradfi", limit=30)
```

**日历行怎么筛**（第 4、5 路）：保留全部 `impact=="High"`；`Medium` 只保留 `estimate` 非空的行；`Low` 一律不留（带预期值也不留，如批发库存、密歇根通胀预期分项）。实测官员讲话、CFTC 持仓、WASDE 都标为 Medium 且 `estimate` 为空，这条规则能把它们去掉，留下贸易差额、首次申领这类有预期值的数据；EIA 原油 / 汽油库存 2026-10-08 实测已带 `estimate`，会被保留（10-07 原油库存 −319 万桶，预期 +170 万桶，正好是当天油价题的佐证）——但只限已发布的行，未来日期的 EIA 库存、MBA 房贷利率行 `estimate` 是空的（2026-10-08 实测 10-14 / 10-15 各行），未来日历里看不到它们属正常。第 5 路不带 `sort_by`、单日一般一页取完；`has_more:true` 时用 `next_cursor` 翻页。
- **当天已公布的行**：第 4 路从今天算起，美东 08:30 之后跑时，当天已发布的数据（`actual` 非空）会出现在这一路——它们挪到"最近已发布数据"表，不留在未来日历里（2026-10-08 实测当日首次申领 197K 就在第 4 路）。
- **预期值存疑**：利率、申领人数、销量这类水平值，`estimate` 偏离 `previous` 超过 15% 的标"预期存疑"，不据它判超预期、也不拿它选新闻题（2026-10-08 实测 10-07 的 `MBA 30-Year Mortgage Rate` 预期 6%、实际 7.49%、前值 7.30%；10-15 的持续申领预期 2070、前值 1716K，且 `unit` 为空）。这条只对利率、申领人数、销量、库存总量这类平稳的水平值用；扩散指数（PMI、地区联储制造业指数、消费者信心）和预算余额本来就会大幅摆动或按月份换号，不套 15%（2026-10-08 实测费城联储预期 31 / 前值 37.8、9 月预算余额预期 +2,100 亿 / 前值 −1,670 亿，都是正常预期）。
- **CPI 的指数点位行不是 CPI 读数**（N-130 / N-161）：`CPI (…)`、`CPI s.a (…)`、`Inflation Rate (…)`（不带 MoM / YoY）是指数点位（`CPI (Sep)` 的 `unit` 还标成 "%"，预期 336.8），未来日历里省掉这几行；CPI 写 `Inflation Rate MoM / YoY` 和 `Core Inflation Rate MoM / YoY` 四行，判超预期也只看这四行。
- **同名同期重复行**合并成一行，两行数字不同就都写上并注明（2026-10-08 实测 `Retail Sales MoM (Sep)` 有两行：12:30 预期 0.2 / 前值 1.4，13:30 预期 0.1 / 前值 1.2），写成"0.2 / 0.1（数据源两行不一致）"。

**Batch 3：新闻**
```
9.  news(query="<按下方规则选>", sources=["media"], time_range="1d", limit=8, sort_by="relevance")
10. news(query="stock market",    sources=["media"], time_range="1d", limit=8, sort_by="relevance")
```
第 9 路的 query 按优先级取第一条满足的（都不满足就用 `"Federal Reserve"`）：
1. "最近已发布数据"里有 High 级数据，且 `actual` 偏离 `estimate` 超过 20%（或方向与预期相反；标"预期存疑"的行不算）→ 用事件主题词，如 `"nonfarm payrolls"` / `"CPI inflation"`
2. `^TNX` 日变化绝对值 ≥ 5bp → `"treasury yield"`
3. VIX > 25，或 VIX 日变化绝对值 > 10% → `"VIX volatility"`
4. 原油日变化绝对值 > 3% → `"oil crude"`。**美东 16:00 至次日 09:30（美股收盘后到次日开盘前）跑时跳过这一条**：这时拿到的原油日变化是夜盘值，不是上一交易日涨跌（见上方"运行时段"）
5. 未来 2 个交易日内有 High 级日历事件 → 事件主题词，**去掉地名 / 机构名**，只留指标本身（如 `Michigan Consumer Sentiment` 写 `"consumer sentiment"`）。2026-10-09 实测 `"Michigan consumer sentiment"` 返回的 8 条全是密歇根州选举、诉讼新闻，0 条相关；`"consumer sentiment"` 能带回 AAII 情绪调查、消费股、关税推高物价等相关稿

`news()` 的 query 写 2-3 个核心名词，纯英文；不写"影响 / 解读 / 分析"这类词。

**Batch 4：补市值 + watchlist**（见 Step 2）

### Step 2: 榜单过滤

三张榜（涨幅 / 跌幅 / 活跃）的行**只有** symbol / name / price / change / changesPercentage 五个字段，没有市值也没有交易所，每张最多约 30 行、以小盘股为主。**榜单覆盖有限：跌幅不够极端的大盘股不会上榜**（实测 10-02 STX −10.2%、市值 1,904 亿美元，三张榜都没有），所以这一节只能叫"榜单内可见的大市值异动"。

1. **先按名称剔基金类产品（含杠杆 / 反向）**：`name` 匹配 `(?i)\bETFs?\b|\bETNs?\b|ProShares|Direxion|Leverage Shares|GraniteShares|Tradr|Defiance|T-Rex|MicroSectors|iPath|SPDR|iShares|Vanguard|Invesco (QQQ|DB)|Grayscale|Teucrium|\b(Bitcoin|Ether(eum)?|Crypto|Gold|Silver|Platinum|Palladium|Oil|Gas|Gasoline|Agriculture|Commodity|Index) (Funds?|Trust|Shares)\b` 即剔（不区分大小写，与 c1 同一份名单）。后半段的发行商名和"商品 + Fund / Trust / Shares"用来接住名字里不带 ETF 的产品——TQQQ 叫 ProShares UltraPro QQQ，RWM 叫 ProShares - Short Russell2000，QQQ 叫 Invesco QQQ Trust。**旧版的 `Ultra|Leverag|\d+X|Bull|Bear|Daily|Short|Inverse|Target` 不再单独当剔除条件**：单独命中会误杀 Target Corp（TGT）、Ultra Clean（UCTT）、Daily Journal 这类正常公司；也不要放宽成 `Invesco`（误杀 Invesco Ltd 本身）或 `Fund|Trust`（误杀 Northern Trust 和名字带 Trust 的 REIT）。2026-10-08 实测三张榜里的 20 只基金类产品（PLTU / PLTA / PTIR / NRGU / CIFG / RIOX / SOXL / TQQQ / IBIT / BKLC 等）新名单全部剔中。
   - **同时剔疑似合股的假涨幅**：`changesPercentage ≥ 200` 的行直接剔（等价于前收 < 现价 / 3，榜单行就能判，免得假涨幅占掉补市值名额）。2026-10-05 c1 实测涨幅榜前四 SCNX +2141%、VIVK +1501%、GUTS +984%、CMND +699% 全是合股前后价格拼出来的，现价都在 $3 以上，价格闸挡不住。
   - **同时剔 SPAC 单位 / 权证 / 权利证**（口径同 c1 / 03，2026-10-09 用户定）：代码为 5 个字母且以 `U` / `W` / `R` 结尾，**并且**名称含 `Acquisition Corp` / `Merger Corp` / `Right` / `Unit` / `Warrant` 的剔掉。两个条件要同时满足：名称含 `Acquisition Corp` 但代码不符合的是 SPAC 普通股，留到第 4 步按 SPAC 标记。2026-10-08 实测 CCAQU（跌幅榜第 1，−40.7%，市值约 1.7 亿）、ALISU（Calisa Acquisition Corp Units，市值约 3,400 万）不剔会白占两个补市值名额。
   - **同时剔仙股**：`price < 5` 的行剔掉（低价大盘股如 GRAB 若因此漏掉，在数据缺口里写一句即可）。
2. **挑候选**（跟 c1，2026-10-09 用户定）：三张榜预筛后合并去重，**先只留 `|changesPercentage| ≥ 3` 的行**（活跃榜里涨跌 1% 的高价股不该占名额），**再按 `price` 从高到低取前 20 只**补市值；排第 21 名起的没补到，在数据缺口里写"榜单候选 N 只、按股价取前 20 补市值，未补：……"。2026-10-08 回放：预筛后 28 只，前 20 名是 ARGX / PLTR / GKOS / MANE / HAE / INTC / RPGL / IREN / PCRX / URGN / CMG / BUUU / CIFR / SECZ / RZAI / CD / VNCE / ANGO / COE / NOK，其中 14 只过 5 亿美元；排第 21 的 GFUZ（市值约 6.9 亿、+13.7%）因此落选，要写进数据缺口。
3. **补市值和交易所**，每批 5 个、最多 4 批，一轮并行发完：
   ```
   metrics(keywords=[<T1>…<T5>], query="行情", asset_type="tradfi")
   ```
   快照行带 `marketCap` 和 `exchange`。涨跌幅沿用榜单行的 `changesPercentage`（**快照的 `change` 是美元变动量，不是百分比**）。
4. **终筛**：先剔补快照后才看得出的合股 / 拆股——快照 `dayLow < price/3`（或第 1 步漏掉的 `previousClose < price/3`）的直接剔（SCNX 快照 `previousClose` 0.1771、`dayLow` 0.1358、`price` 3.97）。再留 `marketCap > 5 亿美元` 且 `exchange` 属于 NYSE / NASDAQ / AMEX 的行。`marketCap` 小于 100 万美元的是异常值（2026-10-08 实测 BBCI 返回 `marketCap: 8`），按缺失处理、写进数据缺口，不要当成小盘股悄悄剔掉。名称含 `Acquisition Corp` / `Merger Corp` 的 SPAC 普通股（借壳空壳公司）保留但在输出里标"SPAC"——它们的暴涨通常来自合并消息，不代表行业动向。
   - **疑似收购单列**（口径同 03，2026-10-09 用户定）：涨幅 > 20%、过了市值闸，且同时满足 ① 快照的 `(dayHigh − dayLow) ÷ price < 0.5%`（股价被钉在收购价下方；用补市值那次快照的字段，**不用下面日线的 `high` / `low`**——2026-10-09 美东收盘后实测 PCRX 快照 36.27~36.405 振幅 0.37%，同日日线 36.27~36.46 振幅 0.52%，换数据源会翻判）② 成交倍数 ≥ 10。成交倍数要近一个月日均成交量，对这类票补一次日线（每批 ≤5 个）：
     ```
     metrics(keywords=[<T1>…<T5>], query="历史走势", asset_type="tradfi", time_range="1m", limit=25)
     ```
     日均**去掉当天那一行**（盘中那一行是开盘至今的累计量，N-158）。收盘后跑：成交倍数 = 快照 `volume` ÷ 近一月日均；盘中跑按已开盘时长折算：成交倍数 = 快照 `volume` ÷（近一月日均 × 已开盘分钟数 ÷ 390），已开盘分钟数从美东 9:30 算到快照的 `as_of`。命中的**不进"涨幅居前"**，放进输出里的"🤝 疑似收购"一节，写"疑似收购要约，待核实"。2026-10-08 实测 PCRX +44%，美东 11:09 快照振幅 0.17%（36.27~36.33）、成交 1,715 万股；按 03 同日测得的近一月日均约 56 万股、已开盘 99 分钟折算约 120 倍，两条都过。
5. **watchlist**（如果传了）每批 ≤5 个取快照；涨跌幅自己算 `change ÷ previousClose × 100`。对涨跌超过 2% 的每只，补一次 `news(query="<公司英文名>", sources=["media"], time_range="1d", limit=3, sort_by="relevance")` 找原因——只在两路宏观新闻里找会把大涨大跌的票误标成"无新闻"（实测 TSLA +4.7% 的交付超预期、MU −2.1% 的财报后报道都只能这样找到；2026-10-08 PEP +2.1% 的三季报超预期也是）。这一路返回的多是前一天的稿子或荐股稿时，写"未见当日直接原因"，不要拿旧稿凑原因（2026-10-08 实测 MU −2.1%，3 条都是 10-07 的热门榜和看多文）。

### Step 3: 分析与聚合

1. **宏观环境**
   - 10Y−2Y 利差（正 = 正常，负 = 倒挂），注明是哪一天
   - VIX 水平：<15 低 / 15-25 正常 / 25-35 偏高 / >35 恐慌
   - 三大指数、原油、美元的日变化
2. **最近已发布数据回顾**：第 5 路按上面的日历规则筛过的行（High 级 + `estimate` 非空的 Medium），加上第 4 路里当天已公布的行，列实际 / 预期 / 前值并标日期。没有数值的 High 级事件（如 `FOMC Minutes`）写"已发布（无数值）"，不要因为 `actual` 为空就略掉（2026-10-07 当天唯一的 High 行就是它）
3. **新闻热点**
   - 两路 news 合并后按 `source_url` 去重；没有 `source_url` 的按标题去重。标题高度相似的也并成一条（返回里没有聚类 id 字段）
   - **媒体名从 `source_url` 的域名取**（`source_name` 字段一律是 `"media"`，不能用）；没有 URL 的来源标"未知"
   - 剔除离题文章（与美国市场无关的），以及标题含 "What You Should Know" / "Should You Buy" / "I'm Buying" 这类模板化个股稿和 `source_url` 含 `yseop_template` 的 Zacks 自动生成稿（`sources=["media"]` 也会返回 `source_quality:"research"` 的 Zacks / GuruFocus / 247wallst 稿，2026-10-08 实测；watchlist 找原因时不剔）。`time_range="1d"` 是从调用时刻往回滚 24 小时，盘中跑会带进前一交易日的盘面综述——标题或正文写明是前一交易日行情的稿子（2026-10-08 实测 "Stock Market Midday, Oct. 7"）不当今日热点、也不计入媒体情绪。剔完再归纳 3 个最热的话题，不要只从其中一路的结果里选
   - 逐篇判断情绪，标"Claude 推断"
4. **媒体情绪 vs 盘面**：情绪分布只是媒体口径，必须和当天指数涨跌、VIX 变化并列写出；两者方向相反时明说（实测 10-02 媒体负面 8/16 篇，而标普 +0.7%、VIX −6.6%）。

### Step 4: 输出报告

```
## 📊 财经早报 [日期]

### 大盘与宏观
| 指标 | 值 | 日变化 | 数据时点 |
|---|---|---|---|
| 标普 500 | X,XXX.XX | ±X.XX% | 最近收盘 / 盘中 美东 HH:MM / 今日收盘 |
| 纳斯达克 | XX,XXX.XX | ±X.XX% | |
| 道琼斯 | XX,XXX.XX | ±X.XX% | |
| 10Y 国债（^TNX）| X.XX% | ±Xbp | |
| 10Y−2Y 利差（FRED）| XXbp | 正常 / 倒挂 | YYYY-MM-DD |
| VIX | XX.X | ±X.X% | |
| WTI 原油 | $XX.XX | ±X.X% | |
| 布伦特原油 | $XX.XX | ±X.X% | |
| 美元指数 | XXX.X | ±X.X% | |

### 🔁 最近已发布数据（美国，时间 UTC）
| 日期 | 事件 | 实际 | 预期 | 前值 |
|---|---|---|---|---|
（上一交易日 + 当天已公布；筛完一行都没有才写"无重要数据发布"）

### 📅 未来 7 天经济日历（美国，时间 UTC）
| 日期 | 事件 | 预期 | 前值 | 重要性 |
|---|---|---|---|---|

### 🔥 今日热点 (Top 3)
1. [话题] — N 家媒体报道
   情绪（Claude 推断）: [正面 / 负面 / 中性]
   代表: "[标题]" — [媒体域名]
2. ...
3. ...

### 📈 Watchlist 异动
| Ticker | 价格 | 涨跌% | 相关新闻 |
|---|---|---|---|
（没传 watchlist 时整节省略）

### 🏆 榜单内可见的大市值异动（市值 > 5 亿美元，已剔除基金类产品、SPAC 单位与疑似收购；盘中跑注明"盘中"）
涨幅居前: ...
跌幅居前: ...
成交活跃且波动 > 3%: ...

> 三行合计不足 3 只时整节写"榜单内无大市值极端异动"；合计够 3 只但某一行为空，那一行写"无"。不要放宽门槛凑数。

### 🤝 疑似收购（不计入榜单看点；没有就省略）
| Ticker | 公司 | 市值 | 涨幅 | 日内振幅 | 成交倍数（盘中为折算值）|
|---|---|---|---|---|---|

### 媒体情绪
正面: XX 篇 | 中性: XX 篇 | 负面: XX 篇（Claude 推断）
对照盘面: 标普 ±X.XX%，VIX ±X.X% → [一致 / 背离]

### ⚠️ 值得关注
- [交叉分析洞察]
- [即将发布的重要数据提醒]

### 数据缺口
- 涨跌榜每张约 30 行、以小盘为主，跌幅不够极端的大盘股不在榜上
- 榜单候选 N 只（预筛并过 |涨跌| ≥ 3% 之后的只数）、按股价取前 20 补市值，未补：[代码]
- [其余没取到的指标及原因]
```

## 输出约束

- 每个数字都要有来源和数据时点；**取不到就写"数据不可用"，不要用"约 / 接近"带过，更不要凭印象填**
- 行情按运行时段标注（最近收盘 / 盘中 / 今日收盘，见调用约定）；数据源 `source_dead` 的段落写"数据暂缺"，不写"没有"
- 不喊单，不预测
- 经济日历按 `impact` 标重要性，时间注明 UTC
- 多源同事件合并去重
