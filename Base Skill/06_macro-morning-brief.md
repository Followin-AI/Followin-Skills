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
- **经济日历必须带 `country="US"` 和 `sort_by="hot"`**：不带 `sort_by` 时按时间排，50 行只覆盖一两天；带上后高重要度事件排在前面。日历的 `date` 是 **UTC**。带 `sort_by="hot"` 时 High 行全部排在 Medium 之前（2026-10-08 实测 30 行里前 22 行是 High），首页一出现 Medium 就说明 High 已取完，`has_more:true` 也不必翻页。
- 如果客户端不接受数组入参（报 `-32602`）：FRED 指标退回 `query="<series_id>"` 单个直查；美股 ticker 退回 `query="<T1> <T2> 行情"`；`*USD` 商品代码没有可用的 query 串写法，标"数据不可用"。
- **运行时段决定报价标注**：先把运行时刻换算成美东时间，再定整篇的口径（2026-10-08 实测）：
  - 美东 20:00 至次日 09:30（夜间 / 盘前）：快照 `price` 是上一常规收盘，标"最近收盘"。
  - 09:30–16:00（盘中）：快照和三张榜都是盘中数据，标"盘中 美东 HH:MM"（取 `as_of`）；"日变化"是相对昨收的盘中变动，不是昨日涨跌，榜单一节标题加"（盘中）"。2026-10-08 美东 10:08 跑，指数、VIX、原油、榜单全是当刻数据。
  - 16:00–20:00（盘后）：`price` 是当日收盘，标"今日收盘"。
  - **不要依赖 `_quote_session`**：2026-10-08 实测所有快照行（含 NVDA / AAPL）都没有这个字段。一律逐行读 `as_of`——同一批里各行时间点可能不同（盘前跑时 `^VIX` 的 `as_of` 会落在当天凌晨，算出来的不是昨收涨跌，N-150；美元指数的 `as_of` 也常比同批晚报十几分钟），与同批不一致的行单独标"截至 美东 HH:MM"。
  - **盘前 / 盘后价**：快照带 `extendedHoursQuote` 时取 (bidPrice+askPrice)/2 对 `price` 自算，标"盘前 / 盘后 美东 HH:MM"（指数没有这个字段，N-150）；没有就不写，**不拿新闻里的盘前涨幅顶替**。

## 执行步骤

### Step 1: 数据拉取（每批 ≤4 路并行）

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

**日历行怎么筛**（第 4、5 路）：保留全部 `impact=="High"`；`Medium` 只保留 `estimate` 非空的行。实测官员讲话、CFTC 持仓、WASDE 都标为 Medium 且 `estimate` 为空，这条规则能把它们去掉，留下贸易差额、首次申领这类有预期值的数据；EIA 原油 / 汽油库存 2026-10-08 实测已带 `estimate`，会被保留（10-07 原油库存 −319 万桶，预期 +170 万桶，正好是当天油价题的佐证）。第 5 路不带 `sort_by`、单日一般一页取完；`has_more:true` 时用 `next_cursor` 翻页。
- **当天已公布的行**：第 4 路从今天算起，美东 08:30 之后跑时，当天已发布的数据（`actual` 非空）会出现在这一路——它们挪到"最近已发布数据"表，不留在未来日历里（2026-10-08 实测当日首次申领 197K 就在第 4 路）。
- **预期值存疑**：利率、申领人数、销量这类水平值，`estimate` 偏离 `previous` 超过 15% 的标"预期存疑"，不据它判超预期、也不拿它选新闻题（2026-10-08 实测 10-07 的 `MBA 30-Year Mortgage Rate` 预期 6%、实际 7.49%、前值 7.30%；10-15 的持续申领预期 2070、前值 1716K，且 `unit` 为空）。
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
4. 原油日变化绝对值 > 3% → `"oil crude"`
5. 未来 2 个交易日内有 High 级日历事件 → 事件主题词

`news()` 的 query 写 2-3 个核心名词，纯英文；不写"影响 / 解读 / 分析"这类词。

**Batch 4：补市值 + watchlist**（见 Step 2）

### Step 2: 榜单过滤

三张榜（涨幅 / 跌幅 / 活跃）的行**只有** symbol / name / price / change / changesPercentage 五个字段，没有市值也没有交易所，每张最多约 30 行、以小盘股为主。**榜单覆盖有限：跌幅不够极端的大盘股不会上榜**（实测 10-02 STX −10.2%、市值 1,904 亿美元，三张榜都没有），所以这一节只能叫"榜单内可见的大市值异动"。

1. **先按名称剔杠杆、反向和 ETF 产品**：`name` 匹配 `(?i)\bETF\b|\bETN\b|Ultra|Leverag|\d+X\b|Bull|Bear|Daily|Short|Inverse|Target` 即剔（不区分大小写）。只判 "ETF" 一个词会漏——TQQQ 的名称是 ProShares UltraPro QQQ，RWM 是 ProShares - Short Russell2000。
2. **挑候选**（不截前 N 名）：
   - 涨幅榜、跌幅榜：**全部** `price ≥ 5` 的行
   - 活跃榜：**全部** `price ≥ 5` 且 `|changesPercentage| ≥ 3` 的行
   - 去重合并。价格闸只用来少发补市值调用；低价大盘股（如 GRAB）若漏掉，在数据缺口里写一句即可。
3. **补市值和交易所**，每批 5 个、每轮 ≤4 批并行：
   ```
   metrics(keywords=[<T1>…<T5>], query="行情", asset_type="tradfi")
   ```
   快照行带 `marketCap` 和 `exchange`。涨跌幅沿用榜单行的 `changesPercentage`（**快照的 `change` 是美元变动量，不是百分比**）。
4. **终筛**：`marketCap > 5 亿美元` 且 `exchange` 属于 NYSE / NASDAQ / AMEX。`marketCap` 小于 100 万美元的是异常值（2026-10-08 实测 BBCI 返回 `marketCap: 8`），按缺失处理、写进数据缺口，不要当成小盘股悄悄剔掉。名称含 `Acquisition Corp` 的是 SPAC（借壳空壳公司），保留但在输出里标"SPAC"——它们的暴涨通常来自合并消息，不代表行业动向。
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
   - 剔除离题文章（与美国市场无关的），以及标题含 "What You Should Know" / "Should You Buy" / "I'm Buying" 这类模板化个股稿和 `source_url` 含 `yseop_template` 的 Zacks 自动生成稿（`sources=["media"]` 也会返回 `source_quality:"research"` 的 Zacks / GuruFocus / 247wallst 稿，2026-10-08 实测；watchlist 找原因时不剔），再归纳 3 个最热的话题，不要只从其中一路的结果里选
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

### 🏆 榜单内可见的大市值异动（市值 > 5 亿美元，已剔除杠杆与反向产品；盘中跑注明"盘中"）
涨幅居前: ...
跌幅居前: ...
成交活跃且波动 > 3%: ...

> 过滤后不足 3 只时写"榜单内无大市值极端异动"，不要放宽门槛凑数。

### 媒体情绪
正面: XX 篇 | 中性: XX 篇 | 负面: XX 篇（Claude 推断）
对照盘面: 标普 ±X.XX%，VIX ±X.X% → [一致 / 背离]

### ⚠️ 值得关注
- [交叉分析洞察]
- [即将发布的重要数据提醒]

### 数据缺口
- 涨跌榜每张约 30 行、以小盘为主，跌幅不够极端的大盘股不在榜上
- [其余没取到的指标及原因]
```

## 输出约束

- 每个数字都要有来源和数据时点；**取不到就写"数据不可用"，不要用"约 / 接近"带过，更不要凭印象填**
- 行情按运行时段标注（最近收盘 / 盘中 / 今日收盘，见调用约定）；数据源 `source_dead` 的段落写"数据暂缺"，不写"没有"
- 不喊单，不预测
- 经济日历按 `impact` 标重要性，时间注明 UTC
- 多源同事件合并去重
