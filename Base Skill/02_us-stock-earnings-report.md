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
- **财报通常盘后发布**：`metrics` 在非交易时段返回的是上一个常规收盘（`_quote_session:"regular_inactive"`），**盘后那根跳涨或跳水不在返回里**。此时 `price` 标"常规收盘"，盘后涨跌取自新闻并标"据 [来源]·盘后"，两个数分开写。`_quote_session` 不是每只都有（2026-10-08 实测 ACN、MU 的快照都没有这个字段），缺失时按 `as_of` 是否落在美东常规时段（9:30–16:00）判"实时 / 常规收盘"。
- **盘中运行时，日线最后一行是当天还没收盘的 K 线**（2026-10-08 实测：美东 10 点调用，第 4 路最后一行 `date` 就是当天，成交量只有平日的零头）。用它算的 1D / 5D 等动量和"至今累计"一律标"盘中"。当天这一行的 `close` 与调用 A 快照的 `price` 不一致（2026-10-08 实测 PEP 同一批调用：日线当天 125.86、快照 125.16，1D 读成 +1.72% 对 +1.16%），盘中的"最新收盘"一律换成调用 A 的 `price`，保证基本信息里的价格和动量表对得上。
- **盘中估值按前收算**：`ratios_ttm` / `key_metrics_ttm` / `dcf` 盘中仍按前收计算（2026-10-08 实测 PEP `dcf["Stock Price"]` 123.73 = `previousClose`，快照已是 125.16），引用 PE / PS / DCF 时写"按前收"。

## 返回结构（字段名以这里为准）

**调用 A — 快照 + 核心基本面**：`metrics(keywords=["<T>"], asset_type="tradfi")`（不写 query）

| 位置 | 内容 |
|---|---|
| `results.market.snapshot[]` | price / change / previousClose / dayHigh/Low / yearHigh/Low / marketCap / exchange。**`change` 是美元变动量**，百分比自己算 `change ÷ previousClose × 100` |
| `fundamentals.concise[].fiscal_quarters[0].earnings_surprise` | **最新一季**的 `actual_eps` / `estimated_eps` / `eps_surprise_pct` / `actual_revenue` / `estimated_revenue` / `revenue_surprise_pct` / `report_date` |
| `fundamentals.concise[].fiscal_quarters[0].financial_statement` | 同一季的 `revenue` / `eps`（基本 EPS）/ `epsDiluted`（GAAP 稀释 EPS）/ `netIncome` / `period_end` |
| `…macro.calendar` | 忽略：ticker 会被模糊匹配到无关事件（实测 MU 匹配成 "Fed Musalem Speech"）|
| `…eps_trend[]` | 最近 4 季**基本** EPS（与 `financial_statement.eps` 相同，不是 GAAP 稀释；2026-10-08 实测 ACN 3.31、MU 33.36）。趋势表的 EPS 用调用 B 的 `epsDiluted` |
| `…balance_sheet[]` / `cash_flow[]` | 最近 4 季 |
| `…profile_block` | sector / industry / ceo / beta / ipoDate / description |
| `…valuation_block.ratios_ttm` | PE / PS / PB / PEG / 毛利率 / 净利率 / D/E 等 |
| `…consensus_price` | 目标价共识 / 最高 / 最低 / 中位 |
| `…next_earnings_estimate` | 下次财报日期与预期 |

**调用 B — 利润表 4 季**：`metrics(keywords=["<T>"], query="财报 利润表", categories=["fundamentals"], asset_type="tradfi", limit=4)` → `income_statement[]`（revenue / grossProfit / operatingIncome / netIncome / eps / epsDiluted）

**调用 C — 分析师与同行**：`metrics(keywords=["<T>"], query="分析师评级 同行 DCF", asset_type="tradfi", limit=10)` → `analyst_grades[]`、`analyst_estimates[]`（远期财年的 EPS / 营收预期）、`stock_peers[]`、`valuation_block.dcf` / `key_metrics_ttm`（ROE、EV/EBITDA 等）

调用 C 的三个读法陷阱（2026-10-03 实测）：
- `analyst_estimates` **可能只有较远的财年**（MU 只返回 FY2029、FY2030，没有 FY27/28），而且同一财年可能有两行、数字不同。按 date 取最近两个财年；同一财年多行（日期差 < 10 天）取 `numAnalystsEps` 大的一行并注明；近两年缺失写"数据不可用"，近端用调用 A 的 `next_earnings_estimate` 代替。
- `stock_peers` **按代码字母序排列、没有行业字段，不保证是业务同业**（10-03 MU 给出 AMAT / ARM / CRM / CSCO / IBM，没有一家存储公司；2026-10-08 再测已换成存储同业，但混有外国代码，同一公司多地上市各占一行——GigaDevice 的 `3986.HK` 与 `603986.SS`，`mktCap` / `price` 是当地货币——Kioxia 的 mktCap 29.4 万亿是日元）。按公司名排除明显的非同业，同一公司只留一行；不要拿 `mktCap` 跨币种排序；剩下不足 3 家时写"接口同行不可靠"。
- PEG < 0.1 或 > 10 时标"增速极端，无参考意义"。

### 五条财报陷阱（判定 Beat/Miss 前必读）

1. **只有最新一季有"实际对预期"**。`fiscal_quarters` 只返回一季，所以"是否连续超预期"无从判断——不要从 `eps_trend` 里推。
2. **两个 EPS 口径不同**。`earnings_surprise.actual_eps` 是分析师口径（通常是调整后），**财报口径一律取 `financial_statement.epsDiluted`（GAAP 稀释）**——`eps` 是基本 EPS，只作参考（实测 MU 分析师口径 33.42、基本 33.36、稀释 32.87，用基本 EPS 会把口径差距低估成几乎为零）。实测 NVDA 同一季分析师口径 2.22、财报口径 2.46。两者不相等时：Beat/Miss 用前者判，并标注"调整后口径"；两者**符号相反**（一正一负）时必须点明"该超预期为调整后口径，本季 GAAP 为亏损"。不要把两个序列混在一张趋势里。
3. **缺失会伪装成 -100%**。`actual_revenue` 为 null 时，`revenue_surprise_pct` 会显示 -100——那是缺数据不是营收归零。`actual_revenue` 非 null 才读 surprise。
4. **财报当晚或次日数据可能还没更新**。满足任一条就判"未更新"：① `earnings_surprise` 整块不存在；② `next_earnings_estimate.date` ≤ 今天，且不等于 `report_date`（说明预定的财报日已过、但这里还是上一季）；③ `next_earnings_estimate.date` 比 `report_date` 晚 150 天以上（N-163：下次财报日往往先滚到下一季，`fiscal_quarters` 还停在上一季，这时 ② 不触发；正常间隔约 3~4 个月，2026-10-08 实测 PEP 10-08 → 2027-02-02 为 117 天）。
   三条都不满足才算已更新（2026-10-08 实测 PEP 盘前发布、美东上午 11 点调用时 `report_date` 已是 10-08，与财报日历逐项一致）。
   未更新时按顺序回退，**不要拿上一季顶替**：
   - **财报日历**：`metrics(query="earnings calendar", asset_type="tradfi", date_from=<财报日>, date_to=<财报日>, limit=50)`。`keywords` 对日历不起过滤作用，在返回里**按 `symbol=="<T>"` 自己筛**；不要传 `country="US"`（它按注册地过滤，会漏掉 ACN 这类爱尔兰注册的美股）。用 `epsActual / epsEstimated`、`revenueActual / revenueEstimated` 自算 surprise，标"据财报日历·基本面块未更新"。日历行和基本面块同属一个数据源（实测 MU 两者逐项一致）。
     日历按代码字母序排，**单页 50 行常常翻不完一天**：本页没有 <T> 且 `meta.pagination` 里 `has_more` 为 true 时，带 `next_cursor` 原样重发、其余参数不变，直到找到或翻完，**最多翻 5 页**（含第 1 页），每页 1 额度（2026-10-08 实测：10-01 共 37 行，ACN 在第 1 页；09-30 超过 200 行，MU 在第 4 页；10-08 超过 250 行，PEP 在第 5 页第 6 行，第 5 页末行已排到 S 开头——T 以后的代码在这种日子翻满 5 页也到不了，直接转新闻）。同一公司的外国挂牌行（ACN 的 `0Y0Y.L`、MU 的 `MU.TO`）数字不同，只认 `symbol` 完全等于 <T> 的那行。
   - **新闻原文**：日历翻满 5 页仍找不到 <T>，或日历里没有时，转 `news()`：先核实财报日（是否已发布、哪天发布），再取媒体原文的实际值和预期值，标来源；新闻里的预期值可能和接口口径不同（实测 MU 媒体 EPS 预期 31.52、接口 31.77），不要混算。
5. **4 季窗口算不出同比**。最新季的去年同期不在返回里，趋势表只做环比；同比需要外部来源，别把 3 季前那季当去年同期。

## 执行步骤

### Step 1: 数据采集（每批 ≤4 路并行）

**Batch 1**
```
1. metrics(keywords=["<T>"], asset_type="tradfi")                                             # 调用 A
2. metrics(keywords=["<T>"], query="财报 利润表", categories=["fundamentals"],
           asset_type="tradfi", limit=4)                                                      # 调用 B
3. metrics(keywords=["<T>"], query="分析师评级 同行 DCF", asset_type="tradfi", limit=10)        # 调用 C
4. metrics(keywords=["<T>"], query="历史走势", asset_type="tradfi", time_range="13m", limit=290) # 13 个月日线
```
第 4 路**必须传 `limit`**——默认只返回 10 条。用 13 个月而不是 1 年：`time_range="1y"` 实测只返回 251 行，往前第 252 个交易日不存在，算不出 1Y 涨幅。这一路返回约 5 万字符，会超出工具输出上限被写进本地文件，用脚本解析 close 序列即可。**不要用日线里的 `change` / `changePercent`**——它们是当日收盘减开盘，不是对比前一天收盘。

**Batch 2**
```
5. news(query="<CompanyName> <TICKER>", sources=["media"],
        time_range="2w", limit=10, sort_by="relevance")                      # 媒体报道
6. news(query="<CompanyName> <TICKER>", sources=["twitter"], time_range="1w", limit=10)   # 推特风向（可选）
7. signal(keywords=["<T>"], categories=["insider_trading","kol_call"],
          asset_type="tradfi", limit=50)                                      # 内部人 + KOL，1 次额度（不拉 13F，见下）
8. metrics(keywords=["<T>"], query="research reports", categories=["fundamentals"],
           asset_type="tradfi", time_range="30d", verbosity="concise")        # 机构研报
```
- **财报日在 3 天内时，第 5 路再补一次 `time_range="1d"`**（其余参数不变；`news()` 不扣额度），两次结果按 `source_url` 合并。2 周窗口按相关度排，财报当天的报道会被前两周的旧稿挤掉：2026-10-08 实测 PEP 盘前发布后 5 小时，2w 的 10 条里只有 1 条财报后的报道，"下调利润展望"（Bloomberg）一条都没有；1d 的 10 条里去掉模板稿还有 4 条与这次财报相关，包括这条。公司指引、盘前 / 盘后涨跌取自这批。
- `news()` 的 query 用"公司名 + 代码"两个词（如 `"Apple AAPL"`），不写"earnings 影响 解读"这类词。
- `news()` 查不到相关内容时不会返回空，而是返回一批不相关的热门内容。**返回里一条都不含目标公司名或代码，就是没查到**，记数据缺口，不要重试，也不要拿这些内容做情绪判断。
- `signal()` **必须显式传 `categories`**——只传 ticker 现在返回空（旧记载"省略 categories 自动展开"已失效）。多类一起传仍只计 1 次额度。
- 第 7 路 `limit` 按类分别生效，**用 50 不用 20**：内部人一份申报会拆成很多行，20 行只覆盖一两个月（2026-10-08 实测 MU 的 CEO 一份 Form 4 拆成 16 行，20 行只回溯到 08-21；50 行回溯到 07-10）。返回可能超出工具输出上限被写进本地文件（含 13F 时实测约 7 万字符），用脚本解析。
- **KOL 先筛 `symbol=="<T>"`，再按 `source_url` 去重**：kol_call 不按标的过滤（实测查 MU 返回 20 行，只有 5 行是 MU，其余 15 行是别的票，有的原帖根本没提 MU），一条推文还会拆成多个标的的多行。tradfi 喊单的方向字段近乎恒为看多，只报条数和话题，不报多空比。喊单上游只覆盖最近约一天，一律写"近一日"。**返回里整个没有 `kol_call` 这一类**，就是近一日没有该标的的喊单（2026-10-08 实测 ACN：请求里带了 kol_call，返回里只有其他类，`status:"ok"`、无 warning；N-166），写"近一日无喊单"，不要当接口失败重试。
- **内部人只认 Form 4**：卖出 = `S-Sale`，买入 = `P-Purchase`；`F-InKind` / `G-Gift` / `A-Award` / `M-Exempt` 和 Form 3 不计。带 `_chamber` 字段的是议员交易，单列。覆盖区间按返回里最早的 `transactionDate` 写；不足 3 个月时写"覆盖 MM-DD 起"，不要写成"近 3 个月"。
- **不使用 13F**（与社群 c4 / c6 一致，第 7 路不传 `institutional`）：季末后头几周会切到申报还没交齐的新季度，持仓与变化率都不可靠（N-152 / N-166；2026-10-08 实测 ACN 已切到 09-30，只剩 1 家且持股 0，同时 MU 仍是 06-30；`*_change_percent` 全为 0 而 `shares_change` 不为 0；同一机构出现两行）。报告里不写机构持仓。
- 研报的 `subject_reports` 是专题报告，`mention_reports` 只是别的报告里提到它；`subject_reports` 为空时不能说"有机构专题覆盖"。研报库比公开新闻晚 1~4 天，财报前瞻常落在 7 天之外，所以窗口用 30 天（实测 MU 7 天 0 篇、30 天专题 1 篇提及 9 篇）；输出区分"财报前 / 财报后"。
- 新闻摘要里的价格数字可能被截断（实测出现"settling at $1"），价格一律以 metrics 为准。

**Batch 3：宏观背景（按行业）**

从 `profile_block.sector` / `industry` 取行业，按下表调用。FRED 指标带 `categories=["macro"]`，不与行情标的放在同一次调用里。

| `sector`（接口返回的原文）| `industry` 含 | 调用 |
|---|---|---|
| Technology / Communication Services | — | `metrics(keywords=["DGS10"], categories=["macro"], limit=5)` + `metrics(keywords=["^VIX"], query="行情", asset_type="tradfi")` |
| Technology | Semiconductors | 上一行两条，另加 `metrics(keywords=["PCEPILFE"], categories=["macro"], limit=13)`（指数值，自算同比 = 最新 ÷ 12 个月前 − 1）|
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
用调用 B 的 4 季利润表算营收和 EPS 的环比，看是加速还是减速。相邻两季 `date` 间隔与其他季相差 20 天以上时（财季长短不一，如 PEP 前三季各 12 周、第四季 16 周），那一格环比标"季长不同"，不判加速减速（2026-10-08 实测 PEP Q1 对 Q4 营收环比 −33.7%，主要是少了 4 周）。利润表里 `incomeBeforeTax` / `incomeTaxExpense` 偶有错误（实测 MU 营业利润 443 亿而税前利润 148 亿、所得税 −229 亿），不引用这两项。

#### 维度二：媒体覆盖与情绪

对第 5 路返回的文章，先剔掉与该公司无关的，再剔掉不算"相关报道"的两类：没有正文的行情页（如 Barron's 的个股报价页）和 Zacks / GuruFocus 等模板稿（标题套路固定，按来源名认；`source_quality` 标 `research`，`category` 有时标 `research`、有时为空——2026-10-08 实测 PEP 的 Zacks 财报速递稿 `category` 为空。247 Wall St 这类有正文的评论稿也标 `research`，不要按这个字段一刀切）——它们不计入篇数，也不参与情绪统计。再逐篇判断：情绪偏向、高频话题、代表性报道（标题 + 来源 + 链接）。情绪结论标"Claude 推断"。

#### 维度三：宏观一致性 + 价格动量

用一年日线自算：
```
1D = 最新收盘 ÷ 前一日收盘 − 1
5D / 1M / 3M / 6M / 1Y = 最新收盘 ÷ 5 / 21 / 63 / 126 / 252 个交易日前的收盘 − 1
YTD = 最新收盘 ÷ 上一年最后一个交易日的收盘 − 1（市场惯例；实测 MU 两种算法差 36 个百分点）
不足 252 行时 1Y 取最早一行，标"≈1Y（N 个交易日）"
```
财报后反应按发布时段定首日和基准（时段看新闻里的 "before the opening bell" / "after the close"，查不到就写"时段未知"并两种都列）：
```
盘前发布：首日 = 财报日；基准 = 财报日前一交易日收盘
盘后发布：首日 = 财报日的下一交易日；基准 = 财报日收盘
跳空 = 首日开盘 ÷ 基准 − 1；首日 = 首日收盘 ÷ 基准 − 1；至今累计 = 最新收盘 ÷ 基准 − 1
```
（2026-10-08 实测：ACN 10-01 盘前发布，首日就是 10-01；MU 9-30 盘后发布，若按"财报日前一交易日"取基准，首日会落在财报公布前的 9-30，读成 0.0%，实际反应在 10-01，收盘 +3.0%。）
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
财报后反应: [盘前 / 盘后发布]，首日 [开盘跳空% / 收盘%]，至今累计 [%]（日线自算，首日与基准见维度三）
下季: 预期 EPS [epsEstimated] / 营收 [revenueEstimated]（next_earnings_estimate）；公司指引 [据新闻，没有写"未检索到"]

### 价格动量
| 1D | 5D | 1M | 3M | 6M | YTD | 1Y |
|----|----|----|----|----|-----|-----|

### 最新季度财报 [fiscal_period]（发布于 [report_date]）
| 指标 | 实际 | 预期 | 差异 | 判定 |
|------|------|------|------|------|
| EPS（分析师口径）| $X.XX | $X.XX | +X.X% | ✅ Beat |
| EPS（GAAP 稀释）| $X.XX | — | — | 参考 |
| 营收 | $X.XB | $X.XB | +X.X% | ✅ Beat |

[两个 EPS 不相等时] ⚠️ 两个 EPS 口径不同：分析师口径 $X.XX，GAAP 稀释 $X.XX
[数据取自财报日历时] ⚠️ 基本面块尚未更新，本季数字据财报日历
[符号相反时] ⚠️ 该超预期为调整后口径，本季 GAAP 为亏损

### 趋势（最近 4 季，财报口径）
| 季度 | 营收 | 环比 | 净利润 | EPS | 环比 |
|------|------|------|--------|-----|------|

> 4 季窗口算不出同比；历史各季的"实际对预期"接口不提供。

### 关键比率 (TTM)
PE: XX.X | PS: X.X | PEG: X.X | ROE: XX.X% | D/E: X.X | 毛利率: XX.X%  [盘中运行时注明"按前收"]

### 📈 分析师预期（analyst_estimates）
| 财年截止 | 预期 EPS | 预期营收 | 覆盖分析师数 |
|------|---------|---------|---------|

目标价共识: $XXX（区间 $XXX – $XXX）｜DCF: $XXX [DCF 与现价相差 5 倍以上时不展示，标"DCF 失效"]

### 🏢 公司画像
- 主营: [description 摘要，≤200 字]
- 同行: [stock_peers 按调用 C 的陷阱筛过后的前 5]

### 📊 分析师评级（analyst_grades 最近 10 条）
- 维持 / 上调 / 下调各几家，列出上调和下调的机构与日期

### 🧭 信号面
- 内部人: [覆盖区间（最多近 3 个月）内 Form 4 主动买入 / 卖出笔数与金额]；议员交易另列
- KOL（近一日）: [按本标的筛选并去重后 N 条；主要话题；没有就写"近一日无喊单"]
- 机构研报: [专题报告 N 篇 / 仅被提及 N 篇；最新催化与主要保留意见]

### 📰 媒体覆盖（近 2 周，相关报道 N 篇）
情绪判断（Claude 推断）: [偏正面 / 中性 / 偏负面]
正面: X 篇 | 负面: X 篇 | 中性: X 篇
热门话题: [关键词]
推特热议（第 6 路，Claude 推断）: [话题，N 条]

代表性报道:
- "[标题]" — [来源]（[日期]）

### 🌐 宏观背景
- [宏观指标]: [值，数据日期] → 对 [sector] 的含义（Claude 推断）

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
