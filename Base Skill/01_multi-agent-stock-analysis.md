---
name: Multi-Agent Stock Analysis
description: 多Agent美股深度分析 — 19位虚拟分析师（8位传奇投资者+5位现代大师+6位量化分析师）独立打分，风控经理约束仓位，组合经理LLM综合决策。对标ai-hedge-fund架构。必须指定具体美股代码，如"帮我全面分析AAPL"、"多维度看TSLA"、"NVDA值不值得买"。
trigger: 多维度分析、多角度分析、全面分析、深度分析、值不值得买、能不能买、该不该买、综合分析、multi-agent分析、AI分析、投资分析、全方位分析、帮我分析一下XX、XX怎么样、XX能买吗、multi-agent analysis、full analysis、comprehensive analysis、should I buy、deep dive、stock analysis、investment analysis
not_trigger: 策略信号、KOL、喊单、热点、日报、背离扫描、财报速查、宏观指标、BTC宏观、黄金宏观、strategy、KOL calls、trending、daily brief、divergence、earnings report、macro、morning brief
mcp: mcp__followin__metrics, mcp__followin__news, mcp__followin__signal
args: ticker
---

# /multi-agent-stock-analysis $ARGUMENTS

多 Agent 美股深度分析 — 19 位分析师独立研判 + 风控 + 组合 = **21 Agents**（Followin MCP 版）

**适用范围**：只做美股。用户给的是公司名就先换成代码；给的是加密代币或非美股，说明本 Skill 不覆盖，不要硬跑。

## 架构

```
                    数据采集层 (Step 1-2)
              基本面 + 历史 + 技术 + 信号 + 研报 + 新闻 + 宏观
                                  │
    ┌─────────────────────────────┼─────────────────────────────┐
    │  Group A: 传奇投资者 (8)     │  Group B: 现代大师 (5)        │
    │  ① Buffett ② Graham         │  ⑨ Damodaran ⑩ Druckenmiller │
    │  ③ Munger  ④ Burry          │  ⑪ Taleb     ⑫ Pabrai        │
    │  ⑤ Ackman  ⑥ Wood           │  ⑬ Jhunjhunwala              │
    │  ⑦ Lynch   ⑧ Fisher         │                              │
    ├─────────────────────────────┼──────────────────────────────┤
    │  Group C: 量化分析师 (6)                                     │
    │  ⑭ Valuation ⑮ Fundamentals ⑯ Technicals                  │
    │  ⑰ Sentiment ⑱ News        ⑲ Growth                       │
    └─────────────────────────────┼──────────────────────────────┘
                  19 路 signal + confidence + reasoning
                                  │
                          ⑳ 风控经理 → ㉑ 组合经理（LLM 综合决策）
```

> 🔗 **19 位分析师、风控经理、组合经理的完整框架**在 `~/.claude/references/01_agent-prompts.md`（仓库内 `references/01_agent-prompts.md`）。**执行 Step 3 前必须先 Read 该文件**，不要凭分析师的名字现编评分框架。
> 🔗 **通用调用红线 + 已知问题登记**：`~/.claude/references/followin-mcp-caveats.md`。本文的调用写法和字段名于 **2026-10-01 逐条实测**；与登记表或 agent-prompts 里的旧工具名冲突时，以本文为准。

## 调用约定（2026-10-01 实测）

`metrics` / `signal` 的入参分工是：**`keywords` 数组放标的，`query` 放意图词，`categories` 指定数据类别**。

- **意图词用中文**。英文指标名写进 query 会被当成 ticker（实测 `"NVDA RSI 14"` 多带回一只代码为 RSI 的股票）。
- 所有 `metrics` / `signal` 调用带 `asset_type="tradfi"`。
- 每次调用后读 `meta.warnings`；`default_fanout_fallback` 是提示不是错误，不要因它重试。
- `signal()` **必须显式传 `categories`**——只传 ticker 返回空。
- 如果客户端不接受数组入参（报 `-32602`），把 ticker 并进 query 串（`query="<T> 分析师评级 同行 DCF"`）。
- 非交易时段，行情快照是上一个常规收盘（`_quote_session:"regular_inactive"`），不是盘后价；标"常规收盘"。

## 执行步骤

### Step 1: 数据采集（4 批，每批 ≤4 路并行，共 15 路）

**Batch A：基本面 + 历史**
```
1. metrics(keywords=["<T>"], asset_type="tradfi")
   → market.snapshot（price / change / previousClose / marketCap / yearHigh/Low）
   → fundamentals.concise[]：fiscal_quarters（最新一季的 earnings_surprise + financial_statement）、
     eps_trend（4 季）、balance_sheet（4 季）、cash_flow（4 季）、profile_block（sector / industry / beta）、
     valuation_block.ratios_ttm、consensus_price、next_earnings_estimate
2. metrics(keywords=["<T>"], query="财报 利润表", categories=["fundamentals"], asset_type="tradfi", limit=4)
   → income_statement（4 季：revenue / grossProfit / operatingIncome / netIncome / R&D / eps）
3. metrics(keywords=["<T>"], query="分析师评级 同行 DCF", asset_type="tradfi", limit=20)
   → analyst_grades、analyst_estimates（未来各财年 EPS / 营收预期）、stock_peers、
     valuation_block.dcf / key_metrics_ttm（ROE / ROIC / EV/EBITDA / FCF yield）/ enterprise_values
4. metrics(keywords=["<T>"], query="历史走势", asset_type="tradfi", time_range="1y", limit=260)
   → 一年日线（必须传 limit=260，默认只返回 10 条）
```

**Batch B：技术指标 + 信号**
```
5. metrics(keywords=["<T>"], query="均线 指标", asset_type="tradfi", limit=1)              → RSI(14)、ADX(14)
6. metrics(keywords=["<T>"], query="均线 指标", asset_type="tradfi", period=50,  limit=1)  → EMA50 / SMA50
7. metrics(keywords=["<T>"], query="均线 指标", asset_type="tradfi", period=200, limit=1)  → SMA200
8. signal(keywords=["<T>"], categories=["insider_trading","institutional","kol_call"],
          asset_type="tradfi", limit=20)                                                   → 三类合计 1 次额度
```
每次技术指标调用都返回全部 9 个指标，按 `indicator` 字段取需要的那个。`period` 参数对 9 个指标同时生效，所以 RSI(14) 取自不传 `period` 的第 5 路。

**Batch C：研报 + 新闻**
```
9.  metrics(keywords=["<T>"], query="research reports", categories=["fundamentals"],
            asset_type="tradfi", time_range="7d", verbosity="detail")       → subject_reports + mention_reports
10. news(query="<CompanyName> <TICKER>", sources=["media"],   asset_type="tradfi", time_range="1m", limit=10, sort_by="relevance")
11. news(query="<CompanyName> <TICKER>", sources=["twitter"], time_range="1w", limit=10)
12. news(query="<CompanyName> <TICKER>", sources=["research"], time_range="2w", limit=10)
```

**Batch D：宏观**
```
13. metrics(keywords=["^VIX"], query="行情", asset_type="tradfi")
14. metrics(keywords=["DGS10"], categories=["macro"], limit=22)
15. metrics(keywords=["<T>"], query="revenue growth 营收增长率", categories=["fundamentals"], asset_type="tradfi", limit=4)
    → financial_growth（最近 4 个**财年**的年度同比：revenueGrowth / netIncomeGrowth / epsgrowth / grossProfitGrowth /
      operatingIncomeGrowth / freeCashFlowGrowth，另有 fiveYRevenueGrowthPerShare 等五年累计值）
    ⚠️ 必须单独调：把"增长率"并进第 2 路的 query，income_statement 会被挤掉（2026-10-01 实测）
```

取数注意：
- `news()` 查不到相关内容时不返回空，而是返回一批不相关的热门内容。返回里一条都不含目标公司名或代码就是没查到，该路记数据缺口，不要拿这些内容做情绪判断，也不要重试。
- 13F 的环比字段在申报季中期不完整，只引用持仓绝对值和结构。
- KOL 喊单先按 `symbol == <T>` 筛行（返回里会混入别的标的的帖子），再按 `source_url` 去重。喊单只覆盖最近 24 小时。
- 研报的 `subject_reports` 为空、只有 `mention_reports` 时，不能说"有机构专题覆盖"。

### Step 2: 数据预处理

```
涨跌幅 = snapshot.change ÷ snapshot.previousClose × 100      （change 是美元变动量，不是百分比）

多周期涨跌（用日线收盘）:
  1D / 5D / 1M / 3M / 6M / 1Y = 最新收盘 ÷ 1 / 5 / 21 / 63 / 126 / 252 个交易日前的收盘 − 1
  YTD = 最新收盘 ÷ 今年第一个交易日的收盘 − 1

年化波动率、最大回撤（风控经理要用）:
  有代码执行工具就用它对 260 条日线算；没有就用最近 60 条的 changePercent 估算，并标"估算值"
```

### 数据可得性对照（先看这张表，再让分析师开工）

`01_agent-prompts.md` 里各分析师"关注数据"是按理想情况写的，其中一部分接口**拿不到**。拿不到的项，该分析师必须写"数据不足"并相应调低置信度，**不许凭记忆补数字**。

| 分析师框架里要的 | 实际可得 |
|---|---|
| 三表 5 年、利润率 5 年趋势 | ❌ 三表只有最近 **4 个季度**（把 limit 调大、query 写"年度"也一样）。利润率只能看季度环比和 TTM 比率 |
| Revenue 3 年 / 5 年 CAGR | ✅ 第 15 路 `financial_growth`：用最近 3 个财年的 `revenueGrowth` 连乘开方得 3 年 CAGR；5 年看 `fiveYRevenueGrowthPerShare`（**每股口径的五年累计增幅**，不是年化，引用时写明）|
| 最近 4 季度 Beat 率 | ❌ 只有**最新一季**的实际对预期 |
| 同比增速 | ⚠️ **年度**同比有（第 15 路 `financial_growth`，4 个财年）；**季度**同比没有——4 季窗口里没有去年同期 |
| DCF | ✅ `valuation_block.dcf`。与现价相差 5 倍以上判失效，不进任何输出（亏损期 DCF 会算崩）|
| ROE / ROIC / EV/EBITDA / PE / PEG / 毛利率 / D/E / 流动比率 | ✅ `key_metrics_ttm` + `ratios_ttm` |
| 分析师远期预期、Forward PE | ✅ `analyst_estimates`（现价 ÷ 下一财年 epsAvg）|
| 行业相对估值 | ⚠️ 只有 `stock_peers` 的名单和市值，没有同行的估值倍数；需要就对前 3 家同行再各调一次第 1 路 |
| Beta、行业、公司简介 | ✅ `profile_block` |
| 内部人交易、13F、KOL、研报、新闻 | ✅ 见 Batch B / C |
| RSI / EMA50 / SMA50 / SMA200 | ✅ 见 Batch B |

**两个 EPS 口径不同**：`earnings_surprise.actual_eps` 是分析师口径（通常是调整后），`financial_statement.eps` 是财报口径（GAAP），实测同一季可以差 10% 以上。引用"超预期"时注明是分析师口径；两者符号相反时必须点明"GAAP 为亏损"。`actual_revenue` 为 null 时 `revenue_surprise_pct` 会显示 -100，那是缺数据。

### Step 3: 19 位分析师独立研判

先 Read `01_agent-prompts.md`。每位分析师按自己的哲学和关注的数据子集，**独立**给出：
- **信号**: Bullish / Bearish / Neutral
- **置信度**: 0-100
- **核心理由**: 2-3 条，每条都要引用 Step 1 取到的具体数字

"独立"的意思是：写某位分析师的结论时，只用他框架里列的数据，不参考其他分析师已经得出的方向。关键数据不足的分析师给 Neutral + 低置信度，并写明缺什么。

### Step 4: ⑳ 风控经理

按 `01_agent-prompts.md` 的"风控经理"一节执行（波动率调整法算仓位上限，含上下限和 VIX 减半规则）。输出风险等级 + 仓位上限 + 2-3 条风险提示。不输出方向。

### Step 5: ㉑ 组合经理

按 `01_agent-prompts.md` 的"组合经理"一节执行：不是简单数票，而是看信号质量、一致性和矛盾点，并自动打上该节列出的分歧标签。输出：
- **模拟决策**: Buy / Hold / Sell（及强弱）
- **模拟仓位**: 不超过风控上限
- **持有周期**: 短线（<1 月）/ 中线（1-6 月）/ 长线（>1 年）
- **置信度**: 0-100
- **关键观察点**: 3-5 个会改变结论的事件或数据

**数据覆盖闸**：Batch A 的第 1 路没取到（基本面和快照都没有），或者 19 位分析师里有 7 位以上因数据不足给了 Neutral，就**不输出模拟决策**，改为说明数据覆盖不足并列出缺口。

## 输出格式

```
## 🎯 [TICKER] 多 Agent 综合分析 — [CompanyName]

> 以下是 19 个模拟分析框架对公开数据的研判汇总，用于梳理多空论据，不构成投资建议。

### 基本信息
行业: [sector] / [industry] | 市值: $[marketCap] | 价格: $[price]（[自算涨跌%]，[实时 / 常规收盘]）| Beta: [beta]

### 📊 19 位分析师投票分布
| Agent | 信号 | 置信度 | 核心理由 |
|---|---|---|---|
| ① Buffett | 🟢 Bullish | 85 | [引用具体数字的理由] |
| ② Graham | 🟡 Neutral | 60 | ... |
| ... | ... | ... | ... |
| ⑲ Growth | 🟢 Bullish | 90 | ... |

**汇总**: 🟢 Bullish: X / 🟡 Neutral: X / 🔴 Bearish: X
**分歧标签**: [组合经理一节定义的标签，命中几个列几个]

### ⑳ 风控经理评估
- 风险等级: Low / Medium / High
- 仓位上限: **X%**（年化波动率 XX%[，估算值]；VIX XX）
- 主要风险: [2-3 条]

### ㉑ 组合经理模拟决策
**决策**: [Strong Buy / Buy / Hold / Sell / Strong Sell]
**模拟仓位**: X%（上限 Y%）
**持有周期**: [短线 / 中线 / 长线]
**置信度**: XX

**核心逻辑**:
[3-5 句：财务、估值、技术、情绪、宏观各自指向哪里，怎么权衡的]

**关键观察点**（会改变结论的事件）:
1. [事件 + 日期 + 触发逻辑]
2. ...

### 数据缺口
- [没取到的数据、因数据不足而降低置信度的分析师；没有就写"无"]
```

## 输出约束

- 每位分析师的理由必须引用本次取到的具体数字；拿不到的写"数据不足"，不凭记忆补
- 多空票数最多的一方不到 19 票的 60% 时，在汇总行标"分歧显著"
- 决策是**模拟结论**：开头的声明行必须保留；不给具体目标价，不承诺收益
- 触发了"数据覆盖闸"就不出模拟决策
