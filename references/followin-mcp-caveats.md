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
| — | trader_position 美股标的覆盖**日级剧变**（实测 07-09 MU 4 人 vs 07-15 MU 1 人、海力士从无到 3 人）；且同一标的可能符号分裂成多组（海力士 underlying=000660.KS 散在 SKHYNIX/SKHX/SKHY 三个 symbol）| 数据特性 | 任何对外用途都当天现拉；空 keywords 拉 trending 看当前有货标的；符号分裂需按 underlying 合并 | —（数据特性，非 bug；符号分裂可提 Dev 归一）|

### 2026-07-22 社群 bundle 实测新增（N 系列）

| 编号 | 内容 | Workaround | 来源 |
|---|---|---|---|
| N-1 | news 趋势模式（空 query）传 asset_type="tradfi" 可用且 0 额度；"news 不传 asset_type"红线仅适用搜索模式。实体搜索亦 0 额度 | news 趋势模式（空 query）传 asset_type="tradfi"；实体搜索亦无额度消耗 | 实测 2026-07-22 |
| N-2 | earnings calendar 市场级可用（query+date_from/to），但返回全球交易所混排、无市值字段；过滤 = 无后缀 symbol + revenueEstimated 初筛 + 二次调用补市值 | 无后缀 symbol + revenueEstimated 初筛 + 二次调用补市值 | 实测 2026-07-22 |
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
| N-22 | **earnings_calendar 不可作发现腿**（⚠️ 本条升级 N-2「市场级可用」与 N-17「漏大票」的定性——问题比"漏"严重）：三重硬伤叠加 —— ①`limit` **50 行硬封顶**（传 100/300 均返 50 行，`total` 恒为 50）②只覆盖 `date_from` **当天**（请求 07-20~07-27 八天，50 行全是 07-20）③按 symbol **字符串升序**截断，实测砍在 `CBKD.L`（字母 C 前）；单独查 07-22 更砍在 `456040.KS`，连字母区都没进。**GOOGL 这类 G 开头的票在任何日期都进不来** | **发现层改用 `query="most active stocks"` 异动榜 + `news()` 双腿**；日历仅可用于对**已知 ticker** 的单点日期核对。GOOGL 的 beat_miss 只能走 keyword 腿（`fundamentals.concise`）拿 | 实测 2026-07-27（date_from=2026-07-20/to=07-27 + 单日 07-22 双向验证） |
| N-23 | **query 串 ticker 解析有两种独立故障，不要混为一谈**（N-12「会静默丢弃」的拆解与定量化）：<br>**(a) 批量截断** —— 上限 **5 个 ticker**，传 8 个只解析前 5 个，无 warning。<br>**(b) 上游字典缺失** —— 某些真实美股**任何 query 形态都解析不出**，单票调用也返回 `keywords: null` + 无 `concise`/`snapshot`，且 warning 把整个 query 串当成 FRED series_id 候选。对照实验：`query="NOK next earnings date"` 正常返回 `keywords:["NOK"]` + 完整数据；同形态的 `"JBLU next earnings date"` 返回 null。**已确认不可解析：JBLU(JetBlue, NASDAQ) / CUBI(Customers Bancorp, NYSE) / ONDS(Ondas Holdings)** —— ONDS 与 N-12 记载的"连续两次被跳过"为同一现象 | 每批 **≤5 个 ticker** 规避 (a)；调用后把 `meta.filters_applied.keywords` 与请求清单**做差集**。差集缺失者**最多补调 1 次**：仍返回 `keywords:null` 即判定为 (b) 字典缺失，**立即放弃并记数据缺口，禁止继续重试**（每次无效补调倒扣 1 额度——实测一轮扫描 12 次额度里有 3 次是注定失败的补调）| 实测 2026-07-27（探针批量测试 + 验收实跑 + JBLU 单票复核三重验证）|
| N-24 | **fundamentals 三档体积**：①`query="<T> next earnings date"` → **~5 KB/票**（concise: beat_miss/consensus_price/eps_trend/latest_quarter/next_earnings_estimate + market.snapshot 含 marketCap，附赠 10 行无关 earnings_calendar）②`query="<T>"` 或 `"<T> 财报"` 或 `"<T> 财报 超预期"` → **~8.7 KB/票**（三者 byte 级完全相同，多出 balance_sheet×4 + cash_flow×4 + profile + valuation；中文意图词对返回**零影响**，纯废字符）③`query="<T> earnings call transcript"` → **~56 KB/票**（含完整逐字稿）。**transcript 仅在 query 明确含 `earnings call transcript` 时才拉取**，其余 query 绝不误带 | 批量验证用 ①（省 3 倍 context，且 marketCap 顺带拿到，可省掉独立行情调用）；只在 Top N 深扫时用 ③ | 实测 2026-07-27 |
| N-25 | `news(limit=N)` 实际返回 **2N 条**（N 篇 `articles` + N 条 `social`，`total`=2N）。且 **social 桶的美股 ticker 密度高于 articles 桶** | 估算返回体积按 2N 算；抽 ticker 时两个桶都要解析，别只看 articles | 实测 2026-07-27 |
| N-26 | news query 句式决定命中率（同为 7d/limit=10）：**陈述业绩事实**句式 `record quarterly revenue results` = 13/20 有效；`earnings beat raised guidance` = 8/20；**情绪涨跌**句式 `earnings surprise stock surges` = **3/20**（被日韩欧股+加密+纯宏观淹没）。另 `beat` 一词在 news 侧会撞上**棒球比分报道**与加密代币 $BEAT | 用陈述业绩事实的句式；避开 surge/soar/jump 等涨跌词与 beat | 实测 2026-07-27 |
| N-27 | `verbosity` 参数对 metrics **无效**：`concise` 与 `standard` 返回 payload 一字不差，仅 `meta.verbosity` 字段变化 | 不用传（传了也不省 context）；省 context 靠 N-24 的 query 后缀 | 实测 2026-07-27 |
| N-28 | transcript 的 `_meta.freshness` 字段**恒为 `"q-1"` 属误导**：实测 INTC / GOOGL / CMCSA 三份逐字稿的 freshness 全是 `q-1`，但同层 `date`/`period`/`year` 显示均为**本次财报**（Q2 2026）。照字面信会误判逐字稿过期而触发不必要的降级 | 核对逐字稿新鲜度一律看 `transcript[0].date` / `period` / `year`，**不看 `_meta.freshness`** | 实测 2026-07-27（三份逐字稿交叉验证）|
| N-29 | **同一 payload 内 GAAP 与非 GAAP EPS 并存且互相矛盾，无字段标明口径**：实测 INTC `beat_miss.epsActual = 0.42`（非 GAAP，对预期 +100%）与 `latest_quarter.eps = −2.16` / `netIncome = −$110.3 亿`（GAAP 巨亏）同处一个返回。只看 beat_miss 会把巨亏季读成"完美超预期" | 凡引用 `beat_miss.epsActual` 必须同时取 `latest_quarter.eps` 比对：**两者反号即判定口径错位**，对外表述强制标注"该超预期为非 GAAP 口径"；营收 surprise 才是可信主锚 | 实测 2026-07-27 |
| N-30 | **原油符号四种写法实测三死一活**（结案 N-11 与红线 6 的长期冲突）：`CLUSD` → `no_match` 返 **0 结果**（不是 402）｜`BZUSD` → query 串里被**静默丢弃**（实测 `query="BZUSD USO"` 只解析出 USO，不报错不返数据）｜`OIL` alias → 返回 **iPath Pure Beta Crude Oil ETN**（symbol OIL，$28.42，市值 5300 万）而非原油价格，且附带诡异 warning `asset_type=tradfi but all keywords resolved to other families (crypto)`｜**`USO` → 唯一可用**（United States Oil Fund，$136.52，市值 $163 亿，跟踪 WTI 近月期货）| 原油一律走 `query="USO"` + `asset_type="tradfi"`。⚠️ **USO 是期货 ETF 代理指标，不是现货价**，对外引用必须说明口径。红线 6 的"CLUSD(WTI)/BZUSD(布油)"记载已**全部作废**；10 号 Skill 原"布油 100% 命中"的记载是过期假声明（静默失败，跑了也不知道没拿到）| 实测 2026-07-27（四种写法逐一验证）|
| N-31 | **7 个 v2 Skill 的 `keywords=[...]` 写法全域失效**（N-8 的影响面盘点）：`~/.claude/commands/` 下 08/09/10/11/12/13/14 共 **107 处** `keywords=[...]` 调用示例，按 N-8 全部会被 schema 拒（`-32602`）。模型实跑时会撞错一次再自行改写成 query 串，属"可恢复但每次白烧一次失败调用"| 正确替代形态实测确认：FRED 指标 `query="DGS10"`（服务端正确回填 `keywords:["DGS10"]` 并返数据）；行情 `query="<T1> <T2> ... 行情"`（≤5 个）。**尚未 sweep，待专项处理** | 实测 2026-07-27（keywords 数组复现被拒 + query 替代形态验证） |

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

