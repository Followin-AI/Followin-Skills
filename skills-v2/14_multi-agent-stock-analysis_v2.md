---
name: Multi-Agent Stock Analysis (v2 — Followin MCP)
description: 多Agent美股深度分析 — 19位虚拟分析师（8位传奇投资者+5位现代大师+6位量化分析师）独立打分，风控经理约束仓位，组合经理LLM综合决策。对标ai-hedge-fund架构。必须指定具体股票代码，如"帮我全面分析AAPL"、"多维度看TSLA"、"NVDA值不值得买"。
trigger: 多维度分析、多角度分析、全面分析、深度分析、值不值得买、能不能买、该不该买、综合分析、multi-agent分析、AI分析、投资分析、全方位分析、帮我分析一下XX、XX怎么样、XX能买吗、multi-agent analysis、full analysis、comprehensive analysis、should I buy、deep dive、stock analysis、investment analysis
not_trigger: 策略信号、KOL、喊单、热点、日报、背离扫描、财报速查、宏观指标、BTC宏观、黄金宏观、strategy、KOL calls、trending、daily brief、divergence、earnings report、macro、morning brief
mcp: mcp__followin__metrics, mcp__followin__news, mcp__followin__signal
args: ticker
---

# /multi-agent-stock-analysis-v2 $ARGUMENTS

多 Agent 美股深度分析 — 19 位分析师独立研判 + 风控 + 组合 = **21 Agents**（Followin MCP 版）

## 架构（保留 v1）

```
                    数据采集层 (Step 1-2)
                  comprehensive + 历史 + 技术 + insider + news + 宏观
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

## 数据层 — Followin MCP 三工具（22 → 5-6 路）

🔒 所有美股调用必须带 `asset_type="tradfi"`（除 BTC/ETH 等 crypto symbol）

| v1 老调用 | v2 替代 |
|---|---|
| profile / income / balance / cashflow / ratios / key_metrics / enterprise / financial_growth / earnings / analyst_estimates / DCF / peers / grades / shares_float | **`metrics(keywords=[T], categories=["fundamentals"], asset_type="tradfi")`** 一次返 **12 个 block**（comprehensive 已修复）|
| historical_price + EMA + SMA + RSI | `metrics(keywords=[T], time_range="1y", interval="1day")` + `metrics(query="RSI 14")` |
| stock-price-change / quote | `metrics(keywords=[T], categories=["market"])` 含 priceAvg50/200 |
| insider_trading_latest | `signal(categories=["insider_trading"], keywords=[T])` 含 corporate + senate + house |
| price-target-consensus | 已含在 fundamentals 的 `consensus_price` block |
| search_finance_news | `news(query="<companyName> <ticker>", time_range="1m", limit=10)` |
| FRED VIX / DGS10 | `metrics(keywords=["^VIX","DGS10"])` |

> **关键变化（vs v1）**：
> - 22 个老调用 → 6 个 Followin 调用（**-73%**）
> - 删除 31 家媒体 users / schema 修复 caveat / FRED limit integer 等
> - **insider 自动 fanout 政客**（v2 新增维度，影响 Group A 的 Burry / Group C 的 Sentiment）

## 执行步骤

### Step 1: 数据采集（分批次 fan-out，每批 ≤ 4 防 SSE 挂）

⚠️ **SSE 高并发限制**：实测单批 20 路并发会挂，必须分 2-3 批：

**Batch A：fundamentals 真聚合 + 行情（3 路并行，比 v1 节省更多）**
```
1. metrics(keywords=[T], categories=["fundamentals"], asset_type="tradfi")
   → ✅ 一次返 12 个 block（comprehensive 已真聚合）：
      income / balance / cashflow / valuation / profile / peers / grades / shares_float
      + beat_miss / consensus / eps_trend / latest_quarter / next_earnings
2. metrics(keywords=[T], categories=["market"], asset_type="tradfi")
   → 当前 price + change + priceAvg50/200 + yearHigh/Low
3. metrics(keywords=[T], time_range="1y", interval="1day", asset_type="tradfi", limit=252)
   → 252 交易日历史，用于多周期涨跌 + 自算 RSI/EMA
```

**Batch B：信号 + 新闻 + 宏观（3 路并行）**
```
4. signal(categories=["insider_trading"], keywords=[T], asset_type="tradfi", limit=20)
   → corporate Form 4 + senate + house 三类聚合
5. news(query="<companyName> <ticker>", time_range="1m", limit=10)
   → 不带 asset_type（实测加 tradfi 返 0）
6. metrics(keywords=["^VIX","DGS10"], asset_type="tradfi")
   → VIX 恐慌 + 10Y 利率（宏观背景）
```

**总计 6 路调用** — 比 v1 的 22 路节省 **-73%**。

### Step 2: 数据预处理

从 252 日历史价格自算多周期：
```
1D = (今日 - 昨日) / 昨日
5D = ...
1M = (今日 - 21 日前) / 21 日前
3M = (今日 - 63 日前) / 63 日前
6M / YTD / 1Y 同理

RSI(14) = 标准 RSI 公式
EMA(50) = 50 日指数移动平均
SMA(200) = 简单 200 日均线
```

### Step 3: 19 位分析师独立研判

每位分析师基于哲学和关注数据子集，**独立**输出：
- **信号**: Bullish / Bearish / Neutral
- **置信度**: 0-100
- **核心理由**: 2-3 条关键论据

> 19 个 Agent 的 prompt（哲学 + 关注数据 + 评分框架）**完全保留 v1**，详见原文件。每个 Agent 从同一数据池中按需取数。

### Step 4: ⑳ 风控经理（Risk Manager）

```
计算建议仓位上限:
- 基于 Beta（高 Beta = 仓位上限低）
- 基于波动率（年化波动 > 50% = 仓位上限低）
- 基于宏观风险（VIX > 25 / DGS10 > 4.5% = 仓位上限低）
- 基于流动性（mktCap < $5B = 仓位上限低）

输出:
- recommended_position_size_max: 0-15% (单股票仓位上限)
- risk_score: 1-10
- 风险提示: 2-3 条
```

### Step 5: ㉑ 组合经理（Portfolio Manager LLM 综合决策）

不用固定权重，让 LLM 综合 19 个 Agent 信号 + 风控约束 + 当前宏观环境，输出：
- **最终决策**: STRONG BUY / BUY / HOLD / SELL / STRONG SELL
- **建议仓位**: 0-15%（不超过风控上限）
- **持有周期**: 短线（< 1月）/ 中线（1-6月）/ 长线（> 1年）
- **关键观察点**: 3-5 个会改变决策的事件 / 数据
- **置信度**: 0-100

## 输出格式

```
## 🎯 [TICKER] 多 Agent 综合分析 — [CompanyName]

### 基本信息
行业: [sector] / [industry] | 市值: $[mktCap] | 当前价: $[price] ([change]%) | Beta: [beta]

### 📊 19 位分析师投票分布
| Agent | 信号 | 置信度 | 核心理由 |
|---|---|---|---|
| ① Buffett | 🟢 Bullish | 85 | 毛利率 75% / ROE 104% / 安全边际 +14% |
| ② Graham | 🟡 Neutral | 60 | PE 43.56 偏高，但 PEG 0.66 合理 |
| ... | ... | ... | ... |
| ⑲ Growth | 🟢 Bullish | 90 | 4Q EPS 翻倍 + 营收 +54% YoY |

**汇总**: 🟢 Bullish: X / 🟡 Neutral: X / 🔴 Bearish: X

### ⑳ 风控经理评估
- 仓位上限: **X%**
- Risk Score: X / 10
- 主要风险: [3 条]

### ㉑ 组合经理最终决策
**决策**: [STRONG BUY / BUY / HOLD / SELL / STRONG SELL]
**建议仓位**: X%（vs 上限 Y%）
**持有周期**: [短线 / 中线 / 长线]
**置信度**: XX

**核心逻辑**:
[3-5 句话综合判断，包括：财务 + 估值 + 技术 + 情绪 + 宏观如何融合]

**关键观察点**（会改变决策的事件）:
1. [事件 + 日期 + 触发逻辑]
2. ...

**风险提示**:
- [对冲建议 / 减仓信号 / 止损位]
```

## 注意事项（v2）

- 🔒 **`asset_type="tradfi"` 必须**（news 除外）
- ⚠️ **SSE 高并发限制**：单批 ≤ 4 路并行，2-3 批跑完
- ✅ **comprehensive 真聚合已修复** — 1 次返 12 个 block，无需单独调"利润表"
- ✅ **insider 已含 senate + house fanout**，Group C Sentiment 可用政客买入信号
- ✅ **historical_price 1y 用于多周期 + 技术指标自算**，不再依赖单独 RSI/EMA/SMA endpoint
- 19 个 Agent prompt **完全保留 v1**（业务逻辑核心，不在 MCP 层）

## v1 → v2 数据层简化对比

| 维度 | v1 | v2 | 节省 |
|---|---|---|---|
| MCP 调用次数 | 22 | **6** | **-73%** |
| 工具种类 | 18 个 finance_tool_* + search_news + fred | 3 个 Followin | **-83%** |
| schema caveat | 8 条 | 0 条 | -100% |
| 用户列表维护 | 31 家媒体 | 自动 | -100% |
| 政客交易 | 不可用 | ✅ 自动 fanout | +∞ |

## 业务逻辑不变（保留 v1 全部 Agent prompts）

19 个 Agent 的：
- 投资哲学描述
- 关注数据子集
- 评分框架（如 Buffett 护城河 / Graham NCAV / Wood 颠覆性创新）
- 信号阈值

详见原文件 14_multi-agent-stock-analysis.md 第 145-700 行。

## 输出约束

- 每个 Agent 信号必须有数据支撑
- 不喊单 / 不预测价格
- 矛盾度高时（>40% Agent 不一致）必须标注
- 数据缺失（如 comprehensive 聚合失败）降级用单 sub-intent 调用补充
