# Followin MCP 调用规范 + 已知问题登记（共享 SSOT）

> `Base Skill/` 下 6 个 Skill（01-06）共享的调用红线与已知问题单一事实源。
> `Community Skill/` 的 c1-c6 同样以本文件为准。
>
> 🔗 **本地消费方（2026-07-27 起）**：`~/.claude/commands/` 下的 08–15 号 Skill 也读本文件——
> `~/.claude/references/followin-mcp-caveats.md` 已改为指向本文件的**软链接**，两份副本不再分叉。
> （此前该路径是 2026-07-22 之前的独立旧版，导致 7 个 v2 Skill 长期读不到 N 系列，已修正。）
>
> 🔗 **上游参照**：官方意图路由与编排基准见 [`followin-routing-primer.md`](./followin-routing-primer.md)。
> 本文件记录的是在官方 primer 之上、经实测得到的更具体约束与上游 bug——两者不冲突时以 primer 为准，
> primer 未覆盖或实测与之有出入的细节以本文件为准（差异已在 primer 文末列表说明）。
> 各 Skill 内联的 caveat 是本文件的本地镜像，**如有冲突以本文件为准**。
> 维护纪律：MCP 行为每次变更 → 先改本文件 → 再 sweep 6 个 Skill 的内联镜像。

## 调用红线（全 Skill 通用）

1. **asset_type 必须显式**：美股/大宗 `asset_type="tradfi"`，加密 `asset_type="crypto"`。不带会 fanout 双返污染（实测 BTC→美股 BTC Inc $33；AMN/WEST→crypto 山寨币 0.005 USDT）。**唯一例外：`news()` 不要传 asset_type**（is_tradfi 字段几乎全 false 老 bug，加 tradfi 返 0 results——0 篇不报错，比报错更危险）。例外扩展（2026-07-22 实测）：news 趋势模式（空 query）传 asset_type="tradfi" 可用且 quota=0；实体搜索亦 quota=0。"不传 asset_type"仅约束搜索模式的过滤语义。
2. **SSE 并发 ≤4**：单批 ≤4 路 MCP 并行，超了 session 可能挂。
3. **FRED macro 走 series_id 直查**：⚠️ **写法已变**（N-8）——`keywords=[...]` 数组被 schema 拒，改走 `query="<series_id>"`（实测 `query="DGS10"` 服务端正确回填 `keywords:["DGS10"]` 并返数据）。原写法 `keywords=["<series_id>"]` + `categories=["macro"]` 仅在 Dev 修好数组入参后恢复。禁止 query 中文/混合自然语言（4 类语义陷阱：含 series_id 也被错抓 / 中文混淆 / degraded / 静默兜底）。中英文 → series_id 翻译表见文末附表 A。
4. **B-31 边界**：FRED macro series **不要批量**（静默丢条目），各自单独 fire；market 行情快照可批量但**上限 5 个**（⚠️ 2026-07-27 实测修正：走 query 串时传 8 个被静默截断到 5，**且无任何 warning**；旧记载的"10 个上限 + `keyword_count_over_max` warning"是 keywords 数组时代的行为，该写法现已失效。见 N-23）。不要在同一次调用里混 market ticker 和 FRED series。
5. **news() query 三原则**：2-3 个核心名词；纯中文或纯英文不混搭；不写"影响/解读/分析/impact"等元词（embedding 过拟合 0 results）。单符号会被同名公司劫持（"CPI"→CPI Card PMTS），用双词消歧。news 无 sort_by 参数（相关性走 search_depth，默认 standard）。
6. **商品 ticker**：黄金 `GCUSD`（GOLD 错抓 Gold.com 美股 $42）；白银 `SIUSD`；**原油走 `USO`**；**不要用 GOLD/SILVER/OIL alias**。⚠️ **原油记载已于 2026-07-27 全面改写（N-30）**：`CLUSD` 返 0 结果、`BZUSD` 静默丢弃、`OIL` alias 返回 iPath ETN——三者均不可用，只剩 USO（WTI 近月期货 ETF，**属代理指标非现货价**，引用须说明口径）。
7. **fundamentals comprehensive 必须显式 `query="全面分析"`**（或 `"comprehensive analysis"` 精确双词）：不带 query 走 default 只返 5 block；带 query 返 14 block（仅缺 stock_peers）。`query="comprehensive"` 单词无效。
8. **历史 OHLCV / 技术指标各自单调**：历史必须 `query="历史走势 30 day chart"` + `time_range`；RSI/EMA/SMA 用 `query="RSI 14"` / `"EMA 50"` / `"SMA 200"` 单独调，不要靠默认 fanout（撞错路径无 fallback）。历史路径支持多 ticker 批量（实测 2026-06-12：3 ticker × limit 各自完整返回，无丢条；~20 个上限未实测）。
9. **mover 榜**：biggest gainers/losers 上游缺 marketCap 且全是仙股（trend-scout v1.8.0 实测）——弃用；改 `query="most active stocks"`，但实测（2026-07-22 2026-07-22 回归）board 行亦不带 marketCap（trend-scout 旧版记载已失效）——候选 ticker 需二次批量快照补市值后再过滤：marketCap ≥$1B + 剔杠杆 ETF。movers 仅美股。<br>⚠️ **2026-07-27 实测修正两点**：①ETF 过滤正则须为 `ETF\|ETN\|UltraPro\|Ultra\|Leveraged\|\dX\|Bull\|Bear\|Daily`——**只判 "ETF" 单词会漏**（`ProShares UltraPro QQQ`/TQQQ 与 `ProShares - UltraPro Short QQQ`/SQQQ 的 name 都不含 "ETF"）；②**慎用"仙股 <$5"闸**，实测误杀 GRAB（$3.31 但市值 $131 亿），市值闸是更准的同类过滤，价格闸只在市值不可得时兜底。
10. **经济日历**：`metrics(keywords=["economic calendar"], categories=["macro"])`。query 别带"本周"——实测（2026-06-12）"本周"被解析成 lookback 7 天，返回**已发布历史**而非前瞻日历。
11. **news() 无匹配时不返回空，返回语义兜底的不相关内容**（实测 2026-06-12：查 Quhuo/Navios 返回的是 BoJ/伊朗等宏观新闻填充）。**所有"报道 ≤ N"类判定必须按 LLM 逐条判断后的相关报道数计数，不能用 raw count**——否则填充内容会把"无声异动"误判成"有报道"。
12. **研报查询 query 必须含研报意图词**（"research reports" / "研报"等）：实测（2026-07-15）query 只放报告标题（如 `query="Can semi cap work if memory doesn't"` + keywords=["MU"]）**不会路由到 research-report 路径**，掉进 CORE fundamentals 默认全家桶（三表/估值/profile），且照常计 1 次额度。**钻取指定报告的正确姿势 = 保持 `query="research reports"` + `verbosity="detail"` 重查，客户端从结果挑目标报告**；无按 event_id/标题取单份的入参。返回分 `subject_reports`（主题报告）与 `mention_reports`（提及报告）两层。

## 已知问题登记（含 Dev 修复后回滚指引）

| 编号 | 症状 | 状态 | Workaround | Dev 修复后回滚动作 |
|---|---|---|---|---|
| B-18 | `keywords=["BTC"]` 不带 asset_type 时 fanout 到美股 BTC Inc（$33）污染 | Dev 待修 | 必传 `asset_type="crypto"` | 保留（显式总是更稳）|
| B-31 | FRED macro 批量 keywords 静默丢条目（如 BAMLH0A0HYM2 被丢）| Dev 待修 | series 单独 fire | 恢复批量（省调用数）|
| B-33 | BAMLH0A0HYM2 不在 FRED 字典，keywords 直查被错抓到 M2SL；CPIMEDSL 同类（被错抓 headline CPI）| Dev 待修 | 05 ⑦ 信用利差标"不可用"+ 权重重分配；02 Healthcare 退用 CPIAUCSL | 05 Batch 1 恢复调用 + ⑦ 恢复 5% 权重；02 Healthcare 换回 CPIMEDSL |
| — | news() 传 asset_type 返 0 results（is_tradfi 几乎全 false）| Dev 待修 | news 一律不传 asset_type | 各 Skill news 调用恢复 asset_type 过滤（防 crypto 混入）|
| — | fundamentals comprehensive 缺 stock_peers | 已上报 | 输出"同行"部分标数据不可用 | 恢复 peers 展示 |
| — | OIL/GOLD/SILVER alias 错路由 | Dev 待修 | 金银用 `GCUSD`/`SIUSD` 具体 ticker；**原油的具体 ticker 现已全部失效，只能用 USO 代理（N-30）** | 金银可继续用具体 ticker；**原油需 Dev 修复 CLUSD/BZUSD 才能拿回现货价** |
| — | insider 全量扫描聚簇（同公司多笔 filing 连排；2026-06-12 实测 SPCX Form 3 占 50 条中 13 条）| 数据特性 | `limit=50` + `sort_by="amount"` + 客户端按 ticker 去重 + 只留 formType="4" 的 P-Purchase；F-InKind/M-Exempt 为缴税代扣非主动交易；对外表述"内部人卖出"只认 S-Sale，买入只认 P-Purchase。 | —（数据特性，非 bug）|
| — | 经济日历 query 带"本周"触发 lookback 返历史 | 行为特性 | 用 keywords 形式（红线 10）| —（语义解析特性）|
| — | 研报无单份钻取入参：query 放报告标题会掉 fundamentals 默认集（红线 12，实测 2026-07-15）| 建议 Dev 增 event_id 入参（P2）| 保持研报意图词 + detail 重查 | Dev 支持 event_id 后可按 ID 直取 |
| — | trader_position 美股标的覆盖**日级剧变**（实测 07-09 MU 4 人 vs 07-15 MU 1 人、海力士从无到 3 人）；且同一标的可能符号分裂成多组（海力士 underlying=000660.KS 散在 SKHYNIX/SKHX/SKHY 三个 symbol）。⚠️ **剧变粒度已被 N-59d 收紧到分钟级**（18 分钟内 SNDK 4 人→5 人）；字段级陷阱见 **N-59 组** | 数据特性 | 任何对外用途都当天现拉；空 keywords 拉 trending 看当前有货标的；符号分裂需按 underlying 合并 | —（数据特性，非 bug；符号分裂可提 Dev 归一）|

### 2026-07-22 社群 bundle 实测新增（N 系列）

| 编号 | 内容 | Workaround | 来源 |
|---|---|---|---|
| N-1 | news 趋势模式（空 query）传 asset_type="tradfi" 可用且 0 额度；"news 不传 asset_type"红线仅适用搜索模式。实体搜索亦 0 额度 | news 趋势模式（空 query）传 asset_type="tradfi"；实体搜索亦无额度消耗 | 实测 2026-07-22 |
| N-2 | ~~earnings calendar 市场级可用（query+date_from/to），但返回全球交易所混排、无市值字段~~ **❌ 2026-07-27 作废，以 N-22 为准**："市场级可用"的定性是错的——服务端 `ORDER BY date, symbol LIMIT 50` 且不尊重 limit，任何跨天/全市场用途都只能拿到极小的字母前段切片。**过滤规则（无后缀 symbol + revenueEstimated 初筛 + 二次补市值）本身仍有效，但过滤的输入集从一开始就是残缺的** | **见 N-22**：不可作发现腿，不可作"某日/某周全部财报"对外发布 | 实测 2026-07-22 · **2026-07-27 推翻定性** |
| N-3 | 研报同一份报告可双 event_id 重复入库；按 机构+标题+日期 去重 | 按 机构+标题+日期 去重 | 实测 2026-07-22 |
| N-4 | signal 不带 categories 默认 fanout 全 4 类且只计 1 额度（省额度利器）；kol_call tradfi 聚合原生可用（top_calls 多空计数） | 不带 categories 时走 fanout 全 4 类、只计 1 额度 | 实测 2026-07-22 · **复核 2026-07-24 仍有效**：NVDA + `asset_type="tradfi"` 两组不同 query 均 `quota.consumed=1`，但只返回 `insider_trading` / `institutional` / `kol_call` **三类**——`trader_position` 未出现（该标的当时无持仓行，非 fanout 失效——见上表「trader_position 美股标的覆盖日级剧变」行）。**依赖 fanout 时不要假定四类恒在，按实际返回的 key 判断** |
| N-5 | kol_call 原帖按提及 fanout 成多行（同 URL 不同 symbol/方向）；按 source_url 去重、symbol 字段归属 | 按 source_url 去重/symbol 归属 | 实测 2026-07-22 · **复核 2026-07-24 仍有效**：同一条 `$MU $GOOGL $NVDA` 推文返回 3 行，仅 symbol / sector 不同，其余字段完全相同 |
| N-6 | insider/congress 行无视 time_range（7d 返回 2020 年记录）；客户端按 transactionDate 过滤强制 | 客户端按 transactionDate 过滤强制 | 实测 2026-07-22 |
| N-7 | 13F institutional 申报季中期 investorsHolding 环比为残缺假信号（实测 NVDA 6234→1441）；申报季内禁止引用环比 | 申报季禁引环比 | 实测 2026-07-22 · **复核 2026-07-24 仍有效**：同一标的 investorsHolding 已回补到 1882（`ownershipPercentChange` −64.4%、`putCallRatioChange` +174% 同为残缺假信号），说明申报季回补持续进行中，环比字段在季内任何时点都不可引用 |
| N-8 | keywords/categories/sources 数组参数 2026-07-20 起全域被序列化成字符串遭 schema 拒；统一走 query 串，服务端自解析（meta.filters_applied.keywords 可验证） | query 串替代；Dev 修复后回退 | trend-scout v1.11.x + 2026-07-22 复现 · **复核 2026-07-24 仍未修复**：`categories=["institutional"]` / `sources=["twitter"]` 均报 `-32602 … has type "string", want one of "null, array"`；根因是这三个入参在 tool schema 中为无类型 `{}`，客户端无从判断该序列化成数组。改走 query 串后服务端正确回填 `meta.filters_applied.keywords=["NVDA"]` |
| N-9 | biggest gainers/losers 上游缺 marketCap 且全是仙股，禁用；改 `query="most active stocks"`，但实测（2026-07-22 2026-07-22 回归）board 行亦不带 marketCap（trend-scout 旧版记载已失效），需二次批量快照补市值后过滤；红线 9 的过滤清单继续沿用 | 改 query="most active stocks"；客户端 marketCap ≥$1B 过滤 + 剔杠杆 ETF + 仙股 <$5 | trend-scout 实测（N-9）＋2026-07-22 回归修正 |
| N-10 | metrics time_range <1d 返一个月前旧数据 bug；小时级用 interval 参数或只用实时快照 | 小时级用 interval/实时快照 | trend-scout 实测（N-10）|
| N-11 | ~~指数类 ^GSPC ^IXIC ^DJI ^VIX 可用；^DXY/CLUSD/NGUSD 为 402 Special Endpoint 禁调——与红线 6 的 CLUSD 记载冲突，实现时复核后统一 SSOT~~ **✅ 2026-07-27 复核结案，见 N-30**：CLUSD 现象已非 402 而是 `no_match` 返 0 结果 | 指数白名单 ^GSPC ^IXIC ^DJI ^VIX 可用；**原油相关一律见 N-30** | trend-scout 实测 · **2026-07-27 复核结案** |
| N-12 | query 串批量会静默丢弃部分 ticker（实测 2026-07-22：9 个 ticker 空格拼串仅解析出 5 个，ONDS 连续两次被跳过且无任何 warning） | 批量调用后必须核对 `meta.filters_applied.keywords` 与请求清单一致，缺失者单独补调 | 实测（2026-07-22 回归） |
| N-13 | signal consensus 聚合疑似对 time_range 不敏感（3d 与 24h 共四次调用返回 total_posts/多空比/榜单完全一致；可能数据池小到收敛，证据不足定性） | 对外表述窗口用词保守（"近幾日"而非精确小时数）；后续以 3d vs 30d 大窗口差异复验 | 实测（2026-07-22 回归，待复验） |
| N-14 | query 串里的普通英文词会被当 ticker 抽取：实测 `query="GOOGL earnings beat miss analyst ratings"` 解析出 `keywords=["GOOGL","BEAT"]`，把仙股 HeartBeam(BEAT,$0.55) 行情混入快照 | query 只放 ticker + 中文意图词（如 `"GOOGL 财报 分析师评级"`）；禁用 beat/miss/hold/buy/now/all 等会撞 ticker 的英文词；调用后核对 `meta.filters_applied.keywords` | 实测（2026-07-23 GOOGL 财报夜实跑） |
| N-15 | 财报当晚 `fundamentals.beat_miss` 仍是上一季数据（实测 GOOGL 7/22 盘后发 Q2，当晚返回的仍是 4/29 Q1），FMP 侧延后更新 | 当晚"实际 vs 预期"一律取 `news()` 媒体/披露原文（0 额度），metrics 只用于盘后快照与目标价；次日后才可用 beat_miss 复核 | 实测（2026-07-23 GOOGL 财报夜实跑） |
| N-16 | `consensus_price` 无分析师家数字段（仅 targetConsensus/High/Low/Median），而 c3/c6 规则要求"目标价必带家数+分歧幅度" | 家数不可得时明确标注"家数未提供"，只给区间+中位；需要家数时改由 `analyst_grades` 近 N 条按机构去重估算并注明是估算 | 实测（2026-07-23） |
| N-17 | 财报日历漏掉当天美股大票：实测 2026-07-23 当日 30 条全被印度/欧洲/OTC 小票占满，而 AAL 的 `next_earnings_estimate.date` 明确是当天，日历却无此股 | limit≥100 + 客户端只留无后缀美股 symbol 并剔优先股(-P) + 对重点标的用 `next_earnings_estimate.date` 交叉验证；名单不全时如实标注 | 实测（2026-07-23 实跑） |
| N-18 | 指数 query 串产生重复行：`"^GSPC ^IXIC ^DJI ^VIX"` 解析出 5 个 keywords（多一个裸 VIX），^VIX 返回两条相同行 | 客户端按 symbol 去重后再引用 | 实测（2026-07-23） |
| N-19 | 研报榜排名基于 mention count，钻取时可能 `subject_reports=0` 只有 `mention_reports`（实测 GOOGL 榜单第 2、66 篇提及，但主题报告为 0，4 篇全是行业报告里的提及） | 榜单高位≠有专题报告；钻取后必须检查 subject/mention 两层比例，只有 mention 时贴文须写明"是被行业报告提及，不是专题研究" | 实测（2026-07-23） |
| N-20 | `signal(query="详细仓位")` 不带 ticker 时返回全市场原帖，体积极大（实测 2026-07-23：13.7 万字符 / 139 行），直接读入会撑爆上下文 | 客户端脚本先聚合再消费：按 `source_url` 去重（一帖按提及裂多行，139→96）→ 按 symbol 分组统计多空 → 只保留结构化摘要；或用 limit 收窄 | 实测（2026-07-23 讯号汇总实跑） |
| N-21 | 研报调用 `meta.warnings` **误报** `default_fanout_fallback`（"no specific topic…returning the CORE fundamentals set"），但 payload 里 `fundamentals.research_reports` 数据齐全 | **该警告是假阴性，不要据此判定失败或重试**——重试白烧 1 次额度。以 `results.fundamentals.research_reports` 是否存在为准，不看 warning | 实测 2026-07-24：`metrics(query="NVDA research reports", verbosity="detail", time_range="7d", asset_type="tradfi")` → 6 篇 subject + 4 篇 mention，含 institution / analyst / target_price / rating_action / thesis / key_caveat / latest_catalyst，quota=1 |

### 2026-07-27 财报季扫描器实测新增（N-22~N-26）

| 编号 | 内容 | Workaround | 来源 |
|---|---|---|---|
| N-22 | **earnings_calendar 不可作发现腿**（⚠️ 本条升级 N-2「市场级可用」与 N-17「漏大票」的定性——问题比"漏"严重）。**单一根因**：服务端等效于 `ORDER BY date ASC, symbol ASC LIMIT 50`，且 `limit` 入参不被尊重（传 20 返 20，传 100/300 均返 50，`total` 恒为 50）。由此派生三种表象：<br>①**历史区间看起来"只覆盖首日"**——因为那些日子当天就 >50 行，轮不到第二天（请求 07-20~07-27，20 行全是 07-20 且止于 `ACE.NS`；请求 07-22~07-25，50 行全是 07-22 且止于 `456040.KS`）<br>②**未来区间可跨天但同样在第 50 行断**——请求 07-27~08-03 八天，50 行 = 07-28 全天（`0HOX.L`→`VM.V`，A–V 全字母段约 45 行）+ 07-29 开头 5 行（`000660.KS`…），**07-30 至 08-03 完全为空**<br>③**字母序偏置**——数字/纯符号 symbol 排在字母前，字母段又按 A→Z，所以字母靠后的美股大票（GOOGL/MSFT/NVDA/TSLA）在"当天行数多"的日子必然出局<br>⚠️ 另有**重复行未去重**：同一 symbol 同一天可出现两行仅 `lastUpdated`/数值不同（实测 `ACE.BO`/`ACE.NS` 各两行、`GOODLUCK.BO`/`.NS` 与 `ORIENTBELL.BO`/`.NS` 成对重复），进一步挤占本就只有 50 的名额<br>⚠️ **`country` 参数对本 block 无效**（见 N-32）<br>❌ **所有客户端杠杆已穷尽验证，无一有效**（2026-07-29 复测，问题未修复）：<br>· `limit=100` → `total` 仍 50 ｜ · `country="US"` → 返回**逐行一致** ｜ · `include_penny_stocks=false` → 返回逐行一致，且 `meta.filters_applied` **连回显都没有**（静默忽略） ｜ · `query="US earnings calendar large cap"` → 返回逐行一致，还把 "US"/"CAP" 当 ticker 解析（N-14） ｜ · **逐日拆分** → `date_from=date_to=2026-07-29`（密集日）仍返 50 行砍在 `0KAB.L`，未进美股字母区；只对当天 <50 行的清淡日有效，而财报季全是密集日<br>📌 **偏置的极端例证**：2026-07-22 的 50 行里**无后缀美股数量 = 0**，全被数字开头与伦敦 `.L` 票占满。其中 **Alphabet 出现了——以法兰克福上市的 `ABEA.F` 身份**（EPS 7.98 vs 预期 2.52）；同一家公司，`GOOGL` 因字母序永远进不来。**这不是"漏了几只"，是按 symbol 首字符决定生死** | **发现层改用 `query="most active stocks"` 异动榜 + `news()` 双腿**；日历仅可用于对**已知 ticker** 的单点日期核对，**绝不可作为"某日/某周全部财报"对外发布**。前瞻名单改由 `fundamentals.next_earnings_estimate.date` 对**维护好的关注池**逐个核实——准确，但只覆盖已知名单，**必须对外声明"名单来自关注池而非全市场扫描"** | 实测 2026-07-27（历史区间 ×3 + 未来区间 ×1 + 单日密集日 ×1 + limit 20/50/100/300 四档交叉验证）|
| N-32 | **`country` 参数只作用于 `results.macro.calendar`（经济日历），不作用于 `results.fundamentals.earnings_calendar`（财报日历）**。两者名字近似但是两个独立 block，极易混淆——实测对照：<br>**财报日历**同 `query="earnings calendar"` 同日期区间，传与不传 `country="US"` **返回完全相同的 20 行**（全为 `.L`/`.SR`/`.TW`/`.F`/`.KL`/`.SS`/`.BO`/`.NS`，零美股）｜request_id `ac352acb1b8f434a84b7342a12aa8e29`（不传）vs `7e03620d9ce67884d1425bff8cefe5f0`（传）<br>**经济日历**同 `query="economic calendar"`（**刻意不在 query 里写 "US"，排除查询词收窄的混淆**），不传 → CN/JO/KR/MY 事件；传 `country="US"` → **100% 美国事件**｜request_id `58e6c189ca07c63306afc7c519ec12ac` vs `1886041cff22082fc795a7d235d616ea` | 需要按国别筛**财报**日历时：`country` 帮不上忙，只能客户端按 symbol 后缀过滤（无后缀≈美股，但 5 字母 F 结尾的 OTC 外国发行人如 `ASMXF`/`CGGGF` 会混入）。**排查此类问题时先确认自己在看哪个 block** | 实测 2026-07-27（两组四次对照调用，request_id 已附）|
| N-23 | **query 串 ticker 解析有两种独立故障，不要混为一谈**（N-12「会静默丢弃」的拆解与定量化）：<br>**(a) 批量截断** —— 上限 **5 个 ticker**，传 8 个只解析前 5 个，无 warning。<br>**(b) 上游字典缺失** —— 某些真实美股**任何 query 形态都解析不出**，单票调用也返回 `keywords: null` + 无 `concise`/`snapshot`，且 warning 把整个 query 串当成 FRED series_id 候选。对照实验：`query="NOK next earnings date"` 正常返回 `keywords:["NOK"]` + 完整数据；同形态的 `"JBLU next earnings date"` 返回 null。**已确认不可解析（累计 9 只，全是真实美股）：JBLU(JetBlue) / CUBI(Customers Bancorp) / ONDS(Ondas) / VIVK(Vivakor) / LVWR(LiveWire) / OTLK(Outlook Therapeutics) / AEHR(Aehr Test Systems) / NRC(National Research) / WERN(Werner Enterprises)** —— ONDS 与 N-12 记载的"连续两次被跳过"为同一现象。<br>**(b) 的两种 warning 形态可在补调前区分**：warning 里 `keyword` 是**整个 query 串**（如 `"VIVK LVWR OTLK next earnings date"`）＝**整批全废**，直接全部记缺口不必补调；成功的 ticker **各自出独立 warning** ＝部分缺失，缺的才补调。<br>**(c) 解析成功 ≠ 拿到数据（新增）**：实测 STAK 正常出现在 `filters_applied.keywords` 且 `market.snapshot` 有 marketCap，但 `fundamentals.concise` **无该条目**；SPCX 有 `concise` 条目却**整块 `beat_miss` 缺失**（有 latest_quarter / next_earnings_estimate）| 每批 **≤5 个 ticker** 规避 (a)。**做三道差集**：①`filters_applied.keywords` ②**`concise[].symbol`** ③逐条查 **`beat_miss` 是否存在**——只做①会把 STAK/SPCX 误判为成功，且闸门读到 undefined 不可当 0 处理。差集缺失者按上述 warning 形态判断，需补调的**最多 1 次**即放弃并记缺口（每次无效补调倒扣 1 额度）。**命中已知清单的直接跳过、0 额度**（实测省 3 次/轮）| 实测 2026-07-27（探针批量 + 验收实跑 + JBLU 单票复核 + v1.1 实跑三批复现）|
| N-24 | **fundamentals 三档体积**：①`query="<T> next earnings date"` → **~5 KB/票**（concise: beat_miss/consensus_price/eps_trend/latest_quarter/next_earnings_estimate + market.snapshot 含 marketCap，附赠 10 行无关 earnings_calendar）②`query="<T>"` 或 `"<T> 财报"` 或 `"<T> 财报 超预期"` → **~8.7 KB/票**（三者 byte 级完全相同，多出 balance_sheet×4 + cash_flow×4 + profile + valuation；中文意图词对返回**零影响**，纯废字符）③`query="<T> earnings call transcript"` → **~56 KB/票**（含完整逐字稿）。**transcript 仅在 query 明确含 `earnings call transcript` 时才拉取**，其余 query 绝不误带 | 批量验证用 ①（省 3 倍 context，且 marketCap 顺带拿到，可省掉独立行情调用）；只在 Top N 深扫时用 ③ | 实测 2026-07-27 |
| N-25 | `news(limit=N)` 实际返回 **2N 条**（N 篇 `articles` + N 条 `social`，`total`=2N）。且 **social 桶的美股 ticker 密度高于 articles 桶** | 估算返回体积按 2N 算；抽 ticker 时两个桶都要解析，别只看 articles | 实测 2026-07-27 |
| N-26 | news query 句式决定命中率（同为 7d/limit=10）：**陈述业绩事实**句式 `record quarterly revenue results` 优于 `earnings beat raised guidance`，两者均远优于**情绪涨跌**句式 `earnings surprise stock surges`（被日韩欧股+加密+纯宏观淹没）。⚠️ **绝对命中率波动大，不可当基准**：07-23 实测 13/20 与 8/20，07-27 复测同样两条降到 **8/20 与 6/20**（情绪句式 3/20）——**相对排序稳定，绝对值不稳定**。另 `beat` 一词在 news 侧误伤形态多样：实测撞上**棒球比分报道**、加密代币 $BEAT、以及一条**路透社罗兴亚难民报道**（"two men threatened to beat her"）| 用陈述业绩事实的句式；避开 surge/soar/jump 等涨跌词与 beat。**用命中率排序可以，用它设阈值不行** | 实测 2026-07-27（07-23 首测 + 07-27 复测） |
| N-27 | `verbosity` 参数对 metrics **无效**：`concise` 与 `standard` 返回 payload 一字不差，仅 `meta.verbosity` 字段变化 | 不用传（传了也不省 context）；省 context 靠 N-24 的 query 后缀 | 实测 2026-07-27 |
| N-28 | **transcript 的 `_meta.freshness` 是硬编码常量，不是动态信号**：恒为 `"q-1"`。实测 INTC / GOOGL / CMCSA / IQV / CDNS 五份逐字稿内容均为**本次财报**（当季），freshness 照样写 `q-1`。⚠️ **强化定性（2026-07-29）**：它不是"有时对有时错"，而是**恒定值恰好与某些情况重合**——拿它判新鲜度会把 **100% 的当季逐字稿误判成滞后** | 核对逐字稿季度一律看 `transcript[0].date` / `period` / `year`，**永远不看 `_meta.freshness`**；预判是否滞后用 N-34 的 gap 判据 | 实测 2026-07-27（三份）· **2026-07-29 追加 IQV/CDNS 两份反例并强化定性** |
| N-29 | **同一 payload 内 GAAP 与非 GAAP EPS 并存且互相矛盾，无字段标明口径**：实测 INTC `beat_miss.epsActual = 0.42`（非 GAAP，对预期 +100%）与 `latest_quarter.eps = −2.16` / `netIncome = −$110.3 亿`（GAAP 巨亏）同处一个返回。只看 beat_miss 会把巨亏季读成"完美超预期" | 凡引用 `beat_miss.epsActual` 必须同时取 `latest_quarter.eps` 比对：**两者反号即判定口径错位**，对外表述强制标注"该超预期为非 GAAP 口径"；营收 surprise 才是可信主锚 | 实测 2026-07-27 |
| N-30 | **原油符号四种写法实测三死一活**（结案 N-11 与红线 6 的长期冲突）：`CLUSD` → `no_match` 返 **0 结果**（不是 402）｜`BZUSD` → query 串里被**静默丢弃**（实测 `query="BZUSD USO"` 只解析出 USO，不报错不返数据）｜`OIL` alias → 返回 **iPath Pure Beta Crude Oil ETN**（symbol OIL，$28.42，市值 5300 万）而非原油价格，且附带诡异 warning `asset_type=tradfi but all keywords resolved to other families (crypto)`｜**`USO` → 唯一可用**（United States Oil Fund，$136.52，市值 $163 亿，跟踪 WTI 近月期货）| 原油一律走 `query="USO"` + `asset_type="tradfi"`。⚠️ **USO 是期货 ETF 代理指标，不是现货价**，对外引用必须说明口径。红线 6 的"CLUSD(WTI)/BZUSD(布油)"记载已**全部作废**；10 号 Skill 原"布油 100% 命中"的记载是过期假声明（静默失败，跑了也不知道没拿到）| 实测 2026-07-27（四种写法逐一验证）|
| N-33 | **`beat_miss` 字段可为 null 但服务端仍参与运算，把缺失伪装成极端真值**（第 4 种数据缺失形态，比 N-23 的三种更危险）：实测 F(Ford) `revenueActual: null` / `revenueEstimated: 47237900000` → 服务端**把 null 当 0 做减法**，输出 `revenue_diff: -47237900000`、**`revenue_surprise_pct: -100`**。该条目 keywords 有、concise 有、beat_miss 结构完整，**N-23 的三道差集全部通过**，下游读到的是"营收暴跌 100%"这个假真值。<br>另：`beat_miss.date` 与 `latest_quarter.date` **季度对齐关系不固定**——实测 F 的 latest_quarter 落后**两季**（Q1 vs 07-28）、STX 落后一季（Q3 vs Q4）、V 反而**领先**一季（Q3 vs Q2） | ①**第 4 道检查**：`revenueActual` 非 null 才可读 `revenue_surprise_pct`；见到 `-100` 一律先当缺失查证（真实世界营收归零几乎不可能）②**N-29 的反号比对须先确认同季**：`beat_miss.date` 与 `latest_quarter.date` 不同季则该项判定作废并标注"口径无法核对"，跨季比对会让一盈一亏的相邻两季产生假阳性 | 实测 2026-07-29（v1.2 实跑 + F 单票复核）|
| N-34 | **`earnings call transcript` 的滞后是确定可算的，不是随机的**（⚠️ 本条已推翻初版"事前无信号可预判"的判断）：<br>**判据**：`transcript[0].period` **恒等于** `latest_quarter.period`。因此用 `gap = beat_miss.date − latest_quarter.date` 即可**事前预测**这次会拿到哪一季——两个字段同在轻量调用返回里，**零额外成本**。<br>**阈值 = 90 天（一个完整财季）**。⚠️ **初版取 60 天已被 42 样本证伪**——45~70 天区间**密集有样本且全部返回当季**（BABA 43 / BIDU 48 / NIO 51 / PDD 57 / TIGR 63 / EH 70，**几乎全是报告节奏慢的中概 ADR**，其中 PDD/TIGR/EH 三只已逐一拉逐字稿验证），60 天会把它们误判为滞后而跳过。<br>**分布（42 样本）**：10~34 天 24 个（美股本土大中盘，当季）｜**43~70 天 10 个**（中概 ADR，当季）｜**71~115 天 0 个**（未实测空白区，但有结构解释）｜116~119 天 3 个（滞后）。<br>**90 是从机制推的不是拍的**：gap 的物理含义即**财报公布滞后天数**——数据新鲜时 gap = 滞后本身（实测 10~70）；latest_quarter 落后一季时 gap = 滞后 **+ 一个完整财季（≈90）**。两者只可能差一个整季，故分界必在 90 量级。<br>❌ **"距财报日天数"假设已被实测证伪**：IQV 与 STX/KLAC **同为 2026-07-28 发财报**（距今均 1 天），IQV 返回当季而 STX/KLAC 返回上一季；CDNS 距今仅 2 天亦返回当季。同日相反结果 ⇒ 日历不是原因。<br>**机制**：`beat_miss` 走即时 surprise 源，而**财报三表与逐字稿是同一批入库**，入库快慢按个股而异，与日历无关 | **拉取前**先算 gap：**≥90 天**则该季尚未入库，transcript 必返上一季，**直接跳过调用**（省 1 额度），该股不占 Top N 名额、关键词闸标注"欠测"。<br>兜底：万一仍拉到季度不符，同样按"欠测"处理——低分=扫了没讲，欠测=根本没扫到，两者对下一步动作的指示相反 | 实测 2026-07-29（4 只专项探针 + INTC/TER/GOOGL/F 回验 + **36 只边界探针**，共 42 样本；判据在全部已测样本上 100% 成立）|
| N-36 | **有"影子代码"的 ticker 会在批量 query 里被双重展开，吃掉批次名额**（**非解析失败，是名额被挤占**）。两类实测：①**商品重名**——`CL`（Colgate-Palmolive）被同时解析成股票 `CL` **和原油期货 `CL=F`**，`filters_applied.keywords` 回填为 `["CL","CL=F","AON","PSX","HCA"]` —— 占满 5 个名额，导致该批第 5 个请求项 NUE **被顶出**（非解析失败，是名额被挤占）；②**中概 ADR 双重上市**——`BABA` 被展开成 `BABA` **+ `9988.HK`**（港股），顶掉同批的 `LI` | 含 `CL`/`GC`/`SI`/`NG`/`HG`（商品重名）或 `BABA`/`JD`/`NTES`/`BIDU` 等在港二次上市的中概时，**该批按 4 个装**，或把这类符号单独放一批。调用后照例核对 `filters_applied.keywords` 与请求清单做差集 | 实测 2026-07-29 |
| N-35 | **个别实体存在 news 召回黑洞，且语义兜底返回的是固定集合而非随机内容**：实测 `query="Bloom Energy BE"` 与 `query="Bloom Energy"` 返回**逐字完全相同的 12 条**兜底内容（Bear Grylls／悼文／美联储／Claude 链接泄露…），**0 条目标公司内容**；而索引里确实有 BE 内容（其他 query 的返回里出现过 BE 财报标题与 3 条 `$BE` 社媒）。同一轮 `query="Teradyne TER"`/`query="Visa V"` 均精准命中，故 N-15 双词形态本身有效 | ①**同 query 重试无意义**，换措辞亦无效（去 ticker 后逐字不变）②**两个不同标的的降级查询若都失败会拿到一模一样的内容**——不逐条核实相关性极易误判成"两票有共同报道"③判别：返回里**一条都不含目标公司名或 ticker** 即判召回失败，记缺口不重试 | 实测 2026-07-29（两组 query 对照 + 跨 query 交叉验证索引确有内容）|
| N-31 | **7 个 v2 Skill 的 `keywords=[...]` 写法全域失效**（N-8 的影响面盘点）：`~/.claude/commands/` 下 08/09/10/11/12/13/14 共 **107 处** `keywords=[...]` 调用示例，按 N-8 全部会被 schema 拒（`-32602`）。模型实跑时会撞错一次再自行改写成 query 串，属"可恢复但每次白烧一次失败调用"| 正确替代形态实测确认：FRED 指标 `query="DGS10"`（服务端正确回填 `keywords:["DGS10"]` 并返数据）；行情 `query="<T1> <T2> ... 行情"`（≤5 个）。**尚未 sweep，待专项处理** | 实测 2026-07-27（keywords 数组复现被拒 + query 替代形态验证） |

### 2026-07-30 twitter list / user_tweets 实测新增（N-42~N-46）

> 本组来自「能不能给公开模板内置一个 Twitter list」这个问题的实测。结论：能读，但失败模式全是静默的。

| # | 现象 | 应对 | 证据 |
|---|---|---|---|
| N-42 | **不存在 / 已私密 / 已删除 / 真的空 —— 四种情况返回上完全无法区分**：伪造 `list_id=1234567890123456789` → HTTP 200 + `results: []` + `total: 0` + `filters_applied: null` + **无任何报错**，且**照样扣 1 credit** | 任何把 list 当数据源的地方，**返回 0 条一律判失败并显式提示「list_id 可能已私密/删除/写错」**，不许当成"今天这个 list 没人发推"。用别人的 list 时尤其要紧——所有权变更不会有任何通知 | 实测 2026-07-30（真假 list_id 对照） |
| N-43 | **`list_timeline` 与 `list_tweets` 各缺一半，且互不包含**。同一 list 同一重叠窗口：`list_tweets` 独有 5 条 reply + 一个 `list_timeline` 里从未出现的成员（40.6k 粉）+ **一条既非 reply 也非 RT 的正常原创长推**。粗略倾向是 timeline 收 RT 弃 reply、list_tweets 收 reply 弃 RT，**但不稳定**——对照组 list 用 `list_timeline` 也返回了 `isReply: true` 的条目 | **推翻了"list_timeline 是对的那个"这个旧说法**。日常用 `list_timeline`；要完整样本必须两个都拉并**按 `id` 合并去重**。两个端点都不报错，用哪个都不会有提示告诉你样本残缺 | 实测 2026-07-30（重叠窗口逐条比对） |
| N-44 | **分页丢块量化**：三页 60 条，墙钟跨度 20h29m，**真实覆盖仅 6h10m ≈ 30%**；两个空洞 6h13m / 8h05m。第一个空洞正好落在**美东午盘+盘后**，而该 list 含三个快讯搬运号（其一 45650 条推文），那段时间不可能一条不发——按页内 15–20 条/小时的密度，应有 200+ 条被丢 | ①**别指望翻页凑出"一天的量"**，页数越多丢得越多；②判 list 产能只用**最新一页的连续头块**，禁止用「全量条数 ÷ 全量跨度」；③简报里写「回看 Xh」而不是「今日全量」 | 实测 2026-07-30 |
| N-45 | **同一工具不同 action 的字段集不同**：`list_timeline` 返回**没有** `inReplyToUserId`（判 reply 只能用 `isReply` / `inReplyToId`）；而 `user_tweets` **有** `isReply` / `inReplyToId` / `inReplyToUserId` / `inReplyToUsername` / `conversationId` 五个，且 60 条样本内每条都物理存在（非 reply 时是显式 `null` 而非键缺失） | **不许把一个 action 的字段观察套到另一个 action**。⚠️ `conversationId` 恒有值（非 reply 时等于自身 id），**不能用它是否为空判 reply**。`include_replies` 只影响筛选不影响字段结构（实测 `true` → 20 条含 13 reply；不传 → 0 reply） | 实测 2026-07-30（两个 action 分别取样） |
| N-46 | **`quoted_tweet` 三层嵌套且第三层是空壳**（只有 id，`author: {}` / `text: ""` / `createdAt: ""`）；同一条推会在同一页里既作为顶层 item、又作为别人的 `quoted_tweet` 出现。另：**`entities.symbols` 不可靠**——实测一条正文提近 10 个代币，`symbols` 只列 1 个 | ①解析 list 返回**必须按 `id` 去重**，否则同条推重复计数；②第三层嵌套是纯 payload 膨胀，jq 时直接丢；③**别拿 `entities.symbols` 当提取标的的唯一来源**，要正文正则兜底 | 实测 2026-07-30 |

> ⚠️ **未解决**：返回文本里出现 `cash-cat:native` / `xyz:SP500` / `xyz:MU` 这类冒号命名的资产标识，
> 且与完好的 `$Sundog` / `$Brett` 混在同一条推里。无法在只读前提下判定是 MCP 侧做了实体替换、
> 还是原推本来就这么写（Hyperliquid 的股票永续确实用 `xyz:` 前缀）。
> **确定的影响**：任何 `$TICKER` 正则都会漏掉这些。

### 2026-07-30 trader_position 端到端实测（N-59）

> 来源：一次「在 trader_position 上做模拟跟单账本」的可行性验证——摸底 + 真建了一份 17 仓账本跑通建账流程。
> **该方案最终被否决**（理由见 CHANGELOG 同日条目），但这组数据面结论独立成立，任何要消费 `trader_position` 的地方都适用。
> 调用：空关键词全榜 2 次 + 单标的定向 3 次 + 价格锚 4 次；样本 = 5 个标的组 / 17 条仓位行 / 15 名交易员
> （`request_id` `f3d1555913…`、`d1516e54d0…`、`a0e138c956…`、`1f1a85335e…`、`32da17cdcd…`）。
> ⚠️ 本组多条是**真拿它算东西才会暴露**的问题：只读单次返回看不出来，一旦用来算收益或判方向就会静默出错。

| # | 现象 | 应对 | 证据 |
|---|---|---|---|
| N-59a | **notional 派生的 rollup 字段会给出反向结论**——`gross/net_notional_value_usd`、`long_notional_ratio`、`short_notional_ratio`、`net_direction` **只统计有名义的行，null 行被静默排除**（不是记 0，是不参与）。实测 CXMT：4 条仓位 3 多 1 空、其中 3 条 notional 为 null，`long_notional_ratio` 报 **1**、`net_direction` 报 `long`——读起来像"一致看多"，实际是 3:1 且总敞口未知。实测 XYZ100：2 条全 null → `gross=0`、`long_notional_ratio=0`、`net_direction="balanced"`，实际是 1 多 1 空（方向对立而非均衡）。<br>⛔ 同一个 rollup 里**按人数的字段是对的**：`agreement.ratio`（CXMT 0.75 = 3/4 ✅）、`long.count`/`short.count`（3/1 ✅）、`active_trader_count` | **判多空一致性只用按人数字段**（`agreement.ratio` + `long.count`/`short.count`）；notional 派生字段只有在该组 null 率为 0 时才可引用，且必须先自查 null 率。**`net_direction="balanced"` 不可读作"多空均衡"**——它同时覆盖"真均衡"和"全员 null"两种情况 | 实测 2026-07-30（16 行中 7 行 notional 为 null = **44%**）|
| N-59b | **`entry_price` 只在 `action=open` 的行上出现**：16 行里仅 **1** 行有（T16 SNDK `entry_price=1123`），add/reduce 行全无。且**没有** unrealized PnL / margin / liquidation price 类字段（逐层扫过 position 行 13 个字段全集）。<br>另：**交易员档案只有聚合统计**（`overall` / `last_30d` / `focus_symbols` / `caution_symbols`），**没有逐笔历史** | 跟单账本**只能前向跟踪、无法回测**——这是数据形态决定的，不是调用姿势问题。开仓价一律用"观察时刻锚价"并把口径写进产出（真实跟单者同样只能在看到信号时进场）。**不要基于 `entry_price` 设计任何算收益的逻辑**，它的覆盖率是 6% | 实测 2026-07-30 |
| N-59c | **一部分标的取不到任何价格**：`metrics(query="CXMT XYZ100 price", asset_type="tradfi")` 返回 `results:{}` + `status:"ok"` + `no_match`——**0 结果不报错**。且 `filters_applied.keywords` 只剩 `["XYZ100"]`，**CXMT 被静默丢弃**（连尝试都没有）。<br>✅ 能取到的：`SNDK` $1015.63（USD）、`000660.KS` ₩1,322,000（**KRW，不是 USD**，`profile_block.currency` 明示）<br>⛔ **必须用 `underlying_symbol` 取价，不能用 `symbol`**：实测 `SKHX` 的 underlying 是 `000660.KS`——前者无覆盖，后者有 | ①永续标的里有非上市/合成标的（CXMT=长鑫存储未上市、XYZ100=合成指数），这类仓位标 `unpriced`：跟方向、**排除在收益统计外**、单独报条数——不编价格也不假装不存在；②**收益一律先算百分比再乘虚拟名义**，跨币种才能同表比较，**绝不做汇率换算、绝不把不同币种锚价放进同一个减法**；③取价前先按 `underlying_symbol` 归一 | 实测 2026-07-30 |
| N-59d | **热门榜是实时快照，日内就会变**：两次拉取相隔 **18 分钟**（08:24:29Z → 08:42:53Z），SNDK 的 `active_trader_count` 从 **4 变 5**（新增T15，`event_time=08:31:24Z` 正落在两次调用之间）。<br>⚠️ 因此**"全榜里没有它"≠"该仓位已平"**。<br>另：样本里 `is_active` **16/16 全为 true**、`action` 无一条 `close`（add 9 / reduce 6 / open 1）——**平仓事件在本次样本里从未观测到** | 账本类用途必须**双路取数**：全榜拉当前有货标的 + 对账本内未平仓标的**逐个定向查询**确认。平仓判定退化为"两路都查不到 → 消失推断"，并**记录发现滞后天数**（= 平仓日 − 最后一次见到的日期）如实暴露观察误差。close/is_active=false 机制上可能支持，**样本内未出现，不要假设一定能抓到** | 实测 2026-07-30（同日两次拉取对照）|
| N-59e | **`signal()` 按交易员名字查询不生效**：`query="T1 交易员仓位 trader position"` 返回的是**完整热门榜**（CXMT/SNDK/SKHX/BTC/XYZ100 五组，与空关键词查询一致），**没有按人过滤**。人名不是可路由的实体维度 | 任何"看某个交易员"的功能只能**拉全榜再本地过滤**，且必须把话说准：拿不到时说"当前榜上没有他"，**不能说"他没有仓位"**。不要对外承诺按人全网检索 | 实测 2026-07-30 |
| N-59f | **`signal()` 的 `categories` / `keywords` 数组入参在本客户端被序列化成字符串后被 schema 拒**：`categories=["trader_position"]` → `type: ["trader_position"] has type "string", want one of "null, array"`。与红线 3（N-8）的 `metrics.keywords` 同源，此前只记了 metrics 侧。<br>另：**取价调用必然附带整套 CORE fundamentals**（`default_fanout_fallback`），实测把 query 从 `"… price"` 改成 `"… quote snapshot"`、再加 `verbosity="concise"` **都去不掉**——三表/估值/profile 照样全返 | ①`signal` 与 `metrics` 一律走 `query` 自由文本路由（服务端会自己抽意图与标的，实测 `filters_applied.keywords` 正确回填）；②取价时**只读 `results.market.snapshot[]`，其余忽略**——额度仍只计 1 次，代价是 token 不是配额；③批量取价上限沿用红线 4 的 **5 个** | 实测 2026-07-30 |
| N-59g | **取价失败有两种静默形态，且都返 `status:"ok"`——必须做差集自查**。实测一次 `metrics(query="SNDK 000660.KS CXMT XYZ100 quote snapshot", asset_type="tradfi")`：①**`CXMT` 被从 `filters_applied.keywords` 里整个剔除**（applied 只剩 `["SNDK","000660.KS","XYZ100"]`，连查都没查）；②**`XYZ100` 进了 keywords 但 `market.snapshot[]` 里没有它的行**（默默少一行）。两种都不报错、不出 warning 指名道姓。<br>另：**crypto 批不带 fundamentals**（`asset_type="crypto"` 只返 market.snapshot + history，很轻），**tradfi 批必带 CORE fundamentals 全家桶**（N-59f）——同一个"取价"动作两种成本 | **把请求的 symbol 列表与返回的 `snapshot[].symbol` 做差集，差集非空即部分失败**——不要用"有没有报错"判断成败，也不要用返回行数对比请求个数（两种形态一个少 keyword 一个少行，只有差集能同时抓住）。crypto 与 tradfi 分批（asset_type 不能混），批内 ≤5 个 | 实测 2026-07-30（4 标的混批，2 成 2 败）|
| N-59h | **`profile.summary` 的散文数字比同对象的结构化字段旧，不可引用**。实测T4：`summary` 写 *"across 406 closed trades"* / *"150 closed trades in last 30 days"*，而同一 profile 的 `overall.n_trades=431`、`last_30d.n_trades=175`——**双双差 25 笔**。该交易员 30 天 175 笔，几小时就能差出这个量；`summary_refreshed_at`（02:37Z）落后于数据本身。对照组：T8同批 summary 22/17 与结构化字段完全一致——**所以"看起来对得上"不能当验证通过**，一致与否取决于该交易员的成交频率 | **所有对外数字一律取结构化字段**（`overall` / `last_30d`），`summary` 只当定性描述（style / follow / skip conditions）读。⚠️ 尤其别把 summary 里的笔数当样本量去判"样本是否充足" | 实测 2026-07-30（T4 vs T8对照）|
| N-59i | **同一份 `trader_position` 返回里两半新鲜度不同：仓位/事件实时，交易员 `profile` 是日快照**。实测 30 分钟内两次拉取（08:24Z / 08:55Z），15 名交易员的 `overall` / `last_30d` / `as_of` / `summary_refreshed_at` **全部一字未变**（`as_of=2026-07-30`，refresh 时点约 02:3xZ），而同期仓位侧新增了T15的 08:31Z 事件（N-59d）。<br>⛔ **`last_30d.n_trades` 是滚动 30 天窗口，日增量 ≠ 当期平仓数**：增量 = 当期平仓 − 滑出窗口的平仓，可为负或偏小。实测T1 `overall=54` / `last_30d=2`——52 笔在窗外，窗口每天都在吐旧数据。<br>✅ **`overall.n_trades` 是累计值**（= 累计已平仓笔数，`rating_reason` 措辞印证："enough samples (22)" / "insufficient sample (2 closed trades)"），**其增量才是当期真实平仓数** | ①任何"该交易员这段时间成交了多少"的推算**只能用 `overall.n_trades` 增量**，且**只在 `as_of` 变化时才算**（同日重跑增量恒为 0，会被误读成"零成交"）；②引用战绩数字一律说"截至 `as_of`"，**不要说"当前"**；③想估"轮询式观察漏了多少"：`观测到的平仓数 ÷ overall 增量` = 观察覆盖率。⚠️ **实测这个比值很低**：15 名交易员合计真实平仓约 **10.8 笔/天**，而日频快照最多只看到"持仓过夜且当日消失"的那几笔——每天观测到 1/2/3 笔分别对应覆盖率 **9%/19%/28%**。任何基于日频轮询的"跟踪某人交易"都要按这个量级打折，别当成看全了| 实测 2026-07-30（同日两次拉取 15 人逐字段对照）|

**本组的正面产出（对外展示交易员档案时必做的四项 sanity check）**：`trader_position` 的 `profile` 把战绩算好了直接给，但**几个最扎眼的数字恰好最会骗人**——散户的眼睛就落在那几个数上。展示任何交易员战绩前过一遍这四条：

1. ⛔ **`pnl_ratio_infinite=true` 不是"神"，是"盈亏比不可验证"**（零亏损记录 → 分母为 0）。实测T1 `n_trades=54` / 胜率 **100%** / 盈亏比 `∞`，但 `last_30d.n_trades=2`——54 笔的辉煌几乎全在 30 天窗口外，`rating_reason` 自己写的是 *"zero-loss record … profit factor is not verifiable; provisional"*。**必须把 `rating_reason` 一起展示，不要只报胜率**。
2. ⛔ **小样本的高盈亏比要连样本量一起报**。实测 T13 盈亏比 **16.04** 看着顶级，`n_trades=7`，且 `last_30d` 净亏 −14,335。tier `P`（provisional）已经编码了这层不确定，但用户看的是 16.04。
3. ⛔ **`current_symbol_caution=true` 是最硬的单条红旗**：他正在做的标的就在他自己的历史弱项名单里。实测T4 **20x 空 XYZ100**，而 `caution_symbols` 首位就是 `XYZ100`；T14 做 `000660.KS`，同样在自己的 caution 名单里（盈亏比 0.05 / 胜率 25%）。
4. ⛔ **杠杆 ≥10x 单独提示**：实测 17 行里 10x 及以上占 8 行（含两条 20x）。杠杆不在 tier 评级的输入里，但它决定这个仓位能不能活到方向被验证。

⚠️ 另：**`n < 10` 时不要给百分比**——3 笔里 2 胜写"2/3"，写成"67%"是伪精确。实测有 `n_trades=1` 且胜率 100% 的行（T5）。

### 2026-07-30 研报通道 Tier4 实测（N-59）

| # | 现象 | 应对 | 证据 |
|---|---|---|---|
| N-59 | **`news()` 拿不到"独立研报 feeds 文章类"**：全部索引条目一律 `provenance:"feeds"`（`_source`/`fmp_news` 字段名**不存在**，Seeking Alpha/fool.com 也返 `provenance:"feeds"`+`source_name:"media"`）；`category` 是话题噪音标签；`sources=["research"]` 数组被 schema 拒（N-8 同源），无字符串替代 | 独立 Substack 深度只能近似捞：① `social[]` 里 `kol_info.categories` 含 `"research"` 且正文挂 substack 链接（真形态）② `articles[]` 里 `source_quality=="research"`（⚠️ Motley Fool 混入，隔离不干净）。正文恒 `content_truncated`（~300-500字预览，全文需原始 URL）。**结构化评级(`analyst ratings`)与整篇研报卡(`research reports`)是另两个通道，不能当 feeds 兜底** | 实测 2026-07-30（news 逐条字段核对） |

> **N-41 补充（研报卡 TP 水分族）**：研报卡 `target_price.currency` **同币种存在多写法**（实测 2330.TW 同新台币写成 `TWD` 与 `NT$` 两种）——做 TP 离散/跨机构比价前必须先归一 currency，否则字符串层把同币种当两种。
>
> **N-38/N-46 现场复现**（研报卡 research_reports 通道，Tier4 实证）：NVDA `report_limit:10`、`subject 6 + mention 4`；台积电枢纽票 `subject 10 / mention 0`（mention 被 subject 挤没）；机构名不归一（`Morgan Stanley` vs `Morgan Stanley & Co. LLC`）+ 同日同 TP 近重复（Citi $300×2 不同 event_id）→ 榜面"23 家"钻取去重实只 3 家。**net_direction 是叙事雷达（谁被点名）不是机构共识**（点名受益股天然正向：NVDA beneficiary:73/negative:14 恒 positive·N-39）。`verbosity="detail"` 单标的实测 65K 字符必炸批 + `limit≥20` 超时。

### 2026-07-30 互动方向/作者回复率实测（N-58）

| # | 现象 | 应对 | 证据 |
|---|---|---|---|
| N-58 | **`user_tweets` 的 `inReplyToUserId` / `inReplyToUsername` 在约 31% 的真 reply 上是 null**（字段存在但值缺）：实测 dotey 42 条真 reply 里 13 条这俩字段为 null，但 `isReply=true` / `inReplyToId` 有值、text 以 `@handle` 开头。`conversationId` 60/60 齐全但指向线程根推，根推常在拉取窗口外（22 个对外 reply 只有 9 个根在窗内）。`author.id` = 账号自身 numeric id（每条都带，判"指向自己"不用另调 user_info） | ①**判 reply 用 `isReply`（或 `inReplyToId` 非空），不是 `inReplyToUserId` 非空**——后者漏 31%，会把真 reply 误分进原推堆；②判"指向自己/对内"用 `inReplyToUserId==author.id`，null 时回溯 `inReplyToId`→父推；③对外互动对象用 `inReplyToUsername` **+ text `@handle` 兜底**（否则漏 1/3）；④作者回复率的分母要单独回捞窗口外根推才全 | 实测 2026-07-30（dotey 3 页 60 条） |

### 2026-07-30 engagement 评论区实测（N-57）

| # | 现象 | 应对 | 证据 |
|---|---|---|---|
| N-57 | **`tweet_replies` 的返回把根推自身混进 replies**（同 id、`isReply=false`），且**"返回数 < replyCount" 多半是分页不是折叠**：实测某推 replyCount=58，翻 2 页得 30 条时 `has_next_page` 仍 true。评论对象字段齐全：`likeCount`/`replyCount`/`viewCount`/`bookmarkCount` + 评论者 `author.followers`（可直接做影响力加权） | ①解析评论必须**按 `isReply`/id 剔掉根推**，否则虚增计数；②判"折叠降权区"必须**翻到 `has_next_page=false`** 才可下结论，没翻完就说折叠会把普通分页误报成降权；③评论者粉丝数用 `author.followers` | 实测 2026-07-30（stacy_muur 推 2 页评论） |

> 另一条 engagement 设计教训（非 MCP）：reply/like 靶标闸只能抓"被围攻的靶标推"（作用对象是**你自己的帖**），
> 抓不到评论区里的**协同刷单簇**（多账号同模板刷无关项目，自身 reply/like=0 逃逸）——后者只能靠内容模式判 D 级。

### 2026-07-30 performance-review 三堆拆分 + 脚本字段命名实测（N-55~N-56）

| # | 现象 | 应对 | 证据 |
|---|---|---|---|
| N-55 | **`user_tweets` 端点有 `viewCount` + 全套 reply 字段，ER 可算**（区别于 list_timeline）：每条带 `viewCount`(int) / `inReplyToUserId` / `inReplyToUsername` / `inReplyToId` / `isReply`。ER = (likeCount+retweetCount+replyCount)/viewCount 逐条可算（实测 stacy_muur 原推 ER ~1.3–1.6%）。三堆拆分（转推 `retweeted_tweet` 非空 / reply `inReplyToUserId` 非空 / 原推其余）在真实数据上勾稽平（20 = 7 转推 + 0 reply + 13 原推） | performance-review 的中位/max/ER 全部可从 `user_tweets` 算。⚠️ 字段是 **camelCase**（`viewCount` 非 `view_count`，`likeCount` 非 `like_count`）——见 N-56 | 实测 2026-07-30 |
| N-56 | **Followin MCP 与 Twitter API v2 字段命名不同，混用会静默降级**：MCP 用顶层 camelCase（`viewCount`/`likeCount`/`retweetCount`）+ `results[0].data.tweets[]` 外层；Twitter API v2 用 `public_metrics.{impression_count,like_count}` snake_case 嵌套 + `data[]` 外层。脚本原本只认后者 → 喂 MCP 数据全读成 0 → `viewCount` 明明在却静默降级成"绝对互动数"排序（而 SKILL 恰恰推荐用脚本"首次建库"，建库数据大概率来自 MCP） | `tweet_analyzer.py` 的 `load_api_json` 已改为两种命名都认（`_pick` 逐个 fallback）+ 识别 MCP 外层结构。任何自己写 jq/脚本消费 MCP 推文的地方都要注意：**不是 `impression_count`，是 `viewCount`** | 实测 2026-07-30（MCP 形状数据回归） |

### 2026-07-30 tweet-composer 写稿实测（N-54）

| # | 现象 | 应对 | 证据 |
|---|---|---|---|
| N-54 | **`metrics` fundamentals 的季度数组只返最近 4 个季度**，所以「最新季的同比(YoY)」对比数据**不在窗口里**：实测 META 返回 `[Q3'25, Q4'25, Q1'26, Q2'26]`，要算 Q2'26 的 YoY 需要 Q2'25——不在数组内。cash_flow / balance_sheet / eps_trend 均是 4 季窗口 | 写财报推做同比时**只能做环比(QoQ，"上季度")或明确标"YoY 数据源外部"**。别把窗口里最老那季（如 Q3'25）当成"去年同期"——那是 3 季前不是 4 季前。想要 YoY 得另调（earnings 端点或外部） | 实测 2026-07-30（META Q2 财报推） |

### 2026-07-30 层 B 剔转推真实数据验证（N-53）

> 第五~八轮改过三四次却从没在真实数据上验证过的「剔转推」规则，本次配真实 KOL 名单实跑确认。

| # | 现象 | 应对 | 证据 |
|---|---|---|---|
| N-53 | **`user_tweets` / `list_timeline` 返回里除 `text` 前缀外，还有 `retweeted_tweet` 对象——这是更稳的转推判据**：非转推时为 `null`，转推时含被转原文与真实作者 `retweeted_tweet.author.userName`。实测 `@stacy_muur` 20 条里 7 条转推（35%），`text` 前缀与 `retweeted_tweet` 两个判据 **7/7 完全重合**；其中 6 条是自我转推、1 条 `RT @ZestProtocol` 转他人产品官宣 | **剔转推首选 `retweeted_tweet` 非空**（结构性，不受前缀变体如无空格 `RT@` 影响）；无该字段（离线 archive/csv 导出）才回退 `text` 前缀。⚠️ 不剔的失败模式已实测复现：那条 ZestProtocol 官宣不剔就会被算成 stacy_muur 自己的原创观点，污染层 B「标杆已发」判断 | 实测 2026-07-30（真实 KOL user_tweets） |

### 2026-07-30 trend-scout 端到端首扫实测新增（N-47~N-52）

> 一次真实首扫（list main + metrics + news）暴露的 5 条 P0 + 1 条 P1。几条的共性：**返回值看着对、其实错**，静态读 schema 发现不了。

| # | 现象 | 应对 | 证据 |
|---|---|---|---|
| N-47 | **`metrics` market snapshot 的 `change` 是「美元变动量」不是百分比**，且**数值会与新闻百分比巧合吻合**：META `change:-9.18` / `previousClose:593.41` → 真实 **−1.55%**；而新闻标题「Meta crashes −9%」（那是**盘后**跌幅）。−9.18 与 −9% 看着对上 | 百分比自己算 `change/previousClose×100`。🔴 **别拿 `change` 去和新闻 % 交叉核实**——会得到假的"核实通过"。两个数（美元 vs 百分比、regular vs 盘后）毫无关系 | 实测 2026-07-30 |
| N-48 | **盘后/盘前 `metrics` 返回的是上一个 regular 收盘，不是当前价**：字段 `_quote_session:"regular_inactive"` + `_quote_cache:"last_regular"`，price 是 8+ 小时前的。财报后盘后跳水**不在 metrics 里** | 看 `_quote_session` 分时段：交易时段 price 可信；非交易时段它是旧收盘，**新闻里的盘后价才是当下真相**（价格铁律在此时段反转）。两个数分开写、标来源 | 实测 2026-07-30 |
| N-49 | **jq 解析 `createdAt` 用 `strptime("...%z...")｜mktime` 是时区相关的**：实测同一串 `"Fri Jul 17 06:30:30 +0000 2026"`，UTC 下正确、**+8 时区偏 +28800s、-5 偏 −14400s**。偏移 <8h 不会让 age 变负，「age 为负」守卫**抓不到** | 🔴 去掉 `%z`：`sub(" \\+0000 ";" ")｜strptime("%a %b %d %H:%M:%S %Y")｜mktime`（mktime 按 UTC，TZ 无关，三时区实测一致）。或正则重组 ISO + `fromdateiso8601` | 实测 2026-07-30（UTC/+8/−5 三时区对照） |
| N-50 | **`MCP error 0: ... invalid during session initialization` 有并发成因，不只是类型错**：一条 message 发 4 个纯 string 的 metrics 调用，**挂了 2 个**，同批另 2 个同形态调用成功 | 判别：同批同形态有成功的 = 排除类型错，是并发争用。失败项**减并发、下批重试**（实测重试即成功）。⚠️ 原 caveat 说「九成类型错」是误导性归因。且 ≤4 并发仍偶发此错，把 ≤4 当上限不是保证 | 实测 2026-07-30 |
| N-51 | **不带 `asset_type` 的 `query` 会同时返币和同名 ETF**：`query="BTC price"` 返回 BTC 币 64,140 **和** Grayscale Bitcoin Mini Trust ETF 28.08 两条，靠 `_asset_type` 区分 | crypto 一律显式 `asset_type="crypto"`；混返时按 `_asset_type` 筛，别把 28.08 当比特币价 | 实测 2026-07-30 |
| N-52 | **`news` 的 TG (`tg_kol_feeds`) item 自带 `tg_category` 预分类字段**（交易信号 / Meme打新 / 链上数据 / 叙事追踪 / 市场结构 / 宏观研判 / 项目研究 / 实盘跟踪），此前 Skill 未用 | 用它做结构过滤比按内容判断稳定：保留 链上数据/市场结构/宏观研判，默认剔 Meme打新/实盘跟踪。实测 25 条广拉靠内容判断砍 15 条"软性"（60%、无量化判据），改用 `tg_category` 可复现 | 实测 2026-07-30 |

> 另一条非 MCP、属运行环境：**`STATE_DIR` 相对路径（`./state`）会跟着会话启动目录漂**，和 `/tmp` 一样静默丢跨天资产。开工检查除了「非 `/tmp`」还要求「绝对路径」。

### 2026-07-29 研报解读实测新增（N-37~N-41）

> 本组是 `Research Reader/` 各支 Skill 的口径地基。**核心结论：MCP 研报侧只开放「一个被连带污染的全量榜 + 每票 10 篇切片」，做不了发现型信号，只能做单标的深度。** 库内四族信号（错位/时钟/信念/水分）建立在状态层全量折叠之上，**搬不到 MCP 侧**——实测只有水分族（TP 离散）能干净地搬。

| 编号 | 内容 | Workaround | 来源 |
|---|---|---|---|
| N-37 | **研报榜 `time_range` 完全无效——它是全量累计榜，不是时间窗榜**。`24h` / `3d` / `7d` 三次调用返回**逐字相同**：NVDA 恒 125 篇 / 23 家机构，`eligible_event_count` 恒 530，`scope` 恒 `"all_batches"`。`meta.filters_applied.time_range` 有回显（24h/3d/7d 各不同）但**对结果零影响**——典型的"参数被接受但被忽略"。<br>⚠️ **由此产生的对外表述错误**：任何把该榜说成"本周/近 7 天研报热议榜"的文案都是错的，它是**建库以来累计**。 | 榜单只能表述为"研报库累计提及最多"，**禁止加任何时间窗定语**。需要时间窗必须钻取后按 `report_date` 客户端过滤 | 实测 2026-07-29（三档窗口交叉验证）<br>request_id：`63ef9e99…`(7d) / `a6b2a68b…`(3d) / `2e682924…`(24h) |
| N-38 | **钻取硬顶 `report_limit: 10`，`limit` 与 `time_range` 双双失效**。`7d`+默认 limit 与 `30d`+`limit=30` 两次调用返回的 `event_id` **完全一致**（恒 6 subject + 4 mention）；后者的 `meta.filters_applied` 里 **`time_range` 连回显都没有**（被整个丢弃）。<br>**叠加两层损耗后真评家数只剩个位数**：NVDA 榜单声称 23 家机构 / 11 家有数字目标价，钻取实际只见 **BofA / MS / Citi 三家**——6 条 subject 按 N-3（机构+标题+日期）去重后**只剩 3 条**。<br>⚠️ **机构名不归一**：同一家出现 `"Morgan Stanley"` 与 `"Morgan Stanley & Co. LLC"` 两种写法；`rating_current` 同样不归一（`"Buy"` / `"BUY"` / `"Attractive"` / `"Overweight; Top Pick"` 混用）。库内有 `institution_alias_v0.json`（12 家）做归一，MCP 侧没有 | **任何"N 家机构"的表述必须标成下界**（"可见的 3 家"而非"3 家"）。机构名先归一再去重，否则同一家会被算成两家。**需要全覆盖的信号（错位/信念族）在 MCP 侧不成立，不要做** | 实测 2026-07-29（两组参数交叉验证）<br>request_id：`555d5409…`(7d/默认) / `be2c7554…`(30d/limit=30) |
| N-39 | **榜单的 `direction_counts` / `net_direction` 是连带混算的假共识，不可当"机构看多"引用**。实测 NVDA `beneficiary 67 / negative 11 / neutral 40 / other 7` → `net_direction: "positive"`，但这是 **mention 层面**的计数——正踩研报库自己定的**连带红线**（实测现役观点 87% 是连带 rank1，研报点名"受益股"天然带正向，一投方向票每层全染多）。<br>与 N-19（榜单高位 ≠ 有专题报告，GOOGL 排第 2 而 `subject_reports=0`）是同一病根的两个表象 | **方向结论只能用钻取后 `subject_reports[].rating_current` 重算**，且按 N-38 标成下界。榜单的 `net_direction` 只能当"**叙事雷达**"（谁被反复点名），**不能当方向共识** | 实测 2026-07-29 |
| N-40 | **`signal()` 的 kol_call 按 ticker 查，目标 ticker 自己的行可能整个不在返回里**（比 N-5 的"裂成多行"更狠）。实测 `signal(query="NVDA", asset_type="tradfi")` 返回 8 行 kol_call，**无一行 `symbol=="NVDA"`**——全是 IREN / ARM / CRWD / CRWV / INTC / NBIS / ORCL / OSCR。而命中的原帖内容是 `"BUY: - $NVDA - $SOFI …"`，**$NVDA 明明列在 BUY 首位**。只按 `symbol` 字段过滤会得到"该标的零 KOL 观点"的假结论 | **必须回读 `content` 判断目标 ticker 的方向，不能只信 `symbol` 字段**。`symbol` 只表示这一行被归给谁，不表示原帖只讲了它。配合 N-5 按 `source_url` 去重后逐帖读 content | 实测 2026-07-29（request_id `908aadc9…`）|
| N-41 | **`detail.catalysts[].time_std` 可排序但格式不统一，且带无法锚定的哨兵值**。⚠️ **本条已于同日按三标的 60 条样本改写——初版按单标的（NVDA 20 条）写的规则实跑覆盖率仅 77%**。<br>**`sort` 共 10 种形态**（60 条全量）：`YYYY-MM-DD`(22) / `YYYY-MM`(11) / `YYYY`(9) / **`YYYY-MM-DDThh:mm:ss±hh:mm`(4，ISO datetime)** / **`YYYY-QN`(4)** / `YYYY-HN`(3) / **`YYYY-MM-DD+`(2，开区间)** / **`YYYY-MM-DD-<语义后缀>`(2，如 `2026-07-23-upcoming-earnings-call`)** / **`YYYY-FQN`(2，财季≠自然季)** / `YYYYHN`(1，无连字符)。另有 `CY` 前缀变体。<br>⛔ **`"9999"` 哨兵与四位年份形态完全相同**（都是 `YYYY`），**只能按值判不能按形态判**——必须先查 `sort=="9999"` 再做形态匹配。<br>**`type` 共 22 种取值**（不是初版写的 12 种），且**三组同义异写**：`half-year`/`half_year`/`half_year_range` ｜ `event_relative`/`relative_event` ｜ `quarter`/`quarter_range`/`fiscal_quarter`。<br>⛔ **最大的坑是精度降级**：`type` 的语义粒度常**粗于** `sort` 的字面粒度。实测 INTC `sort="2026-09-30" type="quarter"` 与 `sort="2026-10-01" type="quarter"`——**直接读 sort 会渲染成"9 月 30 日""10 月 1 日"，实为"Q3 末/Q4 内某时"**，凭空造出精确度。初版只防了 `type=year` 一种，被 `quarter` 打穿。<br>✅ **正面发现**：`catalysts[].security` **可以 ≠ query ticker**——查 NVDA 顺带拿到 AMD 的竞品事件日；查 INTC 拿到 AAPL 财报日、台积电 N3→N2 迁移、SK 电讯 AI 工厂投产。**一次钻取能收获跨标的催化剂** | 归一按序：①`sort=="9999"` 或缺失 → 待锚定桶 ②剥 `CY` 前缀、尾部 `+`、尾部语义后缀 ③ISO datetime 截到日（时刻可留展示，实测 4 条都是财报电话会准确开始时间，是本数据最精确的一类）④`YYYYHN`→`YYYY-HN` ⑤按形态定基础精度 ⑥**按 `type` 语义向下降级**（year/relative_year→年；quarter/quarter_range/fiscal_quarter→季；half-year/half_year/half_year_range→半年；month→月）。<br>**修正后实测归一成功率 58/60 = 97%**（初版规则为 46/60 = 77%），逐标的 NVDA 19/20、INTC 20/20、GOOGL 19/20；精度分布 日 24 / 月 10 / 季 10 / 半年 5 / 年 9 / 待锚定 2。**自检：待锚定率应 ≈3%，>15% 说明遇到本表未收录的新形态，先补规则再出图**。<br>⚠️ 精度降级实测拦下 **8 条**（`2028-01-01`+year→年、`2026-09-30`+quarter→Q3、`2026-07-01`+half-year→H2 等）——**不降级这 8 条全会被渲染成假的精确日期** | 实测 2026-07-29（初版 NVDA 20 条 → 同日 NVDA+INTC+GOOGL **60 条**交叉验证改写，规格写成脚本实跑复验）|

### 2026-07-29 三标的端到端实跑新增（N-42~N-44）

> 来源：`Research Reader/` 三支 Skill 写完后对 **NVDA / INTC / GOOGL / F** 四个标的做端到端实跑（含把客户端规格写成脚本执行）。本组全部是**规格实跑才暴露、只读字段看不出来**的问题。

| 编号 | 内容 | Workaround | 来源 |
|---|---|---|---|
| N-42 | **N-3 的「机构+标题+日期」去重去不掉「快评 + 完整版」重复**（N-3 的补充，非替代）。同一家机构对同一事件常发两篇：盘后快评 + 次日完整版。**标题不同所以 N-3 三元组不同，去重规则整个失效**，该机构被算成两家。<br>实测 INTC：Goldman Sachs **2026-07-23 两篇同为 TP 150**——《…First Take: Strong quarter across the board…》与《…Strong quarter across the board, with margin upside…》。同日、同机构、同目标价、标题近似但不相同。<br>跨日变体：Citi 07-23《2Q26 Earnings Quick Take: Beat-and-Raise》与 07-24《Transformation in Progress; Maintain Buy》同为 TP 130。 | **追加一道：同机构 + 同日 + 同 TP → 强制合并**（保留信息更全的一篇）。跨日的快评/深度对不强制合并，**按机构取最新一篇**即可自然消解。<br>不做这道：INTC 7 条 subject 会被读成 7 家，实际只有 **5 家** | 实测 2026-07-29（INTC 端到端实跑）|
| N-43 | **`revision_summary.list_changes[]` 字段确实存在**（⚠️ 修正此前"MCP 侧无此字段、停覆信号做不了"的错误断言）。结构：`{action, list, security}`。<br>实测出现两种 `action`：`initiate`（Bernstein 2026-07-27 "Asia Quant + Fundamental Portfolio for 2H26" 组合建仓名单，同一份报告在 NVDA 与 GOOGL 的钻取里都出现）、`add`（J.P. Morgan 把 LIG D&A 加入 Positive Catalyst Watch）。<br>**未见到停止覆盖类 action**（drop/remove/terminate），但字段结构与库内时钟族·停覆信号所依赖的是同一套。 | 表述为「**样本内未出现，机制上可能支持**」，**不要写成"做不了"**。遇到停覆类 action 时按库内时钟族读法处理（"机构不再看它"本身是信号）；**同时不承诺一定能抓到** | 实测 2026-07-29（四标的扫 `list_changes`）|
| N-44 | **`subject_reports` 数量是时点状态，会日间剧变——N-19 的「GOOGL subject=0」不是恒定特性**。<br>实测对照：2026-07-23 GOOGL 榜单第 2、66 篇提及、`subject_reports=0`（N-19 原始记载）；**2026-07-29 复测 GOOGL `subject_reports=6`**（Barclays / Morgan Stanley / Bernstein / Citi×2 / Goldman Sachs）。<br>同日 **F(Ford) 才是 subject=0 的案例**：`report_returned_count=3`（连 10 篇上限都没给满），3 篇全是 mention。<br>另：`report_returned_count` **不保证等于 10**——有货才给。 | **每次当场看返回的 `subject_report_returned_count`，绝不照抄历史结论**。N-19 的判定逻辑（榜单高位≠有专题报告，须查两层比例）仍然成立，**但它举的 GOOGL 例子已过期**。<br>`subject=0` 时降级为 mention 叙事，且 **mention 报告的 `detail.catalysts` / `key_caveat` / `consensus_diff` 照样可用**（实测 F 的两条最硬的基准问题就出自 mention 报告）| 实测 2026-07-29（GOOGL 复测 + F 对照）|

### 2026-07-29 产业链读穿实测新增（N-45~N-47）

> 来源：为 `Research Reader/r4` 做的四标的交叉验证（NVDA / INTC / GOOGL / **2330.TW**）。本组解释**研报里的跨标的关系数据到底能不能用、怎么用**。

| 编号 | 内容 | Workaround | 来源 |
|---|---|---|---|
| N-45 | **`detail.affected_names` 有计数、永远没有内容**。`detail_sections.affected_names` 稳定报出 1–31 的计数，但 `detail` 对象里**从不包含 `affected_names` 字段**——实测 **30/30 篇全缺**（NVDA 10 + INTC 10 + GOOGL 10）。<br>被吞掉的正是最理想的产业链数据：Nomura 一篇标了 **31 个** affected names、Bernstein 两篇各 26 个，一个都取不到。<br>⚠️ 与 `content_truncated: true`（实测恒为真）疑似同源，但**其余 10 个 detail 子字段都正常返回**，唯独 affected_names 缺失，不像单纯截断 | **不要基于 `detail_sections` 的计数许诺能拿到名单**——计数不代表内容可得。产业链关系只能走三个替代面：`revision_summary.by_name[]`、`mention_context`、`detail.catalysts[].security`。<br>**建议向 Dev 提**：affected_names 是研报最有产业链价值的字段，计数已经算出来了却不返回，疑似序列化遗漏（P2）| 实测 2026-07-29（三标的 30 篇逐篇检查）|
| N-46 | **10 篇硬顶是 `subject` 与 `mention` 共享名额——专题覆盖多的"枢纽票"反而拿不到跨标的数据**。⚠️ 这条与"查枢纽收割整条链"的直觉完全相反。<br>实测对照：<br>· **2330.TW 台积电**（榜单第 4，70 篇提及 / 17 家机构）→ `subject 10 / mention 0` → 关系边 **0**、跨标的修正 **0**<br>· **INTC**（榜单第 6）→ `subject 7 / mention 3` → 跨标的修正 **16 条**、对手方 **16 个**<br>· NVDA（榜单第 1）→ `subject 6 / mention 4` → 关系边 4、真链修正 6<br>**根因**：跨标的关系数据（`by_name` 跨标的条目、`mention_context`）**几乎只存在于 mention 报告**——实测 30 篇 subject 的 `by_name` 恒为 1 条（标的自己）。专题报告一多，mention 就被挤出 10 篇窗口 | **不要用榜单排名挑标的做产业链分析**——排名越高越可能是"全 subject 零 mention"。**调用后先读 `mention_report_returned_count`**，为 0 时只能从 subject 的 `catalysts` 捞跨标的节点（实测 2330.TW 仅 4 条），并说明是名额被挤占而非该票没有产业链 | 实测 2026-07-29（四标的对照）|
| N-47 | **汇编型报告的 `revision_summary.by_name[]` 是「同框噪音」，不是产业链**。实测查 NVDA 得到 12 条带 `old→new` 的跨标的修正，内容为**印尼棕榈油、印度银行、印度钢铁、印尼制药、韩国船舶**——与英伟达毫无关系，只是同处一份《Asia Morning News and Research Views》。<br>**可用 `subject_name` + `report_type` 判别**：<br>· 🚫 汇编：`subject_name` 含 `morning news`/`portfolio`/`quant`/`weekly`/`daily`/`views`（实测 `"Asia Morning News and Research Views"`、`"Asia Quant + Fundamental Portfolio for 2H26"`）<br>· ✅ 专题：`subject_name` 是具体公司或产业主题（实测 `"Global AI memory strategic partnerships"`、`"Taiwan mature-node foundries and semiconductor design"`、`"Nokia"`）<br>**闸的效果**：NVDA 30 噪音 / 6 真链、GOOGL 17 / 5、**INTC 0 / 16**。不加闸时 NVDA 输出 **83% 是无关名字**。<br>另两条同批发现：①**`by_name` 的 `old_target_price` 覆盖率仅 25/96 = 26%**——只有 new 的是"当前目标价"不是"被改价"，两者必须分开表述；②**`catalysts[].security` 不保证是 ticker**，实测出现板块名 `"AI SEMICONDUCTOR SUPPLY CHAIN"` 与逗号多值 `"373220.KS, 006400.KS"` | 过闸后再用 `by_name`；**`mention_context.rationale` 无论过不过闸都保留**（汇编报告的 rationale 照样是真信息，被丢的只是名单）。关键词表是启发式需持续补充，判别原则：**这份报告有没有统一研究主题**。<br>`security` 清洗：含空格且无 `.` 后缀 → 板块名单列；含 `,` → 拆分 | 实测 2026-07-29（四标的 96 条 by_name 逐条判读）|

**本组的正面发现**：`mention_context.rationale` 质量远高于预期——给的是**机制描述而非标签**，每条都是一条带方向的 A→B 因果边（实测：*"NVIDIA is Nokia's development partner for the O-RAN-compliant AI-RAN platform"*、*"Intel Foundry is seeing improving customer interest because TSMC leading-edge capacity is tight"*）。⚠️ 但**必须读全句**——实测存在自带否定的边：*"Intel is a potential 3nm collaboration partner for UMC, **but Bernstein considers a joint project unlikely**…"*，只读前半句会把否定读成肯定。<br>另一实用副产品：过闸后的 `by_name` 能**顺带白拿链上其他标的的目标价**（实测查 INTC 拿到 NVDA `TP 315` / AVGO `TP 550` / AAPL `TP 350`），但那是**单家读数不是共识**，引用须标出处。

**上一组的正面发现（省额度）**：`metrics(query="<T> analyst ratings price target", asset_type="tradfi")` **一次调用（1 额度）同时返回** `consensus_price`（targetConsensus/High/Low/Median）+ `analyst_grades`（20 行，带 `gradingCompany`/`action`/`newGrade`/`previousGrade`，**这才是可靠的评级动作流，覆盖面远超研报侧的 3 家**）+ `beat_miss` + `eps_trend` + `latest_quarter` + `next_earnings_estimate` + `valuation_block` + `market.snapshot`。跨源印证的**维度1（共识）+ 维度4（基本面）+ 价格腿一次拿全**。<br>⚠️ 但 `consensus_price` 仍无分析师家数字段（N-16 复核成立）；家数改由 `analyst_grades` 按 `gradingCompany` 去重估算并注明是估算（实测 INTC 20 条 grades / **17 家**，覆盖面远超研报侧的 5 家，且能抓到研报窗口外的真动作——Goldman Sachs 2026-06-25 **Sell→Neutral upgrade**）。

**另两条同批实测（附在此处，未单独编号）**：

- ⛔ **`valuation_block.dcf` 在亏损期给出荒谬值，且无任何字段标注失效**。实测 INTC `dcf = 2.95` vs 现价 `86.57`——**差 29 倍**（该季 GAAP 净亏 $110.33 亿，现金流折现模型直接崩）。**自检：`dcf` 偏离现价 >5 倍即判失效**，不进任何输出。
- ⚠️ **N-33 的「同季确认」判据必须用 N-34 的 gap，不能直接比日期**。`beat_miss.date` 是**财报公布日**、`latest_quarter.date` 是**财季结束日**，**两者天然不相等**——朴素比日期会把每个正常样本都判成"不同季"，从而**作废掉本该生效的 N-29 GAAP 错位检测**。正确判据：`gap = beat_miss.date − latest_quarter.date < 90 天 = 同季`。实测 INTC gap = 26 天（07-23 公布 / 06-27 季末）→ 同季，N-29 检测生效并成功抓出 `epsActual 0.42`（非 GAAP，+100%）与 `latest_quarter.eps −2.16`（GAAP 巨亏）的反号错位。

## 附表 A：中英文 → FRED series_id 翻译表

> 红线 3 的配套字典（原宿主 07_macro-analyzer 已删，表迁至此）。用法：用户说指标名 → 查本表转 series_id → `metrics(keywords=["<series_id>"], categories=["macro"], limit=N)` 直查。字典未命中才回退 query 兜底并人工 review 命中的 series。

| 用户可能说 | series_id | 备注 |
|---|---|---|
| CPI / 通胀 / 消费者价格指数 | `CPIAUCSL` | |
| 核心 CPI / Core CPI | `CPILFESL` | |
| PCE / 个人消费支出物价 | `PCEPILFE` | |
| 失业率 / Unemployment | `UNRATE` | |
| 非农 / NFP / 就业人数 | `PAYEMS` | |
| 联邦基金利率 / Fed Funds | `FEDFUNDS` | |
| 10 年期国债收益率 / 10Y | `DGS10` | |
| 2 年期国债 | `DGS2` | |
| 30 年期国债 | `DGS30` | |
| 30 年抵押贷款利率 (mortgage) | `MORTGAGE30US` | ⚠️ 不是 DGS30 |
| 10Y TIPS 实际利率 | `DFII10` | |
| 通胀预期 / 10Y BEI | `T10YIE` | |
| 10Y-2Y 利差 / 收益率曲线 | `T10Y2Y` | |
| M2 货币供应 | `M2SL` | |
| Fed 资产负债表 / WALCL | `WALCL` | |
| 财政部 TGA | `WTREGEN` | |
| 隔夜逆回购 / RRP | `RRPONTSYD` | |
| 高收益债利差 / 信用利差 | ~~`BAMLH0A0HYM2`~~ | 🚫 **暂不可用（B-33）**：不在 FRED 字典，直查被错抓到 M2SL——拿错数据比没数据更糟。标"数据不可用"，Dev 修复后恢复 |
| 零售销售 / Retail Sales | `RSAFS` | |
| WTI 原油 | ~~`CLUSD`~~ | ⚠️ **N-11 实测 402 Special Endpoint**：优先 `BZUSD`（布油）/ `USO`，CLUSD 待复核。market 类，非 FRED |
| 黄金期货 | `GCUSD` | ⚠️ 不是 GOLD（会错抓 Gold.com 美股）。market 类，非 FRED |

