---
name: Earnings Season Screener
description: 财报季超预期扫描 — 扫近期已发布的美股财报，找"业绩大增 × 电话会喊出高景气关键词"的叠加候选榜。无需指定 ticker 的发现器。触发如"财报季扫描"、"本周谁业绩大增"、"earnings screener"。点名单股的财报分析走 Base Skill 02（美股财报分析）。
trigger: 财报季扫描、超预期扫描、本周财报超预期、谁业绩大增、财报季选股、扫一下财报季、earnings screener、earnings season scan、who beat earnings、find earnings beats
not_trigger: XX财报、[代码]财报（点名单股→02）、背离扫描、divergence（→03）、宏观早报、morning brief（→06）、BTC宏观、黄金宏观、KOL、喊单、多Agent分析
mcp: mcp__followin__metrics, mcp__followin__news
tools: WebSearch, WebFetch
args: days, top, watchlist
---

# /earnings-season-screener $ARGUMENTS

财报季超预期扫描 — 把"挨个看业绩大增公司的财报，找高景气表述"这套人肉流程自动化（Followin MCP 版）

> **版本**：v1.8 ｜ **调用写法、字段名实测于 2026-10-01，2026-10-03、2026-10-08 实跑修订**
>
> MCP 的行为会变——v1.5（7 月底）到 v1.6 之间就变了五处：返回字段改名、财报日历从不可用变成可用、数组入参从被拒变成推荐写法、一批"解析不了"的 ticker 恢复、逐字稿正文被截断到 2000 字符。**隔一段时间再用，先花几分钟跑下面 4 条自查**，哪条对不上就以实测为准：
> ① `metrics(keywords=["AAPL"], asset_type="tradfi", limit=1)` → 最新季的超预期数据是否仍在 `fundamentals.concise[].fiscal_quarters[0].earnings_surprise`
> ② `metrics(query="earnings calendar", asset_type="tradfi", date_from=<7 天前>, date_to=<今天>, limit=50)`（不传 country）→ 返回里是否有无后缀的美股代码、且带 `revenueActual`；再看 ACN、MDT、LIN 这类外国注册的美股在财报日是否出现；最后看**末行的 `date` 走到了窗口里的哪一天**（2026-10-08 实测只走到第 2 天，见 Step 1 腿①）
> ③ `metrics(keywords=["MU"], query="earnings call transcript", asset_type="tradfi", verbosity="detail", limit=1)` → `transcript[0].content_truncated` 是否仍为 `true`。截断来自 `verbosity` 的设计上限（detail 档 2000 字符），所以更该看的是 metrics 工具说明里有没有新增分页或全文参数；有的话 **Step 3 来源 B** 回到第一位
> ④ 同 ③ 的返回里 `transcript[0].date` 与 `earnings_surprise.report_date` 是否同一天，且正文开头是主场电话会（"Earnings Conference Call"）——实测 MU 返回的是 "Post-Earnings Analyst Call"，日期相同但不是同一场

## 参数

| 参数 | 必填 | 默认 | 说明 |
|------|------|------|------|
| days | 否 | 7 | 扫描窗口（**三处共用**：日历腿回看 / 新闻腿回看 / 财报新鲜度闸）。前瞻板块默认也看未来 `days` 天；淡季时自动扩到 14 天（见 Step 4）|
| top | 否 | 5 | 关键词深扫上限。幸存者不足 top 就扫几个，**不要为凑数放宽闸门** |
| watchlist | 否 | — | 空格分隔的 ticker。传了则额外查这批的下次财报日，并入「📅 即将发财报」板块 |

## 方法论

源自散户选股四步法，本 Skill 是它的美股自动化版：

1. **前提**：1/4/7/10 月是财报季
2. **业绩大增**：找营收/EPS 显著超预期的公司
3. **关键词**：财报/电话会里是否重点说了「供不应求 / 行业高景气上行 / 市场超预期拓展 / 新品持续超预期 / 价格中枢上涨 / 供给偏紧 / 需求旺盛」
4. **叠加**：2 和 3 同时满足才值得重点关注

**核心纪律：2 和 3 是两道独立闸门，缺一不可。** 只有业绩超预期是"数字好看"，只有关键词是"管理层嘴上说得好听"，叠加才是信号。

## 意图路由

| 用户说的 | 走哪 |
|---------|------|
| 财报季扫描、谁业绩大增、本周超预期 | ✅ 本 Skill |
| AAPL 财报、NVDA earnings（点名单股）| ❌ 转 `Base Skill/02_us-stock-earnings-report` |
| 背离扫描、没新闻却大涨 | ❌ 转 `Base Skill/03_us-stock-divergence-scan` |
| 宏观早报、今日市场 | ❌ 转 `Base Skill/06_macro-morning-brief` |

> 🔗 **已知问题登记**：`~/.claude/references/followin-mcp-caveats.md`（仓库内 `references/`）。本文与登记表冲突时，以日期更新的一方为准。
> 📐 **每个参数的实测依据与历次被否决的方案**：见 [`CHANGELOG.md`](../CHANGELOG.md)（目录 README 已改为纯用户视角，不再收录）。

## 调用约定（2026-10-03 实测）

- `metrics` 的入参分工：**`keywords` 数组放 ticker，`query` 放意图词**。每次最多 5 个 keywords。
- 所有 `metrics` 调用带 `asset_type="tradfi"`。
- **财报日历不要传 `country="US"`**：它按公司**注册地**过滤，美国上市的外国注册公司会被漏掉（实测 10-01 发财报的 ACN 是爱尔兰注册，带 country 时不在名单里；同日的美国公司 HUBG 也因候选上限被漏）。不传 country 时结果里会混入 `.KS` / `.T` / `.L` 等外国代码和重复股类，客户端过滤即可。
- **财报日历的排序决定了单页能看到什么**（2026-10-08 实测）：传 `date_from` / `date_to` 时按日期**从早到晚**，传 `time_range` 时**从晚到早**；同一天内按代码字母序，`0`~`9` 开头的日、韩、港代码排最前，之后是 `.V` / `.L` / `.T` 和 F 结尾的 OTC 外国股。一个工作日有上百行，`limit=50` 的一页只盖住窗口最早的 1~2 天（淡季的周四、周五），`time_range` 写法则一页停在当天的 "AE…"。`keywords` 与 `sort_by` 都改不了排序（N-133 / N-148）。
- 历史日线里每行的 `change` / `changePercent` 是**当日收盘减开盘**，不是对比前一天收盘，算涨跌一律用相邻两天的 `close`。
- **每次调用后读 `meta.warnings` 和 `status`**。`keyword_count_over_max` = 有 ticker 被挤出本批；`status:"partial"` = 结果不完整。`default_fanout_fallback` 只是提示"没指定主题，返回核心集合"，数据是齐的，不要重试。
- **有"影子代码"的 ticker 会多占名额**：`CL`（高露洁）会同时展开成原油期货 `CL=F`；`BABA` 会展开成 3 个（`$BABA` / `BABA` / `9988.HK`）。实测一批 `NVDA MU CL BABA F` 只处理了前三只，BABA 和 F 都被挤掉。→ 批里含 `CL` / `GC` / `SI` / `NG` / `HG`（与商品重名）或 `BABA` / `JD` / `NTES` / `BIDU`（港股二次上市）时，**把它单独放一批**。
- 单批 ≤4 路并发。
- 如果客户端不接受数组入参（报 `-32602`），把 ticker 并进 query 串：`query="<T1> <T2> … next earnings date"`（返回里没有市值，需另调 `query="<T1> <T2> … 行情"` 补）。

---

## 执行流水线（5 步）

### Step 1 — 发现（三条腿并行）

**腿①：财报日历（1 额度）——已发布财报的直接名单**

```
metrics(query="earnings calendar", asset_type="tradfi",
        date_from="<今天 − days>", date_to="<今天>", limit=50)
```
返回 `fundamentals.earnings_calendar[]`：symbol / date / epsActual / epsEstimated / revenueActual / revenueEstimated。
- 客户端只留代码匹配 `^[A-Z]{1,5}$` 的行（去掉 `.KS` / `.T` / `.L` 这类外国代码和 `MKC-V` 这类重复股类），**再剔除 5 位且以 F / Y / W / R / U / Q 结尾的**（OTC 外国股、OTC ADR、权证、权利、单位、破产股）。2026-10-08 实测只用前一条正则时，SOIEF、CASIF、JDWPF、JDWPY、ATCHW、AACTF 都会混进来，SOIEF 还过了营收 +2% 一路送到 Step 2。
- `revenueActual` 非 null = 已发布，可以直接算：`营收 surprise = revenueActual ÷ revenueEstimated − 1`，EPS 同理。`revenueEstimated` 为 null 的算不出 surprise，不在这里淘汰，跟其他候选拼批送 Step 2；那边的预期值也为 null 就记数据缺口（2026-10-08 实测 AIXI、DOGZ、NAMM 都是这种，AIXI 基本面块的预期值同样为 null）。
- `revenueActual` 为 null = 还没发布，留给「📅 即将发财报」板块。
- `has_more:true` 时用 `meta.pagination` 里的 `next_cursor` 翻页，**最多翻到第 2 页**。
- ⚠️ **这条腿实际只覆盖窗口最早的一两天**（见调用约定里的排序一条）。2026-10-08 实测 `days=7`：两页 100 行只走到 10-05 的 "B…"，10-06~10-08 发财报的 STZ、LW、RPM、APLD、LEVI、PEP 一只都没出现。**记下末行的 `date` 和 `symbol`，输出里写"日历腿覆盖 [date_from]~[末行日期]（末行当天只到 [末行代码]）"**——末行那天只盖住字母序靠前的一段，不能算覆盖完整（同日复跑：第 2 页末行是 10-05 的 "CORO.L"）。之后的日子全靠新闻腿。返回还可能带 `status:"partial"`（候选上限），中小盘会漏。
- **淡季判定（按日期）**：运行当天落在 1 / 4 / 7 / 10 月的 1–10 日（财报季刚开头，大公司还没发），或落在 3 / 6 / 9 / 12 月（上一季财报季已结束），判为淡季，输出顶部加一行"本周处于财报淡季"；其余时间按旺季处理。窗口内已发财报、代码合规的公司数（日历腿 + 新闻腿去重，市值不限）只作辅助说明，写"已知至少 N 家"，**不再作判据**——日历腿只盖住一两天，这个数只是下限（2026-10-08 实测按计数得 14 家，漏掉的 STZ、LW、RPM 补上就有 17 家，判淡季与否全看哪几页被翻到）。

**腿②：成交活跃榜（1 额度）——今天在动的票**

```
metrics(query="most active stocks", asset_type="tradfi", limit=30)
```
返回行只有 symbol / name / price / change / changesPercentage。剔除基金类（ETF、杠杆和反向产品）：`name` 匹配 `\bETFs?\b|\bETNs?\b|ProShares|Direxion|Leverage Shares|GraniteShares|Tradr|Defiance|T-Rex|MicroSectors|iPath|SPDR|iShares|Vanguard|Invesco (QQQ|DB)|Grayscale|Teucrium|\b(Bitcoin|Ether(eum)?|Crypto|Gold|Silver|Platinum|Palladium|Oil|Gas|Gasoline|Agriculture|Commodity|Index) (Funds?|Trust|Shares)\b`（不区分大小写）即剔，再加代码黑名单 `QQQ|SPY|IWM|DIA|SOXX`。口径与 `Community Skill/c1` 的 2026-10-08 定稿一致：按发行商名接住名字里不带 ETF 的杠杆 / 反向产品（TQQQ 叫 ProShares UltraPro QQQ，RWM 叫 ProShares - Short Russell2000）；**不再单独用 `Ultra|Bull|Bear|Daily|Short|Inverse|Trust` 判**——会误杀 Ultra Clean、Daily Journal、Northern Trust 这类正常公司。2026-10-08 活跃榜 30 行用新正则剔掉的 11 只与旧正则相同（SOXS、SOXL、BKLC、KORU、PLTD、TQQQ、IBIT、SQQQ、BITO、TSLL、EWZ），无误杀。
**不要用股价做过滤**（GRAB 股价 3 美元、市值 120 亿美元以上）。仙股交给 Step 2 的市值闸。
这条腿是当日快照，回答的是"今天哪些票在异动"，不覆盖整个窗口。**活跃榜的票只有同时出现在日历腿或新闻腿（说明刚发了财报）时才送 Step 2**——实测 18 只活跃票花了 4 次调用，0 只在窗口内发过财报。其余的不送验，只在输出里提一句当日异动。

**腿③：新闻反向捞（0 额度）——日历漏掉的票**

```
news(query="record quarterly revenue results", sources=["media"], time_range="<days>d", limit=10)
news(query="earnings beat raised guidance", time_range="<days>d", limit=10)
```
- 用**陈述业绩事实**的句式。"earnings surprise stock surges" 这类情绪句式命中率很低。
- 第二条不限来源：返回媒体和社交两桶（各 `limit` 条），社交桶里美股代码密度更高，两桶都解析。
- 抽取 `NASDAQ:XXX` / `NYSE:XXX` / `$XXX` / 明确的美国上市公司名。
- 剔除三类噪音：**非美股**（印度、港股、A 股、日韩欧、加密、纯宏观）；**财报预告**（`will release` / `set to announce` / `ahead of` / `stocks to watch this week` 这类语气——一篇"本周十大看点"能带进六七只还没发财报的票。**但预告里写的发布时点已在窗口内过去的，算"已发"的证据，不剔**——2026-10-08 实测 APLD 在新闻腿里只出现一条 10-07 下午的 "reports earnings after the bell"，剔掉它，本周唯一过业绩闸的票连 Step 2 都进不去）；**非本季财报事件**（交付量超预期、评级首覆或变动、同业跟涨、旧季度回顾）。
- 第二条 query 里的 "beat" 会被解析成加密实体（warning `asset_type_no_matching_keyword`），混进无关内容，逐条判断时剔掉（2026-10-08 复跑没出这条 warning，社交桶照样是游戏、政治里的 "beat"）。
- 命中率波动很大，只用它补名单，不拿命中数做任何阈值。
- **这条腿默认按时间倒序，只盖住最近几个小时**：2026-10-08 美东上午实测，第一条 10 篇媒体稿全在 3.4 小时内。记下两条返回里最早一条的 `published_ts`，输出里写"新闻腿覆盖 [最早时间]~现在"。日历末行到这个时间之间是两条腿都没盖住的空档（同日 10-06 发财报的 STZ、LW、RPM 都落在空档里，没进候选池），如实写进数据缺口。改用 `sort_by="relevance"` 能铺开到整个窗口，但同日实测第一条改相关度排序只带出日历腿已有的 ACN、PEP 和窗口外的 MU，另试 "quarterly results revenue estimates shares" 也只多出 APLD，STZ、LW、RPM 仍不在，所以不改。

三条腿取并集去重 → 候选池，记录每只票的来源（日历 / 活跃榜 / 新闻，可多选）。日历腿里营收 surprise 已经 < +2% 的，直接淘汰，不必送 Step 2。

---

### Step 2 — 取数 + 业绩硬闸（每 5 个候选 1 额度）

```
metrics(keywords=[<T1>…<T5>], categories=["market","fundamentals"], asset_type="tradfi", limit=1, verbosity="concise")
```
**不写 query、`limit=1`，带 `categories`**——一次调用同时给到（约 3~5 KB / 票）。不带 `categories` 时会多返回一条宏观日历（实测 MU 被匹配成 "Fed Musalem Speech"、NU 被匹配成南非 PMI）和每只票一条 `kw_not_canonical` warning，数据本身一样，但容易被误当成"取数有问题"：

| 位置 | 用途 |
|---|---|
| `market.snapshot[].marketCap` / `change` / `previousClose` | 市值；当日涨跌 = `change ÷ previousClose × 100`（`change` 是美元变动量）|
| `fundamentals.concise[].fiscal_quarters[0].earnings_surprise` | `actual_revenue` / `estimated_revenue` / `revenue_surprise_pct` / `actual_eps` / `estimated_eps` / `eps_surprise_pct` / **`report_date`** |
| `…fiscal_quarters[0].financial_statement` | 财报口径的 `epsDiluted`（GAAP 稀释，口径核对用这个，不用基本 EPS `eps`）/ `netIncome` / `period_end` |
| `…profile_block.isEtf` | 为 `true` 的直接剔除（名称正则漏掉的 ETF 在这里兜底）|
| `…profile_block.exchange` | 为 `"OTC"` 的直接剔除（日历正则漏掉的 OTC 外国股在这里兜底；2026-10-08 实测 SOIEF）|
| `…next_earnings_estimate.date` | 下次财报日（前瞻板块用）|

#### 数据完整性四道检查

按顺序做，任何一道不过就记数据缺口、淘汰，**不要当 0 处理**：

| # | 检查 | 方法 |
|---|------|------|
| 1 | 有没有被挤出本批 | `meta.warnings` 里有没有该 ticker 的 `keyword_count_over_max`；`meta.filters_applied.keywords` 对照请求清单。被挤出的并入下一批补调（最多补 1 次）|
| 2 | 有没有基本面条目 | `fundamentals.concise[].symbol` 里有没有它（有快照没基本面的情况存在）|
| 3 | 有没有超预期数据 | `fiscal_quarters[0].earnings_surprise` 是否存在。**不存在时先看是不是"这期还没发"**：`financial_statement.period_end` 早于窗口、且 `next_earnings_estimate.date` 在未来的，归"窗口外"，不记数据缺口（实测 NU、NOK、AMOD 都是这种）。**但 `next_earnings_estimate.date − period_end` 超过 150 天时不能这么判**：那是这季已经发了、`next_earnings_estimate` 先滚到了下一季，`fiscal_quarters` 还停在上一季（2026-10-08 实测 APLD 10-07 发财报，次日仍是 `period_end` 05-31、下次财报日 2027-01-06，相隔 220 天；10-06 发的 STZ、LW、RPM 两天后同样如此；同日美东上午复跑，APLD、STZ 已更新，LW、RPM 仍没有——更新时点因票而异）。按"窗口内已发"处理，转下面新鲜度表的第 2 / 3 行取数。**`next_earnings_estimate.date` 落在窗口内、且已经过去的，同样按"窗口内已发"处理**（2026-10-08 实测 LGCL：下次财报日 10-07，`fiscal_quarters` 还停在 2025-12-31，新闻里 10-08 已有上半年业绩稿）|
| 4 | 字段是不是真有值 | `actual_revenue` 非 null。**`revenue_surprise_pct == -100` 一律当缺失**——`actual_revenue` 为 null 时服务端会算出 -100，那不是营收归零 |

#### 新鲜度：先判这一季是不是刚发的

看 `earnings_surprise.report_date` 是否落在 `days` 窗口内。

| 情况 | 处理 |
|------|------|
| 在窗口内 | 用 `earnings_surprise` 的数过硬闸 |
| 在窗口外，**但日历腿显示它在窗口内已发布** | 基本面块还没更新（2026-10-01 实测 MU 9-30 发财报，当时 `report_date` 仍是 6-24 的上一季；10-03 已更新）。**改用日历行的 actual / estimated 自己算 surprise** 过硬闸，并标注"数据取自财报日历行，基本面块尚未更新"。日历行与基本面块同属一个数据源，算出的 surprise 一致。此时做不了口径核对，标"口径未核对" |
| 在窗口外，日历腿里也没有，但新闻明确说它刚发了财报 | `news(query="<公司名> <TICKER>")` 取媒体原文的实际值与预期值。新闻里只有实际值、没有预期值时，再 WebSearch 一次 `"<公司名> <季度> revenue estimate"`，取**财报前**的一致预期（多家数字不同取中间那个），标"预期值来自网页"、"口径未核对"。还取不到才记数据缺口，不参与排序。2026-10-08 实测 APLD：Followin 新闻只给出营收 3.419 亿美元、同比 +322%，没有预期值，WebSearch 查到财报前预期约 1.19~1.35 亿美元——不补这一步，本周唯一过业绩闸的票会被当成数据缺口 |
| 在窗口外，也没有近期财报的证据 | 淘汰出主榜。`next_earnings_estimate.date` 落在未来 `days` 天内的，进「📅 即将发财报」|

#### 四道硬闸（全过才进 Step 3）

**闸① 营收**：营收 surprise ≥ **+2%**。不过直接淘汰，不看 EPS。
> 打分一律用 Followin 的数（基本面块 / 日历行，财报口径营收）。营收 surprise ≥ +100% 时不改分，但在观察区和判定表里写明口径：「Followin 财报口径 +X%」，媒体给了公司调整后口径的实际值与预期值时并列「公司调整后口径 +Y%」。2026-10-08 实测 APLD：财报口径 3.419 亿对 1.163 亿（+194%）；公司调整后营收 3.004 亿（剔除 ChronoScale 4,150 万）对 Benzinga 预期 1.322 亿（+127%）。
> 低基数的 EPS 会骗人：实测 AAL 的 EPS surprise 是 +400%（预期只有 $0.03），营收只超 0.2%；T 的 EPS +10% 而营收 −0.7%。两者都该淘汰。

**闸② 市值** ≥ **20 亿美元**

**闸③ 业绩闸得分 ≥ 24**（这就是 Step 5 的"业绩闸"分数，在这里一次算好）：

| 营收 surprise | 分 | | EPS surprise | 分 |
|---|---|---|---|---|
| ≥ +10% | 20 | | ≥ +30% | 20 |
| ≥ +5% | 14 | | ≥ +15% | 14 |
| ≥ +2% | 8 | | ≥ +5% | 8 |
| | | | < +5% | 0 |

**EPS 扭曲判定**——命中任一条，EPS 项得分 ÷2 并标注：
- EPS surprise **≥ 100%**（含 100%）
- **两个 EPS 符号相反**：`earnings_surprise.actual_eps` 为正而 `financial_statement.epsDiluted` 为负。前者是分析师口径（调整后），后者是财报口径（GAAP）。实测 INTC：分析师口径 0.42（超预期 100%），GAAP 是 −2.16、净亏 110 亿美元——只看前者会把巨亏季读成"完美超预期"。输出里必须写"该超预期为调整后口径，本季 GAAP 为亏损"。
- 两个 EPS 同号但差距大：`|actual_eps − epsDiluted| ÷ |actual_eps| > 20%` 时不减分，但在输出里标"调整后口径"。
- EPS 与营收严重背离且找不到经营性解释

> 🔒 **24 分线和 Step 5 的 🎯 判定是同一条线**，改打分口径时两处一起改。否则卡在线下的候选无论关键词扫出什么都进不了终榜，白花深扫的成本。
> 这条线的实际含义：营收超 2%~5% 的需要 EPS 超 30% 以上；营收超 5%~10% 的需要 EPS 超 15% 以上；营收超 10% 以上的需要 EPS 超 5% 以上。
> 本闸只衡量**相对一致预期的超出幅度**，不衡量增速和指引。高增速、低超预期的票会被刻意排除（实测 MU 营收同比 +379%、超预期 5.6%、业绩闸 22 分被淘汰）——所以输出里要单列"窗口内已发、业绩闸未过"的表，让读者知道它们被考虑过。

**闸④ 新鲜度**：见上一节，窗口外且无近期财报证据的不进主榜。

---

### Step 3 — 关键词深扫（幸存者按营收 surprise 降序取 Top N）

目标是拿到**管理层在财报电话会或财报新闻稿里的原话**。按下面的顺序找来源，拿到够用的就停：

**来源 A：公开的电话会实录（Web）**
```
1. 先跑来源 C 的 news(query="<公司名> <TICKER>")（0 额度），返回里常直接带实录或新闻稿链接（实测 CarMax 返回了 fool.com 的实录页），省掉一次 WebSearch
2. 没有链接再 WebSearch: "<公司名> <季度> earnings call transcript"
3. WebFetch 实录页，prompt 里要求"逐字摘录（verbatim）含以下表述的句子"
```
- 新闻稿通常只有几句 CEO 套话，扫不了 7 类关键词，只作补充，不能代替实录。
- WebFetch 返回的是小模型加工过的文本：同一页抓两次给出的引语集合不同，还会有省略号和拼接错误。摘录标"WebFetch 摘取、未逐字核对"。
- 每只票预算：WebFetch ≤ 2 次。gurufocus 的实录页 WebFetch 返回 403（2026-10-08 实测），搜到了也别花预算。

**来源 B：MCP 逐字稿（1 额度，默认不跑）**——只在来源 A 拿不到实录、要判断"已发但实录未上网"时才跑。
```
metrics(keywords=["<T>"], query="earnings call transcript", asset_type="tradfi", verbosity="detail", limit=1)
```
⚠️ **`transcript[0].content` 被截断到 2000 字符（`content_truncated:true`），只有开场白和第一个提问，扫不了关键词。** 这是 `verbosity` 的设计上限，不是临时故障。所以它排在 Web 之后，只用来确认"这一季的实录是否已入库"：看 `transcript[0].date` 是否等于本次财报日，且正文开头是主场电话会——"Post-Earnings Analyst Call" / "Analyst Day" 不算本季实录。实录入库可能比基本面块早（2026-10-08 实测 APLD 10-07 的主场电话会次日已在，`fiscal_quarters` 还是上一季），所以它也能佐证"这季已经发了"。

**来源 C：新闻**
```
news(query="<公司名> <TICKER>", time_range="<days>d", limit=10)
```
用"公司名 + 代码"两个词，不用长句（长句式只适合 Step 1 那种不指定公司的宽泛捞取）。新闻里的管理层引语可以算命中，记者自己的转述不算。
`news()` 查不到相关内容时不返回空，而是返回一批固定的热门内容。**返回里一条都不含目标公司名或代码 = 没查到**，不要重试（重试、换措辞返回的都是同一批）；两只不同的票如果返回一模一样的内容，说明两只都没查到。

**三个来源都拿不到管理层原话**：该票的关键词闸标**"欠测"**，不是低分——低分的意思是"扫了但没讲高景气"，欠测是"根本没扫到"，两者对下一步的指示完全相反。欠测的票进 👀 观察区，不占 Top N 名额（顺延给下一个幸存者）。

**只拿到新闻稿、没拿到实录**：关键词分照算，但判定写"👀 观察：仅新闻稿，实录未上网"，不要写成"管理层没怎么讲高景气"——新闻稿本来就扫不出几类。财报后一两天公开实录常常还没上网（2026-10-08 实测 APLD 财报次日 WebSearch 只搜到往季实录），新闻稿可直接 WebFetch SEC EDGAR 上 8-K 附的 earnings release。

每个命中记录四要素：

| 要素 | 说明 |
|------|------|
| 类别 | 7 类中的哪一类 |
| 原文摘录 | 一句原文（**必须有，给不出原文的不算命中**）|
| 发言人 | CEO / CFO / IR 等 |
| 语境 | 主动陈述 / 问答确认 / 负面语境（作废）|

输出里注明每只票的关键词来自哪个来源（实录 / 新闻稿 / 新闻引语）。

**（可选）财报后累计涨跌**：默认打分用当日涨跌。要算"财报日至今"的真实反应，对 Top N 各加一次
`metrics(keywords=["<T>"], query="历史走势", asset_type="tradfi", time_range="3m", limit=70)`。
累计涨跌 = 最新收盘 ÷ 财报日前一交易日收盘 − 1；不要用日线的 `change` / `changePercent`（那是当日收盘减开盘）。

---

### Step 4 — 前瞻板块

前瞻窗口默认是未来 `days` 天；**淡季时（见 Step 1 腿①）扩到 14 天**——10 月第一周窗口内多是财年错开的公司（2026-10-08 已知 17 家，ACN、NKE、PEP、STZ 这类 8~9 月季末的公司），真正的财报季从中旬的银行开始，看 7 天会什么都看不到。

**来自候选池**（0 额度）：Step 2 每只票都返回了 `next_earnings_estimate.date`。落在前瞻窗口内且市值 ≥ 20 亿美元的，列进「📅 即将发财报」。候选池里多是刚发完财报的票，下次财报日在一个季度后，这一路通常是空的（2026-10-08 实测 13 只取数，0 只落在 14 天内）。

**来自财报日历**（1 额度，**默认不跑**）：
```
metrics(query="earnings calendar", asset_type="tradfi",
        date_from="<今天>", date_to="<今天 + 前瞻窗口>", limit=50)
```
按调用约定里的排序，这一页从今天的 `0`~`9` 开头代码排起，到不了未来日期。2026-10-08 实测 `date_from` 今天、前瞻 14 天：50 行全是 10-08 当天，末行停在 "AEONTS.BK"，过完正则一只美股都没有。只有用户明确要市场级名单时才跑，并且照腿①的规则过滤、看末行 `date`；末行仍是今天就写"日历前瞻未覆盖"，不翻页硬凑。返回行没有公司名和市值；这两列写"—"，并注明"日历覆盖不完整、未过市值闸"。

**来自 watchlist**（传了才做，每 5 只 1 额度）：用 Step 2 同样的调用查，取 `next_earnings_estimate.date`。这是三者里唯一对指定名单保证准确的。**淡季且用户没传 watchlist 时，在输出里提示"传 watchlist 才能看到即将发财报的名单"**——另外两路基本拿不到东西。

---

### Step 5 — 打分出榜

按下方口径打分排序。业绩闸分数在 Step 2 已算出，直接沿用。

**成本参考**：日历 1~2 + 活跃榜 1 + 新闻 0 + 取数 ⌈候选数 ÷ 5⌉ + watchlist ⌈只数 ÷ 5⌉（前瞻日历、深扫来源 B 默认不跑；来源 B 只在来源 A 拿不到实录时每只 1）。WebSearch 另计：新闻取不到预期值的票各 1 次，深扫每只 ≤1 次。上下文的大头是 Step 3 的网页原文，候选多时建议独立会话跑。

---

## 关键词库

### 正向（7 类）

| 类别 | 检测表述 |
|------|--------------------|
| 产品供不应求 | sold out · supply cannot meet demand · capacity constrained · allocation · backlog growing |
| 行业高景气上行 | industry tailwinds · secular growth · up-cycle · structural demand |
| 市场超预期拓展 | expanding faster than expected · TAM expansion · new market traction · meaningfully ahead of expectations |
| 新品持续超预期 | new product exceeded expectations · ramp ahead of schedule · strong adoption |
| 价格中枢上涨 | pricing power · price increases · ASP up · favorable pricing |
| 供给偏紧 | supply tight · lead times extended · constrained supply · supply constraints |
| 需求旺盛 | robust demand · record demand · demand outpacing supply |

### 反向（减分项，防确认偏误）

| 组 | 表述 |
|---|---|
| 需求 / 价格 / 库存 | pricing pressure · demand softening · inventory correction · guidance cut / lowered outlook · elevated inventory |
| **资本开支 / 盈利质量** | CapEx raised / above prior expectations · pressure on operating margins · margin dilution · free cash flow pressure · impairment / write-down · restructuring charge · elevated costs · FX headwind |

资本开支组是必扫项。实测 INTC 财报日跌 8%，只扫需求侧反向词命中 0 条——真正的空头论据是 CFO 说的"CapEx 将超过 200 亿美元，显著高于年初预期"。只扫需求侧，会对 AI 财报季最主要的空头叙事完全失明。

### 检测原则

1. **按语义匹配，不是字面搜索**——同义表述算命中，但必须能给出原文摘录
2. **负面语境命中作废**：命中句所在段落同时出现 `dilutive` / `declined` / `offset by` / `partially offset` / `headwind` / `pressure` 的，判无效，并在输出里说明为何否决
   > 实测 CMCSA："we continue to see strong adoption of free wireless lines, **which is initially dilutive to broadband ARPU**… broadband ARPU declined 3.8%"——字面命中"新品持续超预期"，语义是负面。
3. **别只找多头证据**。一家公司可以既说需求旺盛，又在另一段承认价格承压或上修资本开支。

---

## 打分口径（0-100）

### 业绩闸（40 分）

见 Step 2 闸③ 的分档表（含 EPS 扭曲 ÷2 规则）。

### 关键词闸（40 分）

- 每命中一个正向类别 +5（7 类共 35）
- 语境权重：主动陈述 ×1.0 ｜ 问答确认 ×0.6 ｜ 负面语境 ×0
- 命中带量化数字佐证（如"数据中心营收同比 +59%，明显高于预期"）：该类别再 +1
- 每命中一组反向词 −5
- 合计封顶 40，下限 0

### 盘面确认（20 分）

用 Step 2 快照自算的**当日涨跌**：≥ +5% → 20 ｜ +2% ~ +5% → 14 ｜ 0 ~ +2% → 8 ｜ −2% ~ 0 → 4 ｜ < −2% → 0

当日涨跌不等于财报反应（窗口大于 1 天时尤其如此），输出必须写明这一维用的是当日数据。非交易时段跑，快照是上一个常规收盘。
跌超 2% 时标注"可能尚未反映，也可能市场看到了财报之外的东西"——不要单方面解读成机会。业绩和关键词接近满分而股价大跌，这个分歧本身就是研究入口。

### 判定

能走到这一步的票都已过业绩闸（≥24）。

| 关键词闸 | 判定 |
|------|------|
| ≥ 20 | 🎯 重点关注（= 方法论的"2 + 3 叠加"）|
| < 20 | 👀 观察：业绩过线，但管理层没怎么讲高景气 |
| 欠测 | 👀 观察：业绩过线，没拿到管理层原话 |
| 只有新闻稿（< 20）| 👀 观察：业绩过线，仅新闻稿、实录未上网（见 Step 3）|

营收 surprise ≥ +100% 的票，判定后面加注口径（「Followin 财报口径 +X% / 公司调整后口径 +Y%」，见 Step 2 闸①）。

Step 2 淘汰的不进明细；其中**窗口内已发财报、只是业绩闸没过**的，列进输出里的"窗口内已发、业绩闸未过"表——淡季时这张表往往是主要信息。

---

## 输出模板

```
## 🔍 财报季超预期扫描 — [日期]（窗口 [N] 天）

[淡季时] ⚠️ 本周处于财报淡季（按日期判定），窗口内已知至少 [n] 家发布财报。

候选池：日历 [a] + 活跃榜 [b] + 新闻 [c]，去重后 **[X] 个送验**
→ 取到数据 [X'] → 窗口内已发财报 [W] → 过硬闸 [Y] → 深扫 [min(Y, top)]

### 终榜（只列 🎯；没有就写"本轮无 🎯（窗口内已发财报 [W] 家）"）
| # | Ticker | 公司 | 营收 Surprise | EPS Surprise | 关键词 | 当日盘面 | 总分 | 判定 |
|---|--------|------|--------------|-------------|--------|---------|------|------|

### 🎯 [TICKER] — [公司名]（总分 XX）

**业绩**：营收 $XXB（+X.X% vs 预期）｜EPS $X.XX（+X.X%）[调整后口径 / GAAP 为亏损 / 口径未核对]
**来源**：日历 / 活跃榜 / 新闻 ｜ **市值**：$XXB ｜ **财报日**：[date] ｜ **数据取自**：基本面块 / 财报日历行 / 新闻 + 网页预期值

**关键词命中（[n]/7 类，来源：实录 / 新闻稿 / 新闻引语）**：
- **[类别]**：「[原文摘录]」— [发言人]（[主动陈述 / 问答确认]）
- **[反向]**：「[原文摘录]」— [发言人] ⚠️
- **[作废]**：「[原文摘录]」— 负面语境否决，因 [理由]

**一句话 thesis**：[综合判断]

### 👀 观察区（过了业绩闸、关键词闸不够或欠测）
| 标的 | 业绩闸 | 关键词闸 | 说明（营收 surprise ≥ +100% 时写口径：Followin 财报口径 / 公司调整后口径）|

### 窗口内已发、业绩闸未过
| Ticker | 营收 Surprise | EPS Surprise | 业绩闸分 | 备注 |
|--------|--------------|-------------|---------|------|

> 本闸只衡量相对一致预期的超出幅度，不衡量增速和指引。

### 📅 即将发财报（未来 [N] 天）
| Ticker | 公司 | 预计财报日 | 市值 | 来源 |
|--------|------|-----------|------|------|

> 名单来自本轮候选池 [+ 财报日历] [+ watchlist]。财报日历覆盖不完整，这不是全市场名单；日历来源的行没有公司名和市值，写"—"。

### 数据缺口
- 财报日历腿只覆盖 [date_from]~[末行日期]（末行当天只到 [末行代码]），之后的日子靠新闻腿补（单页按日期从早到晚、同日按字母序排，见调用约定）
- 新闻腿按时间倒序，只覆盖 [最早一条的时间]~现在；[末行日期]~[该时间] 之间两条腿都没盖住
- 活跃榜为**当日快照**，非 [N] 天全窗口
- 取不到数据的 ticker：[列出]
- 基本面块未更新、改用日历行 / 新闻 / 网页预期值的：[列出]
- 窗口外淘汰的：[列出]
- 关键词欠测的：[列出]

> ⚠️ 盘面一维用的是**当日**涨跌，不等于财报后累计反应。
> ⚠️ 本扫描输出的是"值得进一步研究"的线索，不是投资建议。关键词是管理层的说法，不是已兑现的事实。
```

---

## 输出规则

- 关键词命中**必须附原文摘录**，给不出原文的不算命中
- 区分"主动说" / "被问出来" / "负面语境作废"三态
- 口径问题必须点明：「该超预期为调整后口径，本季 GAAP 为亏损」
- 景气判断标注"Claude 推断"
- 数据缺口如实列，**宁可报告不全也不要假装扫全了**
- 终榜是线索清单，不是买入清单
