# Followin MCP 现行用法与已知问题（SSOT）

> 仓库内所有 Skill（`Base Skill/` 01–06、`Community Skill/` c1–c6、Research Reader、Twitter Workflow、Premarket、Earnings Screener、Trader Diligence、Feed Manager、Crypto Watchlist）调用 Followin MCP 时的单一事实源。各 Skill 内联的规则是本文件的镜像，**冲突时以本文件为准**。
> 本机 `~/.claude/references/followin-mcp-caveats.md` 是指向本文件的软链接，`~/.claude/commands/` 下的 Skill 也读这里。
> 官方意图路由见 [`followin-routing-primer.md`](./followin-routing-primer.md)；primer 没覆盖或与实测不符的细节，以本文件为准。
>
> **文件结构（2026-10-12 重组）**
> - **一、现行用法**：现在该怎么调、怎么读。**先读这一节。**每条规则后面的编号是依据。
> - **二、问题登记**：全部编号条目，按工具和主题分组。
> - **三、归档**：已修复或作废的条目，回归自查用。
> - **附表 A**：中文指标名 → FRED series_id；**附表 B**：旧「红线 1~12」编号对照。
>
> **怎么查**：直接搜编号「N-xx」。编号只增不改、不复用，N-73~N-77 是空号；全仓有七百多处「见 N-xx」引用。条目被合并时，次条保留为一行「→ 见 N-yy」。
> **条目标题末尾的〔A〕〔B〕…** 表示这个坑该由谁消灭：**A** 服务端改默认值 · **B** 服务端在返回里提示 · **C** 写进工具描述 · **D** 上游数据特性，修不了 · **E** 只是我们自己的流程纪律。「·已文档化」表示工具描述已经写明。标题里的 🔴 表示照常读会得出错误结论。
> 条目「依据」里的「GAP Uxx」「A~F 段」指 10-12 复核明细（不入库），读者以日期和 request_id 为准。
>
> **上次全量复核**：2026-10-12，生产端逐条实测 248 条（明细不入库）。下次复核前，以条目里标的日期判断新旧。

## 维护纪律

1. MCP 行为变了：先改「问题登记」里的原条目 → 再同步「现行用法」→ 再 sweep 各 Skill 的内联镜像（`tools/sweep-check.sh`）。
2. **订正旧结论就改原条目**，不要在别处追加「订正 N-xx」；被推翻的说法在原条目里留一行「历史：」。
3. 新问题先看能不能并进已有条目；确实要新号，从 **N-191** 起。
4. 判断 schema 有没有改，看原始 `tools/list`（本机 `docs/internal/probes/mcp_client.py` 可直接请求，该目录不入库），不要看客户端加载后的版本——Claude Code 会把 `["null","array"]` 这类联合类型丢掉，看起来像没声明类型。
5. 修复销案：条目移到「三、归档」，编号不删；Skill 里的规避动作同步撤掉，旧规避有时会主动降低产出质量。

## 当前最需要设防的问题

| 风险 | 编号 | 一句话 |
|---|---|---|
| 🔴 方向会翻 | N-171 | trader_position 的组汇总按返回的行重算，`limit` 小时多空方向可以完全相反，无提示 |
| 🔴 整天漏财报 | N-22 / N-17 | 市场级财报日历两种写法都会漏掉大票；个股财报日以 `next_earnings_estimate` 为主（估算值，会跳季，见 N-149） |
| 🔴 同名资产混流 | B-18 / N-51 | 不传 `asset_type` 时，BTC 混灰度 ETF、AAPL K 线混代币化 AAPL，`symbol` 字段相同 |
| 🔴 幽灵仓 | N-59m / N-59q | 平仓不回流、`is_active` 恒 true；名义金额全空的组显示「多空平衡」 |
| 🔴 实体被静默丢弃 | N-97 / N-59e / N-95 | 中文公司名、人名、机构名查不到时不报错，返回通用榜，`status:"ok"` |
| 🔴 兜底冒充命中 | N-35 | news 查不到时返回不相关内容，不返回空 |
| 内部人数据来回变 | N-187 | 申报行会被合并截短又恢复，10-08 到 10-12 变了 4 次 |
| 美股 KOL 共识不成立 | N-100 | 美股喊单几乎全是看多、样本极薄，只能做主题发现 |

---

# 一、现行用法

> 2026-10-12 按生产端全量实测重写，取代旧版「12 条调用红线」。Skill 里引用的「红线 N」按附表 B 查现在的位置。

## 通用（所有工具）

1. **实体放 `keywords` 数组，意图写 `query`，类别写 `categories`。** 数组写法生产端已正式支持（N-105）；在 Claude Code 里看到这几个参数没有类型，是客户端把联合类型丢了，照常传数组。不要把代码塞进 query 串：query 串会静默丢掉 `*USD` 商品代码和部分小票，还会把英文普通词（EMA、day、KOL、beat）当成代码（N-23、N-69、N-106）。
2. **`asset_type` 必传**：美股、大宗、宏观传 `tradfi`，加密传 `crypto`。不传会把同名资产混在一起，`symbol` 字段还一样（B-18、N-51）。news 的例外见下。
3. **每批 keywords 最多 5 个**，超出的被截断并报 `keyword_count_over_max`。有些代码会被服务端展开成好几个（CL→CL=F，BABA→$BABA / BABA / 9988.HK，UNRATE→别名），挤掉后面的代码；这类代码单独一批（N-36、N-107）。
4. **调用后拿返回的 symbol 和请求列表做差集。** 有些代码会被静默丢掉（`^DXY`、CXMT），有些被改写成别的资产（ANTA→2020.HK，NG→NG=F），有些会多带出不相干的块，`status` 照样是 ok（N-121、N-159、N-86、N-59g）。
5. **看 `meta.filters_applied.keywords` 判断实体有没有被认出来。** 公司名（中、英、韩文都可能）、人名、句柄会被丢成 null，然后返回通用榜（N-97、N-59e、N-95）；机构名可能被错解析成别的代码（Vanguard→5347.TWO），要核对解析出来的代码是不是你要的（N-152）。
6. **读 `meta.warnings` 要按 `reason` 和 `keyword` 对上号**：`default_fanout_fallback` 多半和实际返回无关（N-21）；`kw_not_canonical` 在正常返回上也会出现，但如果对应的 keyword 没有返回行，就是没认出来（N-105、N-107）；不带代码的研报榜上出现 `ticker_unresolved` 是正常的（N-154）。`keyword_count_over_max`、`parameter_partial`、`no_match`、`asset_type_filter_emptied` 说明结果不完整。研报的截顶提示在 `research_reports[0].warnings`，不在 `meta.warnings`（N-183⑥）。
7. **额度**：空结果也扣 1 次（N-156、N-10）；news 不扣；twitter 是单独的额度池（N-188⑥）。
8. **时间窗**：`time_range` 写成 `<数字><单位>`（如 `7d`）。服务端不会从 query 文字里推时间窗。同时传 `date_from` / `date_to` 时绝对区间优先，`time_range` 被静默丢掉（N-153）。
9. **`verbosity`**：concise 200 / standard 600 / detail 2000 字，只截自由文本，数字字段不截；不认识的值按 standard 处理（N-27、N-85）。

## metrics · 行情

- **快照**：standard 没有涨跌幅百分比，只有 `change`（金额）和 `previousClose`；要百分比用 `verbosity="detail"` 的 `changePercentage`，或自己算。盘前、盘后的 `changePercentage` 是上一交易日的涨跌，不是延长时段的涨跌；延长时段价看 `extendedHoursQuote`（N-47、N-150）。
- **交易时段**：非交易时段的 `price` 是上一个常规收盘，个股和 ETF 多半带 `_quote_session:"regular_inactive"`；延长时段只有 `extendedHoursQuote` 的买卖报价，没有成交价，而且这个字段时有时无；指数和部分小盘股不带时段标记；盘中个股普遍没有 `_quote_session`（N-48、N-150、N-157）。
- **历史 K 线**：写 `categories=["market"]`、query 写历史意图（如 `daily price history`）、带 `time_range`，按需要的根数设 `limit`（不设时每只只给 10 行）。只传 time_range、不写历史意图，只返回快照（N-132）。美股用数组写法时不带 `interval` 返回日线；crypto（如 HYPE）和旧的 query 串写法默认给小时线（N-178①、N-182④、N-179③）。
- **日线涨跌字段是收盘对开盘**，不是对前收；涨跌幅、波动率一律用相邻两天收盘自己算（N-131）。
- **最后一根可能没收盘**：盘中的日线和技术指标、商品日线都可能带当天未收盘的一根；日期等于今天且市场未收盘就剔除，不要靠成交量判断（N-158、N-179③）。
- **技术指标**：一次调用返回该资产的全部指标（美股 9 个、crypto 13 个；不传 `asset_type` 时两块混在一起共 21 个），按 `indicator` 字段筛；`limit` 控制每个指标的观测数。crypto 附带的价格随 query 变：写「技术指标」时附 31 行日线（约 2 千字符），按指标名写时附 721 行小时价（约 4 万字符）（N-169）。
- **商品和外汇**：黄金 `GCUSD`、白银 `SIUSD`、WTI `CLUSD`、布油 `BZUSD`、美元指数 `DXUSD`，一律走数组。不要用 `GOLD`（会变成 Gold.com 股票）、`OIL`（会返回 2023 年停更的 ETN 报价）；`^DXY` 会被丢掉（N-106、N-121、N-30）。
- **体积**：1 年日线约 250 行、5 万字符（N-132）。

## metrics · 宏观

- **FRED**：`keywords=["<series_id>", …最多 5 个]` + `categories=["macro"]`，中文指标名先查附表 A。UNRATE / ICSA / PAYEMS / RSAFS 会展开别名占名额，单独一批；WTREGEN、CPIMEDSL 不可用（N-107、N-108）。FRED 日频比最近一个已收盘交易日晚 1 天，当日利率看 `^TNX` 快照（N-139）。FRED 不认 `date_from` / `date_to`，按 `observation_date` 在客户端截窗（N-107）。
- **经济日历**：`query="economic calendar"` + `country="US"` + `sort_by="hot"`。不传 country 会混入各国事件；不传 hot 会被国债拍卖、官员讲话挤满（N-32、N-128）。query 里不写事件名（N-129）。
- **读日历**：事件名和常用叫法不一样（核心 CPI 叫 `Core Inflation Rate MoM`）；`unit` 不可信，百分比和点位按数值量级判断（N-130）。同一事件可能有两行，取 12:30 UTC（美东 8:30）那行，并和官方日程核对（N-161、N-185①）。hot 排序只在候选池内生效，覆盖约两周，翻页也提不上更远的高重要度事件（N-128、N-161）。

## metrics · 基本面与财报

- **只传代码、不写意图**：返回核心集合（快照、资产负债表、现金流、公司简介、TTM 比率、共识目标价、EPS 趋势、最近一季、下次财报）。要别的块就在 query 里写意图词，一个 query 可以合并多块：「财报 利润表」「分析师评级 同行 DCF」「营收增长率」（N-109、N-135、N-123）。**不要用「全面分析」**，现在只返回 5 块（N-109）。**利润表单独一路**：「利润表」和别的意图词（包括「增长率」）写进同一个 query 时，`income_statement` 会被挤掉（N-135、N-123）。
- **最近一季**在 `fiscal_quarters[0]`，服务端多数情况下已按 `fiscal_period` 配好财报和财季，但个别票（JPM、HUBG）会拆成两个元素，超预期那块的 `fiscal_period` 为 null（N-149）；`earnings_surprise.actual_eps` 和 `financial_statement.eps` 可能一个是非 GAAP、一个是 GAAP，正负都能相反，引用时写明口径（N-29、N-149）。
- **分析师**：`consensus_price` 没有分析师家数；`analyst_grades` 默认 10 行，可用 `limit` 调大（警告说上限 20，实际传 21 回 21 行），不带时间窗（N-16、N-147）。
- **逐字稿**只给 2000 字（N-115）。
- **估值**：盘中的 dcf 和 TTM 比率按前收算；`enterprise_values` 停在上一财年末，当前企业价值看 `key_metrics_ttm.enterpriseValueTTM`（N-168、N-134）。
- 🔴 **财报日历**：个股的下次财报日以 `next_earnings_estimate.date` 为主，但它是估算值，还会跳季：距上次财报超过 120 天就视为可疑，用新闻核实，对外写「预计 X 日」（N-149）。市场级日历两种写法都会漏大票：带 `country="US"` 时候选上限先截断，区间前几天整天丢失；不带时按代码字母序排，前几页全是外国代码和 OTC 股（N-22、N-17、N-162）。日历只作补漏，名单不全时如实写明。

## metrics · 研报

- **按代码查**：`keywords=["<T>"]` + `categories=["fundamentals"]` + query 写研报意图（`research reports`）。每页最多 10 张卡，用 `cursor` 翻页；多个代码共用这 10 张（N-38、N-164）。精确取窗用 `date_from` / `date_to`（N-153）。
- **两层要分开读**：`subject`（专题报告）和 `mention`（只是提到）。榜单排名高不等于有专题报告（N-19）。
- **目标价**读 `matched_asset_target_price`（本标的）和 `report_subject_target_price`（报告主体）；**评级**用 `stance_normalized`，不读 `rating_current`（N-79、N-38）。
- **榜单的 `mention_impact`** 是「多少份报告怎么描述这只票」的计数，不是机构共识方向（N-39）。
- **双重上市按代码分桶**：TSM 查不到 2330.TW 的报告，要分别查（N-143）。
- **`key_caveat` 不全是报告原话**，混有抽取流程备注（N-144）。
- **汇编型报告**（晨报、周报、Tracker）的 `by_name` 是同框噪音，按 `report_title` + `report_type` 识别（N-67）。
- **新鲜度**：返回里没有提示，引用前看最新 `report_date`，出榜前过样本闸（N-164①）。
- **没有按单份报告取的参数**；query 只写报告标题会掉进基本面默认集。要某一份，就按研报意图重查再从结果里挑（见研报小节「补充」）。

## metrics · crypto 与衍生品

- **快照**：24h 涨跌幅只有 detail 才返回，`as_of` 为空，24h 成交量是币本位（N-170）。
- **衍生品**：永续合约池、当前费率板、OI 日线、Binance Futures K 线在生产端都能用。费率板按绝对值排，小币霸榜，不能当成「极端费率榜」（见 crypto 小节「补充」；N-104 已归档）。
- **合约地址**：keywords 单项上限 128 字符，放得下，但长尾币的地址认不出来；查地址走 news 的 query 加 `search_depth:"quick"`（N-102、N-101）。

## signal

- **必须传 `categories`**。只传代码不带 categories 会返回空，照扣额度（N-113）。
- **多类合并时带 `time_range`**，窗口内没数据的类会整类消失、没有提示；要多类就分开调，或者不带窗口（N-118、N-166）。`limit` 对每个类别分别生效，默认 10（N-151）。
- **kol_call**
  - 上游只有最近 24 小时，任何窗口都按 24 小时理解和表述（N-117）。
  - 按代码查会混进只是提到这只票的帖子，返回行的 `symbol` 可能都不是目标票，要回原帖核对（N-88、N-119）。
  - 一帖多票会拆成多行，按 `source_url` 去重（N-5）。
  - 美股侧几乎全是看多、样本极薄，只能做主题发现，不能写成「KOL 共识」（N-100）。方向值混用 `buy` 和 `bullish`（N-155）。
- **内部人**
  - 只认 Form 4 的 `P-Purchase` 为买入、`S-Sale` 为卖出；时间窗自己按 `transactionDate` 过滤。
  - 全市场入口只覆盖最近约一个申报日，**不写 query**：query 里写任何文字（包括 `congressional trades`、「国会议员 股票交易」），议员行都会整类消失。按金额排序时议员行可能占一半，按 `_chamber` 拆出，`symbol` 为空的剔除（N-137、N-95）。
  - 逐只单独查、`limit=50`；多个代码合查时共用一个 limit，排在后面的票可能一行都没有（N-176②、N-187）。
  - 申报行会被合并、截短，而且会来回变；持股差只当提示，不当判据（N-187）。没有 Form 144（N-176①）。
- **13F**：季末后头几周返回的是新季度的残缺数据，变动百分比不可引用（N-7、N-152）。
- **trader_position**
  - 🔴 组汇总按返回的行重算，`limit` 太小方向会翻；`positions_returned`、`active_trader_count` 也跟着重算，拿它们核对发现不了截断。要汇总就传 `limit=50`（上限）；某组 `positions_returned` 等于 50 时，汇总只代表返回的这些行，口径里写明「可能被截断」（N-171）。
  - 平仓不回流、`is_active` 恒为 true，陈旧仓按 `event_time` 自己剔（N-59m）。名义金额为空的仓位只计人数不计金额，全空的组会显示「多空平衡」，看 `positions_without_notional`（N-59a、N-59q）。
  - 按交易员名字查不生效（N-59e）；显示名不能当身份键（N-59n、N-59s）。
  - 对外展示交易员战绩前，过一遍该小节的「展示前必查」。

## news

- **搜索**：query 用英文、2~3 个核心名词，不写「影响 / 解读 / 分析」这类词。专有名词和多词短语用 `search_depth:"quick"`，默认 standard 会被语义相近的内容淹没（N-101、N-26）。
- **`asset_type`**：搜索模式不传（传 tradfi 会改变召回结果）；趋势模式（空 query）可以传（N-145、N-1）。
- 🔴 **查不到时不返回空，返回不相关的兜底内容**，`entity_filter_applied:true` 也一样。所有「报道数 ≤ N」的判断，都要逐条判断相关后再计数（N-35）。
- **撞名**：`$BEN` 会匹配到 Ben Affleck 和 Franklin Resources；像普通词的代码要加上公司名。英文术语和公司名相同时（oracle→ORCL），加 `asset_type` 也挡不住，改用中文术语（N-103）。
- **条数**：`limit=N` 返回 N 篇文章加 N 条社交，含 Telegram 时最多 3N（N-25）。
- **排序**：默认按时间，热门事件看不到首发报道；要首发用 `sort_by="relevance"` 或缩小窗口（N-167）。
- **来源**：`sources=["media"]` 会混进研究类来源；`sources=["research"]` 是公开媒体和独立研究，不是券商研报（N-167、N-68）。
- **Telegram**：只覆盖 24 小时；`tg_category` 只当参考标签，分错的比例高，不拿来做过滤（N-52、N-125）。
- **趋势榜**：时间是话题刷新时间，不是事件时间；tradfi 的趋势池很小，`time_range="1d"` 常常为空（报 `asset_type_filter_emptied`），拿不到就去掉 `time_range` 再取；生成的「交易指南」段不当数据用（N-146、N-87）。

## twitter

- **账号状态**要用 `user_info` 和 `user_tweets` 两个接口交叉判断（N-90）。
- **`user_tweets`**：每页最多 20 条，`limit` 只能往小截，截掉的翻页也找不回；按比率下结论前，先算这一页覆盖了多长时间（N-91）。
- **翻页游标**：`user_tweets` 在 `results[0]`，`followings` / `search` / `list_timeline` 在 `meta.filters_applied`（N-93）。
- **`search`**：`time_range` 不严格，客户端要按时间再筛一遍；`Top` 质量高但会混进很老的帖子，`Latest` 新但垃圾多（N-89、N-189①）。
- **判 reply** 用 `isReply`（`user_tweets` 默认不含回复，要统计回复传 `include_replies=true`，N-91、N-172）；**判转推**用 `retweeted_tweet` 或正文的 `RT @` 前缀；`tweets_by_ids` 对转推不给原推（N-55、N-53、N-189②）。
- **嵌套推文**：推文里嵌的 author 没有 `description`，要 bio 走 `user_info` 或 `followings`（N-94）；只取顶层 `tweets`，不要递归归集嵌套推文（N-92）。
- **list**：每页只显示 20 条、其余丢弃；`list_timeline` 和 `list_tweets` 各缺一部分（N-43、N-44、N-189④）。
- **体积**：一页约 7~12 万字符，作者对象每条重复一份（N-99、N-172）。

## subscription

- **未读数是累计条数**，不是新帖数，不对外展示；判断有没有新帖用 `latest_ts`（N-190）。

---

# 二、问题登记

> 按工具和主题分组。每个小节先列主条，再列零碎，最后是存根（→ 见 N-yy）。条目里的「现状」以标注日期的实测为准。

## 通用：参数、实体解析与返回结构

> 跨 `metrics` / `signal` 的共性问题。按主题：数组参数与 query 串（N-105 / N-23 / N-69）· 同名资产混流（B-18 / N-51）· 实体解析与影子代码（N-36 / N-159 / N-97 / N-86）· warnings 与额度（N-21 / N-156）· 时间窗、verbosity 与参数校验（N-10 / N-27 / N-85）。原 N-8 数组参数家族（含 N-71）10-12 已归档。

### N-105 数组参数：`keywords` 放实体、`query` 放意图（参数用法主条） 〔A/C·已文档化〕
- **现状**（10-12 复测）：生产端 `tools/list` 里 metrics / signal 的 `keywords`、`categories`，news 的 `sources`，subscription 的 `items` 都声明为 `"type":["null","array"]` 并带 `items`。工具描述写明 `keywords` 是实体字段、`query` 是意图字段，每批最多处理 5 个，单项上限 128 runes（N-102 的「30 runes」已过时）。本轮 100+ 次数组调用无一被拒。
- **①名额提示**：超过 5 个时超出项有 `keyword_count_over_max`，并置 `status:"partial"`（`48301044…`）；解析不了的项只给 info 级 `kw_not_canonical`，`status` 仍是 `ok`（`8e33d7e7…`）。
- **②提示噪音**：`kw_not_canonical` 也会出现在数据正常返回的 NVDA / MU / INTC / STX / DAL 上（`50d2dac5…` / `000dba41…`）；`default_fanout_fallback` 的噪音见 N-21。读 `meta.warnings` 时要按 `reason` 和 `keyword` 对上号，不能见到 warning 就判失败。
- **③Claude Code 丢联合类型**（10-12 新）：Claude Code 加载 schema 时把 `["null","array"]` 联合类型丢了，上面四个字段在会话里显示为既无 `type` 也无 `items`；`asset_type` 这类单一类型字段不受影响（10-12 本会话加载工具 schema 可见）。Claude Code 里照传数组仍可用（10-01 起各 Skill 数组写法实跑正常），但严格按 schema 序列化的客户端可能把它发成字符串。根治：服务端改成纯 `"type":"array"`。
- **怎么读**：实体一律放 `keywords` 数组，`query` 只写意图；调用后拿请求列表和返回的 `symbol` 做差集。只能用 query 串时见 N-23 / N-69。
- **依据**：10-01 首记 `d9f40132…` / `1c8c3f1f…`；10-12 生产 `tools/list`、`48301044…`。历史：07-20~09-07 数组被 schema 拒（原 N-8，已归档）。

### N-23 query 串里的 ticker 解析会截断、丢项、重复（query 解析主条①） 〔B〕
只在实体写进 query 串、不传 `keywords` 时出现；数组写法见 N-105。
- **(a) 批量截断**：上限 5 个。10-12 起超出部分有 `keyword_count_over_max` 并置 `partial`（传 8 只回前 5，`68fa27b2…`）。历史：07-27 原记为「无任何 warning」。
- **(b) 静默丢弃**：部分真实美股在 query 串里解析不出，无 warning、`status:"ok"`：10-12 `"JBLU WERN NRC 行情"` 只解析出 JBLU（`a428b346…`）。同样的票走 `keywords` 数组全部正常（JBLU / CUBI / AEHR / WERN / ONDS，`570e9d70…`）。07-27 的 9 只「不可解析清单」作废，不再预先跳过。query 串里的 `*USD` 商品代码一律被静默丢掉：整批都是这类代码时返回空，混批时只剩其他代码，见 N-106。
- **(c) 解析成功≠有数据**：07-27 STAK 出现在 `filters_applied.keywords` 里，却没有基本面条目。原判据用的 `beat_miss` 字段已不存在（N-109），10-12 未复测；差集改看返回的 `symbol` 和 `fiscal_quarters`。
- **(d) 指数重复行**（原 N-18）：`"^GSPC ^IXIC ^DJI ^VIX 行情"` 会多解析出 `VIX` / `VIXCLS`，^VIX 两行完全相同，还可能混入同名加密代币 VIX，`status` 仍是 `ok`（10-12 `28b8c34a…` / `83575bfc…`）。按 `symbol` + `asset_type` 去重。
- **怎么读**：首选数组写法。只能用 query 串时每批 ≤5；调用后做两道差集（`filters_applied.keywords`、返回 `symbol`）；缺项补调最多 1 次，空返回照扣额度（N-156）。
- **依据**：07-27 首记；10-12 `68fa27b2…` / `a428b346…` / `570e9d70…`。

### N-69 不传 keywords 时，query 里的英文词会被当成 ticker（query 解析主条②） 〔A〕
- **①**（10-12 仍成立）`metrics(query="DXUSD EMA 50")` → `keywords:["EMA"]`，DXUSD 被丢，返回的是 Emera（EMA）的指标（`049e873f…`）。同类：`"NVDA RSI 14"` 多返 Rush Street（RSI，10-01 `a60249a5…`）；`"… earnings beat miss …"` 抽出 BEAT（原 N-14，10-03 `fb4bcc6d…`）；`"KOL 喊单"` 被解析到 crypto（10-12）。
- **②**（10-12 已修）`signal(query="insider trading", asset_type="tradfi")` 08-04 返空、`status:"ok"`；10-12 正常返回 10 行内部人数据（`eee09148…`）。
- **③**（10-12 仍成立）`"NVDA 历史走势 30 day chart"` → `["NVDA","DAY"]`，多返 Dayforce 10 行并占一个名额（`6b979078…`）。
- **反例**：显式传 `keywords` 时，英文 query（`open interest history` / `broker research reports`）不再多抽 ticker（`43bea894…` / `a0eea254…`）。
- **怎么读**：实体放 `keywords`，query 可以写英文意图（工具描述也推荐英文）。只有不传 keywords 时，query 才写成「ticker + 中文意图词」，并核对 `meta.filters_applied.keywords` 有没有多出或缺了代码。技术指标一次返回全部指标：传 `asset_type="tradfi"` 时 NVDA 为 1 块 9 个（adx / rsi / dema / wma / williams / ema / tema / sma / standarddeviation，`a665ff16…`）；不传时另有 crypto 块（B-18 ③）。
- **依据**：08-04 首记 `fabbc973…` / `440722c0…`；10-12 `049e873f…` / `6b979078…` / `eee09148…`。历史：08-04 原规则「query 禁止英文意图词」，10-12 只对 query 串写法成立。

### B-18 🔴 不传 `asset_type` 时同名资产混流：快照、K 线、技术指标都会混 〔A〕
- **现状**（10-12 复测）：工具描述写明 `asset_type` 「Leave empty to get both」，混流是设计行为，返回里没有任何提示（`meta.warnings` 为空）。两行的 `symbol` 相同，只能靠 `asset_type`（无下划线）区分。
- **①快照**：`keywords=["BTC","AMN"]` 返回 4 行：BTC＝Grayscale Bitcoin Mini Trust ETF $36.36 + 加密 BTC 83,828；AMN＝AMN Healthcare $36.52 + 加密 AMN 0.00094（`4f968bd0…`）。同类：ETH→Grayscale Ethereum Mini Trust ETF、SOL→已退市的 Emeren Group、LINK→Interlink、COMP→Compass、OP→OceanPal（09-16 `a114c182…` / `56a9c223…`）；query 串 `"NVDA MU AMD 行情"` 也混入 3 行代币化股（`5df65d72…`）。历史：原记为「美股 BTC Inc $33」，实为 Grayscale ETF。
- **②K 线**：`market.history` 把同 symbol 的不同资产混进一个数组：BTC / ETH 混入 ETF 日线和 Binance 小时线；SOL 混入 Emeren（停在 2025-12-12）；美股也中招：AAPL 是 FMP 日线混 CoinMarketCap 代币化 AAPL 小时线（09-16 `5fecb679…`；10-09 探针 `38ad7891…`）。
- **③技术指标**：NVDA 返回两块，tradfi 块之外多一块 "Crypto price data for NVDA"（13 个指标全是 "N/A: Not a trading day"，附 721 行 7×24 小时价 CSV），同一天出现两个 RSI（39.47 对 45.07）（09-16 `065308c5…`；10-09 `b27a2dfe…`）。
- **怎么读**：metrics 的快照、历史、技术指标一律显式传 `asset_type`。传了就干净：crypto 侧 09-16 `e793aee1…`；tradfi 侧 10-12 NVDA 指标只 1 块、NVDA / MU / AMD 小时线全是 fmp（`a665ff16…` / `8ff9a02b…`）。拿到来路不明的返回时按 `asset_type` + `provenance` 分组，组数 >1 即混流；`date` 带时分的是小时线，不能和日线混算。别名错抓（GOLD→Gold.com）传了 tradfi 也去不掉，见 N-159 ③。
- **依据**：B 系列早期首记（原红线 1，日期不详）；10-12 `4f968bd0…`；GAP U1（10-09 探针 P01–P08 全未过）。

### N-36 影子代码与别名展开会挤占 5 个名额 〔A〕
- **现状**（10-12 复测，比原记载更重）：一个请求项可能展开成多个代码，一起占 5 个名额，超出的被截掉。现在有 truncated / `keyword_count_over_max` 提示，但用户实际只给了 5 个。
  - `CL` → `CL` + `CL=F`（2 个），还多返一行原油 CLUSD；`BABA` → `$BABA` / `BABA` / `9988.HK`（3 个）。数组请求 CL / BABA / AON / PSX / HCA / NUE，只处理了 CL 和 BABA（`23ec6a57…`）；`[NVDA, MU, CL, BABA, F]` 里 BABA 本体被挤掉、一行都没有（`847ceb18…`）。
  - `ASML` 展开出 `ASML.AS`（`4d0c73fa…`）；`Gold` → GOLD / GC=F / XAU（3 个）；`Block` → BLOCK / SQ / XYZ，曾把 Block 自己挤掉（10-10 `c7584a81…`；10-12 `de25dd22…`，GAP U22）。FRED 的 UNRATE / ICSA 同类，见 N-107。
- **怎么读**：含商品重名（CL / GC / SI / NG / HG）、港股二次上市中概（BABA / JD / NTES / BIDU）、ADR 与欧股双挂牌、公司俗名（Gold / Block）的项单独一批，或直接传具体代码（GCUSD、XYZ）；调用后拿返回 `symbol` 与请求列表做差集。历史：07-29 原规避「该批按 4 个装」，10-12 已不够。
- **依据**：07-29 首记；10-01 `db29129d…` / `9a39d28c…`（原 N-116 后半）；10-12 `23ec6a57…` / `847ceb18…`。

### N-159 🔴 代码被静默改写成别的资产，退市代码照返旧报价 〔B〕
- **①改写**：`ANTA`→`2020.HK`（安踏）；`NG`→`NG=F`（NovaGold 整行消失，`NG=F` 也没有行）；`CORN`→多出 `ZC=F` 占名额，把同批 `CL=F` 挤掉，`ZC=F` 本身也没有行，不传 `asset_type` 时 CORN 解析成加密 CORN（$0.0256）；`DX-Y.NYB`→`DXUSD`；`CL=F`→`CLUSD`；`USDJPY`→`USDJPY=X`。全部 `status:"ok"`、无改写提示（10-12 `59954294…`）。
- **②** `asset_type_no_matching_keyword` 会误报「全部解析成加密」，而返回的数据照常是美股（10-08，10-12 未复测）。
- **③退市 / 改名代码照返旧报价**（10-12 并入）：SOL→Emeren $1.94（`as_of` 2025-12-12）、SQ 停在 2025-02-13、ONE→Meta Data 停在 2022-05-02、`OIL`→iPath ETN（`as_of` 2023-06-08，`623f9c15…`），全部 `status:"ok"`、无过期标记，同一请求里只有部分行带 `_quote_snapshot_as_of`。别名错抓同类：`GOLD`→Gold.com $40.66（`f5135612…`），传 tradfi 也去不掉；服务端 `no_match` 提示里推荐的 `gold|oil|silver` 别名照做也会掉进来（`00a7d331…`）。
- **怎么读**：逐个比对「请求代码 vs 返回 `symbol`」，对不上的记为取不到；快照逐行读 `as_of`，距今超过 5 个交易日的不当现价；改名代码用新代码（SQ→XYZ）；商品用具体代码（GCUSD / CLUSD / BZUSD），不用 GOLD / OIL 别名。上述 warning 只作参考。
- **依据**：10-08 首记 `e55cefc0…` / `68a95644…`；10-12 `59954294…`；③ 见 09-16 `2b41f011…`、10-09 `05abcccc…`、10-10 `db43c904…`（GAP U2）。

### N-97 🔴 公司名被静默丢弃，返回貌似合理的通用结果 〔A〕
- **现状**（10-12 复测）：`query="宁德时代 研报 分析师评级"` → `keywords:null`，返回全量通用研报榜（NVDA / GOOGL / AMZN…）（`66e2f883…`）。返回里有 info 级 `ticker_unresolved`（"not entity-specific"），但这条在任何不带代码的研报榜上都会出现（N-154 ①），不能当成「名字被丢」的专门提示。
- **不限中文**（10-12 并入）：三星的中、英、韩写法（三星电子 / "Samsung Electronics" / 삼성전자）都被丢弃，`keywords:null`、无 warning；`005930.KS` 直查正常。SK 海力士、丰田、软银、索尼的名称能解析，"Ondas" 不行（10-10 `ed7b4f3b…`；10-12 `16f1c797…` / `ad00e0dd…`，GAP U21）。
- **A 股覆盖**（08-17，10-12 未复测）：按代码查有主体报告但命中率低：潍柴 `000338.SZ` subject 1 篇；上汽 / 长城 / 比亚迪只有 mention；宁德 `300750.SZ` 全 0。
- **怎么读**：公司名一律先转 ticker 再查，调用后核 `meta.filters_applied.keywords` 非 null（这是唯一能发现丢弃的地方）；A 股对外演示只用已验证有 subject 的票；判断覆盖面时，测试标的从 MCP 返回值里取，不凭记忆自选。用公司名查研报能展开多地上市的部分见 N-143。
- **依据**：08-17 首记 `7c614bed…` / `b78cd253…`；10-12 `66e2f883…`。

### N-86 🔴 按代码查会扩展出额外的平级结果块 〔A/C·已文档化〕
- **现状**（10-12 复测）：研报的 query 串写法下仍会扩展：`2330.TW` → `["2330.TW","TW"]`，TW（Tradeweb）块 0 卡（`225df57e…`）；`ASML.AS` → `["ASML.AS","ASML"]`，现在 ASML.AS 自己有 9 卡、在 `[0]`，ASML 块 1 卡，两块共用一页 10 卡，`meta.total:2` 数的是块（`2a0107a1…`）。数组写法下 2330.TW 不扩展（N-154 ②）。工具描述已写明「查一个别名解析出的全部上市地，所有块共用一页卡」。
- **新形态**（10-12）：数组 `[F, INTC, STX, V, DAL]`、不传 `categories` 时，`F` 额外带出一个 `macro.calendar` 块（委内瑞拉节假日，`_resolved_from_keyword:"F"`）——扩展跨到了别的结果桶（`000dba41…`）。
- **怎么读**（三条硬规矩保留）：① 不用 `research_reports[0]` 取数；② 逐块比对 `query_ticker` 与要查的标的，只认相等的块；③ 不用 `meta.total` 判条数。返回里出现没请求的桶时，先看 `_resolved_from_keyword`；显式传 `categories` 可减少这类串桶。
- **依据**：08-12 首记 `e005bd86…` / `6158d03d…`；10-12 `225df57e…` / `2a0107a1…` / `000dba41…`。历史：08-12 记「ASML.AS 库里查不到、靠扩展出的 ASML 才拿到报告」，10-12 已不成立。

### N-51 crypto 侧：价格源不止 Binance，但只有价格 〔C/D〕
- **①** 不传 `asset_type` 时 `query="BTC price"` 同时返回 BTC 币 83,954.61 和 Grayscale ETF 36.36（10-12 `4e9526e0…`）→ 混流已并入 B-18 ①。区分字段已从 `_asset_type` 改名为 `asset_type`。
- **②** 长尾链上币也有价：Robinhood 链 meme PONS（未上 Binance 现货）返回 10 日日线，`provenance:"coinmarketcap"`（10-12 `aa80b961…`）。先查再判「不覆盖」。历史：「crypto 仅 Binance 定价」09-07 已作废。
- **③** crypto 只有价格：`"<T> holders liquidity onchain"`、`"token unlock schedule"` 都掉进股票基本面兜底（`default_fanout_fallback`，提示的可查主题全是股票概念），持有人、流动性、解锁日历都没有（10-12 ARB `a66a6c2a…`）。这类问题不要问 metrics。
- **依据**：07-30 首记；09-07 `3d44becc…` / `b8031436…`；10-12 `4e9526e0…` / `aa80b961…` / `a66a6c2a…`。

### N-21 `default_fanout_fallback` 提示常与实际返回无关 〔B〕
- **①**（10-12 已修）研报调用误报：07-24 `NVDA research reports` 数据齐全却报这条 warning；10-12 同类调用 `warnings:[]`（`66ac7a9c…`）。
- **②** 不写 query 的 metrics 调用（包括纯行情快照）几乎都附一条 info 级 `default_fanout_fallback`（"returning the CORE fundamentals set…"），`source` 有时还是 `metrics_macro`（10-12 `8da9fc97…` / `000dba41…`）；`keywords=["NVDA"], interval="1hour"` 只返回快照、却说返回了核心基本面（`04c9c3af…`）。
- **③** 宏观查询串台（10-12 并入）："Fed interest rate decision" 返回 "…CORE fundamentals set for keywords=[rate_decision] (income / balance sheet …)"，与实际返回的宏观数据无关（09-16 `91d38de6…`；10-09 `65ca72a0…`，GAP U18）。
- **④** 研报的提示不全在 `meta.warnings`：`no_research_reports`、截顶提示放在 `research_reports[0].warnings`（10-12 `a8f61a88…`；另见 N-183 ⑥）。
- **怎么读**：这条 warning 只在「问的是别的、拿回来的确实是核心基本面块」时才有意义（如 N-51 ③、只写报告标题的研报查询）；其余一律以实际返回的块为准，不据此重试（重试照扣额度）。读研报提示要同时看卡片组里的 `warnings`。
- **依据**：07-24 首记；10-12 `66ac7a9c…` / `8da9fc97…` / `04c9c3af…`。

### N-156 失败和空结果照样扣额度 〔A〕
- **①上游整体 403**：10-05 美东盘中，报价 / 批量报价 / 历史 / 涨跌榜 / 内部人 / 市场级财报日历同时 `status:"degraded"` + `severity:"source_dead"`（`fmp_quote_error` 等），正式端与测试端一致，重试无效，每次仍 `consumed:1`（`4788e3a7…` / `f1bf021b…`）。10-12 上游正常，未能复测。
- **②空结果照扣**（10-12 并入）：signal 不带 `categories`（N-4 / N-113，`a25456fb…`）、12 小时窗口的历史（N-10，`00a7d331…`）、crypto 查研报（`23c3ebc5…`）、不存在的 twitter list（N-42，`89918922…`）都是 0 条、扣 1。news 调用（含 degraded）一律 `consumed:0`。
- **怎么读**：批量前先发一次快照当探针，遇到 `source_dead` 就跳过同一上游的其余调用；`source_dead` 时的内部人空结果按「缺数据」写，不按「没有交易」写；已知会返空的写法不要发，补调最多 1 次。
- **依据**：10-05 首记；10-12 `a25456fb…` / `00a7d331…` / `23c3ebc5…`。

### N-10 历史查询的 `time_range` 小于 1 天时返回空 〔B〕
- **现状**（10-12 复测）：`keywords=["NVDA"], query="历史走势", time_range="12h"` → `results:{}` + `no_match`，照扣 1 额度（`00a7d331…`）。历史：原记为「返回一个月前的旧数据」。
- **怎么读**：日内数据用 `interval`（`1min` … `4hour`），且 query 要写历史意图——只传 `interval` 不写 query 时只返回快照（`04c9c3af…`）；或者只用实时快照。不要用小于 1 天的 `time_range`。
- **依据**：07-22 批首记（trend-scout）；10-12 `00a7d331…` / `04c9c3af…`。

### N-27 `verbosity` 只截自由文本，数字载荷不变 〔C·已文档化〕
- **现状**（10-12 复测）：concise 200 / standard 600 / detail 2000 字的上限只作用于自由文本（逐字稿、研报正文、推文等），数字、日期、ID 不截，工具描述已写明。`"NVDA next earnings date"` concise 3,607 字符、standard 3,608 字符，只差 meta（`7d7819bc…` / `e25d719f…`）。
- **怎么读**：省 context 靠 query 只问需要的块（N-24）和 `limit`，不靠 verbosity；逐字稿在 detail 下也只有 2000 字（N-115）；行情快照的字段集会随 verbosity 变（N-150）。
- **依据**：07-27 首记；10-12 `7d7819bc…` / `e25d719f…`。历史：07-27 原记为「对 metrics 无效」，10-01 起已截文本（N-115）。

### N-85 写错的 `verbosity` 静默按 standard 处理 〔C·已文档化〕
- **现状**（10-12 复测）：`verbosity:"ultra"` → `meta.verbosity:"standard"`，warnings 里没有任何提示，照扣额度（`23c3ebc5…`）。工具描述已写明 "standard 600 (default for empty or unknown)"。对照：`time_range` 写错会正确报错。08-12 产品侧决定不修。
- **怎么读**：只用 `concise` / `standard` / `detail`；按返回体积流控时以 `meta.verbosity` 的回显为准。
- **依据**：08-07 首记 `ce90a05d…`；10-12 `23c3ebc5…`。

### N-12 → 见 N-23
query 串批量静默丢 ticker（07-22 ONDS 连续两次被跳过）已拆成 N-23 (a) 截断与 (b) 丢弃；10-12 截断已有 warning，ONDS 走数组可正常解析。

### N-14 → 见 N-69
英文词 `beat` 被当成 ticker（HeartBeam / BEAT）是 N-69 ① 的一例；10-03 仍复现（`fb4bcc6d…`）。

### N-18 → 见 N-23 (d)
指数 query 串产生重复的 ^VIX 行，10-12 仍复现。

### N-116 → 见 N-23 (b) / N-36
前半「不可解析清单在数组路径失效」并入 N-23 (b)；后半「影子代码更重（BABA 展开成 3 个）」并入 N-36。

## metrics · 行情（快照、K 线、技术指标、交易时段）

### N-30 原油 / 商品代码：数组可用，query 串和别名不可用 〔A/B〕
- **现状**（10-12 复测）：走 `keywords` 数组时 `CLUSD`（WTI 91.13）、`BZUSD`（布伦特 104.12）、`GCUSD`（黄金 4206.8）、`SIUSD`（白银 61.21）都能取到。放进 query 串会被静默丢掉（`"CLUSD BZUSD USO OIL 行情"` 只解析出 USO、OIL，无 warning；范围见 N-106）。别名仍错：`GOLD` → Gold.com 美股（$40.66），还会展开出 GC=F / XAU 占名额（N-36）；`OIL` → iPath 原油 ETN，`as_of` 停在 2023-06-08，没有任何提示；`SILVER` 未测。
- 用自然语言问商品（如「gas prices trend」）会解析成空 keywords，返回空结果、不报 warning。空返回不等于没有数据（GAP U19，09-23 回执）。
- **怎么读**：商品一律传代码数组；不用 GOLD / OIL / SILVER 别名；USO 只作 ETF 代理，引用时说明口径。
- **历史**：07-27 原记「CLUSD / BZUSD / OIL 三死、只剩 USO」，10-01 N-106 证明只在 query 串路径成立。本条已并入旧顶部表第 72 行（别名错路由）和红线 6 的事实部分。
- **依据**：07-27 首记；10-01 `1d2f50e0…`；10-12 `f5135612…`（数组 + GOLD）/ `623f9c15…`（query 串 + OIL）；U19 `f775f69d…`

### N-106 🔴 query 串静默丢弃 `*USD` 商品 / 外汇代码 〔A〕
- **现状**（10-12 复测）：query 串里的 `*USD` 代码（GCUSD / CLUSD / BZUSD / DXUSD / ESUSD 等）一律被静默丢掉。整批都是这类代码时返回 `results:{}`、`keywords:null`、`status:"ok"`，无 warning（`"GCUSD CLUSD BZUSD ESUSD 行情"`）；混有其他代码时只剩其他代码（`"CLUSD BZUSD USO OIL 行情"` → USO、OIL）。同样的代码走 `keywords` 数组全部正常。
- 纯美股或纯加密代码的 query 串仍能解析，但不传 `asset_type` 会混入同名代币化股（`"NVDA MU AMD 行情"` 多出 3 行 crypto 报价）。指数 query 串会多解析出 `VIX` / `VIXCLS`，返回重复的 `^VIX` 和一个同名加密代币，`status` 仍是 `ok`（10-01 原记为 `partial`）。
- **怎么读**：商品、外汇、指数只走数组；query 串只写意图。
- **依据**：10-01 `cc59a780…` / `2ee5f77d…`；10-12 `8da9fc97…`（数组正常）/ `03593c64…`（整批空）/ `623f9c15…`（混批）/ `83575bfc…`（指数）

### N-121 `^DXY` 走数组也被静默丢弃 〔B〕
- **现状**（10-12 复测）：`keywords=["DXUSD","GCUSD","CLUSD","BZUSD","^DXY"]` 只回 4 行，`status:"ok"`，warnings 里只有一条无关的 `default_fanout_fallback`。`NGUSD` 可用（不再 402）。
- **怎么读**：美元指数用 `DXUSD`。只读 `meta.warnings` 发现不了所有丢失；批量后要拿请求列表与返回行的 `symbol` 做差集。
- **依据**：10-01 `c13facdc…` / `8999a3c1…`；10-12 `8da9fc97…`

### N-47 🔴 快照 `change` 是金额变动，不是百分比 〔A〕
- **现状**（10-12 复测）：standard 快照只有 `change`（按报价币种的金额变动）和 `previousClose`，没有涨跌幅字段。SNDK `change:-27.64` / `previousClose:1609.46` 实为 −1.72%；000660.KS 的 `change:-76000` 是韩元。`verbosity="detail"` 才带 `changePercentage`（N-150）。
- **怎么读**：涨跌幅用 detail 的 `changePercentage`，或自算 `change ÷ previousClose × 100`。不要拿 `change` 和新闻里的百分比交叉核对：07-30 META `change:-9.18` 恰好对上新闻的「−9%」（那是盘后跌幅），常规时段实际是 −1.55%，会得到假的「核实通过」。
- **依据**：07-30 首记；10-01 `d9f40132…`；10-12 `0b0b89af…`

### N-48 非交易时段的 `price` 是上一常规收盘 〔B〕
- **现状**（10-12 美东 04:00 复测）：SNDK 带 `_quote_session:"regular_inactive"`、`_quote_cache:"last_regular"`，`price` 1581.82 的 `as_of` 是 10-09 20:00Z（上周五收盘）。同一行另有 `extendedHoursQuote`（bid 1556.24 / ask 1564.71），没有成交价。
- **怎么读**：盘前盘后的 `price` 是旧收盘，财报后的跳空不在里面。当下价用 `extendedHoursQuote` 的中间价（N-150）；缺失时可以引新闻里的盘后成交价（只引价格、不引百分比），两个数分开写并标来源。
- **依据**：07-30 首记；10-12 `0b0b89af…`

### N-150 快照字段随 verbosity 变；`extendedHoursQuote` 只有报价 〔C〕
- **现状**：`verbosity="detail"` 的快照带 `changePercentage` / `priceAvg50` / `priceAvg200`，standard 不带。`extendedHoursQuote` 只有 bid / ask / size / volume / timestamp，没有成交价和涨跌。指数（`^GSPC` / `^VIX`）从不带；个股和 ETF 时有时无：PTC 在 10-05~10-09 连缺 4 次、PCVX 也缺过，10-12 04:01 ET 盘前两只都有（PTC 价差约 1%）；10-09 盘后 QQQ / DIA 缺。
- 盘前快照的 `changePercentage` 是上一交易日涨跌，不是盘前涨跌。盘后 `extendedHoursQuote.volume` 是含常规时段的全天累计（10-09 NVDA 8,435 万对常规 7,895 万），盘前则只是盘前量，两个时段口径不同。`^VIX` 的 `as_of` 可能落在下一交易日盘前（10-12 07:46Z），同批其他指数仍是上一收盘。
- **怎么读**：盘前 / 盘后价 = (bid+ask)/2，标「盘前报价」或「盘后报价」，价差大时注明；缺失时不用新闻百分比顶替；逐行读 `as_of`。
- **依据**：10-05 首记；10-09 `204ff42a…`（盘前）/ `9d1d2b34…`（盘后）；10-12 `7ed3d0a6…` / `bef3df49…`（盘后部分 10-12 未复测）

### N-157 `_quote_session` 随时段变，不能当时段判据 〔B〕
- **现状**：盘前、盘后的个股和 ETF 带 `_quote_session:"regular_inactive"` + `_quote_cache:"last_regular"`（10-12 04:01 ET：NVDA / MU / PTC / PCVX / QQQ / DIA / FBTC）。指数、外汇、商品一直不带；部分小盘股（JBLU / CUBI / AEHR / WERN）盘前也不带。10-08 盘中实测，大盘股、指数、ETF 普遍不带，`extendedHoursQuote` 整个字段缺失。2330.TW 收盘后也不带（N-179⑤）。
- 已退市代码照常返回旧报价、`status:ok`、无过期标记（SOL → Emeren，`as_of` 2025-12-12；GAP U2，主述见 N-159）。
- **怎么读**：「实时 / 最近收盘」一律看 `as_of` 是否落在美东 9:30–16:00；`as_of` 距今超过 5 个交易日的不当当前价；盘前盘后价只在延长时段取（N-150）。
- **历史**：10-03 N-139 原记「部分大盘股有」，10-08 订正为盘中普遍缺。10-12 复核时是盘前，盘中断言无法复测。
- **依据**：10-08 `c0183352…` / `cf9b1fe3…`；10-12 `7ed3d0a6…` / `bef3df49…` / `570e9d70…`；U2 10-09 `05abcccc…`

### N-131 🔴 日线 `change` / `changePercent` 是收盘对开盘 〔A〕
- **现状**（10-12 复测）：历史日线的 `change` / `changePercent` 是当日收盘对当日开盘，不是对前收。NVDA 10-09 字段 −1.95%（= 229.28 ÷ 233.84 − 1），对前收实为 −0.52%。商品日线同样（原 N-188①）：WTI 10-08 字段 +2.8%、自算 +3.64%；布伦特字段 +3.11%、自算 +4.07%。
- **怎么读**：涨跌幅、波动率一律用相邻两天的 `close` 自算。按字段算的 1 年波动率是 31.0%，按收盘算是 37.4%，用字段会把风控仓位上限算高。
- **依据**：10-03 首记 `6d7e6511…`；10-12 `963de176…`（NVDA）/ `cbeb18a8…`（原油）

### N-132 1 年日线只有 250 行，凑不出第 252 个交易日 〔C〕
- **现状**（10-12 复测）：`time_range="1y"`、`limit=365` 返回 250 行（2025-10-13~2026-10-09），约 5.2 万字符，可能超出工具输出上限而被写进本地文件。history 每只最多返回 `limit` 行，默认 10 行。tradfi 只传 `time_range`、不写历史意图（如 `query="daily price history"`）时只返回快照，没有 history。
- **怎么读**：1Y 涨幅用 `time_range="13m"` + `limit=290`，用脚本解析 `close`；不足 252 行时标「≈1Y（N 个交易日）」。取历史要写明历史意图，并按需要的根数设 `limit`。
- **依据**：10-03 `95c6be82…`；10-12 `963de176…` / `07c573f2…`

### N-158 盘中的日线与技术指标含当天未收盘的一根 〔C〕
- **现状**：交易日盘中，历史日线与技术指标都带 `date` 为今天的一根（close ≈ 实时价，成交量只有平日零头），不只周一；EMA / SMA 也把盘中价算了进去（10-08）。10-12 盘前 04:00 ET 的 1 小时线已含进行中的 04:00 那根（量 4,983）。商品 / 外汇日线在亚洲时段也有当日行，见 N-179③。
- **怎么读**：多日涨跌可以用，但标「盘中」；SMA、波动率、最大回撤、周变动要剔除当天这根。
- **依据**：10-08 `409fd524…` / `51d99884…` / `9962dd7e…`；10-12 `0810f8a3…`（日线盘中部分 10-12 无法复测）

### N-169 技术指标：指标集按资产块固定，`limit` 截观测值 〔C〕
- **现状**（10-12 复测）：返回哪些指标与 query 写什么无关，按资产块固定。tradfi 块 9 个：dema / sma / adx / ema / tema / rsi / williams / standarddeviation / wma（日线）。crypto 块 13 个：atr / boll / boll_lb / boll_ub / close_10_ema / close_50_sma / close_200_sma / macd / macdh / macds / mfi / rsi / vwma。美股不传 `asset_type` 时两块都返回（多出来的是代币化股的 crypto 块），合计 21 个名字，出现两个 RSI。
- `limit` 截每个指标的观测数（N-127 已修）。tradfi 的 `standarddeviation` 观测没有数值字段；crypto 没有标准差。crypto 块附带的价格随 query 变：写「技术指标」「RSI」时附 Binance 日线 31 行（约 2 千字符，N-185④）；按指标名写（`"SMA 50, SMA 200, bollinger bands"`）时附 721 行小时价（约 4 万字符，停在当天 00:00 UTC，N-178①）。数据源历史不足的币（HYPE）`close_50_sma` = `close_200_sma` = `boll` 三值相同，BTC 正常；`mfi` 是 0–1 刻度。
- **怎么读**：传 `asset_type`；按 `indicator` 字段筛，不要分开单调；历史不足时不判长期均线；指标值先做合理性检查。
- **历史**：GAP R1「一次返回 9 个还是 21 个」：传 tradfi 时 9 个，不传 `asset_type` 时两块合计 21 个，两边都对（用 10-12 已有返回判定，未新增调用）。红线 8 的指标名 `stddev` 应为 `standarddeviation`。
- **依据**：10-08 `2dfba67a…` / `40548e33…`；10-12 `a665ff16…`（tradfi 9 个）/ `e807873a…`（HYPE）/ `0562d56f…`（BTC）/ `5b1ae7ce…`；R1 10-09 探针 `b27a2dfe…`

### N-175 行情 / 日历 / 基本面零碎（10-08 第二轮复跑） 〔C〕
- **①** 1 小时线含延长时段：每天 16 根（04:00–19:00 ET），时间戳为美东；`09:00` 那根跨盘前与盘中（10-09 量 1,508 万）；`limit` 按每只计。10-12 复现（`0810f8a3…`）。
- **②** `^TNX` 未收盘那行 close 是三位小数，已收盘是两位，可以据此认出未收盘行（10-12 盘前无法复测）。
- **③** → 见 N-161（经济日历按 High → Medium → Low 排，带预期值的 Medium 落到第 2 页；未来日期的 EIA 库存、MBA 利率行没有 estimate）。
- **④** news `time_range="1d"` 是从调用时刻往回滚 24 小时，不按自然日（10-12 复现，`17998f13…`；属 news 主题）。
- **⑤** 财报当天基本面的更新时点因票而异；新季度初版数据缺项（折旧、利息为 0，资本开支符号反），财报 3 天内不引 EBITDA 与现金流。10-12 LW / RPM 已更新（`1a42225b…`）。财报字段时序见 N-149。
- **⑥** → 见 N-168（`dcf["Stock Price"]`、估值比率盘中仍按前收；引用估值注明按前收）。
- **⑦** 代码改写又见 `DX-Y.NYB` → `DXUSD`、`CL=F` → `CLUSD`（10-12 复现，`59954294…`），见 N-159；`stock_peers` 里的 SKHY 是 SK 海力士美股 ADR（报表韩元、报价美元），见 N-168。
- **依据**：10-08 06 / 02 / 01 / c2 / Premarket 复跑记录；10-12 E 段复核

### N-179 行情 / 估值零碎（10-09 第三轮复跑） 〔B/D〕
- **①** 收盘后估值口径：10-12 MU `dcf["Stock Price"]` 已等于最近收盘（1029），但 `enterprise_values.stockPrice` 仍是上一财年末的价格（958.16，MU 财年末 09-03）。引用比率与 DCF 前先反推所用价格，见 N-168 / N-134②。（10-09 原记「`dcf["Stock Price"]` 既非收盘也非前收」，10-12 未复现）
- **②** 分析师预期同一财年出现两行（10-12 MU FY2030：5 位分析师一行、1 位一行），取分析师数多的那行，见 N-134④。
- **③** **商品 / 外汇日线的未收盘行（主述；N-185②③、N-188① 并入此处）**：`CLUSD` / `BZUSD` / `GCUSD` / `DXUSD` 日线的最后一行可能是当天未收盘行，亚洲时段就会出现（10-12 成交量：CLUSD 42,171 对前一日 341,641，BZUSD 7,506，DXUSD 2,971，GCUSD 35,140）。`DXUSD` 周末行落在周日（10-11、10-04），开高低与周一相同。相邻两天的成交量可能完全相同（CLUSD 10-08 = 10-09 = 341,641；BZUSD、GCUSD 各两处），只看成交量判断不了。日线自带的涨跌字段是收盘对开盘（N-131）。
  怎么读：日期等于当天的行一律当未收盘行剔除；上一交易日涨跌用收盘对前收自算。
  历史：10-09 先记「不带 `interval` 返回小时 K」，后改为「带 `categories=["market"]` 才返回日 K」（N-185②）。10-12 用 `keywords` 数组 + `query="price history"`，带不带 categories 都返回日 K，两种解释都作废。crypto 和旧 query 串写法（`"<T> 历史走势"`）不带 `interval` 仍可能返回小时 K，与工具描述「omit for daily」不符（N-178①）。
- **④** 日线与快照的高低价、开盘、成交量小幅不一致（10-12 PCRX 已基本一致；SOXX 开盘 571.01 对 570.69，量 5.03M 对 4.77M）。振幅只用快照的高低价。
- **⑤** 交易时段标记不一致：`^TNX` 快照 `as_of` 停在 14:59 ET，开高低三个值都是 5.244，而日线高低是 5.28 / 5.23；2330.TW 收盘后快照没有 `_quote_session`，美股收盘后带 `regular_inactive`（N-157）。（10-09 记的「`^TNX` 前收与日线不符」10-12 已对上）
- **⑥** 1 小时线 15:00 那根（15:00–16:00）含收盘竞价（10-12 NVDA 1,246 万），16:00 起是盘后（2.6 万）。（10-12 订正：原记为「16:00 那根含收盘竞价」）
- **⑦** 财报日历的代码过滤会放过 4 字母场外股（SCTQ）。日历行没有 `exchange` 字段，原对策「靠 `exchange=="OTC"` 兜」做不到，只能补快照后按 `exchange` 剔除。财报日历见 N-22。
- **⑧** 历史走势调用附带无关的公司资料块（SOXX）。（10-12 未复现，视为已修）
- **依据**：10-09 01 / 02 / 06 / c3 / Premarket / Feed Manager 复跑记录；10-12 `cbeb18a8…` / `ceb1f2f8…` / `9929ece8…` / `40c8873b…` / `77885f7d…` / `560f9bc2…`

### N-185 行情 / 日历零碎（10-09 第四轮复跑） 〔B/D〕
- **①** 经济日历同一事件可能有两行，宽窗口被 50 行上限截掉一行，看起来像「随窗口变」，详见 N-161③。（10-12 证伪：原记为「同一行随查询窗口变化」，实为上游本来就有 12:30 / 13:30 UTC 两行零售销售）
- **②** 原油查历史返回日 K 还是小时 K → 见 N-179③。（10-12 订正：带不带 `categories=["market"]` 都返回日 K，「差别在是否带 categories」作废）
- **③** `DXUSD` 最新一行可能是未收盘行，「日期晚于最近收盘日才剔」剔不掉 → 见 N-179③。（10-12 订正：成交量可能复制前一天，只看成交量判断不可靠）
- **④** crypto 技术指标附带的日线数据头 `Total records` 被约 30 天窗口封顶在 31，不能当历史长度用（10-12 BTC 复现，`26e55955…`）。
- **⑤** `interval="1hour", limit=24` 时 BTC 缺当前未走完那根、其他币有。（10-09 第五轮和 10-12 都未复现，BTC / ETH / SOL 都含当前那根，属偶发）
- **⑥** crypto 流通量 / 市值查询返回 `no_match`（10-12 BTC / HYPE 复现，`4610d9d9…`）；流通量从新闻或外部源取。
- **依据**：10-09 06 / c2 / Crypto Watchlist / Feed Manager 复跑记录；10-12 `7b64a9d0…` / `a015ef8b…` / `cbeb18a8…` / `2756a29f…`

### N-188 行情 / 研报零碎（10-09 第五轮复跑） 〔C/D〕
- **①** 布伦特日线也有未收盘行，原油日线的涨跌字段同样是收盘对开盘 → 见 N-179③、N-131（10-08 WTI 自算 +3.6%、字段 +2.8%；布伦特 +4.1% / +3.1%）。（原文「同 N-128 的日线口径」是错引，应为 N-131）
- **②** `^TNX` 日线的收盘值约等于 15:00 ET 前的快照（10-09 日线 5.24，14:59:55 快照 5.244），可能与媒体报的收盘不同（10-08 媒体报 5.28%）。收盘以日线为准，并注明可能是 15:00 前的值（10-12 复现，`9929ece8…`）。
- **③** `analyst_grades` 不传 `limit` 只回 10 行，传 20 回 20 行（10-12 复现），见 N-147。
- **④** 研报提及层按日期倒序，页内与翻页处都没有乱序，可据此设翻页止损（10-12 复现：10-09 ×5 → 10-08 ×3，`5ff7885f…`）。
- **⑤** 研报 `detail` 单页可达约 10 万字符（10-12：7 张卡 67,002 字符，约 9.6K / 张，`250df662…`）。
- **⑥** twitter 工具的额度单独计，本账户上限 10000，与 metrics / signal 的池子分开（10-12 复现）。
- **依据**：10-09 06 / c3 / Premarket / c4 复跑记录；10-12 `cbeb18a8…` / `77885f7d…` / `dd4875fc…`

### N-110 → 见 N-47
standard 快照没有涨跌幅字段（detail 有，N-150），这部分并入 N-47；榜单行字段（6 个，无 `exchange` / `marketCap`）并入 N-9。

### N-122 → 见 N-106
N-122 是 N-106 的范围扩大版（query 串里的 `*USD` 代码一律被丢，整批都是时返回空；纯美股 / 纯加密 query 串正常；指数 query 串多解析出 `VIX` / `VIXCLS`），已合并到 N-106。

## metrics · 宏观（FRED、经济日历）

### N-107 FRED 走数组可批量，但别名展开挤名额、日期参数不生效 〔A〕
- **现状**（10-12 复测）：`keywords=[series_id…]` + `categories=["macro"]` 一批 ≤5 个都能返回（DGS10 / BAMLH0A0HYM2 / WDTGAL / MORTGAGE30US / PCEPILFE / T10Y2Y 均命中）；单个 series 写 `query="<series_id>"` 也行。查不到的给 info 级 `kw_not_canonical`，`status` 仍是 `ok`。
- `UNRATE` / `ICSA` / `RSAFS` / `PAYEMS` 会被额外展开成别名（`unemployment` / `jobless_claims` / `retail_sales`）多占名额：传 [UNRATE, ICSA, DGS10, T10Y2Y, VIXCLS, DFF] 时后三个被挤掉，warning 计数前后不一（「5 of 6」与「5 of 7」）；`unemployment` 别名还带出 8 行不受 `country` 约束的非美经济日历。
- 来自报告（GAP U17）：FRED 不认 `date_from` / `date_to`（传 2026-09-11 单日仍返回 10 个月）；`query="CPI YoY release actual"` 被路由到 FRED 的 CPI 指数（334.131），不是日历里的同比；`GDP` 与 `gdp` 各解析一次，产生重复行。
- **怎么读**：FRED 批量 ≤5，含上述四个的单独查；批量后对请求与返回的 `series_id` 做差集；按 `observation_date` 在客户端截窗，按 `series_id` + 日期去重；CPI 同比走日历的 `Inflation Rate YoY`（N-130）；批次含 UNRATE 时丢弃 `macro.calendar`。
- **历史**：红线 3 / 4 与 B-31 原记「数组被拒、FRED 不可批量、会静默丢条目」，10-01 证伪。
- **依据**：10-01 `f9806f93…` / `bea59307…`；10-12 `8e33d7e7…` / `48301044…` / `7b8c286f…`；U17 09-17 `f15281ef…`、09-28 `82d5e6fc…`

### N-108 FRED 字典缺口：`WTREGEN`、`CPIMEDSL` 不可用 〔D〕
- **现状**（10-12 复测）：`WTREGEN`（财政部账户）和 `CPIMEDSL` 已失效，返回 `kw_not_canonical`，无数据。`WDTGAL` 可用（周频，单位 "Mil. of U.S. $"，10-07 = 885,783）；`BAMLH0A0HYM2` 已恢复（10-08 = 3.15，见 B-33）。
- **怎么读**：TGA 用 `WDTGAL`。单位：`WALCL` / `WDTGAL` 是百万美元，`RRPONTSYD` 是十亿美元。附表 A 相应更新。
- **依据**：10-01 `1d31eacc…` / `598c432c…` / `23f46a93…`；10-12 `8e33d7e7…`

### B-33 信用利差 `BAMLH0A0HYM2` 已恢复，只剩 `CPIMEDSL` 不可用 〔D〕
- **现状**（10-12 复测）：`BAMLH0A0HYM2` = 3.15（10-08）；`CPIMEDSL` 无数据，给 info 级 `kw_not_canonical`，不再被错抓成总体 CPI。
- **怎么读**：05 ⑦ 的信用利差可恢复调用和 5% 权重；02 Healthcare 继续用 `CPIAUCSL`。原状态「Dev 待修」已过期。
- **历史**：07 月原记两个 series 都不在字典，分别被错抓到 `M2SL` 和 `CPIAUCSL`；BAML 部分 10-01 销案（N-108）。
- **依据**：10-01 `eea76e19…`；10-12 `41caec8e…`

### N-139 FRED 比行情晚一天；当日利率看 `^TNX` 〔D〕
- **现状**（10-12 复测）：FRED 日频比最近一个已收盘交易日晚 1 天（美东上午看就是两个交易日前，N-168 说的是同一件事）。10-12 盘前 `DGS10` 最新是 10-08 的 5.22，`^TNX` 是 10-09 的 5.244。两者方向可能相反（10-02 `^TNX` +4bp，FRED 最新一天 −5bp）。
- 收益率曲线（`provenance:"fmp_treasury"`）放在 `results.macro.calendar` 桶里，不在 `indicators` 桶（GAP U19）。
- **怎么读**：当日 10 年期用 `^TNX`，注明可能是 15:00 ET 前的值（N-188②）；要收益率曲线去 calendar 桶找 `fmp_treasury` 行。本条原记的 `_quote_session` 部分已移到 N-157，`CLUSD` / `BZUSD` 部分见 N-30。
- **依据**：10-03 `8a374fa9…` / `b7fdf669…`；10-12 `8e33d7e7…` / `8caaa7d6…`；U19 09-23 `f775f69d…`、10-09 `441a16c0…`

### N-32 `country` 对经济日历和财报日历都生效 〔C·已文档化〕
- **现状**（10-12 复测）：经济日历按事件国过滤，不传 `country` 时 50 行 High 混了 US 21 / EU 5 / CH 4 / IT 4 / CA 3 / DE 3，传 `country="US"` 全是美国事件。财报日历按发行人注册地过滤，但受 500 候选上限影响会整天丢失，见 N-22①。工具描述已写明两种口径。
- **怎么读**：经济日历必传 `country="US"`。排查时先确认自己看的是 `macro.calendar` 还是 `fundamentals.earnings_calendar`。
- **历史**：07-27 原记「`country` 不作用于财报日历」（`ac352acb…` / `7e03620d…`），10-12 证伪。
- **依据**：07-27 `58e6c189…` / `1886041c…`；10-12 `7cc5ccd7…`（经济日历）/ `052efd1d…` / `16e54c37…`（财报日历）

### N-128 经济日历要带 `sort_by="hot"`；前瞻只覆盖约两周 〔C〕
- **现状**（10-12 复测）：不带 `sort_by` 时按时间排，50 行只覆盖 10-07~10-12，CPI / 非农 / PCE 一条都没有。带 `hot` + `time_range="35d"` 能拿到最近一期非农、失业率、核心 PCE、议息、核心 CPI。前瞻有候选上限：`date_to` 设到 38 天后，High 行只排到 11 天后，之后接 Medium，warning 为 `ordering covers only retrieved events`。现在有 `has_more` / `next_cursor`，但 hot 只在候选池内排序，翻页也提不上更远的高重要度事件。`status:"partial"` + `parameter_partial` 是常态。
- 来自报告（GAP U16）：没有 `impact` 参数，传了直接报 `unexpected additional properties`；`impact` 分档粗，与人工分档一致率约 36%，美国 CPI 与 BRC 零售监测同档，hot 下 CPI 可能排到第 12。
- **怎么读**：`query="economic calendar"` + `country="US"` + `sort_by="hot"`；回看 35 天、前瞻 ≤14 天，更远的事件按单日 `date_from=date_to` 查；重要性靠 hot 加事件名白名单（N-130）。
- **依据**：10-03 `0b8d0239…`；10-12 `1b4b1c5b…`（不带 hot）/ `5a2c5c86…` / `71d26ad3…`；U16 09-16 `783ebda1…`、10-10 `9810d4c7…`

### N-129 日历按事件名查不可靠，`keywords` 不过滤 〔A〕
- **现状**：事件名会被当成 ticker。10-12 `query="Non Farm Payrolls"` 仍被解析成 `FARM`，但模糊匹配（`fmp_calendar_fuzzy`）能返回 1 行 `Non Farm Payrolls (Sep)`，`partial`，结果不稳定。10-03 实测：`"nonfarm payrolls"` 只返回 `Nonfarm Payrolls Private`；`"core CPI core PCE"` 被拆成 9 个 FRED 关键词后截断；给日历传 `keywords` 时 `filters_applied.keywords` 为 null，无 warning，也不过滤。query 写 "FOMC rate decision" 不影响排序（GAP U16）。
- **怎么读**：日历 query 只写 `economic calendar`，靠 `sort_by="hot"` 加客户端按事件名筛。
- **历史**：10-03 原记「`Non Farm Payrolls` 返回 0 行」，10-12 起模糊匹配能返出该事件。
- **依据**：10-03 `7c65449d…` / `4aa4260d…` / `cce312bd…`；10-12 `c079982c…`

### N-130 日历事件名与常用叫法不一致，`unit` 不可信 〔D〕
- **现状**（10-12 复测）：核心 CPI 环比叫 `Core Inflation Rate MoM`（名字里没有 CPI）；议息叫 `Fed Interest Rate Decision`；非农总数叫 `Non Farm Payrolls`，另有 `Nonfarm Payrolls Private`。`CPI s.a (…)` 和不带 MoM / YoY 的 `Inflation Rate (…)` 都是指数点位（8 月分别为 334.131 / 334.98）；前瞻行 `CPI (Sep)` 预期 336.8 也是点位，`unit` 却标「%」。EU 的 `Inflation Rate (Sep)` 是点位（104.3），UK 同名行是百分比（3.3）。按「含 CPI」筛会选中点位行，把超预期方向判反。
- `CPI s.a` 与 FRED `CPIAUCSL` 是季调（334.131），`Inflation Rate (…)` 是未季调（334.98），不要混用（GAP U17）。日历 `date` 为 UTC。
- **怎么读**：各 Skill 写死事件名：`Core Inflation Rate MoM` / `Core PCE Price Index MoM` / `Non Farm Payrolls` / `Unemployment Rate` / `Fed Interest Rate Decision`；百分比和点位按数值量级判断，不信 `unit`。
- **GAP R3 复核**（用 10-12 已有返回，未新增调用）：09-28 与 10-09 报告说「CPI 单位标 % 已消失、`Core Inflation Rate` 的 unit 变成 null」，只对已发布的 8 月样本成立（8 月行里没有 `CPI (Aug)` 这一行）；10 月的前瞻行 `CPI (Sep)` 仍标 %，`Core Inflation Rate` 的 unit 是 %、不是 null。10-14 发布后再看这一行会不会被清掉。
- **依据**：10-03 `61375d90…` / `1e2d6adb…`；10-12 `5a2c5c86…` / `71d26ad3…` / `21c9c070…`

### N-161 经济日历数据质量：重复行、空值、回铺深度不定 〔D〕
- **①** 排序：`sort_by="hot"` 先排完 High，再排 Medium、Low；各档内回看按时间倒序，绝对区间按正序（工具描述已写）。带预期值的 Medium 会落到第 2 页；未来日期的 EIA 库存、MBA 利率行没有 estimate（原 N-175③）。
- **②** 回铺深度不定：`country="US"` + 35 天，50 行 High 铺到约 32 天前（核心 CPI 在第 44 行）；不传 country 只铺到 12 天前。会报 `parameter_partial`（"candidate cap reached before full date coverage could be proven"）。
- **③** 同一事件可能有两行：10-15 的 `Retail Sales MoM (Sep)` 有「12:30 UTC / 预期 0.3 / 前值 1.4」和「13:30 UTC / 预期 0.1 / 前值 1.2」两行，宽窗口（10-05~16）被 50 行上限截掉 12:30 那行，看起来像随窗口变（原 N-185①，10-12 证伪）。另有 `Budget Balance (Sep)` 两行（10-12 预期 210、10-13 预期 −28）；`Fed Press Conference` 与 `Press Conference` 并存；两个 Michigan 通胀预期同值但重要性不同（GAP U16）。
- **④** 空值与异常值：`FOMC Minutes` 标 High 但数值全空；前值接近 0 时 `changePercentage` 爆表（CPI n.s.a MoM 前值 −0.01 → 3300，GAP U16）。10-08 记的 `Continuing Jobless Claims` 预期 2070、unit 为空，10-12 已正常（1710，K）。
- **怎么读**：按事件名逐行核对，必要时用 cursor 翻第 2 页；同名多行取 12:30 UTC（美东 8:30）那行，并与官方日程核对；同时刻同值的行合并，取较高的 impact；预期偏离前值 >15% 标「预期存疑」；无数值的 High 事件仍算已发布；前值很小时不用 `changePercentage`。
- **依据**：10-08 `c72b7072…` / `fae3ef66…`；10-12 `5a2c5c86…` / `21c9c070…` / `7b64a9d0…` / `a015ef8b…`；U16 09-23 `3bdef1a7…`、10-10 `87db72f7…`

## metrics · 基本面与分析师

### N-109 fundamentals 的现行返回结构与取数写法 〔C〕
- **①** 超预期与报表合在 `fiscal_quarters[]`，按 `fiscal_period` 成组（工具描述已写）：`earnings_surprise`（`actual_eps` / `estimated_eps` / `eps_surprise_pct` / `actual_revenue` / `estimated_revenue` / `revenue_surprise_pct` / `report_date`）+ `financial_statement`（`revenue` / `eps` / `epsDiluted` / `netIncome` / `ebitda` / `period_end`）。通常只有 1 个元素，`limit` 调大也不会多给季度；配对失败时拆成 2 个元素（见 N-149②）。旧的 `beat_miss` / `latest_quarter` 已不存在。
- **②** `query="全面分析"` / `"comprehensive analysis"` 只返 5 块：consensus_price / eps_trend / fiscal_quarters / income_statement / next_earnings_estimate，另附 `market.history` 10 行和 `technical` 指标（工具描述的示例「AAPL 全面分析」就是这个写法）。历史：红线 7 原记「必须写全面分析才返 14 块（仅缺 stock_peers），不写只返 5 块」，10-01 起正好反过来，10-12 复现。
- **③** 不写 query（或 query 只写代码）返回核心集合：snapshot + balance_sheet + cash_flow + profile_block + `valuation_block.ratios_ttm` + consensus_price / eps_trend / fiscal_quarters / next_earnings_estimate。**不含 income_statement**，4 季利润表要 `query="财报 利润表"`。
- **④** `query="分析师评级 同行 DCF"` 返 analyst_grades / analyst_estimates / stock_peers / dcf / key_metrics_ttm / enterprise_values，不带快照（N-120）。同行与 DCF 的口径见 N-134⑤⑧。
- **⑤** `limit` 截每个嵌套列表（`limit=1` 时 eps_trend 只剩 1 行；`limit=3` 时 sec_filings、stock_peers 各 3 条），`verbosity` 也生效（N-115）。这两点已写进参数描述。来源：GAP U32（09-23 `f263b9b5…`、10-09 `4cb11363…`），10-12 `0e1810d9…` 复现。
- **怎么读**：单股 `metrics(keywords=[T], asset_type="tradfi")` 取核心集合；多块合并见 N-135；批量轻量 `keywords=[≤5], limit=1, verbosity="concise", categories=["market","fundamentals"]`，约 3~4 KB/票。
- **依据**：10-01 `ad9e3732…` `b51bf976…`；10-12 `a6a533a6…` `6e141c6f…`（全面分析）/ `50d2dac5…` `bc833084…`（核心集合）/ `4c58bb11…`（评级同行 DCF）

### N-29 🔴 两个 EPS 口径不一，`actual_eps` 本身口径也不统一 〔B〕
- **现状**（10-12 复测）：同一元素里 `earnings_surprise.actual_eps` 与 `financial_statement.eps` 常不相等，且没有字段标明口径：NVDA 2.22 / 2.47，DAL 1.72 / 1.15，V 3.32 / 2.97，F 0.42 / −0.33，INTC 0.42 / −2.16。
- **①** 反号：INTC 非 GAAP 超预期 +100%，同季 GAAP 净亏 110 亿。只看超预期会把巨亏季读成完美超预期。
- **②** 同号不等更危险，会被当成同一个数混用。08-05 实例：把 2.40（报表）接 2.08（下季预期）写成「利润下滑 13%」，实为 1.87 → 2.08、+11%。
- **③** 两者相等也不代表口径一致（GAP C5，09-17 报告）：AMZN `actual_eps` 5.75 取的是 GAAP（含约 534 亿美元 Anthropic 投资收益），与报表相等，判据不触发，对调整后预期 1.82 算出超预期 +215.9%。JPM `actual_eps` = `eps` = 7.59（10-12 未变），原文 GAAP 稀释 7.70、调整后 6.14，都对不上。
- **怎么读**：反号时标「该超预期为非 GAAP 口径」，改用营收超预期作主锚。两条序列不跨用：和 `estimated_eps` 比只用 `actual_eps`；看趋势只用 `eps_trend`（与报表同源）；GAAP 用 `epsDiluted`（N-134③）。超预期绝对值 >50%，或当季有大额一次性收益时，标「口径可能不一致」，不输出超预期百分比。两个 EPS 进同一句话前，先确认二者在同一个 `fiscal_quarters[]` 元素、且 `fiscal_period` 不为 null（N-149②）。
- **依据**：07-27 INTC 首记；08-05 NVDA；09-17 `8fa83b32…`(AMZN) `c79f2995…`(JPM)；10-12 `a6a533a6…` `000dba41…` `a051bcb7…`

### N-134 fundamentals 字段口径陷阱 〔D〕
- **①** `netDebt` 只扣现金等价物，不算短期投资：NVDA `netDebt` +164 亿，按现金加短投 994 亿减债务 334 亿，实为净现金 660 亿（10-12 复现）。
- **②** `enterprise_values` 是上一财年末的快照：NVDA 停在 2026-01-25（股价 186.47）；当前值在 `key_metrics_ttm.enterpriseValueTTM`（5.57 万亿）。MU 的同类现象见 N-179①。
- **③** `financial_statement.eps` 是基本 EPS，GAAP 稀释在 `epsDiluted`（NVDA 2.47 / 2.46）。报表 EPS 本身也会错：JPM `eps` 7.59、`epsDiluted` 7.57，财报原文稀释 EPS 7.70（GAP U23①，09-17 `c79f2995…`；10-12 数值未变，`a051bcb7…`）。
- **④** `analyst_estimates` 可能缺当前财年，同一财年也会出两行：NVDA 只有 FY2028~FY2031，缺当前的 FY2027；MU 的 FY2029、FY2030 各两行，分析师数不同（同 N-179②）。
- **⑤** `stock_peers` 不按业务挑：每行 `peer_symbol` / `companyName` / `mktCap` / `price`，按 `peer_symbol` 字母序排。FMP 的同业定义是「同交易所、同板块、市值相近」（GAP U25）。10-12 NVDA 的 10 家以半导体为主，但混入客户 CoreWeave、Corvex（MOVE，市值 3.1 亿）和股价 $0.97 的 Exascale Labs（XLAB）；MU 的 10 家是存储同业，但混外国代码，同一公司两地各一行（Gigadevice 3986.HK / 603986.SS），市值按当地货币计（Kioxia 28.7 万亿日元）。10-10 抽查 45 个同行只有 21 个是真对手，还有卡组织（SOFI→Visa/Mastercard）、BTC 财库公司（COIN→MSTR）。同行批量取数只回 `ratios_ttm`、没有 EV/EBITDA（10-03 记，未复测）。原 N-168④ 并入此处。Q4 已定从工具描述摘除同业榜，不再投入修复。
- **⑥** 利润表 `incomeBeforeTax` / `incomeTaxExpense` 偶有错误（10-03 MU 营业利润 443 亿而税前 148 亿、所得税 −229 亿）。10-12 NVDA 正常，MU 未复测。
- **⑦** 13F 的 `*_change_percent` 恒为 0，新建仓行为 100（如 DRAM，10-09 订正）。10-12 NVDA 持有人的 `*_change_percent` 全为 0，而 `shares_change` 不为 0（`ae1f335c…`）。13F 其他字段问题见 N-7 / N-152。
- **⑧** `valuation_block.dcf` 在亏损期给出荒谬值，没有任何失效标注：INTC `dcf` 2.17 对 `Stock Price` 104.7，差 48 倍（07-29 是 2.95 对 86.57）；亏损公司还会给负值（IREN −109.22 对现价 42.62，GAP U23③，09-17 `f7c43fb6…`）。原为旧文件第 300 行未编号附注，本次并入。Q4 已定从工具描述摘除 DCF，不再投入修复。
- **怎么读**：净现金自己算；EV 用 TTM；GAAP 用 `epsDiluted`，与财报原文差超过 1% 以原文为准；预期取 `numAnalystsEps` 足够的近端财年；不引用税前利润与所得税；13F 变动只用绝对值；`dcf` ≤0 或偏离现价超过 5 倍即判失效，新写法不依赖 DCF。同行先按公司名剔除客户、卡组织、财库公司和市值差两个数量级以上的公司，同一公司多地上市去重，不跨币种按市值排序，再用 `profile_block.industry` 核对。
- **依据**：10-03 `165428c1…` `c73c80e8…` `c6ab96f0…`；10-12 `bc833084…`（①③）/ `4c58bb11…`（②④⑤）/ `7788bf46…`（⑤ MU）/ `3ec8ea27…`（⑧）；10-10 `8a688e7a…`（⑤）

### N-149 财报字段时序错位：下次财报日跳季、季度配对失败 〔D〕
- **①** 下次财报日跳过一季：TSLA `next_earnings_estimate.date=2027-02-03`（上一季 07-22 公布，Q3 被跳过），10-12 仍如此。
- **②** 季度配对失败：`fiscal_quarters` 返回 2 个元素，一个只有 `financial_statement`，另一个只有 `earnings_surprise` 且 `fiscal_period:null`。HUBG 的报表停在 2025-Q3（晚一年），surprise 是 10-01 公布的那次；JPM 的报表（2026-Q2）和 surprise 也分在两个元素里。与 N-109①「通常 1 个元素」不符。
- **③** 营收口径不一：JPM `actual_revenue` 573 亿，`financial_statement.revenue` 825 亿。
- **④** 下次财报日是估算值，不标是否经公司确认：09-17 报告记 NVDA 给 11-18，公司电话会宣布的是 11-17（GAP U23②，`284616af…`）；10-12 仍给 11-18（`e7715754…`）。
- **怎么读**：下次财报日距上次超过 120 天视为可疑，用新闻核实；对外写「预计 X 日」，以公司公告为准；多元素时按日期认季，`fiscal_period:null` 的那块不和报表做同季比对。
- **依据**：10-05 `dad481bc…` `df5fc040…` `11755ec7…`；10-12 `a051bcb7…`

### N-24 fundamentals 三种常用写法的体积 〔C〕
- **现状**（10-12，NVDA 单票）：① `"<T> next earnings date"` 约 3.6 KB：consensus_price / eps_trend / fiscal_quarters / next_earnings_estimate，外加 10 行与该票无关的当日财报日历（N-148），**不再带快照**；② 核心集合（不写 query 或只写代码）约 8.3 KB，含快照；③ `"earnings call transcript"` + detail 约 3.5 KB，逐字稿只有 2000 字（N-115）。
- **怎么读**：批量核财报日用 ①，或 N-109 的批量轻量写法；要市值走核心集合或单独拉快照；③ 只用来确认该季逐字稿是否入库。
- **历史**：07-27 记为 5 KB / 8.7 KB / 56 KB，① 附带含市值的快照、③ 含逐字稿全文；10-01 结构换代后不再成立。
- **依据**：10-12 `e25d719f…` `50d2dac5…` `e7715754…`

### N-135 一个 query 能合并多块 fundamentals；批量要带 categories 〔C〕
- **现状**（10-12 复现）：`query="行情 公司简介 资产负债表 现金流 分析师评级 同行 DCF 营收增长率"`、`limit=20`、concise，一次返回快照、简介、两表、评级（20 行）、预期、同行、DCF、TTM 指标、`financial_growth`，只缺利润表（并进来会被挤掉，N-123）。不带 `categories` 时代码会误匹配到宏观日历：MU→坦桑尼亚节日「Mwalimu Julius Nyerere Day」，F→委内瑞拉节假日；带 `categories=["market","fundamentals"]` 就没有。
- **怎么读**：多块一次取，利润表单独一路；多标的批量必带 `categories`。
- **依据**：10-03 `22092c55…` `820d6ef7…`；10-12 `af3ec652…` `bc833084…` `000dba41…`

### N-120 分析师调用不附带行情快照，query 写「行情」才附带 〔C〕
- **现状**（10-12 复现）：`query="分析师评级 同行 DCF"` 没有 market 块；query 里加「行情」就多出 `market.snapshot`，仍计 1 额度。研报 query 未复测。快照的均线字段见 N-150（detail 带 `priceAvg50` / `priceAvg200`）。
- **一次调用能拿到的**：`query="<T> analyst ratings price target"` 返回 consensus_price + analyst_grades（默认 10 行）+ analyst_estimates + eps_trend + fiscal_quarters + valuation_block（INTC 10 行 / 8 家）。共识和基本面一次拿全，价格腿要加「行情」或另拉快照。历史：07-29 原记（旧文件第 296 行）「20 行 / 17 家，且带 `beat_miss` 和快照」，结构换代后不再成立。
- **怎么读**：c3 / c6 / r1 这类要现价的地方，query 带「行情」。
- **依据**：10-01 `9e8b31fd…` `ffdbe960…`；10-12 `4c58bb11…` `af3ec652…` `3ec8ea27…`

### N-16 目标价共识没有家数，口径也不透明 〔C〕
- **现状**（10-12）：`consensus_price` 仍只有 targetConsensus / High / Low / Median，没有家数。样本窗口和纳入范围没有文档，与主流聚合差距大：TSLA 低 / 均 / 高 370 / 471 / 840，主流是 125 / 约 400 / 600；NVDA 最低 270，主流 180。疑似只收了近期新闻源（StreetInsider、TheFly、Benzinga）里的目标价（GAP U24，09-16 `284616af…`、09-17 TSLA 对照）。
- **怎么读**：家数由 `analyst_grades` 估算（N-147），写明「估算」；对外引用写「口径未公开、与主流聚合有差异」，区间用 grades 近 180 天自己估。Q4 计划在工具描述里把它降级为「须附样本数与口径说明」。
- **依据**：07-23 首记；10-12 `a6a533a6…`

### N-147 `analyst_grades`：默认 10 行、上限名不副实、无时间窗、评级不归一 〔B/C〕
- **①** 默认 10 行（NVDA、INTC 各 10 行，INTC 是 8 家）；`limit=20` 返回 20 行。
- **②** 传 `limit=21` 报 `parameter_partial`「capped at 20 rows total」，实际回 21 行（HUBG）。原记于 N-174⑤，并入本条。
- **③** 不带时间窗：HUBG 21 行跨 2025-10-31 ~ 2026-10-06。
- **④** 没有归一字段：HUBG 21 行里有 10 种写法（Equal Weight / Buy / Outperform / Neutral / Sell / Hold / Overweight / Positive / Market Perform / In Line）；研报卡有 `stance_normalized`，两边口径不统一。query 写 "upgrades downgrades" 不会只返回变动（21 行里 17 条 maintain）。来源：GAP U27（10-10 metrics 扫描 H 节），10-12 复现。
- **怎么读**：家数 = `limit=20` + 近 180 天 + 按 `gradingCompany` 去重，20 行全在窗口内时写「≥N 家」；评级客户端自建三档映射；升降级按 `action` 字段筛。
- **依据**：10-05 `37fdaa48…` `72615456…`；10-12 `18d44e16…` `3ec8ea27…` `af3ec652…` `d3090b57…`

### N-123 年度增长率可得（`financial_growth`） 〔C〕
- **现状**（10-12 复现）：query 写 "revenue growth / 营收增长率" 返回 `financial_growth`，最近 4 个财年的同比（`revenueGrowth` / `netIncomeGrowth` / `epsgrowth` / `grossProfitGrowth` / `operatingIncomeGrowth` / `freeCashFlowGrowth`）加五年每股累计增幅（`fiveY*`）。三表仍只有 4 季（写 annual 或 `limit=6` 也一样）。「增长率」和「利润表」写进同一 query，`income_statement` 会被挤掉。
- **怎么读**：3 年 CAGR 用 `revenueGrowth` 连乘；利润表单独一路。季度同比见 N-54。
- **依据**：10-01 `f3e7687b…` `4d4c1124…`；10-12 `af3ec652…`

### N-54 季度数组只有 4 季，季度同比算不了 〔A〕
- **现状**（10-12 复现）：income_statement / eps_trend / balance_sheet / cash_flow 都只有 4 季。META 返回 Q3'25~Q2'26，算 Q2'26 同比需要的 Q2'25 不在。
- **怎么读**：季度只做环比，或标「同比数据来自外部」；别把窗口里最老那季当去年同期（那是 3 季前）。年度同比用 `financial_growth`（N-123）。服务端多给 1 季即可消除。
- **依据**：07-30 META 首记；10-12 `8f12976f…`

### N-115 逐字稿正文截到 2000 字符 〔A〕
- **现状**（10-12 复现）：`verbosity` 对 metrics 生效（concise 200 / standard 600 / detail 2000 字符上限）；`transcript[0].content` 在 detail 下也只有 2000 字、`content_truncated:true`，没有翻页入口，只够读到开场白（NVDA FY27 Q2）。N-27「verbosity 无效」随之作废。
- **怎么读**：关键词深扫先找公司新闻稿或公开实录，MCP 逐字稿只用来确认该季是否入库，news 引语兜底；都拿不到标「欠测」。Q4 O2 计划交付「电话会全文 + 分段」。
- **依据**：10-01 `6910a69c…` `8d80748c…`；10-09 P16 `ae12763e…`；10-12 `9ba6e9f2…` `e7715754…`

### N-34 逐字稿季度的判断 〔C〕
- **现状**（10-12）：逐字稿行带 `date` / `fiscal_year` / `fiscal_quarter` / `period`（工具描述已写）。NVDA 逐字稿 FY2027 Q2、2026-08-26，与 `fiscal_quarters[0]`（2027-Q2，report_date 08-26）一致。今天没有碰到滞后样本。
- **怎么读**：逐字稿属于哪季，看 `transcript[0].date` / `fiscal_year` / `fiscal_quarter`。预判滞后：`earnings_surprise` 单独成元素且 `fiscal_period:null`（N-149②），或 `next_earnings_estimate` 已滚到下一季而 `fiscal_quarters` 没动（N-163），就说明该季三表和逐字稿还没入库，按「欠测」处理。欠测和「扫了没讲」要分开标。
- **历史**：07-29 用 `gap = beat_miss.date − latest_quarter.date ≥ 90 天` 预判逐字稿滞后（42 样本全部成立；60 天阈值被中概 ADR 证伪；「距财报日天数」假设也被证伪）。10-01 结构换代后两个日期落在同一 `fiscal_period` 元素里，gap 判据随 N-33② 作废。逐字稿只给 2000 字后，「先算 gap、滞后就跳过省 1 额度」的意义也不大了。
- **依据**：07-29 42 样本；10-12 `e7715754…`

### N-15 财报当晚超预期数据可能还是上一季 〔D〕
- **现状**：07-23 GOOGL 盘后发 Q2，当晚返回的超预期（当时的字段 `beat_miss` 现已不存在，对应 `fiscal_quarters[0].earnings_surprise`）仍是 Q1。10-12 不是财报夜，无法复测；旁证：DAL 10-09 发财报，10-12 已更新（report_date 10-09，period_end 09-30）。
- **怎么读**：财报当晚的「实际 vs 预期」取 news 原文（0 额度），metrics 只做盘后快照与目标价，次日后再用 metrics 复核。更新顺序与半更新见 N-163、N-126。
- **依据**：07-23 GOOGL 实跑；10-12 `000dba41…`

### N-126 财报后 `earnings_surprise` 可能整块缺失 〔D〕
- **现状**：10-01 MU（09-30 盘后发）`fiscal_quarters[0]` 已是新一季、带 `financial_statement`，但整块 `earnings_surprise` 缺失，既没有预期值也没有 `report_date`。10-12 复查 MU 已补齐（report_date 09-30，`actual_eps` 33.42 对预期 31.77），缺口是暂时的，12 天内补上。
- **怎么读**：读超预期前先判 `earnings_surprise` 在不在；缺失就用财报日历行（N-114）或新闻原文自算，标「超预期数据未更新」，不拿上一季顶替。
- **依据**：10-01 `be7b7cf1…`；10-12 `bc833084…`

### N-163 财报后先滚下次财报日，`fiscal_quarters` 后更新 〔D〕
- **现状**：10-08 观察到 APLD 发财报次日、STZ / LW / RPM 两天后，`next_earnings_estimate.date` 已滚到下一季，`fiscal_quarters` 仍停在上一季；电话会逐字稿比基本面块先入库。10-12 复查这四家都已更新，滞后不超过 6 天。新季度初版数据缺项（折旧、利息为 0，资本开支符号反）见 N-175⑤。
- **怎么读**：下次财报日距本季末超过 150 天，按「已发、基本面块未更新」处理，不判「这期还没发」。
- **依据**：10-08 `e0f88bc4…` `9713480d…` `040cabff…`；10-12 `a051bcb7…` `1a42225b…`

### N-33 超预期字段为 null 时被当 0 运算，输出 −100% 〔B〕
- **①** 07-29 实测 F：`revenueActual: null`、`revenueEstimated` 472 亿，服务端把 null 当 0 做减法，输出 `revenue_surprise_pct: -100`。条目结构完整，N-23 的三道检查全部通过，是数据缺失的第 4 种形态。10-12 无 null 样本，无法复测（F 的 `actual_revenue` 已补成 483 亿）。字段现名 `actual_revenue` / `revenue_surprise_pct`。
- **②** 同季确认的 gap 判据（10-12 已修，见归档）：服务端已按 `fiscal_period` 成组，不用再算 gap；配对失败的情形见 N-149②。
- **怎么读**：`actual_revenue` 不为 null 才读 `revenue_surprise_pct`；见到 −100 一律先当缺失查证。
- **依据**：07-29 v1.2 实跑 + F 单票复核；10-12 `000dba41…`

### N-168 估值和宏观数据的时点错位 〔C〕
- **①** 估值按前收：盘中 `dcf["Stock Price"]`、`ratios_ttm`、`key_metrics_ttm` 仍按前一交易日收盘算（10-08 实测）。10-12 盘前 MU `dcf["Stock Price"]`=1029，等于 10-09 收盘；盘中部分待补测。N-175⑥ 与此重复，已并入本条。`enterprise_values` 的股价是财年末价，见 N-134②。
- **②** `meta.fundamentals_valuation_asof` 不能当时点用：10-12 08:03 UTC 的调用返回 12:33Z，比调用时间晚 4.5 小时；08:00 UTC 的另一次返回 06:01Z；有的调用干脆不带这个字段。
- **③** 美东上午 FRED `DGS10` / `DFII10` 最新只到两个交易日前（10-12 周一 04:00 ET 最新为 10-08）。宏观数据滞后以 N-139 为准。
- **④** `stock_peers` 名单内容 → 已并入 N-134⑤。
- **怎么读**：引用估值写明「按前收」；新鲜度不靠 asof 判断。
- **依据**：10-08 `cf9b1fe3…` `137b0c98…` `58836295…`；10-12 `7788bf46…`（①）/ `000dba41…` `4c58bb11…`（②）/ `57d9ea4c…`（③）

## metrics · 财报日历

### N-22 🔴 财报日历不能当完整名单：带不带 `country` 都会漏大票（主条） 〔A/B〕
- **①** 传 `country="US"`：500 候选上限在过滤之前生效，候选从区间最晚的一端取，结果只剩区间末尾一两天。10-12 查 10-13~10-16，只回 17 行，全在 10-15 / 10-16；10-13 发财报的 JPM / WFC / GS / C / JNJ 全缺（它们的 `next_earnings_estimate.date` 都是 10-13）。返回 `status:"partial"` + `parameter_partial`「country candidate cap 500 reached…」，但 `has_more:false`，也不说丢了哪几天（N-72）。
- **②** 不传 `country`：按日期正序，同一天按代码字母序（数字开头的外国代码最前），每页最多 50 行，一个工作日就上百行。10-13 前两页 100 行几乎全是外国代码和 OTC 股（只有 ACI、AZZ 两只美股），JPM 等排在更后面（N-162）。
- **③** `country` 对财报日历是生效的，按发行人注册地过滤（工具描述已写明），注册地不明的行也会被剔掉；美国上市的外国注册公司因此被滤掉（N-133）。N-32 前半句「country 不作用于财报日历」已作废。
- **怎么读**：个股财报日一律以 `next_earnings_estimate.date` 为准，`keywords=[≤5], query="next earnings date", limit=1, verbosity="concise"` 逐只核关注池，对外写「预计」（N-149④）。市场级日历只作补漏：不传 `country`，按 `cursor` 翻页，写明覆盖到的末行日期；完整性只看 `status`（N-72）。不对外发布「某日 / 本周全部财报」，名单要注明「来自关注池，不是全市场扫描」。
- **历史**：07-27 首记（不传 country 时零美股）；08-04 早间判「大部分修复」，同日撤回；10-01 N-114 判「N-22 销案」，10-12 三段独立复现，证伪。旧记的「传 country 返回 0 条」「`next_cursor` 无对应入参」已过期：现在是丢区间前段，`cursor` 可以回传。
- **依据**：08-04 `03c16ce8…` `bfe1c45f…`；10-12 `052efd1d…` / `5bad39ab…` / `560f9bc2…`（三段复现）、`0e1810d9…`（大行下次财报日）、`af63b872…` `a9143cd7…`（不传 country 两页）

### N-17 财报日历漏掉当天的美股大票（10-12 回归，从归档移回） 〔A/B〕
- **现状**：07-23 首记：当日 30 条全是印度、欧洲、OTC 小票，AAL 的 `next_earnings_estimate.date` 是当天，日历里却没有；08-04 销案归档。10-12 回归：`country="US"` 查 10-13~10-16，10-13、10-14 两天 0 行，JPM / WFC / GS / C / JNJ 全部缺席。
- **怎么读**：按 N-22。重点标的必须用 `next_earnings_estimate.date` 交叉核对，名单不全如实标注。
- **依据**：07-23 实跑；10-12 `560f9bc2…` `93b814c2…`

### N-114 日历行可用来自算超预期；「N-22 销案」作废 〔B〕
- **现状**：日历行带 `epsActual` / `epsEstimated` / `revenueActual` / `revenueEstimated`，可以用 `cursor` 翻页。但覆盖不全，10-12 带 `country="US"` 一周只有 17 行，10-13 / 10-14 全缺（N-22①）；同时 JPM / WFC / GS 是 10-13、ASML 10-14、TSM 10-15，都不在那份日历里。
- **怎么读**：基本面块滞后时（N-126、N-163），可以用日历行的实际值和预期值自算超预期（10-01 MU 09-30 已发，日历行有实际值，而 `fiscal_quarters` 仍停在 06-24 那一季）。当发现腿怎么用，按 N-22。
- **历史**：10-01 原记「财报日历可用，N-22 销案」，示例写法带 `country="US"`；10-12 证伪，两种写法都漏大票。
- **依据**：10-01 `60ad4a02…` `9a39d28c…`；10-12 `5bad39ab…` `4d0c73fa…`

### N-133 `country` 按注册地过滤；`keywords` 不过滤日历 〔A〕
- **现状**：`country` 按发行人注册地过滤：ACN（爱尔兰注册）10-01 发财报，带 country 时不在名单；10-01 还见过 warning「missing stored profile country for …(+291 more)」，即没有注册地资料的行被剔掉。但漏票的主因是候选上限（N-22①），10-12 美国注册的 JPM / WFC / GS 一样被漏。`keywords` 对日历块不起过滤作用：传 `keywords=["JPM","WFC","GS","TSM","ASML"]` 时附带的日历仍是当天的 0UYN.L、195870.KS 等。不传 country 时混有 `.KS/.T/.L` 外国代码和 `MKC-V` 这类重复股类。
- **怎么读**：按 N-22。
- **历史**：10-03 原规避「不传 country，客户端只留 `^[A-Z]{1,5}$`」已不够用：正则会放过 AACTF、AONNY 这类 OTC 股，而且要翻很多页；「不传 country 返回 41 行、status ok」只在当天成立（N-148 已订正）。
- **依据**：10-01 `bb125dfd…`；10-03 `94fe8ac7…` `9647dfac…` `a5c3eb9c…`；10-12 `5bad39ab…` `4d0c73fa…` `a9143cd7…`

### N-162 日历排序：绝对区间正序、回看倒序、同日按代码字母序 〔C·已文档化〕
- **现状**（10-12 复现）：传 `date_from` / `date_to` 按日期从早到晚，传 `time_range` 从晚到早（工具描述已写）；同一天内按代码字母序，数字开头的外国代码在最前。一个工作日上百行，每页最多 50 行只覆盖一天左右（10-12~10-16 首页是 10-12 的 42 行 + 10-13 的 8 行）。`cursor` 翻页可用。`country="US"` 从区间最晚端取候选，所以丢的是前几天（N-22①）。
- **怎么读**：市场级日历翻页，并写明覆盖到的末行日期；`country` 不传。
- **依据**：10-08 `6edb85a2…` `b0919911…` `4af3cc81…`；10-12 `1003d899…` `a9143cd7…`

### N-148 日历默认 10 行、`sort_by="hot"` 不适用、会被自动附带 〔C〕
- **现状**（10-12 复现）：不传 `limit` 时日历默认 10 行，上限 50（超出用 50 并在 warnings 里报，工具描述已写）；`sort_by="hot"` 报 info 级 `not_applicable`，顺序不变。`query="next earnings date"` 会自动附带当天的 `earnings_calendar` 块，和所查股票无关（查 NVDA 附带 10 行 0UYN.L、195870.KS…；`limit=1` 时附带 1 行）。排序规则见 N-162。
- **怎么读**：读 `next earnings date` 的返回只看 `next_earnings_estimate`，忽略附带的日历块。周报不用市场级日历。
- **依据**：10-05 `b8310a39…` `8c159a0f…` `abbb8384…`；10-12 `b20e9d3f…` `1003d899…` `e25d719f…`

### N-98 不带代码的日历是当天的全球流水，不是「重要财报」 〔A〕
- **现状**（10-12 复现）：`query="本周 财报日历"` 返回 10 行，全是当天 10-12，按代码字母序（0UYN.L、195870.KS、2408.TW…），10 行里 6 行 `epsEstimated:null`。「本周」不会被解析成时间窗（工具描述：服务端不从 query 推断时间窗）。
- **怎么读**：「今天 / 本周有什么重要财报」这类问题，改成对关注池逐只查 `next_earnings_estimate`（N-22）；对外指南写成「我关注的这几只什么时候发财报」。要时间窗就显式传 `date_from` / `date_to`。
- **依据**：08-17 `39c39e2b…`；10-12 `8f51092a…`

### N-72 `status:"partial"` 与 `has_more:false` 同时出现，完整性只看 `status` 〔B〕
- **现状**（10-12）：`country="US"` 查 10-13~10-16 那 17 行的返回，同时带 `has_more:false` 和 `status:"partial"`（cap 500 warning），实际 10-13 / 10-14 整天缺失。同一写法用默认 10 行时 `has_more:true`、带 `cursor`，可见 `has_more` 只管翻页、不管覆盖。`meta.filters_applied` 仍不回显 `country` / `date_from` / `date_to`。
- **怎么读**：`partial` 就是不完整，不管 `has_more` 怎么说；产出写「（服务端提示覆盖不完整）」并转述 warning 原因，不写「本周全部」。
- **依据**：08-04 `ad0458ae…`；10-12 `052efd1d…` `560f9bc2…` `b20e9d3f…`

## metrics · 研报（研报卡、榜单、分页）

> 榜单 = 不带代码的「研报提及榜」（`research_report_most_mentioned`）；钻取 = 带代码的研报卡片流（`research_reports`，分 `subject_reports` 专题层 / `mention_reports` 提及层）。研报只在 `asset_type="tradfi"`。
> 已修的研报条目（N-37 系、N-61、N-65、N-78~N-84、N-140）见归档区。

### N-19 榜单排名高≠有专题报告 〔B〕
- **现状**（10-12 复测）：榜单按提及次数排，榜面只有 `mentioned_report_count`，不给 subject 计数。NVDA 是 7d 榜第 1（30 篇提及），7d 钻取却是 subject 0 / mention 10；30d 首页 subject 2 / mention 8。
- subject 数是时点状态，会日间剧变：07-23 GOOGL subject 0 → 07-29 为 6；08-07 NVDA 7d 全是 mention → 08-12 有 2 篇 subject。`report_returned_count` 有货才给，不保证 10（07-29 F 只有 3 篇，全是 mention）。
- **怎么读**：每次当场看 `subject_report_returned_count`，不照抄历史结论。subject=0 时降级为提及叙事，文案写「被行业报告提及」，不写「专题研究」；「被最多研报写到」≠「最多机构在研究它」。mention 卡的 `detail.catalysts` / `key_caveat` / `consensus_diff` 照样可用。
- 产品侧 08-12 决定不向 dev 提「榜单给 subject 计数」；r0 对 Top 3 预检多花的 3 额度是已接受的固定成本，复核不再上报。
- **依据**：07-23 首记；08-07 / 08-12 复测；10-12 `66ac7a9c…` / `a0eea254…` / `80362788…`（N-64 与原第 327 行已并入本条）

### N-39 榜单 `mention_impact` 不是机构共识；提及方向值不统一 〔A/C·已文档化〕
- **①** 榜单 `mention_impact{counts:{adverse,beneficiary,mixed,neutral}, dominant}` 统计的是「多少份报告怎样描述该票」（工具描述已写明），属提及层叙事计数，不是评级共识；被点名的受益股天然偏正。10-12 NVDA 7d `beneficiary 18 / neutral 12` → `dominant:beneficiary`。同一标的换窗口 `dominant` 也会换（08-04 NVDA 7d=neutral、07-01→07-15=beneficiary）。平局值为 `tie`（N-80）。
- **②** 方向值已见清单（唯一维护处）：卡片 `mention_context.mention_direction` = `beneficiary` / `neutral` / `negative`（10-08 起）/ `competitor`（10-05）；榜单 counts 键 = `adverse` / `beneficiary` / `mixed` / `neutral`。卡片 `negative` 对应榜单 `adverse`（10-10 用卡片复算 AAPL、STX 的榜面计数对得上）；`competitor` 记入榜单哪个桶未测。
- **③** 方向的视角不对（10-10，U26）：`mention_direction` 标的是「该票在主体公司故事里的角色」，不是「对该票本身的影响」，抽 32 条有 5 条可争议。例：NVDA 作为台积电、Bloom 的需求方被标 beneficiary；Largan 报告里 Apple 是风险来源被标 negative；MS 把 Bloom 写成竞争对手却标 beneficiary。
- **怎么读**：榜单方向只当叙事雷达（谁被反复点名），不写「机构看多」。方向结论用钻取后 subject 卡的 `stance_normalized` 重算（N-38③），并按下界表述。引用单条 `mention_direction` 前先读 `rationale` 判视角；负面值按 {`negative`, `adverse`} 归一。
- **依据**：07-29 首记；10-10 `4232f039…` / `3f044148…` / `86fc7c0c…` / `9a3b00e7…`；10-12 `80362788…` / `a0eea254…`（N-154④、N-177⑥、N-174⑦ 的方向枚举已并入②）

### N-60 榜面目标价覆盖≠专题密度 〔C〕
- **现状**（10-12 复测）：字段已改名 `target_price_coverage.with_target_price`（N-82）。亚洲票明显偏高：三星 77、台积电 69，对 NVDA 52、MSFT 33、GOOGL 28、AAPL 20。原因是亚洲券商在晨报、综述里也照列目标价（mention 级 TP）；行业报告顺带给的目标价同样计入（N-164④）。
- **怎么读**：不用它推专题密度，只能说「多少篇报告写了数字目标价（含 mention 级）」。比较专题密度要翻页枚举后数 subject（N-81）。
- 历史：08-01 原记「三星 TP 30、GOOGL 14，首页 subject/mention 却都是 6/4」；10-12 首页三星 10/0、GOOGL 7/3，首页被 10 卡截顶，不翻页比不出来。
- **依据**：08-01 `89742e42…`；10-12 `bd13fd5f…` / `07f90b23…` / `9490ab0e…`

### N-164 🔴 研报库入库、回补与计数口径 〔B〕
- **①** 返回里没有新鲜度提示：09-28~10-07 停更期间 `status`、`time_scope` 全部正常（N-140，已归档）。10-12 库在正常入库（7d 132 篇、最新 10-10），但仍无任何新鲜度字段或 warning。
- **②** 回补会改写历史窗口：10-08 一批（后缀 `__20261008T105153`）补进 09-28~10-07，09-28 那周 7d 从 6 篇变 124 篇。`event_id` 前段日期不是报告日（`evt-20260930_…__20261008T105153-008` 的 `report_date` 是 09-28），后缀才是批次时间。
- **③** 家数不按券商合并：`distinct_institution_count` 把 `UBS` 与 `UBS Securities LLC` 算两家；10-12 卡上同时有 `UBS` / `UBS Global Research`、`J.P. Morgan` / `J.P. Morgan Securities LLC`（另见 N-38②）。
- **④** 榜面 `with_target_price` 会算上行业报告里顺带给的目标价（见 N-60）。
- **⑤** mention 卡的 `matched_asset_target_price` 没有 `security` 键，但会配 `mention_rating`。
- **⑥** 多标的一次查研报共用一页 10 张卡，按卡流分摊，后面的标的可能为 0 且无警告（10-12 MU+NVDA+AAPL 分到 5+3+2）〔C·已文档化〕。
- **⑦** 入榜量随滚动窗口和回补变化：7d 08-06 163 / 08-07 126 / 08-12 168 / 10-12 132；累计 08-07 770 → 08-12 913 → 10-12 2230。
- **怎么读**：出榜前过样本闸——`eligible_event_count`、Top 5 机构家数、累计榜最大 `latest_report_date` 距今天数（阈值见 c3 / r0）；失效时改拉最近 7 个有数据日或 30d，并写明最新入库日。数字出榜时当场记录（回补后现场无法复现）。家数按券商合并后再写；多标的研报逐只查；对外文案不写死入榜量。
- **依据**：10-05 `b93b3e05…`（停更现场）；10-08 `ddc27235…` / `0d6a9114…` / `75145fd4…`；10-12 `f40a4669…` / `9447b962…` / `edd4b9b4…`

### N-153 精确取窗用 `date_from`/`date_to`；与 `time_range` 同传时后者被静默丢弃 〔B·已文档化〕
- **现状**（10-12 复测）：`date_from` + `date_to` 可精确取窗，榜单和钻取都按 `report_date` 含两端过滤（钻取块带 `time_scope:"report_date_window"`，榜单本身已无 `time_scope` 字段）。与 `time_range` 同传时绝对区间优先，`time_range` 从 `filters_applied` 消失、无 warning。工具描述已写「date_from 优先」，返回里仍不提示。
- `time_range="7d"` 两端都算，实际覆盖 8 个日历日（10-12 查得 10-05~10-12）。
- **怎么读**：按自然周、事件窗取数用 `date_from`/`date_to`，不与 `time_range` 同传。
- **依据**：08-12 `af242e96…`（原第 321 行，首次确认可精确取窗）；10-05 `2e62856e…`；10-12 `ac21b0cb…` / `ed996c6c…`

### N-38 单页 10 卡、未翻完的家数是下界；机构名与评级不归一 〔A〕
- **①** 每页最多 10 张卡（工具描述已写明），`next_cursor` 可翻页取全（N-81）。没翻完时任何「N 家机构」都是下界：10-12 NVDA 30d 首页 subject 2 / mention 8、`has_more:true`；7d 榜 `distinct_institution_count:11`。
- **②** 机构名不归一：`Morgan Stanley` / `Morgan Stanley MUFG Securities Co., Ltd.`（10-12）/ `Morgan Stanley & Co. LLC`（07-29）；UBS、J.P. Morgan 同理（N-164③）。库内 `institution_alias_v0.json` 可用来归一，MCP 侧没有。
- **③** `rating_current` 是原文：Buy / Overweight / In-Line / Outperform / Market-Perform / Attractive 混用，甚至是整句（"Prefer semiconductor capital equipment to semiconductors"）。归一字段 `stance_normalized`（08-12 起）已见值：公司报告 `positive` / `neutral`，行业或策略报告 `null`（"Attractive"→null，"In-Line"→neutral）。复合值见 N-177③，数字码见 N-183④。
- **怎么读**：家数先归一机构名，再按 N-3 / N-62 去重；未翻完写「可见 X 家」。评级分布用 `stance_normalized`，不自建映射。需要全覆盖的信号（库内错位 / 信念族）要翻页取全后才成立，翻页成本见 N-183②。
- 历史：07-29 原记「榜面 23~25 家，钻取去重只见 3 家」，是 10 篇死顶加去重叠出来的，08-12 可翻页后不再成立。
- **依据**：07-29 `555d5409…` / `be2c7554…`；10-12 `a0eea254…` / `66ec98b3…` / `80362788…`

### N-142 分页：10-15 起跨层按日期倒序（此前 subject 优先） 〔C〕
- **现状**（10-15 复测，正式端与测试端一致）：卡片流**不再 subject 优先**，subject 与 mention 混排、统一按 `report_date` 倒序。AMD 30d 首页 10 张全是 mention（10-13→10-09），标的层到第 4 页才出现（花旗 09-28）；MU、NVDA 30d 首页同样 0 张 subject，而两只 30 天内都有标的层报告（`55ffc7ef…` / `bbd130d8…` / `81643993…`）。这是 Dev 对 N-181① 的处理：按新到旧读，最先碰到的目标价就是最新的；分层本身未改。**「首页一出现 mention 就说明 subject 已见尽」不再成立**——要数标的层报告必须按日期翻到窗口下限或 `has_more:false`。
- **旧现状**（10-12 复测，已失效）：卡片流先排 subject、再排 mention，层内按 `report_date` 倒序（工具描述写了 subject 优先）。首页一出现 mention，subject 就已见尽。不传窗口时首页可能全是旧 subject：10-12 NVDA 首页 subject 10 / mention 0，最新 09-28（距今 14 天），同期 7d 榜 NVDA 有 30 篇提及、最新 10-09。
- 翻页游标在 `meta.pagination["fundamentals.research_reports"]`（键名含点），回传时其余参数一字不改（含 `verbosity`）。单标的 detail 一页约 83–106K 字符，会超工具输出上限落盘（另见 N-188⑤）。
- **怎么读**：模板写明报告日期跨度与 `time_scope`；最新 subject 距今 >21 天时领读先声明。**不依赖排序**：按 `next_cursor` 翻页、逐张按 `match_type` 分层，翻到卡片日期早于窗口下限或 `has_more:false` 为止；同一机构按新到旧第一次出现的目标价即最新价。用脚本按字段解析。
- **依据**：10-05 `495a1d17…` / `286fe916…` / `68660816…`；10-12 `9447b962…` / `f40a4669…`

### N-66 subject 与 mention 共享一页名额，跨标的关系数据主要在 mention 卡 〔C·已文档化〕
- **现状**（10-12 复测；10-15 起不再 subject 优先，见 N-142）：一页 10 卡由 subject 和 mention 共享、subject 优先（工具描述已写明）。跨标的关系数据（`revision_summary.by_name` 里的他标的行、`mention_context`）几乎只在 mention 卡里——07-29 统计 30 篇 subject 的 `by_name` 恒为 1 行（标的自己）。专题覆盖多的票首页可能没有关系边：07-29 台积电首页 10/0、关系边 0；10-12 2330.TW 30d 窗口首页 7/3（`225df57e…`），不带窗口时 10/0（N-143）。
- **怎么读**：做产业链分析先读 `mention_report_returned_count`；为 0 时翻页取 mention（N-81），不要写成「该票没有产业链」。不要按榜单排名挑产业链分析的标的。
- **依据**：07-29 四标的对照（NVDA / INTC / GOOGL / 2330.TW）；10-12 `225df57e…`

### N-143 双重上市的研报按代码分桶，与工具描述不符 〔A/C〕
- **现状**（10-12 复测）：工具描述写 "searches every resolved ticker, including multiple listings from one alias"，实测 ADR 与本地代码互不展开：TSM 首页 subject 0 / mention 10，2330.TW 首页 subject 10 / mention 0（最新 10-08），两次 `filters_applied.keywords` 都只有一个代码。
- 反过来，用公司名查能展开（10-10，U21）：按 "TSMC" 查展开到 TSM + 2330.TW、subject ≥3 篇；按 TSM 查 subject 0、mention 1。但公司名能否解析因名而异（三星的中、英、韩写法都被静默丢弃，见 N-97）。
- **怎么读**：产业链读穿（mention）用 ADR / 美股代码，单标的解读（subject）用本地代码；ADR 标的可补一次公司名查询，查完核 `filters_applied.keywords` 非 null。两边结果不要互相当缺失。描述与行为冲突，待提 dev（改行为或改描述）。
- **依据**：10-05 `e9678282…` / `132cfcdc…`；10-10 `e9bba54c…` / `d84bc46c…`；10-12 `96ef1628…` / `6c1e3f73…`

### N-3 同一份报告可能以两个 `event_id` 重复入库 〔D〕
- **现状**：07-22 首记同一份报告双 `event_id`；07-29 见 Citi 同日同 TP $300 两张卡、`event_id` 不同。10-12 NVDA 7d 的 10 张 mention 卡按 机构+标题+日期 无重复，样本太小，不判已修。
- **怎么读**：按 机构（先归一，N-38②）+ 标题 + 日期 去重；「快评 + 完整版」去不掉，见 N-62。
- **依据**：07-22 首记；10-12 `66ac7a9c…`

### N-62 同机构「快评 + 完整版」两张卡，N-3 去不掉 〔D〕
- **现状**（10-12 回放仍在）：同机构对同一事件常发盘后快评 + 次日完整版，标题不同，N-3 的三元组去不掉。INTC：Goldman 07-23 两张同为 TP 150（"First Take…" 与 "Strong quarter…"）；Citi 07-23 Quick Take 与 07-24 完整版同为 TP 130。
- **怎么读**：同机构 + 同日 + 同 TP → 强制合并（留信息更全的一篇）；跨日的按机构取最新一篇。不做这一步，INTC 7 条 subject 会读成 7 家，实为 5 家。
- **依据**：07-29 首记；10-12 `66ec98b3…`

### N-141 detail 的嵌套数组被截顶，各数组没有截断标记 〔B·已文档化〕
- **现状**（10-12 逐卡核对与原记录一致）：每篇 `detail.caveats` 恒 1 条（与 `key_caveat` 逐字相同）、`risks` 2、`key_points` 3、`data_points` 3、`catalysts` 2、`chart_takeaways` 2、`affected_names.items` 5。原始计数在 `detail_sections`（工具描述已写 "capped evidence sections plus original section counts"），如 caveats 2–7、catalysts 3–16。改 `limit`、改 query 都解不开。
- 各数组自身没有截断标记；只有 `affected_names` 带 `total` / `truncated`（08-12 起有内容，N-65；10-12 MS 一篇 `total:67`、items 只给 5）。
- **怎么读**：产出写「可见 X / 报告内 Y」（Y 取 `detail_sections`）；「近期没有节点」「报告未自陈」一律限定「在可见样本内」。`affected_names` 只当名单，关系边仍以 `mention_context` 为准。
- **依据**：10-05 `f85fed57…` / `78e2ef6e…` / `d4291e56…`（dev 同）；08-12 `faf6dc57…`；10-12 `9447b962…` / `a0eea254…`

### N-165 研报字段时有时无 〔B〕
- **现状**（10-12 复测）：`key_caveat`、`consensus_diff`、`scenarios`、评级字段可能整个缺失，`detail_sections` 里却有计数——UBS 一张卡缺 `rating_*` / `consensus_diff`、detail 缺 `scenarios`，`detail_sections` 记 consensus_diff=1、scenarios=3。mention 卡的 `rating_current` / `report_subject_target_price` 属于报告主体，不是本标的。卡片顶层 `coverage_flag.missing` 会列出缺什么（N-181②）。
- **怎么读**：缺字段写「未返回」，不写「报告没给」；mention 卡的评级和 caveat 先判是不是在说本标的。
- 历史：10-08 原记「流程备注改出现在 `coverage_flag.missing`」，10-12 证伪：`key_caveat` 里仍有 6/40 是流程备注（N-144①），两处都会出现。
- **依据**：10-08 `f97838b6…` / `2fc8c64e…`；10-12 `9447b962…` / `96ef1628…`

### N-144 `key_caveat` 不全是报告自陈，要先分流 〔B〕
- **①** 混入抽取流程备注："supplied full-report AI digest…"、"filename is rendered in English…"（10-12 40 张卡里 6 张）。不带 filename 字样的新形态见 N-177⑦。
- **②** 书目缺失："does not provide a prior target price"（10-12 GS 两张）。
- **③** 抽取器检出的报告内部数字矛盾：MS 摘要表 $81.6B 对正文 $96.2B（10-12 仍在）。
- 另一种形态「抽取器指出报告没给某项实质内容」见 N-181②。
- **怎么读**：流程备注、书目缺失不计分；内部矛盾标「抽取时发现」，不写成「报告承认」；N-181② 那类注明「抽取器所见」。
- **依据**：10-05 `68660816…` / `f85fed57…`；10-12 `96ef1628…` / `6c1e3f73…` / `9447b962…`

### N-41 催化剂 `time_std`：假精度、哨兵值、取值持续扩张 〔B〕
- **现状**（10-12 复测）：`sort` 的字面精度常细于事件真实精度——`month` 类 "mid-November" → `2026-11-15`，`quarter` 类 "4Q26" → `2026-10-01`，`year_end` 类 "year-end" → `2026-12-31`。`"9999"` 是哨兵（与四位年份同形，只能按值判），可能不带 `type`，也可能配 `type:"relative"`。`relative*` 族的 `sort` 按报告日推（"yesterday" = 报告日 −1，"in coming quarters" = 报告日本身）；`as_of` 的 sort 就是报告日。datetime 偏移写法混用（`Z` / `+08:00` / `-04:00`）。`anchor`（10-05 起）常比 `sort` 诚实。
- **已见值清单**（唯一维护处；N-154③、N-177②⑤ 不再另列）：
  - `type` 44 种（按首见日期）：07-29 `date` `datetime` `month` `quarter` `quarter_range` `fiscal_quarter` `half-year` `half_year` `half_year_range` `year` `relative_year` `relative` `relative_period` `rolling_window` `event_relative` `relative_event` `range` `date_range` `deadline` `recurring` `period` `null`｜10-05 `fiscal_year` `fiscal_period` `quarter_end` `half` `month_range` `reporting_period` `relative_window` `relative_range` `approximate_date` `deadline_month` `earnings_event` `conditional`｜10-08 `year_range` `approximate` `calendar_year` `open_ended` `after`｜10-12 `date_window` `year_end` `by_date` `week` `as_of`
  - `sort` 形态：`YYYY-MM-DD`、`YYYY-MM`、`YYYY`、ISO datetime、`YYYY-QN`、`YYYY-HN` / `YYYYHN`、`YYYY-FQN`、`YYYY-FY`、`YYYY-FYyy-QN`、`A/B` 区间、尾部 `+`（开区间）、尾部语义后缀（如 `-upcoming-earnings-call`）、`CY` 前缀、哨兵 `9999`
- **怎么读**：归一与降级以 r3 规则表为准：先判 `9999`；`type` 粒度粗于 `sort` 时以 `type` 为准；`anchor` 含 `Q` / `H` / `FY` / `/` / ` to ` 时按 anchor。财报类 `quarter` / `fiscal_quarter` 的季是指标所属期，不是发布时间，判过期按「季末 + 45 天」。表外新值先按 `time` 原文判，判不了降到年级，并补进 r3 和本清单。
- 正面：`catalysts[].security` 可以 ≠ 查询标的，一次钻取能顺带拿到别家的事件日（查 NVDA 得 AMD 竞品事件、查 INTC 得 AAPL 财报日）；`security` 不保证是代码（N-67②）。
- 历史：07-29「type 共 22 种」「归一成功率 58/60」只对当时样本成立。
- **依据**：07-29 NVDA+INTC+GOOGL 60 条；10-05 `960fdf70…` / `372a173c…`；10-12 `a0eea254…` / `a7434981…` / `250df662…` / `321003c3…`

### N-63 `revision_summary.list_changes[]` 存在，未见停覆类动作 〔C〕
- **现状**（10-12 复测）：结构 `{action, list, security}`，`revision_summary` 在卡片顶层（N-183①）。已见 `action`：`initiate`（组合建仓名单）、`add`（加入观察名单；10-12 INTC 卡 `{add, "JPM APAC Conviction Call", 1888.HK}`）、`remove`（10-05，移出催化剂观察名单）。未见 drop / terminate 类停止覆盖动作。
- **怎么读**：写「样本内未出现停覆，机制上可能支持」，不写「做不了」，也不承诺能抓到。`remove` 不读成停覆。
- 历史：07-29 之前曾误记「MCP 侧无此字段」。
- **依据**：07-29 四标的；10-05 `c4d18240…`；10-12 `a7434981…`（N-154⑤ 已并入）

### N-67 汇编报告的 `by_name` 是同框噪音；识别改看 `report_title` + `report_type` 〔B〕
- **现状**（10-12 复测）：晨报、组合、tracker 类汇编报告的 `revision_summary.by_name[]` 列的是同一份报告里的其他公司，与查询标的无关：NVDA 钻取里 Nomura《Morning News & Views - Asia》带出 Info Edge、PB Fintech、TCS 等 9 个无关名字。07-29 不加闸时 NVDA 输出 83% 是无关名字。
- **怎么读**：识别汇编报告看 `report_title`（含 Morning News / Views / Portfolio / Quant / Weekly / Daily / Tracker）+ `report_type`（strategy / tracker），不再看 `subject_name`。过闸后再用 `by_name`；`mention_context.rationale` 不论过不过闸都保留。关键词是启发式，判别原则是「这份报告有没有统一研究主题」。10-12 `by_name` 新增 `change_pct` 键。
- **①** `old_target_price` 覆盖率低（07-29 25/96 = 26%，10-12 5/21）：只有 new 的是「当前目标价」，不是「改价」，分开表述。`by_name` 行不带币种，非美元标的按挂牌地判断。
- **②** `catalysts[].security` 不保证是代码：见过板块名 `"AI SEMICONDUCTOR SUPPLY CHAIN"`、逗号多值 `"373220.KS, 006400.KS"`、非上市 `"Moonshot AI (unlisted)"`。含空格且无 `.` 后缀的单列为板块 / 非上市；含 `,` 的拆开。
- **③** 正面：`mention_context.rationale` 是机制描述，可读成带方向的 A→B 因果边（如 NVIDIA 是 Nokia AI-RAN 平台的开发伙伴）；但必须读全句，存在自带否定（"…but Bernstein considers a joint project unlikely"）。10-12 起 `rationale` 与 `context_snippet` 逐字相同，读一个即可。过闸后的 `by_name` 能顺带拿到链上别家的目标价（10-12 SpaceX 300、GDS 49），那是单家读数，引用标出处。
- 历史：07-29 原用 `subject_name` 判别；10-12 Nomura 晨报的 `subject_name` 已变成 "Asian equities, AI infrastructure and regional macroeconomic trends"，不含关键词，判别失灵。
- **依据**：07-29 四标的 96 条 `by_name` 逐条判读；10-12 `a0eea254…` / `321003c3…`（原第 294 行「正面发现」已并入③）

### N-154 研报路径零碎（10-05） 〔C〕
- **①** 纯聚合榜每次必带 info 级 `ticker_unresolved`，正常，不是 N-78 那种失败（10-12 仍在）。
- **②** 数组写法下 2330.TW 不扩展出 `TW`（10-12 仍不扩展）；query 串写法仍会扩展（10-12 `2330.TW` → `["2330.TW","TW"]`，见 N-86），认块规矩保留。
- **③** `time_std` 新值与假精度 → 已并入 N-41 已见值清单。要点：`relative*` 的 `sort` 填的是报告日（假精度）；`fiscal_year` 的 sort 形如 `2027-10`；`sort` 新形态 `A/B` 与 `YYYY-FY`；新字段 `anchor`。
- **④** `mention_direction` 新值 `competitor` → 已并入 N-39②。
- **⑤** `list_changes` 出现 `action:"remove"`（移出催化剂观察名单，≠停覆）→ 已并入 N-63。
- **怎么读**：降级表以 r3 为准，方向值以 N-39② 为准。
- **依据**：10-05 `960fdf70…` / `372a173c…` / `c4d18240…` / `78e2ef6e…`；10-12 `f40a4669…` / `6c1e3f73…` / `225df57e…`

### N-177 研报零碎（10-08 第二轮复跑） 〔C〕
- **①** `verbosity="concise"` 不返回 `detail`，`by_name` 无标记截到 5 行，本标的那行可能被截掉（10-12 AAPL Bernstein 卡 `by_name` 5 行、`affected_names` 8；另见 N-183①）。
- **②** `time_std.type` 新值 `calendar_year` / `open_ended` / `after`；财报类 quarter 事件的季是指标所属期 → 已并入 N-41。
- **③** `rating_action` 是自由文本（"assume coverage"、"initiate"、"recent downgrade … prior rating not supplied"；10-12 又见 "reiterate Buy (Conviction List)"、"positive read-across"、"initiate Overweight from Not Rated"）；`rating_current` 有复合值（"Buy; Conviction List"），此时 `stance_normalized` 为 null。
- **④** `scenarios` 常只有 base 或为 null（10-12 仍只有 base 键）；`risks` 会返回过时的模板句。
- **⑤** relative 类 "yesterday" 的 sort 是报告日 −1（10-12 INTC 花旗 09-16 报告 → `2026-09-15`）→ 归 N-41。
- **⑥** `mention_direction` 出现 `negative` / `neutral` → 已并入 N-39②。
- **⑦** 流程备注出现不带 filename 字样的新形态 → 按 N-144① 分流。
- **⑧** 刚好 10 篇时首页即 `has_more:false`；单标的翻到尽头时 subject + mention 篇数等于榜面点名次数。
- **怎么读**：r4 必用 detail；财报类季级事件按「季末 + 45 天」判过期（r3）；`rating_action` 不硬编码枚举。
- **依据**：10-08 第二轮复跑（r0 / r2 / r3 / r4 / c3 记录）；10-12 `edd4b9b4…` / `9447b962…` / `a7434981…`

### N-181 研报零碎（10-09 第三轮复跑） 〔C〕
- **①** 标题写明上调目标价的报告会被归到提及层（花旗 10-06 "AMD to $800"；花旗 09-28 MU 1150→1300 也在提及卡），只看 subject 层会漏真实的目标价动作和最新目标价。10-12 仍在提及层，但卡上已有 `matched_asset_target_price:{currency:"USD", new:800}`，顶层 `revision_summary.by_name` 有 AMD 575→800。
- **②** `key_caveat` 有一种形态是抽取器指出报告没给某项实质内容（如没给催化剂；10-12 高盛 10-06 "This is a multi-company research digest; … not supplied"），既不是报告自承的口径边界，也不是书目缺失。缺什么现在主要写在卡片顶层 `coverage_flag.missing`。
- **怎么读**：①已于 10-09 拍板：目标价动作和最新目标价连提及层一起看，读 mention 卡的 `matched_asset_target_price` 与顶层 `revision_summary.by_name[]` 的 old→new；研报翻页取全并按日期止损（c3 / 01，N-188④）；同一机构取最新一篇。②注明「抽取器所见」，按 N-144 分流。
- **依据**：10-09 第三轮复跑（01 / c3 / r2 记录）；10-12 `321003c3…`

### N-183 研报零碎（10-09 第四轮复跑） 〔B/C〕
- **①** `revision_summary` 在卡片顶层，不在 `detail` 下；`concise` 下 `by_name` 截到 5 行，本标的那行会被截掉（高盛 10-02 MU 那篇 detail 实为 22 行；10-12 concise 仍只 5 行、没有 MU）。
- **②** 提及层翻页很贵：10-09 全翻 30d，NVDA 14 页、META 8 页、AMD / 2330.TW 各 7 页（每页 1 额度）。止损规则已定，见 N-188④。
- **③** 报告正文给了本标的目标价，`by_name` 却没有这一行（伯恩斯坦 10-05 给 NVDA $400；10-12 同卡 `matched_asset_target_price` 为 $400 而 `by_name` 0 行）。
- **④** 评级字段返回数字码（花旗 `"1"`）——10-12 未复现（花旗 10-06 卡为 "Buy"），规则保留。
- **⑤** 卡片顶层有未登记字段 `coverage_flag` / `routing_action` / `routing_circle`；`audit_counts` / `registry_candidate_counts` 只在 `verbosity="detail"` 的页里出现，concise 不带。历史：10-09 第五轮记「每页都带，含首页」，10-12 订正为只限 detail 页。
- **⑥** 单标的 30d 钻取传 `limit=30` 时仍只返回 10 张，并带 `research_report_limit_capped`——这个警告在 `research_reports[0].warnings`，不在 `meta.warnings`，只扫 meta 会漏。
- **怎么读**：old→new 一律用 detail 读顶层 `revision_summary.by_name[]`，本标的行缺失时回落到 `matched_asset_target_price`；数字评级码不硬译；扫警告连 `research_reports[*].warnings` 一起扫。
- **依据**：10-09 第四、五轮复跑（01 / c3 记录）；10-12 `61bf8349…` / `250df662…` / `321003c3…` / `5ff7885f…`

### N-64 → 见 N-19
「subject 数是时点状态（07-23 GOOGL subject 0 → 07-29 为 6）」「`report_returned_count` 不保证 10」「subject=0 时 mention 卡照样可用」三点都已并入 N-19；原第 327 行「榜首标的可能一篇专题都没有」同并入 N-19。

**补充**（无编号的旧内容）
- **研报无按单份取报告的入参**〔C〕（原红线 12 / 第 33、75 行）：query 只放报告标题、不带研报意图词时，不进研报路径，掉进 CORE 基本面默认集合（带 info `default_fanout_fallback`），照扣 1 额度；没有按 `event_id` 或标题取单份的入参（10-12 `tools/list` 确认）。取某份报告 = query 保持 "research reports" / "研报"、代码放 `keywords`、`verbosity="detail"`，在客户端从卡片里挑。可提 dev 增 `event_id` 入参（P2）。依据：07-15 首记；10-12 `dc7c7498…`。
- **crypto 没有研报**〔B〕（原第 324 行）：`asset_type="crypto"` 查研报返回 `results:{}`、`total:0`，照扣 1 额度；10-12 起带 info 级 `no_match`（08-07 / 08-12 时没有 warning）。研报只在 tradfi 侧查。08-12 产品侧定不修。依据：08-07 `686dab2f…`；10-12 `23c3ebc5…`。
- **`excluded_counts` 的读法**〔C〕（原第 325、328 行）：key 是复合路径串，个数随窗口变（10-12：7d 3 个、累计 5 个；08-12 时为 2 / 4），按整个对象求和，不硬编码 key（08-12 产品侧定不修）。累计榜里 `report_ignored.out_of_scope` = 70、`ignored_over_page` = 12，从 07-20 到 10-12 逐位不变，同期 `eligible_event_count` 299 → 2230、最新报告到 10-10：这两个桶不再计数，不是研报库停更，与归档 N-61 的结论一致；窗口榜里这两个桶已不出现。不要把 70 / 12 当成「本期排除量」；判断停更看 N-164① 的样本闸。历史：08-12 原把它写成「N-61 疑似停更的跨期证据」，10-12 证伪。依据：10-12 `80362788…` / `66e2f883…`。
- **研报通道 08-07 立单批说明**（原第 303–309 行）：立单时编号 N-70~N-77，08-12 因撞号改为 N-78~N-85，引用一律用新号。P0 / P1（N-78~N-84）08-12 全部修复，见归档；P2 三条（N-85、上面的 crypto 与 `excluded_counts` 两条）08-12 产品侧定不修——行为仍在、规避照守，复核不再作为待修项上报。同批复测发现的 ticker 扩展另立 N-86。
- **07-29 段首结论已过时**（原第 266 行）：原写「MCP 研报侧只有一个被连带污染的全量榜 + 每票 10 篇切片，做不了发现型信号，只能做单标的深度」。现在榜单按窗口计（N-37，08-03 修）、可翻页取全（N-81，08-12 修）、可按 `date_from`/`date_to` 精确取窗（N-153）。剩下的限制是成本（提及层翻页每页 1 额度，N-183②）、榜面不给 subject 计数（N-19）和方向值视角问题（N-39③）；需要全覆盖的库内信号要翻页取全后才成立（N-38）。
- 另见 N-188④⑤：提及层跨页严格按日期倒序，可据此设翻页止损；`detail` 单页可达 10.6 万字符。

## metrics · crypto 与衍生品

### N-170 crypto 快照：24h 涨跌只在 detail，`as_of` 恒空，成交量是币本位 〔C〕
- **现状**（10-12 复测）：standard 快照没有涨跌字段，`verbosity="detail"` 才有 `change_percent_24h`；`as_of` 两次都是 null；`volume_24h` 是币本位（BTC 9,243）。
- **怎么读**：快照用 detail；时点按调用时间记；要成交额自己乘价格。
- **依据**：10-08 `55a7471d…` / `bf3327e3…`；10-12 `ec975966…` / `5a93ccfb…`

### N-102 合约地址放进 `keywords` 不会被截断，但长尾币识别不了 〔A〕
- **现状**（10-12 复测）：`keywords` 单项上限已是 128 runes（schema），42 位 EVM 地址放得进去，不再有截断 warning；但长尾币的 CA 不被识别：`metrics(keywords=[CA], asset_type="crypto")` 返回 `keywords:null`、`no_match`、0 条。schema 称已知代币的完整合约地址可作别名（例：UNI），未实测。
- **怎么读**：CA 仍走 news 的 query 串 + `search_depth:"quick"`（N-101）；对外不承诺「支持合约地址查询」。
- **历史**：09-07 原记「上限 30 runes、CA 必被截断，生产端数组不可用，CA 只能走 query」，10-12 前两点都已不成立。
- **依据**：09-07 schema 直读；10-12 `cf3f8ad7…`

### N-178 crypto 与 twitter 零碎（10-08 第二轮复跑） 〔B〕
- **①** crypto 不带 `interval` 查日 K 仍返回小时 K（10-12 BTC `query="price and daily candles"` 回 10 根小时 K，与工具描述「omit for daily」不符）。技术指标按指标名写 query 时附带的是小时价，停在当天 00:00 UTC，拿不到当日高低价（10-12 HYPE 复现，见 N-169）。振幅用 `interval="1hour", limit=24` 另取。
- **②** `tweets_by_ids` 请求 7 个只回 6 个，无警告；同一条推文在不同调用里显示不同作者。（10-12 7 个全回、作者一致，属偶发）twitter 见 N-182②。
- **③** 转推的 `type` 是 `"tweet"`，外层 text 是 X 自带的约 140 字截断，全文在 `retweeted_tweet.text`；外层 `content_truncated:true` 常由被引原文触发。10-12 新增：`tweets_by_ids` 对转推返回 `isRetweet:false`，也没有 `retweeted_tweet`，拿不到全文，要用 `user_tweets` 取。twitter 见 N-189。
- **依据**：10-08 Crypto Watchlist / Feed Manager 复跑记录；10-12 `e807873a…` / `5a93ccfb…` / `dc52e047…` / `fdfd6170…`

**补充**
- **衍生品读法**（原 N-104 中仍有效的部分；N-104 已归档）：生产端四叶齐全（永续合约池、当前费率板、OI 日线、Binance Futures K 线）。费率板按 `lastFundingRate` 绝对值降序（工具描述已写），前列多是常年负费率的小币（10-12 RSR −1.94%、CKB、RLC、MINA），没有分位字段，不能直接当「极端费率榜」，要按各合约自身的历史分位重排。OI 是日频，默认 3 个点，最多 30 个（`time_range="30d"`）。数值是原始小数字符串，服务端不年化费率、不算 OI 变动。依据：10-12 `fd938d0d…` / `43bea894…`。
- **crypto K 线与指标的其他零碎**：指标集与附带价格见 N-169；日线数据头封顶 31 见 N-185④；当前小时 K 偶发缺失见 N-185⑤；流通量 / 市值 `no_match` 见 N-185⑥；HYPE 价格数据换成小时格式见 N-182④。

## metrics · 涨跌榜（Q4 已决定不投入修复）

> Q4 已决定把涨跌榜（`biggest gainers` / `biggest losers` / `most active stocks`）从工具描述里摘除，不再投入修复。以下条目只供仍在用涨跌榜的 Skill（如 03 / 06 / trend-scout）参考。

### N-111 🔴 涨幅榜有反向拆股造成的假涨幅 〔B/D〕
- **现状**（10-12 复测）：涨幅榜 NXGL 显示 +2570.67%（$4.006），实价 $0.2003，正好 ×20；DFLI 显示 +669.98%（$3.7752），实价 $0.4719，正好 ×8。两只都是反向拆股后现价调整了、前收没调整（Longbridge 对照）。同榜 WFF +499.5% 是真涨。跌幅榜首 SEQUX −74.8% 是共同基金（疑似除息造成的假跌），其次的 ALISU 是 SPAC 单位。默认已剔除 <$1，剩下的仍以小盘为主（N-160）。
- **怎么读**：|涨跌| >200% 的行，先补快照或外部行情核对现价与前收的量级；基金类涨跌 >50% 先当数据异常。
- **历史**：10-01 原记「数据已恢复正常，03 / 06 恢复使用，撤销 N-9 的弃用」，10-12 证伪。
- **依据**：10-01 `d269ae0e…` / `cc7df926…`；10-12 `7fb491c6…`（涨幅榜）/ `46c264e8…`（跌幅榜）

### N-9 榜单行没有市值，要补快照后再过滤 〔B〕
- **现状**（10-12 复测）：三张榜的行只有 6 个字段：`symbol` / `name` / `price` / `change` / `changesPercentage` / `provenance`，没有 `marketCap`、`exchange`、日期（原 N-110 的榜单行部分）。只覆盖美股。榜内混有杠杆产品（10-12 有 MRNX「Daily Target 2X Long」）。
- **怎么读**：候选代码二次批量快照补 `marketCap` / `exchange`，取市值 ≥$1B；剔杠杆 ETF 用正则 `ETF|ETN|UltraPro|Ultra|Leveraged|\dX|Bull|Bear|Daily`，只判 "ETF" 会漏 TQQQ / SQQQ；不用「<$5 仙股闸」，会误杀 GRAB（10-12 $3.19，市值百亿美元级），价格闸只在拿不到市值时兜底。
- **待复测**（GAP R4）：`most active` 是否真按成交量排。09-16 的单个样本里前两名与涨幅榜相同（`77e4470c…`），之后没有复测。
- **历史**：07 月 trend-scout 记为「弃用涨跌榜，改用 most active」；10-01 N-111 撤销弃用；Q4 决定摘除。本条已并入红线 9 的事实部分。
- **依据**：07-22 回归；10-12 `cdefd4e1…` / `46c264e8…`

### N-160 涨跌榜默认剔除 $1 以下股票，但不按证券类型过滤 〔C·已文档化〕
- **现状**（10-12 复测）：`include_penny_stocks` 默认 false，剔除 <$1（涨幅榜 30 行最低 $1.01），工具描述已写明。不按证券类型过滤：每张榜约 20% 不是普通股（杠杆 ETF、SPAC 或 SPAC 单位、共同基金）；行内没有日期，同一代码两次调用一次 +676%、一次 −34%，分不清是哪个交易日（GAP U20）。快照 `marketCap` 偶有垃圾值（10-08 BBCI=8）；FBTC 的 `exchange` 是 `"CBOE"`（10-12 仍是）。
- **怎么读**：补快照后按 profile 的 `isEtf` / `isFund` 剔除；名称含 Unit / Acquisition 的 SPAC 剔除；市值 <100 万美元按异常值处理；交易所白名单以外的另行判断；记录榜单的调用时刻。
- **依据**：10-08 `b1c901ce…` / `b9f352a0…`；10-12 `5ff5ea4b…` / `bef3df49…`；U20 10-10 `650bbebb…`、10-12 `ef50cbb5…`

### N-138 涨跌榜不补位，默认只剩 30~40 行 〔B〕
- **现状**（10-12 复测）：榜单取上游前 50 名，默认剔除 <$1 后不补位：`biggest losers` 传 `limit=50` 返回 37 行，无 `has_more`、无 warning；加 `include_penny_stocks=true` 能拿满 50 行（13 行 <$1），可见的跌幅下限不变（−12.8%，GRML）。跌得不够狠的大盘股三张榜都看不到（10-03 STX −10.2%、市值 1,904 亿，不在榜内）。
- **怎么读**：榜单只代表「榜内可见」，输出里写明覆盖边界；需要满 50 行时传 `include_penny_stocks=true` 再自己过滤。
- **历史**：10-03 原记为「行数上限约 30」，10-12 证伪。
- **依据**：10-03 `022675fd…` / `8c2f769b…`；10-12 `46c264e8…` / `afce531f…`

## signal · KOL 喊单（kol_call）与多类合并调用

### N-88 🔴 按标的查喊单会混进别的票，表层计数不能当个股共识 〔A/B〕
- **现状**（10-12 复测）：`keywords` 不按喊单标的过滤，而是按正文命中（成因见 N-119）。`keywords=["NVDA"]` 的明细只回 1 行，`symbol` 是 NBIS（原帖正文提到 NVDA）；`query="NVDA consensus"` 的 `total_posts` 为 1，`top_calls` 里只有 NBIS，NVDA 自己不在。反过来，目标票真被点名的帖也可能整帖归到别的 `symbol` 上（07-29：8 行里没有一行 `symbol=="NVDA"`，但原帖 BUY 列表第一个就是 `$NVDA`）。
- **按 KOL 查也失效**（GAP U6 并入）：`keywords` 传 KOL 句柄会被清空成 `keywords:null`，退化成全量浏览，DaanCrypto 与 fundmyfund 两个句柄返回完全相同；`status:"ok"`、没有 warning，与工具描述「omissions are reported in meta.warnings」不符。
- **怎么读**：① 单标的结果先筛 `symbol==<T>`，再回读 `content` 核对 `$<T>` 和方向，两边都对上才算；② 不读表层 `bull_bear_ratio` / `bullish_count`，单标的多空取 `top_calls` 里该标的那一行；③ 去重后独立帖不到 10 条，不叫「共识」（美股侧普遍不够，见 N-100）；④ 要看某个 KOL 的喊单：不带关键词拉全量（`limit=50`），客户端按 `username` 筛，对外不承诺「按 KOL 查」。不带标的的全市场聚合不受影响。
- **依据**：07-29 `908aadc9…`（原 N-40）；08-13 `35507a87…`；10-12 `65799d74…` / `6d1320b5…`；U6 句柄 10-12 `840e4f24…` / `1ff50e53…`。已并入 N-40。

### N-119 kol_call 的 `keywords` 按子串匹配正文，不按标的 〔A〕
- **现状**（10-12 复测）：`keywords=["MU"]` 返回 3 行：HXSCY 和 MU（同一条推文拆成两行），以及 META（原帖没有 MU 这只票）。成因（GAP U7，crypto 和 tradfi 两侧都一样）：关键词按子串匹配正文——SOL 命中 sold / Solutions / consolidating，MU 命中 community / much / accumulation，AI 命中 failing / waiting / remains。consensus 同样被污染：10-10 MU 共识里约 80% 是别的票。
- **怎么读**：短代码（≤3 个字母，或本身是常用词）查完必须同时满足 `symbol==<T>` 且正文含 `$<T>`；单标的多空数取 `top_calls` 里该标的那一行，不取顶层 `bullish_count`；一帖多行先按 `source_url` 去重（N-5）。
- **依据**：10-01 `15e5588d…`；10-05 `c5743aef…`（原 N-136）；10-10 `4b97cfe5…`（U7）；10-12 `d715cc2c…` / `1f4389da…`。已并入 N-136。

### N-100 🔴 美股喊单池一边倒看多，「KOL 共识」在美股侧不成立 〔D〕
- **现状**（10-12 复测）：`query="共识"` 返回看多 42 / 看空 1 / 中性 0（`total_posts` 43）。`query="喊单"` 的 20 行里看空 0 条，方向值 `buy` 13 条、`bullish` 7 条混用（归一见 N-155）。这 20 行只来自 8 个 `source_url`，其中一帖拆成 13 行，占 65%（N-5）。`target_price` 只有 2/20 非空。能用的部分：行内有 `tier`（A+/A/B）、`signal_level`、`sector`、`event_context`，可以分层、归类主题。
- **怎么读**：① 多空比和「KOL 共识看多 X」不作对外信号，也不拿来演示（恒看多，没有信息量）；② 只用来发现主题（看 `top_calls` 的主线），同时写明去重后的帖数和人数；③ 引用具体观点前先按 `tier` / `signal_level` 筛；④ query 用 `consensus` 或纯中文意图词，不要写「KOL」——`query="KOL 喊单"` 会把 KOL 解析成 crypto 代码，返回 `degraded`、0 条（N-69 的实例）。
- 历史：08-17 首记为 45:1，榜首 MU 只有 7 次提及。
- **依据**：08-17 `43469fb9…`；10-12 `85bb3a75…` / `2c2b3422…` / `35f03b29…`

### N-117 kol_call 上游只有最近 24 小时 〔D/B〕
- **现状**（10-12 复测）：tradfi 传 `time_range="7d"` 或 `"3d"`，返回 `status:"partial"` 加 warning `KOL upstream covers only the latest 24 hours`，各项计数与传 `24h` 完全相同（`total_posts` 43）。超过 24h 的窗口一律被降到 24h，N-13 记的「consensus 对 time_range 不敏感」就是这个原因。crypto 侧传 `12h` 时没有这条 warning；10-01 记的「全市场原帖传 24h 也 partial」10-12 没有复测。
- **窗口内没有帖时，提示语会误导**（GAP U8 并入）：返回 `no_match` 加 "unknown ticker / no upstream coverage"（ETH、MSTR、HNGE；MSTR 还是工具描述里的示例）。但同一窗口不带关键词浏览时，其实能看到 `$HNGE` 的原帖；池内账号 24h 内发的 `$ETH` 帖也可能没被抽进 kol_call。
- **怎么读**：喊单一律写「近 24 小时」，不写「近 3 天」「本周 N 帖」；要周度数字只能客户端逐日累积。看到 "unknown ticker" 先当作「近 24h 没有数据或没抽到」，不写「不支持该标的」；需要时用不带关键词的浏览结果交叉核对。
- **依据**：09-07 `cc4d5dcf…`（原 N-13）；10-10 `a687b33c…`（U8）；10-12 `c8a6a3f4…` / `d569d8f5…` / `61028f05…`。已并入 N-13。

### N-118 多类合并调用带 `time_range` 时，窗口内没数据的类整类消失 〔B〕
- **①** 不传 categories、只写 `query="consensus"`，只返 kol_call 一类（10-01；10-12 未复测）。现在不传 categories 多数情况直接返空，见 N-113。
- **②** `categories=["kol_call","insider_trading"]` + MU + `24h`：只回 kol_call 3 行，insider_trading 整类不见，`status:"ok"`、没有 warning；同样参数不带窗口，insider 20 行 + kol 3 行，计 1 额度（10-12 仍成立）。不带窗口时，没有匹配的类同样整类缺席（10-12 HUBG 三类合查只回 insider_trading，见 N-166①）。
- **③** 四类 + `7d`：institutional 被拒（`parameter_unsupported`，13F 没有滚动窗口语义）（10-01；10-12 未复测）。工具描述已写 "Sources without truthful rolling-window semantics fail closed"。
- **怎么读**：多类合并调用不带 `time_range`，内部人在客户端按 `transactionDate` 过滤；要 24h 口径的喊单聚合就单独调；按返回里实际有的 key 判断哪些类到了，缺一类不等于这类没有数据。
- **依据**：10-01 `50af1eb0…` vs `8502bcc6…`；10-12 `786bd7c7…` vs `d715cc2c…`、`fbafa8d8…`

### N-113 signal 不传 `categories`、只给标的时返回空，照扣额度 〔A〕
- **现状**（10-12 复测）：`signal(query="NVDA")` 和 `signal(keywords=["NVDA"], asset_type="tradfi")` 都返回 `results:{}` + `no_match`、`status:"ok"`，各扣 1 额度。这与工具描述的「Pick categories to scope (omit for all)」不符。显式传 `categories` 正常，多类一次调用仍只计 1 额度。旧的「不带 categories 一次拿全四类」（N-4）是能力被撤销，不是修好，已归档。
- 分点订正：原记「`sort_by="amount"` 实际按申报时间排」，已被 N-137② 订正（10-12 再次确认按金额降序）；「带 `time_range` 会 `partial`」10-12 未复测；「英文意图词的 query 有返回」仍成立，但全市场内部人只要带 query 文字就会丢掉议员行（N-137④）。
- **怎么读**：signal 一律显式传 `categories`；空结果也扣额度，调用前先核参数。
- **依据**：10-01 `21c31e47…` / `b2d4a68d…`；10-12 `1b0460b4…` / `a25456fb…`

### N-151 `limit` 按类别分别生效、默认 10；多票帖会把目标票挤出去 〔C·已文档化〕
- **现状**（10-12 复测）：tradfi 24h 传 `limit=50` 回 43 行，只来自 18 个 `source_url`、8 个账号，其中一帖拆成 13 行；concise 体积 2.5～3.7 万字符。样本日 `limit=50` 约等于 24h 全池（行数 = `total_posts`）。`limit=20` 不等于「最新 20 帖」，10-05 就因此漏掉了唯一的看空帖。多票帖拆出的行会把目标票挤出去（10-05 SOFI 被一条 11 只票的帖挤到第 11 行）。`consensus` 的 `total_posts` 按拆行计，名次并列时两次调用顺序不同。
- 工具描述已写 limit 的分类语义（"KOL raw posts: per asset family … Insider trades: merged category list … Not a total-response limit"），没写拆行会挤占名额。
- **怎么读**：单标的钻取用 `limit=50`；对外的帖数先按 `source_url` 去重，再按 `username` 计人数；名次并列时按账号数排。
- **依据**：10-05 `469ba6d2…` / `a7a958b4…`；10-12 `59649d05…`

### N-155 喊单的 `direction` / `target_price` 不能直接引用 〔A/D〕
- **①** `target_price` 会把假设估值当成目标价（「若给同倍数会到 $3,210」→ 3210），还出现过 0 和负数（反讽帖，10-08）。10-12 样本里只有 640、75 两个合理值，误标与否取决于具体帖子。
- **②** `direction` 会误读语气（「别追 IPO，但公司更强」被标成 bearish）。取值也没有归一：tradfi 同时出现 `bullish` / `bearish` / `neutral` 和 `buy`（10-12 24h 43 行：bullish 28、buy 14、bearish 1），10-09 还出现过 `hold`（N-180④）。
- **③** crypto 行没有 `direction` 字段（浏览 8/8 都没有），consensus 把 crypto 帖基本记成中性：BTC 6 帖记成 1 多 5 中性，人工读原文约 3 多 2 空 1 中性；对照集里系统对 crypto 方向的判断 0/8 正确（GAP U9，10-10）。
- **④** tradfi `trader_position` 的热门榜曾混进加密币（10-05 SUI、LIT 被标成 `stock_perp`）。10-10 和 10-12 两次全榜都没有再出现，但都是单次样本，判断不了是修了还是没碰上（10-12 复核，见 N-96）。
- **怎么读**：`direction` 先归一（`buy` 算看多，`hold` 算中性）再计数；crypto 喊单方向只读原文判断，不引用 `bullish_count` / `neutral_count`；引用 `target_price` / `direction` 前对照原文；trader_position 入场价量级不像股价的，按加密处理。
- **依据**：10-05 `a7a958b4…` / `212ea161…`；10-10 `0214eccf…`（U9）；10-12 `59649d05…` / `091a49af…`

### N-5 一帖多票拆成多行 〔D〕
- **现状**（10-12 复测）：一条推文点名几只票就拆成几行，除 `symbol` / `sector`（有时 `direction`，如同一推文「MU 看多 + AMD 看空」）外，其余字段逐字相同。zzy 一帖拆 7 行（AVGO / CRWV / GRAB / HIMS / IREN / LMND / NFLX）；`喊单` 20 行只来自 8 帖，其中一帖 13 行。拆行会让「被提及次数」和 `total_posts` 虚高（N-100 / N-151），也可能只拆出一部分票（N-180③）。
- **怎么读**：计数先按 `source_url` 去重，再按 `username` 计人数；`symbol` 只表示这一行归给了谁，不代表原帖只讲了这只票。
- **依据**：07-22 首记；10-12 `6e13fae2…` / `2c2b3422…`

### N-20 全市场原帖的体积跟着 `limit` 走 〔C〕
- **现状**（10-12 复测）：`signal(categories=["kol_call"], query="详细仓位")` 默认 10 行、约 9 千字符；调到 `limit=50` 才会膨胀到 2.5～3.7 万字符（concise，见 N-151）。
- **怎么读**：大窗口先用脚本聚合（按 `source_url` 去重 → 按 symbol 统计多空 → 只留摘要）再交给模型读；调用必须带 `categories`（N-113）。
- 历史：07-23 记为不带 categories 时返回 13.7 万字符 / 139 行，10-12 已不成立。
- **依据**：10-12 `6e13fae2…`

### N-166 signal 的截断与新取值（10-08 零碎） 〔B〕
- **①** 多类合并时，没有匹配的类整类缺席，`status:"ok"`（10-12 HUBG 三类合查只回 insider_trading）→ 并入 N-118。
- **②** kol consensus 不带 `time_range` 时 `total_posts` 卡在 50，带 `24h` 是 57（10-08 工作日；10-12 周末池只有 43，无法复测）。帖数对外写「至少 N」。
- **③** 工作日 24h 原帖池可以超过 50，截断丢的是中间时段的行（10-12 无法复测）。
- **④** `direction` 出现 `"buy"`，`target_price` 出现 0 和负数 → 见 N-155。
- **⑤** 单票内部人 `limit=50` 只给最近约 50 行。原记「议员行排在最后」，10-12 改成按交易日与 Form 4 行穿插（NVDA+ARGX：议员行在第 1、21、38–42、46、47、49 行）；议员 `type` 有 `"Sale (Full)"` / `"Sale (Partial)"`，按前缀判断。
- **⑥** 「联合申报把同一笔记两次」10-12 未复现（NORA JOHNSON 同一份申报的两行股数不同，是两笔交易）。
- **⑦** 13F `limit=50` 返回 50 家（订正 N-152 原记的「只返前 10」）；季度切换各标的不同步 → 见 N-152。
- **怎么读**：单票钻取用 `limit=50`；判断有没有截断，只看公司内部人行。
- **依据**：10-08 `035e1832…` / `a4cf81b3…`；10-12 `fbafa8d8…` / `c75bf7dc…` / `929533d0…`

### N-40 → 见 N-88
按 ticker 查喊单时，返回行的 `symbol` 可能都不是目标票（明细侧）。这和 N-88（聚合侧）是同一种 mention 错配，已合并；07-29 的原例和 10-12 复测都在 N-88。

### N-136 → 见 N-119
10-05 `keywords=["MU"]` 返回 20 行，只有 5 行是 MU，有的原帖根本没提 MU。和 N-119 是同一件事，已合并（`c5743aef…` 留在 N-119 的依据里）。

### N-13 → 见 N-117
「consensus 对 time_range 不敏感」的成因是上游只有 24h。原条标了「✅结案」却留在正文，现象到 10-12 仍在（`61028f05…`，3d 仍 partial），内容已并入 N-117。

## signal · 内部人、议员与 13F

### N-187 🔴 内部人申报行会被合并、又会恢复，来回变；持股差只当提示 〔B/D〕
- **现状**（10-12 复测）：MU、SNDK 的申报已恢复逐行，与 SEC 原件一致。MU CEO 8/21（-000015）27 行，卖出合计 40,000 股；7/24 的两份 Form 4（-000013 / -000014）都在；SNDK CEO 9/17 卖出 15 行合计 33,841 股，另有 A-Award 3,296 股一行。N-180②（MU CEO 46 行消失）和 N-184①（NBIS 9/14、ONDS 9/24 的行消失）里缺的行也都回来了。但这类数据 10-08 到 10-09 两天内变了三次，10-12 又恢复，共变 4 次，会来回变，不能当作已修。
- **被合并时的机制**（10-09 第二批工单复测，对照 SEC 原件）：去重键是「同一申报人 + 同一交易日」，不分交易类型、不分是哪份申报、不分普通股表还是衍生品表；保留哪一行不固定（MU CEO 6/26 那份留的是第一行）；跨多日的申报每个交易日各留一行；`securitiesOwned` 只是单个账户的持股（Olivan 显示 1,175 股，5 个账户合计约 8.7 万股）。合并状态下，卖出、行权、扣税混在一份申报里时，卖出行会整份消失（MRVL CEO 7/15）；同一天的第二份申报会被丢（SNDK CTO 9/3）。
- **怎么读**：① 内部人逐只单独查，`limit=50`（多个 keywords 合查共用 limit，MU+SNDK 查 50 行只分到 4 行 MU，见 N-176②）；② 同一个 (`reportingName`, `transactionDate`) 只有 1 行，就当作可能被合并了；③ 精确股数只认行内 `url` 指向的 SEC 原件；④ 前后两份申报的持股差只当提示，而且两行必须是同一账户（`directOrIndirect` 相同），不能写成「卖出 N 股」，对不上时写「申报后持股比上一份少约 N 股（申报行可能不全）」；⑤ 结论注明查询时间。观察到 10-19，稳定了再考虑归档。
- 历史：10-09 原记「保留每份申报的最后一行、`securitiesOwned` = 整份申报后的持股、可以用持股差发现截短」，同日第二批复测对照 SEC 原件证伪（GAP C2）。
- **依据**：10-09 第二批 2-1 复测 `45f1da01…` / `fa70367e…`、探针 P31–P33 `4286e35d…`；10-12 `c9f2b01a…` / `e9c6a339…` / `249cd1da…`。主条，合并了 N-180② / N-184①。

### N-137 全市场内部人扫描：覆盖、排序与议员行 〔D/A〕
- **①** 只覆盖最近一个申报日：10-12 `sort_by="amount"`、`limit=50` 返回的公司行全是 10-09 申报（19 行、9 家、6 笔买入）。同一公司扎堆比以前轻，最多 4 行（BPRE）；10-05 曾经一家占 25 条，06-12 SPCX 的 Form 3 占 50 条中的 13 条。
- **②** `sort_by="amount"` 按金额降序（订正 N-113 原记的「按申报时间排」），但会被错值顶上来：IHT 那行把总金额（约 5 万美元）填进了 `price`，按 price × 股数算成 21.7 亿美元，排在第一。
- **③** 议员行与公司行按金额混排：`limit=50` 里议员 31 行（参议院 24、众议院 7），`limit=20` 里 8 行；大半 `symbol:""`（对冲基金 LLC 之类的非上市资产，只有 `assetDescription` 看得出是什么；limit 20 那 8 行全是空 symbol）。议员行 `provenance` 也是 `"fmp"`，议院看 `_chamber`；众议院议员编号放在 `senateID` 字段里，布尔值是字符串（GAP U34）；交易到披露滞后 17～40 天，金额是区间。
- **④** query 里写任何文字，议员行都会整类消失：同样 `sort_by="amount"`，加上 `query="congressional trades"`，50 行全是公司申报（还多出 Form 3、A-Award 行），议员 0 行；中文「国会议员 股票交易」、英文「insider trading」也只回公司行。原记「意图词不起作用」，10-12 实测是更糟：起反作用。
- **⑤** 带 `time_range` 返回 `partial`，内容不变（10-05；10-12 未复测）。
- **怎么读**：全市场扫描不写 query，结论只说「最近一个申报日内」；先按 `_chamber` 拆出议员行，`symbol` 为空的剔除（不能按 ticker 去重）；公司行只认 `formType` 为 4 / 4/A 的 S-Sale（卖出）和 P-Purchase（买入），F-InKind / M-Exempt 是扣税和行权，A-Award 是授予；引用大额交易前，用 `securitiesTransacted × price` 对照市值核一遍。
- **依据**：10-05 `9efe36d0…`；10-12 `575e0e84…` / `92be6777…`；10-12 补测 `45d909eb…`（不带 query、limit 20，议员 8 行）/ `16834e49…`（带 query、limit 50，议员 0 行）。已并入旧表格第 73 行（insider 全量扫描聚簇）。

### N-95 🔴 议员与内部人怎么查：按人只有议员姓可用，全市场入口一带 query 就丢议员行 〔A/C〕
- **个股入口**：`keywords=[<代码>]` + `categories=["insider_trading"]`，议员行与公司行混排（08-17 NVDA 15 行里议员 7 行；10-12 NVDA+ARGX 50 行里议员 10 行，按交易日穿插）。
- **议员姓入口**（GAP C6）：`keywords=["Pelosi"]` 返回 12/12 全是 Nancy Pelosi（工具描述里也有这个例子）；同姓多人时静默只选一个（"Johnson" → Julie Johnson TX32），不给候选。
- **全市场入口**：照工具描述的示例「金额最大的几笔国会交易 → `categories=["insider_trading"], sort_by="amount"`」原样调用，拿到的不是国会交易，而是公司申报和议员行按金额混排（limit 20 里议员 8 行，symbol 全空）；只要把意图写进 query（`congressional trades`、「国会议员 股票交易」），议员行就是 0 条（N-137④）。外部 Agent 最容易照抄的就是这个示例。
- **按高管姓名查会失效**（GAP U6）：`keywords=["Tim Cook"]` / `["Jensen Huang"]` 被清空成 `keywords:null`，返回全市场最新的 Form 4；只传单姓 "Huang" 返回 `no_match`；全部 `status:"ok"`、没有 warning。工具描述说 insider_trading 的 keywords 可以是人名，实际只有议员姓能用。
- **怎么读**：查公司内部人一律按代码查，再按 `reportingName` 筛；查某位议员用姓，返回后核对全名和选区；「最近哪些议员在买卖」不写 query、`limit=50` 拉回后按 `_chamber` 过滤，并说明只覆盖最近一批披露；对外写「披露于 X 日」，金额写区间。改示例和描述归 C，「带 query 丢议员行」「人名被静默清空」归 A。
- 历史：08-17 原记「只有个股入口，没有全市场入口」，当时全市场两种问法都被 Magnetar × CRWV 单一申报方占满；10-12 扎堆换成 AIOK、WRAP 各 4 行（`334e6b27…`），并发现了议员姓入口。
- **依据**：08-17 `3c31a6da…`；10-10 `00a9866a…` / `e093b493…`；10-12 `ad1e8e98…`（Tim Cook）/ `d07a88a7…`（Johnson）/ `3659ce51…`（示例 + query，议员 0 行）/ `45d909eb…`（示例原样，混排）

### N-152 13F：季末后切到新季度、数据不全，按代码查的标签有误导 〔D/C〕
- **①** 季末后头几周切到新季度：10-12 VST `report_period:"2026-09-30"`，上游 56 家、返回 50 家，其中 3 行 `shares` 为 0；HUBG 9 家（10-05 时是 `[]` 而 status ok）；query 里写 06-30 也拉不回上一季；各标的切换时间不同步（N-166⑦）。
- **②** 同一个 CIK 出现两行（10-05 Susquehanna；10-12 VST 的 CIK 0002069222）。
- **③** 原记「只返前 10（`is_exhaustive:false`）」已被 N-166⑦ 订正：`limit=50` 返回 50 家。
- **④** 按代码查的字段和标签（GAP U15）：`security_name` 全空；变动百分比恒为 0（N-7 / N-134⑦）；标成 `top_holders` 的其实是新季度最早交申报的小机构（AAPL「第一大」持有人 MN Services 只有 5.9 亿美元）；没有全市场聚合（机构数、机构持股比例）。按机构查（如伯克希尔）可用：`manager_changes` 带 `previous_shares` / `current_shares`，与媒体报道一致。
- **⑤** 按机构名查会解析错（GAP U6）：「Vanguard」被当成证券代码，解析成台股 5347.TWO（holders 为空）；「State Street」返回的是 STT 这只股票的持有人，不是这家机构的 13F；候选按字母序排，同名候选没有区分信息；`status:"ok"`、没有 warning。
- **怎么读**：社群类 Skill 不用 13F。要用时：`report_period` 过了 45 天再引用 `top_holders`；同一 CIK 先合并；增减幅度用按机构查的 previous / current 自己算；机构名写法定全称（"Vanguard Group"），从 `manager_candidates` 里人工核 CIK；机构数和持股比例走 WebSearch，并注明各来源数字不一致。
- **依据**：10-05 `7923d7d1…`；10-09 `0c7e44ba…`（探针 F01）；10-12 `929533d0…` / `d47afb87…` / `e9b4c92e…`

### N-7 13F 申报季内的变动字段不能引用 〔D〕
- **现状**（10-12 复测）：`investorsHolding` 字段已经不存在（09-17、10-09、10-12 都没有）。NVDA 返回 `report_period:"2026-09-30"`、`coverage_type:"top_holders"`、`is_exhaustive:false`，前 10 名全是先报的小机构（第一名 Congress Asset Mgmt 257 万股）；所有 `*_change_percent` 都是 0，`shares_change` 却不是 0。
- **怎么读**：申报季内（季末后约 45 天）不引用环比、变动百分比，也不把 `top_holders` 当大股东榜；变动用按机构查的 previous / current 自己算（N-152④）。本条留着防字段回归。
- 历史：07-22 记为 `investorsHolding` 6234→1441 的残缺假信号（07-24 回补到 1882）。
- **依据**：07-22 首记；10-09 `0c7e44ba…`；10-12 `ae1f335c…`

### N-176 signal 零碎（10-08 第二轮复跑） 〔D〕
- **①** 覆盖边界：外国私人发行人（ARGX 等 ADS）不报 Form 4，insider 只剩议员行（10-12 NVDA+ARGX 合查时 ARGX 0 行，分不清是被挤掉还是本来就没有，见 ②）。另外 insider 只有 Form 3 / 4，没有 Form 144（减持预告），fundamentals 的 SEC 文件列表里也没有；Stevens 9/2 报备减持 500 万股（约 10.9 亿美元），只能从 WebSearch 查到（GAP U33，09-17 `710a819a…`）。
- **②** 多标的同批查询时，`limit` 作用于合并后的整张列表（10-12 NVDA+ARGX `limit=50` 全是 NVDA，没有 warning）。工具描述已写（"Insider trades: merged category list"）〔C·已文档化〕。
- **③** 单票内部人行按交易日倒序，迟报的申报排回交易日的位置（10-12 仍成立）。
- **④** A-Award 行可能带非零价格（10-12 没有样本）。
- **⑤** 评级入库滞后：ARGX 当天 −14.8%，`analyst_grades` 最近一条还是 9/8。这是 metrics 的行为，同族见 N-184③（10-12 没有样本）。
- **⑥** 反向 ETF（TZA）的喊单被标成 bullish（10-12 没有样本）。
- **⑦** 喊单汇总带整批的 `neutral_count` 和 `_drilldown` 提示（10-12 仍成立）。
- **怎么读**：内部人逐只查；外国发行人写「无 Form 4」，不写「无买入」；「有没有减持预告」不能靠 MCP 判断，走 WebSearch 或 SEC EDGAR；反向 ETF 的看多算作看空。
- **依据**：10-08 第二轮复跑记录（c4 / c6 / Premarket / 01）；10-12 `c75bf7dc…` / `a92d88a5…`

### N-180 signal 零碎（10-09 第三轮复跑） 〔D〕
- **①** 代码复用导致串档：`signal(keywords=["DRAM"], categories=["insider_trading"])`（DRAM 现在是 ETF）返回 2014–2017 年 Dataram 公司的申报（10-12 仍成立，companyCik 0000027093）。原记「MU 的议员交易混进一行别家公司」10-12 未复现（4 行都是 Micron）。
- **②** MU 内部人比前一天少了 CEO 那 46 行 → 见 N-187（10-12 已回来）。
- **③** 一帖多票只拆出一部分：推文 2108286840579219940 点名 9 只（UBER / META / APP / ASTS / RKLB / SPCX / CCJ / BWXT / LEU），只拆出 META、UBER，ASTS / RKLB / SPCX 的看空丢了。10-12 两条清单帖 13/13 全拆出，另一条帖丢了 DRAM / SKHY，仍会发生（同族见 N-5）。
- **④** 方向值出现 `"hold"` → 见 N-155（10-12 样本里没有 `hold`）。
- **怎么读**：ETF 不查内部人；议员行核对公司名；清单帖回原文核对点名的票；`hold` 按中性计。
- **依据**：10-09 第三轮复跑记录；10-12 `3e187568…` / `10f90909…` / `a28bb28a…`

### N-184 signal 零碎（10-09 第四轮复跑） 〔D/C〕
- **①** 内部人行前后不一致：NBIS 首席营收官 9/14 的行权行、ONDS 首席财务官 9/24 的卖出行，10-08 有、10-09 没了 → 见 N-187（10-12 都回来了）。
- **②** `transactionType` 为空、股数为 0 的行是 Form 3（初始持股申报），按 `formType=="3"` 跳过（10-12 订正：原记只写了「空类型行」，没认出是 Form 3）。
- **③** `analyst_grades` 入库不全：MRVL 10-07 有 15 家，没有新闻里写的 BMO、BofA 上调（10-12 用 `limit=20` 复测仍然没有）。新闻里报道的评级动作，在 `analyst_grades` 里查不到事件日的，不算新催化（10-09 已拍板）。
- **怎么读**：Form 3 行跳过；内部人结论注明查询时间（N-187）。
- **依据**：10-09 第四轮复跑记录；10-12 `249cd1da…` / `3e187568…` / `dd4875fc…`

## signal · 交易员实盘持仓（trader_position）

> 🔒 **交易员一律脱敏**：07-30 ~ 08-04 样本用 `T1`/`T2`…（`T3` 与 `T3′` 是同一人的两个显示名）；10-12 复测样本不编号，只描述。数字、tier、`rating_reason` 均为实测原值。
> **来源**：07-30 一次「在 trader_position 上做模拟跟单账本」的可行性验证（摸底 + 实建 17 仓账本），方案已否决（见 CHANGELOG 07-30），但数据面结论独立成立，任何消费 `trader_position` 的地方都适用。之后 08-01 / 08-03 / 08-04 / 08-17 / 10-08 多轮补测，10-12 生产端全量复核。07-30 原始调用 `f3d15559…` `d1516e54…` `a0e138c9…` `1f1a8533…` `32da17cd…`。
> ⚠️ 本组多数问题只读一次返回看不出来，**一拿它算收益、判方向就会静默出错**。

### N-171 🔴 组汇总按截断后的行重算，`limit` 一小方向就会翻 〔A〕
- **①（主）现状**（10-12 复测）：`limit` 是每组返回几条仓位（默认 10、最大 50；不传 `sort_by` 时组内按 tier → `profile_confidence` 排，截断先砍 D / P 档）。`symbol_rollup` 整块按返回的这几行重算，人数、`positions_returned`、`agreement`、金额、`latest_event_time` 全跟着变，`status:"ok"`、无 warning。同查 BTC：`limit=1` 看多 1/1、gross 41 万；`limit=50` 看空 4/7、gross 746 万。工具描述写 "symbol_rollup metadata is returned per group outside that row budget"，与实际行为矛盾。
- **怎么读**：要用汇总一律传 `limit=50`，再逐组看 `positions_returned`：**等于所传 `limit` 即可能被截**，汇总只代表返回的行，口径里写明。⛔ 拿 `positions_returned` 对 `active_trader_count` 查不出截断，两者一起被重算（`limit=1` 时都是 1）。默认 10 在 10-12 没踩到（最大组 BTC 7 腿），但组一超过 10 腿就会出事。
- **②** 多标的查询缺组不提示（GAP U31；归 B）：`keywords=["ETH","MU","SOL"]` 只回 ETH 组，MU、SOL 整组缺席；`["BTC","ETH","SKHY","SNDK","CL"]` 只回 BTC、ETH 两组，SKHY、SNDK 没有任何提示（唯一的 warning 是关键词超过 5 个）。与描述 "omissions are reported in meta.warnings" 不符。读法：请求列表与返回组做差集，缺的逐只单查；仍缺就写「当前榜上无可见仓位」，不写「没人持有」。
- **③** 全榜（空 `keywords`）固定只回 5 组，`limit=50` 也一样；入选随 `asset_type` / `sort_by` 变。10-12：crypto 为 BTC/ETH/NEAR/XRP/BNB，tradfi 为 INTC/AAPL/XYZ100/SKHYNIX/NVDA，不传为 BTC/ETH/NEAR/INTC/AAPL。跨标的敞口写「榜内可见下界」，并写明拉了哪几张榜。
- **④** 按名字过滤不生效 → 见 N-59e。
- **⑤** 取不到价格的标的静默少行 → 见 N-59g。
- **⑥** 档案带 `profile_confidence`（对象：`score` / `max` / `higher_is_better`），默认排序 tier → `profile_confidence` 已写进工具描述。
- **⑦** 擅长与弱项名单可重叠、弱项名单可为 `null` → 见 N-59o。
- **⑧** `time_range` 会静默剔掉陈旧仓，组人数与 `agreement` 按剔后重算（10-08：BTC 7→5 人）；单查加 `limit=50` 返回 `ok`、无警告，只在全榜加小 `limit` 时见过 `partial`。不要拿它当服务端陈旧闸（剔了谁看不见），陈旧判定见 N-59m。
- **依据**：10-08 首记 `c4cc9110…` `3d42b288…` `2326e2c7…` / `18207b4a…`；10-12 ① `08319538…` / `e06b2526…`、`d53af8c5…` / `7285836a…`；② 10-10 `e04db624…`，10-12 `c98a3d74…` `584a96bb…`；③ `33c1dd4f…` `2ef0028a…` `b36da36a…`

### N-59m 🔴 平仓不回流：清仓后仍返回旧仓，`is_active` 恒为 true 〔A〕
- **现状**（10-12 复测）：10 个标的组 `actions.close` 全为 0，21 行 `is_active` 全为 `true`。9/21 行 `event_time` 已 ≥3 天未动（名义 $334 万，占全部 $967 万的 35%），最长 7.9 天；6 行比所在组 `latest_event_time` 落后 ≥2 天。陈旧度是连续分布（2.4~3.4 天之间有 6 仓），没有断层。
- **怎么读**：消费前过「陈旧闸」，命中任一即标「待核，不计入敞口排名」：① `now − event_time ≥ 3 天`；② 比组内 `latest_event_time` 落后 ≥2 天。3 天、2 天都是拍定的阈值，未回测；但方向确定，不设闸就会把幽灵仓当真实敞口。措辞只写「≥N 天未观测到变动，可能已平仓」，不写「他持有」，也不写「他已平仓」。`time_range` 代替不了这道闸（N-171⑧）。
- **历史**：08-01 上游实盘 bot 显示 T5 已无持仓，MCP 仍返回其两仓共 $451 万，是当次全榜名义第一（占 38%）。原记「3 天切点是数据自己给的」，10-12 样本没有断层，已删。
- **依据**：08-01 `66880966…` / `2ab45ef2…`；08-03 `c02a7271…`；10-12 `33c1dd4f…` `2ef0028a…`

### N-59q 🔴 全组名义为 null 时报「多空平衡、金额 0」 〔A〕
- **现状**（10-12 复测）：`positions_without_notional == positions_returned` 时，`gross` / `net` 为 0，两个比率为 0，`net_direction:"balanced"`，不报缺数据。10-12 有 4 组命中（BNB、AAPL、XYZ100、SKHYNIX，各 1 腿、10~20x）：AAPL 组只有一条 20x 多单，也报 `balanced`。
- **危害**：「没有数据」和「真的多空对等」在返回值上无法区分；`gross=0` 会让该组在敞口排序里沉底。截断也会人为造出本条（10-08：ETH 组 `limit=1` 只剩一条无名义空单，报 `balanced`，见 N-171①）。
- **怎么读**：先判 `positions_without_notional == positions_returned`，命中则 `gross` / `net` / 两个比率 / `net_direction` 五个字段整体作废，只报人数与杠杆。措辞写「该组 N 人 M 条腿（多 x／空 y），平台未提供金额，敞口无法计价」，不写「多空平衡」，也不写「无敞口」。
- **依据**：08-03 `c02a7271…`；10-12 `33c1dd4f…` `2ef0028a…`

### N-59j 名义口径会被单个巨鲸压秤，null 率为 0 也一样 〔C〕
- **现状**（10-12 复测）：BTC 组 7 腿全有名义，人数 4 空 : 3 多（`agreement` short / 0.571），名义空头占 88%，其中一条空单（约 390 万）占 gross 的 52%。当天两种口径方向一致、没有翻，但强度被一个人放大。
- **历史**：08-01 BTC 组 8 仓全有名义，人数 7:1 偏多（`agreement` long / 0.875），T3 一仓占 gross 50%，`net_direction` 被翻成 `short`；翻向的这一仓 `current_symbol_caution` 恰为 `true`。这一次推翻了 N-59a 旧写法「null 率为 0 时金额口径可用」。
- **怎么读**：`net_direction` 和金额比率任何时候都不单独用：① 先报 `long.count : short.count`；② 算「最大单仓 ÷ gross」，>40% 标「单人主导」（阈值拍定，未回测）；③ 净方向写两个口径，例如「按人数 4:3 偏空；按名义 88% 偏空，单仓占 52%」。
- **依据**：08-01 `66880966…`；10-12 `33c1dd4f…`

### N-59a 名义为 null 的腿计入人数、不计入金额 〔C·已文档化〕
- **现状**（10-12 复测）：工具描述已写明（"a position with null notional remains in leg counts but is excluded from dollar exposure and increments positions_without_notional"），返回带 `positions_without_notional`。10-12 ETH 组 2 多 2 空，一条空单名义为 null，结果 `net_direction:"long"`、`long_notional_ratio` 0.60，而同组 `agreement` 是平局 `unknown`。
- **怎么读**：`positions_without_notional > 0` 时金额类字段不完整，只作参考；判多空用按人数的字段（`long.count` / `short.count`、`agreement`）。全 null 见 N-59q；全有名义也会失真，见 N-59j。
- **历史**：原写「null 率为 0 时金额字段才可引用」，已被 N-59j 推翻。
- **依据**：07-30 首记；10-12 `33c1dd4f…`

### N-59r `agreement` 按人计票：双向持仓者弃权，平局吐 `unknown/0/0` 〔C·已文档化〕
- **现状**（10-12 复测，10 组逐组复算全中）：`agreement` 按去重后的交易员计票，每人一票；同时持多空两腿的人弃权（不进分子，但计入 `total_trader_count`）；`ratio = dominant_trader_count ÷ total_trader_count`；可计票的人里没有严格多数时，整体吐 `unknown/0/0`。工具描述已写前两点，**没写平局规则**。10-12：BTC 4 空 3 多 → `short/4/0.571`；ETH 2 多 2 空、无人双向 → `unknown/0/0`、`total_trader_count:4`。
- **怎么读**：`unknown` 和 `ratio:0` 一律读作「该组没有多数方向」，不是「没有共识」，也不是字段坏了；再看 `long.count : short.count`，判断是平局还是双向者弃票。⛔ 不要用 `positions_returned > active_trader_count` 判 `unknown` 的成因：它只能识别有人双向，识别不了平局。反过来可用：`dominant_trader_count ÷ ratio` 能反推 `total_trader_count`，用来核对人数。
- **历史**：N-59k（08-01）原记「有人双向持仓就打崩成 unknown」，08-03 由本条订正，10-12 再次证伪（ETH 无人双向也是 `unknown`）。
- **依据**：08-03 `c02a7271…`（5/5 命中）；10-12 `33c1dd4f…` `2ef0028a…`

### N-59s 同一显示名下可能是两个人 〔B〕
- **现状**（10-12 无法复测：16 个显示名对应 16 个档案指纹，一一对应）：08-04 BTC 组「T3」出现两次，`profile` 完全不同（一条 tier A / 151 笔 / 净盈利 329.7 万；另一条 tier「—」/ 0 笔 / focus `[ETH,BTC]`），两条都是空单。`active_trader_count` 把它们算作 2 人：服务端按档案计数是对的，错在显示名。
- **怎么读**：显示名在两个方向上都不能当身份键（另一方向见 N-59n）。按档案指纹（`overall.n_trades` + `overall.net_pnl_usd` + `summary_refreshed_at`）归一：指纹相同就合并；**指纹不同就强制拆开**，产出里标「同名两个账户」。与 `dominant_trader_count ÷ ratio` 反推的人数对不上时，以服务端为准。
- **服务端**：描述说 `agreement` 按 "distinct canonical traders" 计，服务端有身份键只是没暴露；返回 canonical trader id 即可同时消灭本条与 N-59n。
- **依据**：08-04 `5a6f20d4…`；10-12 `33c1dd4f…` `2ef0028a…` `584a96bb…`

### N-59n 同一个人在不同标的组下显示名不同 〔B〕
- **现状**（10-12 无法复测，样本内未出现）：08-01「T3」（BTC 组）与「T3′」（SKHY 组）的 `profile` 逐字段相同（149 笔 / 净盈利 309.5 万 / 盈亏比 2.56，连 `summary_refreshed_at` 都是同一秒）。按显示名聚合会把该员 $251 万敞口拆成 $206 万与 $45 万两个人，「谁的钱最大」排名失真，红旗也会重复计或漏计。
- **怎么读**：不用 `trader` 字符串当聚合主键，按档案指纹归一（见 N-59s），产出注明「已合并显示名 A/B」。
- **依据**：08-01 `66880966…`

### N-59p `as_of` 不是战绩刷新时间，各人档案刷新不同步 〔B〕
- **现状**（10-12 复测）：同一份返回里，仓位和事件是实时的，交易员 `profile` 是日快照（约 02:35~02:46Z 刷新），22 分钟内两次拉取一字不变。`as_of` 却对所有人统一写拉取日：10-12 08:00Z 的一次拉取，21 行 `as_of` 全是 `2026-10-12`，而 16 人里 15 人的 `summary_refreshed_at` 还停在 10-11T02:36~02:46Z，只有 1 人是 10-12。
- **历史**：08-03 T1 的 `summary_refreshed_at` 比同表其他人旧 2 天，旧的恰好是最扎眼的「98% 胜率 + 盈亏比 5510」那组数。
- **怎么读**：战绩的时间锚用 `summary_refreshed_at`（保守口径：`last_30d` 可能比它新，见 N-59h），不用 `as_of`，也不说「当前」。同表多人时取各人 `summary_refreshed_at` 的最小值做整表口径，跨度 ≥1 天就点名最旧的那个人。
- **依据**：07-30 同日两次拉取对照；08-03 `c02a7271…`；10-12 `33c1dd4f…` / `fcf2432c…`

### N-59i `last_30d` 是滚动窗口，成交增量只能看 `overall` 〔C〕
- **现状**（10-12 复测）：`last_30d.n_trades` 是滚动 30 天，日增量 = 当期平仓 − 滑出窗口的平仓，可为负；`overall.n_trades` 是累计已平仓笔数，它的增量才是当期真实平仓数。10-12 有人 `overall` 149 笔、`last_30d` 0 笔，全部在窗口外。档案新鲜度见 N-59p。
- **怎么读**：推算某人一段时间成交多少，只用 `overall.n_trades` 的增量，且只在 `summary_refreshed_at` 推进时才算（同日重跑增量恒为 0，不代表零成交）。日频轮询的观察覆盖率 = 观测到的平仓数 ÷ `overall` 增量；07-30 样本 15 人合计约 10.8 笔/天真实平仓，日频快照只看得到「持仓过夜且当日消失」的一两笔（覆盖率约 9%~28%）。任何「跟踪某人交易」都要按这个量级打折。
- **依据**：07-30 首记；10-12 `33c1dd4f…` / `fcf2432c…`

### N-59h `profile.summary` 里的数字比结构化字段旧 〔B〕
- **现状**（10-12 复测）：形态变了：累计笔数已和 `overall` 一致，30 天笔数仍对不上（三人 summary 分别写 23 / 95 / 35，`last_30d.n_trades` 是 21 / 85 / 30）。还有人 summary 写 "no latest active positions"，而他有在 `summary_refreshed_at` 之后新开的两仓。
- **历史**：07-30 T4 的 summary 写 406 / 150 笔，同一 profile 的 `overall` 431、`last_30d` 175，双双差 25 笔；同批另一人完全一致。所以「对得上」不能当验证通过。
- **怎么读**：对外数字一律取结构化字段（`overall` / `last_30d`），summary 只读定性部分（风格、跟与不跟的条件），尤其别拿 summary 里的笔数判样本量。
- **依据**：07-30；10-12 `33c1dd4f…`

### N-59o 标的既不在擅长名单也不在弱项名单时，没有任何标记 〔B〕
- **现状**（10-12 复测）：`current_symbol_caution` 只在标的落入 `caution_symbols` 时为 `true`；落入 `focus_symbols` 和两边都不在，返回值都是 `false`。10-12 的 21 行里擅长 11 / 弱项 3 / 都不在 7，其中「都不在 + 杠杆 ≥10x」6 行（例如一人 20x 做 BTC，而他的 focus 全是 CXMT/QNT/ARB/SUI/FORM）。另外，`caution_symbols` 可能是 `null` 而不是空数组（10-12 有 4 行）；两个名单可以重叠（10-08）。名单的导出口径没有文档。
- **怎么读**：客户端自己做三分类：在 caution 里 → 弱项；在 focus 里 → 擅长；都不在 → 陌生。陌生区只写「系统对他在这个标的上没有判断」，不写「他不擅长」。值得单独提示的组合是「陌生 × 杠杆 ≥10x」。判空时 `null` 和 `[]` 都要认；两个名单重叠时按弱项处理。
- **依据**：08-01 `66880966…`（19 仓：擅长 12 / 弱项 3 / 陌生 4）；10-12 `33c1dd4f…` `2ef0028a…`

### N-59e 按交易员名字查不生效，名字被静默清掉 〔B〕
- **现状**（10-12 复测，比原记更糟）：名字放进 `keywords` 会被服务端静默删掉（`filters_applied.keywords` 变成 `null`），无 warning，返回与空关键词相同的整张热门榜（5 组 16 行）；名字写在 query 串里，同样返回整榜。与描述 "omissions are reported in meta.warnings" 不符。
- **同族**（GAP U6，10-10 / 10-12 复现）：kol_call 传 KOL 句柄、insider 传 CEO 全名、13F 传机构名（「Vanguard」被解析成台股 5347.TWO）也都静默失效，`status:"ok"`、无提示（分别见 N-88、N-95、N-152）。人名、句柄、机构名都不是可靠的路由维度。
- **怎么读**：「看某个交易员」只能拉全榜后按档案指纹在本地筛（N-59s）；全榜只有 5 组（N-171③），筛不到只能说「当前榜内没看到他」，不能说「他没有仓位」。不要对外承诺按人查。
- **依据**：07-30 首记；10-12 `b36da36a…` / `0439a652…`

### N-59d 仓位是实时快照；定向查询会漏掉符号分裂的组 〔A〕
- **现状**：仓位侧是实时快照，日内就会变（07-30 18 分钟内 SNDK 4 人→5 人；10-12 22 分钟内两次拉取逐字相同，只说明这段时间没有新事件）。覆盖随日剧变，例如 MU 07-09 有 4 人、07-15 只剩 1 人。
- **定向查询不可靠**（10-12）：全榜里有 `SKHYNIX` 组（`underlying_symbol:"000660.KS"`），而 `keywords=["000660.KS","SKHYNIX"]` 定向查时，`SKHYNIX` 被改写掉、只剩 `000660.KS`，返回 `degraded` + `no_match`（机制见 N-124③）。同一标的历史上散在 `SKHYNIX` / `SKHX` / `SKHY` 三个代码，10-12 全榜只见 `SKHYNIX`。
- **怎么读**：「全榜里没有它」不等于已平仓，「定向查不到」也不等于已平仓。账本类用途要双路取数：全榜记下 `symbol` + `underlying_symbol`，账内未平仓标的再逐个定向查（`limit=50`）；定向查不到时以全榜为准；两路都没有才做「消失推断」，并记录发现滞后天数。符号分裂按 `underlying_symbol` 合并。平仓事件本身不回流，见 N-59m。
- **依据**：07-30 同日两次拉取对照；10-12 `33c1dd4f…` / `fcf2432c…`，`2ef0028a…` 对 `ab4c2a87…`

### N-124 trader_position 的路由三点 〔A〕
- **①** `query="trader positions"` 只返回 trader_position 一类，与 `categories=["trader_position"]` 等价（10-12 仍成立，5 组 BTC/ETH/NEAR/INTC/AAPL）。仍建议显式传 `categories`。
- **②** 单标的没有活跃仓时返回 `status:"degraded"` + `no_match`，不是空组；提示文案是 "unknown ticker / no upstream coverage"，连工具描述示例里的 MSTR 也会这样（GAP U8，10-10 / 10-12）。读法：看到 "unknown ticker" 按「当前无活跃仓」理解，不写「不支持该标的」。
- **③** HIP-3 / 股票永续代码会按别名改写成底层股票代码，然后查空：`keywords=["SKHX"]` → `filters_applied.keywords:["000660.KS"]` → `no_match`；`["000660.KS","SKHYNIX"]` 同样只剩 `000660.KS`，而全榜里明明有 `SKHYNIX` 组（N-59d）。读法：这类标的拉全榜，在客户端按 `symbol` / `underlying_symbol` 筛。
- **依据**：10-01 `57cfff27…` / `29121b9e…`，`1fbf7624…` / `dadf59f2…` / `961202d8…` / `e1a9cd54…`；10-12 ① `7ba51577…`，② `ab4c2a87…`，③ `eee09d01…` / `ab4c2a87…`

### N-96 tradfi 交易员持仓：全市场入口能用，但池子很薄 〔D〕
- **现状**（10-12 复测）：`asset_type="tradfi"` 全市场入口可用但很薄：5 组共 6 腿（INTC 2 腿，AAPL / XYZ100 / SKHYNIX / NVDA 各 1 腿），`limit=50` 也一样；3/6 腿名义为 null；tier 从 A 到 D 都有；除 INTC 外，各腿最近事件都在 10-08~10-09。`instrument_type` 全是 `stock_perp` / `index_perp`，未见加密混入（GAP R5：10-05 曾混入 SUI、LIT，见 N-155；10-12 两次样本未复现）。
- 个股入口是时点现象：08-17 查「NVDA 持仓」返回 `degraded` + `no_match`；10-12 有 1 腿，tier D、累计净亏约 49.8 万。
- **怎么读**：演示和对外问句用全市场形式（「交易员最近在链上交易哪些美股」）；不把整条数据流称作「顶级交易员」，引用时按 `tier` / 战绩筛（只引 A/B 或点名战绩），亏损档案不包装；引用名义额前查 null（N-59q）和陈旧度（N-59m）。
- **依据**：08-17 `4b89d8f6…` / `29f7525e…`；10-12 `9935626a…` / `2e2ee055…` / `2fdd2474…`

### N-59b `entry_price` 只在开仓行出现，没有浮盈和逐笔历史 〔D〕
- **现状**（10-12 复测）：`entry_price` 只在 `action=open` 的行上有（10-12 共 21 行，open 4 行全有，add 11 行、reduce 6 行全无）。仓位行字段（含新增的 `signed_notional_value_usd`）里没有浮盈 / 保证金 / 强平价；交易员档案只有聚合统计（`overall` / `last_30d` / `focus_symbols` / `caution_symbols`），没有逐笔历史。
- **怎么读**：跟单类用途只能前向跟踪，无法回测。开仓价一律用「观察时刻锚价」并写明口径；不要基于 `entry_price` 设计任何算收益的逻辑，它的覆盖率随 open 行占比而变（07-30 为 1/16，10-12 为 4/21）。
- **依据**：07-30；10-12 `33c1dd4f…` / `2ef0028a…`

### N-59c 部分标的取不到价，取价要按 `underlying_symbol` 〔D〕
- **现状**（10-12 复测）：永续标的里有未上市或合成标的（CXMT = 长鑫存储，未上市；XYZ100 = 合成指数），`metrics` 取不到价：4 个代码都留在 `filters_applied.keywords` 里，快照只出 SNDK、`000660.KS` 两行，`status:"ok"`、无 warning（静默形态与差集自查见 N-59g）。取价要用 `underlying_symbol`（`SKHYNIX` / `SKHX` → `000660.KS`），用 `symbol` 取不到。只取 `market` 时快照不带币种字段，`000660.KS` 是韩元，按 `exchange`（`KSC`）判。
- **怎么读**：① 取不到价的仓位标 `unpriced`：跟方向、排除在收益统计外、单独报条数；② 收益一律先算百分比再乘虚拟名义，不做汇率换算，不把不同币种的锚价放进同一个减法；③ 取价前先按 `underlying_symbol` 归一。
- **历史**：07-30 原记「CXMT 被剔出 keywords、连查都没查」「`profile_block.currency` 明示币种」，10-12 均不再如此。
- **依据**：07-30；10-12 `0b0b89af…` / `c648f3ba…`

### N-59g 批量取价失败是静默的，只能靠差集发现 〔B〕
- **现状**（10-12 复测）：`metrics` 批量取价时，取不到的代码留在 `filters_applied.keywords` 里、快照默默少行，`status:"ok"`、无 warning（请求 4 个、返回 2 行，`total:2`）。crypto 批只返快照（`as_of:null`、不带涨跌字段）。
- **历史**：07-30 还见过第二种形态（代码直接从 `filters_applied.keywords` 里消失），10-08、10-12 都没复现；原记「tradfi 取价必带 CORE fundamentals」已修（见归档 N-59f）。
- **怎么读**：把请求的代码列表与返回的 `snapshot[].symbol` 做差集，非空即部分失败；不要用「有没有报错」或「返回行数」判成败。crypto 与 tradfi 分批，批内 ≤5 个。
- **依据**：07-30；10-08 `fded70b5…`；10-12 `0b0b89af…` / `c648f3ba…` / `51ed8476…`

**展示前必查**（对外展示交易员战绩前逐条过；`profile` 把战绩算好了直接给，但最扎眼的几个数恰好最会骗人。10-12 复核时这些形态都还在）
1. ⛔ `pnl_ratio_infinite=true` 不是「神」，是「盈亏比无法验证」（零亏损，分母为 0）。必须连 `rating_reason` 一起展示，不要只报胜率。10-12 仍有一人 `pnl_ratio_infinite:true`、胜率 100%、7 笔、tier `P`。
2. ⛔ 有限的极大盈亏比同样不能当实力读：`pnl_ratio > 100` 与 `pnl_ratio_infinite=true` 同等对待。10-12 一名 tier A 交易员累计只有 11 笔，`last_30d.pnl_ratio` 是 985,510.24（6 笔）。tier 会因一笔样本跃迁（历史：T1 07-20 为 `∞` / 100% / tier P，08-01 多一笔亏损后变成 5510.64 / 98% / tier A），只当当次读数，别当稳定标签。
3. ⛔ 小样本的高盈亏比要连样本量一起报；tier `P`（provisional）已经编码了这层不确定，但用户看的是那个数。`n < 10` 不给百分比（3 笔 2 胜写「2/3」，不写「67%」）。
4. ⛔ `current_symbol_caution=true` 是最硬的单条红旗：他正在做的标的就在他自己的历史弱项名单里。10-12 有一人 40x 空 BTC 且命中（tier D）。
5. ⛔ 杠杆 ≥10x 单独提示：杠杆不进 tier 评级，但决定仓位能不能活到方向被验证。10-12 样本 21 行里 16 行 ≥10x。
6. 时间锚写 `summary_refreshed_at`（N-59p），数字只取结构化字段（N-59h），陈旧仓先过闸（N-59m），「陌生 × 高杠杆」单独提示（N-59o），身份按档案指纹归一（N-59n / N-59s）。

### N-59k → 见 N-59r
08-01 原记「同一交易员双向持仓时 `agreement` 退化为 `unknown`」，成因判断不完整（根因是可计票者平局，双向者只是弃权），10-12 再次证伪（ETH 组无人双向也是 `unknown`）。计票规则与读法已并入 N-59r；原建议「用 `positions_returned` 对 `active_trader_count` 判 `unknown` 成因」作废。

## news（搜索、趋势榜、Telegram）

### N-145 news 的 `asset_type`：趋势模式可传，搜索模式不传 〔A〕
- **现状**（10-12 复测）：搜索模式传 `asset_type="tradfi"` 会改变召回集合，不是在原结果上做减法，也不报警。两次样本：A 段 `"Micron MU"` 7d `limit=10`，传与不传都是 10+10、文章 7/10 重合，差异不大；E 段同一 query `limit=20`，传了 14 条、不传 17 条，不传独有 7 条（Fool / CNBC / Kiplinger 等），传了也有 4 条独有。以 E 段为准：会丢召回。
- 公司名含常见词或 query 是宽主题词时，返回 `asset_type_no_matching_keyword`（"all keywords resolved to other families (crypto)"），此时即使 `entity_filter_applied:true` 也可能 0 条相关；`"stock market"` 带 tradfi 仍混进 Starknet 稿。过滤既损召回，又不去噪（10-05）。
- `asset_type="crypto"` 在推特搜索、混合搜索、媒体搜索、媒体浏览四条路径上，结果与不传逐条相同，只是后置标签过滤，挡不住查询漂移；tradfi 的媒体浏览能生效，但会漏进加密稿（10-10 起，10-12 复现）。
- **怎么读**：搜索模式一律不传 `asset_type`，范围在客户端按完整公司名或 `$TICKER` 判；出现 `asset_type_no_matching_keyword` 按召回失败处理。趋势模式（空 query）照传，见 N-1 / N-146。
- 历史：N-112①（10-01）记「传 tradfi 正常返回」，只说明不再返回 0 条（原第 70 行，已归档），不说明召回无损；10-05 首测带 tradfi 2 条、不带 8 条（路透 / 彭博 / WSJ 全丢）。
- **依据**：10-05 `ae77c21a…` / `7c7181c9…`；10-12 `65a30d51…` / `7efd7fee…`（A 段）、`3fa0a261…` / `86a58392…`（E 段）；crypto 不生效 10-10 `592a8d47…`、10-12 `7dad5c41…` / `d8278feb…`

### N-35 🔴 news 查不到时返回兜底内容，不返回空 〔B〕
- **①** 无匹配时多数情况返回语义兜底的不相关内容，`status:"ok"`：10-12 `"Quhuo Navios"` 7d 返回 20 条航运 / 霍尔木兹新闻，0 条相关（红线 11 的事实）。
- **②** 个别实体是召回黑洞：`"Bloom Energy"` 与 `"Bloom Energy BE"` 都是 0 条相关，20 条里 17 条相同。兜底内容是当时的最新信息流，所以两个不同标的同时查失败，会拿到几乎一样的结果，容易误读成「两票有共同报道」。
- **③** 也可能返回空数组 + `status:"degraded"`，不一定是兜底内容（10-03，原第 444 行）。
- **④** 兜底时 `entity_filter_applied:true` 照样会出现，不能拿它判断命中。
- **怎么读**：所有「报道 ≤ N 条」「有没有报道」的判断，按逐条判过相关后的条数算，不用 raw count。返回里一条都不含目标公司名或 ticker 即判召回失败，记资料缺口；同 query 重试、换措辞都无效。公司名 + ticker 双词消歧（红线 5）对黑洞实体无效。
- 历史：07-29 原记「兜底是固定集合」，10-12 看更像当时的最新信息流；原文「故 N-15 双词形态有效」引错，应为红线 5。
- **依据**：06-12 首记（红线 11）；07-29 Bloom Energy；10-12 `a48c3aff…` / `913f288a…` / `f05dfcc4…`

### N-101 🔴 专有名词、多词短语、合约地址：默认 standard 会被语义近邻淹没 〔A/C〕
- **现状**：`search_depth` 默认 `standard`（短语 + 语义召回），专有名词和多词话题的精确命中会被语义近邻淹没；`quick` 只做精确短语，更快，但不补满条数。10-12 同窗对照（`"tokenized deposits"`，7d，`limit=10`）：standard 20 条里只有 1 条讲 tokenized deposits，其余是 tokenized stocks、债券等近邻；quick 7 条全含这两个词，其中 4 条正是该话题；两边按 `source_url` 只重合 1 条（quick 0.6 秒，standard 2.0 秒）。纯 ticker 查询两档几乎没区别（10-10 GS 8 条里 7 条相同）。
- **①** 合约地址（CA）最重：standard 下 `entity_filter_applied:false`，10-12 返回 10 条 social，0 条含目标 CA，8 条含别的 0x 地址；quick 3/3 含目标 CA。工具描述称「完整 token 地址可作别名」，对长尾 meme（PONS）不生效。Solana 地址未复测（09-07 quick 空返回 + `degraded`，不可定性）。
- **②** 只有 `$SYMBOL`、没有 CA 的帖子 quick 抓不到。链上标的要 CA 路和 `$SYMBOL` 路各跑一次，按 `source_url` 去重；`$SYMBOL` 路的结果按帖内 CA 分三类（含目标 CA / 含他币 CA / 无 CA），撞名见 N-103。
- **怎么读**：多词专有名词、政策话题、CA 先用 `quick`，条数不够再用 standard + `sort_by="relevance"`；纯 ticker 不必切 quick。`entity_filter_applied:false` 就是语义召回，一律逐条判相关（原第 444 行）。
- 历史：09-07 立条时只针对 CA；09-16 报告已指出 CA 只是特例，10-12 复测确认是通用缺陷。「quick 与 standard 差别大」和「几乎没区别」两种说法分别对应短语查询和纯 ticker 查询，都成立。
- **依据**：09-07 `c4b99a7b…` / `f2dde047…`；10-12 `63bd6169…` / `93c45aed…`（CA）、`0fac7986…` / `333bc4fd…`（短语对照）；10-10 `890e149d…` / `37c4150e…`（GS）

### N-103 news 实体撞名：cashtag 和多词短语里像代码的词被当实体 〔A〕
- **①** cashtag 撞人名和同名股票：10-12 `$BEN`（quick，`entity_filter_applied:true`）20 条里 0 条在讲 meme 币，有 Ben Affleck、Ben Shapiro、Ben-Gvir 等，还有 Franklin Resources（美股代码 BEN）的稿。链上 symbol 短而常见（BEN / CTO / MOO / PONS），撞名概率远高于股票代码。
- **②** 多词短语里像代码的词被锁成实体：「Groq 3 LPX」召回 Louisiana-Pacific；「strategic bitcoin reserve bill」用 quick 时 bitcoin 被解析成 BTC，吞掉整个短语；「AI chip export controls」结果与 `query="AI"` 逐条相同；「SWIFT tokenized deposits pilot …」里 pilot 被锁成实体，召回的全是飞行员新闻；`ONE` 撞英文单词 one，`MSTR` 被展开成普通词 strategy。这些都显示 `entity_filter_applied:true`；结果行没有 `matched_by` 一类字段，看不出是怎么命中的（09-16 起，10-12 复现）。
- **③** 用 SPAC 原名查新闻几乎全无关，用合并对象名才准（10-03，原第 444 行）。
- **④** 英文领域术语撞公司名：「oracle manipulation liquidation exploit thin liquidity price feed attack」（本意是预言机）20 条全是 Oracle 公司（ORCL）的稿，`entity_filter_applied:true`；同一 query 加 `asset_type="crypto"` 结果不变（与 N-145「crypto 只是后置标签过滤」一致）；改写成「DeFi price oracle manipulation exploit lending protocol」仍混进 ORCL；去掉 oracle 改写成「price feed manipulation flash loan …」，loan 又召回房贷车贷。改用中文「预言机 喂价 操纵 清算 攻击」后 `entity_filter_applied:false`，加 `sort_by="relevance"`：3 天窗口第 1 条即命中预言机操纵事件，2 个月窗口 8 条里 7 条相关（10-13）。
- **怎么读**：`entity_filter_applied:true` 不代表相关。英文领域术语和公司名相同时（oracle / pilot），`asset_type` 挡不住，改用中文术语查询。含产品型号或多词话题的查询，逐条核正文是否含完整短语；公司名是常用词（Strategy、ONE）时用全称 + ticker 再逐条核；链上币逐条核是否在讲代币（含 CA / 链名 / meme 语境），不按 raw count 计热度。
- 历史：红线 5 原例「"CPI" 被 CPI Card 劫持」10-12 未复现（20 条都在讲通胀，`4983e44a…`），撞名现象本身仍在。
- **依据**：09-07 `c02f3116…`；10-09 `81e49939…`；10-12 `d5ab528f…` / `8d09e9b2…` / `3c371907…`；④ 10-13 `a60a85ba…` / `b45c17d6…`（+crypto）/ `a1366d9e…` / `7032cdf6…` / `b3f14001…`（中文 + relevance）

### N-146 news 趋势榜（空 query）：时间是刷新时间、没有信源、池子很小 〔C·已文档化〕
- **①** `published_ts` 是话题刷新时间，不是事件时间：10-05 PTC、PCVX 两条相同到毫秒；10-09 Orca 显示 10 小时前，首报在 29.5 小时前；10-12 RSR 条目时间 05:00，首报「Upbit 将上线 RSR」早 8 小时（合并原 N-189⑤）。
- **②** 行内没有 `source_url`，看不出信源（10-12 仍成立）。
- **③** 池子极小且随日变：10-12（周一）全池 1d 4 条、72h 8 条；带 tradfi 时 1d、72h 都是 0 条，`status:"degraded"` + `asset_type_filter_emptied`；同日 tradfi 不带窗口有 6 条。工具描述的示例「美股今天有什么风向 → `asset_type="tradfi", time_range="1d"`」当天就是空返回。旧值：10-05 tradfi 24h 3 条。
- **④** `content` 是 AI 摘要，数字可能自相矛盾（标题 +2.4%、正文 +2.5%），并夹带「操盘指南」，生成段见 N-87。标题会把代码写错（STRK 写成 "stock"，ASTS 写成 ATS）。
- **⑤** `social` 腿一直是未筛选的 TG 原始流，噪音约 50%；窗口内没有该类热点时 `articles` 为空，`social` 用 TG 原始流静默补满，warning 写 "possible upstream tag gap"，有误导。`asset_type="crypto"` 对补位内容不生效；`limit=10` 只给 5 篇 articles（09-16 起，10-10 复现）。
- **怎么读**：趋势榜只用来发现题目，只读 `articles`；`articles` 为空就写「该窗口无该类热点」，不把 `social` 当热点；短窗口为空时放宽到 24h 或去掉 `time_range`。判新旧用首报时间；信源数和数字一律回搜索模式取原文。
- **依据**：10-05 `9f374fb9…`；10-10 `d103cfcf…`；10-12 `081d5a85…` / `2ab40860…` / `0a1e1a4f…`

### N-87 🔴 tradfi 热榜的「交易指南 / KOL 观点」段是生成内容，不当数据源 〔A〕
- **现状**：08-13 实测 5 篇里 2 篇把加密模板硬套到美股上：SNDK 实价约 $200，却写「跌破关键支撑位 0.85 美元」「链上活跃地址下降」「项目方解锁代币」，引用的 CryptoWhale 等是模板名；同批文章的事实段（财报数字、盘前涨跌）核对无误。10-12 抽检 tradfi 热榜 6 篇，只有 1 篇带「交易指南」段，内容是「观望。素材无明确交易建议、支撑/阻力或技术指标位」：形态变了，但样本小。
- **怎么读**：热榜文章只引用事实段；「交易指南」「技术面」「KOL 观点」三类段落不读、不转述、不当数据源；对外引用热榜必须另拉行情核价。tradfi 加 `time_range="1d"` 可能空返回，见 N-146③。
- **依据**：08-13 `04b7fd20…`；10-12 `8d57f3ba…` / `0caf0aa8…`

### N-167 news 排序与噪音：默认时间序看不到首报，按代码搜噪音过半 〔C〕
- **①** 默认 `sort_by="time"`：热门事件整页都是最近几小时的跟进稿（10-08 `limit=30` 只回到 6.6 小时前，BTC 10 条只覆盖约 50 分钟），按 `relevance` 才看得到第一篇报道。10-12 没碰到热门事件（NVIDIA 1d 按时间排，12 条覆盖 21 小时，周末低量）。
- **②** `sources=["media"]` 会混入 `source_quality:"research"` 的 Zacks / GuruFocus / Seeking Alpha 模板稿（10-12 MU 7d 混入 4–5 条）。
- **③** 新闻行的推文作者与链接偶有错配（10-08，未复测）。
- **④** 按代码搜索时，标的只是分析方、消息来源或清单成员的稿件占大头：噪音 49–72%（混合 72%、TG 与研究源 67%、推特 53%、媒体 49%），银行股最重（JPM 17 条里 13 条是「摩根大通称……」）。按相关度排序明显改善（AAPL 3/12→10/12），但挡不住撞名（N-103）（10-10 扫描）。
- **怎么读**：判事件时间、判覆盖时用 `sort_by="relevance"`；计报道数时剔除模板稿、行情页和「标的只是分析方 / 来源 / 清单成员」的稿；作者与链接只认逐条核过的。
- **依据**：10-08 `dd1fa64d…` / `c32ea9aa…`；10-12 `86a58392…` / `17998f13…`

### N-112 news 参数现状：`sources` 数组、`sort_by` 可用，news 不扣额度 〔C·已文档化〕
- **①** 传 `asset_type="tradfi"` 不再返回 0 条（原第 70 行问题，已归档）；但搜索模式传了会丢召回，**不传**，以 N-145 为准。
- **②** `sources` 数组可用：`media` / `twitter` / `telegram` / `research`（10-12 生产端 schema 已声明数组类型）。
- **③** 有 `sort_by`：搜索模式 `time`（默认）/ `relevance`；趋势模式 `hot`（默认）/ `time`；`sources` 浏览只有 `time`。生效值回显在 `sort_by_effective`。
- **④** news 调用不扣额度：10-12 复核的 17 次 news 调用，`quota.consumed` 都是 0。
- **怎么读**：要权威报道用 `sources=["media"], sort_by="relevance"`，再按 N-167② 剔模板稿。
- 历史：本条撤销了红线 1 的「news 不传 asset_type（返回 0）」和红线 5 的「news 无 sort_by」；其中「不传 asset_type」10-05 又按召回理由恢复（N-145）。
- **依据**：10-01 `6073e072…` / `e0d14471…`；10-12 `56a6cdc7…`

### N-125 news 的 `sources` 浏览与 Telegram 源 〔C/B〕
- **①** 空 query + `sources=["telegram"]` 返回带 `tg_category` 的 TG 条目（分类可靠性见 N-52）。
- **②** `sources=["twitter"]` + `asset_type="tradfi"` 返回纯推特流。
- **③** `sources=["research"]` + query 返回 `source_quality:"research"` 的文章，但那是公开媒体和独立 newsletter，不是券商研报，见 N-68。
- **④** `asset_type="crypto"` 能返回结果，但 crypto 过滤不生效，见 N-145（订正原「crypto 实体搜索正常」）。
- **⑤** Telegram 只覆盖最近 24 小时：`time_range="3d"` 返回 `status:"partial"` + warning "Telegram news covers at most 24h"，但顶层 `time_range_effective` 仍回显 `3d`，实际值只在 `source_time_range_effective.news_tg_kol_feeds`；TG 搜索 `limit=12` 实给 10 条（10-10，10-12 复现）。
- **⑥** TG 搜索只认已知资产或频道类目：话题词查询（`"tokenized deposits"`）TG 这一路 0 条，带 info `no_search_keywords`（10-12）。
- **怎么读**：TG 广拉和推特流直接用 `sources`，均 0 额度；TG 结论一律按「近 24 小时」表述，读 `source_time_range_effective`；TG 搜索用具体资产词（BTC），不用泛词或话题词。
- **依据**：10-01 `0b1d42f5…`；10-12 `967c4172…` / `a1bf4a79…` / `0fac7986…`

### N-52 🔴 TG 的 `tg_category` 只当参考标签，不当过滤闸 〔C〕
- **现状**：TG（`tg_kol_feeds`）条目仍自带 `tg_category`（交易信号 / Meme打新 / 链上数据 / 叙事追踪 / 市场结构 / 宏观研判 / 项目研究 / 实盘跟踪；10-12 抽 10 条都在这 8 类内）。但分类不可靠：10-10 实测 15 条里 6 条不符、1 条有争议，情绪帖、邀请码、段子被标成「交易信号」「链上数据」；与 Jev 对照的系统准确率约 36%，主要错在每条都硬塞一个类目，没有「无合适类目」。服务端也没有按类目过滤的参数（10-09 探针传 `tg_category` 被拒：`unexpected additional properties ["tg_category"]`）。
- **怎么读**：`tg_category` 只作弱提示；保留或剔除必须叠加内容判断（零信息、邀请码、情绪帖）；不能只凭类目定保留名单或剔除名单。
- 历史：07-30 原记「用 `tg_category` 做结构过滤比按内容判断稳定、可复现：保留链上数据 / 市场结构 / 宏观研判，默认剔 Meme打新 / 实盘跟踪」，10-10 实测证伪。
- **依据**：07-30 首记；10-10 噪音扫描与 news 扫描 F 节；10-12 `be3c71c9…`

### N-68 news 的 research 源是公开媒体和独立 newsletter，不是券商研报 〔C·已文档化〕
- **现状**（10-12 复测）：`sources=["research"]` 可用、0 额度，返回 `source_quality:"research"` 的文章：有 Substack 类独立研究（taekim.substack、bepresearch、tmtbreakout），也混 247wallst、Zacks、GuruFocus、Motley Fool 等财经媒体，`source_name` 一律是 `"media"`。工具描述写明 research 源只覆盖 tradfi，结构化券商研报在 metrics。按代码搜索时噪音约 67%（晨报、标的只是客户）。正文按 `verbosity` 截断（standard 600 字、detail 2000 字），全文看原链接。
- **怎么读**：不当券商研报引用（券商研报卡走 `metrics` fundamentals 的 `research_reports`）；要独立研究就按 `source_url` 域名二次过滤，并逐条判相关。社交侧可补：`kol_info.categories` 含 `"research"` 且正文挂 substack 链接的帖。
- 历史：07-30 原记「全部条目 `provenance:"feeds"`、`sources=["research"]` 被 schema 拒、没有替代」，10-01 起已不成立（N-112②、N-125③）；`provenance` 字段 10-12 已不存在。
- **依据**：07-30 首记；10-10 `47fa4100…`；10-12 `a3cb12c5…` / `d70382f4…`

### N-70 news 返回字段：没有 `cluster_id`，`source_name` / `source_lang` 不能直接用 〔C〕
- **现状**（10-12 复测）：article 字段为 `title` / `content` / `content_truncated` / `published_ts` / `source_url` / `source_name` / `source_quality` / `source_lang` / `category`，social 另带 `kol_info`；没有 `cluster_id`，也已没有 `provenance`。正文是否截断看 `content_truncated`，不再「恒截断」。
- **①** `source_name` 一律是 `"media"`，媒体名要从 `source_url` 域名取（原第 444 行；10-12 5/5 仍是）。
- **②** `source_lang` 不可靠：日经、路透日文版被标成 `en`，英文推文被标成 `ko` / `la` / `sv` / `es`（系统准确率约 85%）；`source_lang="ja"` 在 1d、1w 窗口都返回 0 条 + `degraded`，不给原因（10-10，10-12 复现）。
- **怎么读**：多源去重按 `source_url` + 标题近似判重，没有服务端聚类 id；不用 `source_lang` 过滤或分组，按字符集（假名、谚文、CJK）自己判。
- **依据**：08-04 `a1a09a5c…`；10-12 `070bb07b…` / `56a6cdc7…` / `795e0dd3…`

### N-1 news 趋势模式可传 `asset_type="tradfi"` 〔C·已文档化〕
- **现状**（10-12 复测）：空 query 的趋势模式传 `asset_type="tradfi"` 可用（不带窗口返回 6 条），0 额度；带短窗口可能空返回，见 N-146③。
- **怎么读**：「news 不传 asset_type」只约束搜索模式（N-145），趋势模式照传。news 全部 0 额度见 N-112④。
- **依据**：07-22 首记；10-12 `596a763d…`

### N-25 `news(limit=N)` 是每个来源各 N 条，不是总数 〔C·已文档化〕
- **现状**（10-12 复测）：`limit=10` 返回 articles 10 + social 10，`total=20`。工具描述写明 `limit` 按独立预算计：articles N 条；social 里推特 N 条 + Telegram N 条，所以最多可能 3N；上限 50。也会不满：趋势模式 `limit=10` 只给 5 篇 articles（N-146⑤），`quick` 只回精确命中（10-12 `limit=10` 只回 7 条，N-101）。social 桶的美股 ticker 密度高于 articles 桶（07-27）。
- **怎么读**：体积按 2N~3N 估；抽 ticker 两个桶都要解析；不用 `total` 判覆盖。
- **依据**：07-27 首记；08-04 `a1a09a5c…`；10-12 `65a30d51…`

### N-26 news query 写法：陈述事实句优于情绪涨跌句 〔E〕
- **现状**（10-12 复测）：同为 7d，`"record quarterly revenue results"` 20 条里约 15 条与财报 / 营收相关，`"earnings surprise stock surges"` 约 6 条，混入 $ENA / $BTC / $HYPE 加密帖（人工判读）。相对排序稳定，绝对命中率波动大（07-23 13/20、07-27 8/20、10-12 约 15/20）。`beat` 一词会撞棒球比分、代币 $BEAT 和无关社会新闻。
- **怎么读**：用陈述业绩事实的句式，避开 surge / soar / jump 和 beat；命中率只能用来排序，不能设阈值。红线 5 的其余写法纪律（2–3 个核心名词；不写「影响 / 解读 / 分析 / impact」这类元词，否则可能 0 条；中英文不混搭）10-12 未单独复测；工具描述推荐英文 query。
- **依据**：07-23 / 07-27 首记；10-12 `9453dfb1…` / `1f74569a…`

### N-182 news / twitter / crypto 零碎（10-09 第三轮复跑） 〔A/B〕
- **①** news 媒体按相关度要 10 篇只回 4 篇、社交稿与媒体稿覆盖起点不同（10-09）：10-12 未复现，`"Atlassian"` media + relevance 回满 10 篇，最早到 04-13。
- **②** `tweets_by_ids` 对个别 ID 返回空壳、无警告；推文里 HYPE 的 cashtag 显示成 Solana 合约地址（10-09）。10-12 两个 ID 都返回完整内容，原空壳 ID 没记录，无法定点复测。
- **③** `user_tweets` 偶发超时，重试即成功；超时那次是否扣额度不稳定：10-09 第三轮一次疑似扣，第四轮两次未扣；10-12 没遇到超时，正常调用 2.4 秒、扣 1（合并原 N-186②）。
- **④** HYPE 不带 interval 查价格历史返回小时行（10-12 仍成立，且已没有 "Total records" 字段）。这是行情问题：日线根数不要按数据头算（N-185④），crypto 日 K 的写法见 N-178①；原对策「只认 Binance 日线数据头」与 N-185④ 矛盾，已删。
- **怎么读**：推文 ID 逐个核对是否空壳；超时按「可能扣额度」预估。
- **依据**：10-09 复跑记录；10-12 `021aa58c…` / `705dd060…` / `a31c8d3c…`

### N-186 news / twitter 零碎（10-09 第四轮复跑） 〔B〕
- **①**（10-12 已修）10-09 `news(query="Atlassian")` 与 `"TEAM Atlassian"` 返回完全相同的无关稿、无警告；10-12 两者各回 10 篇相关稿，8 篇重合。召回不中时仍按 N-35 记资料缺口。
- **②** `user_tweets` 超时是否扣额度：与 N-182③ 是同一件事，已并入 N-182③。
- **依据**：10-09 复跑记录；10-12 `021aa58c…` / `fd5e9e05…`

## twitter

### N-90 🔴 账号有四种状态，只查一个接口会误判 〔B〕
- **现状**：正常：两个接口都有数据。改名：`user_info` 返回 `{"data":null,"msg":"user not found"}`，`user_tweets` 走 id 映射照常返回新 handle 的时间线（`author.userName` 是新 handle，`author.id` 不变）。销号：`user_info` 同上，`user_tweets` 是 `code:0`、`msg:"success"`、`tweets:[]`。封号：`user_info` 返回 `msg:"success"`、`status:"success"`，但 `data` 是 `{"message":"User is suspended","unavailable":true,"unavailableReason":"Suspended"}`，`user_tweets` 为空。
- 10-12 复测封号态仍如此（ElonJet）；改名、销号是一次性样本，未复测。不存在的 handle：`user_info` 返回 `user not found`、`user_tweets` 为空、`from:` 搜索 0 条（合并原 N-189⑦，10-12 复现）。
- **怎么读**：判存活必须 `user_info` + `user_tweets` 交叉查；`user_tweets` 空数组不当「最近没发推」，一律回查 `user_info`；`user_info` 必须查 `data.unavailable`，只看 `msg` 或 `data != null` 都会把封号当正常；`user_tweets` 返回的 `author.userName` 与请求的 handle 不一致，说明 handle 已过期，按返回值回写库。
- **依据**：08-14 首记（改名 1 / 销号 3 / 封号 1）；10-12 `a9178dca…` / `97c8180c…`

### N-89 twitter search：时间窗按模式不同，垃圾多，额度独立 〔A〕
- **①** `time_range`：Top 模式完全不生效、无提示（10-12 `time_range="2d"` 返回 465–614 小时前的帖，还有约 1 年前的；`$NVDA` Top 10 条全是 10-02~10-11 的帖）。Latest 模式话题搜索基本生效（同日 2d 全部在 0.3 小时内），但按作者 `from:` 搜仍会越界（`from:followin_io_zh` + `1d`，10-12 最早一条 63.8 小时前，10-09 是 25.6 小时前）。合并原 N-189①。
- **②** 默认 `query_type` 是 Latest，首屏是营销号、抽奖帖、低粉帖（10-12 粉丝中位数 1,722、最低 39）；Top 质量较好（中位数 15.4 万），但也不干净。10-10：Latest 下 `$SOL` 15 条里 13 条、`AAPL` 15 条里 10 条是垃圾（meme 合约推广、钓鱼链接、荐股群、诈骗回复），Top 下 `$BTC` 40% 是抽奖帖；同样 4 个查询走 `news(sources=["twitter"])`，垃圾 0 条。
- **③**（10-12 已修）原记 Top 返回不带 `entities.symbols` ticker 标签；10-12 Top 20 条里 15 条带。
- **④** twitter 是独立额度池（10-12 上限 10000，原记 2500）；search 的翻页游标在 `meta.filters_applied`（见 N-93）。
- **怎么读**：时间过滤一律在返回后按 `createdAt` 客户端再滤；显式传 `query_type`，要质量用 Top，要时效用 Latest，两种都要客户端剔抽奖和诈骗；内容型需求优先用 `news(sources=["twitter"])`（账号池已筛过）。
- 历史：08-13 原记①「`time_range` 被静默无视」，10-09 改成「部分生效」，10-12 按模式拆开：对 Top 来说原记成立。
- **依据**：08-13 首记；10-10 `62c6cd21…`；10-12 `b55b1725…` / `17471040…` / `7e927f3d…`

### N-91 `user_tweets`：没有 `count`，默认 20 条，`limit` 只能截短 〔C·已文档化〕
- **①** 传 `count` 硬报错（`unexpected additional properties ["count"]`）。默认一页 20 条；`limit`（默认 20、最大 20）只在本地截短，不改上游页大小，截掉的记录翻页也找不回（工具描述原文）。`limit=5` 实测生效，返回约 5–6 条，并提示 "showing 5/20 fetched"（09-23、10-09、10-12）。合并原 N-189⑥。
- **②** 不带 `include_replies` 时 `isReply` 恒为 false（10-12 20/20），带上则是真值（N-172）。游标在 `results[0].next_cursor` / `results[0].has_next_page`；`has_next_page:true` 不保证下一页有数据，以空页为准（08-14）。
- **③** 20 条覆盖的时间窗差异极大：08-14 207 个账号中位 7.0 天，不到 1 天的 20 个，最短 5.6 小时；10-12 Kobeissi 20 条约 52 小时。
- **怎么读**：按比率下判定（转推率、含票率、发帖频率）前先算样本时间窗；窗口不到 24 小时不足以判账号形态，翻页补深再定（08-14 曾把只覆盖 16 小时的「转推 90%」判成账号退化）。
- **依据**：08-14 首记；09-23 `b4169dc3…`；10-12 `78b7f4e6…`

### N-99 `user_tweets` 单页载荷大，`verbosity` 几乎不省 〔A〕
- **现状**（10-12 复测）：Kobeissi 一页 20 条 70,072 字符，author 对象（约 1,400 字符）每条复制一份；`verbosity="concise"` 只少 7%（64,968），因为它只截正文、不压缩 author。带回复的页更大（N-172：约 12 万字符）。10-09 `limit=5` + concise 仍有 4.4 万字符。
- **怎么读**：瘦身靠小 `limit`，再由客户端丢掉 `author` 和 `quoted_tweet`；`limit` 只能截短、截掉的翻页找不回（N-91）。只想知道「某账号最近说了什么」，可改用 `news(sources=["twitter"], query="<handle>")`：本人发帖那一路干净，「提到他」那一路约 81% 无关，只留 `kol_info.name` 等于目标账号的行（10-10）；或用 `twitter search` + `from:<handle>`，时间窗见 N-89①。
- 历史：08-17 原记「twitter 没有 `verbosity`」「不能用 `sources` 缩范围（N-8）」，均已不成立（N-172、N-112②）。
- **依据**：08-17 首记（77,183 字符）；10-09 `b4646745…`；10-12 `78b7f4e6…` / `85f0b9b2…`

### N-172 twitter 的 `verbosity` 只截正文 〔C·已文档化〕
- **现状**（10-12 复测）：推文正文按 `verbosity` 截：concise 200 / standard 600（默认）/ detail 2000 字，嵌套推文正文同样截，截断时带 `content_truncated:true`；与条数（`limit`）无关，也不压缩 author（N-99）。`include_replies=true` 时 `isReply` 是真值（elonmusk 20 条里 11 条 `isReply:true`），这一页 120,588 字符（10-08 记 9~17 万）。
- **怎么读**：拉 KOL 推文要全文就传 `verbosity="detail"`；体积控制见 N-99，条数与 `limit` 见 N-91。
- **依据**：10-08 `cbf320c9…`；10-12 `dc52e047…`

### N-44 list 分页丢块：每页上游取回几十条，只显示 20 条 〔B〕
- **现状**（10-12 复测）：`list_timeline` 每页上游取回 49~88 条，只显示 20 条，返回带 `local_display_truncated`（"showing 20/82 fetched records"），其余无法经游标追回（合并原 N-189④）。这就是 07-30 记的「三页 60 条、墙钟 20.5 小时、真实覆盖仅约 30%，空洞正落在美东午盘 + 盘后」的成因。10-12 一页 20 条跨 2 小时 41 分。翻页游标在 `meta.filters_applied`，不在 `results[0]`。
- **怎么读**：别指望翻页凑「一天的量」，页越多丢越多；判 list 产能只用最新一页的连续头块，不用「全量条数 ÷ 全量跨度」；简报写「回看 X 小时」，不写「今日全量」。
- **依据**：07-30 首记；10-09 审计；10-12 `911fd2aa…` / `37a8d604…`

### N-43 `list_timeline` 与 `list_tweets` 各缺一部分 〔D〕
- **现状**（10-12 复测）：同一 list 重叠窗口里，`list_timeline` 11 条、`list_tweets` 20 条，共有 8 条；`list_timeline` 独有 1 条转推 + 2 条某成员原创（这个成员在 `list_tweets` 里没出现），`list_tweets` 独有 12 条，全是回复。大致是 timeline 收转推、list_tweets 收回复，但不稳定（07-30 对照组的 timeline 也有回复）。两个端点都不报错。
- **怎么读**：日常用 `list_timeline`；要完整样本就两个都拉，按 `id` 合并去重。
- **依据**：07-30 首记；10-12 `911fd2aa…` / `7d7a4e80…`

### N-42 list 不存在、私密、已删、真空，返回无法区分，且照扣额度 〔B〕
- **现状**（10-12 复测）：伪造的 `list_id` 返回 `results:[]`、`total:0`、`filters_applied:null`，没有报错，照扣 1 credit。
- **怎么读**：把 list 当数据源时，返回 0 条一律判失败，并提示「list_id 可能已私密 / 删除 / 写错」，不当「今天没人发推」；用别人的 list 尤其要紧，所有权变更不会有通知。
- 背景：N-42~N-46 来自 07-30「能不能给公开模板内置一个 Twitter list」的实测，结论是能读，但失败全是静默的（原第 122 行）。
- **依据**：07-30 首记；10-12 `89918922…`

### N-53 判转推用 `retweeted_tweet`；`tweets_by_ids` 只能看正文 〔C〕
- **①** `user_tweets` / `list_timeline` 的 `retweeted_tweet` 在非转推时是 `null`，转推时含被转原文和真实作者，比 `text` 前缀（`RT @`，还有无空格的 `RT@` 变体）稳（10-12 stacy_muur 20 条里 3 条转推，两个判据 3/3 重合）。
- **②** 转推带的是原推的时间和互动数：10-09 一条 14 小时前的旧帖被当成 2.2 小时前的新帖，不剔会污染时效和互动统计（原 N-189② 前半；10-12 那一页没有转推，未复测）。
- **③** `tweets_by_ids` 查纯转推返回 `type:"tweet"`、`isRetweet:false`、`isQuote:false`，没有 `retweeted_tweet`（10-12；10-09 曾标成引用推），只能靠正文开头的 `RT @` 识别（原 N-189② 后半）。
- **怎么读**：剔转推首选 `retweeted_tweet` 非空；没有该字段时（离线导出、`tweets_by_ids`）回退 text 前缀。不剔会把别人的官宣算成本人原创。
- **依据**：07-30 首记；10-12 `d28bca8b…` / `a28bb28a…`

### N-57 `tweet_replies`：含楼中楼；返回数少于 `replyCount` 多半是分页 〔C〕
- **①** 原记「根推自身混进 replies」10-12 两次都没复现（20 条全是 `isReply:true`）。
- **②** 混有楼中楼：`inReplyToId` 不等于根推，20 条里 3–4 条（合并原 N-189③）。
- **③** 返回数少于 `replyCount` 多半是没翻完，不是折叠：replyCount 110 时首页 20 条、`has_next_page:true`；分页字段在 `meta.filters_applied`。
- **④** 评论对象带 `likeCount` / `replyCount` / `viewCount` / `bookmarkCount` 和评论者 `author.followers`（20/20）。
- **怎么读**：一级评论按 `inReplyToId == 根推 id` 筛，顺手按 id 剔根推作防御；判「折叠降权」必须翻到 `has_next_page=false`；影响力加权用 `author.followers`。
- **依据**：07-30 首记；10-12 `914676d8…` / `2d35f758…`

### N-93 翻页游标的位置因 action 而异 〔A〕
- **现状**（10-12 复测）：`user_tweets` 在 `results[0].next_cursor` / `results[0].has_next_page`；`followings`、`search`、`list_timeline`、`tweet_replies` 在 `meta.filters_applied.next_cursor` / `has_next_page`（`followings` 的 `results` 直接是用户对象数组）。按前一种位置去后几种里找，会取到 `None`，误判成只有一页。`followings` 返回自带 `description` / `followers_count` / `statuses_count` / `id`，做候选前置筛选够用。
- **怎么读**：每换一个 action 重新确认游标位置；稳妥写法是两处都探，取非空的那个。
- **依据**：08-14 首记；10-12 `78b7f4e6…` / `80028139…` / `6b9cd4d7…`

### N-45 同一工具不同 action 的字段集不同 〔C〕
- **现状**（10-12 复测）：`list_timeline` 和 `list_tweets` 都没有 `inReplyToUserId` / `inReplyToUsername` / `conversationId`，判回复只能用 `isReply` / `inReplyToId`；`user_tweets` 五个字段都有，非回复时是显式 `null` 而不是缺键。`conversationId` 在非回复时等于自身 id，不能用它判回复。`include_replies` 只影响筛选，不影响字段结构。
- **怎么读**：不把一个 action 的字段观察套到另一个 action；信封层差异见 N-93，外层结构见 N-56。
- **依据**：07-30 首记；10-12 `19175d05…`

### N-94 推文内嵌的 author 对象 `description` 恒为空 〔A〕
- **现状**（10-12 复测）：不只嵌套层，推文里所有内嵌 author（顶层和 `quoted_tweet` 都算）的 `description` 都是 `""`，键在值空（search 返回的 40 个顶层 + 4 个嵌套 author 全空）。`user_tweets` 顶层作者的 bio 在 `author.profile_bio.description`；`followings` 20 个里 19 个有 `description`。
- **怎么读**：解析内嵌 author 只信 `userName` / `followers` / `id`。`if author.get('description')` 永远走 else，`'description' in author` 永远为真，两种判法都不对。要 bio：`user_tweets` 读 `profile_bio.description`，其他场景走 `user_info`（1 额度）或用 `followings` 的返回建索引。
- 历史：08-14 原记只有嵌套 `quoted_tweet.author` 为空（356/356），10-12 扩大到所有内嵌 author。
- **依据**：08-14 首记；10-12 `78b7f4e6…` / `17471040…` / `80028139…`

### N-46 `quoted_tweet` 第三层是空壳；`entities.symbols` 不全 〔B〕
- **①** `quoted_tweet` 三层嵌套，第三层只剩空壳（`author:{}`、`text:""`；10-12 有一条连 `id` 都是空串；8 条引用推里 4 条嵌到第三层）。
- **②** 同一条推会在同一页里既是顶层 item，又是别人的 `quoted_tweet`（07-30；10-12 样本里没出现）。
- **③** `entities.symbols` 不可靠：一条正文提了近 10 个代币，`symbols` 只列 1 个（07-30；10-12 未测）。
- **④** 正文里出现 `cash-cat:native` / `xyz:SP500` / `xyz:MU` 这类冒号命名的资产标识，和 `$Sundog` 一类正常 cashtag 混在同一条推里；无法判定是 MCP 侧替换的还是原推本来就这么写（Hyperliquid 股票永续确实用 `xyz:` 前缀）。10-12 40 条 list 推文里没出现，无法复测（原第 132–135 行）。
- **怎么读**：解析 list 返回按 `id` 去重；第三层嵌套直接丢；提取标的不只靠 `entities.symbols`，用正文正则兜底，并兼容 `xyz:` 这类冒号写法（普通 `$TICKER` 正则会漏）。
- **依据**：07-30 首记；10-12 `911fd2aa…` / `7d7a4e80…`

### N-92 嵌套推文带完整 author，递归归集会把老推算进时间线 〔E〕
- **现状**：`user_tweets` 顶层 `tweets` 之外，`quoted_tweet`、转推原文等嵌套层也带完整 `author`。递归收集「author == 目标账号」的推文，会把该账号多年前被引用的老推当成当前条目：08-14 样本跨度从 7 天膨胀到 5,292 天，频率判据被打歪。10-12 结构仍在（search 的 `quoted_tweet` 带完整 author），跨度膨胀这一页没复现。
- **怎么读**：只取顶层 `data.tweets` 的直接元素，不递归；必须递归时按嵌套深度分层标记；归属校验用「占多数的 author」，不用「出现过的 author」。N-46 的按 id 去重解决不了这个问题。
- **依据**：08-14 首记；10-12 `17471040…`

### N-55 `user_tweets` 有 `viewCount` 和全套回复字段，ER 可算 〔E〕
- **现状**（10-12 复测）：每条带整数 `viewCount`，以及 `likeCount` / `retweetCount` / `replyCount` / `quoteCount` / `bookmarkCount` 和 `isReply` / `inReplyToId` / `inReplyToUserId` / `inReplyToUsername`；ER =（like + retweet + reply）/ viewCount，逐条可算（07-30 stacy_muur 原推约 1.3–1.6%）。
- **怎么读**：三堆拆分：转推 = `retweeted_tweet` 非空；回复 = `isReply` 为 true（或 `inReplyToId` 非空）；其余为原推。判「回复自己」用 `inReplyToUserId == author.id`。算作者回复率时，`conversationId` 指向线程根推，根推常在拉取窗口外（07-30 样本 22 个对外回复只有 9 个根推在窗内），分母要单独回捞。字段是 camelCase，见 N-56。
- 历史：原写「reply = `inReplyToUserId` 非空」；07-30 曾测得该字段在约 31% 的真回复上为 null（N-58，10-12 已修、已归档），判据统一改用 `isReply`。
- **依据**：07-30 首记；10-12 `5d704ba8…` / `d28bca8b…`

### N-56 MCP 推文字段命名与 Twitter API v2 不同 〔E〕
- **现状**（10-12 复测）：MCP 用顶层 camelCase（`viewCount` / `likeCount` / `retweetCount`），外层有两种：`user_tweets` 是 `results[0].data.tweets[]`，`tweet_replies` / `list_timeline` 的 `results` 直接是推文数组。Twitter API v2 是 `public_metrics.{impression_count, like_count}` 嵌套 + `data[]` 外层。脚本只认 v2 时，喂 MCP 数据会全读成 0，静默降级成按绝对互动数排序。
- **怎么读**：自写 jq / 脚本消费 MCP 推文时，认 `viewCount` 不认 `impression_count`，并识别不同外层。`Twitter Workflow/skills/performance-review/scripts/tweet_analyzer.py` 的 `load_api_json` 已兼容。
- **依据**：07-30 首记；10-12 `914676d8…`

### N-189 twitter 零碎（10-09 Twitter Workflow 审计） 〔A/B/C〕
- **①** `search` 的 `time_range` 不严格：已按模式拆开写进 N-89①（Top 完全不生效，Latest 话题搜索基本生效，`from:` 会越界）。
- **②** `user_tweets` 的转推带原推时间和互动数；`tweets_by_ids` 认不出纯转推：见 N-53②③（10-12 不再标成引用推，但仍是 `isRetweet:false`、没有原推字段）。
- **③** `tweet_replies` 首页混入原推：10-12 未复现；楼中楼仍在，见 N-57。
- **④** `list_timeline` 每页上游取回 49~88 条只显示 20 条，其余不可追回；游标在 `meta.filters_applied`：见 N-44（10-12 复现）。
- **⑤** 新闻热榜条目的时间是刷新时间，不是首报时间：见 N-146①（10-12 RSR 例）。
- **⑥** `twitter` 有 `limit`（最大 20，只能截短，截掉的翻页找不回）：已实测生效（09-23 `b4169dc3…`、10-09 `b4646745…`），见 N-91。
- **⑦** 不存在的 handle：`user_info` 返回 `user not found`、`user_tweets` 为空、`from:` 搜索 0 条，见 N-90（10-12 复现）。
- **⑧**（新增，09-16 实测）`twitter` 的 `trends` 全球榜 30 条全是零食、偶像、明星一类，零金融相关，还占 twitter 额度；Q4 已决定从描述里摘除。不调用，热点从 news 趋势模式取（N-146）。证据 `e9a16eba…`。
- **依据**：10-09 审计记录；10-12 `7e927f3d…` / `a28bb28a…` / `2d35f758…`

**补充**
- （原第 208–209 行，〔E〕，非 MCP 行为）评论区运营的设计教训：按 reply/like 比设的靶标闸，只能抓「被围攻的靶标推」，抓不到评论区里多账号同模板刷无关项目的协同刷单簇（这些账号自身 reply/like 为 0），后者只能按内容模式判。

## subscription（关注列表）

### N-190 未读数是累计条数，不是新帖数 〔B〕
- **现状**：`subscription(action="list")` 的未读数是累计条数（BTC 365→472、ETH 92→111），没有决策意义；`latest_ts` 与 kol_call 最新帖一致，可以用。`items` 在 Claude Code 里同样丢类型（N-105③）；`set` 是写操作，10-12 未测。
- **怎么读**：未读数不对外展示，只用 `latest_ts` 判断有没有新帖。
- **依据**：09-16 `c2f5b560…`；10-10 `a2be3448…`

## 运行环境与客户端

### N-50 会话初始化报错多是并发争用，不是参数类型错 〔E〕
- **现状**：07-30 一条消息发 4 个同形态 metrics 调用，挂了 2 个（`MCP error 0: ... invalid during session initialization`），另 2 个成功，重试即成功。10-12 没能复现：标准库客户端同会话 4 并发、4 个新会话同时初始化、跳过 `notifications/initialized`、Claude Code 同一条消息 4 路并行，共 16/16 成功（`212b2dfb…` / `a1a65146…`）；服务端同会话 6 路并发 4.3 秒全部返回（`596a763d…`）。
- **怎么读**：同批同形态有成功的，就排除类型错，是客户端会话初始化时的并发争用；失败项减并发、下批重试。原红线 2「单批 ≤4 路」是客户端传输层的经验值，不是服务端上限，≤4 也不保证不出错。
- **依据**：07-30 首记；10-12 `212b2dfb…` / `596a763d…`。

### N-49 jq 用 `%z` 解析 `createdAt` 会随本机时区偏移 〔E〕
- **现状**（10-12 复测，jq 1.7.1）：同一串 `"Fri Jul 17 06:30:30 +0000 2026"` 用 `strptime("…%z…") | mktime`：UTC 下正确（1784269830），Asia/Shanghai 偏 +28800s，America/New_York（7 月夏令时 −4）偏 −14400s。偏移小于 8 小时不会让 age 变负，「age 为负」守卫抓不到。
- **怎么读**：去掉 `%z`：`sub(" \\+0000 ";" ") | strptime("%a %b %d %H:%M:%S %Y") | mktime`（三时区结果一致）；或用正则重组 ISO 串后 `fromdateiso8601`。
- **依据**：07-30 首记；10-12 B 段复测。历史：原写「−5 偏 −14400s」，时区标注有误。

**补充**
- **`STATE_DIR` 用绝对路径**（旧第 245 行）：相对路径（`./state`）会跟着会话启动目录漂，和放在 `/tmp` 一样会静默丢掉跨天资产。开工检查除了「不在 `/tmp`」，还要求「是绝对路径」。（运行环境纪律，非可测。）
- **`tools/sweep-check.sh` 门禁**（旧第 401 行）：规则以脚本头注释为准，现有 (a)~(g)：10-02 起不再拦数组写法，改拦 query 串里的 `*USD` 商品代码与英文指标名；10-03 补 signal 不带 `categories`、`beat_miss` / `WTREGEN`；10-08 补日历与 news 写法。10-12 实测 (a)~(d) 拦的写法仍会取错数据。(f) 的提示语 10-12 已补「重点标的用 next_earnings_estimate 核对」（两种日历写法都漏大票，见 N-22）。

## 第三方数据源（非 Followin MCP，迁出说明）

> 这里记的是 DeFiLlama、FedWatch、SPDR、ETF 流向站点等外部数据源，不是 Followin MCP 的行为。取数规则已写进 `Base Skill/04_btc-macro-dashboard.md` 与 `Base Skill/05_gold-macro-dashboard.md`，caveats 只留指针。N-174 里属于 MCP 的分点改为指向对应条目。

### N-173 外部数据源的缺值与口径（迁 04 / 05） 〔E〕
- **现状**（10-12 curl 直查）：DeFiLlama 稳定币 USDD / OUSD 的 `circulatingPrevMonth` 为空，一个 USDX 为 0；全表 430 个币中 100 个缺上月值，且收录了代币化国债基金 BUIDL。SPDR 存档 API `https://api.spdrgoldshares.com/api/v1/historical-archive?product=gld&exchange=NYSE` 返回 200 + xlsx（541KB）；官网 GLD CSV 已 301。未复测：tftc 的 ETF 日度合计取自 SoSoValue、bitbo 晚一天且缺行；thevaultreport 上海金溢价 10-08 实测滞后约 9 天。
- **应迁到**：稳定币与 BTC ETF 流向 → `Base Skill/04_btc-macro-dashboard.md`（⑫ 两期配对、剔除国债基金；⑪ 两家对照，已写入）；GLD 持仓与上海金溢价 → `Base Skill/05_gold-macro-dashboard.md`（⑨ 取数、⑩ 保鲜期，已写入）。
- **依据**：10-08 首记（04 / 05 Skill 修订）；10-12 复核 E 段。

### N-174 10-08 复跑零碎：①②③ 是外部源，④~⑨ 指向 MCP 条目 〔E〕
- **①**（外部，迁 04 ⑫）DeFiLlama 部分稳定币 `price` 为 null（M、HUSD、Avalon USDa，10-12 仍成立）；剔除国债基金时的价格条件对这些币不适用。
- **②**（外部，迁 04 ③ / 05 ③）FedWatch 二手来源的「一周前值」差异极大（同为 10-01 前后，CME 来源 28%、Yahoo 未注明来源 50.9%），检索还会把 09-23 的旧值当成「10 月初」返回。多来源冲突取更接近 0 的档，各来源原始值写进明细。
- **③**（外部，迁 05 ⑨）SPDR GLD 存档是 xlsx：数据在第二个工作表、`Tonnes of Gold` 列，假日行各列都是文字 `US Holiday`；WebFetch 解析不了，要下载后用脚本读（同 N-173）。
- **④**（MCP，见 N-158）盘中 `market.history` 当天那行的 close 与同一次返回的快照价不一致（10-08 ACN 199.26 vs 195.51）；10-12 不在盘中，未复测。
- **⑤**（MCP，见 N-147）`analyst_grades` 传 `limit=21` 报「上限 20」，实际却回 21 行（10-12 复现 `d3090b57…`）。
- **⑥**（MCP，暂无对应条目）快照 `volume` 出现小数、`yearHigh` 有未按合股调整的值（10-08 RPGL 现价 40.8、yearHigh 66432）；10-12 1 小时线 volume 小数复现（7385812.14，`0810f8a3…`）。
- **⑦**（MCP，方向值清单见 N-39②）`mention_direction` 出现 `neutral`（10-12 neutral 3 / negative 2，`edd4b9b4…`）。
- **⑧**（MCP，暂无对应条目）tradfi 趋势榜混进 A 股、韩股新闻；10-12 取到的 tradfi 趋势榜为 0 条，未复测。
- **⑨**（MCP，另见 N-167）律所「集体诉讼调查」稿大量出现在个股新闻里，不计入报道数（Premarket Tracker、c6 引用本分点）。
- **依据**：10-08 复跑（04 / 05 / 03 / c1 / r1）；10-12 复核 E 段。

---

# 三、归档

> 已修复或作废的条目。编号永久保留，回归自查时按条目里的证据复测。旧规避动作已撤销的，Skill 里也要同步撤掉。

## 2026-10-12 全量复核确认已修

### N-8 数组参数（`keywords` / `categories` / `sources` / `items`）被 schema 拒 ✅ 10-12 确认已修
- **原问题**：07-20 起这四个参数在工具 schema 里是无类型空对象 `{}`，守 schema 的客户端只能序列化成字符串，服务端却要求数组，于是全域报错（`want one of "null, array"`）；服务端 `no_match` 建议的数组写法照抄也报错（原 N-71）；`subscription.set` 从守 schema 的客户端整个调不通。09-07 起生产端已接受数组，但 schema 仍无类型。
- **现在**：生产端 `tools/list` 里 metrics / signal 的 `keywords`、`categories`，news 的 `sources`，subscription 的 `items` 都声明为 `"type":["null","array"]` 并带 `items`；本轮 100+ 次数组调用无一被拒。现行写法见 N-105。残留：Claude Code 加载 schema 时丢掉联合类型，会话里这四个字段仍显示无 `type`（见 N-105 ③）。原规避「统一走 query 串」现在反而有害：query 串会静默丢 `*USD` 代码和部分美股（N-23 (b) / N-106）。
- **证据**：原 `28a68c92…`（08-04）；10-12 生产 `tools/list`（复核 A / D 段）、`65799d74…`。

### N-71 服务端 `no_match` 提示里的建议写法照做必报错 ✅ 10-12 确认已修
- **原问题**：08-04 空返回的 `no_match` warning 推荐 `categories=[kol_call] keywords=[BTC]`，照抄被 schema 拒（`28a68c92…`）；08-04 已并入 N-8。
- **现在**：数组写法被接受，照建议写 `categories:["kol_call"], keywords:["NVDA"]` 正常返回。注意：建议里的别名（`keywords=[gold|oil|silver…]`）语义上会掉进 GOLD→Gold.com、OIL→2023 年 ETN 旧价的坑（`00a7d331…`），已记入 N-159 ③。
- **证据**：10-12 `65799d74…`（复核 C 段）。

### N-104 衍生品四叶只在 dev、生产端未部署 ✅ 10-12 确认已修
- **原问题**：09-07 记 `market-derivatives` 的费率、OI、永续合约池、费率板只在 `followdao-test` 可用；生产端按标的只返回永续 K 线，无实体的榜单 `no_match`。应对是「验收先测 dev」。
- **现在**：生产端四叶齐全。`keywords=["BTC"]` + `query="open interest history"` 返回 OI 日点；`current perpetual funding rates` 返回费率板（可翻页）；`Binance USDT perpetual universe` 按 quoteVolume 排、带游标；原应对②的 query 串写法同时返回 `funding_rate` 与 `open_interest`。09-16 报告已实测上线（GAP C1），caveats 一直没改。「先测 dev」作废；费率板「按绝对值排、小币霸榜、无分位」的读法保留在 crypto 小节的「补充」。
- **证据**：09-16 `58acd4fb…` / `c0058a91…`；10-12 `43bea894…` / `fd938d0d…` / `b961c17b…` / `03571b4b…`

### N-127 技术指标 `limit` 不裁剪观测值，响应 9.5 万字符 ✅ 10-12 确认已修
- **原问题**：10-01 crypto `keywords=["BTC","SOL"]` 技术指标 `limit=1` 仍返回约 30 天观测值，共 9.5 万字符。
- **现在**：`limit` 截每个指标的观测数（10-08 N-169 首见，10-09 探针 P15 通过）。10-12 `query="技术指标"`、`limit=1` 时每个指标 1 个观测，整个响应 1.5 万字符。按指标名写 query 时仍会附约 4 万字符小时价，见 N-169。
- **证据**：10-01 `456c87c2…`；10-12 `5b1ae7ce…`

### B-31 FRED 批量查询静默丢条目 ✅ 10-12 确认已修
- **原问题**：07 月记 FRED 批量 keywords 会静默丢条目（如 BAMLH0A0HYM2 被丢），应对是每个 series 单独调用（红线 4）。
- **现在**：`keywords` 数组 + `categories=["macro"]` 一批 5 个都返回；查不到的那个（CPIMEDSL）给 info 级 `kw_not_canonical`，不再静默。别名展开挤名额是另一回事，见 N-107。回滚动作「恢复批量（省调用数）」可以执行。
- **证据**：10-01 `f9806f93…`；10-12 `41caec8e…` / `8e33d7e7…` / `7b8c286f…`

### 旧顶部表第 74 行（无编号）经济日历 query 带「本周」触发回看 ✅ 10-12 确认已修
- **原问题**：06-12 实测 query 里的「本周」被解析成回看 7 天，返回已发布的历史而不是前瞻日历（红线 10 末句、顶部表第 74 行）。
- **现在**：`query="本周 economic calendar"` 返回 10-12~10-19，含 10-14 的 CPI；工具描述写明 "the server does not infer a window from query text"。时间窗只用 `time_range` / `date_from` / `date_to` 表达。
- **证据**：10-12 `28d4dc14…`

### N-28 `_meta.freshness` 是按来源写死的常量，不能判新鲜度 ✅ 10-12 确认已修
- **原问题**：`_meta.freshness` 按 source 写死，不是按记录算的：transcript 先恒为 `q-1`、08-14 换成 `stable`；analyst_estimates / enterprise_values / key_metrics_ttm / ratios_ttm 恒 `q-1`；consensus_price / analyst_grades / dcf 恒 `realtime`。写死取值做匹配的下游规则会失效。
- **现在**：10-12 逐字稿、全面分析、核心集合、5 票批量、评级同行 DCF 五类返回都没有 `_meta`，也没有 `freshness` 字段；逐字稿行带 `date` / `fiscal_year` / `fiscal_quarter` / `period`。工具描述仍写「Transcript rows carry … stable freshness」，与返回不符，可提给 dev 删掉这半句。
- **保留的读法**：逐字稿季度看 `transcript[0].date` / `fiscal_year` / `fiscal_quarter`（N-34）。
- **证据**：10-12 `e7715754…` `a6a533a6…` `50d2dac5…` `000dba41…` `18d44e16…`；历史 08-14 `205f59be…` `3f31b92f…` `edf24219…`

### （旧文件第 71 行，无编号）「全面分析」缺 `stock_peers` ✅ 10-12 确认已修
- **原问题**：comprehensive 返回 14 块唯独缺 stock_peers，输出里「同行」部分只能标数据不可用。
- **现在**：`query="分析师评级 同行 DCF"` 返回 `stock_peers`（NVDA 10 家，每行带 `peer_symbol`），写法见 N-109④。注意「全面分析」本身现在只返 5 块（N-109②）；同行名单质量见 N-134⑤，Q4 已定从工具描述摘除同业榜。
- **证据**：10-01 `af3c11ec…`；10-12 `18d44e16…` `4c58bb11…`

### N-33② 同季确认用 gap 判据（旧文件第 301 行）✅ 10-12 确认已修
- **原问题**：旧字段（现已不存在）`beat_miss.date`（公布日）与 `latest_quarter.date`（季末日）天然不等，二者的季度对齐关系也不固定（07-29 F 落后两季、STX 落后一季、V 领先一季）。朴素比日期会把每个正常样本判成「不同季」，作废 N-29 的口径检测；当时规定用 `gap = 公布日 − 季末日 < 90 天` 判同季。
- **现在**：服务端按 `fiscal_quarters[].fiscal_period` 成组（工具描述已写），同一元素里的 `earnings_surprise` 和 `financial_statement` 就是同一季：INTC 2026-Q2 内 report_date 07-23、period_end 06-27；F / STX / V 已对齐。配对失败时 surprise 单独成一个元素、`fiscal_period:null`（JPM、HUBG），按 N-149② 处理，不再算 gap。
- **读法变化**：「同季」= 同一元素且 `fiscal_period` 不为 null。N-29、N-33①、N-34 正文和 r1 闸 3 已同步（10-12）。
- **证据**：10-12 `3ec8ea27…`（INTC 成组）/ `000dba41…`（F / STX / V）/ `a051bcb7…`（JPM / HUBG 配对失败）

### N-140 研报库入库停滞 ✅ 10-12 确认已修
- 原问题：最新 `report_date` 停在 09-28（批次后缀 `__20260929T095307`），`time_range="7d"`（09-28→10-05）只有 6 篇入榜、Top 10 全是 UBS 同一批；`date_from=09-29` 起为 0；等长上一周有 140 篇。`time_scope`、`status` 全部正常，没有任何字段提示数据不新鲜。
- 现在：10-08 回补批（`__20261008T105153`）补进 09-28~10-07；10-12 7d 有 132 篇、`date_from=10-08` 起 58 篇、榜面最新 `latest_report_date` 为 10-10、Top 10 有 7–11 家机构。
- 仍有效的读法已移到正文：返回里仍无新鲜度提示，样本闸保留（N-164①）；回补会事后改写历史窗口（N-164②）。
- 证据：10-05 `b93b3e05…` / `960fdf70…` / `62a90729…` / `2e62856e…`；10-12 `f40a4669…` / `ac21b0cb…`

### N-4 不带 `categories` 自动展开四类 ✅ 10-12 确认已修（能力被撤销，不是修好）
- **原问题**（07-22）：`signal` 不带 `categories` 时自动展开全部四类且只计 1 额度，曾被当作省额度写法（07-24 复核时只回三类）。
- **现在的行为**：这项能力被撤销了。不带 `categories` 返回 `results:{}` + `no_match`，**照扣 1 额度**；显式列出多类，一次调用仍只计 1 额度。所以旧写法今天的结果是「空返回 + 扣费」，不能理解成「修好了」。现行写法见 N-113（必须传 categories）、N-118（多类合并不带窗口）。原条后半句「kol_call tradfi 聚合可用（`top_calls` 多空计数）」仍成立，读法受 N-88 / N-100 约束。
- **证据**：10-01 `21c31e47…`；10-12 `a25456fb…`（keywords=NVDA、不带 categories）/ `1b0460b4…`（query=NVDA）

### N-6 单票内部人传窗口仍返回多年前的旧记录 ✅ 10-12 确认已修（只验证了公司内部人行）
- **原问题**（07-22）：insider / congress 行无视 `time_range`，传 7d 返回 2020 年的记录。
- **现在的行为**：NVDA 单类内部人 + `7d` 只回 1 行（10-07 交易、10-09 申报），`status:"ok"`。**只验证了公司内部人行，议员行没有测。**
- **客户端写法不撤**：c4 / c6 / r1 引用本条的「不传 `time_range`、客户端按 `transactionDate` 过滤」继续有效——多类合并时带窗口会让 insider 整类消失（N-118），议员行的窗口行为也没验证过。
- **证据**：10-12 `c04d9a22…`

### N-59f tradfi 取价必带整套 CORE fundamentals ✅ 10-12 确认已修
- **原问题**（07-30）：`metrics` 取 tradfi 价时必然附带整套 CORE fundamentals（`default_fanout_fallback`），把 query 改成 "quote snapshot"、加 `verbosity="concise"` 都去不掉。
- **现在**：原写法（query 串、不传 `categories`）与数组写法（均带行情意图 query）都只返 `market.snapshot`，没有 fundamentals；不写 query 时仍会带 info 级 `default_fanout_fallback`（N-21②），fanout 只在 query 没有可识别主题时真正发生。
- **证据**：10-12 `c648f3ba…` / `0b0b89af…`；对照 `a66a6c2a…`（"token unlock schedule"）。
- **作废的旧读法**：原应对①「signal 与 metrics 一律走 query 自由文本路由」与现行工具描述（`keywords` 是实体字段，点名标的时必填）冲突，作废；「数组入参被拒」已过时（随 N-8 处理）。

### N-59l rollup 把 `entry_price` 当名义金额加总 ✅ 10-12 确认已修
- **原问题**（08-01）：`notional_value_usd` 为 null、而该行有 `entry_price` 时，rollup 把 `entry_price` 计入名义（SNDK 组手算与 rollup 差 1,222.04，恰为 T1 该仓的开仓价）。
- **现在**：触发条件 10-12 出现两处（ETH、SKHYNIX 各一条无名义、有开仓价的空单）：ETH 组 gross 1,248,797 与逐仓手算一致，SKHYNIX 组 gross 为 0，均未污染。工具描述明写 "entry_price is never used as notional"。10-08 也没复现。
- **证据**：08-01 `66880966…`；10-08 `3d42b288…`；10-12 `33c1dd4f…` / `2ef0028a…`

### N-58 `user_tweets` 真回复的 `inReplyToUserId` / `inReplyToUsername` 约 31% 为 null ✅ 10-12 确认已修
- 原问题：07-30 dotey 42 条真回复里 13 条这两个字段为 null（`isReply=true`、`inReplyToId` 有值、正文以 `@handle` 开头），按 `inReplyToUserId` 非空判回复会漏约三分之一，对外互动对象也会漏。
- 现在的行为：10-12 dotey 两页 40 条，其中 22 条 `isReply:true`，两字段为空 0/22；`author.id` 每条都有。
- 证据：`5d704ba8…` / `8ae33832…`。读法遗产：判回复统一用 `isReply`、作者回复率分母要回捞窗口外根推，两条已并入 N-55；`Twitter Workflow/skills/performance-review/scripts/tweet_analyzer.py` 第 88 行注释仍引用本条，无需改动。

### （无编号 · 原顶部状态表第 70 行）news 传 `asset_type` 返回 0 条 ✅ 10-12 确认已修
- 原问题：「news() 传 asset_type 返 0 results（is_tradfi 几乎全 false），0 篇不报错」，规避是 news 一律不传 asset_type（红线 1 的例外）。
- 现在的行为：10-01 起已不返回 0 条（N-112①）；10-12 `"Micron MU"` 带 tradfi 7d 返回 10+10。
- 证据：`65a30d51…`。回滚注意：表上写的回滚动作「各 Skill news 调用恢复 asset_type 过滤」**不要执行**——搜索模式传 tradfi 会丢召回，仍然不传（N-145）；趋势模式可传（N-1）。

## 2026-08-12 销案批 · 研报通道（N-78~N-84、N-65）

> 立单 2026-08-07（原编号 N-70~N-77，撞号后改为 N-78~N-85；归档的是 N-78~N-84，N-85 定为不修、留在正文），2026-08-12 复测全部修复，**2026-10-12 回查均无回归**。这批的旧规避动作已作废，继续套用会降低产出质量。
> 这批修法值得以后提工单时引用：N-79 用**改名**消除歧义；N-84 **归一字段、原值另存**；N-65 补 `truncated` 标志，**截断如实告知**。

### N-78 解析不了的代码静默退回全市场榜单 ✅
- 现在：keywords 写法下返回空结果加 `research_reports[0].warnings:["no_research_reports"]`；不带代码的榜单查询带 info 级 `ticker_unresolved`。10-12 回查 `a8f61a88…`。

### N-79 mention 层目标价是报告主体的价 ✅
- 现在：拆成 `matched_asset_target_price`（本标的，无则显式 null）和 `report_subject_target_price`（报告主体）。10-12 回查花旗 AMD 卡 matched = USD 800（`321003c3…`）。

### N-80 `dominant:"mixed"` 与 `counts.mixed` 撞名 ✅
- 现在：字段为 `mention_impact.dominant` / `mention_impact.counts`，平局值是 `"tie"`。10-12 回查未见冲突。

### N-81 limit 无翻页 ✅
- 现在：`meta.pagination.fundamentals.research_reports{returned, has_more, next_cursor}`，可翻页枚举（`5ff7885f…`）。

### N-82 `with_numeric_target` 与 `with_text_target` 假分列 ✅
- 现在：合并为 `target_price_coverage.with_target_price`。

### N-83 同一代码跨窗口返回不同公司名 ✅
- 现在：7d 与 30d 榜逐条一致（10-12 回查）。按代码聚合的旧规避可保留，成本为零。

### N-84 币种写法打架（`NT$` vs `TWD`） ✅
- 现在：`currency` 归一为 ISO 码，原写法留在 `text`。但 `revision_summary.by_name[].new_target_price` 不带币种，非美元标的按挂牌地判断（10-12 `321003c3…`）。

### N-65 `detail.affected_names` 有计数没内容 ✅
- 现在：返回 `{items:[{name, ticker, direction, context_snippet, rating?}], total, truncated}`，截断如实标注；detail 下 items 最多 5 条（10-12 BofA 一篇 total 137）。

## 更早的销案与作废

### N-2 「市场级财报日历可用」 ❌ 作废
- 原记载：按 query + date_from/to 取市场级财报日历可用。07-27 推翻：服务端按日期加代码排序再截断，只能拿到极小的字母序前段。现行结论见 N-22（财报日历主条）。

### N-11 指数可用、`^DXY` / `CLUSD` / `NGUSD` 是 402 禁调 ✅ 结案
- 07-27 结案为 `no_match`；10-12 起 `CLUSD` / `BZUSD` 走数组可直接取日线（`cbeb18a8…`）。现行结论见 N-106（商品代码）与 N-121（`^DXY` 被丢）。

### N-31 7 个 v2 Skill 的 keywords 数组写法失效 ✅ 已反转
- 原记载（07-27）：按 N-8 数组被拒，示例改成 query 串。10-01 起 N-105 反转：现行写法是 `keywords=[...]` + `query=意图`；query 串反而会静默丢代码（N-106）。

### N-61 研报剔除桶 12 天不变 ✅
- 08-04 销案：桶随窗口过滤，不是管线停更。10-12 回查：7d 与 30d 计数不同。桶名已改为 `report_deep.outer.deep_extract` / `report_title_only.outer.title_only` / `report_title_only.registry_pending.registry_candidate`；累计榜里另有两个历史桶冻结在 70 / 12，是不再计数，不代表停更（见研报小节补充）。

### N-37 研报榜 `time_range` 无效 ✅（含 N-37a、N-37b）
- 07-29 记：三档窗口返回逐字相同，是全量累计榜。08-03 修复：五档窗口各不相同，新增 `time_scope` / `date_from` / `date_to` / `window_granularity`。10-12 回查 7d 132 篇、30d 562 篇。
- **N-37a**（随 N-37 销案）：榜面数字单调增长的跨日佐证。现在榜单随窗口变化，可以跨期比较，但入榜量仍会飘，对外不写死数字。
- **N-37b**（随 N-37 销案）：传 `time_range` 曾把 status 降成 partial，warning 来自宏观日历的模糊匹配腿。10-12 回查 30d 榜 `status:"ok"`，无此警告。

---

# 附表 A：中文指标名 → FRED series_id

> 用法：`metrics(keywords=["<series_id>", …最多 5 个], categories=["macro"], asset_type="tradfi", limit=N)`（N-105、N-107）。单个序列也可以写 `query="<series_id>"`，query 里只放代码，不写中文。
> UNRATE / PAYEMS / RSAFS / ICSA 会展开别名占名额，不要和别的序列放同一批。表里查不到再用 query 兜底，并人工核对命中的序列。
> 2026-10-12 抽测 MORTGAGE30US / WDTGAL / BAMLH0A0HYM2 / PCEPILFE / T10Y2Y 一批 5 个全部命中（`7b8c286f…`）。

| 用户可能说 | series_id | 备注 |
|---|---|---|
| CPI / 通胀 / 消费者价格指数 | `CPIAUCSL` | |
| 核心 CPI / Core CPI | `CPILFESL` | |
| PCE / 个人消费支出物价 | `PCEPILFE` | 指数（2017=100），不是百分比 |
| 失业率 / Unemployment | `UNRATE` | 会展开别名，单独一批 |
| 非农 / NFP / 就业人数 | `PAYEMS` | 会展开别名，单独一批 |
| 联邦基金利率 / Fed Funds | `FEDFUNDS` | |
| 10 年期国债收益率 / 10Y | `DGS10` | 比行情晚 1 天，当日看 `^TNX`（N-139） |
| 2 年期国债 | `DGS2` | |
| 30 年期国债 | `DGS30` | |
| 30 年抵押贷款利率 | `MORTGAGE30US` | 周频；不是 DGS30 |
| 10Y TIPS 实际利率 | `DFII10` | |
| 通胀预期 / 10Y BEI | `T10YIE` | |
| 10Y-2Y 利差 / 收益率曲线 | `T10Y2Y` | |
| M2 货币供应 | `M2SL` | |
| Fed 资产负债表 | `WALCL` | |
| 财政部 TGA | `WDTGAL` | 周频、百万美元；`WTREGEN` 不可用（N-108） |
| 隔夜逆回购 / RRP | `RRPONTSYD` | |
| 高收益债利差 / 信用利差 | `BAMLH0A0HYM2` | 日频、% |
| 零售销售 / Retail Sales | `RSAFS` | 会展开别名，单独一批 |

**不是 FRED、但常被一起问的**（走 `categories=["market"]` 数组）：

| 用户可能说 | 代码 | 备注 |
|---|---|---|
| WTI 原油 | `CLUSD` | 现货日线；最后一根可能没收盘，涨跌用收盘对前收自己算（N-106、N-131）。`USO` 只是 ETF 代理 |
| 布伦特原油 | `BZUSD` | 同上 |
| 黄金 | `GCUSD` | 不要用 `GOLD`（会变成 Gold.com 股票） |
| 白银 | `SIUSD` | |
| 美元指数 | `DXUSD` | `^DXY` 会被丢掉（N-121） |

# 附表 B：旧「调用红线」编号对照

> 2026-10-12 前本文件开头有 12 条编号红线，仓库里仍有十几个文件按「红线 N」引用。红线已并入「一、现行用法」和对应条目，旧编号按下表查。

| 旧编号 | 原内容 | 现在在哪 | 10-12 状态 |
|---|---|---|---|
| 红线 1 | `asset_type` 必须显式 | 现行用法·通用第 2 条；B-18、N-51；news 的例外见 N-145 | 仍有效；混流例子换成灰度 ETF 和代币化股票 |
| 红线 2 | SSE 并发 ≤4 | N-50 | 改为客户端经验值：服务端 6 路并发实测正常 |
| 红线 3 | FRED 用 series_id 直查 | 现行用法·宏观；附表 A；N-107 | 写法改为 `keywords` 数组，不再走 query 串 |
| 红线 4 | FRED 不批量、行情上限 5 | 现行用法·通用第 3 条；N-107、N-23 (a) | FRED 可一批 5 个；超限现在有 warning |
| 红线 5 | news query 三原则 | 现行用法·news 搜索；N-26 | 三原则仍有效；「news 无 sort_by」作废（N-112） |
| 红线 6 | 商品代码 | 现行用法·行情 商品和外汇；N-30、N-106 | 「原油只能用 USO」作废，CLUSD / BZUSD 走数组可取 |
| 红线 7 | 「全面分析」返回 14 块 | N-109 | 作废：现在只返回 5 块，不要用 |
| 红线 8 | 历史 K 线与技术指标写法 | 现行用法·行情 历史 K 线、技术指标；N-132、N-169 | 改为数组 + `categories=["market"]` + 历史意图词 |
| 红线 9 | 涨跌榜弃用 / 改用 most active | 涨跌榜小节：N-111、N-9、N-160、N-138 | Q4 不投入；有反向拆股假涨幅 |
| 红线 10 | 经济日历与财报日历写法 | 经济日历见现行用法·宏观（N-32、N-128、N-129）；财报日历见 N-22 | 经济日历写法仍有效；财报日历两种写法都会漏大票 |
| 红线 11 | news 无匹配时返回兜底内容 | N-35 | 仍有效 |
| 红线 12 | 研报 query 必须含研报意图词，没有按单份取的参数 | 现行用法·研报；研报小节「补充」第 1 条 | 仍有效；现在可用 `cursor` 翻页 |
