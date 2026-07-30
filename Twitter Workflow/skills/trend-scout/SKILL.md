---
name: trend-scout
description: "Crypto & macro market trend scanner — orchestrates MCP tools and data skills to collect breaking news, on-chain signals, macro data, trading signals, and CT buzz into a structured briefing. Use this skill whenever the user mentions finding trends, hot topics, market news, what's happening in crypto, morning briefing, news roundup, 热点, 新闻, 行情, 今日要闻, 早报, 市场动态, what happened overnight, daily scan, or any request to gather market intelligence before tweeting."
---

# 热点采集 Trend Scout

调 Followin MCP 拿一手数据，Agent 子进程处理巨量返回，输出 `candidates.json` + 结构化简报。
**只采集 + 初筛，不出选题**（选题走 topic-engine）。

## 0. 使用前必填（占位配置）

clone 后先改这里，全文只引用这些变量名。未填项 → 相关规则跳过并在简报里如实标注，**不准静默略过**。

| 变量 | 含义 |
|---|---|
| `ACCOUNT_ENGINES` | 主引擎方向（决定什么算 off-strategy 噪音），如「美股传导 / AI 实测 / 反共识」 |
| `CATEGORY_CAP` | 单赛道配比上限，如「Crypto ≤25%」 |
| `LIST_IDS` | Twitter list 三栈的 `list_id`：`main / tech / master`，不足三条就删对应行 |
| `BRIEF_DIR` | 简报输出目录 |
| `STATE_DIR` | 跨天状态目录，默认 `~/.claude/state/`（**别用 `/tmp`**——重启即清，后果见 `config.md`）|
| `NEWS_LANG` | firehose 语言，`zh-cn` / `en` |
| `KOL_WHITELIST` | 对标 KOL 白名单（`is_kol_match` 用，5-8 个） |
| `BOARDS` | 叙事热度榜板块清单 + **每板块一句定义** |

`BOARDS` 的定义句是必需的：板块名不自解释时先查定义再填，**禁照字面猜**（曾把某板块名按字面理解成另一个生态，整块漏扫多天）。


### 🕐 时钟（🔴 每轮开工第一件事，先于一切采集）

本文所有 `$DATE` / `$WEEK` / `now` / `scan_ts_ms` **必须来自 shell 现取的这一组值**，
取一次、全程复用：

```bash
DATE=$(date +%F)           # 2026-07-30
WEEK=$(date +%G-W%V)       # 2026-W31 —— ISO 周编号，跨年不漂
NOW_MS=$(( $(date +%s) * 1000 ))
```

🔴 **禁止凭模型自己的日期认知推算日期或周数。** 模型的日期偏差常达数月，
而这几个值被当**文件名**用——猜错就写进错误日期的文件，于是「今日简报是否已存在」查重扑空、
下游读不到今日产物、回填链断，**而全程不报错、产物格式齐全**。
凡是要写「今晚 / 明天 / 本周」这类相对时间，也一律以 `$DATE` 为基准换算，不凭印象。

> 周编号只认 `%G-W%V` 一种格式（`2026-W31`）。全文任何周文件名都用它拼，
> **不许出现 `2026-31` / `2026-W31` 混用**——同一份文件的读写路径不一致，
> 结果是每天都判「缓存缺失」、每天重建、每天多喊一次告警。

## 1. 模式入口

| 用词 | 模式 | 窗口 | 输出 |
|---|---|---|---|
| "首扫" / 当日首次 | 🟢 首扫 | 24h | 全量简报 + candidates ≥12（**高集中度日例外见 §5.0**）|
| "刷新" / 距首扫 ≥2h | 🔵 刷新 | 上次扫描→now | 增量补丁 + 真新增 candidates ≥7 |
| "突发" / 单一大事件 | 🔴 突发 | <6h | 单事件深挖 + candidates ≥3（**每条候选各写自己的 `event_id`**，见 §8；共享指针文件只表示「当前最新事件」），SLA 5min |
| "30秒扫一下" | 🟡 极速 | 当下 | 价格 + Top1（**不出 candidates、不接 topic-engine**）|

当日首次必须首扫（无 baseline 不准跑刷新）；距上次扫描 <30min 拒绝刷新。

**首扫开始时三查**：① 今日简报是否已存在（防重复首扫）② 周缓存 `$STATE_DIR/trend-scout-weekly-cache-$(date +%G-W%V).json` 有则直接读、**无则立刻建（任何天都建，别死等周一）**、建失败才 emergency 全跑且简报顶部喊「⚠️ 本周缓存缺失·Wave2B 未采」③ 每月 1 号追加月度叙事审计 prompt。
⚠️「只有周一才建缓存」是陷阱：周一没跑扫描则整周 emergency-no-write、Wave2B 天天静默跳过、无人察觉。

**刷新 threshold（必跑）**：开始读 `$STATE_DIR/trend-scout-last-refresh-$DATE.txt` → `LAST_MS`（无则 4h ago），所有增量过滤统一用此值，Agent prompt 显式传「THRESHOLD_MS=…，严格用此值不要重算时区」；结束写回 `NOW_MS` + 追加 `$STATE_DIR/trend-scout-history-$DATE.json`（entity+velocity，二次发酵对比用）。

---

## 2. 数据源与调用规范（Followin MCP：metrics / news / signal / twitter）

### 2.1 metrics
- **tradfi 必传 `asset_type="tradfi"`**，单 ticker 单调用并行（多 ticker 一次塞会被路由到 fundamentals）。
- **crypto 批量必传 `asset_type="crypto"`**（防同名 tradfi 污染，如 BTC→某 ETF），`time_range="1d", limit=2`。
- 🔴 **`change` 字段是「美元变动量」不是「百分比」**（实测 META `change:-9.18` / `previousClose:593.41` → 真实 **−1.55%**）。
  百分比必须自己算：`change / previousClose × 100`。**危险在于数值会巧合吻合**——META 的 −9.18 与新闻标题「crashes −9%」看着对上，
  直接拿去和新闻交叉核实会得到**假的"核实通过"**（那 −9% 是盘后跌幅、−9.18 是美元，两个数毫无关系）。写进简报的涨跌幅一律用自算的 %，并注明基准。
- 🔴 **盘后/盘前拿到的是上一个 regular 收盘，不是当前价**：看 `_quote_session`（`regular_inactive` = 已收盘）与 `_quote_cache`（`last_regular`）。
  这时 metrics 的 price 是 8+ 小时前的收盘，而**新闻里的盘后价才是当下真相**——「价格铁律」在此时段是反的（见 §6 修正）。
  盘后事件（财报后跳水）标注 `regular 收盘 X（−a%）｜盘后另跌约 b%（来源：新闻，未取到一手盘后价）`，两个数分开写、别混。
- 🔴 **不带 `asset_type` 的 query 会同时返币和同名 ETF**：`query="BTC price"` 返回 BTC 币 64,140 **和** Grayscale Bitcoin Mini ETF 28.08 两条。
  必须按 `_asset_type` 筛（crypto vs tradfi），别把 28.08 当比特币价。crypto 一律显式传 `asset_type="crypto"`。
  - 🚨 批量写法：`query="BTC ETH SOL BNB XRP price"` —— 空格拼 symbol 走 query 串，服务端自解析成 keywords（meta 可见 `keywords:[...]`），一次全回。**禁传 `keywords=[...]` 数组**（§2.5）。
  - ⚠️ `time_range` <1d 有 bug（返一个月前数据），小时级用 `interval`。
- 可用 tradfi symbol：`^GSPC ^IXIC ^DJI ^VIX ESUSD GCUSD SIUSD USO UUP EURUSD USDJPY`；`^DXY` / `CLUSD` / `NGUSD` 是 402 Special Endpoint，**禁调**。
- 国债 / 经济日历 / CPI：纯 query 自然语言（`query="US 10 year treasury yield curve"` 即返全曲线）。🔴 **读之前必须按 `_resolved_from_keyword` 去重**——多 keyword 解析会返回内容相同的多行，不去重会把同一条曲线当三个独立数据点（细节见 `references/source-list.md` §MCP 坑位）。
- **商品（黄金/原油）拿不到一手价**：四个符号里只有替代源可用，口径必须标注 → 见 §MCP 坑位。🔒 拿不到就按「价格数据铁律」标「未取到一手价」，**禁引用新闻里的涨跌幅当数据**。
- **异动榜**：`metrics(query="most active stocks", asset_type="tradfi")`，🔴 **返回不含 `marketCap`，必须二次批量补市值再按 ≥$1B 过滤 + 按 name 剔 ETF/杠杆**（不做的话杠杆 ETF 会混进候选；正则见 §MCP 坑位）。`biggest gainers/losers` **禁用**。
- **tradfi 降级路径**：行情端点（quote / historical_chart / most_actives）同时 403 → 实时价改用 `mcp__tradingview__yahoo_price`（symbol 直传 `^GSPC ^IXIC ^VIX GC=F CL=F` 及个股；偶发 SSL 瞬断重试 1 次即恢复），简报实时数据区**必须标「替代源」**；异动榜无替代 → 留空标注。
- **crypto 备援**：`mcp__okx__market_get_ticker`（`instId` 如 `BTC-USDT`）；启用时同样标「替代源」，首次启用前先实测一个 symbol 交叉核对。
- 🚨 **候选 one_liner 里的涨跌幅必须经行情源核实后才可下传**——新闻 / KOL 转述的百分比一律视为二手（实测偏差可达一倍，且常把盘中峰值当收盘）。

### 2.2 news
- **firehose**：不传 query，`time_range="1d"（首扫）/"4h"（刷新）, limit=25, source_lang=<NEWS_LANG>`。
- > ⚠️ **`NEWS_LANG` 留空时，firehose 与下方 TG 广拉塌缩成同一次调用**（参数完全相同）——**只调一次即可**，两条腿的产物都从这一次的 `articles[]` + `social[]` 里取，别重复调浪费额度。

**Telegram 资金流遥测（1 次广拉，主进程直调）**：**不传 `sources=["telegram"]` 数组**（会被拒）→ **无 sources 广拉**：`news(time_range="1d"/"4h", limit=20-25)` + **空 query**；firehose 的 `social[]` 天然含 TG provenance 条目（`tg_kol_feeds`）。
  - 🚫 **绝不传 `source_lang`**：TG item 的 `source_lang` 全是空串 `""`，传语言值会把数据全筛光、连续多天误报「源已降级」。
  - 判 TG 真挂：广拉返回里 `tg_kol_feeds` 条目为 0 才是真挂；有任一返回即源活着。
  - **产物只喂简报「资金流」区，不产候选、不做 consensus 聚合**。取两类：**大额转账**（金额 + 方向，挑 ≥$30M 或与当日候选实体相关的，佐证「解锁→交易所 = 实锤抛压」类叙事）、**清算簇**（按主流币聚合多空方向与量级，佐证多空强弱）。**剔** memecoin 喊单 / 赌球 / 与 firehose 重复的头条。
  - 🔴 **先用 `tg_category` 字段做结构过滤，再按内容判断**（实测返回自带此字段，之前没用它）：每条 TG item 带 `tg_category` ∈ {交易信号 / Meme打新 / 链上数据 / 叙事追踪 / 市场结构 / 宏观研判 / 项目研究 / 实盘跟踪}。
    **保留**：链上数据 / 市场结构 / 宏观研判（资金流与结构信号在这里）；**默认剔**：Meme打新 / 实盘跟踪（喊单晒单）。这比纯凭内容判断稳定得多——实测 25 条广拉里靠内容判断砍掉 15 条"软性"，占 60%，而"软性"无量化判据；用 `tg_category` 分流可复现。
  - **只拉 1 次**：TG feed 是 bot 不是 KOL，`distinct_authors` 聚合前提不成立；多 category 路由几乎不分流（10 次 ≈ 1 次信息量）。链上突发走 §8，不靠日常 TG 兜底。
- **CT firehose（浏览模式，仅首扫）**：**不传 `sources=["twitter"]`** → `news(asset_type="tradfi", query="<当日 3-5 个宽主题词空格拼，如 semiconductor memory oil Fed earnings>", time_range="1d", limit=20)`；Twitter 条目在 `social[]`（`articles[]` 多为 media）。代价：从「无差别浏览」变「主题引导」，主题词由当日 list/firehose 已知线索定，**主题外盲区如实认**。无完整 author/viewCount → 剔个人喊单 / 引流 / 闲聊 / 纯 TA，保留基本面异动 / 产业链 / 地缘 / 高密度框架。刷新模式不启用本层。
- 媒体频道走 web news 不走 TG；同 username 去重 ≤3 条。

### 2.3 twitter（list_timeline 三栈）
| List | 用途 | 模式 |
|---|---|---|
| `LIST_IDS.main` | 泛行业 + 宏观，BREAKING 首发地 | 首扫 + 刷新 ⚡P0 |
| `LIST_IDS.tech` | 跨界传导源 | 首扫 + 刷新 ⚡P0 |
| `LIST_IDS.master` | 投资大佬本人 / 追踪号 | 仅首扫（24h <3 条 → 追加取最新扩 top5+3 并标「⚠️大佬安静」）|

P0：**`config.md` 里已配置的每条 list 都必须成功**（失败重试 1 次，真失败简报标 ❌ 且当次刷新强制补）。配了几条查几条；**0 条配置 → 整条 list 腿跳过**，简报标「list 未配置」、自查 ②/⑪.a 记 `n/a`，**不阻塞下传**。
- ⚠️ **已配置却扫失败 = 硬 FAIL**，这是本条规则真正要防的：源配了却静默漏扫，简报看起来正常实则缺了一整个信息面。
- 🔴 **返回 0 条也算失败，不算"今天没人发推"**：实测**不存在 / 已私密 / 已删除 / 真的空**这四种情况
  返回上完全一样（HTTP 200 + `results: []` + 无报错 + 照样扣 1 credit）。
  已配置的 list 返回空 → 简报标 ❌ 并**显式提示「list_id 可能已私密/删除/写错，去 Twitter 上确认」**。
  用别人的 list 当数据源时这条尤其要紧——你不会收到任何通知。（所以规则约束的是「不许偷偷少扫已配置的源」，不是「必须凑满三条」。）

**🚨 端点铁律**：主用 `action="list_timeline"`（**不要用 `list_tweets` 当唯一来源**——
它静默丢纯 RT，而 KOL 转发 = 背书 = 选题线索）。
⚠️ **但 2026-07-30 实测修正了原先的说法：两个端点都不完整、且互不包含。**
同一 list 同一重叠窗口里，`list_tweets` 独有 5 条 reply、一个 `list_timeline` 里从未出现的成员，
**以及一条既非 reply 也非 RT 的正常原创长推**——那不是分页空洞，是重叠窗口内直接丢的。
所以：**日常首扫用 `list_timeline` 即可**；当某个 list 产出明显偏低、或要复核"某人今天真的没发推"时，
**补拉一次 `list_tweets` 并按 `id` 合并去重**。对照表见 `references/agent-prompt-template.md` §端点铁律。

⚠️ **`list_timeline` 的返回里没有 `inReplyToUserId`**，判 reply 用 `isReply` / `inReplyToId`。
（`user_tweets` 端点**有** `inReplyToUserId` / `inReplyToUsername` —— 同一个 MCP 工具，
不同 action 字段集不同，别把一处的观察套到另一处。）
**⚠️ 分页丢块（未解决，2026-07-30 量化）**：翻多页时**页内密集、页间凭空缺整段时间**，是 API 分页丢块不是 list 停更。
实测三页：墙钟跨度 20h29m，真实覆盖只有 **6h10m ≈ 30%**，两个空洞分别 6h13m / 8h05m，
且第一个空洞正好落在**美东午盘+盘后**——而 list 里有三个快讯搬运号，那段时间不可能一条不发。
→ ① **判 list 产能只用最新一页的连续头块**，禁止用「全量条数 ÷ 全量跨度」算日均（名义 1.32 vs 头块 6.7 条/天，差 5 倍）；
② **别指望翻页凑出"一天的量"**——页数越多丢得越多，覆盖"一个自然日"这个前提本身不成立，
简报里该说的是「回看 Xh」而不是「今日全量」。
🔴 **而且这个 Xh 必须是"真实覆盖时长"不是"墙钟跨度"**（实测子进程报了墙钟 19.2h，真覆盖只有 ≈30%）：
墙钟跨度 = 最新条 − 最老条，包含中间的空洞；真实覆盖 = 各页头块连续时长之和。**报后者，或两个都报（"墙钟 20h / 实覆盖 6h"）**，
只报墙钟会把 30% 的覆盖说成"回看了一整天"。

### 2.4 signal
- tradfi `insider_trading` / `institutional`（议员 / 内部人 / 13F）：走 query 串。返回可能超长 → 落盘再抽；剔税务代扣类条目；空信号标 `empty_no_signal` 不阻塞。
  🔴 **query 写得再具体也不改变返回内容**——`signal` 不做类型路由，想要议员交易只能拿到结果后按 `provenance` 客户端筛（见 §MCP 坑位）。
- crypto `kol_call` / `trader_position`：**`ACCOUNT_ENGINES` 不含"喊单 / 实盘跟单"则默认关闭**（低差异化、长期 0 候选），突发模式用户明确要"看巨鲸/实盘"时例外；加密交易向账号可全开。

### 2.5 MCP 类型铁律
- 数字参数传 **int 字面量**（`limit=12` 不是 `"12"`）；`list_id` / `symbol` / `query` 是 string。
- ⚠️ **`MCP error 0: ... invalid during session initialization` 有两个成因，别只查类型**（实测：同批 4 个纯 string 调用挂了 2 个）：
  ① 参数类型错（数字传了字符串）；② **并发争用**——一条 message 塞多个 followin 调用时，部分会撞到"会话初始化中"而失败，**与参数无关**。
  判别：同批其他同形态调用成功 = 排除类型错，是并发。**动作：失败的那几个减少并发、下一批重试**（实测重试即成功）。
  🔴 原先写「九成是类型错」会把人引向查参数（查不出），这是误导性归因——比没有归因更糟。
- 🚨 **数组参数全域禁用**：`keywords` / `categories` / `sources` 等**即使主进程直调也会被序列化成字符串遭 schema 拒**（`["market"] has type "string"` 连环 `-32602`），没有安全通道。**统一走 `query` 自然语言 / 空格拼串**，服务端自解析。副作用：返回可能带 fundamentals 噪音（fanout fallback），忽略即可。
- **并发上限**：主进程一条 message 里 followin 调用 **≤4 个**（一次发 12 个会有半数 `-32001` 超时）。⚠️ **实测 ≤4 仍偶发 session-init 失败**（4 个挂 2 个）——把 ≤4 当上限而非保证，失败项按上一条减并发重试。
- session 每 5-8 calls 可能短挂 → 重试 1 次，或让用户 `/mcp restart followin`。

---

## 3. Agent 派工三定律

1. **只有 `list_timeline` 派 Agent**（单 string 参数 + 返回巨大必须 jq 抽数）；`metrics` / `news` / `signal` 一律主进程直调，分批 ≤4 个/message。
2. **一 Agent 一调用链一 jq**：翻页**覆盖驱动**——翻到最老一条 `createdAt` 早于窗口起点，或达上限（主 3 页 / 科技 2 页 / 大师 1 页）；到上限仍不足必须注明「⚠️ 覆盖不足：实覆盖 X.Xh（墙钟 Y.Yh）」（诚实标注 > 假装覆盖；🔴 报**实覆盖**不是墙钟跨度，见 §2.3 分页丢块）。刷新维持单页。prompt 必含「🚫 不要读 SKILL.md」。
3. **首扫单批次全并发**：所有采集（主进程直调 + 全部 Agent）在**同一条 message** 发出，不分波；跨源综合（聚合 / 共振 / 跨界传导 / 纯交易预排除）等全返回后在主进程做。

**Agent prompt**：用 `references/agent-prompt-template.md` **逐字复制、只替换占位符**。
那份文件里是完整载荷（createdAt strptime 规范 / velocity 双轨公式 / RT 封顶 / age<0 报错口径 /
噪音过滤 / 返回 schema / 回执路径）。🔴 **禁手拼**——手拼出过复用过期 scan_ts、时区规范缺失两类事故，
两次都不报错，只是排序悄悄失效。

**回执必落**：list 走子进程，主 session 的调用审计看不到它 → 不落回执则自查 ⑪.a 永久 WARN，
久了会训练操作者对 WARN 失敏。路径与字段见模板文件 §回执。

**噪音号**：能判什么、判不了什么、以及"真解是人工把号移出 list"，见模板文件 §噪音号。
Skill 侧只做内容级过滤，**不维护点名黑名单**。

对标差异化判定**不在本 skill 做**（topic-engine 层 B 专责）。

---

## 4. 标准执行流（首扫）

```
单批次全并发（一条 message）：
  主进程直调：metrics(crypto 批量) · metrics(tradfi 按需 4-12 单调) · metrics(国债/宏观 query)
              metrics(most_actives → 二次补市值后过滤 mc≥$1B) · news(firehose) · news(TG 广拉 1 次)
  Agent 并行：A 主list · B 科技list · C 大师list · D CT firehose 过滤
              F Wave2B（议员/内部人快照，仅本周首个无缓存日建缓存[不限周几]；
                有缓存日不派 F、主进程直接读）
全部返回 → 主进程综合 → 按落盘顺序出文件 → 自查
```
刷新 = 2 个 list Agent + firehose + crypto metrics + 关键 tradfi delta + 1 次 TG 广拉。

### 落盘顺序（硬规则）
```
⓪ 回填上一个简报日：目标日 ≠ 机械的"昨日"——**向前找最近一个存在简报的日期 D**（≤7 天，
   找不到则跳过并在审计块注明）；否则遇到没扫描的日子会扑空，而更早那份简报的
   published[]/data_tracking[] 正空着等回填，断链复发。
   实操：ls $BRIEF_DIR 倒序取今日之前第一个存在的日期 D → 主进程
   twitter(action="user_tweets", 自己账号) → 解析 results[0].data.tweets → 抽 D 日窗口
   非 reply（含 likes/rt/replies/bookmarks 完整互动字段）→ 回填该日简报 published[] +
   data_tracking[]。边际成本 ~1 分钟；没有这一步，data_tracking 会长期全空。
① candidates.json（含 "render" 块 = 简报内容槽）→ ② -latest.txt 索引
③ state（last-refresh + history）→ ④ narrative-watchlist / deathnote（无命中也写空占位）
④.5 story registry $STATE_DIR/trend-scout-stories.json：命中弧线 last_hit=$DATE，
   days_hit 只在 last_hit != $DATE 时才 ++（🔴 **按日历天计，不按运行次数计**）、
   新弧线登记、cooling / closed 按 $DATE − last_hit 的**实际天数**判（≥5 天 cooling / ≥10 天 closed）；
   days_hit≥5 且近 3 次相关推 views 递减 → 简报标「⚠️ 弧线疲劳」；recurring_excluded 免每日重判
⑤ 简报：**按固定模板渲染，禁手写散文**——模板从同一份配置生成全部板块行与 list 锚点，
   结构性不可能漏项；渲染内置 raw_score 重算校验（h*0.5+t*0.4+d*0.1，差 >0.01 拒绝渲染）
   与 CATEGORY_CAP 硬闸。简报既是人读文档又是机器工件：散文会漂，模板不会。
```

### 周缓存（仅首扫）
`$STATE_DIR/trend-scout-weekly-cache-$WEEK.json`（`$WEEK` = `$(date +%G-W%V)`，如 `2026-W31`；**和 §0 时钟、§首扫三查用的是同一个拼法**），**必须在 `$STATE_DIR` 不能在 `/tmp`**（`/tmp` 重启即清，周内合同活不过重启）。内容 = 议员 / 内部人快照。
**不要调 earnings / econ calendar 端点**——连续多周返回垃圾（外币小票、关键词被误解析成 ticker）；改用 `$STATE_DIR/trend-scout-anchors.json` **事件锚点登记表**：已核实的 forward 事件（财报日 / 转换窗口 / 发布会）一次登记、每日首扫直接读、过期自动忽略。CPI / 非农逐月官方核实后写入，**禁按惯例直接发推**（曾因日期 churn 3 天翻车）。

---

## 5. 打分与候选池

**5.0 age gate（落盘前硬闸，最先执行）**：每条算 `age = (scan_ts_ms − first_seen_ts_ms)/3600000`，**>48h 直接踢进 `removed_stale_violation` 不进池**。⚠️ firehose `time_range=1d` 的 trending feed 按**热度而非时间**返回，常混多日陈货，肉眼核会漏 → **必须机器核**。剔除后若 <floor，补**真新鲜**信号，**禁回填陈货**。

🔴 **floor 与「🔗聚合事件」方向相反，必须给高集中度日一个可区分状态**（实测暴露）：
big-news 日（Fed / 财报季 / 崩盘）list 出 18 条，按 §5.4 `🔗聚合事件`（同实体 ≥2 条合并）合并后可能只剩 8 个**独立事件** < floor 12。
**这不是采集不足，恰恰是信息量最大**——要凑满 12 就得不合并、留一堆同一事件的碎片，那才是真降质。
判别与动作：
- 若 `原始候选数 ≥ floor` 且 `合并压缩比高`（原始 / 独立事件 ≥1.5）且**每个 `🔗聚合事件` 标签都成立** →
  记 **`concentrated_day`**：候选数按独立事件算、**不判 FAIL、正常下传**，但简报顶部标
  「⚠️ 高集中度日：N 条原始合并为 M 个独立事件，未强凑 floor」。
- 若原始候选就 < floor（真采集不足：源少 / 窗口空）→ 照常 FAIL、要求补采。
**区别在于「合并前够不够」**：合并前够 = 集中不是缺，合并前不够 = 真缺。

**5.1 纯交易数据预排除（打分前最先执行）**：单一交易事件（巨鲸爆仓 / 抄底 / 仓位反转 / 单一喊单 / 清算地图 / 技术面阈值 / 资金费率异动）且 title/one_liner 内**无叙事 layer**（宏观政策锚 / 项目生态 / KOL 冲突 / 跨源共识；**不可从同实体其他候选继承**）→ **砍**，写入 `excluded_pure_trade`（`title`+`reason`+`kept_as`），保留进简报资金流区作背景。分高也照砍。

### 5.2 raw_score
```
raw_score = heat×0.50 + timeliness×0.40 + diffusion×0.10
```
- **heat 5 是稀缺**：≥5 源共振 / 互动 >200K / 全网刷屏；4 = ≥3 源或 50-200K；3 = 2K-10K 或单源高质量；2 = 500-2K；1 = <500。
- **timeliness**：5 = <2h 且未扩散（<2h 已全网扩散最多给 4）；4 = 2-6h；3 = 6-12h；2 = 12-24h；1 = 24-48h；>48h 不入池。
- **diffusion**（稀缺度）：5 链上独家 / 私域；4 中文 KOL <50K 粉；3 国际 KOL / 项目官号；2 二线财经媒体；1 头部通讯社 / 央行（已全网扩散）。
- **反通胀配额**：`raw ≥4.5` 单批次 ≤2 条，超了必须拉档。顶格 4.8 一周 2-3 次正常，**天天 3 条 = 尺子坏了**。
- **单源 BREAKING**（地缘 / 政治 / 军事 / 监管）：≥2 个相互独立信源确认才可 timeliness ≥4，否则强制 cap 3 + 标 `⚠️单源待验证`。浏览模式 firehose 来的 BREAKING 一律先按单源。

### 5.3 candidates schema
必填：`id` / `title`(≤30字) / `one_liner`(**≤110字**含核心数字；**预算优先级：核心数字 > 事件 > 交叉信号**，放不下就砍交叉信号别砍数字) / `category`(crypto|tech|investing|macro) / `source_type` / `source_list`(main|tech|master|external) / `is_kol_target` / `first_seen_ts_ms` / **`scan_ts_ms`（= 本次 `NOW_MS`，写在 json 顶层，不是每条候选各写一份）** / `event_id`（突发模式下必填，见 §8；非突发填 `null`）/ `raw_signals`(engagement_twitter + engagement_other + diffusion_minutes + cross_source_count) / `scores` / `tags` / `schema_version`。无 `notes` 字段——交叉信号 / 风险写进 `one_liner`。
- **`exclusive_details` 只给 BREAKING 候选**：≥2 条且分属不同类型（时间线拼图 / 量级换算 / 细节放大 / 时间巧合 / 跨语言共识），同主题撞车升 ≥3。非 BREAKING 禁加。
- **`source_list` 按真实来源标，不准图省事全填 `external`**（复发坑）：在某条 list-Agent 输出里出现过 → 标该 list；只有真从 firehose / TG / metrics 来、未在任一 list 出现的才算 external。⚠️ **CT firehose 不是三个 list 之一 → 它来的候选一律 `external`**（曾把 7 条 CT 半导体料误标成 list 来源）。
- **`source_handle`**（`source_list ∈ {main,tech,master}` 必填）：让它冒出来的 @用户名（不带 @，与回执 `handles` 同源）。自查 ⑪.d 交叉验：必须 ∈ 该 list 回执的 `handles`，否则 WARN。把 source_list 准确性从自律变机检。
- 🚨 **只写持久目录，不要写 `/tmp`**：`$STATE_DIR/trend-scout-candidates/YYYY-MM-DD.json`；刷新档 `YYYY-MM-DD-HHMM.json` 同目录；索引 `$STATE_DIR/trend-scout-candidates/YYYY-MM-DD-latest.txt` 内容为当次 json 的绝对路径。**下游（topic-engine / twitter-ops lint）一律从这里读，全仓不存在第二个候选池位置。**

**5.4 标签体系**（写 `tags` 数组，不加 schema 字段）：`⚡加速`(年轻+快速积累) / `🔗聚合事件`(同实体 ≥2 条合并，engagement 累加) / `📅pre-event`(macro 且 12h 内高影响日历，timeliness +1) / `📈升温`(同 entity velocity >3× 上轮) / `🔥潜热`(首发+共振+高 reply 等 ≥2 信号) / `🌉跨界传导`(如 半导体↔矿企 / 黄金↔BTC / VIX↔加密 / 利率↔风险资产) / `🌊narrative` / `🆕周新增` / `BREAKING` / `✅多源确认` / `⚠️单源待验证`。

---

## 6. 简报与输出

- **单日单文档** `$BRIEF_DIR/YYYY-MM-DD 每日热点简报.md`：首扫新建，刷新 append `## 🔵 刷新 · HH:MM` + frontmatter 累加 `modes` / `刷新_times` / `last_updated`。
- **10 个 section 全出**（逐个点名，缺一即自查⑦ FAIL）：
  ① 📊 实时数据区 ② 📰 叙事摘要区 ③ 🌊 叙事热度榜 ④ 🔥 必关注 Top5
  ⑤ 🗣 KOL / 社媒 ⑥ **💰 资金流**（TG 广拉的大额转账 / 清算簇 + `excluded_pure_trade` 的去处）
  ⑦ 📅 事件锚点 ⑧ 🟡 数据源审计 ⑨ 📋 候选池排序表 ⑩ ➡️ 接驳提示
  —— 写「N 个 section 齐」但不枚举，这条机检就只能靠猜；而**枚举漏一个比不枚举更糟**：
  资金流区一旦不在名单里，TG 那一整腿的产物会被当成"不该存在"整块丢掉，
  而自查⑧（TG 审计凭证）照样 PASS，因为广拉确实调了。
- 叙事热度榜 **`BOARDS` 全列**（0 hit 也标），刷新窗口内任一板块 ≥2 新候选必须重算叙事榜。
  必关注 Top5 每条 1 行摘要（数据在表 / candidates，不重复展开）。

  **🌊 板块热度分口径**见 `references/source-list.md` §板块热度分（0–5 分四项判据）。
  两条约束留在这里，因为它们最容易被忽略：**0 hit 板块记 0.0 不是 n/a**（deathnote 要的就是连续低分）；
  四项必须来自**本次扫描**，但周级消费者（deathnote）用 `score_week_max` 而非最后一次的分。

- **价格铁律**：当前价只引 metrics 返回值，新闻里的价格是"历史叙述"；实时数据区与叙事区数字不混用。
  🔴 **例外——盘后/盘前时段这条是反的**：metrics 在非交易时段返回的是**上一个 regular 收盘**（看 `_quote_session=regular_inactive`），
  8+ 小时前的旧价；此时**新闻里的盘后价才是当下真相**。财报后跳水这类，两个数分开写：
  `regular 收盘 X（自算 −a%）｜盘后另跌约 b%（来源：新闻，未取到一手盘后价）`，标清来源，别拿旧收盘当"当前价"。
- **数据源诚实**：自查 WARN ≥1 → 简报顶部必有 `> 🟡 数据源审计告警` 块显式列降级项；汇报说「N PASS / M WARN / K FAIL」，**禁称"全 PASS"**；某源连续 2 次 degraded → section 顶部显式标注。
- **宏观事件时间**：写"今晚 / 明晚"前用绝对日历核对（CPI = 每月第二个周三 8:30 ET；非农 = 第一个周五；GDP advance = 季末月最后一周周三 / 四），标 ET + 本地双时间。

**候选池排序表必出**：首扫 AND 刷新，扫描结束**必须在对话回复里**出 raw_score 降序全表（刷新 = 分桶叙述**之外额外**出表），"表在简报里"不算。尾部固定顺序：①排序表 → ②接驳提示。
```markdown
## 🎯 候选池（按 raw_score 降序）
> JSON：<路径> · N 条 · excluded_pure_trade M 条
| # | 候选 | 类别 | heat | time | diff | **raw** | tag |
配比：crypto X% / … · ≥4.5 N 条
```
**接驳**：末尾必附——本 skill 只采集 + 初筛，**不出选题**；"出选题 / Top X / 写推文"必须走 topic-engine 读 candidates.json，**禁止从简报直接出选题表**。配比权威 = `skills/twitter-ops/references/operations-plan.md`。
**BREAKING 落地**：P0 级 BREAKING 简报必标 `24h 落地承诺`（必发 / 选发 / 已发）。

---

## 7. 落盘后自查（12 项，三态 PASS / WARN / FAIL）

FAIL 必须补做，**不准下传 topic-engine**。建议固化成脚本 + 一份配置（板块名 / section 标记 / list_id 集中一处），改配置即同时改模板与自查，避免三处漂移。

① `BOARDS` 板块全列（未配置记 n/a）② P0 list 标记齐（**以 `config.md` 实际配置的条数为准**；一条没配记 n/a） ③ 候选数 floor（首扫 ≥12 / 刷新 ≥7；**`concentrated_day` 按独立事件数计且已标注 = PASS**，见 §5.0）④ schema 必填完整 ⑤ 简报模板锚点未漂 ⑥ `source_list` / `is_kol_target` 已填 ⑦ **10 个 section 齐**（含 💰 资金流） ⑧ TG 审计凭证（≥1 次真实广拉）⑨ state 文件（last-refresh + history）已写 ⑩ 零废弃工具调用（只用 §2 白名单内的） ⑪ 工具调用审计（⑪.a 三栈回执齐即 PASS；⑪.d `source_handle` ∈ 回执 `handles`，WARN-only）⑫ age gate 已执行（无 >48h 陈货入池）。

**叙事清单维护**：T1 刷新重算评分 / T2 每日 `BOARDS` 全扫 / T3 每次扫描落盘 `$STATE_DIR/narrative-watchlist-$WEEK.json`（非清单板块满足 ≥3 KOL + 跨语言 + cluster ≥5 时累积）与 `$STATE_DIR/narrative-deathnote-$WEEK.json`（连续 4 周 <2.0；**跳周会让相邻两个文件被当成连续两周**，判 deathnote 前先核对四个 `$WEEK` 编号真的连续）/ T4 每月 1 号出审计 prompt，用户拍板增删 `BOARDS`（新增板块**必须同时写定义句**）。

## 8. 突发模式

事件 ID 锚点 `evt-YYYYMMDD-HHMM-keyword`（日期时分取自 §0 时钟）写进
`$STATE_DIR/trend-scout-current-event-id.txt`，**并同时写进每条候选自己的 `event_id` 字段**。

> 🔴 **不许只靠那个共享文件认领事件。** 该文件按天覆盖、"所有候选共享"，
> 于是一天里出现**第二个**突发事件时，事件 1 的候选会被静默归到事件 2 名下——
> 归组错了，后续的跨轮追踪、弧线计数、回填全跟着错。
> 共享文件只当"当前最新事件"的指针用；**归属关系落在候选自己身上**。
工具：`advanced_search` Latest（最有价值）+ 主 list 关键词过滤 + 当事人 `user_tweets` + replies/quotes 看反应 + 相关 metrics + media news。**keyword 拆 2-3 个独立词并行，禁 AND 长 query**——零结果本身是信号（抢先窗口仍在）。≥2 源确认才标"已验证"。SLA 5 分钟。

## 9. 信号不足 / 维护

- 首扫 <12 或刷新 <7：A) 重跑首扫 B) 锁定事件走突发 C) 收窄到单一标的做深度。**禁止凑数**、禁止跳过自查直接出 candidates。
- 工具集变化 → 先改 §2；板块 / section / list 变化 → **只改 §0 配置**（模板与自查从它派生）。新增规则只写「一句话原因 + 操作结论」，不在本文件堆版本叙事。

## 参考文件
- `references/source-list.md` — 新闻源 / 宏观数据源清单
- `skills/twitter-ops/references/operations-plan.md` — 配比与频次权威
