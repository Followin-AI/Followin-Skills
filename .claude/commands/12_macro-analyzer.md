---
name: Macro Analyzer
description: 宏观数据影响分析 — 从指标变动到板块影响的全链路。必须同时包含"指标名"+"影响/解读/分析"才触发，如"CPI出来了对市场有什么影响"、"非农解读"、"利率影响哪些板块"。纯数据查询（"CPI是多少"）走情报中心，综合日报走morning-brief，BTC/黄金宏观走各自看盘Skill。
trigger: 宏观指标影响、宏观指标解读、宏观指标分析、宏观数据影响、宏观数据解读、宏观数据分析、CPI影响、CPI解读、CPI分析、非农影响、非农解读、非农分析、利率影响、利率解读、GDP影响、GDP解读、关税影响、关税分析
not_trigger: 策略信号、KOL、喊单、热点、日报、BTC宏观、黄金宏观、财报、earnings、宏观日报、宏观早报、美股早报、CPI是多少、利率是多少
mcp: fred_get_series, finance_tool_batch_quote_short, finance_tool_quote, search_finance_news
args: indicator
---

# /macro-analyzer $ARGUMENTS

宏观数据影响分析 — 从指标变动到板块影响的全链路

## 参数

| 参数 | 必填 | 说明 |
|------|------|------|
| indicator | 是 | 宏观指标名或关键词，如 CPI、NFP、Fed Rate、GDP |

## 意图路由

| 用户说的 | 走哪个Skill |
|---------|-----------|
| CPI影响、非农解读、利率影响、GDP影响、宏观数据分析 | ✅ 本Skill（macro-analyzer） |
| 宏观日报、宏观早报、美股早报、美股日报 | ❌ 转 morning-brief |
| XX财报、XX earnings | ❌ 转 earnings-report |
| 背离扫描、异常信号 | ❌ 转 divergence-scan |
| BTC宏观、宏观看盘 | ❌ 转 08_BTC宏观看盘_v1 |
| 黄金宏观 | ❌ 转 09_黄金监控看盘_v1 |

本Skill 聚焦**单个宏观指标发布后的影响分析**（指标→板块→个股的全链路），不做综合日报、不做个股财报、不做信号背离扫描。

## 数据层工具映射

> **重要**: `finance_tool_*` 系列工具 schema 已修复，大部分可直接调用。
> 仍有 schema 问题的工具（`profile`、`analyst_estimates`、`stock_price_change`）需通过 `finance_tool_stable_request` 访问。

| 用途 | 调用方式 | 参数 | 说明 |
|------|----------|------|------|
| FRED 指标数据 | `fred_get_series` | series_id + limit(integer) | 直接调用 |
| ETF 批量报价 | `finance_tool_batch_quote_short` | `symbols: "XLE,XLB,..."` | 逗号分隔，直接调用 |
| VIX 实时 | `finance_tool_quote` | `symbol: "^VIX"` | 直接调用，symbol 带 `^` |
| 商品报价 | `finance_tool_quote` | `symbol: "BZUSD"` | 布油/原油等，直接调用 |
| 媒体报道 | `search_finance_news` | keyword + users(array) + count | 用英文缩写搜索 |

## 指标别名映射

```json
{
  "CPI": "CPIAUCSL",
  "核心CPI": "CPILFESL",
  "PCE": "PCEPILFE",
  "非农": "PAYEMS",
  "NFP": "PAYEMS",
  "失业率": "UNRATE",
  "GDP": "GDPC1",
  "利率": "FEDFUNDS",
  "Fed Rate": "FEDFUNDS",
  "国债": "DGS10",
  "10年国债": "DGS10",
  "2年国债": "DGS2",
  "VIX": "VIXCLS",
  "原油": "DCOILWTICO",
  "WTI": "DCOILWTICO",
  "美元指数": "DTWEXBGS",
  "零售": "RSAFS",
  "房贷利率": "MORTGAGE30US",
  "房屋开工": "HOUST",
  "初请失业金": "ICSA",
  "PMI": "MANEMP"
}
```

## 指标 → 板块影响映射

```json
{
  "CPIAUCSL": {
    "name": "CPI (消费者物价指数)",
    "bullish_sectors": ["Energy", "Materials", "Real Estate"],
    "bearish_sectors": ["Technology", "Consumer Discretionary"],
    "key_etfs": ["XLE", "XLB", "XLK", "XLY", "XLRE", "TIP"],
    "interpretation": "CPI 高于预期 → 加息预期升温 → 成长股承压，通胀受益股偏强"
  },
  "PAYEMS": {
    "name": "Non-Farm Payrolls",
    "bullish_sectors": ["Consumer Discretionary", "Financials"],
    "bearish_sectors": ["Utilities", "Real Estate"],
    "key_etfs": ["XLY", "XLF", "XLU", "XLRE"],
    "interpretation": "强就业 → 经济强劲 → 周期股受益，但加息预期也升温"
  },
  "FEDFUNDS": {
    "name": "Federal Funds Rate",
    "bullish_sectors": ["Financials"],
    "bearish_sectors": ["Real Estate", "Utilities", "Technology"],
    "key_etfs": ["XLF", "XLRE", "XLU", "XLK"],
    "interpretation": "加息 → 银行净息差扩大受益，高估值成长股承压"
  },
  "DGS10": {
    "name": "10-Year Treasury Yield",
    "bullish_sectors": ["Financials"],
    "bearish_sectors": ["Technology", "Real Estate", "Utilities"],
    "key_etfs": ["XLF", "XLK", "XLRE", "XLU", "TLT"],
    "interpretation": "10Y上行 → 贴现率上升 → 成长股估值承压，金融股受益"
  },
  "DCOILWTICO": {
    "name": "WTI Crude Oil",
    "bullish_sectors": ["Energy"],
    "bearish_sectors": ["Airlines", "Transportation"],
    "key_etfs": ["XLE", "JETS", "XLI", "USO"],
    "interpretation": "油价上涨 → 能源股直接受益，运输成本上升"
  },
  "UNRATE": {
    "name": "Unemployment Rate",
    "bullish_sectors": ["Consumer Staples", "Utilities"],
    "bearish_sectors": ["Consumer Discretionary", "Financials"],
    "key_etfs": ["XLP", "XLU", "XLY", "XLF"],
    "interpretation": "失业率上升 → 防御型受青睐，消费和金融承压"
  },
  "GDPC1": {
    "name": "Real GDP",
    "bullish_sectors": ["Industrials", "Consumer Discretionary", "Financials"],
    "bearish_sectors": ["Utilities"],
    "key_etfs": ["SPY", "QQQ", "IWM", "XLU", "XLI"],
    "interpretation": "GDP超预期 → 风险偏好提升，周期股和小盘股受益"
  }
}
```

## 执行步骤

### Step 1: 解析指标

```
1. 检查用户输入是否匹配别名映射表 → 获取 series_id
2. 如果没有匹配，尝试用英文缩写直接作为 series_id 调 fred_get_series
3. 从板块影响映射中获取对应 sectors 和 key_etfs
```

### Step 2: 并行拉取数据（3个调用）

**FRED 数据趋势：**
```
fred_get_series:
  series_id: [解析结果]
  limit: 12 (integer!)
  sort_order: desc

提取: 最新值、前值、变化幅度、趋势方向
⚠️ null 值处理：跳过 null，取最近非 null 值，标注数据截止日期
```

**ETF 板块批量报价：**
```
finance_tool_batch_quote_short:
  symbols: "[key_etfs逗号分隔]"

例如 CPI → symbols: "XLE,XLB,XLK,XLY,XLRE,TIP"
返回: price, change, volume
```

**媒体解读：**
```
search_finance_news:
  keyword: [指标英文缩写，如 "CPI" "GDP" "NFP"]
  count: 10
  not_before_ts: 7天前的 unix 时间戳(秒)
  users: [全部31家媒体的 Followin 用户名]

注意:
- 英文缩写搜索效果好（"CPI" 命中率 ~80%）
- 不支持复合关键词（"tariff Iran" 返回空），每个概念单独搜
- users 必填且为 array 类型
```

### Step 3: 影响分析

1. **数据解读**：
   - 最新值 vs 前值（跳过 null），12 期趋势方向
   - 标注数据截止日期

2. **时效性判断**：
   ```
   计算 FRED 最新数据日期 与 今天 的间隔:
   - 间隔 ≤ 7 天 → "实时验证模式"：板块 ETF 涨跌反映的是市场对实际数据的反应
   - 间隔 > 7 天 → "预期验证模式"：板块 ETF 涨跌反映的是市场对下次发布的预期
   在报告中明确标注当前是哪种模式。
   ```

3. **媒体共识**：Claude 从 title + content 提取主流解读和分歧观点

4. **板块验证**：
   - 对比理论影响映射 vs ETF 实际涨跌
   - 标注不一致项
   - 在"预期验证模式"下，不一致不一定代表映射错误，可能是市场在交易其他因素

### Step 4: 输出报告

```
## 🌐 宏观数据影响分析 — [Indicator Name]

### 最新数据（数据来源: fred_get_series）
| 指标 | 最新值 | 数据日期 | 前值 | 变化 | 趋势 |
|------|--------|---------|------|------|------|
| [name] | X.XX | YYYY-MM | X.XX | +X.XX | ↑上行 |

12期趋势: [简要描述]
（如有 null 值: "注意: [月份] 数据缺失，已跳过"）

### 验证模式: [实时验证 / 预期验证]
[如果是实时验证]: 数据发布于 X 天前，板块表现反映市场对实际数据的反应
[如果是预期验证]: 距上次数据发布已 X 天，板块表现反映市场对下次发布的预期

### 📰 媒体解读 (N篇相关报道)
主流观点: [一句话总结]
Claude 情绪判断: [偏鸽/偏鹰/中性]

代表性报道:
- "[标题]" — [来源] → [source_url]
- "[标题]" — [来源] → [source_url]

### 📊 板块影响（数据来源: stable_request batch-quote-short）
| 方向 | 板块 | ETF | 当前价格 | 当日涨跌 | 理论一致性 |
|------|------|-----|---------|----------|-----------|
| 利好 | Energy | XLE | $XX | +$X.XX | ✅ 一致 |
| 利空 | Tech | XLK | $XX | -$X.XX | ⚠️ 不一致 |

### 🔍 投资启示
[综合判断]
[不一致信号解释]
[下一个关键数据发布日期提醒]
```

## 注意事项

- **大部分 FMP 工具已可直接调用**；`profile`、`analyst_estimates`、`stock_price_change` 仍需通过 `finance_tool_stable_request`（schema 未修复）
- **ETF 批量报价用 `finance_tool_batch_quote_short`**（symbols 逗号分隔）
- **VIX 用 `finance_tool_quote`** symbol="^VIX"
- **商品报价用 `finance_tool_quote`** symbol="BZUSD"
- **`fred_get_series` 的 limit 必须传 integer**（如 `12`），不能传 string
- **FRED 数据可能有 null 值**，必须跳过处理，取最近非 null 值
- **FRED 可能间歇性返回 500 错误**，降级方案：用 `finance_tool_stable_request` path=`economic-indicators` 获取替代数据
- **`search_finance_news` 不支持复合关键词**，每个概念单独搜索
- **`search_finance_news` 的 users 参数必须为 array 类型**
