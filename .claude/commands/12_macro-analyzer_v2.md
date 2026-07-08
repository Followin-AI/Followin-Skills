---
name: Macro Analyzer (v2 — Followin MCP)
description: 宏观数据影响分析 — 从指标变动到板块影响的全链路。必须同时包含"指标名"+"影响/解读/分析"才触发，如"CPI出来了对市场有什么影响"、"非农解读"、"利率影响哪些板块"。纯数据查询（"CPI是多少"）走情报中心，综合日报走morning-brief，BTC/黄金宏观走各自看盘Skill。
trigger: 宏观指标影响、宏观指标解读、宏观指标分析、宏观数据影响、宏观数据解读、宏观数据分析、CPI影响、CPI解读、CPI分析、非农影响、非农解读、非农分析、利率影响、利率解读、GDP影响、GDP解读、关税影响、关税分析、macro impact、macro analysis、CPI impact、NFP impact、rate impact、GDP impact、tariff impact、indicator analysis
not_trigger: 策略信号、KOL、喊单、热点、日报、BTC宏观、黄金宏观、财报、earnings、宏观日报、宏观早报、美股早报、CPI是多少、利率是多少、strategy、KOL calls、trending、daily brief、BTC macro、gold macro、earnings report、macro morning brief
mcp: mcp__followin__metrics, mcp__followin__news
args: indicator
---

# /macro-analyzer-v2 $ARGUMENTS

宏观数据影响分析 — 从指标变动到板块影响的全链路（Followin MCP 版）

## 参数

| 参数 | 必填 | 说明 |
|------|------|------|
| indicator | 是 | 宏观指标名或关键词，如 CPI、NFP、Fed Rate、GDP |

## 意图路由

| 用户说的 | 走哪个Skill |
|---------|-----------|
| CPI影响、非农解读、利率影响、GDP影响、宏观数据分析 | ✅ 本Skill |
| 宏观日报、宏观早报、美股早报 | ❌ 转 morning-brief |
| XX财报、XX earnings | ❌ 转 earnings-report |
| 背离扫描、异常信号 | ❌ 转 divergence-scan |
| BTC宏观、宏观看盘 | ❌ 转 08_BTC宏观看盘 |
| 黄金宏观 | ❌ 转 09_黄金监控看盘 |

本Skill 聚焦**单个宏观指标发布后的影响分析**（指标→板块→个股的全链路）。

> 🔗 **通用调用红线 + 已知问题登记**：以 `~/.claude/references/followin-mcp-caveats.md` 为准（仓库内 `.claude/references/`）。本文内联 caveat 是其镜像，冲突时以该文件为准。

## 数据层 — Followin MCP 三工具映射

| 用途 | 调用 | 参数 |
|------|------|------|
| FRED 指标历史数据 | `metrics()` | `keywords=["CPIAUCSL"]`（先查 Step 1 翻译表转 series_id 再 keywords 直查）, `categories=["macro"]`, `limit=12` |
| ETF 板块批量报价 | `metrics()` | `keywords=["XLE","XLB","XLK"]`, `categories=["market"]` |
| VIX / 商品 / 国债收益率 | `metrics()` | `keywords=["^VIX"]` 或 `keywords=["GCUSD"]`（⚠️ 不要用 GOLD，会错抓 Gold.com 美股）|
| 媒体解读 | `news()` | `query="CPI inflation"`, `time_range="1w"`（⚠️ 不写"影响/解读"等元词，见 query 三原则）|

> **关键变化（vs v1）**：
> - 删除 21 个 series_id 别名表 — Followin 自动识别中英文（"CPI"/"核心CPI"/"非农"/"NFP" 全 ✅）
> - 删除 31 家媒体 users 列表 — `news()` 自动检索全源
> - 删除 stable_request 兜底逻辑 — Followin 单端点稳定
> - 4 个工具 → 2 个工具

## 指标 → 板块影响映射（业务逻辑，保留）

```json
{
  "CPI": {
    "name": "CPI (消费者物价指数)",
    "bullish_sectors": ["Energy", "Materials", "Real Estate"],
    "bearish_sectors": ["Technology", "Consumer Discretionary"],
    "key_etfs": ["XLE", "XLB", "XLK", "XLY", "XLRE", "TIP"],
    "interpretation": "CPI 高于预期 → 加息预期升温 → 成长股承压，通胀受益股偏强"
  },
  "Core CPI": {
    "name": "核心 CPI",
    "bullish_sectors": ["Energy", "Real Estate"],
    "bearish_sectors": ["Technology", "Consumer Discretionary"],
    "key_etfs": ["XLE", "XLK", "XLY", "XLRE", "TIP"],
    "interpretation": "核心 CPI 反映持续性通胀压力，对 Fed 决策影响最直接"
  },
  "PCE": {
    "name": "PCE 物价指数（Fed 首选通胀指标）",
    "bullish_sectors": ["Energy", "Real Estate"],
    "bearish_sectors": ["Technology", "Consumer Discretionary"],
    "key_etfs": ["XLE", "XLK", "XLY", "XLRE", "TIP"]
  },
  "NFP": {
    "name": "Non-Farm Payrolls",
    "bullish_sectors": ["Consumer Discretionary", "Financials"],
    "bearish_sectors": ["Utilities", "Real Estate"],
    "key_etfs": ["XLY", "XLF", "XLU", "XLRE"],
    "interpretation": "强就业 → 经济强劲 → 周期股受益，但加息预期也升温"
  },
  "Fed Rate": {
    "name": "Federal Funds Rate",
    "bullish_sectors": ["Financials"],
    "bearish_sectors": ["Real Estate", "Utilities", "Technology"],
    "key_etfs": ["XLF", "XLRE", "XLU", "XLK"],
    "interpretation": "加息 → 银行净息差扩大受益，高估值成长股承压"
  },
  "10Y Treasury": {
    "name": "10-Year Treasury Yield",
    "bullish_sectors": ["Financials"],
    "bearish_sectors": ["Technology", "Real Estate", "Utilities"],
    "key_etfs": ["XLF", "XLK", "XLRE", "XLU", "TLT"],
    "interpretation": "10Y上行 → 贴现率上升 → 成长股估值承压，金融股受益"
  },
  "Oil": {
    "name": "WTI Crude Oil",
    "bullish_sectors": ["Energy"],
    "bearish_sectors": ["Airlines", "Transportation"],
    "key_etfs": ["XLE", "JETS", "XLI", "USO"],
    "interpretation": "油价上涨 → 能源股直接受益，运输成本上升"
  },
  "Unemployment": {
    "name": "Unemployment Rate",
    "bullish_sectors": ["Consumer Staples", "Utilities"],
    "bearish_sectors": ["Consumer Discretionary", "Financials"],
    "key_etfs": ["XLP", "XLU", "XLY", "XLF"]
  },
  "GDP": {
    "name": "Real GDP",
    "bullish_sectors": ["Industrials", "Consumer Discretionary", "Financials"],
    "bearish_sectors": ["Utilities"],
    "key_etfs": ["SPY", "QQQ", "IWM", "XLU", "XLI"]
  },
  "Initial Claims": {
    "name": "初请失业金（高频劳动力指标）",
    "bullish_sectors": ["Consumer Discretionary"],
    "bearish_sectors": ["Consumer Staples", "Utilities"],
    "key_etfs": ["XLY", "XLP", "XLU"]
  },
  "Retail Sales": {
    "name": "零售销售",
    "bullish_sectors": ["Consumer Discretionary"],
    "bearish_sectors": ["Consumer Staples"],
    "key_etfs": ["XLY", "XLP", "XRT"]
  }
}
```

## 执行步骤

### Step 1: 解析指标 + 加载映射

> 🔒 **v3 修复**（实测验证）：query 路径有 4 类语义陷阱（含 series_id 也被错抓 / 中文混淆 / degraded / 静默兜底）。**必须**先把用户输入翻译为 FRED series_id 再走 keywords 直查。

#### 中文/英文 → FRED series_id 翻译表（高频指标）

| 用户可能说 | series_id |
|---|---|
| CPI / 通胀 / 消费者价格指数 | `CPIAUCSL` |
| 核心 CPI / Core CPI | `CPILFESL` |
| PCE / 个人消费支出物价 | `PCEPILFE` |
| 失业率 / Unemployment | `UNRATE` |
| 非农 / NFP / 就业人数 | `PAYEMS` |
| 联邦基金利率 / Fed Funds | `FEDFUNDS` |
| 10 年期国债收益率 / 10Y / DGS10 | `DGS10` |
| 2 年期国债 / DGS2 | `DGS2` |
| 30 年期国债 | `DGS30` |
| 30 年抵押贷款利率 (mortgage) | `MORTGAGE30US` ⚠️ 不是 DGS30 |
| 10Y TIPS 实际利率 | `DFII10` |
| 通胀预期 / 10Y BEI | `T10YIE` |
| 10Y-2Y 利差 / 收益率曲线 | `T10Y2Y` |
| M2 货币供应 | `M2SL` |
| Fed 资产负债表 / WALCL | `WALCL` |
| 财政部 TGA | `WTREGEN` |
| 隔夜逆回购 / RRP | `RRPONTSYD` |
| 高收益债利差 / 信用利差 | `BAMLH0A0HYM2` |
| 零售销售 / Retail Sales | `RSAFS` |
| WTI 原油 | `CLUSD` (categories="market", asset_type="tradfi") |
| 黄金期货 | `GCUSD` (不是 GOLD，GOLD 会错抓 Gold.com 美股) |

字典未命中再走 query 兜底。

### Step 2: 三路并行

**第一路：FRED 指标趋势**
```
metrics(
  keywords=[<series_id 从翻译表查到>],
  categories=["macro"],
  limit=12
)

返回: 12 期 series_id / value / date
判断 status:ok 或 partial
```

⚠️ 字典 miss 时才回退 `query=<用户原始输入>` 并人工 review 是否命中正确 series_id。

**第二路：ETF 板块批量报价**
```
metrics(
  keywords=[映射表查到的 key_etfs],
  categories=["market"]
)

返回: 每个 ETF 的 price / change / changePercentage / volume
```

**第三路：媒体报道**
```
news(
  query="[指标核心词 2-3 个]",          # 纯英文或纯中文，不混搭
  time_range="1w",
  limit=10
  # news 无 sort_by（相关性走 search_depth，默认 standard）
)

例:
  CPI       → query="CPI inflation"           （双英文核心词，避免被 PMTS 等公司劫持）
  非农       → query="nonfarm payrolls"
  Fed Rate  → query="Fed rate cut"
  GDP       → query="GDP growth"
  零售销售   → query="retail sales"

返回: 媒体文章含 title / content / published_ts / source_name
LLM 读原文做解读，不要把"解读/影响/分析"塞进 query
```

### Step 3: 影响分析

1. **数据解读**：最新值 vs 前值（跳过 null），12 期趋势方向，标注数据日期
2. **时效性判断**：
   - FRED 最新数据日期 与今天的间隔 ≤ 7 天 → "实时验证模式"（板块涨跌反映实际数据反应）
   - 间隔 > 7 天 → "预期验证模式"（反映对下次发布的预期）
3. **媒体共识**：从 news() 返回的 title + content 提取主流解读和分歧
4. **板块验证**：
   - 对比理论影响映射 vs ETF 实际涨跌
   - 标注不一致项
   - 预期模式下，不一致不一定代表映射错误

### Step 4: 输出报告

```
## 🌐 宏观数据影响分析 — [Indicator]

### 最新数据（来源: Followin metrics → FRED）
| 指标 | 最新值 | 数据日期 | 前值 | 变化 | 趋势 |
|------|--------|---------|------|------|------|
| [name] | X.XX | YYYY-MM | X.XX | +X.XX | ↑上行 |

12 期趋势: [简要描述]

### 验证模式: [实时验证 / 预期验证]
[对应说明]

### 📰 媒体解读 (N 篇相关报道)
主流观点: [一句话总结]
情绪判断: [偏鸽/偏鹰/中性]

代表性报道:
- "[标题]" — [来源]
- "[标题]" — [来源]

### 📊 板块影响（来源: Followin metrics → ETF 报价）
| 方向 | 板块 | ETF | 当前价 | 当日涨跌% | 理论一致性 |
|------|------|-----|--------|----------|-----------|
| 利好 | Energy | XLE | $XX | +X.XX% | ✅ 一致 |
| 利空 | Tech | XLK | $XX | -X.XX% | ⚠️ 不一致 |

### 🔍 投资启示
[综合判断]
[不一致信号解释]
[下一个关键数据发布日期提醒]
```

## 注意事项（v2 — Followin MCP）

- **`metrics()` 自动 alias**：CPI/核心CPI/PCE/非农/NFP/失业率/GDP/Fed Rate/10Y国债/2Y国债/原油/WTI/M2/PMI 等中英文混用都能命中
- **`metrics()` macro path** 已 100% 命中（32/32 FRED series 验证）
- **status:partial** 是历史遗留（market 子路由 warning），数据本身仍可用 — 看 `categories_used` 是否含 "macro" 即可
- **`news()` 自动多源**：覆盖 newsapi / rss / Twitter / TG / 媒体专栏，不用列 user list
- **`news()` query 设计三原则**（实测验证）：
  1. **2-3 个核心名词**，不要超过 4 词
  2. **纯中文 or 纯英文**，避免混搭
  3. **不写"影响 / 解读 / 分析 / impact / interpretation"** — 这些是 LLM 干的活，写进 query 反而 0 results（embedding 过拟合）
  4. **避免单纯股票符号**（`"CPI"` 会被 CPI Card PMTS 公司劫持，要双词 `"CPI inflation"` 消歧）
- **time_range** 选 `"1w"`（覆盖周内主流报道），`"1d"` 太窄 `"1m"` 太宽
- **避免高并发**：单次 ≤ 4 个 MCP 调用并发，否则 SSE session 可能挂
- **特殊行情符号**：VIX 写 `^VIX`；黄金必须 `GCUSD`（⚠️ GOLD 会错抓 Gold.com 美股 $42，不要依赖 alias）；白银 `SIUSD`；原油 `CLUSD`（WTI）/ `BZUSD`（布油），**不要用 OIL alias**（未修，会错路由）
