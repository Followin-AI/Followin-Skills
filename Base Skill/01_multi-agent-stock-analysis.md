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
> 🔗 **通用调用红线 + 已知问题登记**：`~/.claude/references/followin-mcp-caveats.md`。本文的调用写法和字段名于 **2026-10-03 实跑验证**、2026-10-08 盘中复跑（AVGO；拍板后 MU 再跑一次）、2026-10-09 第三轮拍板后 MU 盘前复跑；与登记表或 agent-prompts 里的旧工具名冲突时，以本文为准。

## 调用约定（2026-10-03 实测）

`metrics` / `signal` 的入参分工是：**`keywords` 数组放标的，`query` 放意图词，`categories` 指定数据类别**。

- **意图词用中文**。英文指标名写进 query 会被当成 ticker（实测 `"NVDA RSI 14"` 多带回一只代码为 RSI 的股票）。
- 所有 `metrics` / `signal` 调用带 `asset_type="tradfi"`。
- 每次调用后读 `meta.warnings`；`default_fanout_fallback` 是提示不是错误，不要因它重试。
- `signal()` **必须显式传 `categories`**——只传 ticker 返回空。
- 如果客户端不接受数组入参（报 `-32602`），把 ticker 并进 query 串（`query="<T> 分析师评级 同行 DCF"`）。
- 非交易时段，行情快照是上一个常规收盘（`_quote_session:"regular_inactive"`），不是盘后价；标"常规收盘"。
- 盘中跑时快照是实时价，但可能没有 `_quote_session`（2026-10-08 实测 AVGO 盘中无此字段），按 `as_of` 判断并标"实时"。
- `ratios_ttm` / `key_metrics_ttm` 的价格**不一定是表头价**：盘中按前收算，收盘后也可能还停在前一交易日（2026-10-09 美东盘前实测 MU：表头为 10-08 常规收盘 1035.84，P/E 14.45 = 10-07 收盘 1088 ÷ TTM EPS 75.31）。引用 P/E、P/S、P/B 前用"比率 × TTM 每股值"反推它用的价格，与表头价不同就用表头价自算，或写明"按 X 日收盘"。`dcf["Stock Price"]` 同样不可当表头价（盘中实测 = 前收；10-09 盘前实测 1040.49，既不是收盘也不是前收）。**DCF 安全边际一律用表头价自算**（`dcf ÷ 表头价 − 1`，表头价 = 实时价，非交易时段为常规收盘）。实测 MU 10-08 盘中按前收 +24.3%、按实时价 +27.0%，正好跨过 ① 的 25% 线。

## 执行步骤

### Step 1: 数据采集（4 批，每批 ≤4 路并行，共 13 路；"自定同业"可选 +1 路）

**Batch A：基本面 + 历史**
```
1. metrics(keywords=["<T>"], query="行情 公司简介 资产负债表 现金流 分析师评级 同行 DCF 营收增长率",
           asset_type="tradfi", limit=20, verbosity="concise")
   → 一次返回：market.snapshot（price / change / previousClose / marketCap / yearHigh/Low）、
     fiscal_quarters（最新一季的 earnings_surprise + financial_statement）、eps_trend、balance_sheet、cash_flow（各 4 季）、
     profile_block（sector / industry / beta）、valuation_block（ratios_ttm / key_metrics_ttm / dcf）、consensus_price、
     next_earnings_estimate、analyst_grades、analyst_estimates、stock_peers、financial_growth（最近 4 个财年的年度同比）
   （2026-10-03 实测这一个 query 能代替原来的三路调用；只缺利润表）
2. metrics(keywords=["<T>"], query="财报 利润表", categories=["fundamentals"], asset_type="tradfi", limit=4)
   → income_statement（4 季：revenue / grossProfit / operatingIncome / netIncome / R&D / eps / epsDiluted /
     incomeBeforeTax / totalOtherIncomeExpensesNet）
3. 行业同行（必做）：第 1 路的 stock_peers 只有 companyName / mktCap / price，**没有行业字段，而且按代码字母序排列**
   （不是按规模，也不是按业务——实测 NVDA 的名单是 AAPL、ADI、AVGO、ENTG、GOOGL、IMOS、MSFT、TER、TSM）。
   先按公司名排除明显的非同业（如 NVDA 名单里的 AAPL / GOOGL / MSFT），剩下的按 mktCap 从大到小取前 3 家，合并一次。
   名单里混有外国代码时（2026-10-08 实测 MU 的 10 家里 6 家是 .TW / .T / .HK / .SS，GigaDevice 两地各一行），
   外国代码的 mktCap 是**当地货币**（Kioxia 29.4 万亿日元排第一），不能跨币种比大小：先按公司名去重，
   只在美股代码（`^[A-Z]{1,5}$`，含 ADR）里按 mktCap 排；美股代码不足 3 家时再用外国代码补位：
   metrics(keywords=[P1,P2,P3], categories=["market","fundamentals"], asset_type="tradfi", limit=1, verbosity="concise")
   不带 categories 时同行代码会被宏观日历劫持（实测 ADI 多返回一条日本领先指数）。
   返回后核对每家的 profile_block.industry 与目标一致，不一致的在数据缺口注明。
   这一路的估值只有 ratios_ttm（P/E、P/S、P/B、利润率），没有 key_metrics_ttm，同行的 EV/EBITDA 拿不到。
   同行的服务端 PEG 不可比（2026-10-08 实测 MRVL 为 0.03），不引用；行业对比只用 P/E、P/S、P/B、利润率。
   ADR 同行（如 TSM）的报表和 EPS 可能是本币，只引用比率
   **自定同业（可选，+1 路）**：接口同行与目标同属一个 industry、但主营细分明显不同时（实测 AVGO 的接口同行前 3 是
   TXN / MRVL / ADI，其中 TXN、ADI 是模拟芯片，AVGO 主营 AI 定制芯片与网络芯片），或接口同行的 industry 与目标不一致时
   （实测 MU 的前 3 是 SKHY / SNDK / STX，后两家 industry 为 Computer Hardware），可另选**最多 3 只**同细分行业的同业，
   按同样写法再调一次 metrics(keywords=[S1,S2,S3], categories=["market","fundamentals"], asset_type="tradfi", limit=1, verbosity="concise")。
   返回后同样核对 profile_block.industry。输出里标"自定同业"并逐只写选择理由，与接口同行**分开展示、分开算中位数**，不混成一组。
   外国代码可以直接放进 keywords（2026-10-08 实测 005930.KS / 2408.TW / 285A.T 均未被改写），但报表与市值是当地货币，只引用比率
4. metrics(keywords=["<T>"], query="历史走势", asset_type="tradfi", time_range="13m", limit=290)
   → 13 个月日线（必须传 limit；time_range="1y" 只返回 251 行，算不出 1Y 涨幅）。
     返回约 5 万字符，用代码解析 close 序列。盘中跑时最后一行是**当天未走完的 K 线**（date = 今天、close ≈ 实时价，
     2026-10-08 实测），处理方法见 Step 2
```

**Batch B：技术指标 + 信号**
```
5. metrics(keywords=["<T>"], query="均线 指标", asset_type="tradfi", limit=1)              → RSI(14)、ADX(14)
6. metrics(keywords=["<T>"], query="均线 指标", asset_type="tradfi", period=50,  limit=1)  → EMA50
7. signal(keywords=["<T>"], categories=["insider_trading","institutional","kol_call"],
          asset_type="tradfi", limit=50)                                                   → 三类合计 1 次额度
```
每次技术指标调用都返回全部 9 个指标，按 `indicator` 字段取需要的那个。`period` 参数对 9 个指标同时生效，所以 RSI(14) 取自不传 `period` 的第 5 路。SMA50 / SMA200 直接用第 4 路的日线收盘自算（实测与接口值完全一致），不必再调。
第 7 路用 `limit=50`：内部人和议员交易共用名额，`limit=20` 实测只覆盖约 30 天，⑰ 要的是 90 天（50 行也可能不够，截断自检见下方"取数注意"）。这一路返回约 5.8 万字符（内部人 + 13F + KOL），和第 4 路一样用代码解析，不要整段读进上下文。

**Batch C：研报 + 新闻**
```
8.  metrics(keywords=["<T>"], query="research reports", categories=["fundamentals"],
            asset_type="tradfi", time_range="30d", verbosity="detail")      → subject_reports + mention_reports
9.  news(query="<CompanyName> <TICKER>", sources=["media"], time_range="1m", limit=10, sort_by="relevance")
10. news(query="<CompanyName> <TICKER>", sources=["twitter"], time_range="1w", limit=10)
11. news(query="<CompanyName> <TICKER>", sources=["research"], time_range="2w", limit=10)
```
研报窗口用 30 天、`detail`：研报库比公开新闻晚 1~4 天，7 天窗口常为空；`concise` 下 `by_name` 截到 5 行会截掉本标的（见下方"取数注意"），`detail` 与 `concise` 额度相同，但每页约 9~11 万字符，要用代码解析。第 9~11 路分别供 ⑱ 使用（媒体、推特、research 源文章；正面率只算第 9 路、且不算其中 `source_quality:"research"` 的篇目，后两路只做叙事）；第 7 路的 KOL 和 13F、第 8 路的研报（评级动作 / 目标价变动）供 ⑰ 使用，读法与权重见附件 ⑰。

**Batch D：宏观**
```
12. metrics(keywords=["^VIX"], query="行情", asset_type="tradfi")
13. metrics(keywords=["DGS10"], categories=["macro"], limit=22)
```
`financial_growth` 已含在第 1 路里（最近 4 个**财年**的年度同比：revenueGrowth / netIncomeGrowth / epsgrowth / grossProfitGrowth / operatingIncomeGrowth / freeCashFlowGrowth，另有 fiveYRevenueGrowthPerShare 等五年累计值）。不要把"增长率"并进第 2 路的 query，income_statement 会被挤掉。

取数注意：
- `news()` 查不到相关内容时不返回空，而是返回一批不相关的热门内容。返回里一条都不含目标公司名或代码就是没查到，该路记数据缺口，不要拿这些内容做情绪判断，也不要重试。
- 13F 的 `*_change_percent` 字段恒为 0、不可用；`shares_change == shares` 的行不要当成新建仓；同一机构可能有两行。只引用持仓绝对值和结构，写明"截至 report_period"。
  季末后头几周 `report_period` 会切到刚结束的季度，返回的只是先报的小机构（2026-10-09 实测 MU：report_period 09-30，第一名持股仅占 0.03%，N-152）：此时写"新季度申报未齐，13F 结构不引用"，不要把这些机构当前十大。
- 研报（第 8 路）一页最多 10 篇，subject 卡排在前面，⑰ 要按 `next_cursor` 翻页取全（翻到 `has_more:false` 或卡片日期超出 30 天窗口为止；翻页时 `cursor` 原样回传，其余参数与首页一字不差）：mention 层卡片里带本标的 old→new 目标价变动的也算目标价动作（读卡片顶层的 `revision_summary.by_name[]` 里 `ticker == 本标的` 那一行，先按 `mention_context.mention_ticker` 确认是本标的；N-181①，2026-10-09 实测花旗 09-28 MU 1150→1300 在提及卡里），只看第一页会漏。
  字段路径是卡片顶层的 `revision_summary`，不是 `detail.revision_summary`：`detail` 里没有这个字段，`concise` 也不返回 `detail`（2026-10-09 美东收盘后 MU 两种 verbosity 各翻 5 页实测）。
  所以首页和翻页都用 `verbosity="detail"`（额度与 concise 相同）：`concise` 下 `by_name` 无标记截到 5 行（N-177①），本标的那一行可能被截掉——同次实测高盛 10-02 汇编稿 detail 有 22 行、含 MU 1100→1250，concise 只见 5 行、没有 MU（高盛已由 09-30 的 subject 篇计入上调，家数未受影响）。用 detail 后不再需要"by_name 可能被截断"的注明。
  实测 MU 30 天窗口共 5 页 43 篇（subject 5 + mention 38），5 次额度；detail 前 4 页每页 9.3~10.6 万字符、末页较短，要用代码解析，不要整段读进上下文（2026-10-09 美东 10-08 收盘后按 detail 重跑，页数、篇数、额度与 concise 相同）。
  同次实测 detail 下 11 张卡带 MU 那一行，其中 2 张排在第 5 行之后（高盛 10-02 第 22/22 行 1100→1250、高盛 09-14 第 13/13 行 1100→1100），都没有新增可计的动作，⑰ 结果不变。
  按机构去重时，`institution` 同一家有几种写法（实测 "UBS" / "UBS Securities LLC"、"Morgan Stanley" / "Morgan Stanley Research"），先按母公司归并再去重。同一机构后一篇里本标的目标价没变（old == new，如 1250→1250）不算动作，不覆盖它更早的上调 / 下调（见附件 ⑰）。
- KOL 喊单先按 `symbol == <T>` 筛行（返回里会混入别的标的的帖子），再按 `source_url` 去重。喊单只覆盖最近 24 小时，tradfi 方向字段近乎恒为看多，只报条数和话题。
- 第 7 路返回里**没有 `kol_call` 这一类**（`status` 仍是 `ok`、无 warning）时，是近 24 小时没有本标的喊单，不是调用失败：写"近一日无喊单"，不要重试，也不记数据缺口（2026-10-08 实测 AVGO：合并调用缺这一类，单独调返回 `no_match`，全市场喊单池正常）。
- 内部人只认 Form 4：卖出 = `S-Sale`，买入 = `P-Purchase`，按 `transactionDate ≥ 今天 − 90 天` 过滤；`F-InKind` / `G-Gift` / `A-Award` / `M-Exempt` 不计。带 `_chamber` 的议员交易单列。
  `limit=50` 不保证覆盖 90 天：一笔卖出常按成交价拆成几十行（2026-10-08 实测 MU 的 CEO 两天申报占 46 行，公司内部人行只回到 07-24，90 天窗口起点是 07-10）。
  公司内部人行（不含议员行）最早的 `transactionDate` 晚于"今天 − 90 天"时，写"可见窗口 X~Y（被截断）"，买卖金额按"至少"写。
  申报行本身也会被合并截短（N-187：2026-10-09 实测 MU CEO 8/21 只显示 1 行 258 股）：拿同一申报人、同一 `securityName`、同一 `directOrIndirect` 前后两份申报的 `securitiesOwned`（申报后持股）之差核对，持股减少量大于申报行股数就是被截短了。持股差也不能当卖出股数——同日拆成两份的申报只回一份、同份申报里的授予行会被合并掉（对照 SEC 原件：MU CEO 8/21 实卖 40,000 股，持股差是 48,715）。这时写"8/21 申报后持股较上一份申报（7/24）减少约 4.9 万股（申报行异常）"，该份申报行的股数、金额只当下限（并入合计时按"至少"写），不以持股差替代——持股减少量大于申报行股数也可能是申报之外的转出，行本身没被截短（同日实测 MU CBO 8/18：原件就是 15,000 股一行，4/10 以来另少的 1.8 万股不在任何 MU 的 Form 4 里）。持股减少量小于申报行股数或持股反增是中间有归属入账（2026-10-09 实测 MRVL CEO 8/17、COO 8/3），照申报行写，不算异常。
- 研报的 `subject_reports` 为空、只有 `mention_reports` 时，不能说"有机构专题覆盖"。

### Step 2: 数据预处理

```
涨跌幅 = snapshot.change ÷ snapshot.previousClose × 100      （change 是美元变动量，不是百分比）

多周期涨跌（用日线收盘）:
  1D / 5D / 1M / 3M / 6M / 1Y = 最新收盘 ÷ 1 / 5 / 21 / 63 / 126 / 252 个交易日前的收盘 − 1
  YTD = 最新收盘 ÷ 上一年最后一个交易日的收盘 − 1
  不足 252 行时 1Y 取最早一行，标"≈1Y（N 个交易日）"
  盘中跑（最后一行 date = 今天）：多周期涨跌可以用这一行，标"盘中"；SMA、波动率、最大回撤去掉这一行，
  按最后一个完整交易日算（未走完的一天会被当成一个完整日收益）

SMA50 / SMA200 = 最近 50 / 200 个收盘的平均

年化波动率、最大回撤（风控经理要用）:
  对日线 close 算对数收益 ln(close_t ÷ close_{t−1})，年化波动率 = 日收益标准差 × √252。
  有代码执行工具就用它算；没有就对最近 60 个 close 手算相邻收盘涨跌，并标"估算值"。
  ⚠️ 不要用日线的 changePercent / change：它们是当日收盘对当日开盘，不是对前收。实测用它估出的年化波动率
  是 29%（真实 38%），仓位上限会被高估约 30%
```

### 数据可得性对照（先看这张表，再让分析师开工）

`01_agent-prompts.md` 里各分析师"关注数据"是按理想情况写的，其中一部分接口**拿不到**。拿不到的项，该分析师必须写"数据不足"并相应调低置信度，**不许凭记忆补数字**。

| 分析师框架里要的 | 实际可得 |
|---|---|
| 三表 5 年、利润率 5 年趋势 | ❌ 三表只有最近 **4 个季度**（把 limit 调大、query 写"年度"也一样）。利润率只能看季度环比和 TTM 比率 |
| Revenue 3 年 / 5 年 CAGR | ✅ 第 1 路的 `financial_growth`：用最近 3 个财年的 `revenueGrowth` 连乘开方得 3 年 CAGR；5 年看 `fiveYRevenueGrowthPerShare`（**每股口径的五年累计增幅**，是倍数增量——12.12 即 +1212%，不是年化，引用时写明）|
| 最近 4 季度 Beat 率 | ❌ 只有**最新一季**的实际对预期 |
| 同比增速 | ⚠️ **年度**同比有（第 1 路的 `financial_growth`，4 个财年）；**季度**同比没有——4 季窗口里没有去年同期 |
| DCF | ✅ `valuation_block.dcf`。与现价相差 5 倍以上判失效，不进任何输出（亏损期 DCF 会算崩）。安全边际 = `dcf ÷ 表头价 − 1`（表头价 = 实时价，非交易时段为常规收盘），不用 `dcf["Stock Price"]`（不是表头价，见调用约定）|
| ROE / ROIC / EV/EBITDA / PE / PEG / 毛利率 / D/E / 流动比率 | ✅ `key_metrics_ttm` + `ratios_ttm` |
| 分析师远期预期、Forward PE | ⚠️ `analyst_estimates` 可能缺当前财年、只有较远的财年，且远期数字不自洽（实测 NVDA FY2030 高于 FY2031，后者只有 9~10 位分析师）。Forward PE = 现价 ÷ 最近的、`numAnalystsEps ≥ 20` 的财年 epsAvg，并写明是哪个财年。同一财年可能有两行（`date` 相差几天，2026-10-09 实测 MU 的 FY2030 有 2030-09-03 / 2030-08-28 两行，分析师 5 位 / 1 位），按 `numAnalystsEps` 多的那行算，另一行不用 |
| PEG | ⚠️ 统一口径见 `01_agent-prompts.md` 开头，**先判是不是周期股**（是就直接走下面的"周期股"一句，不再算历史增速）；不是周期股时：TTM P/E ÷（最近财年 epsgrowth × 100）；最近财年 epsgrowth < 0 或 > 100% 时改用 3 年 EPS CAGR 作分母，仍不可得、或 4 个财年里有一年 epsgrowth < −1（EPS 转负，连乘失真）、或 3 年 CAGR 仍 > 100% 时标"PEG 不适用"、不进 ⑥⑦⑲ 的判据。周期股改用分析师预期 EPS 增速作分母，取不到同样"不适用"（判定见附件开头）。附注服务端值 |
| 行业相对估值 | ⚠️ 第 3 路只有同行的 `ratios_ttm`（P/E、P/S、P/B、利润率；服务端 PEG 不可比）；同行 EV/EBITDA 不返回，写"数据不足"。接口同行细分不符时可加"自定同业"（最多 3 只，写理由，分开展示）|
| 维护性 CapEx | ❌ 只有总 CapEx，所有者盈余用总 CapEx 近似并注明 |
| 净现金 / 净负债 | ⚠️ 不要用 `netDebt`（只扣现金等价物）。统一用 `cashAndShortTermInvestments − shortTermDebt − longTermDebt` |
| 企业价值 | ✅ `key_metrics_ttm.enterpriseValueTTM`。不要用 `enterprise_values`：它是上一个财年末的快照，实测比当前低 20% |
| SBC / 商誉 / 应收 / 递延收入 / 有形账面 / WACC / 分红历史 / 客户集中度 / 预期修正 | ❌ 接口不提供，写"数据不足"；ROIC 对 WACC 只能写"ROIC = X%（WACC 不可得）" |
| Beta、行业、公司简介 | ✅ `profile_block` |
| 内部人交易、13F、KOL、新闻 | ✅ 见 Batch B / C |
| 研报评级动作 / 目标价变动（⑰ 用）| ⚠️ 第 8 路：subject 层有 `rating_action` / `revision_summary`；mention 层带本标的 old→new 的同样算目标价动作，否则只能用 `matched_asset_target_price`（本标的自己的目标价，可能为 null）和 `mention_direction`。研报库比公开新闻晚 1~4 天，嵌套列表截顶（N-141）|
| RSI / EMA50 | ✅ 见 Batch B |
| SMA50 / SMA200 | ✅ 第 4 路日线自算 |

**两个 EPS 口径不同**：`earnings_surprise.actual_eps` 是分析师口径（通常是调整后），财报口径取 `financial_statement.epsDiluted`（GAAP 稀释），实测同一季可以差 10% 以上。引用"超预期"时注明是分析师口径；两者符号相反时必须点明"GAAP 为亏损"。`actual_revenue` 为 null 时 `revenue_surprise_pct` 会显示 -100，那是缺数据。

**非经营损益**：任一季 `|totalOtherIncomeExpensesNet| ÷ incomeBeforeTax > 10%` 时（取绝对值，收益和损失都算），在数据池里标"利润含大额非经营损益"（实测 NVDA 某季非经营收益占税前利润 23%，GAAP EPS 反而高于分析师口径；AVGO 各季是 −4.7 亿 ~ −7.8 亿的非经营损失，占税前利润 5.1%~9.3%，未触发）。涉及净利率、P/E、ROE 的分析师须注明口径。

### Step 3: 19 位分析师独立研判

先 Read `01_agent-prompts.md`。每位分析师按自己的哲学和关注的数据子集，**独立**给出：
- **信号**: Bullish / Bearish / Neutral
- **置信度**: 0-100
- **核心理由**: 2-3 条，每条都要引用 Step 1 取到的具体数字
- **缺口是否决定信号**: 是 / 否——如果把拿不到的数据补上，这位分析师的信号可能改变方向，就填"是"

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

**数据覆盖闸**：Batch A 的第 1 路没取到（基本面和快照都没有），或者"缺口是否决定信号 = 是"的分析师 ≥ 7 位，就**不输出模拟决策**，改为说明数据覆盖不足并列出缺口。

**数据簇提醒**：19 票其实建立在约 6 组数据上（估值 ①②④⑤⑨⑫⑭ 共用 P/E、DCF、P/B；质量 ③⑧⑮；增长 ⑥⑦⑬⑲；宏观 ⑩；风险 ⑪；市场 ⑯⑰⑱）。组合经理权衡时按数据簇看分歧，不要把同一组数据的多张同向票当成多份独立证据。

## 输出格式

```
## 🎯 [TICKER] 多 Agent 综合分析 — [CompanyName]

> 以下是 19 个模拟分析框架对公开数据的研判汇总，用于梳理多空论据，不构成投资建议。人名仅为分析框架的代称，不代表其本人观点；仓位为方法演示。

### 基本信息
行业: [sector] / [industry] | 市值: $[marketCap] | 价格: $[price]（[自算涨跌%]，[实时 / 常规收盘]）| Beta: [beta]
同行（接口）: [P1/P2/P3 的 P/E、P/S、P/B、利润率及中位数]
自定同业: [S1/S2/S3 同上 + 每只的选择理由；没加就删掉这一行]

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
- 仓位上限: **X%**（年化波动率 XX%[，估算值]；VIX XX）［算出 < 2% 时写"**观望**（算出 X.X%）"，不硬凑到 2%］
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
- 票数最多的方向（含 Neutral）不到 12/19 时，在汇总行标"分歧显著"（与附件里"多数 Bullish ≥ 12/19"是同一条线）
- 决策是**模拟结论**：开头的声明行必须保留；不给具体目标价，不承诺收益
- 触发了"数据覆盖闸"就不出模拟决策
- 内部人申报行被截短（持股减少量大于申报行股数，N-187）时，写持股变化并注明"申报行异常"，不把持股差写成卖出股数
