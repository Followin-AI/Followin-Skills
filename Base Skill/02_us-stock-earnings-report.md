---
name: US Stock Earnings Report
description: 单股财报三维分析（财务Beat/Miss + 媒体情绪 + 宏观背景）。必须指定具体股票代码或公司名才触发，如"帮我看AAPL财报"、"TSLA earnings"、"英伟达财报分析"。泛问"今天有哪些财报"不在本Skill范围。
trigger: 帮我看XX财报、XX财报分析、XX财报速查、XX earnings、XX earnings report、[股票代码]财报、[公司名]财报、[ticker] earnings、earnings report、earnings analysis、show me [ticker] earnings、look at [ticker] earnings
not_trigger: 全面分析、多维度分析、值不值得买、深度分析（→01）、策略信号、KOL、喊单、热点、日报、背离扫描、divergence、strategy、KOL calls、trending、daily brief、divergence scan、morning brief
mcp: mcp__followin__metrics, mcp__followin__news, mcp__followin__signal
args: ticker
---

# /earnings-report $ARGUMENTS

单股财报分析 — 财务数据 + 媒体覆盖 + 宏观背景三维（Followin MCP 版）

## 参数

| 参数 | 必填 | 说明 |
|------|------|------|
| ticker | 是 | 美股代码，如 AAPL、TSLA、NVDA。用户给的是公司名就先换成代码；给的是加密代币就说明本 Skill 只做美股 |

## 意图路由

| 用户说的 | 走哪个Skill |
|---------|-----------|
| XX财报、XX earnings、财报分析 | ✅ 本Skill |
| 全面分析、值不值得买 | ❌ 转 01 multi-agent-stock-analysis |
| 财报季扫描、谁业绩大增（不点名）| ❌ 转 earnings-season-screener |
| 宏观日报、美股早报 | ❌ 转 06 morning-brief |
| 背离扫描 | ❌ 转 03 divergence-scan |

> 🔗 **通用调用红线 + 已知问题登记**：`~/.claude/references/followin-mcp-caveats.md`（仓库内 `references/`）。本文的调用写法和字段名于 **2026-10-01 逐条实测**；与登记表冲突时，以日期更新的一方为准。

## 调用约定（2026-10-01 实测）

`metrics` / `signal` 的入参分工是：**`keywords` 数组放标的，`query` 放意图词**。

- **意图词用中文**。实测把英文指标名写进 query 会被当成 ticker：`"NVDA RSI 14"` 多带回一只代码为 RSI 的股票，`"… 30 day chart"` 多解析出 DAY。标的放进 `keywords` 数组后不会被丢，但 query 里的英文词仍可能额外解析出别的标的。
- 所有 `metrics` / `signal` 调用带 `asset_type="tradfi"`，否则同名加密代币会混进来。
- 每次调用后读 `meta.warnings`；`results` 里没有请求的标的就是没取到，别当成"数据为零"。
- `default_fanout_fallback` 这条 warning 是提示不是错误：它说明"没指定主题，返回核心基本面集合"，数据是齐的，不要重试。
- 如果客户端不接受数组入参（报 `-32602`），把 ticker 并进 query 串：`query="<T> 分析师评级 同行 DCF"`。
- **财报通常盘后发布**：`metrics` 在非交易时段返回的是上一个常规收盘（`_quote_session:"regular_inactive"`），**盘后那根跳涨或跳水不在返回里**。此时 `price` 标"常规收盘"，盘后涨跌取自新闻并标"据 [来源]·盘后"，两个数分开写。

## 返回结构（字段名以这里为准）

**调用 A — 快照 + 核心基本面**：`metrics(keywords=["<T>"], asset_type="tradfi")`（不写 query）

| 位置 | 内容 |
|---|---|
| `results.market.snapshot[]` | price / change / previousClose / dayHigh/Low / yearHigh/Low / marketCap / exchange。**`change` 是美元变动量**，百分比自己算 `change ÷ previousClose × 100` |
| `fundamentals.concise[].fiscal_quarters[0].earnings_surprise` | **最新一季**的 `actual_eps` / `estimated_eps` / `eps_surprise_pct` / `actual_revenue` / `estimated_revenue` / `revenue_surprise_pct` / `report_date` |
| `fundamentals.concise[].fiscal_quarters[0].financial_statement` | 同一季的 `revenue` / `eps` / `epsDiluted` / `netIncome` / `period_end` |
| `…eps_trend[]` | 最近 4 季 EPS（财报口径）|
| `…balance_sheet[]` / `cash_flow[]` | 最近 4 季 |
| `…profile_block` | sector / industry / ceo / beta / ipoDate / description |
| `…valuation_block.ratios_ttm` | PE / PS / PB / PEG / 毛利率 / 净利率 / D/E 等 |
| `…consensus_price` | 目标价共识 / 最高 / 最低 / 中位 |
| `…next_earnings_estimate` | 下次财报日期与预期 |

**调用 B — 利润表 4 季**：`metrics(keywords=["<T>"], query="财报 利润表", categories=["fundamentals"], asset_type="tradfi", limit=4)` → `income_statement[]`（revenue / grossProfit / operatingIncome / netIncome / eps / epsDiluted）

**调用 C — 分析师与同行**：`metrics(keywords=["<T>"], query="分析师评级 同行 DCF", asset_type="tradfi", limit=10)` → `analyst_grades[]`、`analyst_estimates[]`（未来各财年的 EPS / 营收预期）、`stock_peers[]`、`valuation_block.dcf` / `key_metrics_ttm`（ROE、EV/EBITDA 等）

### 五条财报陷阱（判定 Beat/Miss 前必读）

1. **只有最新一季有"实际对预期"**。`fiscal_quarters` 只返回一季，所以"是否连续超预期"无从判断——不要从 `eps_trend` 里推。
2. **两个 EPS 口径不同**。`earnings_surprise.actual_eps` 是分析师口径（通常是调整后），`financial_statement.eps` 是财报口径（GAAP）。实测 NVDA 同一季分别是 2.22 和 2.47。两者不相等时：Beat/Miss 用前者判，并标注"调整后口径"；两者**符号相反**（一正一负）时必须点明"该超预期为调整后口径，本季 GAAP 为亏损"。不要把两个序列混在一张趋势里。
3. **缺失会伪装成 -100%**。`actual_revenue` 为 null 时，`revenue_surprise_pct` 会显示 -100——那是缺数据不是营收归零。`actual_revenue` 非 null 才读 surprise。
4. **财报当晚数据可能还是上一季**。先看 `earnings_surprise.report_date`：如果它不是刚发布的这次，说明数据还没更新，本季的"实际对预期"一律取自 `news()` 的媒体原文并标来源，第二天再用 metrics 复核。
5. **4 季窗口算不出同比**。最新季的去年同期不在返回里，趋势表只做环比；同比需要外部来源，别把 3 季前那季当去年同期。

## 执行步骤

### Step 1: 数据采集（每批 ≤4 路并行）

**Batch 1**
```
1. metrics(keywords=["<T>"], asset_type="tradfi")                                             # 调用 A
2. metrics(keywords=["<T>"], query="财报 利润表", categories=["fundamentals"],
           asset_type="tradfi", limit=4)                                                      # 调用 B
3. metrics(keywords=["<T>"], query="分析师评级 同行 DCF", asset_type="tradfi", limit=10)        # 调用 C
4. metrics(keywords=["<T>"], query="历史走势", asset_type="tradfi", time_range="1y", limit=260) # 一年日线
```
第 4 路**必须传 `limit=260`**——默认只返回 10 条，算不出多周期涨跌。

**Batch 2**
```
5. news(query="<CompanyName> <TICKER>", sources=["media"], asset_type="tradfi",
        time_range="2w", limit=10, sort_by="relevance")                      # 媒体报道
6. news(query="<CompanyName> <TICKER>", sources=["twitter"], time_range="1w", limit=10)   # 推特风向（可选）
7. signal(keywords=["<T>"], categories=["insider_trading","institutional","kol_call"],
          asset_type="tradfi", limit=20)                                      # 内部人 + 13F + KOL，1 次额度
8. metrics(keywords=["<T>"], query="research reports", categories=["fundamentals"],
           asset_type="tradfi", time_range="7d", verbosity="detail")          # 机构研报
```
- `news()` 的 query 用"公司名 + 代码"两个词（如 `"Apple AAPL"`），不写"earnings 影响 解读"这类词。
- `news()` 查不到相关内容时不会返回空，而是返回一批不相关的热门内容。**返回里一条都不含目标公司名或代码，就是没查到**，记数据缺口，不要重试，也不要拿这些内容做情绪判断。
- `signal()` **必须显式传 `categories`**——只传 ticker 现在返回空（旧记载"省略 categories 自动展开"已失效）。三类一起传仍只计 1 次额度。
- 13F 的环比字段在申报季中期不完整，只引用持仓绝对值和结构。
- KOL 喊单先按 `source_url` 去重，一条提到多个标的的推文会裂成多行。
- 研报的 `subject_reports` 是专题报告，`mention_reports` 只是别的报告里提到它；`subject_reports` 为空时不能说"有机构专题覆盖"。

**Batch 3：宏观背景（按行业）**

从 `profile_block.sector` / `industry` 取行业，按下表调用。FRED 指标带 `categories=["macro"]`，不与行情标的放在同一次调用里。

| `sector`（接口返回的原文）| `industry` 含 | 调用 |
|---|---|---|
| Technology / Communication Services | — | `metrics(keywords=["DGS10"], categories=["macro"], limit=5)` + `metrics(keywords=["^VIX"], query="行情", asset_type="tradfi")` |
| Technology | Semiconductors | 上一行两条，另加 `metrics(keywords=["PCEPILFE"], categories=["macro"], limit=5)` |
| Energy | — | `metrics(keywords=["CLUSD","BZUSD"], query="行情", asset_type="tradfi")` |
| Financial Services | — | `metrics(keywords=["DGS10","DGS2"], categories=["macro"], limit=5)` |
| Consumer Cyclical / Consumer Defensive | — | `metrics(keywords=["RSAFS","CPIAUCSL"], categories=["macro"], limit=5)` |
| Real Estate | — | `metrics(keywords=["MORTGAGE30US"], categories=["macro"], limit=5)` |
| Healthcare | — | `metrics(keywords=["CPIAUCSL"], categories=["macro"], limit=5)`（医疗 CPI `CPIMEDSL` 取不到）|
| 其他 | — | 同第一行 |

### Step 2: 三维分析

#### 维度一：财报表现

用 `earnings_surprise` 判定（先过上面的陷阱 3 和 4）：
```
EPS：    Beat = eps_surprise_pct > +2%；Miss = < −2%；其余 In-line
营收：   Beat = revenue_surprise_pct > +2%；Miss = < −2%；其余 In-line
```
用调用 B 的 4 季利润表算营收和 EPS 的环比，看是加速还是减速。

#### 维度二：媒体覆盖与情绪

对第 5 路返回的文章，先剔掉与该公司无关的，再逐篇判断：情绪偏向、高频话题、代表性报道（标题 + 来源 + 链接）。情绪结论标"Claude 推断"。

#### 维度三：宏观一致性 + 价格动量

用一年日线自算：
```
1D = 最新收盘 ÷ 前一日收盘 − 1
5D / 1M / 3M / 6M / 1Y = 最新收盘 ÷ 5 / 21 / 63 / 126 / 252 个交易日前的收盘 − 1
YTD = 最新收盘 ÷ 今年第一个交易日的收盘 − 1
```
交叉对照（用来提问，不是下结论）：
- Beat + 情绪正面 + 宏观顺风 + 价格上行 → 各维度一致
- Beat + 情绪负面 → 市场在担心什么
- Miss + 价格没跌 → 是否已提前反映
- Beat + 宏观逆风 + 价格下行 → 是否被板块拖累

### Step 3: 输出报告

```
## 📋 [TICKER] 财报速查 — [CompanyName]

### 基本信息
行业: [sector] / [industry] | 市值: $[marketCap] | 价格: $[price]（[自算涨跌%]，[实时 / 常规收盘]）
CEO: [ceo] | IPO: [ipoDate] | Beta: [beta]
[非交易时段且新闻里有盘后价时加一行] 盘后: [涨跌]（据 [来源]）

### 价格动量
| 1D | 5D | 1M | 3M | 6M | YTD | 1Y |
|----|----|----|----|----|-----|-----|

### 最新季度财报 [fiscal_period]（发布于 [report_date]）
| 指标 | 实际 | 预期 | 差异 | 判定 |
|------|------|------|------|------|
| EPS（分析师口径）| $X.XX | $X.XX | +X.X% | ✅ Beat |
| EPS（财报口径）| $X.XX | — | — | 参考 |
| 营收 | $X.XB | $X.XB | +X.X% | ✅ Beat |

[两个 EPS 不相等时] ⚠️ 两个 EPS 口径不同：分析师口径 $X.XX，财报口径 $X.XX
[符号相反时] ⚠️ 该超预期为调整后口径，本季 GAAP 为亏损

### 趋势（最近 4 季，财报口径）
| 季度 | 营收 | 环比 | 净利润 | EPS | 环比 |
|------|------|------|--------|-----|------|

> 4 季窗口算不出同比；历史各季的"实际对预期"接口不提供。

### 关键比率 (TTM)
PE: XX.X | PS: X.X | PEG: X.X | ROE: XX.X% | D/E: X.X | 毛利率: XX.X%

### 📈 分析师预期（analyst_estimates）
| 财年截止 | 预期 EPS | 预期营收 | 覆盖分析师数 |
|------|---------|---------|---------|

目标价共识: $XXX（区间 $XXX – $XXX）｜DCF: $XXX [DCF 与现价相差 5 倍以上时不展示，标"DCF 失效"]

### 🏢 公司画像
- 主营: [description 摘要，≤200 字]
- 同行: [stock_peers 前 5]

### 📊 分析师评级（analyst_grades 最近 10 条）
- 维持 / 上调 / 下调各几家，列出上调和下调的机构与日期

### 🧭 信号面
- 内部人: [近 3 个月主动买入 / 卖出笔数与金额]
- 机构持仓: [前几大持有人与占比]
- KOL: [去重后的多空条数]
- 机构研报: [专题报告 N 篇 / 仅被提及 N 篇；最新催化与主要保留意见]

### 📰 媒体覆盖（近 2 周，相关报道 N 篇）
情绪判断（Claude 推断）: [偏正面 / 中性 / 偏负面]
正面: X 篇 | 负面: X 篇 | 中性: X 篇
热门话题: [关键词]

代表性报道:
- "[标题]" — [来源]（[日期]）

### 🌐 宏观背景
- [宏观指标]: [值，数据日期] → 对 [sector] 的含义

### 🔍 三维交叉判断
[综合 Beat/Miss、情绪、宏观、动量；信号不一致时点明分歧在哪、可能的原因]

### 数据缺口
- [没取到的部分及原因；没有就写"无"]
```

## 输出规则

- Beat/Miss 注明口径（分析师口径 EPS）
- 情绪判断标"Claude 推断"
- 取不到的字段写"数据不可用"并列入数据缺口，不要留空让人以为是零，更不要凭印象填
- 这是"值得进一步研究"的线索，不是交易建议；不给买卖结论，不预测价格
