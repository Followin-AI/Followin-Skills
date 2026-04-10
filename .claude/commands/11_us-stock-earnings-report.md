---
name: US Stock Earnings Report
description: 单股财报三维分析（财务Beat/Miss + 媒体情绪 + 宏观背景）。必须指定具体股票代码或公司名才触发，如"帮我看AAPL财报"、"TSLA earnings"、"英伟达财报分析"。泛问"今天有哪些财报"走情报中心，不在本Skill范围。
trigger: 帮我看XX财报、XX财报分析、XX财报速查、XX earnings、XX earnings report、[股票代码]财报、[公司名]财报
not_trigger: 策略信号、KOL、喊单、热点、日报、背离扫描、divergence
mcp: finance_tool_income_statement, finance_tool_earnings, finance_tool_ratios_ttm, finance_tool_quote, finance_tool_stable_request, search_finance_news, fred_get_series
args: ticker
---

# /earnings-report $ARGUMENTS

单股财报分析 — 财务数据 + 媒体覆盖 + 宏观背景三维分析

## 参数

| 参数 | 必填 | 说明 |
|------|------|------|
| ticker | 是 | 股票代码，如 AAPL、TSLA、NVDA |

## 意图路由

| 用户说的 | 走哪个Skill |
|---------|-----------|
| XX财报、XX earnings、财报分析、财报速查 | ✅ 本Skill（earnings-report） |
| CPI影响、非农解读、宏观数据分析 | ❌ 转 macro-analyzer |
| 宏观日报、美股早报 | ❌ 转 morning-brief |
| 背离扫描、异常信号 | ❌ 转 divergence-scan |

本Skill 聚焦**单只个股的财报三维分析**（财务Beat/Miss + 媒体情绪 + 宏观背景），不做宏观指标解读、不做综合日报、不做多标的扫描。

## 数据层工具映射

> **重要**: `finance_tool_*` 系列工具 schema 大部分已修复，可直接调用。
> 仍有 schema 问题的工具（`profile`、`analyst_estimates`、`stock_price_change`）需通过 `finance_tool_stable_request` 访问。

| 用途 | 调用方式 | 参数 | 说明 |
|------|----------|------|------|
| 公司基本信息 | `finance_tool_stable_request` | path=`profile`, params=`{symbol: TICKER}` | ⚠️ schema 未修复，仍需 stable_request |
| 季度利润表 | `finance_tool_income_statement` | `symbol, period: "quarter", limit: 8` | ✅ 直接调用 |
| Beat/Miss 判定 | `finance_tool_earnings` | `symbol` | ✅ 直接调用，返回 Adjusted EPS |
| 分析师预测 | `finance_tool_stable_request` | path=`analyst-estimates`, params=`{symbol: TICKER, period: "quarter"}` | ⚠️ schema 未修复。**必须传 period，否则 400 错误** |
| 关键比率 TTM | `finance_tool_ratios_ttm` | `symbol` | ✅ 直接调用 |
| 实时报价 | `finance_tool_quote` | `symbol` | ✅ 直接调用 |
| 多时间框架涨跌 | `finance_tool_stable_request` | path=`stock-price-change`, params=`{symbol: TICKER}` | ⚠️ schema 未修复 |
| 媒体覆盖 | `search_finance_news` | `keyword: "companyName ticker"`（如 `"Apple AAPL"`） | 31家财经媒体搜索。加 ticker 提升精度 |
| 宏观指标 | `fred_get_series` | series_id + limit(integer) | FRED 序列数据 |

## EPS 数据源说明

⚠️ FMP 有两套 EPS 数据，含义不同：

| 来源 | endpoint | 字段 | 含义 | 用途 |
|------|----------|------|------|------|
| earnings | `earnings` | epsActual / epsEstimated | **Adjusted EPS**（剔除一次性项目） | Beat/Miss 判定 |
| income-statement | `income-statement` | epsdiluted | **GAAP Diluted EPS**（含一次性项目） | 趋势分析、盈利质量 |

**规则**：
- Beat/Miss 判定：**只用 earnings endpoint 的 Adjusted EPS**
- 趋势表：两列并列展示 `Adj. EPS` 和 `GAAP EPS`，标注来源
- 若两者差异 > 30%，在分析中标注"Adjusted 与 GAAP 差异显著，注意非经常性项目影响"

## 执行步骤

### Step 1: 获取公司基本信息

```
finance_tool_stable_request:
  path: "profile"
  params: {symbol: "[TICKER]"}
  ⚠️ profile schema 未修复，仍需通过 stable_request

提取: companyName, sector, industry, mktCap, country
用 companyName 作为后续 search_finance_news 的 keyword
```

### Step 2: 并行拉取数据（7个调用）

同时发起以下调用：

**FMP 直调工具（4个）：**
```
1. finance_tool_income_statement:
   symbol: "[TICKER]", period: "quarter", limit: 8
   → 最近8季度（4季度趋势 + 4季度用于YoY对比）

2. finance_tool_earnings:
   symbol: "[TICKER]"
   → Adjusted EPS actual vs estimated → Beat/Miss 判定核心

3. finance_tool_ratios_ttm:
   symbol: "[TICKER]"
   → PE, PS, ROE, D/E (TTM)

4. finance_tool_quote:
   symbol: "[TICKER]"
   → 当前价格、涨跌幅
```

**FMP stable_request（2个，schema 未修复）：**
```
5. finance_tool_stable_request:
   path: "analyst-estimates"
   params: {symbol: "[TICKER]", period: "quarter"}
   → 未来EPS/Revenue前瞻预测（⚠️ 必须传 period，否则 400 错误）

6. finance_tool_stable_request:
   path: "stock-price-change"
   params: {symbol: "[TICKER]"}
   → 1D/5D/1M/3M/6M/YTD/1Y 涨跌幅
```

**媒体覆盖（1个调用）：**
```
search_finance_news:
  keyword: "[companyName] [ticker]"（如 "Apple AAPL"、"Tesla TSLA"、"NVIDIA NVDA"）
  count: 10
  not_before_ts: 14天前的 unix 时间戳
  ⚠️ 纯公司名（如 "Apple"）太宽泛，会混入无关内容。加 ticker 可显著提升精度。
```

### Step 3: 宏观数据

```
根据 sector/industry 调用 fred_get_series（limit 用整数类型）:

- Technology → DGS10 (limit: 5), VIXCLS (limit: 5)
  - Semiconductors 额外: DCOILWTICO, PCEPILFE
- Energy → DCOILWTICO
- Financials → DGS10, DGS2
- Consumer → RSAFS, CPIAUCSL
- Real Estate → MORTGAGE30US
- Healthcare → CPIMEDSL
- 其他 → DGS10, VIXCLS

注意: fred_get_series 的 limit 参数必须传 integer（如 5），不能传 string
```

### Step 4: 三维分析

**维度一：财报表现 (Beat / Miss / In-line)**

```
从 earnings endpoint 取最近季度的 Adjusted EPS:
- Beat: epsActual > epsEstimated × 1.02
- Miss: epsActual < epsEstimated × 0.98
- In-line: ±2% 范围内
- Revenue 同理

从 income-statement 取 GAAP EPS:
- 与 Adjusted EPS 对比，差异 > 30% 时标注
- 计算 QoQ 和 YoY 变化（需要8季度数据）

趋势:
- 是否连续 beat？趋势改善还是恶化？
- Revenue/EPS 的 YoY 增速是加速还是减速？
```

**维度二：媒体覆盖与情绪**
```
从 search_finance_news 的 10 篇文章中:
- Claude 逐篇分析 title + content，判断情绪
- 计算正面/负面/中性比例
- 提取高频关键词
- 标注"Claude 推断"以区分机器 sentiment
```

**维度三：宏观一致性 + 价格动量**
```
结合 stock-price-change 的多时间框架数据:
- 1D/5D: 短期动量
- 1M/3M: 中期趋势
- 6M/1Y: 长期方向

交叉验证:
- 财报 Beat + 情绪正面 + 宏观顺风 + 价格上行 = 强多信号
- 财报 Beat + 情绪负面 = 市场在担心什么？
- 财报 Miss + 价格未跌 = 已 price in？
- 财报 Beat + 宏观逆风 + 价格下行 = 板块 beta 拖累
```

### Step 5: 输出报告

```
## 📋 [TICKER] 财报速查 — [CompanyName]

### 基本信息
行业: [sector] / [industry] | 市值: $[mktCap] | 当前价: $[price] ([change]%)

### 价格动量
| 1D | 5D | 1M | 3M | 6M | YTD | 1Y |
|----|----|----|----|----|-----|-----|
| +X% | +X% | +X% | +X% | +X% | +X% | +X% |

### 最新季度财报 [Q? FY????]
| 指标 | 实际 | 预期 | 差异 | 判定 |
|------|------|------|------|------|
| EPS (Adjusted) | $X.XX | $X.XX | +X.X% | ✅ Beat |
| EPS (GAAP) | $X.XX | — | — | 参考 |
| Revenue | $X.XB | $X.XB | +X.X% | ✅ Beat |

> ⚠️ Adjusted 与 GAAP EPS 差异 XX%，主要因 [非经常性项目说明]（仅在差异>30%时显示）

### 趋势（最近4季度）
| 季度 | Revenue | YoY | QoQ | Adj. EPS | YoY | GAAP EPS | Beat/Miss |
|------|---------|-----|-----|----------|-----|----------|-----------|
| Q4 FY25 | $X.XB | +X% | +X% | $X.XX | +X% | $X.XX | ✅ Beat |
| Q3 FY25 | ... | ... | ... | ... | ... | ... | ... |

### 关键比率 (TTM)
PE: XX.X | PS: X.X | ROE: XX.X% | D/E: X.X | Gross Margin: XX.X%

### 📈 长期增长预期
| 期间 | 预期 EPS | 预期 Revenue | EPS 增速 |
|------|---------|-------------|---------|
| FY2026 | $X.XX | $X.XB | +X% |
| FY2027 | $X.XX | $X.XB | +X% |

隐含 PEG: [当前PE / 预期年化EPS增速]

### 📰 媒体覆盖 (近14天, N篇报道)
情绪判断（Claude 推断）: [偏正面/中性/偏负面]
正面: X篇 | 负面: X篇 | 中性: X篇
热门话题: [关键词1], [关键词2]

代表性报道:
- "[标题]" — [来源] ([日期]) → [source_url]
- "[标题]" — [来源] ([日期]) → [source_url]

### 🌐 宏观背景
- [宏观指标]: [值] → 对[sector]的影响: [利好/利空/中性]

### 🔍 三维交叉判断
[综合 Beat/Miss + 情绪方向 + 宏观环境 + 价格动量 的结论]
[如有不一致信号，明确指出分歧点和可能原因]
```

## 输出规则

- Beat/Miss 数据标注来源为 `earnings` endpoint (Adjusted EPS)
- 趋势表同时展示 Adjusted 和 GAAP EPS
- Adjusted 与 GAAP 差异 > 30% 时专门标注
- 情绪判断标注"Claude 推断"
- 新增价格动量表（stock-price-change）提供多时间框架上下文
- 财报分析不是交易建议，是"值得进一步研究"的线索

## 注意事项

- **大部分 FMP 工具已可直接调用**（`income_statement`、`earnings`、`ratios_ttm`、`quote`）
- **`profile`、`analyst_estimates`、`stock_price_change` 仍需通过 `finance_tool_stable_request`**（schema 未修复，params 对象为空）
- **Beat/Miss 必须用 `earnings` endpoint**，不能用 `analyst-estimates`（后者只有前瞻预测）
- **EPS 需区分 Adjusted vs GAAP**，earnings 返回 Adjusted，income-statement 返回 GAAP
- **income-statement 取 8 季度**（而非 4 季度），多出的 4 季度用于计算 YoY
- **search_finance_news 用 companyName**（如 "Tesla" > "TSLA"），count 控制在 10 篇
- **fred_get_series 的 limit 必须传 integer**（如 `5`），不能传 string `"5"`
- **stock-price-change** 提供 1D-1Y 多时间框架涨跌幅，用于判断价格动量方向
