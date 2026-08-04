---
name: Earnings Season Screener
description: 财报季超预期扫描 — 扫近期已发布的美股财报，找"业绩大增 × 电话会喊出高景气关键词"的叠加候选榜。无需指定 ticker 的发现器。触发如"财报季扫描"、"本周谁业绩大增"、"earnings screener"。点名单股的财报分析走 Base Skill 02（美股财报分析）。
trigger: 财报季扫描、超预期扫描、本周财报超预期、谁业绩大增、财报季选股、扫一下财报季、earnings screener、earnings season scan、who beat earnings、find earnings beats
not_trigger: XX财报、[代码]财报（点名单股→02）、背离扫描、divergence（→03）、宏观早报、morning brief（→06）、BTC宏观、黄金宏观、KOL、喊单、多Agent分析
mcp: mcp__followin__metrics, mcp__followin__news
args: days, top, watchlist
---

# /earnings-season-screener $ARGUMENTS

财报季超预期扫描 — 把"挨个看业绩大增公司的财报，找高景气表述"这套人肉流程自动化（Followin MCP 版）

> **版本**：v1.5 ｜ **实测验证于 2026-07-27 ~ 2026-07-29**
>
> ⚠️ **本文所有 ⚠️ 与阈值都是那三天对 Followin MCP 的实测结果，不是推断。MCP 行为会变。**
> 其中多条是上游 bug 的规避——**上游修好之后，这些规避会朝反方向出错**（例如日历修好了却仍在教你别用）。
> 登记表里每条都记了「Dev 修复后回滚动作」，见 `references/followin-mcp-caveats.md`。
>
> **隔一段时间再用，先花几分钟自查这 5 条**（本文件常被复制到 `~/.claude/commands/` 单独使用）：
> ① 日历 `metrics(asset_type="tradfi", query="earnings calendar", date_from=<7天前>, date_to=<今天>, limit=100)` —— `total` 仍是 50 且同一天 = 未修
> ② `country` 过滤：同上调用传与不传 `country="US"`，逐行相同 = 未修
> ③ 数组参数：`metrics(asset_type="tradfi", keywords=["AAPL"])` 报 `-32602` = 未修
> ④ ticker 字典：`metrics(asset_type="tradfi", query="JBLU next earnings date")` 返 `keywords: null` = 未修
> ⑤ 逐字稿判据：`transcript[0].period` 是否仍恒等于 `latest_quarter.period`

## 参数

| 参数 | 必填 | 默认 | 说明 |
|------|------|------|------|
| days | 否 | 7 | 扫描窗口（**三处共用**：新闻腿回看 / 财报新鲜度闸 / 前瞻板块的未来天数）|
| top | 否 | 5 | 逐字稿深扫上限。幸存者不足 top 就扫几个，**不要为凑数放宽闸门** |
| watchlist | 否 | — | 空格分隔的 ticker 串。传了则额外查这批的前瞻财报日（每 5 只 1 额度），并入「📅 即将发财报」板块 |

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
| 背离扫描、内部人悄悄买入 | ❌ 转 `Base Skill/03_us-stock-divergence-scan` |
| 宏观早报、今日市场 | ❌ 转 `Base Skill/06_macro-morning-brief` |

> 🔗 **通用调用红线 + 已知问题登记**：以 `~/.claude/references/followin-mcp-caveats.md` 为准（仓库内 `references/`）。本文内联 caveat 是其镜像，冲突时以该文件为准。
>
> 📐 **方法论映射与被否决的方案**：见同目录 [`README.md`](./README.md)。

---

## 执行流水线（5 步）

🔒 全程美股：**除 `news()` 外所有调用必带 `asset_type="tradfi"`**
🔒 **数组参数全域被拒（N-8）**：`keywords`/`categories`/`sources` 一律走 query 串

> ❌ **不要用财报日历做发现腿**（N-22）。**单一根因**：服务端等效 `ORDER BY date ASC, symbol ASC LIMIT 50`，`limit` 入参不被尊重。派生表象：历史区间看似"只覆盖首日"（当天就 >50 行）；未来区间可跨天但仍断在第 50 行；字母序让 GOOGL/MSFT/NVDA/TSLA 在密集日必然出局。
>
> **2026-07-29 复测未修复，且所有客户端杠杆已穷尽**：`limit=100` / `country="US"` / `include_penny_stocks=false` / 改写 query / 逐日拆分 —— **五种全部返回逐行一致的结果**（`include_penny_stocks` 连 `filters_applied` 回显都没有）。
> 📌 偏置的极端例证：2026-07-22 的 50 行里**无后缀美股 = 0 只**；其中 Alphabet 以法兰克福的 `ABEA.F` 身份出现，而 `GOOGL` 因字母序永远进不来——**同一家公司，首字符决定生死**。

---

### Step 1 — 发现·腿①：异动榜（1 额度）

```
metrics(asset_type="tradfi", query="most active stocks", limit=30)
```

返回 `market.most_active`：symbol / name / price / change / changesPercentage。**无 marketCap**（红线 9），市值在 Step 3 一并补。

**只做一道过滤——剔除 ETF / 杠杆产品**：

`name` 命中以下任一正则即剔：`ETF | ETN | UltraPro | Ultra | Leveraged | \dX | 2x | Bull | Bear | Daily`
再加指数代号黑名单兜底：`QQQ | SPY | IWM | DIA | SOXX`

⚠️ **不要只用 "ETF" 一词判断**（实测反例）：`ProShares UltraPro QQQ`(TQQQ) 和 `ProShares - UltraPro Short QQQ`(SQQQ) 的 name **都不含 "ETF" 字串**，单词规则漏网。而 `Direxion Daily TSLA Bull 2X ETF`(TSLL)、`GraniteShares 2x Short NVDA Daily ETF`(NVD)、`ProShares Bitcoin ETF`(BITO)、`Direxion Daily Semiconductor Bull/Bear 3X ETF`(SOXL/SOXS)、`Direxion Daily S&P 500 Bear 1X ETF`(SPDN) 才含。

❌ **不要用价格闸**（`price < $5`）：实测 GRAB $3.31 被误杀，实际市值 **$131 亿**且业绩闸达标。Step 3 的市值闸是更准的同类过滤，价格闸只贡献误杀。仙股（VIVK/LVWR/OTLK）和妖股（STAK +602% 但市值 $0.93 亿）交给市值闸拦——多花的验证额度远低于漏掉真标的的代价。

⚠️ **这条腿是当日快照，不是 N 天窗口**。它答的是"今天哪些票在异动"——实测捞到 INTC −7.9% / T +5.1% / AAL +6.8% / CLF +8.9% / PATH +6.3%。历史区间靠腿②补。

> 💡 AAL 正是 caveats N-17 记载"财报日历漏掉"的那只票——异动榜捞得到。这就是换腿的理由。

---

### Step 2 — 发现·腿②：新闻反向捞（0 额度）

两条 query，**不传 `sources`、不传 `asset_type`**（N-8 数组被拒；news 带 asset_type 实测返 0）：

```
news(query="record quarterly revenue results", time_range="<days>d", limit=10)   # 两条里命中率更高的
news(query="earnings beat raised guidance",    time_range="<days>d", limit=10)
```

⚠️ **命中率是波动的，别把具体分数当基准**：两条 query 在 2026-07-23 实测为 13/20 与 8/20，07-27 复测降到 8/20 与 6/20（同为 7d/limit=10）。**相对优劣顺序稳定，绝对值不稳定**——用它排序可以，用它设阈值不行。

⚠️ **`limit=N` 实际返回 2N 条**（N 篇 articles + N 条 social，N-25），估算体积按 2N 算。
⚠️ **social 桶的美股 ticker 密度高于 articles 桶**，两桶都要解析。

抽取模式：`NASDAQ:XXX` / `NYSE:XXX` / `$XXX` / 明确的美国上市公司名。

**必须剔除的两类噪音**：

| 类型 | 规则 |
|------|------|
| 非美股 | 印度股、港股、A 股、日韩欧股、加密、纯宏观、体育新闻 |
| **财报预告** | 文章语气为 `will release` / `gears up for` / `set to announce` / `ahead of` / `stocks to watch this week` → **标记为预告，不进候选池** |

⚠️ 预告文章是主要污染源：实测「Big Tech Earnings Take Center Stage: 10 Stocks to Watch This Week」一篇就带进 MSFT/META/AAPL/LLY/RCL/NUE 六个**还没发财报**的名字，照单全收会白烧 Step 3 额度。

> ❌ **不要用"情绪/涨跌"句式**（N-26）：`earnings surprise stock surges` 实测仅 3/20 有效；`beat` 一词还会撞上棒球比分报道和加密代币 $BEAT。用**陈述业绩事实**的句式。

---

### Step 3 — 合并 + 业绩硬闸（每 5 个候选 1 额度）

两腿取并集去重 → 候选池，记录来源（异动榜独有 / 新闻腿独有 / 双腿命中）。

**逐批验证，每批最多 5 个 ticker**：

```
metrics(asset_type="tradfi", query="<T1> <T2> <T3> <T4> <T5> next earnings date")
```

一次调用同时给到（约 11 KB / 5 票）：
- `fundamentals.concise[].beat_miss` → EPS/营收 actual vs estimated **+ date（新鲜度判定用）**
- `fundamentals.concise[].latest_quarter.eps` → GAAP EPS（口径错位判定用）
- `market.snapshot[].marketCap` / `.changesPercentage` → 市值与当日涨跌

⚠️ **`next earnings date` 后缀是省 context 的关键**（N-24）：不加会额外返回 balance_sheet×4 + cash_flow×4 + profile + valuation（8.7 KB/票 → 35 KB/5 票）。附赠的 `earnings_calendar` 是无关副产品，丢弃。

⚠️ **N-14**：query 里除 ticker 外**只允许** `next earnings date` 后缀。禁用 `beat`/`miss`/`surprise`/`hold`/`buy`/`call` 等英文词。中文词（财报/超预期）安全但**对返回内容零影响**，纯浪费字符。

⚠️ **有"影子代码"的 ticker 会吃掉批次名额**（N-36）：某些 ticker 被**展开成两个 symbol**，占掉 2 个名额，把该批最后一个请求项顶出去（**不是解析失败，是名额被挤占**）。实测两类：

| 类型 | 实测 | 风险符号 |
|---|---|---|
| **与商品重名** | `CL`（高露洁）→ `CL` + `CL=F`（原油期货），顶掉 NUE | `CL` / `GC`(黄金) / `SI`(白银) / `NG`(天然气) / `HG`(铜) |
| **中概 ADR 双重上市** | `BABA` → `BABA` + `9988.HK`（港股），顶掉 LI | `BABA` / `JD` / `NTES` / `BIDU` 等在港二次上市的中概 |

→ 含这些符号时**该批按 4 个装**，或把它单独放一批。调用后照例核对 `filters_applied.keywords` 做差集。

#### 数据完整性三道差集（N-23）

⚠️ **只查 `keywords` 差集不够**——实测存在"keywords 解析成功但拿不到数据"的形态，单查会误判为成功。按顺序做三道检查：

| # | 检查 | 方法 | 失败时 |
|---|------|------|--------|
| **1** | ticker 是否被解析 | `meta.filters_applied.keywords` vs 请求清单 | 见下方补调规则 |
| **2** | 是否真拿到基本面 | **`results.fundamentals.concise[].symbol`** vs 请求清单 | 记数据缺口，淘汰 |
| **3** | 是否有 beat_miss | 逐条查 `concise[i].beat_miss` **是否存在** | 记数据缺口，淘汰 |
| **4** | **字段是否真有值** | `beat_miss.revenueActual` **非 null**；若 `revenue_surprise_pct == -100` **一律先当缺失查证** | 记数据缺口，淘汰 |

> 实测反例：**STAK** 正常出现在 `filters_applied.keywords` 里、`market.snapshot` 也有 marketCap，但 `concise` 里**根本没有它的条目**——只做第 1 道差集会是空集，误判成拿到了数据。
> **SPCX** 有 `concise` 条目、有 `latest_quarter` 和 `next_earnings_estimate`，唯独**整块 `beat_miss` 缺失**——闸① 直接读 `beat_miss.revenue_surprise_pct` 会拿到 undefined。
> ⚠️ **第 4 道是最危险的一种**（实测 F/Ford）：`beat_miss` 存在且结构完整，但 `revenueActual: null`，服务端**把 null 当 0 参与减法**，直接给出 `revenue_diff = -47237900000`、`revenue_surprise_pct = -100`。**前三道全部通过**，闸① 读到的是"营收暴跌 100%"这个假真值——这不是缺失被识别，是**缺失被伪装成极端真值**。`-100` 这个数在真实世界里几乎不可能（营收归零），见到就要当缺失查。

#### 补调规则（第 1 道差集失败时）

先看 warning 形态区分两种故障，**能省掉一整轮补调**：

| warning 形态 | 含义 | 处理 |
|---|---|---|
| warning 里 `keyword` 是**整个 query 串**（如 `"VIVK LVWR OTLK next earnings date"`）| **整批全废**，批内无一 ticker 可解析 | **直接全部记缺口，不补调** |
| 成功的 ticker **各自出一条独立 warning** | 部分缺失 | 缺的**最多补调 1 次** |

⚠️ **补调最多 1 次**。实测 JBLU（真实 NASDAQ 股）单票调用返回 `keywords: null`，而同形态的 `NOK next earnings date` 正常返回——根因是**该 ticker 不在上游解析字典里，换任何 query 形态都取不回来**，继续重试纯浪费额度。

**已知不可解析清单（实测累计 9 只）**：`JBLU`(JetBlue) / `CUBI`(Customers Bancorp) / `ONDS`(Ondas) / `VIVK`(Vivakor) / `LVWR`(LiveWire) / `OTLK`(Outlook Therapeutics) / `AEHR`(Aehr Test Systems) / `NRC`(National Research) / `WERN`(Werner Enterprises)。
→ **命中清单的直接跳过、0 额度**，不要送验。

**"最多 1 次"是上限不是义务——两种情况可以一次都不补**：

| 情况 | 做法 |
|------|------|
| 已有证据表明该候选**必败某道硬闸** | 直接记缺口。实测 AEHR 单季营收 $1,880 万（Step 2 原文可见），年化远不足以支撑 $2B 市值 → 闸② 必败，补调回来也是淘汰，白烧 1 额度 |
| 补调可**并入下一批**（该批不足 5 只）| 并进去，**0 额外额度**。实测 NRC/WERN 并入末批 `GOOGL HOPE BE NRC WERN`，比单开一次省 1 额度 |

> 💡 优先级：**能并批就并批 > 必败则不补 > 单开补调**。

#### 三道硬闸（全过才进 Step 4）

**闸① 主锚**：营收 surprise ≥ **+2%**（不过直接淘汰，不看 EPS）
> ⚠️ 读之前先过上面第 3 道差集——`beat_miss` 整块缺失时该字段是 undefined，**不要当 0 处理**（会误判成"营收持平"而非"数据缺失"）。无 beat_miss 一律记缺口淘汰。
> 实测反例：AAL 的 EPS 名义 +400%，但预期基数仅 $0.03，是低基数噪音；营收仅 +0.2%。T 的 EPS +10.2% 而营收 −0.75%。两者都该淘汰。

**闸② 市值** ≥ **$2B**

**闸③ 业绩闸得分 ≥ 24** —— 在这里就算出 Step 5 的业绩闸分数，**闸门与终判自对齐**：

| 营收 surprise | 分 | | EPS surprise | 分 |
|---|---|---|---|---|
| ≥+10% | 20 | | ≥+30% | 20 |
| ≥+5% | 14 | | ≥+15% | 14 |
| ≥+2% | 8 | | ≥+5% | 8 |
| | | | <+5% | 0 |

**GAAP 扭曲判定（先判后加总）**，命中任一即 **EPS 项得分 ÷2** 并标注：
- EPS surprise **≥100%**（注意是闭区间——实测 INTC 恰好 100.0%，开区间会漏）
- **`beat_miss.epsActual` 与 `latest_quarter.eps` 反号**（N-29。实测 INTC：`epsActual=0.42` 非 GAAP vs `latest_quarter.eps=−2.16`、`netIncome=−$110.3 亿` GAAP，同处一个 payload 且**无任何字段标明口径**。这种错位比单纯数值大更值得警惕——只看 beat_miss 会把巨亏季读成"完美超预期"）
  > 🔒 **比对前必须先确认两者同季**（N-33）：`beat_miss.date` 与 `latest_quarter.date` 的季度对齐关系**不固定**——实测 F 的 latest_quarter 落后两季（Q1 vs 07-28）、STX 落后一季、V 反而**领先**一季。**不同季则本项判定作废**（标注"口径无法核对"），不要跨季比反号，否则一盈一亏的相邻两季会产生假阳性告警。
- EPS 与营收严重背离且无经营性解释

> 🔒 **闸③ 的 24 分线是从 Step 5 的 🎯 判定反推的。改动打分口径时必须同步改这里**，否则会重现 v1.0 的缺陷：卡在及格线的候选无论逐字稿写什么都进不了终榜，白烧最贵的 transcript 额度（实测 CMCSA 业绩闸锁死 16 分，结论在打开逐字稿前就已注定）。

**闸④ 财报新鲜度**：`beat_miss.date` 必须落在 `days` 窗口内。

| 情况 | 处理 |
|------|------|
| 在窗口内 | 正常进入 Step 4 |
| 在窗口外，且无近期财报证据 | **淘汰出主榜**，但**不要丢掉**——查它的 `next_earnings_estimate.date`，落在未来 `days` 天内的进「📅 即将发财报」板块（见 Step 5）。实测 GRAB 用 2026-05-05 的旧季数据通过了全部数值闸，差一步就进深扫——"财报季扫描器"把两个月前的季度和本周的混排是定位级错误；但它下次财报 08-03 是有价值的前瞻信息 |
| 在窗口外，但确有近期财报（N-15 滞后）| 转降级通道：`news(query="<公司名> <TICKER>")` 取媒体原文实际值。**取不到量化 surprise 就记数据缺口，不参与排序**（实测 BKR 07-26 发 Q2 而 beat_miss 返回 04-23 的 Q1，媒体原文只说"超预期"无具体数字）|

---

### Step 4 — 逐字稿深扫（幸存者取 Top N，每股 1 额度）

按**营收 surprise 降序**取 Top N：

```
metrics(asset_type="tradfi", query="<TICKER> earnings call transcript")
```

⚠️ 单份逐字稿约 50 KB。**`top` 就是为这个存在的，不要为"扫全"放大它。**
✅ 安全边界（N-24）：**只有 query 含 `earnings call transcript` 才会拉逐字稿**，Step 3 的批量调用绝不会误带。
⚠️ **核对逐字稿季度看 `transcript[0].date` / `period` / `year`，`_meta.freshness` 是硬编码标签**（N-28）：该字段**恒为 `"q-1"`**，实测 IQV / CDNS 明明返回当季 Q2，freshness 照样写 `q-1`。**它不是动态信号，是常量**——拿它判新鲜度会把 **100% 的当季逐字稿误判成滞后**。

#### 🔑 调用前先预判：滞后是**确定可算**的，别白烧额度（N-34）

**判据**：`transcript[0].period` **恒等于** `latest_quarter.period`。两者都在 Step 3 的轻量返回里，**零额外成本**就能算出这次会拿到哪一季。

**操作规则**——拉 transcript 前，用 Step 3 已有的两个字段算间隔：

```
gap = beat_miss.date − latest_quarter.date
```

**阈值 = 90 天（一个完整财季）**：

| gap | 含义 | 动作 |
|-----|------|------|
| **< 90 天** | 刚报的这季**已入库**（latest_quarter 就是它），gap 即该股的财报公布滞后 | ✅ 正常拉，会拿到当季 |
| **≥ 90 天** | 刚报的这季**尚未入库**，latest_quarter 还停在上一季（多出整整一个财季）| ❌ **直接跳过调用**，拉了必然是上一季 |

> 🔒 **90 这个数不是拍的，是从机制推的**：gap 的物理含义就是**财报公布滞后天数**。数据新鲜时 gap = 滞后本身；`latest_quarter` 落后一季时 gap = 滞后 **+ 一个完整财季（≈90 天）**。两者只可能差一个整季，所以分界必然在 90 的量级。

**42 个样本实测（分布不是双峰，中间区间密集有样本）**：

| gap 区间 | 样本数 | 典型标的 | 实测结果 |
|---|---|---|---|
| 10~34 天 | 24 | ORCL 10 / ADBE 13 / MU 27 / CRWD 34（美股本土大中盘）| ✅ 当季 |
| **43~70 天** | **10** | BABA 43 / BIDU 48 / NIO 51 / **PDD 57** / **TIGR 63** / **EH 70**（**几乎全是中概 ADR**，报告节奏慢）| ✅ 当季（PDD/TIGR/EH 三只已逐一验证）|
| 71~115 天 | **0** | —— | ⚠️ **未实测的空白区**，但有结构解释：要落进来需"滞后 71~115 天"或"滞后 <25 天且数据陈旧" |
| 116~119 天 | 3 | STX 116 / KLAC 119 / F 119 | ❌ 滞后 |

> ⚠️ **曾经的错误，别再犯**：v1.4 一度把阈值定在 **60 天**，那是在"45~100 无样本"的错误认知下画的线。实测发现 45~70 是**中概 ADR 的系统性栖息带**——按 60 天，TIGR(63) 和 EH(70) 会被误判滞后而跳过，**丢掉本来拿得到的逐字稿**。教训：**阈值画在空白区之前，先确认那真的是空白**。

> ❌ **不要用"距财报日天数"判断**——这条假设已被实测证伪：IQV 与 STX/KLAC **同为 07-28 发财报**，结果相反。机制是 `beat_miss` 走快速 surprise 源，而**财报三表与逐字稿是同一批入库**，入库快慢按个股而异，与日历无关。

**跳过时的处理**：该股不占 Top N 名额（顺延给下一个幸存者），在 `👀 观察区` 注明"财报三表尚未入库，逐字稿本轮不可得"，**关键词闸标注"欠测"而非低分**——低分意味着"扫了但没讲高景气"，欠测意味着"根本没扫到"，两者对下一步动作的指示完全相反。

**兜底**：万一仍拉到季度不符的（判据失效），同样按"欠测"处理，别当真实低分。

对每份逐字稿扫关键词库，每个命中记录四要素：

| 要素 | 说明 |
|------|------|
| 类别 | 7 类中的哪一类 |
| 原文摘录 | 一句话原文（**必须有，给不出原文的不算命中**）|
| 发言人 | CEO/CFO/IR 等 |
| 语境 | 主动陈述 / 问答确认 / **负面语境（无效）**——见下 |

**降级路径**：逐字稿不可得 → 改用 `news(query="<公司名> <TICKER>")` 扫关键词，标注"降级来源"。

⚠️ **降级查询用 N-15 的"公司名 + TICKER"双词形态，不要套用 N-26 的长句式**——N-26 只管 Step 2 的无实体宽泛捞取。实测 `query="Baker Hughes second quarter results revenue"` 返回 0 条 BKR 内容（触发红线 11 的语义兜底，回的是印度财报和新加坡货币政策），改回 `query="Baker Hughes BKR"` 首条即命中。

⚠️ **个别实体存在"召回黑洞"，且重试无意义**（N-35）：实测 `query="Bloom Energy BE"` 与 `query="Bloom Energy"` 返回**逐字完全相同的 12 条兜底内容**（Bear Grylls、悼文、美联储……），0 条 BE 相关。而同一轮里 `query="Teradyne TER"` / `query="Visa V"` 都精准命中，说明双词形态本身有效。
> 关键认知修正：**红线 11 的语义兜底不是每次返回随机内容，而是返回一个固定的"最近热门"兜底集**。两个后果：①**同一 query 重试毫无意义**，换措辞也无效（去掉 ticker 后逐字不变）；②**两个不同标的的降级查询若都失败，会拿到一模一样的内容**——不逐条核实相关性，极易误判成"这两只票有共同报道"。
> 判别方法：降级返回里若**一条都不含目标公司名或 ticker**，即判为召回失败，记数据缺口，**不要重试**。

**（可选）精算财报后涨跌**：默认打分用当日涨跌。要算"财报日至今"真实反应，对 Top N 各加一次
`metrics(asset_type="tradfi", query="<TICKER> 历史走势", time_range="3m")`（+N 额度）。

---

### Step 5 — 打分出榜 + 前瞻板块（0 额度）

按下方口径打分排序输出。业绩闸分数在 Step 3 已算出，直接沿用。

#### 📅 即将发财报（零额外额度）

Step 3 的轻量调用**每票都返回了 `next_earnings_estimate.date`**，别丢掉。把候选池里满足以下条件的挑出来单列一节：

- `next_earnings_estimate.date` 落在**未来 `days` 天内**
- 市值 ≥ $2B（沿用闸②）

主要来源是**被闸④淘汰的那批**——它们 `beat_miss.date` 在窗口外，正说明上一季财报已经过去、下一季还没到。实测本轮：SOFI（07-29）、GRAB（08-03）、NVDA（08-26，超窗口不列）。

> 🔒 **必须标注名单边界**：这份前瞻**来自本轮候选池**（异动榜 + 新闻腿捞到的票），**不是全市场财报日历**。
> ❌ **不要用市场级 `earnings_calendar` 补全这份名单**——见流水线开头的 N-22，那个接口做不到，接进来只会给一份"看起来更全"的假名单。
> 💡 想要固定名单的前瞻，传 `watchlist` 参数（见下），别指望全市场扫描。

#### （可选）watchlist 前瞻

传了 `watchlist` 时，对池内标的额外逐批查（≤5/批，每批 1 额度）：

```
metrics(asset_type="tradfi", query="<T1> <T2> <T3> <T4> <T5> next earnings date")
```

取 `next_earnings_estimate.date` 落在未来 `days` 天内的，并入前瞻板块，标注来源为 watchlist。
这是**唯一准确的前瞻路径**：准，但只覆盖你给的名单。

**成本参考**：异动榜 1 + 新闻 0 + 硬闸 ⌈候选数/5⌉ + 幸存者逐字稿。实测 20 个候选 → 12 次额度（含 3 次字典缺失的无效补调，按新规则可省下）。上下文大头是逐字稿，**建议独立会话跑**。

---

## 关键词库

### 正向（7 类）

| 类别 | Transcript 检测表述 |
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
| 需求/价格/库存 | pricing pressure · demand softening · inventory correction · guidance cut / lowered outlook · elevated inventory |
| **资本开支/盈利质量** | CapEx raised / above prior expectations · pressure on operating margins · margin dilution · free cash flow pressure · impairment / write-down · restructuring charge · elevated costs · FX headwind |

⚠️ **资本开支组是必扫项**。实测 INTC 当日 −8%、GAAP 净亏 $110.3 亿，而旧版反向库（只有需求/价格/库存）命中 **0** ——真实空头论据全是 CFO 亲口说的资本开支：「we're raising our outlook for 2026 and now expect our CapEx to be more than $20 billion, which is up significantly versus our expectations entering the year」。GOOGL 同理：「the cost of that capacity will put some pressure on operating margins for cloud」。**只扫需求侧反向词，对本轮 AI 财报季的主导空头叙事完全失明。**

### 检测原则

1. **语义匹配而非字面 grep** —— 同义表述算命中，但必须能给出原文摘录
2. **负面语境命中作废（×0）**：命中句所在段落若同时出现 `dilutive` / `declined` / `offset by` / `partially offset` / `headwind` / `pressure`，判为**无效命中**，且要在输出里说明为何否决
   > 实测：CMCSA「we continue to see strong adoption of free wireless lines, **which is initially dilutive to broadband ARPU**… broadband ARPU declined 3.8%」——字面完美命中"新品持续超预期"，语义是负面。
3. **别只找多头证据**。一家公司可以既说需求旺盛，又在另一段承认价格承压或上修资本开支。

---

## 打分口径（0-100）

### 业绩闸（40 分）

见 Step 3 闸③ 的分档表（含 GAAP 扭曲 ÷2 规则）。**Step 3 已算出，此处不重算。**

### 关键词闸（40 分）

- 每命中一个类别 +5（7 类满 35），封顶 40
- 语境权重：主动陈述 ×1.0 ｜ 问答确认 ×0.6 ｜ **负面语境 ×0（作废）**
- 命中带量化数字佐证（如"DCAI revenue +59% YoY, meaningfully ahead of expectations"）：该类别 +1
- 反向词：每命中一类 −5，下限 0

### 盘面确认（20 分）

**默认用当日涨跌**（Step 3 快照）：≥+5% → 20 ｜ +2~5% → 14 ｜ 0~+2% → 8 ｜ −2~0% → 4 ｜ <−2% → 0

⚠️ 当日涨跌 ≠ 财报反应（扫描窗口 >1 天时尤其如此），**输出必须写明这一维用的是当日数据**。

<−2% 时标注："可能尚未 price in，也可能市场看到了财报之外的东西"——不要单方面解读成机会。
> 实测 INTC：业绩闸与关键词闸接近满分而当日 −8%，分歧本身就是研究入口，不是打分错误。

### 判定

| 条件 | 判定 |
|------|------|
| 业绩闸 ≥24 **且** 关键词闸 ≥20 | 🎯 重点关注（= 方法论"2+3 叠加"）|
| 仅过关键词闸 | 👀 观察（业绩闸 <24 的已在 Step 3 拦下，不会到这一步）|
| 都不过 | 淘汰（不进明细，只计入统计）|

---

## 输出模板

```
## 🔍 财报季超预期扫描 — [日期]（窗口 [N] 天）

候选池：异动榜独有 [a] + 新闻腿独有 [b] + 双腿命中 [c] = **[X] 个送验**
→ 上游解析成功 [X'] → 硬闸幸存 [Y] → 深扫 [min(Y, top)]

### 终榜
| # | Ticker | 公司 | 营收 Surprise | EPS Surprise | 关键词 | 当日盘面 | 总分 | 判定 |
|---|--------|------|--------------|-------------|--------|---------|------|------|

### 🎯 [TICKER] — [公司名]（总分 XX）

**业绩**：营收 $XXB（+X.X% vs 预期）｜EPS $X.XX（+X.X%）[GAAP 扭曲标注]
**来源**：异动榜 / 新闻腿 / 双腿命中 ｜ **市值**：$XXB ｜ **财报日**：[date]

**关键词命中（[n]/7 类）**：
- **[类别]**：「[原文摘录]」— [发言人]（[主动陈述/问答确认]）
- **[反向]**：「[原文摘录]」— [发言人] ⚠️
- **[作废]**：「[原文摘录]」— 负面语境否决，因 [理由]

**一句话 thesis**：[综合判断]

### 👀 观察区
| 标的 | 差在哪一闸 |

### 📅 即将发财报（未来 [N] 天）
| Ticker | 公司 | 预计财报日 | 市值 | 来源 |
|--------|------|-----------|------|------|

> ⚠️ 本节名单来自**本轮候选池**（异动榜 + 新闻腿）[+ watchlist]，**不是全市场财报日历**——市场级日历接口按字母序截断，做不到全市场（N-22）。

### 数据缺口
- 异动榜为**当日快照**，非 [N] 天全窗口
- 上游字典缺失取不到的 ticker：[列出]
- beat_miss 滞后一季转降级通道的：[列出，注明是否拿到量化值]
- 窗口外淘汰的：[列出]
- 逐字稿降级的：[列出]

> ⚠️ 盘面一维用的是**当日**涨跌，不等于财报后累计反应。
> ⚠️ 本扫描输出的是"值得进一步研究"的线索，不是投资建议。关键词是管理层的说法，不是已兑现的事实。
```

---

## 输出规则

- 关键词命中**必须附原文摘录**，给不出原文的不算命中
- 区分"主动说"/"被问出来"/"负面语境作废"三态
- GAAP 口径错位必须在输出里点明：「该超预期为非 GAAP 口径，本季 GAAP 为亏损」
- 情绪/景气判断标注"Claude 推断"
- 数据缺口如实列，**宁可报告不全也不要假装扫全了**
- 终榜是线索清单，不是买入清单

---

## 注意事项（caveats 内联镜像）

| # | 规避动作 |
|---|---|
| **N-8** | 数组参数全域被拒 → 走 query 串 |
| **N-12/N-23** | 批量 ≤5 个 ticker；差集缺失者**最多补调 1 次**，返回 `keywords:null` 即判上游字典缺失，直接记缺口（已知：JBLU/CUBI/ONDS）|
| **N-14** | query 除 ticker 外只允许 `next earnings date` 后缀；禁 beat/miss/surprise/call |
| **N-15** | 财报当晚 beat_miss 滞后一季 → 查 `beat_miss.date`，滞后走降级通道（**用"公司名+TICKER"双词，不用长句式**）|
| **N-22** | earnings_calendar limit 50 封顶 + 只覆盖首日 + symbol 升序截断 → **不可做发现腿** |
| **N-24** | `next earnings date` = 轻量模式（5 KB vs 8.7 KB）；transcript **仅**在 query 含 `earnings call transcript` 时才拉 |
| **N-25** | `news(limit=N)` 实返 **2N** 条；social 桶美股 ticker 密度更高 |
| **N-26** | news 陈述业绩事实句式优于情绪涨跌句式（相对排序稳定；**绝对命中率波动大不可当基准**，07-23 与 07-27 两轮实测同 query 差近一半）——**仅适用 Step 2 无实体捞取** |
| **N-27** | `verbosity` 参数对 metrics **无效**，不用传 |
| **N-28** | 🆕 transcript 的 `_meta.freshness` 恒为 `"q-1"` 属误导，核对新鲜度看 `transcript[0].date`/`period` |
| **N-29** | 同 payload 内 GAAP 与非 GAAP EPS 并存且无口径字段 → 引用 `beat_miss.epsActual` 必比对 `latest_quarter.eps`，反号即口径错位（**须先确认同季，见 N-33**）|
| **N-33** | 🆕 `revenueActual: null` 被当 0 算出 `revenue_surprise_pct: -100`，**骗过全部三道差集** → 加第 4 道检查；另 beat_miss 与 latest_quarter **季度对齐不固定**，反号比对须先验同季 |
| **N-34** | 逐字稿滞后**确定可算**：`transcript.period` ≡ `latest_quarter.period`，用 `gap = beat_miss.date − latest_quarter.date` **≥90 天**（一个财季）则**跳过调用**。零成本预判；"距财报天数"假设已证伪；**60 天阈值亦已证伪**（会误杀 gap 45~70 的中概 ADR）|
| **N-36** | 🆕 有"影子代码"的 ticker 双重展开吃名额：`CL`→`CL`+`CL=F`（商品重名）、`BABA`→`BABA`+`9988.HK`（中概双重上市）→ 该批按 **4 个**装 |
| **N-35** | 🆕 个别实体 news 召回黑洞，兜底返回**固定集合**（非随机）→ 同 query 重试无意义；两个失败查询会拿到一模一样的内容，须逐条核实相关性 |
| **N-21** | fundamentals 的 `default_fanout_fallback` warning 是**误报**，不要重试 |
| — | 红线 11：news 无匹配时不返空而返语义兜底的不相关内容 → "报道数"类判定必须逐条核实相关性 |
| — | news 不传 `asset_type`；metrics 全程带 `asset_type="tradfi"`；单批 ≤4 路并发 |
