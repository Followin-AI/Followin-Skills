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

> 🔗 **通用调用红线 + 已知问题登记**：`~/.claude/references/followin-mcp-caveats.md`（仓库内 `references/`）。本文的调用写法于 **2026-10-01 逐条实测**；与登记表冲突时，以日期更新的一方为准。

## 调用约定（2026-10-01 实测）

`metrics` 的入参分工是：**`keywords` 数组放标的 / series_id，`query` 放意图词**。

- **不要把标的塞进 query 串**：query 串解析会静默丢掉 `DXUSD` / `CLUSD` / `BZUSD` 这类 `*USD` 商品代码（不报错、不返数据），还会让 `^VIX` 返回重复行。数组写法没有这些问题，原油现货价也因此能直接取到，不必再用 USO 这只 ETF 代理。
- **每次调用最多 5 个 keywords**。超出或解析不了的项会写进 `meta.warnings`（`keyword_count_over_max` / `kw_not_canonical`）——每次调用后读一遍，有缺口就补调。
- FRED 指标带 `categories=["macro"]`；美股行情带 `asset_type="tradfi"`。
- `news()` 现在可以传 `asset_type="tradfi"` 和 `sources=["media"]`（旧记载"传了返回 0 条 / 数组被拒"已不成立）。
- 如果客户端不接受数组入参（报 `-32602`）：FRED 指标退回 `query="<series_id>"` 单个直查；美股 ticker 退回 `query="<T1> <T2> 行情"`；`*USD` 商品代码没有可用的 query 串写法，标"数据不可用"。
- **早报通常在盘前跑**：行情快照返回的是上一个常规收盘（`_quote_session:"regular_inactive"`）。只有交易时段才标"实时"，否则一律标"最近收盘"；盘前盘后的真实价格以新闻为准。

## 执行步骤

### Step 1: 数据拉取（每批 ≤4 路并行）

**Batch 1：宏观 + 榜单**
```
1. metrics(keywords=["DGS2","DGS10","DGS30"], categories=["macro"], limit=5)        # 国债收益率，5 条 = 近 5 个交易日
2. metrics(keywords=["^VIX","DXUSD","CLUSD","BZUSD"], query="行情", asset_type="tradfi")   # VIX / 美元指数 / WTI / 布油
3. metrics(query="economic calendar", country="US", date_from="<今天>", date_to="<今天+7天>", limit=50)
4. metrics(query="most active stocks", asset_type="tradfi", limit=30)               # 成交最活跃 30 只
```
- 经济日历**必须传 `country="US"`**，不传返回的是韩国、印度等地的事件。query 里不要写"本周"。噪音很多（国债拍卖、EIA 周报、官员讲话），只保留 `impact` 为 High 或 Medium 的行；`has_more:true` 时用 `meta.pagination` 里的 `next_cursor` 翻页。

**Batch 2：涨跌榜 + 新闻**
```
5. metrics(query="biggest gainers", asset_type="tradfi", limit=30)
6. metrics(query="biggest losers",  asset_type="tradfi", limit=30)
7. news(query="<按下方规则选>", sources=["media"], asset_type="tradfi", time_range="1d", limit=8, sort_by="relevance")
8. news(query="stock market",    sources=["media"], asset_type="tradfi", time_range="1d", limit=8, sort_by="relevance")
```
第 7 路的 query 按 Batch 1 的结果选一个最突出的信号（都不满足就用 `"Federal Reserve"`）：
- 10 年期收益率日变化 > 5bp → `"treasury yield"`
- VIX > 25，或日变化 > 10% → `"VIX volatility"`
- 原油日变化 > 3% → `"oil crude"`
- 未来 48 小时内有 High 级日历事件 → 事件名，如 `"CPI inflation"` / `"Fed FOMC"`

`news()` 的 query 写 2-3 个核心名词，纯英文；不写"影响 / 解读 / 分析"这类词。

**Batch 3：补市值 + watchlist**（见 Step 2）

### Step 2: 榜单过滤

三张榜（活跃 / 涨幅 / 跌幅）的行**只有** symbol / name / price / change / changesPercentage 五个字段，没有市值也没有交易所，而且混着大量仙股和杠杆 ETF。

1. **先按名称剔杠杆与 ETF 产品**：`name` 命中 `ETF|ETN|UltraPro|Ultra|Leveraged|\dX|Bull|Bear|Daily` 任一即剔。只判 "ETF" 一个词会漏——TQQQ（ProShares UltraPro QQQ）的名称里没有 "ETF"。
2. **挑候选**：涨幅榜、跌幅榜各取 `price ≥ 5` 的前 5 只；活跃榜取 `|changesPercentage| ≥ 3%` 的前 5 只。去重后通常 ≤15 只。这一步的价格闸只是为了少发几次补市值调用，漏掉的低价大盘股由活跃榜兜住。
3. **补市值和交易所**，每批 ≤5 个：
   ```
   metrics(keywords=[<T1>…<T5>], query="行情", asset_type="tradfi")
   ```
   快照行带 `marketCap` 和 `exchange`。涨跌百分比用 `change ÷ previousClose × 100` 自己算——**快照的 `change` 是美元变动量，不是百分比**。
4. **终筛**：`marketCap > 5 亿美元` 且 `exchange` 属于 NYSE / NASDAQ / AMEX。
5. watchlist（如果传了）同样每批 ≤5 个取快照。

### Step 3: 分析与聚合

1. **宏观环境**
   - 10Y−2Y 利差（正 = 正常，负 = 倒挂）
   - VIX 水平：<15 低 / 15-25 正常 / 25-35 偏高 / >35 恐慌
   - 原油、美元的日变化方向
2. **新闻热点**
   - 两路 news 合并后按 `source_url` 去重，标题高度相似的也并成一条（返回里没有聚类 id 字段）
   - 归纳出 3 个最热的话题，不要只从其中一路的结果里选
   - 逐篇判断情绪，标"Claude 推断"
3. **Watchlist 与异动**
   - watchlist 涨跌超过 2% 的标出来，并在新闻标题和正文里找有没有提到它

### Step 4: 输出报告

```
## 📊 财经早报 [日期]

### 宏观环境
| 指标 | 值 | 日变化 | 数据时点 |
|---|---|---|---|
| 10Y 国债 | X.XX% | ±Xbp | YYYY-MM-DD |
| 2Y 国债 | X.XX% | ±Xbp | YYYY-MM-DD |
| 10Y−2Y 利差 | XXbp | 正常 / 倒挂 | |
| VIX | XX.X | | 最近收盘 / 实时 |
| WTI 原油 | $XX.XX | ±X.X% | |
| 布伦特原油 | $XX.XX | ±X.X% | |
| 美元指数 | XXX.X | ±X.X% | |

### 📅 未来 7 天经济日历（美国）
| 日期 | 事件 | 预期 | 前值 | 重要性 |
|---|---|---|---|---|

### 🔥 今日热点 (Top 3)
1. [话题] — N 家媒体报道
   情绪（Claude 推断）: [正面 / 负面 / 中性]
   代表: "[标题]" — [来源]
2. ...
3. ...

### 📈 Watchlist 异动
| Ticker | 价格 | 涨跌% | 相关新闻 |
|---|---|---|---|
（没传 watchlist 时整节省略）

### 🏆 大市值异动（市值 > 5 亿美元，已剔除杠杆产品）
涨幅居前: ...
跌幅居前: ...
成交活跃且波动 > 3%: ...

> 过滤后不足 3 只时写"今日大市值股无极端异动"，不要放宽门槛凑数。

### 情绪分布
正面: XX 篇 | 中性: XX 篇 | 负面: XX 篇
整体市场情绪（Claude 推断）: [偏乐观 / 中性 / 偏悲观]

### ⚠️ 值得关注
- [交叉分析洞察]
- [即将发布的重要数据提醒]

### 数据缺口
- [没取到的指标及原因；没有就写"无"]
```

## 输出约束

- 每个数字都要有来源和数据时点；**取不到就写"数据不可用"，不要用"约 / 接近"带过，更不要凭印象填**
- 行情在非交易时段标"最近收盘"
- 不喊单，不预测
- 经济日历按 `impact` 标重要性
- 多源同事件合并去重
