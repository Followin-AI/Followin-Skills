---
name: US Stock Premarket Watchlist Automation
description: 用 Followin MCP 创建或更新美股自选股盘前追踪自动化，按持仓状态生成盘前报告、异动与重大新闻提醒、条件化交易计划。适用于“每天盘前跟踪自选股”“监控我的美股持仓”“创建盘前自动化”“premarket watchlist”等请求；用户只需提供自选股和持仓状态。
trigger: 美股盘前追踪、盘前自选、盘前自动化、每天盘前跟踪、自选股跟踪、监控我的持仓、美股盯盘、premarket watchlist、premarket tracker、daily stock watchlist、monitor my holdings
not_trigger: 宏观早报、社群早报、開盤前瞻、开盘前瞻、财报季扫描、单股财报分析、多Agent深度分析、背离扫描、crypto morning brief、macro morning brief、earnings screener、earnings report、divergence scan
mcp: mcp__followin__metrics, mcp__followin__news, mcp__followin__signal, mcp__followin__twitter, mcp__followin__subscription
args: watchlist, positions, schedule, timezone
---

# /premarket-watchlist-automation $ARGUMENTS

用 Followin MCP 为用户的美股自选股和持仓创建盘前追踪任务。用户只需提供自选股与当前持仓；没有指定时间时，采用其所在时区中“美股常规交易开盘前约 1 小时”的工作日时间。

## 使用边界

- 以 Claude Code 为主要客户端：有定时任务能力（如 `/schedule`、scheduled-tasks 工具）时，创建或更新周期任务；先查找同名或同一 watchlist 的任务，避免重复。其他客户端（Codex 等）的接入见文末附录。
- 云端定时（`/schedule`）需在任务里另行配置 Followin MCP，本机 `~/.claude.json` 的配置不一定可用；下次建任务时实测（建完先手动触发一次，确认 Followin 调用成功再交付）。
- 没有自动化工具时，立即运行一次同结构的盘前报告，并说明当前客户端不能创建周期任务。
- Followin MCP 是主要证据层。不可用或鉴权失败时，明确说明，不得伪造 Followin 数据。
- 行情上游整体失效时照样扣额度（N-156）：第 1 步快照兼作探针，返回 `status:"degraded"` + `severity:"source_dead"` 就跳过同一上游的其余行情 / 历史 / 内部人调用，对应段落写"缺数据"，不写"没有交易"或"无异动"。
- Followin MCP 不执行券商订单。只输出条件化研究计划，不得声称已下单、成交或修改仓位。

## 先收集四项输入

1. **Watchlist**：股票代码列表，例如 `DRAM, SNDK, MU, NOK, MRVL`。
2. **Positions**：每只股票为空仓（无持仓）、多仓、空头或期权；已有仓位尽量记录数量、均价、止损和目标。用户只说“全部空仓”时，将所有标的视为仅观察。
3. **Schedule / Timezone**：默认美股交易日开盘前约 1 小时（美东 08:30）。用户未给时区时按其所在时区换算：Asia/Shanghai 在美国夏令时通常为工作日 20:30，冬令时通常为 21:30；创建任务时说明夏令时切换。
4. **Destination**：默认回到当前任务；只有用户明确要求时才使用其他目标。

用户为空仓时，不追问均价和数量。缺少非必要字段时先建立第一版任务，不要因过度澄清而停住。

## 创建或更新自动化

1. 查找已有的盘前任务；watchlist 与目的相同则更新，不另建重复任务。
2. 验证 Followin MCP 已连接。可先运行：

   ```bash
   claude mcp get followin
   ```

3. 使用 Claude Code 的定时任务能力创建或更新任务，不手写不可执行的自动化指令。
4. 将 watchlist、positions、schedule、timezone、输出结构和失败处理全部写入任务提示词。
5. 返回任务 ID、运行时间、标的列表和持仓假设。

Claude Code 接入（Streamable HTTP；key 用环境变量传入，避免明文留在命令历史，但添加后会以明文保存在 `~/.claude.json`）。必须带 `--scope user`：默认 `local` 只在执行命令的那个项目目录生效，定时任务换了工作目录就连不上 Followin：

```bash
claude mcp add --scope user --transport http followin https://mcp.followin.io/v2/mcp --header "x-api-key: ${FOLLOWIN_MCP_TOKEN}"
```

不得在报告、日志或回复中输出真实 API key。

## SSOT 红线内联

- **入参分工（2026-10-01 实测，N-105）**：标的放 `keywords` 数组，意图词放 `query`，信号类别放 `categories`，新闻来源放 `sources`。指数（`^GSPC` 等）与商品代码（`GCUSD` / `CLUSD` 等）**只能走数组**——商品代码写进 query 串整批返空且不报错。客户端不接受数组入参（报 `-32602`）时，美股代码可退回 query 空格拼串。
- **批量 ≤5 个 symbol/次；SSE 并发 ≤4 路/批**（红线 2）。
- **调用后读 `meta.warnings`**：超出 5 个或解析不了的 symbol 会报 `keyword_count_over_max` / `kw_not_canonical`；个别代码仍会被静默丢弃（实测 `^DXY` 无任何提示，美元指数用 `DXUSD`），所以再把请求列表与返回行做一次差集，差集非空即部分失败。

## Followin 调用顺序

`metrics` 与 `signal` 的美股调用都传 `asset_type="tradfi"`；**`news` 搜索模式不传**——传了召回大降且不报警，路透 / 彭博 / WSJ 会整批丢失（N-145）。

1. **`metrics` 市场层**：`metrics(keywords=[≤5 个], query="行情", asset_type="tradfi", verbosity="detail")` 取指数或 ETF 市场背景、自选股当前价/最近收盘、涨跌、成交量。必须用 `detail`：standard 不带 `changePercentage` / `priceAvg50` / `priceAvg200`（N-150）。盘前 / 盘后的个股报价在 `extendedHoursQuote`（只有 bid / ask / size / volume / timestamp，没有成交价和涨跌；三大指数没有，部分个股缺失，N-150），盘前价 = (bid+ask)/2，对快照 `price`（即上一 regular 收盘）自算涨跌。历史走势用 `query="历史走势"` + `time_range` + **`limit`**——不传 `limit` 时每只只回 10 根日线（2026-10-08 实测：`time_range="30d"` 每只 10 行），要 20 日高低点就传 `limit=25`。量比用的小时线另取一次（写法见下文"异动"）。技术指标用 `query="均线 指标"`。⚠️ 日线的 `change` / `changePercent` 是**当日收盘对当日开盘**，不是对前一日收盘（N-131）——多日涨跌和波动一律用相邻两天的 `close` 自算；**美东 9:30–16:00 之间运行时，日期等于今天（美东）的那根是未收盘的半截 K 线**，`close` 比快照滞后（2026-10-08 实测：美东 10:09 NVDA 日线 close 234.05、成交量 1486 万，同时刻快照 235.55、1761 万），自算时剔除；16:00 后运行时这根已收盘（2026-10-09 实测美东 21:40：MU 日线 close 1035.84 与快照一致），照常使用。当日涨跌一律用快照 `price` 对 `previousClose`。价格、涨跌、成交量只读 `market.snapshot`：同一次 `query="行情"` 有时还会带 `fundamentals` 的 `profile_block`，其中 `price` / `volume` 与快照不一致（2026-10-09 实测 SNDK 1609.46 对快照 1609.07）。
2. **`metrics` 基本面层**：`metrics(keywords=["<TICKER>"], query="行情 分析师评级 目标价", asset_type="tradfi")` 一次拿快照、最新一季财报（`fiscal_quarters[0].earnings_surprise` / `financial_statement`；数组有多个元素时按 `period_end` / `report_date` 认季，不默认取 `[0]`——2026-10-08 实测 PCVX `[0]` 没有 `earnings_surprise`，它在 `[1]` 且 `fiscal_period` 为 null）、下一次财报日期（`next_earnings_estimate.date`）与分析师评级；估值比率在不写 query 的默认返回里（`valuation_block.ratios_ttm`）。`next_earnings_estimate.date` 会跳季（N-149：TSLA 上季 07-22 公布，返回 2027-02-03），距上次 `report_date` 超过约 100 天就标"日期待核"，不写成确定日期。`analyst_grades` 不带时间窗（N-147），只把近 30 天的行当"评级变化"。
3. **`news(query="<公司英文名> <TICKER>", time_range="24h"~"7d", limit=N)`**：每只标的一次调用，同时读两桶——articles 桶看重大新闻、公告与催化，**social 桶**看社媒热度（实际约 2N 条，N-25）；social 按原帖 URL 去重后再计数。公司名撞常见词或同名公司时（`PTC` 会混进 PTC Therapeutics / PTC Industries），逐条核正文是否为目标公司再计入。市场级热度另用同样写法搜主题词。
4. **结构化研报走 `metrics(keywords=[…], query="research reports", asset_type="tradfi", date_from=…, date_to=…)`**（红线 12：query 必含研报意图词）。目标价、评级和结构化 thesis 仍以 `metrics` 为准。多标的一次调用时**所有标的共用一页 10 张卡**，靠前的标的会把后面的挤成 0 条（2026-10-08 实测：5 只同批 NVDA 6 + MU 4，TSLA 返回 0 且无 warning；TSLA 单独查有 3 篇）。判读：某标的为 0 且带 `no_research_reports` warning 才是"无研报"；为 0 但无该 warning、且 `meta.pagination` 里 `has_more:true`，按"被挤出"处理，单独补查或翻页。
5. **`signal(keywords=[≤5 个], categories=["kol_call","insider_trading","institutional"], asset_type="tradfi", limit=50)`**：**必须显式列出 `categories`**（2026-10-01 实测：省略后只传 ticker 返回空），三类一次调用仍只计 1 额度；`limit` 对每类分别生效、默认 10，多票帖拆出的行会把目标票挤出（N-151），所以传 50；某类返回行数恰好等于 `limit`（内部人最常见）时说明被截断，拆成单票再查。ETF / 基金（快照 profile `isEtf:true`）不查内部人：代码可能被旧公司用过（2026-10-09 实测 `DRAM` 返回 2014–2017 年 Dataram 公司 CIK 0000027093 的申报，含 `P-Purchase`）。个股的议员行核对 `assetDescription` 是否为本公司（同日实测 `MU` 混进一行 "MIRION TECHNOLOGIES"），对不上的剔除。内部人回看窗口 90 天：公司内部人按 `transactionDate`、议员按 `disclosureDate` 只留近 90 天的行；单票 50 行的最后一行仍在 90 天内时说明窗口没取全，写"至少 N 笔"。**内部人的 50 行是同批所有标的合计**，不是每只 50 行（2026-10-08 实测：5 只同批恰好 50 行，NVDA 22、PCVX 19，MU / PTC / TSLA 各 3；MU 单查 50 行，回溯到 07-24，含 CEO 08-21 的一批 `S-Sale`，同批时全被挤掉），所以多票时内部人直接逐只查（`categories=["insider_trading"]`），喊单与 13F 仍可同批。不带 `time_range`（13F 带窗口会被拒，喊单上游只覆盖最近 24 小时）；喊单行按 `symbol` 自行筛并按 `source_url` 去重（一条推文提到多个标的会拆成多行，N-136），去重后 <10 帖不称"共识"，美股喊单方向结构性单边看多（N-100），只报帖数与原话，不报多空比。内部人按 `transactionDate` 自行过滤，卖出只认 `S-Sale`、买入只认 `P-Purchase`（`M-Exempt` / `F-InKind` / `A-Award` 是行权、代扣与授予，不是主动交易）；国会议员交易带 `_chamber` 字段、滞后 2~4 周申报，按 `disclosureDate` 判新旧（N-137）。13F 的 `*_change_percent` 恒为 0，只用持仓绝对值（N-134 ⑦）；季末后头几周会切到只剩零星几家的新季度（N-152），不据此判断机构动向。只解读实际返回的类别。
6. **`twitter`**：仅在用户点名账号、指定推文或需要原始线程时使用，不拿它替代一般社媒搜索。
7. **`subscription`**：用户要求维护 KOL 喊单关注收件箱时使用。它是拉取式未读箱，不是服务端主动推送。

## 每次报告的固定结构

### 1. 市场背景

- 指数/ETF、行业主题和风险偏好；只写 Followin 实际返回的可验证数据。
- 美国节假日或休市日明确写“今日休市”，不把最近收盘冒充当日盘前。休市按美东日期判：周末或 NYSE 假日即休市；快照 `as_of` 与历史日线最后一根停在前一交易日只作佐证。
- 运行时在美东 9:30–16:00 之间（补跑、延迟触发），报告标题改标"盘中快照"并写明 `as_of`，不再称盘前报告。16:00 之后到次日 04:00 之前运行（如北京白天手动跑），价格都是当天收盘，标题标"收盘后快照"，量比按下文"收盘后量比"算。

### 2. 单票追踪

每只股票给出：

- 盘前价或最近可验证价格、涨跌和成交量/异动。**异动**＝涨跌幅绝对值 ≥3% 或量比 ≥2，二者满足其一即标"异动"；进入「并购价差观察」的票不判异动（量比、涨跌幅都不判）。量比＝当前成交量 ÷ 近 20 个交易日同一时段的平均成交量；基准剔除这 20 天里单日涨跌幅绝对值 ≥10% 的事件日（单日涨跌用相邻两天日线 `close` 自算，不用日线 `changePercent`，N-131），剔除后不足 10 天标"基准不足"、不据量比判异动（2026-10-08 实测 PCVX：不剔除 10-05~10-07 时量比 1.26，剔除后约 4.2）。同时段均量只能用小时线算：`metrics(keywords=[≤5 个], query="历史走势", asset_type="tradfi", interval="1hour", limit=340)`。2026-10-08 实测：
  - 小时线含延长时段，每天 16 根（美东 04:00–19:00 开头，时间戳是美东），`limit` 按每只计——`limit=200` 每只只覆盖约 12 个交易日，20 天要 340；`5min` / `15min` / `30min` 每天 192 / 64 / 32 根，受历史上限 365 根限制凑不满 20 天。5 只一次约 27 万字符，会落盘，用脚本解析。
  - `09:00` 那根覆盖 09:00–09:59，混了半小时盘前，切不出 9:30。所以**盘中量比**＝今天从 `09:00` 到最后一根已走完的小时线成交量合计 ÷ 前 20 个交易日同几根的合计均值；**盘前量比**＝今天 `04:00` 到最后一根已走完的盘前小时线合计 ÷ 前 20 日同几根均值（08:30 运行时是 04:00–07:00 四根，`08:00` 那根未走完不算）；**收盘后量比**（16:00 后到次日 04:00 前运行）＝刚收盘那天 `09:00`–`16:00` 八根合计 ÷ 前 20 日同八根均值，`16:00` 那根含收盘竞价（2026-10-09 实测：MU 该根开盘价即收盘价、成交 186 万股，`17:00` 那根只有 4.6 万），要计入。
  - 事件日剔除只在这 20 天里做，不往前补天数。
  - 缺的小时线按成交 0 计，不跳过那一天（小盘股盘前常缺行：PTC 当天盘前只有 4 根、合计 36 股）；`volume` 带小数，取整后再算。
  - 小时线取不到时，退回"成交量 ÷ 20 日日均量"并标明不是量比、不据此判异动；`extendedHoursQuote.volume` 同样只作参考。⚠️ `change` 是**美元变动量不是百分比**（N-47），百分比自算 `change/previousClose×100`，别拿 `change` 与新闻里的 % 交叉核实。
- 关键技术位与触发条件。技术位只取可复核的数：前收 `previousClose`、最近 10 / 20 个交易日收盘高低点（历史日线，剔除当日半截 K 线）、`priceAvg50` / `priceAvg200`、`yearHigh` / `yearLow`，以及事件价（收购报价、跳空前收盘、增发定价）；不写凭感觉画的支撑压力。
- 最近催化、重大新闻、公司公告、财报/研报变化。
- 去重后的社媒热度、KOL/内部人/机构信号及样本量。

价格时点用**字段判据**判定，不用挂钟时间猜，按下面顺序：

1. **盘前报价**（⚠️ 待盘前实测：默认 08:30 ET 触发时能否取到 `extendedHoursQuote` 尚未验证，2026-10-08 只在盘中跑过，盘中不返回该字段）：快照带 `extendedHoursQuote` 且 bid / ask 都非空时，盘前价 = (bid+ask)/2，标"盘前报价（买卖中间价）"并注明 `timestamp`；涨跌对快照 `price` 自算。**兜底**：取不到（字段缺失、bid 或 ask 为空）时价格写"最近收盘"，不用新闻里的百分比顶替，按下面第 2、3 条判定。
2. **最近收盘**：返回里 `_quote_session=="regular_inactive"` / `_quote_cache=="last_regular"`（N-48）即是上一个 regular 收盘——盘前时段快照的 `price` 仍是旧收盘，标"最近收盘"，不得称为盘前价。
3. **字段缺失**：没有 `_quote_session`（`^VIX`、外汇、商品和多数小盘股都没有，N-139；2026-10-08 实测美东 10:09 盘中 NVDA / MU / TSLA / PTC / PCVX 与 `^GSPC` / `^IXIC` 全部不带）就看 `as_of`：落在今天美东 9:30–16:00 内才算实时价，早于今天或在此区间外一律标"最近收盘"，不能因为字段缺失就当成实时价。`^VIX` 的 `as_of` 会落在下一交易日盘前而数值仍是上一收盘（N-150），按"最近收盘"写。

### 3. 持仓对应计划

- **空仓**：给“等待 / 试仓 / 突破 / 反转”中的条件化计划，包括触发价、失效价/止损逻辑和优先级。
- **已宣布现金收购的标的**：剔出方向性计划，单列「并购价差观察」：收购价、现价、价差（(收购价−现价)÷现价×100%），附交易进展与主要风险（监管审批、股东投票、交易终止）。收购价以公司公告或新闻原文为准，并注明来源。
  - "已宣布"＝公司公告或签了协议、写明每股现金价；"接近达成""据知情人士"只算传闻，不进此栏（2026-10-08 实测 PTC：10-04 彭博 / FT 传"接近 200 亿美元收购"，10-05 才宣布每股 205 美元现金）。
  - 现价按上面的价格时点规则取，注明是盘前中间价、实时价还是最近收盘。
  - 另列三项：① **预计完成时间**，照抄公告原文（如"预计 2027 年上半年完成"）；② **年化价差**＝价差 × 365 ÷ 距预计完成日的天数（从运行当天的美东日期起算），原文只给区间时按区间末日算并注明（"by the third quarter of 2027" 按 2027-09-30），原文没给时写"无法年化"；③ **交易告吹的下跌参考**＝(传闻前一日收盘−现价)÷现价×100%，没有传闻时用宣布前一日收盘（PTC：传闻前一日 10-02 收盘 144.03，对现价 193.68 为 −25.6%）。
  - 此栏不列 10 / 20 日高低点和均线（都停在宣布前，PTC 20 日收盘低点 128.72，对价差没有意义），技术位只写收购价。
  - 宣布后的律所"调查是否公平"稿不算交易进展（N-174 ⑨）；进展只认审批、投票、竞购、条款变更与终止。
- **多仓 / 空头 / 期权**：根据用户提供的均价、数量和风险预算，给持有、加减仓、止损或对冲观察条件。
- 明确区分“交易设置”和“中长期投资逻辑”。
- 不承诺收益，不把社媒热度写成确定性信号。

### 4. 组合视角

- 排出当天最值得关注的 1–2 个机会。排序：24 小时内有新催化**且**涨跌幅绝对值 ≥2% 的排前；有催化但涨跌幅不到 2% 的不优先，和没有催化的一起按涨跌幅绝对值从大到小排。「并购价差观察」里的标的不参与排序。
  - "24 小时"从运行时刻往回算，按 news 行的 `published_ts` 判；首发时间不确定时用 `sort_by="relevance"` 再搜一次找第一篇（N-167）。正文写明事件日期早于这 24 小时的转述稿按事件日期判，不算新催化（2026-10-09 实测：一篇 24 小时内发布的稿子转述大摩 10-07 报告把 MRVL 目标价从 268 上调到 300）。
  - "新催化"只认当事公司、交易对手或监管的新动作：公告、财报与指引、试验数据、增发 / 可转债定价、并购条款、评级或目标价变动（`analyst_grades` 里 `maintain` 不算）。律所调查稿、内部人卖出的转述稿、行情播报稿、第三方产品或合作方新闻、发布会展示稿、"据报道"类未经公司确认的消息（如传闻裁员）都不算。
- 列出需要回避的标的或事件风险。
- 提醒同一行业、同一因子或同一事件造成的相关性风险。

### 5. 来源与刷新条件

- 明确哪些事实来自 Followin MCP，补充公共来源时单独标注。
- 给出下一次需要刷新报告的时间、事件或价格条件。
- 结尾注明“仅供研究参考，不构成个性化投资建议”。

## 自动化提示词模板

```text
使用 Followin MCP 作为主要数据源，监控美股自选股：{WATCHLIST}。

当前持仓：{POSITIONS}。
时区：{TIMEZONE}。如果标记为空仓，只给条件化入场计划，不给持有或减仓建议。

每次运行输出简洁中文盘前报告：
1. 市场背景：指数/ETF、行业主题和风险偏好。
2. 单票：盘前价或最近可验证价格、涨跌/异动（涨跌幅绝对值 ≥3% 或量比 ≥2；量比＝当前成交量 ÷ 近 20 日同时段均量，用 1 小时线算，基准剔除单日涨跌幅绝对值 ≥10% 的事件日、剩不足 10 天标"基准不足"，盘前对比注明口径；并购价差观察里的票不判异动）、关键技术位（前收、10/20 日收盘高低、50/200 日均线、52 周高低、事件价）、近期催化、重大新闻、结构化研报变化、去重后的社媒与公开信号（标样本量）。
3. 持仓计划：空仓给触发价、失效/止损逻辑与优先级；已有多仓、空头或期权则按持仓状态给条件化管理计划。已宣布现金收购的标的（公告或协议写明每股现金价，传闻不算）不做方向性计划，单列「并购价差观察」：收购价、现价、价差、预计完成时间（公告原文）、年化价差、交易告吹的下跌参考（传闻或宣布前一日收盘相对现价），不列 10/20 日高低与均线。
4. 组合视角：当天优先关注的 1–2 个机会（24 小时内有新催化且涨跌幅绝对值 ≥2% 的优先，其余按涨跌幅绝对值排；催化只认当事方的新动作，律所调查稿、内部人卖出转述、行情稿、发布会展示稿、"据报道"类未经公司确认的消息、评级 maintain 不算）、需要回避的风险和相关性风险。
5. 来源纪律：明确标注 Followin MCP 来源。Followin 不可用时直接说明，不得编造。

调用纪律（每次运行都遵守）：
- metrics / signal 传 asset_type="tradfi"，news 搜索不传；标的放 keywords 数组，每次 ≤5 个，调用后核对 meta.warnings 并把请求列表与返回行做差集。
- 第一次行情调用兼作探针：status="degraded" 且 severity="source_dead" 时跳过其余行情 / 历史 / 内部人调用，对应段落写"缺数据"。
- 行情用 verbosity="detail"。盘前价 = extendedHoursQuote 的 (bid+ask)/2，对快照 price 自算涨跌（08:30 ET 能否取到该字段待盘前实测）；取不到时写"最近收盘"，不用新闻百分比顶替；带 _quote_session="regular_inactive"、或 as_of 不在今天美东 9:30–16:00 内的价格一律标"最近收盘"。
- 价格、涨跌、成交量只读 market.snapshot，不读 fundamentals.profile_block。快照 change 是美元变动量；日线 change / changePercent 是收盘对开盘。当日涨跌用快照 price 对 previousClose 自算；多日涨跌用相邻两天 close 自算，美东 9:30–16:00 运行时剔除日期为今天的未收盘 K 线（16:00 后这根已收盘，照用）；历史日线显式传 limit。
- 量比：metrics 传 interval="1hour"、limit=340（每天 16 根含延长时段，时间戳为美东），只用已走完的小时线；盘中从 09:00 那根起算，盘前从 04:00 起算，16:00 后到次日 04:00 前运行取当天 09:00–16:00 八根（16:00 那根含收盘竞价），与前 20 日同几根的均值比；缺的小时线按 0 计。16:00 后运行的报告标"收盘后快照"。
- signal 必须显式传 categories=["kol_call","insider_trading","institutional"]、limit=50、不带 time_range；喊单按 symbol 筛、按 source_url 去重，<10 帖不称共识；内部人只认 S-Sale / P-Purchase，回看 90 天（议员按 disclosureDate，核对 assetDescription 是本公司）。内部人 50 行是同批所有标的合计，多票时逐只查；ETF 不查内部人。
- 新催化按事件日期判：24 小时内发布、但转述更早事件的稿子不算。
- 基本面 fiscal_quarters 有多个元素时按 period_end / report_date 认季，不默认取 [0]。
- 研报多标的同批共用 10 张卡，某标的 0 条且没有 no_research_reports warning 时单独补查。
休市日明确写休市。Followin MCP 不执行订单，不得声称已经下单。

结尾给出下一次刷新条件，并注明仅供研究参考，不构成个性化投资建议。
```

## 完成时确认

返回：

- 创建或更新的任务 ID。
- 运行时区与具体时间。
- Watchlist 和 positions 摘要。
- 是否完成 Followin MCP 验证。
- 若只运行了一次报告，明确说明未创建周期任务。

## 附录：其他客户端接入（Codex）

Codex 用 TOML 配置 Streamable HTTP（`~/.codex/config.toml`）：

```toml
[mcp_servers.followin]
url = "https://mcp.followin.io/v2/mcp"
env_http_headers = { "x-api-key" = "FOLLOWIN_MCP_TOKEN" }
```

若用户接受把 key 存进配置，也可使用：

```toml
[mcp_servers.followin]
url = "https://mcp.followin.io/v2/mcp"
http_headers = { "x-api-key" = "YOUR_API_KEY_HERE" }
```

Codex 的周期任务用其自带的自动化功能创建，提示词仍用上面的模板。不得在报告、日志或回复中输出真实 API key。
