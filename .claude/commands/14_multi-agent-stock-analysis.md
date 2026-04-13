---
name: Multi-Agent Stock Analysis
description: 多Agent美股深度分析 — 19位虚拟分析师（8位传奇投资者+5位现代大师+6位量化分析师）独立打分，风控经理约束仓位，组合经理LLM综合决策。对标ai-hedge-fund架构。必须指定具体股票代码，如"帮我全面分析AAPL"、"多维度看TSLA"、"NVDA值不值得买"。
trigger: 多维度分析、多角度分析、全面分析、深度分析、值不值得买、能不能买、该不该买、综合分析、multi-agent分析、AI分析、投资分析、全方位分析、帮我分析一下XX、XX怎么样、XX能买吗、multi-agent analysis、full analysis、comprehensive analysis、should I buy、deep dive、stock analysis、investment analysis
not_trigger: 策略信号、KOL、喊单、热点、日报、背离扫描、财报速查、宏观指标、BTC宏观、黄金宏观、strategy、KOL calls、trending、daily brief、divergence、earnings report、macro、morning brief
mcp: finance_tool_stable_request, finance_tool_income_statement, finance_tool_balance_sheet_statement, finance_tool_cash_flow_statement, finance_tool_earnings, finance_tool_ratios_ttm, finance_tool_key_metrics_ttm, finance_tool_quote, finance_tool_discounted_cash_flow, finance_tool_financial_growth, finance_tool_enterprise_values, finance_tool_historical_price_eod_full, finance_tool_insider_trading_latest, finance_tool_technical_indicators_rsi, finance_tool_technical_indicators_ema, finance_tool_technical_indicators_sma, search_finance_news, fred_get_series
args: ticker
---

# /multi-agent-stock-analysis $ARGUMENTS

多Agent美股深度分析 — 19位分析师独立研判 + 风控经理 + 组合经理 = 21 Agents（对标 ai-hedge-fund）

## 参数

| 参数 | 必填 | 说明 |
|------|------|------|
| ticker | 是 | 股票代码，如 AAPL、TSLA、NVDA |

## 意图路由

| 用户说的 | 走哪个Skill |
|---------|-----------|
| 全面分析、深度分析、多维度分析、值不值得买 | ✅ 本Skill |
| XX财报、XX earnings | ❌ 转 earnings-report |
| CPI影响、非农解读 | ❌ 转 macro-analyzer |
| 背离扫描、异常信号 | ❌ 转 divergence-scan |
| 宏观日报、美股早报 | ❌ 转 morning-brief |

## 架构设计

```
                    ┌───────────────────────────────────────┐
                    │         数据采集层 (Step 1-2)          │
                    │  profile + 三表 + 估值 + 技术 + 情绪    │
                    └─────────────────┬─────────────────────┘
                                      │
    ┌─────────────────────────────────┼─────────────────────────────────┐
    │  Group A: 传奇投资者 (8)         │  Group B: 现代大师 (5)           │
    │  ① Buffett  ② Graham           │  ⑨ Damodaran  ⑩ Druckenmiller  │
    │  ③ Munger   ④ Burry            │  ⑪ Taleb      ⑫ Pabrai         │
    │  ⑤ Ackman   ⑥ Wood             │  ⑬ Jhunjhunwala                │
    │  ⑦ Lynch    ⑧ Fisher           │                                │
    ├─────────────────────────────────┼────────────────────────────────┤
    │  Group C: 量化分析师 (6)                                          │
    │  ⑭ Valuation  ⑮ Fundamentals  ⑯ Technicals                     │
    │  ⑰ Sentiment  ⑱ News Sentiment ⑲ Growth                        │
    └─────────────────────────────────┼────────────────────────────────┘
                                      │
                        19路 signal + confidence + reasoning
                                      │
                              ┌───────┴───────┐
                              │ ⑳ 风控经理     │ ← 计算仓位上限
                              │ (Risk Mgr)    │
                              └───────┬───────┘
                              ┌───────┴───────┐
                              │ ㉑ 组合经理     │ ← LLM综合决策
                              │ (Portfolio Mgr)│  （不用固定权重）
                              └───────────────┘
```

## 数据层工具映射

> **重要**: `finance_tool_*` 系列工具 schema 大部分已修复，可直接调用。
> 仍有 schema 问题的工具需通过 `finance_tool_stable_request` 访问。

| 用途 | 调用方式 | 参数 | 说明 |
|------|----------|------|------|
| 公司信息 | `finance_tool_stable_request` | path=`profile`, params=`{symbol}` | ⚠️ schema 未修复 |
| 实时报价 | `finance_tool_quote` | `symbol` | ✅ |
| DCF 估值 | `finance_tool_discounted_cash_flow` | `symbol` | ✅ |
| 利润表 | `finance_tool_income_statement` | `symbol, period: "annual", limit: 5` | ✅ |
| 资产负债表 | `finance_tool_balance_sheet_statement` | `symbol, period: "annual", limit: 5` | ✅ |
| 现金流量表 | `finance_tool_cash_flow_statement` | `symbol, period: "annual", limit: 5` | ✅ |
| 季度利润表 | `finance_tool_income_statement` | `symbol, period: "quarter", limit: 8` | ✅ 季度趋势 |
| 关键比率 TTM | `finance_tool_ratios_ttm` | `symbol` | ✅ |
| 关键指标 TTM | `finance_tool_key_metrics_ttm` | `symbol` | ✅ |
| 企业价值 | `finance_tool_enterprise_values` | `symbol, period: "annual", limit: 3` | ✅ |
| 财务增长率 | `finance_tool_financial_growth` | `symbol, period: "annual", limit: 5` | ✅ |
| Beat/Miss | `finance_tool_earnings` | `symbol` | ✅ Adjusted EPS |
| 分析师预测 | `finance_tool_stable_request` | path=`analyst-estimates`, params=`{symbol, period: "annual"}` | ⚠️ 必须传 period |
| RSI | `finance_tool_technical_indicators_rsi` | `symbol, period: 14, time_period: "daily"` | ✅ |
| EMA | `finance_tool_technical_indicators_ema` | `symbol, period: 50, time_period: "daily"` | ✅ |
| SMA | `finance_tool_technical_indicators_sma` | `symbol, period: 200, time_period: "daily"` | ✅ |
| 历史价格 | `finance_tool_historical_price_eod_full` | `symbol, from: 1年前` | ✅ 250交易日 |
| 价格动量 | `finance_tool_stable_request` | path=`stock-price-change`, params=`{symbol}` | ⚠️ |
| 内部人交易 | `finance_tool_insider_trading_latest` | `symbol` | ✅ |
| 目标价共识 | `finance_tool_stable_request` | path=`price-target-consensus`, params=`{symbol}` | ⚠️ |
| 新闻报道 | `search_finance_news` | `keyword: "companyName ticker", count: 10` | 31家媒体 |
| VIX | `fred_get_series` | `series_id: "VIXCLS", limit: 5` | ✅ integer |
| 10Y 利率 | `fred_get_series` | `series_id: "DGS10", limit: 5` | ✅ integer |

## 执行步骤

### Step 1: 获取公司基本信息

```
finance_tool_stable_request:
  path: "profile"
  params: {symbol: "[TICKER]"}

提取: companyName, sector, industry, mktCap, beta, country, description
```

### Step 2: 并行拉取全部数据（~20 个调用）

所有调用同时发起，最大化并行效率：

```
 1. finance_tool_discounted_cash_flow: symbol
 2. finance_tool_income_statement: symbol, period: "annual", limit: 5
 3. finance_tool_income_statement: symbol, period: "quarter", limit: 8
 4. finance_tool_balance_sheet_statement: symbol, period: "annual", limit: 5
 5. finance_tool_cash_flow_statement: symbol, period: "annual", limit: 5
 6. finance_tool_ratios_ttm: symbol
 7. finance_tool_key_metrics_ttm: symbol
 8. finance_tool_enterprise_values: symbol, period: "annual", limit: 3
 9. finance_tool_financial_growth: symbol, period: "annual", limit: 5
10. finance_tool_earnings: symbol
11. finance_tool_stable_request: path="analyst-estimates", params={symbol, period: "annual"}
12. finance_tool_technical_indicators_rsi: symbol, period: 14, time_period: "daily"
13. finance_tool_technical_indicators_ema: symbol, period: 50, time_period: "daily"
14. finance_tool_technical_indicators_sma: symbol, period: 200, time_period: "daily"
15. finance_tool_historical_price_eod_full: symbol, from: 1年前
16. finance_tool_stable_request: path="stock-price-change", params={symbol}
17. finance_tool_insider_trading_latest: symbol
18. finance_tool_stable_request: path="price-target-consensus", params={symbol}
19. search_finance_news: keyword="[companyName] [ticker]", count: 10, not_before_ts: 30天前
20. fred_get_series: series_id="DGS10", limit: 5
21. fred_get_series: series_id="VIXCLS", limit: 5
22. finance_tool_quote: symbol
```

### Step 3: 19 位分析师独立研判

每位分析师基于自己的投资哲学和关注的数据子集，**独立**输出：
- **信号**: Bullish / Bearish / Neutral
- **置信度**: 0-100
- **核心理由**: 2-3 条关键论据

所有分析师共享 Step 2 的数据池，但各自只关注与其哲学相关的指标。

---

## Group A: 传奇投资者 (8位)

### ① Warren Buffett — 长期价值投资

**哲学**: 以合理价格买入优秀企业，持有一辈子。寻找持久竞争优势（护城河）、优秀管理层、可预测的盈利。

**关注数据**: 利润表5年、比率TTM、现金流、DCF

**分析框架**:
```
护城河评估:
- Gross Margin > 40% 且 5年稳定 → 定价权（护城河标志）
- ROE > 15% 持续 → 资本配置能力
- Net Margin > 20% → 宽护城河
- Revenue 5年稳定增长 → 可预测性

所有者盈余 (Owner Earnings):
= Net Income + D&A - CapEx（维护性）
- Owner Earnings Yield > 10Y利率 → 有吸引力

估值纪律:
- DCF vs Price → 安全边际
- 安全边际 > 25% → Bullish
- 安全边际 < -15% → 太贵不买

红线: D/E > 1.0 | ROE < 10% | FCF持续为负 | 管理层大量SBC
```

### ② Ben Graham — 深度价值投资

**哲学**: 极端的安全边际。寻找价格远低于内在价值的"烟蒂股"。定量筛选，不依赖定性判断。

**关注数据**: 资产负债表、比率TTM、指标TTM、DCF

**分析框架**:
```
Graham 经典筛选条件:
1. P/E < 15 (或 P/E × P/B < 22.5)
2. P/B < 1.5
3. Current Ratio > 2.0
4. D/E < 0.5（非金融公司）
5. 连续5年正盈利
6. 连续分红记录

净流动资产价值 (NCAV):
= Current Assets - Total Liabilities
- Price < NCAV × 2/3 → 经典格雷厄姆买入信号（极少见）

Graham Number = √(22.5 × EPS × Book Value per Share)
- Price < Graham Number → Bullish
- Price > Graham Number × 1.5 → Bearish

红线: 连续亏损 | Current Ratio < 1 | 无有形资产支撑
```

### ③ Charlie Munger — 品质复合增长

**哲学**: "以合理价格买入伟大公司，远好于以低价买入平庸公司。"关注商业品质、管理层理性、长期复合能力。

**关注数据**: 利润表5年、比率TTM、现金流、增长率

**分析框架**:
```
品质筛选（Munger Checklist）:
1. 商业可理解性: 业务模式是否简单可预测？
2. 持续竞争优势: Gross Margin 趋势 + ROE 稳定性
3. 管理层理性:
   - SBC/Revenue < 5% → 理性
   - 不乱收购（goodwill增长率 vs revenue增长率）
   - 回购而非稀释
4. 盈利品质: FCF/Net Income > 80%（非纸面利润）
5. 资本回报: ROIC > WACC（创造价值而非毁灭价值）

复合能力:
- ROE > 20% + 高留存率 → 内生复合增长引擎
- Revenue CAGR 5年 > 8% + 利润率稳定/扩大

Munger 不买: 高杠杆 | 不可理解 | 管理层贪婪 | 周期性太强
```

### ④ Michael Burry — 逆向深度价值

**哲学**: 独立思考，逆向操作。寻找市场严重错误定价的机会。愿意做空被高估的资产。关注资产负债表中隐藏的问题。

**关注数据**: 资产负债表5年、现金流、比率TTM、估值

**分析框架**:
```
逆向价值:
- P/E vs 行业中位数: 显著折价 → 市场忽略？
- EV/EBITDA < 8 且有形资产充足 → 隐藏价值
- Price < Tangible Book Value → 清算价值折价

做空信号（Burry 特有）:
- P/S > 15 + FCF 持续为负 → 高估泡沫
- Goodwill/Total Assets > 40% → 收购依赖型增长
- Operating Cash Flow 趋势 vs Net Income 趋势背离 → 盈利质量问题
- SBC/Revenue > 15% → 隐藏成本，利润虚高
- 应收账款增速 >> Revenue增速 → 可能确认了不存在的收入

资产负债表风险扫描:
- 短期债务 / 现金 > 1 → 流动性危机风险
- 递延收入变化趋势（下降 = 未来收入前景恶化）
- 商誉减值风险（goodwill > equity）
```

### ⑤ Bill Ackman — 激进价值投资

**哲学**: 集中持仓，大胆下注。寻找被市场误解但有催化剂驱动价值回归的公司。愿意公开对抗管理层。

**关注数据**: 利润表5年、比率TTM、增长率、新闻

**分析框架**:
```
Ackman 三要素:
1. 简单可预测的商业模式（护城河 + 经常性收入）
2. 显著的改善空间（利润率可扩张 / 管理层可更换）
3. 明确的催化剂（新管理层 / 业务分拆 / 监管变化 / 市场重新认知）

估值 + 催化剂:
- FCF Yield > 7% + 存在改善催化剂 → Bullish
- Operating Margin 有提升空间（vs 行业最佳水平）
- Revenue 稳定 + 成本可削减 = 利润率扩张机会

集中度信心:
- 如果 Ackman 会建仓，仓位会多大？
- 高确信 → Bullish with high confidence
- 低确信 → Pass（Ackman 不做小赌注）
```

### ⑥ Cathie Wood — 颠覆式创新投资

**哲学**: 投资于颠覆性创新平台。5年以上时间视野。愿意承受短期波动换取指数级增长。关注TAM扩张和S曲线拐点。

**关注数据**: 增长率、分析师预测、利润表、新闻（创新叙事）

**分析框架**:
```
颠覆性创新评估:
1. 是否处于技术创新S曲线的早期？（AI / 区块链 / 基因编辑 / 机器人）
2. TAM（Total Addressable Market）是否在扩大？
3. Revenue CAGR > 25% → 指数级增长阶段
4. 平台效应: 用户/开发者/数据的网络效应

增长 vs 估值:
- Revenue 3Y CAGR > 30% → 高增长阶段，可容忍高估值
- PEG < 1 → 增长被低估
- 当前亏损但 FCF 拐点在望 → 可接受

分析师前瞻:
- Revenue 未来3年 CAGR 预期 > 20% → 增长持续
- EPS 拐点: 从亏损转盈利 → 强催化剂
- Beat 率 > 75% → 管理层指引保守（好信号）

Wood 不买: 增长减速 | 护城河不清晰 | 传统行业微改进
```

### ⑦ Peter Lynch — GARP (成长合理价格)

**哲学**: "投资你了解的公司。"寻找增长被低估的公司（10-baggers）。PEG 是核心指标。偏好被忽略的中小盘。

**关注数据**: 增长率、比率TTM、利润表、earnings

**分析框架**:
```
Lynch 分类（先判断公司类型）:
1. Slow Growers: Revenue/EPS增速 < 5% → 看股息
2. Stalwarts: 增速 10-15% → 看估值折价
3. Fast Growers: 增速 > 20% → 核心猎场
4. Cyclicals: 周期性行业 → 看周期位置
5. Turnarounds: 从亏损转盈利 → 看拐点
6. Asset Plays: 隐藏资产 > 市值 → 看资产重估

PEG 核心:
- PEG = PE / EPS Growth Rate (长期)
- PEG < 1.0 → 严重低估（Lynch最爱）
- PEG 1.0-1.5 → 合理
- PEG > 2.0 → 过贵

Lynch 附加检查:
- 净现金 / 市值 → 现金折价
- Earnings Beat 持续性 → 管理层可信度
- 机构持股比例低 → 被忽略（好事）

Lynch 警告: P/E > 40 | 热门股 | 多元化收购 | "下一个XX"叙事
```

### ⑧ Phil Fisher — 成长股质量投资

**哲学**: "Scuttlebutt"方法——深入调研公司的管理、研发和市场地位。愿意为高品质成长支付溢价。极长持有期（"卖出的时间几乎永远不会来"）。

**关注数据**: 利润表5年趋势、增长率、比率TTM、现金流

**分析框架**:
```
Fisher 15点清单（核心5点可量化）:
1. 产品/服务增长潜力: Revenue CAGR 5年 > 10%
2. 研发效率: R&D支出趋势 + Revenue 增速是否匹配
3. 利润率趋势: Gross Margin + Operating Margin 5年走势
   - 扩大 → 规模效应 / 定价权增强
   - 缩小 → 竞争加剧警告
4. 管理层资本配置:
   - CapEx/Revenue 合理且持续 → 投资未来
   - 回购 + 低杠杆 → 股东友好
5. 长期盈利可见度:
   - Revenue 波动率低 → 可预测
   - 经常性收入占比高 → 粘性

Fisher 买入: Margin扩张 + Revenue持续增长 + 低杠杆 + 研发投入
Fisher 卖出: 管理层恶化 | 增长天花板 | 利润率持续下降
```

---

## Group B: 现代大师 (5位)

### ⑨ Aswath Damodaran — 学术估值大师

**哲学**: "每家公司都有一个故事，每个故事都有数字。"严格的估值纪律。不相信没有叙事的数字，也不相信没有数字的叙事。

**关注数据**: DCF、利润表、增长率、比率TTM、企业价值

**分析框架**:
```
Damodaran 估值三角:
1. 内在价值（DCF）:
   - DCF vs Price → Gap%
   - 若 DCF 模型失效（负盈利），用 Revenue Multiple + 远期盈利假设

2. 相对估值:
   - P/E vs 行业 → 折价/溢价
   - EV/EBITDA vs 行业
   - P/S vs 增长率（高增长可容忍高PS）

3. 叙事一致性:
   - 公司叙事 = 增长叙事 / 效率叙事 / 衰退叙事？
   - 数字是否支持叙事？
   - Revenue增速支持增长叙事？Margin趋势支持效率叙事？

Damodaran 关键指标:
- EV/Sales: 用于亏损公司的估值锚
- 隐含增长率 = 当前PE下需要多少增长才合理？
  → 隐含增长率 > 实际增长预期 → 高估
  → 隐含增长率 < 实际增长预期 → 低估
```

### ⑩ Stanley Druckenmiller — 宏观趋势大师

**哲学**: "不要关注当前的盈利，要关注18个月后的盈利。"宏观趋势驱动选股。寻找与宏观顺风方向一致的个股。不对称押注。

**关注数据**: 宏观(VIX/DGS10)、利润表、增长率、新闻、sector

**分析框架**:
```
宏观-微观对齐:
1. 宏观环境判断:
   - 10Y利率趋势: 上行→避开成长股, 下行→加仓成长股
   - VIX水平: < 15→risk-on, > 25→risk-off
   - 利率周期位置: 加息末期/降息初期 → 布局

2. 板块顺逆风:
   - 利率下行 + 该公司是成长型 → 宏观顺风
   - 利率上行 + 该公司高杠杆 → 宏观逆风
   - 通胀上行 + 该公司有定价权 → 可抗通胀

3. 盈利动量 (18个月前瞻):
   - 分析师预期上修 vs 下修
   - Revenue加速 vs 减速趋势
   - 如果18个月后盈利显著好转 → 现在就买

Druckenmiller 核心: "判断对了大方向，仓位可以加重"
- 宏观+微观双顺风 → 高置信 Bullish
- 宏观逆风但微观强劲 → Neutral（等待）
- 宏微双逆风 → Bearish
```

### ⑪ Nassim Taleb — 反脆弱 / 尾部风险

**哲学**: "杠铃策略"——极度保守+小仓位博极大收益。关注一家公司在黑天鹅事件中是受益还是受损。讨厌脆弱的东西。

**关注数据**: 资产负债表、现金流、波动率(历史价格)、beta、D/E

**分析框架**:
```
脆弱性评估 (Fragility Score):
1. 财务脆弱:
   - D/E > 2 → 脆弱 (杠杆放大冲击)
   - Current Ratio < 1 → 脆弱 (短期偿付风险)
   - 固定成本占比高 → 脆弱 (下行无缓冲)
   - 收入高度集中于单一来源 → 脆弱

2. 反脆弱特征:
   - 净现金 > 0 → 有期权性（可逆势扩张）
   - 波动性中受益（如保险、交易所、做市商）
   - 轻资产模式 → 在危机中灵活调整
   - Optionality: 公司是否有免费期权？（新市场、新产品线）

3. 凸性 (Convexity):
   - 上行空间 vs 下行风险 是否不对称？
   - 最大亏损 = 股价归零（有限）
   - 最大收益 = 市场重估（可能无限）
   - 凸性比率 = 潜在上行倍数 / 潜在下行百分比

Taleb 判定:
- 反脆弱 + 凸性高 → Bullish (小仓位博大收益)
- 脆弱 + 高杠杆 → Bearish (可能被黑天鹅消灭)
- 坚韧但无凸性 → Neutral
```

### ⑫ Mohnish Pabrai — Dhandho 投资

**哲学**: "Heads I win big, tails I don't lose much。"低风险高回报的不对称机会。极度集中（6-10只），极度耐心。借鉴Buffett但更激进。

**关注数据**: DCF、资产负债表、比率TTM、增长率

**分析框架**:
```
Dhandho 框架:
1. 下行保护:
   - 有形账面价值 vs 市值 → 资产地板
   - Net Cash / Market Cap → 现金保护层
   - 最坏情况下能回收多少？（清算价值）
   - D/E < 0.3 → 低杠杆保护

2. 上行弹性:
   - 如果核心假设成立，3-5年后值多少？
   - 分析师最高目标价 / 当前价 → 上行倍数
   - Revenue 增速 × 利润率改善 → 双击潜力
   - Turnaround 机会？（从亏损到盈利的拐点）

3. 确定性vs回报:
   - 下行风险 < 20% + 上行 > 100% → Dhandho！
   - 下行风险 > 50% → 不够安全，pass
   - 上行 < 50% → 回报不够诱人，pass

Pabrai 不碰: 高杠杆 | 复杂业务 | 管理层不诚信 | 没有资产底
```

### ⑬ Rakesh Jhunjhunwala — 新兴市场 / 大胆增长

**哲学**: 印度"大牛"。结合宏观趋势和个股基本面。愿意在市场恐慌时大胆买入。长期看多增长型经济体和新兴行业。

**关注数据**: 增长率、利润表、宏观数据、分析师预测

**分析框架**:
```
宏观+增长双轮驱动:
1. 行业增长周期:
   - 行业是否处于增长初期？（渗透率 < 30%）
   - TAM 增速 > GDP增速？
   - 监管是顺风还是逆风？

2. 公司竞争地位:
   - 市场份额趋势（上升 = 赢家）
   - Revenue 增速 > 行业增速 → 在抢份额
   - Operating Leverage: Revenue增速 > OpEx增速 → 规模效应

3. 价格 vs 价值:
   - Forward PE vs 预期增速 → 合理吗？
   - 市场恐慌性抛售创造的机会？（短期利空 vs 长期基本面）
   - 如果恢复正常估值 → 潜在回报

Jhunjhunwala 核心: 市场恐慌 + 基本面强劲 + 增长可见 = 最佳买点
```

---

## Group C: 量化分析师 (6位)

### ⑭ Valuation Agent — 多模型估值

**关注数据**: DCF、比率TTM、指标TTM、企业价值、分析师预测

**分析框架**:
```
四种估值方法加权:

1. DCF 估值 (权重 30%):
   - 直接使用 finance_tool_discounted_cash_flow 结果
   - DCF vs Price → 安全边际

2. Multiples 估值 (权重 30%):
   - P/E 相对行业 → 折溢价
   - EV/EBITDA 相对行业
   - P/S vs 增长率

3. 分析师目标价 (权重 20%):
   - 共识目标价 vs 当前价
   - 高低差距 → 市场分歧度

4. 远期估值 (权重 20%):
   - Forward PE (用分析师预期EPS)
   - 若当前亏损: Forward Revenue Multiple
   - 隐含增长率测试

综合: 4种方法的均值方向 → 信号
- 3/4 以上方法看低估 → Bullish
- 3/4 以上方法看高估 → Bearish
- 混合 → Neutral
```

### ⑮ Fundamentals Agent — 财务健康体检

**关注数据**: 三表（利润表+资产负债表+现金流）5年、比率TTM

**分析框架**:
```
四维体检:

1. 盈利质量:
   - Net Income vs OCF 差异（差异>30% → 应计利润警告）
   - FCF/Net Income → 现金转化率
   - SBC/Revenue → 隐藏成本

2. 资产负债表健康:
   - Current Ratio > 1.5 → 健康
   - D/E < 1.0 → 安全
   - Goodwill/Equity → 收购质量（>100% 危险）
   - Net Cash vs Net Debt

3. 利润率趋势（5年）:
   - Gross Margin 趋势 → 定价权
   - Operating Margin 趋势 → 运营效率
   - Net Margin 趋势 → 综合盈利

4. 资本效率:
   - ROE 趋势（是否靠杠杆驱动？）
   - ROIC vs WACC → 创造 or 毁灭价值
   - CapEx/Revenue → 资本密集度

评分: A(优秀) / B(良好) / C(一般) / D(警告) / F(危险)
→ A/B → Bullish, C → Neutral, D/F → Bearish
```

### ⑯ Technicals Agent — 技术分析

**关注数据**: RSI、EMA、SMA、历史价格、价格动量

**分析框架**:
```
三层技术分析:

1. 趋势:
   - Price vs SMA200 → 长期方向
   - EMA50 vs SMA200 → 金叉(看多)/死叉(看空)
   - Price vs SMA50 → 中期方向

2. 动量:
   - RSI(14):
     > 70 → 超买（回调风险）
     < 30 → 超卖（反弹机会）
     40-60 → 中性区
   - stock-price-change 多时间框架:
     1M/3M/6M 方向一致 → 趋势确认
     方向矛盾 → 转折信号

3. 波动结构:
   - 从历史价格计算:
     近20日波动率 vs 近60日波动率
     波动率收缩 → 突破在即
     波动率扩张 → 趋势加速

信号:
- Bullish: 金叉 + RSI 50-65 + 多时间框架上行
- Bearish: 死叉 + RSI>75 or 多时间框架下行
- Neutral: 混合信号
```

### ⑰ Sentiment Agent — 内部人 + 华尔街情绪

**关注数据**: 内部人交易、目标价共识

**分析框架**:
```
双维度情绪:

1. 内部人行为 (50%):
   - 近90天净买卖
   - CEO/CFO 买入 → 强信号
   - 期权行权卖出 → 中性（排除）
   - 大额集中买入 → 强看多

2. 华尔街共识 (50%):
   - 目标价 vs 当前价 → 上行空间
   - 目标价分散度 → 市场分歧度
   - 上行 > 20% + 多数Buy → Bullish
   - 下行 + 多数Sell → Bearish
```

### ⑱ News Sentiment Agent — 新闻情绪

**关注数据**: search_finance_news (10篇近期报道)

**分析框架**:
```
媒体情绪分析（独立于⑰的内部人/华尔街维度）:

1. 逐篇分析:
   - Claude 阅读10篇近期报道的 title + content
   - 逐篇判断: 正面 / 负面 / 中性
   - 提取关键主题和高频词

2. 情绪聚合:
   - 正面率 = 正面篇数 / 总篇数
   - > 60% 正面 → Bullish
   - > 60% 负面 → Bearish
   - 混合 → Neutral

3. 叙事分析:
   - 主流叙事是什么？（增长故事 / 风险警告 / 监管担忧）
   - 是否有叙事转变的信号？
   - 标注"Claude 推断"
```

### ⑲ Growth Agent — 增长动能

**关注数据**: 增长率、earnings (Beat/Miss)、分析师预测、季度利润表

**分析框架**:
```
增长质量评估:

1. 历史增长:
   - Revenue 3Y CAGR
   - EPS 增速趋势（加速/稳定/减速）
   - Gross Profit 增速 vs Revenue 增速 → 增长质量

2. Beat/Miss 持续性:
   - 最近 4 季度 EPS Beat 率
   - Beat 幅度趋势（扩大 = 预期太保守）
   - Revenue Beat 率

3. 前瞻增长:
   - 分析师预期 Revenue/EPS 未来 3 年增速
   - 预期是否在上修（当前 vs 历史预期）
   - 增速是否可持续（TAM 还有多少？）

4. 增长估值匹配:
   - PEG = PE / 长期 EPS Growth
   - PEG < 1 → 增长被低估
   - PEG > 2.5 → 增长溢价过高
   - Revenue Growth / PS → 增长效率

信号:
- Bullish: 增长加速 + Beat持续 + PEG < 1.5
- Bearish: 增速减速 + 预期下修 + PEG > 2.5
- Neutral: 增长稳定但无加速
```

---

## ⑳ 风控经理 (Risk Manager)

**不输出方向信号，只输出风险等级和仓位上限。**
**对标原版**: 计算波动率指标、相关性分析、保证金约束，为组合经理提供仓位上限。

**关注数据**: 历史价格（波动率）、Beta、VIX、DGS10

```
1. 波动率计算:
   - 日波动率 = std(daily returns)
   - 年化波动率 = 日波动率 × √252
   - 波动率百分位（vs 历史分布）

2. 回撤分析:
   - 最大回撤 = max peak-to-trough (1年内)
   - 当前距高点的回撤幅度

3. 市场环境:
   - VIX: <15低波, 15-25正常, 25-35高波, >35恐慌
   - 10Y利率水平及趋势
   - Beta → 系统性风险敞口

4. 仓位上限计算（波动率调整法）:
   - 基础仓位 = 10%（等权10只）
   - 波动率调整仓位 = 基础仓位 × (市场均值波动率~16% / 个股年化波动率)
   - VIX > 30 → 全局仓位减半
   - 上限 cap 在 25%（单票不超过1/4组合）
   - 下限 floor 在 2%（太小不值得持有则标"观望"）

输出: Low Risk / Medium Risk / High Risk + 仓位上限百分比
```

---

## ㉑ 组合经理 (Portfolio Manager) — LLM 综合决策

**对标原版 ai-hedge-fund**: 组合经理不使用固定权重公式，而是作为 LLM 综合判断所有 Agent 信号，考虑信号强度、一致性、矛盾点，做出最终投资决策。

### 决策流程（对标原版 portfolio_manager.py）

```
输入:
- 19位分析师的 {signal, confidence, reasoning}
- 风控经理的 {risk_level, max_position_size}
- 当前持仓状态（假设空仓，首次建仓分析）

组合经理 LLM 综合决策步骤:

1. 信号汇总:
   - 统计多空比: X Bullish / X Neutral / X Bearish
   - 识别高置信信号 (confidence > 70%)
   - 识别低置信信号 (confidence < 40%)

2. 信号质量评估（不是简单投票）:
   - 高置信一致信号 > 低置信分散信号
   - 量化分析师(⑭-⑲)的数据驱动信号 → 基础参考
   - 传奇投资者(①-⑧)的框架判断 → 哲学验证
   - 现代大师(⑨-⑬)的宏观/风险视角 → 约束条件
   - Burry(④)的逆向信号单独标注（不计入简单多空比）

3. 矛盾调和:
   - 识别关键分歧（如价值派vs成长派）
   - 判断哪方的论据更有数据支撑
   - 矛盾本身就是信息："市场对此有分歧"

4. 最终决策:
   - 方向: Buy / Sell / Short / Hold
   - 仓位: 在风控上限内决定实际仓位比例
   - 置信度: 基于信号一致性和质量
   - 关键理由: 综合最重要的 3-5 个论据

5. 参考评分（辅助，非决策依据）:
   - 多空比 > 14/19 一致 → 高确信
   - 多空比 10-13/19 → 中等确信
   - 多空比 < 10/19 → 低确信，组合经理需给出强理由
```

### 分歧标签（自动标注）

```
当出现以下模式时，组合经理必须在报告中标注:

⚠️ 高风险看多: 风控 High Risk + 多数 Bullish → "收益可期但波动极大"
💡 价值vs成长分歧: 价值派(①②③④⑫) Bearish + 成长派(⑥⑦⑧⑬⑲) Bullish
⏰ 基本面好时机差: 基本面(⑮) Bullish + 技术(⑯) Bearish → "等更好的入场点"
🧊 逆市场情绪: 情绪/新闻(⑰⑱) Bearish + 基本面多数 Bullish → "逆向机会?"
🔄 Burry 逆向信号: Burry(④) 方向与多数人相反 → 单独标注其逻辑
🌊 宏观逆风: Druckenmiller(⑩) Bearish → "宏观环境不利，考虑延后"
💣 脆弱警告: Taleb(⑪) Bearish → "黑天鹅来临时此标的会被重创"
🎯 Dhandho不对称: Pabrai(⑫) 强Bullish → "下行有限+上行巨大的稀有机会"
```

---

## Step 4: 输出报告

```
## 🏛️ [TICKER] 多Agent深度分析 — [CompanyName]

**综合判定: [📈 看多 / ⚖️ 中性 / 📉 看空]　｜　综合得分: [+X.XX]　｜　建议仓位: [X%]**
**多空比: [X Bullish / X Neutral / X Bearish]　｜　[分歧标签]**

---

### 公司概况
行业: [sector] / [industry] | 市值: $[mktCap] | Beta: [beta]
当前价: $[price] ([change]%) | 52周范围: $[low] — $[high]

---

### 📊 Group A: 传奇投资者 (8位)

| # | 分析师 | 信号 | 置信度 | 核心理由 |
|---|--------|------|--------|----------|
| ① | Buffett | [B/N/S] | XX% | [一句话] |
| ② | Graham | [B/N/S] | XX% | [一句话] |
| ③ | Munger | [B/N/S] | XX% | [一句话] |
| ④ | Burry | [B/N/S] | XX% | [一句话] |
| ⑤ | Ackman | [B/N/S] | XX% | [一句话] |
| ⑥ | Wood | [B/N/S] | XX% | [一句话] |
| ⑦ | Lynch | [B/N/S] | XX% | [一句话] |
| ⑧ | Fisher | [B/N/S] | XX% | [一句话] |

### 📊 Group B: 现代大师 (5位)

| # | 分析师 | 信号 | 置信度 | 核心理由 |
|---|--------|------|--------|----------|
| ⑨ | Damodaran | [B/N/S] | XX% | [一句话] |
| ⑩ | Druckenmiller | [B/N/S] | XX% | [一句话] |
| ⑪ | Taleb | [B/N/S] | XX% | [一句话] |
| ⑫ | Pabrai | [B/N/S] | XX% | [一句话] |
| ⑬ | Jhunjhunwala | [B/N/S] | XX% | [一句话] |

### 📊 Group C: 量化分析师 (6位)

| # | 分析师 | 信号 | 置信度 | 核心理由 |
|---|--------|------|--------|----------|
| ⑭ | Valuation | [B/N/S] | XX% | [一句话] |
| ⑮ | Fundamentals | [B/N/S] | XX% | [一句话] |
| ⑯ | Technicals | [B/N/S] | XX% | [一句话] |
| ⑰ | Sentiment | [B/N/S] | XX% | [一句话] |
| ⑱ | News Sentiment | [B/N/S] | XX% | [一句话] |
| ⑲ | Growth | [B/N/S] | XX% | [一句话] |

### ⚡ 风控经理

| 指标 | 值 | 判断 |
|------|-----|------|
| 年化波动率 | XX.X% | [低/中/高] |
| 最大回撤 (1Y) | -XX.X% | — |
| Beta | X.XX | [防御/中性/进攻] |
| VIX | XX.X | [低波/正常/高波/恐慌] |
| 10Y | X.XX% | [上行/下行/平稳] |
| **风险等级** | **[Low/Med/High]** | 仓位: [X%] |

---

### 🎯 组合经理综合判定

**信号矩阵 (19位分析师)**:

| 分类 | Bullish | Neutral | Bearish |
|------|---------|---------|---------|
| 传奇投资者 (8) | X位 | X位 | X位 |
| 现代大师 (5) | X位 | X位 | X位 |
| 量化分析师 (6) | X位 | X位 | X位 |
| **合计** | **X位** | **X位** | **X位** |

**加权综合得分: [+X.XX] → [📈/⚖️/📉]**

### 🔑 关键洞察

**最大共识**: [多数分析师一致看好/看空的点]
**核心分歧**: [价值派vs成长派、基本面vs技术面的矛盾]
**催化剂**: [接下来需要关注的事件]
**最大风险**: [可能颠覆当前判断的因素]

> ⚠️ 本分析由 AI 多Agent系统（19 Agents）生成，仅供研究参考，不构成投资建议。
```

## 输出规则

- 19位分析师**完全独立打分**，各自只使用自己哲学框架内的逻辑
- 每位分析师在汇总表中给**一句话核心理由**，在正文中给**2-3条详细论据**（可选展开）
- **Burry 的信号可能与多数人相反**——这是正常的，他是逆向投资者
- **Taleb 主要输出脆弱性评估**，方向信号基于凸性而非传统估值
- Beat/Miss 数据来源为 `earnings` endpoint (Adjusted EPS)
- 情绪判断标注 "Claude 推断"
- **分歧标签必须标注**——分歧本身就是信息
- 风控经理**不参与方向投票**，只约束仓位
- 组合经理报告多空比 + 加权得分 + 分歧分析

## 简洁模式

如果用户要求"简洁版"或"快速版"，只输出:
1. 汇总表（19位信号 + 1句话理由）
2. 风控经理结论
3. 组合经理最终判定
跳过详细论据展开。

## 注意事项

- **大部分 FMP 工具已可直接调用**
- **`profile`、`analyst_estimates`、`stock_price_change`、`price_target_consensus` 仍需 `finance_tool_stable_request`**
- **fred_get_series 的 limit 必须传 integer**
- **search_finance_news 用 "companyName ticker"**，count 控制在 10 篇
- **并行调用最大化**: Step 2 的 ~22 个调用应尽量并行发起
- **数据缺失处理**: 某个工具返回空或报错时，对应分析师标注"数据不足"，置信度降至 30% 以下
- **同一数据多视角**: 同一份利润表，Buffett 看护城河，Graham 看安全边际，Burry 看做空信号——这是设计意图
