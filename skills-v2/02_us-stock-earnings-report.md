---
name: US Stock Earnings Report (v2 — Followin MCP)
description: 单股财报三维分析（财务Beat/Miss + 媒体情绪 + 宏观背景）。必须指定具体股票代码或公司名才触发，如"帮我看AAPL财报"、"TSLA earnings"、"英伟达财报分析"。泛问"今天有哪些财报"走情报中心，不在本Skill范围。
trigger: 帮我看XX财报、XX财报分析、XX财报速查、XX earnings、XX earnings report、[股票代码]财报、[公司名]财报、[ticker] earnings、earnings report、earnings analysis、show me [ticker] earnings、look at [ticker] earnings
not_trigger: 策略信号、KOL、喊单、热点、日报、背离扫描、divergence、strategy、KOL calls、trending、daily brief、divergence scan、morning brief
mcp: mcp__followin__metrics, mcp__followin__news
args: ticker
---

# /earnings-report-v2 $ARGUMENTS

单股财报分析 — 财务数据 + 媒体覆盖 + 宏观背景三维（Followin MCP 版）

## 参数

| 参数 | 必填 | 说明 |
|------|------|------|
| ticker | 是 | 股票代码，如 AAPL、TSLA、NVDA |

## 意图路由

| 用户说的 | 走哪个Skill |
|---------|-----------|
| XX财报、XX earnings、财报分析 | ✅ 本Skill |
| CPI影响、非农解读 | ❌ 转 macro-analyzer |
| 宏观日报、美股早报 | ❌ 转 morning-brief |
| 背离扫描 | ❌ 转 divergence-scan |

## 数据层 — Followin MCP 三工具映射

🔒 **本 Skill 全程美股，所有调用必须带 `asset_type="tradfi"`**（避免 ticker 错路由到 crypto 山寨币）

| 用途 | 调用 |
|------|------|
| **基本面聚合**（含 profile / 三表 / 估值 / 财报 Beat / 同行 / 评级）| `metrics(keywords=[ticker], categories=["fundamentals"], asset_type="tradfi")` 一次返全 |
| 行情 + 市值 + 多周期均线 | `metrics(keywords=[ticker], categories=["market"], asset_type="tradfi")` |
| 多时间框架历史 | `metrics(keywords=[ticker], time_range="1y", interval="1day", asset_type="tradfi")` |
| 媒体覆盖 | `news(query="<companyName> <ticker>", time_range="2w", limit=10, asset_type="tradfi")` |
| 宏观（按行业）| `metrics(keywords=["DGS10"], categories=["macro"], limit=5)` 等（见行业映射表）|

> **关键变化（vs v1）**：
> - 9 个老调用 → 3 个 metrics + 1 个 news + 行业宏观
> - **fundamentals 聚合**：profile + income_statement + ratios_ttm + earnings + analyst_estimates → **1 次调用搞定**
> - 删除 31 家媒体 users 列表
> - 删除 schema 修复说明（profile / analyst_estimates / stock_price_change 都自动走 fundamentals 聚合）
> - **stock-price-change 多周期涨跌**用 metrics 时间序列计算（snapshot 已含 priceAvg50 / 200，配合 time_range="1y" 可算 1D/5D/1M/3M/6M/YTD/1Y）

## EPS 数据源说明（保留 v1）

⚠️ Followin fundamentals 聚合返回两种 EPS：

| 来源 | 字段 | 含义 | 用途 |
|------|------|------|------|
| `beat_miss` block | epsActual / epsEstimated | **Adjusted EPS** | Beat/Miss 判定 |
| `latest_quarter` block | eps | **GAAP Diluted EPS** | 趋势分析 |
| `income_statement` block | epsdiluted | **GAAP EPS 历史** | 4Q YoY/QoQ 对比 |
| `eps_trend` block | eps（4 quarters）| **GAAP EPS 趋势** | 趋势表 |

**规则**：
- Beat/Miss 判定：用 `beat_miss.epsActual` vs `beat_miss.epsEstimated`
- 趋势表：两列并列 `Adj. EPS`（来源 beat_miss）+ `GAAP EPS`（来源 income_statement）
- Adjusted 与 GAAP 差异 > 30% 在分析中标注

## 执行步骤

### Step 1: fundamentals 真聚合（1 次拿全 12 个 block）

✅ **Dev 已完整修复 fundamentals 聚合** — 不带 query 或 query="全面分析" 自动走 `comprehensive` intent，**1 次返 12 个 block**：

```
metrics(keywords=["[T]"], categories=["fundamentals"], asset_type="tradfi")
→ intent_label="comprehensive"，~7000 tokens，含：
   1. beat_miss (Adj EPS Beat/Miss)
   2. consensus_price (目标价共识)
   3. eps_trend (4Q EPS)
   4. latest_quarter (Q 最新)
   5. next_earnings_estimate (下次财报预测)
   6. income_statement (4Q × 30+ 字段)        ← 利润表
   7. balance_sheet (4Q × 60+ 字段)            ← 资产负债表
   8. cash_flow (4Q × 35+ 字段)                ← 现金流量表
   9. valuation_block (dcf + ev + key_metrics_ttm + ratios_ttm)
   10. profile_block (CEO / sector / IPO / beta / website)
   11. stock_peers (9 个同行)
   12. analyst_grades (20 条评级历史)
   13. shares_float (流通股)
```

**等价的显式 trigger**（任选其一）：
- 不带 query（推荐，最简洁）
- `query="全面分析"`
- `query="comprehensive analysis"`（精确双词）

⚠️ **不要用的 trigger**：
- `query="comprehensive"` 单词 → default（识别不全，待 Dev 修）
- 这个 bug 不重要，因为**不带 query 已经默认走 comprehensive**

**可选追加**（按需展开）：
- `query="现金流量表"` → cashflow_detail + financial_growth
- `query="公司简介 profile"` → profile_block
- `query="评级变化 grades"` → analyst_grades 30 条
- `query="流通股 shares float"` → shares_float

**Batch B — market 行情 + 历史**：
```
2. metrics(keywords=["[T]"], categories=["market"], asset_type="tradfi")
   → price / change / volume / priceAvg50 / priceAvg200 / yearHigh/Low / marketCap

3. metrics(keywords=["[T]"], time_range="1y", interval="1day", asset_type="tradfi", limit=252)
   → 252 交易日历史，用于计算多周期涨跌
```

### Step 2: 媒体覆盖

```
news(
  query="[CompanyName] [TICKER]",   # 例: "Apple AAPL" / "Tesla TSLA" / "NVIDIA NVDA"
  time_range="1w" 或 "2w",
  limit=10,
  sort_by="relevance"
  # ⚠️ 不要传 asset_type="tradfi" — 实测会返 0 results（is_tradfi 字段几乎全 false 老 bug）
)

⚠️ query 三原则:
1. 2-3 个核心名词
2. 公司名 + ticker（提升精度，避免泛搜）
3. 不写"earnings 影响 解读"等元词
```

### Step 3: 宏观背景（按行业）

从 fundamentals 拿 `profile_block.sector` 和 `industry`，按映射调宏观：

| Sector | 调用 |
|---|---|
> 🔒 v3 修复：行业宏观 **全部走 keywords 直查**（query 路径已实测翻车：
> "WTI 原油" 返 crypto OIL + ETN / "30 年抵押贷款" 错抓 DGS30 国债）

| Sector | 调用 |
|---|---|
| Technology | `metrics(keywords=["DGS10","^VIX"], categories=["market"], asset_type="tradfi")` |
| Semiconductors | + `metrics(keywords=["CLUSD"], categories=["market"], asset_type="tradfi")` + `metrics(keywords=["PCEPILFE"], categories=["macro"], limit=5)` |
| Energy | `metrics(keywords=["CLUSD"], categories=["market"], asset_type="tradfi")` |
| Financials | `metrics(keywords=["DGS10","DGS2"], categories=["macro"], limit=5)` |
| Consumer | `metrics(keywords=["RSAFS"], categories=["macro"], limit=5)` + `metrics(keywords=["CPIAUCSL"], categories=["macro"], limit=5)` |
| Real Estate | `metrics(keywords=["MORTGAGE30US"], categories=["macro"], limit=5)` ⚠️ 不要写 "30 年抵押贷款" |
| Healthcare | `metrics(keywords=["CPIAUCSL"], categories=["macro"], limit=5)` ⚠️ CPIMEDSL 暂不在 Followin 字典（被错抓到 headline CPI，B-33），退而用 headline CPI |
| 其他 | `metrics(keywords=["DGS10","^VIX"], categories=["market"], asset_type="tradfi")` |

### Step 4: 三维分析

#### 维度一：财报表现（Beat / Miss / In-line）

从 `beat_miss` 取 Adjusted EPS:
```
- Beat:   epsActual > epsEstimated × 1.02
- Miss:   epsActual < epsEstimated × 0.98
- In-line: ±2% 内
```

从 `income_statement` 取 4 quarters GAAP EPS / Revenue 计算 YoY / QoQ。

趋势:
- 是否连续 beat？
- Revenue / EPS YoY 增速加速 / 减速？
- Adjusted vs GAAP 差异 > 30%？

#### 维度二：媒体覆盖与情绪

从 news() 10 篇文章，Claude 逐篇分析：
- 情绪偏向（正面 / 负面 / 中性）
- 高频关键词
- 代表性报道（标题 + 来源 + URL）
- 标注"Claude 推断"

#### 维度三：宏观一致性 + 价格动量

1Y 时间序列计算多周期涨跌：
```
1D = (今日 - 昨日) / 昨日
5D = (今日 - 5 日前) / 5 日前
1M = (今日 - 21 日前) / 21 日前
3M = (今日 - 63 日前) / 63 日前
6M = (今日 - 126 日前) / 126 日前
YTD = (今日 - 年初) / 年初
1Y = (今日 - 252 日前) / 252 日前
```

交叉验证:
- 财报 Beat + 情绪正面 + 宏观顺风 + 价格上行 = 强多信号
- 财报 Beat + 情绪负面 = 市场在担心什么？
- 财报 Miss + 价格未跌 = 已 price in？
- 财报 Beat + 宏观逆风 + 价格下行 = 板块 beta 拖累

### Step 5: 输出报告（同 v1 格式）

```
## 📋 [TICKER] 财报速查 — [CompanyName]

### 基本信息
行业: [sector] / [industry] | 市值: $[mktCap] | 当前价: $[price] ([change]%)
CEO: [ceo] | IPO: [ipoDate] | Beta: [beta]

### 价格动量
| 1D | 5D | 1M | 3M | 6M | YTD | 1Y |
|----|----|----|----|----|-----|-----|

### 最新季度财报 [Q? FY????]
| 指标 | 实际 | 预期 | 差异 | 判定 |
|------|------|------|------|------|
| EPS (Adjusted) | $X.XX | $X.XX | +X.X% | ✅ Beat |
| EPS (GAAP) | $X.XX | — | — | 参考 |
| Revenue | $X.XB | $X.XB | +X.X% | ✅ Beat |

> ⚠️ Adjusted 与 GAAP EPS 差异 XX%（仅在 >30% 时显示）

### 趋势（最近 4 季度）
| 季度 | Revenue | YoY | QoQ | Adj. EPS | YoY | GAAP EPS | Beat/Miss |
|------|---------|-----|-----|----------|-----|----------|-----------|

### 关键比率 (TTM)
PE: XX.X | PS: X.X | ROE: XX.X% | D/E: X.X | Gross Margin: XX.X%

### 📈 长期增长预期
| 期间 | 预期 EPS | 预期 Revenue | EPS 增速 |
|------|---------|-------------|---------|

隐含 PEG: [当前 PE / 预期年化 EPS 增速]

### 🏢 公司画像（profile_block）
- 主营: [description 摘要 200 字]
- 同行: [stock_peers top 5]

### 📊 分析师评级（analyst_grades 最近 10 条）
- maintain Buy: X 家
- upgrade Buy: X 家
- downgrade Hold: X 家

### 📰 媒体覆盖 (近 2 周, N 篇报道)
情绪判断（Claude 推断）: [偏正面/中性/偏负面]
正面: X篇 | 负面: X篇 | 中性: X篇
热门话题: [关键词1], [关键词2]

代表性报道:
- "[标题]" — [来源] ([日期])

### 🌐 宏观背景
- [宏观指标]: [值] → 对[sector]影响: [利好/利空/中性]

### 🔍 三维交叉判断
[综合 Beat/Miss + 情绪 + 宏观 + 动量的结论]
[如有不一致信号，明确指出分歧点和可能原因]
```

## 输出规则

- Beat/Miss 数据来源标 `beat_miss block (Adjusted EPS)`
- 趋势表同时展示 Adjusted 和 GAAP EPS
- Adjusted 与 GAAP 差异 > 30% 专门标注
- 情绪判断标"Claude 推断"
- 财报分析不是交易建议，是"值得进一步研究"的线索

## 注意事项（v2 — Followin MCP）

- 🔒 **`asset_type="tradfi"` 必须**（除 news），否则 ticker 名同 crypto 山寨币会错路由
- ⚠️ **news() 不要传 asset_type**（实测加 tradfi 返 0 results，is_tradfi 字段几乎全 false 老 bug）
- ✅ **fundamentals 真聚合已修复** — 不带 query 或 `query="全面分析"` 默认走 comprehensive intent，**1 次返 12 个 block**（~7000 tokens）。无需多次调用。
- 单独 sub-intent 触发词（仅在不需要全套时用）：
  - `query="利润表"` = income_statement only（1.4K tokens 节省）
  - `query="资产负债表"` = balance_sheet only
  - `query="现金流量表"` = cashflow + financial_growth
  - `query="估值"` = valuation_block only
  - `query="同行"` = stock_peers only
  - `query="评级变化"` = analyst_grades only
- **stock-price-change 多周期涨跌**：通过 `metrics(time_range="1y", interval="1day")` 时间序列计算，不需要单独端点
- **`news()` query 三原则**：2-3 核心名词 / 不混搭中英 / 不写元词
- **避免高并发**：单批 ≤ 4 路并发，否则 SSE 可能挂
- **`metrics()` FRED 字典未命中走 fred_search_fallback** → 改用 `keywords=["<series_id>"]` 兜底
