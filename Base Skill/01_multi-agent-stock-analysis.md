---
name: Multi-Agent Stock Analysis
description: 多Agent美股深度分析 — 19位虚拟分析师（8位传奇投资者+5位现代大师+6位量化分析师）独立打分，风控经理约束仓位，组合经理LLM综合决策。对标ai-hedge-fund架构。必须指定具体股票代码，如"帮我全面分析AAPL"、"多维度看TSLA"、"NVDA值不值得买"。
trigger: 多维度分析、多角度分析、全面分析、深度分析、值不值得买、能不能买、该不该买、综合分析、multi-agent分析、AI分析、投资分析、全方位分析、帮我分析一下XX、XX怎么样、XX能买吗、multi-agent analysis、full analysis、comprehensive analysis、should I buy、deep dive、stock analysis、investment analysis
not_trigger: 策略信号、KOL、喊单、热点、日报、背离扫描、财报速查、宏观指标、BTC宏观、黄金宏观、strategy、KOL calls、trending、daily brief、divergence、earnings report、macro、morning brief
mcp: mcp__followin__metrics, mcp__followin__news, mcp__followin__signal
args: ticker
---

# /multi-agent-stock-analysis $ARGUMENTS

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

> 🔗 **通用调用红线 + 已知问题登记**：以 `~/.claude/references/followin-mcp-caveats.md` 为准（仓库内 `references/`）。本文内联 caveat 是其镜像，冲突时以该文件为准。

## 数据层 — Followin MCP 三工具（11 路调用 / 3 批）

> 🔗 **官方路由 primer**（意图→工具映射、命名约定、尽调编排）见 `references/followin-routing-primer.md`。本 Skill 的调用序列已对齐官方「美股尽调」五项编排。

🔒 所有美股调用必须带 `asset_type="tradfi"`（除 BTC/ETH 等 crypto symbol）
🔒 **N-8（2026-08-04 实测仍复现）**：`keywords` / `categories` / `sources` 数组入参被 schema 拒，一律走 query 串（ticker/series_id 并入 query）；调用后核对 `meta.filters_applied.keywords` 差集

| 用途 | Followin 调用 |
|---|---|
| 基本面真聚合（profile / 三表 / 估值 / 评级 / shares_float / beat-miss / consensus / eps_trend / latest_quarter / next_earnings）| `metrics(query="<T> 全面分析", asset_type="tradfi")` 一次返 14 block（缺 stock_peers，输出"同行"标"数据不可用"）|
| 行情快照（price / change / volume / dayHigh/Low / yearHigh/Low / marketCap）| `metrics(query="<T> 行情", asset_type="tradfi")`（批量 ≤5 个，超出静默截断且无任何 warning——红线 4）|
| 历史 OHLCV（用于多周期涨跌 + 技术指标自算）| `metrics(query="<T> 历史走势", asset_type="tradfi", time_range="1y")` |
| 技术指标（RSI / EMA / SMA）| `metrics(query="<T> 相对强弱 指标", asset_type="tradfi")` 或 `query="<T> 均线 指标"` |
| **信号面 fanout**（内部人 Form 4 + senate + house，**外加 13F institutional + KOL 喊单**——省略 `categories` 一次拿三类，仍只计 1 额度，N-4）| `signal(query="<T>", asset_type="tradfi", limit=20)` |
| **机构研报**（目标价 / rating_action / thesis / key_caveat / latest_catalyst）| `metrics(query="<TICKER> research reports", asset_type="tradfi", verbosity="detail", time_range="7d")` ⚠️ warning 误报见 N-21 |
| 媒体覆盖 | `news(query="<companyName> <ticker>", time_range="1m", limit=10)` 读 `articles` 桶（sources 数组被拒无字符串替代 N-8；news 实返 2N 条 = articles + social 两桶 N-25）|
| 推特风向 | `news(query="<companyName> <ticker>", time_range="1w", limit=10)` 读 `social` 桶 |
| 宏观背景（VIX / 10Y）| `metrics(query="^VIX 行情", asset_type="tradfi")` + `metrics(query="DGS10", limit=5)` 两路分开（⚠️ 不要把 market ticker 和 FRED series 混批，红线 4/B-31；FRED query 只放纯 series_id，禁中文/混合语言）|

## 执行步骤

### Step 1: 数据采集（分批次 fan-out，每批 ≤ 4 防 SSE 挂）

⚠️ **SSE 高并发限制**：实测单批 20 路并发会挂，必须分 2-3 批：

**Batch A：fundamentals 真聚合 + 行情（4 路并行）**
```
1. metrics(query="<T> 全面分析", asset_type="tradfi")
   → ✅ 一次返 14 个 block（⚠️ query 必须含"全面分析"意图词才走 comprehensive，
      否则 default 只返 5 block；N-8：keywords/categories 数组被拒，ticker 并入 query 串）：
      income / balance / cashflow / financial_growth / valuation / profile / sec_filings
      / grades / shares_float + beat_miss / consensus / eps_trend / latest_quarter
      / next_earnings（❌ 缺 stock_peers，Dev 待修）
2. metrics(query="<T> 行情", asset_type="tradfi")
   → 当前 price + change + dayHigh/Low + yearHigh/Low + marketCap
   → ⚠️ change 是美元变动量不是百分比（N-47），百分比自算 change/previousClose×100
3. metrics(query="<T> 历史走势", asset_type="tradfi", time_range="1y")
   → 1y daily OHLCV，用于多周期涨跌（自算 1D/5D/1M/3M/6M/YTD/1Y）
4. metrics(query="<T> 相对强弱 指标", asset_type="tradfi", period=14)
   → ⚠️ 实测（2026-08-04, N-69）该调用**一次 fanout 返回全部 9 个指标**（adx/rsi/dema/wma/williams/ema/tema/sma/standarddeviation），按 `indicator` 字段筛即可，**不必为 RSI/EMA/SMA 分开调用**（省额度）。禁写英文指标名（"EMA 50"/"SMA 200" 会被劫持成同名 ticker）。
```

**Batch B：信号 + 研报 + 新闻（4 路并行）**
```
5. signal(query="<T>", asset_type="tradfi", limit=20)
   → ⚠️ 省略 categories 才 fanout：corporate Form 4 + senate + house
     + institutional(13F) + kol_call 三类一次拿全，仍只计 1 额度（N-4）
   → keywords/categories 数组被 schema 拒，一律 query 串路由（N-8/N-59f）
   → 13F 环比字段季内不可引用，只取绝对值与持仓结构（N-7）
   → kol_call 统计多空前按 source_url 去重（N-5）
6. metrics(query="<TICKER> research reports", asset_type="tradfi",
           verbosity="detail", time_range="7d")
   → subject_reports（专题）+ mention_reports（行业报告提及）两层
   → ⚠️ meta.warnings 会误报 default_fanout_fallback，以 payload 为准不要重试（N-21）
   → ⚠️ subject=0 只有 mention 时，不能当成"有机构专题覆盖"（N-19）
7. news(query="<companyName> <ticker>", time_range="1m", limit=10)
   → 不带 asset_type（实测加 tradfi 返 0）
   → sources 数组被 schema 拒且无字符串替代（N-8）；媒体覆盖读 articles 桶
     （news 实返 2N 条 = articles + social 两桶，N-25）
8. news(query="<companyName> <ticker>", time_range="1w", limit=10)
   → 推特风向读 social 桶，供 Sentiment 分析师使用
```

**Batch C：研报原文 + 宏观（3 路并行）**
```
9.  news(query="<companyName> <ticker>", time_range="2w", limit=10)
    → 官方尽调编排的 news(["research"]) 一环：研报来源的原始文章
    → sources=["research"] 数组被 schema 拒且无字符串替代（N-8/N-59）：研报类内容客户端近似识别
      ——articles 桶 source_quality=="research"（⚠️ Motley Fool 会混入）+ social 桶 kol_info.categories 含 "research"
    → 与 ⑥ 互补——⑥ 给结构化字段（目标价/rating_action），本路给原文论述；quota=0
10. metrics(query="^VIX 行情", asset_type="tradfi")
    → VIX 恐慌指数
11. metrics(query="DGS10", limit=5)
    → 10Y 利率（⚠️ FRED series 每个单独 fire，query 只放纯 series_id 禁中文/混合语言；
      不与 market ticker 混批，红线 4/B-31）
```

**总计 11 路调用**（3 批，每批 ≤4 遵守 SSE 并发红线）。相对旧版 8 路：
- **净增 1 次额度**——新增的结构化研报层计 1；signal 由「只取 insider」放宽为 fanout **额度不变**却多拿 13F + KOL；news 由 1 路拆成 media / twitter / research 三路**不增额度**（news 实体搜索 quota=0）
- 编排已覆盖官方尽调全五项：`metrics(market)` + `metrics(fundamentals)` + `news(twitter)` + `news(research)` + `signal(insider_trading)`
- 比 v1 的 22 路仍节省 **-50%**

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

> 19 个 Agent 的 prompt（哲学 + 关注数据 + 评分框架）**完全保留 v1**，执行前先 Read 引用附件 `~/.claude/references/01_agent-prompts.md`（仓库内对应 `references/01_agent-prompts.md`）。每个 Agent 从同一数据池中按需取数。

> ⚠️ **数据硬闸（⑭⑮⑲ 强制执行）**：
> - ⑭ Valuation：`valuation_block.dcf` 偏离现价 >5 倍即判失效，不进任何输出（SSOT 实测 INTC dcf 2.95 vs 现价 86.57——亏损期 DCF 直接崩且无失效标注）
> - ⑮ Fundamentals / ⑲ Growth：`beat_miss.epsActual` 与 `latest_quarter.eps` **反号即口径错位**（非 GAAP vs GAAP），引用超预期必须标"非 GAAP"（N-29）
> - ⑮ Fundamentals / ⑲ Growth：`revenueActual` 为 null 时 `revenue_surprise_pct` 会显示 -100——那是缺失不是暴跌，**revenueActual 非 null 才可读 surprise_pct**（N-33）

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
行业: [sector] / [industry] | 市值: $[mktCap] | 当前价: $[price] ([change/previousClose×100]%，自算) | Beta: [beta]
⚠️ N-47：snapshot 的 change 是美元变动量不是百分比——别拿 change 去和新闻里的 % 交叉核实（会得到假的"核实通过"）

### 📊 19 位分析师投票分布
| Agent | 信号 | 置信度 | 核心理由 |
|---|---|---|---|
| ① Buffett | 🟢 Bullish | 85 | 毛利率 75% / ROE 104% / 安全边际 +14% |
| ② Graham | 🟡 Neutral | 60 | PE 43.56 偏高，但 PEG 0.66 合理 |
| ... | ... | ... | ... |
| ⑲ Growth | 🟢 Bullish | 90 | 4Q EPS 翻倍 + 营收 +54% QoQ（最新季 YoY 不在 4 季窗口，需外源——N-54）|

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
- ✅ **comprehensive 真聚合**：**必须显式 `query="<T> 全面分析"`**（N-8：ticker 并入 query 串）才走 comprehensive intent（query 不含意图词走 default 只返 5 block）；带意图词时返 14 block（缺 stock_peers，输出"同行"标"数据不可用"）
- ✅ **insider 已含 corporate Form 4 + senate + house 三路 fanout**，Group C Sentiment 可用政客买入信号
- ✅ **历史 OHLCV** 用 `query="<T> 历史走势"` + `time_range="1y"`；**技术指标** 用 `query="<T> 相对强弱 指标"` 或 `query="<T> 均线 指标"` 各自单调（不要靠 fanout，撞错路径无 fallback）
- 🆕 **signal 必须省略 `categories`（N-4）**：省略即 fanout 到 insider_trading + institutional(13F) + kol_call 三类，**合计仍只计 1 额度**。按类分 3 次调 = 3 倍额度且数据完全相同
- 🆕 **13F 环比字段季内不可引用（N-7，2026-07-24 复核仍有效）**：`investorsHolding` / `ownershipPercentChange` / `putCallRatioChange` 在申报季中期是残缺假信号（实测 NVDA 6234→1441→1882 持续回补）。Group C 只能引用绝对持仓与结构，**任何环比一律不用**
- 🆕 **KOL 喊单先按 `source_url` 去重（N-5）**：多标的推文按 symbol 裂成多条，不去重会把一条低信号推文计成三个独立喊单，直接污染 Sentiment 分析师输入
- 🆕 **研报层 warning 是误报（N-21）**：`meta.warnings` 报 `default_fanout_fallback` 时 payload 里 `research_reports` 仍然齐全，**以 payload 为准不要重试**；另 `subject_reports=0` 只有 mention 时不能当作"有机构专题覆盖"（N-19）
- 19 个 Agent prompt 业务逻辑保持稳定（不在 MCP 层）

## 业务逻辑（19 Agent prompts 保持稳定）

19 个 Agent 的：
- 投资哲学描述
- 关注数据子集
- 评分框架（如 Buffett 护城河 / Graham NCAV / Wood 颠覆性创新）
- 信号阈值

以及 ⑳ 风控经理 / ㉑ 组合经理的完整决策逻辑，全部在引用附件 **`01_agent-prompts.md`**（路径：`~/.claude/references/01_agent-prompts.md`，仓库内 `references/01_agent-prompts.md`）。**执行 Step 3 前必须先 Read 该文件**，不要凭分析师名字现编评分框架。

## 输出约束

- 每个 Agent 信号必须有数据支撑
- 不喊单 / 不预测价格
- 矛盾度高时（>40% Agent 不一致）必须标注
- 数据缺失（如 comprehensive 聚合失败）降级用单 sub-intent 调用补充
