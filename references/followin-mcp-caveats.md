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
8. **历史 OHLCV / 技术指标**：⚠️ **2026-08-04 按 N-69 改写**——历史用 `query="<T> 历史走势"` + `time_range`（**去掉 "30 day chart" 英文尾巴**，实测 "day" 被劫持成 ticker DAY）；技术指标用 `query="<T> 均线 指标"`，**一次 fanout 返回全部 9 个指标**（adx/rsi/dema/wma/williams/ema/tema/sma/stddev），按 `indicator` 字段筛，不必也不应分开单调。原"英文指标词单调"写法已被 N-69 证伪。历史路径支持多 ticker 批量（实测 2026-06-12：3 ticker × limit 各自完整返回，无丢条；~20 个上限未实测）。
9. **mover 榜**：biggest gainers/losers 上游缺 marketCap 且全是仙股（trend-scout v1.8.0 实测）——弃用；改 `query="most active stocks"`，但实测（2026-07-22 2026-07-22 回归）board 行亦不带 marketCap（trend-scout 旧版记载已失效）——候选 ticker 需二次批量快照补市值后再过滤：marketCap ≥$1B + 剔杠杆 ETF。movers 仅美股。<br>⚠️ **2026-07-27 实测修正两点**：①ETF 过滤正则须为 `ETF\|ETN\|UltraPro\|Ultra\|Leveraged\|\dX\|Bull\|Bear\|Daily`——**只判 "ETF" 单词会漏**（`ProShares UltraPro QQQ`/TQQQ 与 `ProShares - UltraPro Short QQQ`/SQQQ 的 name 都不含 "ETF"）；②**慎用"仙股 <$5"闸**，实测误杀 GRAB（$3.31 但市值 $131 亿），市值闸是更准的同类过滤，价格闸只在市值不可得时兜底。
10. **经济日历**：`metrics(query="economic calendar", country="US")`（⚠️ 2026-08-04 按 N-8 改写：原 keywords 数组形态已被 schema 拒；`country="US"` 必传，否则返 CN/JO/KR/MY 事件——N-32）。query 别带"本周"——实测（2026-06-12）"本周"被解析成 lookback 7 天，返回**已发布历史**而非前瞻日历。
11. **news() 无匹配时不返回空，返回语义兜底的不相关内容**（实测 2026-06-12：查 Quhuo/Navios 返回的是 BoJ/伊朗等宏观新闻填充）。**所有"报道 ≤ N"类判定必须按 LLM 逐条判断后的相关报道数计数，不能用 raw count**——否则填充内容会把"无声异动"误判成"有报道"。
12. **研报查询 query 必须含研报意图词**（"research reports" / "研报"等）：实测（2026-07-15）query 只放报告标题（如 `query="Can semi cap work if memory doesn't"` + keywords=["MU"]）**不会路由到 research-report 路径**，掉进 CORE fundamentals 默认全家桶（三表/估值/profile），且照常计 1 次额度。**钻取指定报告的正确姿势 = 保持 `query="research reports"` + `verbosity="detail"` 重查，客户端从结果挑目标报告**；无按 event_id/标题取单份的入参。返回分 `subject_reports`（主题报告）与 `mention_reports`（提及报告）两层。

## 已知问题登记（含 Dev 修复后回滚指引）

> ### 📊 状态总览（2026-08-12 · 每轮验收更新此块）
>
> **102 个条目 = 活跃 80 + 存根 5 + 归档 17。** 条目数是认知覆盖率，不是产品破损度——大多数条目是「读法纪律」（数据的脾气，永远不会"修好"），真正需要客户端设闸的硬问题见下。
> 🆕 **08-12 验收轮**：研报通道 P0/P1 九条销案（N-78~N-84 + N-65）、P2 三条产品侧结案不修、新增 N-86。⚠️ 编号 **N-73~N-77 为空号段**（08-07 批撞号让位改为 N-78~N-85 所致），**保持空置，不要复用**。
>
> **🔴 当前仍需客户端设闸的硬问题（速览，权威以正文为准）**
> · **一行修法团灭一族**：N-8 数组参数 schema 无类型（含服务端建议自相矛盾）
> · **query 解析家族**：N-23（截断/字典缺失/解析成功≠有数据/指数重复）· N-69（英文词劫持）· N-36（影子代码挤名额）——根治 = 结构化参数，与 N-8 同一张票
> · **trader_position 族**：N-59e 按人查不生效 · N-59j 巨鲸压秤 · N-59l entry_price 污染(待复验) · N-59m 平仓不回流 · N-59n/N-59s 显示名两个方向都不可靠 · N-59p as_of 掩盖刷新不同步 · N-59q 全 null 伪装 balanced
> · **先截断再过滤**：N-22 财报日历 `country` 在「取前 500 候选」之后才生效，候选按 symbol 字母序 → 美股永远够不着（⚠️ **单窗口验收会误判已修**）· N-72 has_more vs status:partial 语义打架
> · **部分修复待收尾**：N-38 单页 10 篇仍在（🔄 08-12 起可翻页枚举完，N-81——只剩「每页 1 额度」的成本问题）· N-39 改名后仍不可当共识
> · **🆕 取数认块**：N-86 ticker 解析静默扩展出平级结果块且顺序不保证——禁用 `[0]` 取数 / 逐块比对 `query_ticker` / 禁用 `meta.total` 判条数
>
> **维护纪律**：销案→移入文末归档段（ID 不删不复用）· 新坑先看能否归入既有家族 · 编号只增不改（全仓上百处 `见 N-xx` 引用）
>
> ℹ️ **本文件是消费端的读法手册**——记录「上游数据当前是什么样、因此该怎么读」。**不是缺陷追踪表**：条目留存是为了防回归自查，不代表这些问题都待处理。


| 编号 | 症状 | 状态 | Workaround | Dev 修复后回滚动作 |
|---|---|---|---|---|
| B-18 | `keywords=["BTC"]` 不带 asset_type 时 fanout 到美股 BTC Inc（$33）污染 | Dev 待修 | 必传 `asset_type="crypto"` | 保留（显式总是更稳）|
| B-31 | FRED macro 批量 keywords 静默丢条目（如 BAMLH0A0HYM2 被丢）| Dev 待修 | series 单独 fire | 恢复批量（省调用数）|
| B-33 | BAMLH0A0HYM2 不在 FRED 字典，keywords 直查被错抓到 M2SL；CPIMEDSL 同类（被错抓 headline CPI）| Dev 待修 | 05 ⑦ 信用利差标"不可用"+ 权重重分配；02 Healthcare 退用 CPIAUCSL | 05 Batch 1 恢复调用 + ⑦ 恢复 5% 权重；02 Healthcare 换回 CPIMEDSL |
| — | news() 传 asset_type 返 0 results（is_tradfi 几乎全 false）| Dev 待修 | news 一律不传 asset_type | 各 Skill news 调用恢复 asset_type 过滤（防 crypto 混入）|
| — | fundamentals comprehensive 缺 stock_peers | 已上报 | 输出"同行"部分标数据不可用 | 恢复 peers 展示 |
| — | OIL/GOLD/SILVER alias 错路由 | Dev 待修 | 金银用 `GCUSD`/`SIUSD` 具体 ticker；**原油的具体 ticker 现已全部失效，只能用 USO 代理（N-30）** | 金银可继续用具体 ticker；**原油需 Dev 修复 CLUSD/BZUSD 才能拿回现货价** |
| — | insider 全量扫描聚簇（同公司多笔 filing 连排；2026-06-12 实测 SPCX Form 3 占 50 条中 13 条）| 数据特性 | `limit=50` + `sort_by="amount"` + 客户端按 ticker 去重 + 只留 formType="4" 的 P-Purchase；F-InKind/M-Exempt 为缴税代扣非主动交易；对外表述"内部人卖出"只认 S-Sale，买入只认 P-Purchase。 | —（数据特性，非 bug）|
| — | 经济日历 query 带"本周"触发 lookback 返历史 | 行为特性 | query 不带"本周" + `country="US"`（红线 10 现行写法）| —（语义解析特性）|
| — | 研报无单份钻取入参：query 放报告标题会掉 fundamentals 默认集（红线 12，实测 2026-07-15）| 建议 Dev 增 event_id 入参（P2）| 保持研报意图词 + detail 重查 | Dev 支持 event_id 后可按 ID 直取 |
| — | trader_position 美股标的覆盖**日级剧变**（实测 07-09 MU 4 人 vs 07-15 MU 1 人、海力士从无到 3 人）；且同一标的可能符号分裂成多组（海力士 underlying=000660.KS 散在 SKHYNIX/SKHX/SKHY 三个 symbol）。⚠️ **剧变粒度已被 N-59d 收紧到分钟级**（18 分钟内 SNDK 4 人→5 人）；字段级陷阱见 **N-59 组** | 数据特性 | 任何对外用途都当天现拉；空 keywords 拉 trending 看当前有货标的；符号分裂需按 underlying 合并 | —（数据特性，非 bug；符号分裂可提 Dev 归一）|

### 2026-07-22 社群 bundle 实测新增（N 系列）

| 编号 | 内容 | Workaround | 来源 |
|---|---|---|---|
| N-1 | news 趋势模式（空 query）传 asset_type="tradfi" 可用且 0 额度；"news 不传 asset_type"红线仅适用搜索模式。实体搜索亦 0 额度 | news 趋势模式（空 query）传 asset_type="tradfi"；实体搜索亦无额度消耗 | 实测 2026-07-22 |
| N-3 | 研报同一份报告可双 event_id 重复入库；按 机构+标题+日期 去重 | 按 机构+标题+日期 去重 | 实测 2026-07-22 |
| N-4 | signal 不带 categories 默认 fanout 全 4 类且只计 1 额度（省额度利器）；kol_call tradfi 聚合原生可用（top_calls 多空计数） | 不带 categories 时走 fanout 全 4 类、只计 1 额度 | 实测 2026-07-22 · **复核 2026-07-24 仍有效**：NVDA + `asset_type="tradfi"` 两组不同 query 均 `quota.consumed=1`，但只返回 `insider_trading` / `institutional` / `kol_call` **三类**——`trader_position` 未出现（该标的当时无持仓行，非 fanout 失效——见上表「trader_position 美股标的覆盖日级剧变」行）。**依赖 fanout 时不要假定四类恒在，按实际返回的 key 判断** |
| N-5 | kol_call 原帖按提及 fanout 成多行（同 URL 不同 symbol/方向）；按 source_url 去重、symbol 字段归属 | 按 source_url 去重/symbol 归属 | 实测 2026-07-22 · **复核 2026-07-24 仍有效**：同一条 `$MU $GOOGL $NVDA` 推文返回 3 行，仅 symbol / sector 不同，其余字段完全相同 |
| N-6 | insider/congress 行无视 time_range（7d 返回 2020 年记录）；客户端按 transactionDate 过滤强制 | 客户端按 transactionDate 过滤强制 | 实测 2026-07-22 |
| N-7 | 13F institutional 申报季中期 investorsHolding 环比为残缺假信号（实测 NVDA 6234→1441）；申报季内禁止引用环比 | 申报季禁引环比 | 实测 2026-07-22 · **复核 2026-07-24 仍有效**：同一标的 investorsHolding 已回补到 1882（`ownershipPercentChange` −64.4%、`putCallRatioChange` +174% 同为残缺假信号），说明申报季回补持续进行中，环比字段在季内任何时点都不可引用 |
| N-8 | 🐛 **【数组参数家族·主条】`keywords`/`categories`/`sources` 数组入参全域被 schema 拒**（2026-07-20 起）。🔑 **根因已锁定（2026-08-04）**：这几个参数在工具 schema 里声明为**无类型空对象 `{}`**——客户端无从知道该发数组，只能序列化成字符串，服务端却要求 array。<br>**家族成员**：① metrics 侧（本条原始记录，07-22 复现、07-24 仍在）② signal 侧同源（原 N-59f 前半，07-30）③ 107 处 v2 Skill 示例受累盘点（N-31，已归档，示例均已改写）④ 🐛 **服务端自己的补救建议照做必报错**（原 N-71，08-04）：空返回的 `no_match` warning 推荐 `categories=[kol_call] keywords=[BTC]` 写法——照抄必被 schema 拒。<br>💡 **根因层面**：若 schema 声明为 `{"type":"array","items":{"type":"string"}}`，全家族一并消失 | 统一走 query 串（服务端自解析，`meta.filters_applied.keywords` 可验证）；⛔ **不要照抄 warning 里的数组建议**；Dev 修复后回退 | trend-scout v1.11.x + 07-22/07-24/07-30/**08-04** 四轮复现<br>request_id：`28a68c92…` |
| N-9 | biggest gainers/losers 上游缺 marketCap 且全是仙股，禁用；改 `query="most active stocks"`，但实测（2026-07-22 2026-07-22 回归）board 行亦不带 marketCap（trend-scout 旧版记载已失效），需二次批量快照补市值后过滤；红线 9 的过滤清单继续沿用 | 改 query="most active stocks"；客户端 marketCap ≥$1B 过滤 + 剔杠杆 ETF + 仙股 <$5 | trend-scout 实测（N-9）＋2026-07-22 回归修正 |
| N-10 | metrics time_range <1d 返一个月前旧数据 bug；小时级用 interval 参数或只用实时快照 | 小时级用 interval/实时快照 | trend-scout 实测（N-10）|
| N-12 | ➡️ **并入 N-23（query 解析家族·主条①）**。原记录：query 串批量静默丢弃 ticker（9 传 5 收，ONDS 连跳两次无 warning，实测 07-22）——N-23 已将其拆解定量化，ONDS 在其不可解析清单内 | 见 N-23 | 存根（2026-08-04 归并）|
| N-13 | signal consensus 聚合疑似对 time_range 不敏感（3d 与 24h 共四次调用返回 total_posts/多空比/榜单完全一致；可能数据池小到收敛，证据不足定性） | 对外表述窗口用词保守（"近幾日"而非精确小时数）；后续以 3d vs 30d 大窗口差异复验 | 实测（2026-07-22 回归，待复验） |
| N-14 | ➡️ **并入 N-69（query 解析家族·主条②）**。原记录：英文词 beat 被当 ticker 抽取混入仙股 HeartBeam（实测 07-22）——N-69 已证明这是 query 解析的普遍行为，不限财报词 | 见 N-69 | 存根（2026-08-04 归并）|
| N-15 | 财报当晚 `fundamentals.beat_miss` 仍是上一季数据（实测 GOOGL 7/22 盘后发 Q2，当晚返回的仍是 4/29 Q1），FMP 侧延后更新 | 当晚"实际 vs 预期"一律取 `news()` 媒体/披露原文（0 额度），metrics 只用于盘后快照与目标价；次日后才可用 beat_miss 复核 | 实测（2026-07-23 GOOGL 财报夜实跑） |
| N-16 | `consensus_price` 无分析师家数字段（仅 targetConsensus/High/Low/Median），而 c3/c6 规则要求"目标价必带家数+分歧幅度" | 家数不可得时明确标注"家数未提供"，只给区间+中位；需要家数时改由 `analyst_grades` 近 N 条按机构去重估算并注明是估算 | 实测（2026-07-23） |
| N-18 | ➡️ **并入 N-23 形态(d)**。原记录：指数 query 串产生重复行（^VIX 双行，实测 07-23）| 见 N-23 | 存根（2026-08-04 归并）|
| N-19 | 研报榜排名基于 mention count，钻取时可能 `subject_reports=0` 只有 `mention_reports`（实测 GOOGL 榜单第 2、66 篇提及，但主题报告为 0，4 篇全是行业报告里的提及） | 榜单高位≠有专题报告；钻取后必须检查 subject/mention 两层比例，只有 mention 时贴文须写明"是被行业报告提及，不是专题研究" | 实测（2026-07-23） |
| N-20 | `signal(query="详细仓位")` 不带 ticker 时返回全市场原帖，体积极大（实测 2026-07-23：13.7 万字符 / 139 行），直接读入会撑爆上下文 | 客户端脚本先聚合再消费：按 `source_url` 去重（一帖按提及裂多行，139→96）→ 按 symbol 分组统计多空 → 只保留结构化摘要；或用 limit 收窄 | 实测（2026-07-23 讯号汇总实跑） |
| N-21 | 研报调用 `meta.warnings` **误报** `default_fanout_fallback`（"no specific topic…returning the CORE fundamentals set"），但 payload 里 `fundamentals.research_reports` 数据齐全 | **该警告是假阴性，不要据此判定失败或重试**——重试白烧 1 次额度。以 `results.fundamentals.research_reports` 是否存在为准，不看 warning | 实测 2026-07-24：`metrics(query="NVDA research reports", verbosity="detail", time_range="7d", asset_type="tradfi")` → 6 篇 subject + 4 篇 mention，含 institution / analyst / target_price / rating_action / thesis / key_caveat / latest_catalyst，quota=1 |

### 2026-07-27 财报季扫描器实测新增（N-22~N-26）

| 编号 | 内容 | Workaround | 来源 |
|---|---|---|---|
| N-22 🔴未修 | ⛔ **2026-08-04 晚：撤回同日早间「✅大部分修复」的判定——那是单窗口取样造成的假象，根因一点没变**。<br>**新增入参 `country`/`date_from`/`date_to` 确实被接受，但 `country` 是在「取前 500 候选」之后才过滤的**，而候选仍按 **symbol 字母升序**排——美股永远排在 `0CHZ.L`/`1304.TW`/`2207.T` 之后。<br>**决定性对照（同一窗口 08-10→08-14）**：不传 `country` → 50 条**全是** `.L`/`.T`/`.TW`/`.HK`/`.SR`/`.KS`，`has_more:true`（`03c16ce8…`）；传 `country="US"` → **0 条**、`status:"degraded"`（`bfe1c45f…`）。<br>⚠️ **早间 08-04→08-08 窗口能返回 BRK-B/TTWO/VST 是巧合**——该窗口候选总数少，美股恰好落进前 500。**换个窗口即归零**。<br>📌 另测得：`limit` 实际页大小 **50**（传 100 报 `limit_over_max`），`next_cursor` 存在但 **schema 无对应入参**，游标无法回传。<br>原始记录：**earnings_calendar 不可作发现腿** | **发现层改用 `query="most active stocks"` 异动榜 + `news()` 双腿**；日历仅可用于对**已知 ticker** 的单点日期核对，**绝不可作为"某日/某周全部财报"对外发布**。前瞻名单改由 `fundamentals.next_earnings_estimate.date` 对**维护好的关注池**逐个核实——准确，但只覆盖已知名单，**必须对外声明"名单来自关注池而非全市场扫描"** | 实测 2026-07-27（历史区间 ×3 + 未来区间 ×1 + 单日密集日 ×1 + limit 20/50/100/300 四档交叉验证）<br>**2026-08-04 撤回复测**：同窗口 08-10→08-14 对照 —— 不传 `country` `03c16ce8…` / 传 `country="US"` `bfe1c45f…` |
| N-32 | **`country` 参数只作用于 `results.macro.calendar`（经济日历），不作用于 `results.fundamentals.earnings_calendar`（财报日历）**。两者名字近似但是两个独立 block，极易混淆——实测对照：<br>**财报日历**同 `query="earnings calendar"` 同日期区间，传与不传 `country="US"` **返回完全相同的 20 行**（全为 `.L`/`.SR`/`.TW`/`.F`/`.KL`/`.SS`/`.BO`/`.NS`，零美股）｜request_id `ac352acb1b8f434a84b7342a12aa8e29`（不传）vs `7e03620d9ce67884d1425bff8cefe5f0`（传）<br>**经济日历**同 `query="economic calendar"`（**刻意不在 query 里写 "US"，排除查询词收窄的混淆**），不传 → CN/JO/KR/MY 事件；传 `country="US"` → **100% 美国事件**｜request_id `58e6c189ca07c63306afc7c519ec12ac` vs `1886041cff22082fc795a7d235d616ea` | 需要按国别筛**财报**日历时：`country` 帮不上忙，只能客户端按 symbol 后缀过滤（无后缀≈美股，但 5 字母 F 结尾的 OTC 外国发行人如 `ASMXF`/`CGGGF` 会混入）。**排查此类问题时先确认自己在看哪个 block** | 实测 2026-07-27（两组四次对照调用，request_id 已附）|
| N-23 | **【query 解析家族·主条①】query 串 ticker 解析有两种独立故障，不要混为一谈**（N-12「会静默丢弃」的拆解与定量化）：<br>**(a) 批量截断** —— 上限 **5 个 ticker**，传 8 个只解析前 5 个，无 warning。<br>**(b) 上游字典缺失** —— 某些真实美股**任何 query 形态都解析不出**，单票调用也返回 `keywords: null` + 无 `concise`/`snapshot`，且 warning 把整个 query 串当成 FRED series_id 候选。对照实验：`query="NOK next earnings date"` 正常返回 `keywords:["NOK"]` + 完整数据；同形态的 `"JBLU next earnings date"` 返回 null。**已确认不可解析（累计 9 只，全是真实美股）：JBLU(JetBlue) / CUBI(Customers Bancorp) / ONDS(Ondas) / VIVK(Vivakor) / LVWR(LiveWire) / OTLK(Outlook Therapeutics) / AEHR(Aehr Test Systems) / NRC(National Research) / WERN(Werner Enterprises)** —— ONDS 与 N-12 记载的"连续两次被跳过"为同一现象。<br>**(b) 的两种 warning 形态可在补调前区分**：warning 里 `keyword` 是**整个 query 串**（如 `"VIVK LVWR OTLK next earnings date"`）＝**整批全废**，直接全部记缺口不必补调；成功的 ticker **各自出独立 warning** ＝部分缺失，缺的才补调。<br>**(c) 解析成功 ≠ 拿到数据（新增）**：实测 STAK 正常出现在 `filters_applied.keywords` 且 `market.snapshot` 有 marketCap，但 `fundamentals.concise` **无该条目**；SPCX 有 `concise` 条目却**整块 `beat_miss` 缺失**（有 latest_quarter / next_earnings_estimate）<br>**(d) 指数重复行（原 N-18 并入）**——`"^GSPC ^IXIC ^DJI ^VIX"` 解析出 5 个 keywords（多一个裸 VIX），^VIX 返回两条相同行；客户端按 symbol 去重（实测 07-23）| 每批 **≤5 个 ticker** 规避 (a)。**做三道差集**：①`filters_applied.keywords` ②**`concise[].symbol`** ③逐条查 **`beat_miss` 是否存在**——只做①会把 STAK/SPCX 误判为成功，且闸门读到 undefined 不可当 0 处理。差集缺失者按上述 warning 形态判断，需补调的**最多 1 次**即放弃并记缺口（每次无效补调倒扣 1 额度）。**命中已知清单的直接跳过、0 额度**（实测省 3 次/轮）| 实测 2026-07-27（探针批量 + 验收实跑 + JBLU 单票复核 + v1.1 实跑三批复现）|
| N-24 | **fundamentals 三档体积**：①`query="<T> next earnings date"` → **~5 KB/票**（concise: beat_miss/consensus_price/eps_trend/latest_quarter/next_earnings_estimate + market.snapshot 含 marketCap，附赠 10 行无关 earnings_calendar）②`query="<T>"` 或 `"<T> 财报"` 或 `"<T> 财报 超预期"` → **~8.7 KB/票**（三者 byte 级完全相同，多出 balance_sheet×4 + cash_flow×4 + profile + valuation；中文意图词对返回**零影响**，纯废字符）③`query="<T> earnings call transcript"` → **~56 KB/票**（含完整逐字稿）。**transcript 仅在 query 明确含 `earnings call transcript` 时才拉取**，其余 query 绝不误带 | 批量验证用 ①（省 3 倍 context，且 marketCap 顺带拿到，可省掉独立行情调用）；只在 Top N 深扫时用 ③ | 实测 2026-07-27 |
| N-25 | `news(limit=N)` 实际返回 **2N 条**（N 篇 `articles` + N 条 `social`，`total`=2N）。且 **social 桶的美股 ticker 密度高于 articles 桶** | 估算返回体积按 2N 算；抽 ticker 时两个桶都要解析，别只看 articles | 实测 2026-07-27 |
| N-26 | news query 句式决定命中率（同为 7d/limit=10）：**陈述业绩事实**句式 `record quarterly revenue results` 优于 `earnings beat raised guidance`，两者均远优于**情绪涨跌**句式 `earnings surprise stock surges`（被日韩欧股+加密+纯宏观淹没）。⚠️ **绝对命中率波动大，不可当基准**：07-23 实测 13/20 与 8/20，07-27 复测同样两条降到 **8/20 与 6/20**（情绪句式 3/20）——**相对排序稳定，绝对值不稳定**。另 `beat` 一词在 news 侧误伤形态多样：实测撞上**棒球比分报道**、加密代币 $BEAT、以及一条**路透社罗兴亚难民报道**（"two men threatened to beat her"）| 用陈述业绩事实的句式；避开 surge/soar/jump 等涨跌词与 beat。**用命中率排序可以，用它设阈值不行** | 实测 2026-07-27（07-23 首测 + 07-27 复测） |
| N-27 | `verbosity` 参数对 metrics **无效**：`concise` 与 `standard` 返回 payload 一字不差，仅 `meta.verbosity` 字段变化 | 不用传（传了也不省 context）；省 context 靠 N-24 的 query 后缀 | 实测 2026-07-27 |
| N-28 | **transcript 的 `_meta.freshness` 是硬编码常量，不是动态信号**：恒为 `"q-1"`。实测 INTC / GOOGL / CMCSA / IQV / CDNS 五份逐字稿内容均为**本次财报**（当季），freshness 照样写 `q-1`。⚠️ **强化定性（2026-07-29）**：它不是"有时对有时错"，而是**恒定值恰好与某些情况重合**——拿它判新鲜度会把 **100% 的当季逐字稿误判成滞后** | 核对逐字稿季度一律看 `transcript[0].date` / `period` / `year`，**永远不看 `_meta.freshness`**；预判是否滞后用 N-34 的 gap 判据 | 实测 2026-07-27（三份）· **2026-07-29 追加 IQV/CDNS 两份反例并强化定性** |
| N-29 | **同一 payload 内 GAAP 与非 GAAP EPS 并存且互相矛盾，无字段标明口径**：实测 INTC `beat_miss.epsActual = 0.42`（非 GAAP，对预期 +100%）与 `latest_quarter.eps = −2.16` / `netIncome = −$110.3 亿`（GAAP 巨亏）同处一个返回。只看 beat_miss 会把巨亏季读成"完美超预期"。<br>⚠️ **2026-08-05 判据放宽（原记「反号即判定」过窄）**：实测 NVDA **同号不同值**——`earnings_surprise.actual_eps 1.87` vs `financial_statement.eps 2.40`，同一季度、都为正、差 **28%**，按反号判据**完全不触发**。<br>🔴 **同号错位比反号更危险**：反号一眼看得出不对劲，同号会被当成同一个数直接混用——实测下游因此产出「上季 2.40 → 下季预期 2.08 = 利润下滑 13%」（实为 `1.87 → 2.08` **+11%**）与「实际 2.40 vs 预期 1.76 超预期 6.3%」（该式算出来是 +36%，自身不成立）两个假陈述 | **判据：两个 EPS 只要不相等即判定口径错位**（不限反号）。<br>· **反号** → 标注「该超预期为非 GAAP 口径」，改用营收 surprise 作主锚<br>· **同号不等** → 两条序列都可用但**严禁跨序列组合**：与 `next_earnings_estimate.epsEstimated` 比只能用 `actual_eps`；看历史趋势只能用 `eps_trend`（与 `financial_statement` 同源）<br>✅ 自检：任何两个 EPS 进同一句话前，先确认同一字段族 | 实测 2026-07-27 |
| N-30 | **原油符号四种写法实测三死一活**（结案 N-11 与红线 6 的长期冲突）：`CLUSD` → `no_match` 返 **0 结果**（不是 402）｜`BZUSD` → query 串里被**静默丢弃**（实测 `query="BZUSD USO"` 只解析出 USO，不报错不返数据）｜`OIL` alias → 返回 **iPath Pure Beta Crude Oil ETN**（symbol OIL，$28.42，市值 5300 万）而非原油价格，且附带诡异 warning `asset_type=tradfi but all keywords resolved to other families (crypto)`｜**`USO` → 唯一可用**（United States Oil Fund，$136.52，市值 $163 亿，跟踪 WTI 近月期货）| 原油一律走 `query="USO"` + `asset_type="tradfi"`。⚠️ **USO 是期货 ETF 代理指标，不是现货价**，对外引用必须说明口径。红线 6 的"CLUSD(WTI)/BZUSD(布油)"记载已**全部作废**；10 号 Skill 原"布油 100% 命中"的记载是过期假声明（静默失败，跑了也不知道没拿到）| 实测 2026-07-27（四种写法逐一验证）|
| N-33 | **`beat_miss` 字段可为 null 但服务端仍参与运算，把缺失伪装成极端真值**（第 4 种数据缺失形态，比 N-23 的三种更危险）：实测 F(Ford) `revenueActual: null` / `revenueEstimated: 47237900000` → 服务端**把 null 当 0 做减法**，输出 `revenue_diff: -47237900000`、**`revenue_surprise_pct: -100`**。该条目 keywords 有、concise 有、beat_miss 结构完整，**N-23 的三道差集全部通过**，下游读到的是"营收暴跌 100%"这个假真值。<br>另：`beat_miss.date` 与 `latest_quarter.date` **季度对齐关系不固定**——实测 F 的 latest_quarter 落后**两季**（Q1 vs 07-28）、STX 落后一季（Q3 vs Q4）、V 反而**领先**一季（Q3 vs Q2） | ①**第 4 道检查**：`revenueActual` 非 null 才可读 `revenue_surprise_pct`；见到 `-100` 一律先当缺失查证（真实世界营收归零几乎不可能）②**N-29 的反号比对须先确认同季**：`beat_miss.date` 与 `latest_quarter.date` 不同季则该项判定作废并标注"口径无法核对"，跨季比对会让一盈一亏的相邻两季产生假阳性 | 实测 2026-07-29（v1.2 实跑 + F 单票复核）|
| N-34 | **`earnings call transcript` 的滞后是确定可算的，不是随机的**（⚠️ 本条已推翻初版"事前无信号可预判"的判断）：<br>**判据**：`transcript[0].period` **恒等于** `latest_quarter.period`。因此用 `gap = beat_miss.date − latest_quarter.date` 即可**事前预测**这次会拿到哪一季——两个字段同在轻量调用返回里，**零额外成本**。<br>**阈值 = 90 天（一个完整财季）**。⚠️ **初版取 60 天已被 42 样本证伪**——45~70 天区间**密集有样本且全部返回当季**（BABA 43 / BIDU 48 / NIO 51 / PDD 57 / TIGR 63 / EH 70，**几乎全是报告节奏慢的中概 ADR**，其中 PDD/TIGR/EH 三只已逐一拉逐字稿验证），60 天会把它们误判为滞后而跳过。<br>**分布（42 样本）**：10~34 天 24 个（美股本土大中盘，当季）｜**43~70 天 10 个**（中概 ADR，当季）｜**71~115 天 0 个**（未实测空白区，但有结构解释）｜116~119 天 3 个（滞后）。<br>**90 是从机制推的不是拍的**：gap 的物理含义即**财报公布滞后天数**——数据新鲜时 gap = 滞后本身（实测 10~70）；latest_quarter 落后一季时 gap = 滞后 **+ 一个完整财季（≈90）**。两者只可能差一个整季，故分界必在 90 量级。<br>❌ **"距财报日天数"假设已被实测证伪**：IQV 与 STX/KLAC **同为 2026-07-28 发财报**（距今均 1 天），IQV 返回当季而 STX/KLAC 返回上一季；CDNS 距今仅 2 天亦返回当季。同日相反结果 ⇒ 日历不是原因。<br>**机制**：`beat_miss` 走即时 surprise 源，而**财报三表与逐字稿是同一批入库**，入库快慢按个股而异，与日历无关 | **拉取前**先算 gap：**≥90 天**则该季尚未入库，transcript 必返上一季，**直接跳过调用**（省 1 额度），该股不占 Top N 名额、关键词闸标注"欠测"。<br>兜底：万一仍拉到季度不符，同样按"欠测"处理——低分=扫了没讲，欠测=根本没扫到，两者对下一步动作的指示相反 | 实测 2026-07-29（4 只专项探针 + INTC/TER/GOOGL/F 回验 + **36 只边界探针**，共 42 样本；判据在全部已测样本上 100% 成立）|
| N-36 | **【query 解析家族·成员（独立机制：名额挤占）】有"影子代码"的 ticker 会在批量 query 里被双重展开，吃掉批次名额**（**非解析失败，是名额被挤占**）。两类实测：①**商品重名**——`CL`（Colgate-Palmolive）被同时解析成股票 `CL` **和原油期货 `CL=F`**，`filters_applied.keywords` 回填为 `["CL","CL=F","AON","PSX","HCA"]` —— 占满 5 个名额，导致该批第 5 个请求项 NUE **被顶出**（非解析失败，是名额被挤占）；②**中概 ADR 双重上市**——`BABA` 被展开成 `BABA` **+ `9988.HK`**（港股），顶掉同批的 `LI` | 含 `CL`/`GC`/`SI`/`NG`/`HG`（商品重名）或 `BABA`/`JD`/`NTES`/`BIDU` 等在港二次上市的中概时，**该批按 4 个装**，或把这类符号单独放一批。调用后照例核对 `filters_applied.keywords` 与请求清单做差集 | 实测 2026-07-29 |
| N-35 | **个别实体存在 news 召回黑洞，且语义兜底返回的是固定集合而非随机内容**：实测 `query="Bloom Energy BE"` 与 `query="Bloom Energy"` 返回**逐字完全相同的 12 条**兜底内容（Bear Grylls／悼文／美联储／Claude 链接泄露…），**0 条目标公司内容**；而索引里确实有 BE 内容（其他 query 的返回里出现过 BE 财报标题与 3 条 `$BE` 社媒）。同一轮 `query="Teradyne TER"`/`query="Visa V"` 均精准命中，故 N-15 双词形态本身有效 | ①**同 query 重试无意义**，换措辞亦无效（去 ticker 后逐字不变）②**两个不同标的的降级查询若都失败会拿到一模一样的内容**——不逐条核实相关性极易误判成"两票有共同报道"③判别：返回里**一条都不含目标公司名或 ticker** 即判召回失败，记缺口不重试 | 实测 2026-07-29（两组 query 对照 + 跨 query 交叉验证索引确有内容）|

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

> 🔒 **本节交易员已脱敏**（`T1`/`T2`…；`T3` 与 `T3′` 是同一人的两个显示名）。数字、tier、`rating_reason` 均为实测原值未改。

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
| N-59f | ➡️ 数组入参被拒部分**已并入 N-8（数组参数家族）**，本条保留独立发现：**取价调用必然附带整套 CORE fundamentals**（`default_fanout_fallback`），实测把 query 从 `"… price"` 改成 `"… quote snapshot"`、再加 `verbosity="concise"` **都去不掉**——三表/估值/profile 照样全返 | ①`signal` 与 `metrics` 一律走 `query` 自由文本路由（服务端会自己抽意图与标的，实测 `filters_applied.keywords` 正确回填）；②取价时**只读 `results.market.snapshot[]`，其余忽略**——额度仍只计 1 次，代价是 token 不是配额；③批量取价上限沿用红线 4 的 **5 个** | 实测 2026-07-30 |
| N-59g | **取价失败有两种静默形态，且都返 `status:"ok"`——必须做差集自查**。实测一次 `metrics(query="SNDK 000660.KS CXMT XYZ100 quote snapshot", asset_type="tradfi")`：①**`CXMT` 被从 `filters_applied.keywords` 里整个剔除**（applied 只剩 `["SNDK","000660.KS","XYZ100"]`，连查都没查）；②**`XYZ100` 进了 keywords 但 `market.snapshot[]` 里没有它的行**（默默少一行）。两种都不报错、不出 warning 指名道姓。<br>另：**crypto 批不带 fundamentals**（`asset_type="crypto"` 只返 market.snapshot + history，很轻），**tradfi 批必带 CORE fundamentals 全家桶**（N-59f）——同一个"取价"动作两种成本 | **把请求的 symbol 列表与返回的 `snapshot[].symbol` 做差集，差集非空即部分失败**——不要用"有没有报错"判断成败，也不要用返回行数对比请求个数（两种形态一个少 keyword 一个少行，只有差集能同时抓住）。crypto 与 tradfi 分批（asset_type 不能混），批内 ≤5 个 | 实测 2026-07-30（4 标的混批，2 成 2 败）|
| N-59h | **`profile.summary` 的散文数字比同对象的结构化字段旧，不可引用**。实测T4：`summary` 写 *"across 406 closed trades"* / *"150 closed trades in last 30 days"*，而同一 profile 的 `overall.n_trades=431`、`last_30d.n_trades=175`——**双双差 25 笔**。该交易员 30 天 175 笔，几小时就能差出这个量；`summary_refreshed_at`（02:37Z）落后于数据本身。对照组：T8同批 summary 22/17 与结构化字段完全一致——**所以"看起来对得上"不能当验证通过**，一致与否取决于该交易员的成交频率 | **所有对外数字一律取结构化字段**（`overall` / `last_30d`），`summary` 只当定性描述（style / follow / skip conditions）读。⚠️ 尤其别把 summary 里的笔数当样本量去判"样本是否充足" | 实测 2026-07-30（T4 vs T8对照）|
| N-59i | **同一份 `trader_position` 返回里两半新鲜度不同：仓位/事件实时，交易员 `profile` 是日快照**。实测 30 分钟内两次拉取（08:24Z / 08:55Z），15 名交易员的 `overall` / `last_30d` / `as_of` / `summary_refreshed_at` **全部一字未变**（`as_of=2026-07-30`，refresh 时点约 02:3xZ），而同期仓位侧新增了T15的 08:31Z 事件（N-59d）。<br>⛔ **`last_30d.n_trades` 是滚动 30 天窗口，日增量 ≠ 当期平仓数**：增量 = 当期平仓 − 滑出窗口的平仓，可为负或偏小。实测T1 `overall=54` / `last_30d=2`——52 笔在窗外，窗口每天都在吐旧数据。<br>✅ **`overall.n_trades` 是累计值**（= 累计已平仓笔数，`rating_reason` 措辞印证："enough samples (22)" / "insufficient sample (2 closed trades)"），**其增量才是当期真实平仓数** | ①任何"该交易员这段时间成交了多少"的推算**只能用 `overall.n_trades` 增量**，且**只在 `as_of` 变化时才算**（同日重跑增量恒为 0，会被误读成"零成交"）；②引用战绩数字一律说"截至 `as_of`"，**不要说"当前"**；③想估"轮询式观察漏了多少"：`观测到的平仓数 ÷ overall 增量` = 观察覆盖率。⚠️ **实测这个比值很低**：15 名交易员合计真实平仓约 **10.8 笔/天**，而日频快照最多只看到"持仓过夜且当日消失"的那几笔——每天观测到 1/2/3 笔分别对应覆盖率 **9%/19%/28%**。任何基于日频轮询的"跟踪某人交易"都要按这个量级打折，别当成看全了| 实测 2026-07-30（同日两次拉取 15 人逐字段对照）|

| N-59j | ⚠️ **推翻 N-59a 的 workaround：notional 派生方向在 null 率为 0 时**照样**会给出反向结论——巨鲸压秤**。N-59a 说"notional 派生字段只有在该组 null 率为 0 时才可引用"，**该条件不充分**。<br>实测 BTC 组（8 仓**全部有 notional，null 率 0**）：`long{count:7, notional:2,061,400}` vs `short{count:1, notional:2,064,433}` → `long_notional_ratio 0.4996` / **`net_direction:"short"`**，而同一个 rollup 的 `agreement` 报 `dominant_direction:"long", ratio:0.875`。<br>**7:1 的人数分歧被一个人的仓位抹成 50:50 并翻成 short**（T3 单仓占 gross 的 **50.0%**）。<br>⚠️ 叠加红旗：**翻转方向的这一仓，其 `current_symbol_caution` 恰为 `true`**（BTC 在T3 自己的 `caution_symbols` 里）| **`net_direction` / notional 比率任何时候都不单独用**——不是"null 率 0 才可用"。<br>正确读法三步：①先报 `long.count`:`short.count`；②算 `最大单仓 ÷ gross`，**>40% 标「单人主导」**（阈值拍的，未回测）；③净方向**永远写两个口径**（"按人数 7:1 偏多；按名义 50:50，因单仓占 50%"），绝不写单一结论 | 实测 2026-08-01（5 组 21 仓逐仓手算核对）<br>request_id：`66880966…` |
| N-59k | **同一交易员双向持仓时 `agreement` 整个退化为 `unknown`/0/0——而 N-59a 恰恰推荐用它判一致性**。<br>实测 ETH 组：`active_trader_count:3` 但 `positions_returned:4`——T1同时持 ETH 多头 155 万与空头 95.7 万（对冲腿）。结果 `long{count:2}` / `short{count:2}`（4 条腿），`agreement:{dominant_direction:"unknown", dominant_trader_count:0, ratio:0}`。<br>✅ **对照**：CXMT 组也有人双向（T2），但还有 2 名单向交易员 → `agreement` 正常给出 `long/2/0.667`。**说明字段是"能算就算、算不动吐 unknown"，不是坏了** | ⚠️ **`agreement.ratio: 0` 不可读作"没有共识"**——先用 **`positions_returned` vs `active_trader_count`** 判断是否有人双向持仓（不等即有），**有则必须点名那个人**，再说"该组存在对冲腿，一致性不可用单一比率表达"。<br>⚠️ **2026-08-03 修正：该判据只覆盖了 `unknown` 的一个成因**——实测 CL 组无人双向（`positions_returned == active_trader_count`）而 `agreement` 照样 `unknown`（单向交易员本身平局）。**完整计票规则见 N-59r** | 实测 2026-08-01<br>request_id：`66880966…` |
| N-59l | 🐛 **疑似上游 bug：`notional_value_usd` 为 null 但该行有 `entry_price` 时，rollup 把 `entry_price` 当成名义金额加总**。<br>实测 SNDK 组：逐仓手算 `long.notional` = T9 136,632 + T5 2,542,330 = **2,678,962**，而 rollup 报 **2,680,184.04**——**差 1,222.04，恰好等于T1该仓的 `entry_price`（1222.04）**，且T1该仓 `notional_value_usd` 为 null。<br>**`.04` 小数是铁证**：其余所有名义均为整数。<br>✅ **两组对照排除其他解释**：① ETH/JS 与 CXMT/JS 均为 null notional 且**无** entry_price → 被正确排除；② BTC/T4 **同时有** notional(271,204) 与 entry_price(64,431.6) → 计入的是 notional，未污染。<br>→ 触发条件精确为 **`notional == null && entry_price != null`**。5 组里 4 组算术干净，仅此一组污染 | **消费 `gross_notional_value_usd` 前先手算 `long.notional + short.notional` 核对**，对不上且差额等于某行 `entry_price` 即命中本条 → **以逐仓明细为准，不用 rollup 汇总**。<br>⚠️ 本条会让「单人占比」等派生指标一起偏，但因污染量通常极小（entry_price 量级远小于名义），**影响的是精确性不是方向** | 实测 2026-08-01（5 组逐组算术核对，1 组命中）<br>request_id：`66880966…`<br>⏳ **2026-08-03 复验：触发条件未出现，维持待复验**。本批 5 个 null-notional 行**全部无 `entry_price`**（对应 N-59l 的排除路径）；唯一同时具备两者的行（T4/BTC，notional 271,204 + entry_price 64,431.6）经手算核对 `long.notional` 合计 **2,244,902 = rollup 逐字相符**，未污染。→ **不能判已修，只能判本批未命中** |
| N-59m | 🔴 **平仓不回流 → 幽灵仓：交易员已清仓，MCP 仍返回其旧仓位且 `is_active` 恒 `true`**。N-59d 曾记"close/is_active=false 机制上可能支持，样本内未出现，不要假设一定能抓到"——**现在有了反例，可以定性了**。<br>**外部证据**：上游实盘监控 bot 显示「T5 当前无持仓 · 当前杠杆概览：—」（该员 07-29 10:18 有过仓位变动通知），而 MCP 于 **08-01** 仍返回其两条仓位：SNDK **$2,542,330** + SKHY **$1,970,988**，`is_active: true`、`action: "add"`、无任何平仓痕迹。<br>**⚠️ 危害等级**：这两条合计 **$451 万**，在当次全榜里是**名义第一大敞口**（占全榜 $1,201 万的 **38%**）——不过滤就会把幽灵仓当成"最大的钱"写进结论。<br>✅ **可从 MCP 数据本身检测**：看 `event_time` 陈旧度。T5两仓分别 **3.7 / 3.6 天**未动；本批 21 仓中 **7 仓（33%）≥3 天**、涉及名义 **$486 万（40%）**。<br>📌 **本批出现干净断层**：陈旧簇集中在 **3.0–4.8 天**，活跃簇全在 **≤1.8 天**，中间**无任何仓位**——3 天这个切点在本样本里是数据自己给的 | **消费前必过「陈旧闸」，两条并联**（命中任一即标"待核，不计入敞口排名"）：<br>① **绝对**：`now − event_time ≥ 3 天`<br>② **组内落后**：`该仓 event_time` 比所在组 `symbol_rollup.latest_event_time` 落后 **≥2 天**（T5 SNDK 落后 3.7 天、SKHY 落后 2.9 天，两条都命中）<br>⚠️ **3 天/2 天均为拍的阈值，仅有本批断层支撑，未回测**。但**方向是确定的**：`close` 不回流 + `is_active` 恒 true ⇒ **不设闸就必然把幽灵仓当真实敞口**。<br>⛔ 措辞：陈旧仓只能说"**≥N 天未观测到变动，可能已平仓**"，不能说"他持有 X"，也不能说"他已平仓"（两头都无法证实）| 实测 2026-08-01 + 上游 bot 交叉验证<br>request_id：`66880966…` / `2ab45ef2…`（两次拉取一致）<br>🔴 **2026-08-03 复验：机制仍在，且证据更强**。原样本里的 T5 已掉出榜单（无法直接复现该员），但**本批 5 个 `symbol_rollup` 的 `actions.close` 全部为 `0`**——20 仓、跨 8 天数据、**零个平仓事件**，与「close 不回流」完全一致。陈旧仓依旧普遍：T1/BTC 3.9 天、T4/BTC 4.8 天、T7/BTC 5.6 天、T2/CXMT 多头腿 6.2 天，`is_active` 全为 `true`。→ **闸① 必须保留** |
| N-59n | **同一交易员在不同标的组下显示名不一致，按人聚合时会被算成两个人**。实测「**T3**」（BTC 组）与「**T3′**」（SKHY 组）的 `profile` **逐字段完全相同**：`overall` 149 笔 / `net_pnl_usd` 3,095,063 / `pnl_ratio` 2.56 / 胜率 44%、`last_30d` 71 笔、`focus_symbols` 与 `caution_symbols` 数组逐项一致，**连 `summary_refreshed_at` 都是同一秒**（`2026-08-01T02:35:31Z`）。<br>**危害**：按人聚合敞口时，该员真实敞口 **$2,509,907**（BTC 空 2,064,433 + SKHY 多 445,474）会被拆成两个人的 $206 万与 $45 万，**"谁的钱最大"排名直接失真**；同时会重复计入其红旗（`current_symbol_caution`）或反之漏掉 | **不要用 `trader` 字符串当聚合主键**。建议按 **profile 指纹**归一——`overall.n_trades` + `overall.net_pnl_usd` + `summary_refreshed_at` 三元组相同即判为同一人（三者同时巧合的概率极低）。<br>归一后须在产出里注明"已合并显示名 A/B" | 实测 2026-08-01<br>request_id：`66880966…` |

| N-59o | **`focus_symbols` / `caution_symbols` 只覆盖两端，「两个名单都不在」这第三种状态没有任何字段标记**。`current_symbol_caution` 只在标的落入 `caution_symbols` 时为 `true`；**落入 `focus_symbols`、或两边都不在，返回值完全一样（`false`）**——消费端无法区分「他擅长这个」与「系统对他在这个标的上毫无判断」。<br>实测三分类（19 仓，已剔幽灵仓）：**擅长区 12（63%）· 弱项区 3（16%）· 陌生区 4（21%）**。<br>⚠️ **陌生区常伴高杠杆**：4 仓中 **3 仓 ≥10x**——JS 做 ETH **25x**（其 focus 是 CXMT/LITE，均为股票永续）、T1 做 SNDK **20x**（focus 是 ETH/BTC/EDEN，全加密，且这是他全部仓位里最高杠杆）、T4 做 BTC 11x（tier D，PF 0.67）。**4 仓中 3 仓属跨资产类别**（加密玩家做股票永续或反之）。<br>⚠️ **未知**：`focus_symbols` 的导出口径**未文档化**——可能按成交频次，也可能按表现。从 `caution_symbols` 的语义反推像是表现导出（T2 caution 含 CXMT 而其 PF 0.42；N-59 记过 T14 做 000660.KS 亦在自身 caution，盈亏比 0.05）。| **客户端自行做三分类**：`标的 ∈ caution` → 弱项；`∈ focus` → 擅长；**两者皆非 → 陌生**。<br>⛔ **陌生区的表述必须校准**：只能写「**系统对他在这个标的上没有判断**」，**不能写「他不擅长」**（无证据）。<br>✅ 值得单独提示的是**组合**：`陌生区 × leverage ≥10x`——无信息 + 高杠杆。| 实测 2026-08-01（19 仓逐仓分类）<br>request_id：`66880966…` |
| N-59p | **`as_of` 不是该交易员战绩的刷新时间——同一次返回里各人的 `summary_refreshed_at` 可以差好几天，而 `as_of` 对所有人统一等于拉取日**。<br>实测 2026-08-03 一次拉取（5 组 / **20 仓 / 13 个显示名**，归一后 12 人）：**T1 的 `as_of` 写 `2026-08-03`，但 `summary_refreshed_at` 停在 `2026-08-01T02:35:53Z`——落后 2 天**；同批其余 12 人全部为 `2026-08-03T02:3x:xxZ`。<br>⚠️ **且 T1 的战绩数字在 08-01 与 08-03 两次拉取里逐字未变**（`overall` 55 笔 / PF 5510.64 / 胜率 98%，`last_30d` 2 笔）——与 `summary_refreshed_at` 未推进一致。<br>🔴 **危害精确落在最扎眼的那个数上**：本组 sanity check 第 1 条要拆的正是 T1 的「98% 胜率 + PF 5510」，而这组数比同表其他人旧 2 天。按 `as_of` 写「截至 2026-08-03」= **把 08-01 的快照标成 08-03**。<br>📌 与 N-59i 的分工：N-59i 说的是「profile 整体是日快照、比仓位旧」；本条说的是「**日快照本身各人不同步**」，`as_of` 掩盖了这种不同步 | **战绩的时间锚一律用 `summary_refreshed_at`，不用 `as_of`**。`as_of` 只能理解为「本次拉取日」，不是「该员数据刷新日」。<br>✅ 同表展示多人时：取各人 `summary_refreshed_at` 的**最小值**做整表口径，跨度 ≥1 天必须在产出里点名最旧的那个人。<br>⛔ 措辞：写「战绩截至 `<该员 summary_refreshed_at>`」，**不写「截至 as_of」也不写「当前」** | 实测 2026-08-03（13 个显示名逐人对照）<br>request_id：`c02a7271…` |
| N-59q | **全组 notional 皆为 null 时，rollup 不报缺数据，而是吐出 `net_direction:"balanced"` + 金额 0 + 比率 0——「完全没有数据」被渲染成「多空正好平衡、没有敞口」**。<br>实测 XYZ100 组：`positions_returned:3` / **`positions_without_notional:3`（100%）** → `gross_notional_value_usd:0`、`net_notional_value_usd:0`、`long_notional_ratio:0`、`short_notional_ratio:0`、**`net_direction:"balanced"`**，而 `long{count:2}` / `short{count:1}`、三条腿**全是 20x 杠杆**。<br>✅ **对照排除「字段坏了」**：同批 ETH 组 `positions_without_notional:1`（4 中 1），rollup 照常给出 gross **2,609,830** → 字段是「有多少算多少」，**只有全 null 才退化**。<br>🔴 **双重危害**：①`balanced` 与「真的多空对等」在返回值上**完全无法区分**；② `gross=0` 会让该组在「谁的敞口最大」排序里**沉到最底**或被过滤掉，而它实际有 3 条 20x 的腿。<br>📌 与 N-59j 的区别：N-59j 是**有数据但被巨鲸扭曲**，本条是**没有数据却给出了值** | **读 `net_direction` / 任何金额派生字段之前，先判 `positions_without_notional == positions_returned`**——命中则该组 `gross`/`net`/`long_notional_ratio`/`short_notional_ratio`/`net_direction` **五个字段整体作废**，只能报**人数与杠杆**。<br>⛔ 措辞：只能写「该组 N 人 M 条腿（多 x／空 y），**平台未提供金额，敞口无法计价**」，**不能写「多空平衡」，也不能写「无敞口」**。<br>💡 `positions_without_notional` 是 dev 新加的字段，本条与 N-59j 现在都可**机械判定**，不必再手算核对 | 实测 2026-08-03（5 组对照，1 组全 null、1 组部分 null）<br>request_id：`c02a7271…` |
| N-59r | ✅ **`agreement` 的真实计票规则（实测反推，5/5 全中）——`unknown` 有两个成因，N-59k 只记了其中一个**。<br>N-59k 说「双向持仓会把 `agreement` 打崩成 unknown」，并建议用 `positions_returned > active_trader_count` 识别。**该判据不充分**：实测 CL 组 `agreement:{unknown, 0, 0, total:2}` 而 `positions_returned(2) == active_trader_count(2)`——**没有任何人双向持仓**。<br>**逐组反推出的规则**：`agreement` **按「交易员」计票而非按「腿」**，每人取其唯一方向；**双向持仓的人不计入分子**（但仍计入 `total_trader_count`）；`ratio = dominant_trader_count / total_trader_count`；**可计票的人里若无严格多数（平局），整体吐 `unknown/0/0`**。<br>**5 组逐组验证全中**：BTC 6长1空 → `long/6/0.857`（6÷7）· CXMT 2 人单向做多+1 人双向 → `long/2/0.667`（2÷3）· XYZ100 1 人单向做多+1 人双向 → `long/1/0.5`（1÷2）· **ETH 1长1空+1人双向 → 平局 → `unknown`** · **CL 1长1空、无人双向 → 平局 → `unknown`**。<br>⇒ 成因①**双向持仓吃掉一票**导致剩余票平局；成因②**单向交易员本身就是平局**（本条新发现，与双向无关） | ⛔ **不要用 `positions_returned` vs `active_trader_count` 判 `unknown` 的成因**——它只能识别「有人双向」，识别不了平局。<br>✅ 正确读法：`unknown` 一律读作「**该组没有多数方向**」，然后**看 `long.count` : `short.count` 自己判**是平局还是被双向吃票。<br>✅ 反过来这条规则是**正面可用的**：`ratio` 的分母是**人数**不是腿数，所以 `dominant_trader_count / ratio` 能反推出 `total_trader_count`，可用于交叉校验 `active_trader_count` | 实测 2026-08-03（5 组逐组反推，5/5 命中）<br>request_id：`c02a7271…` |

| N-59s | 🔴 **同一显示名下可以是两个不同的人——这是 N-59n 的镜像，两个方向同时存在**。<br>实测 2026-08-04 BTC 组：**「T3」出现两次，`profile` 完全不同**——一条 `tier:"A"` / `overall.n_trades:151` / `net_pnl:3,296,931` / `summary_refreshed_at:08-03T02:35:30Z`；另一条 `tier:"—"` / `n_trades:0` / `refreshed:08-04T02:35:13Z` / `focus:[ETH,BTC]`。两条都是 short，名义 2,063,784 与 2,104,852。<br>⚠️ **同一份返回里同时存在两种病**：`T3`(tier A/151笔) 与 CL 组的 `T3′` **profile 逐字段相同**（N-59n：同人两名），而 `T3` 又与另一条同名但不同 profile 的行共存（本条：同名两人）。<br>✅ `active_trader_count:8` 把两条算作 2 人——**服务端按 profile 计数，是对的**；错的是显示名 | ⛔ **显示名在两个方向上都不能当身份键**。闸② 的 profile 指纹归一方向正确，但必须**双向**执行：①指纹相同 → 合并（哪怕名字不同）；②**指纹不同 → 强制拆开（哪怕名字一样）**，且产出里必须标注「同名两个账户」，否则读者会以为是渲染重复。<br>💡 交叉校验：`agreement.dominant_trader_count ÷ ratio` 反推出的 `total_trader_count` 与去重后人数对不上时，优先信服务端 | 实测 2026-08-04<br>request_id：`5a6f20d4…` |

**本组的正面产出（对外展示交易员档案时必做的四项 sanity check）**：`trader_position` 的 `profile` 把战绩算好了直接给，但**几个最扎眼的数字恰好最会骗人**——散户的眼睛就落在那几个数上。展示任何交易员战绩前过一遍这四条：

1. ⛔ **`pnl_ratio_infinite=true` 不是"神"，是"盈亏比不可验证"**（零亏损记录 → 分母为 0）。实测T1 `n_trades=54` / 胜率 **100%** / 盈亏比 `∞`，但 `last_30d.n_trades=2`——54 笔的辉煌几乎全在 30 天窗口外，`rating_reason` 自己写的是 *"zero-loss record … profit factor is not verifiable; provisional"*。**必须把 `rating_reason` 一起展示，不要只报胜率**。
2. ⛔ **小样本的高盈亏比要连样本量一起报**。实测 T13 盈亏比 **16.04** 看着顶级，`n_trades=7`，且 `last_30d` 净亏 −14,335。tier `P`（provisional）已经编码了这层不确定，但用户看的是 16.04。
3. ⛔ **`current_symbol_caution=true` 是最硬的单条红旗**：他正在做的标的就在他自己的历史弱项名单里。实测T4 **20x 空 XYZ100**，而 `caution_symbols` 首位就是 `XYZ100`；T14 做 `000660.KS`，同样在自己的 caution 名单里（盈亏比 0.05 / 胜率 25%）。
4. ⛔ **杠杆 ≥10x 单独提示**：实测 17 行里 10x 及以上占 8 行（含两条 20x）。杠杆不在 tier 评级的输入里，但它决定这个仓位能不能活到方向被验证。

5. ⛔ **盈亏比极大值同样不可读作实力**（2026-08-01 新增，与第 1 条同源）。`pnl_ratio_infinite` 只覆盖"零亏损"这一端，**但有限的极大值一样骗人**：实测T1 `pnl_ratio: 5510.64` / 胜率 98% / 55 笔——比值离谱说明**亏损样本极少或极小**，不是实力越强。<br>⚠️ **同一交易员 07-20 时还是 `pnl_ratio_infinite: true` / 胜率 100% / tier `P`**，08-01 变成 `5510.64` / 98% / tier **`A`**——**多出的那一笔（第 55 笔）亏损让分母不再为 0，tier 直接从 provisional 跳到 A**。<br>→ 判据：`pnl_ratio > 100` 与 `pnl_ratio_infinite=true` **同等对待**；**tier 会因单笔样本跃迁，当次读数用，别当稳定标签**。

⚠️ 另：**`n < 10` 时不要给百分比**——3 笔里 2 胜写"2/3"，写成"67%"是伪精确。实测有 `n_trades=1` 且胜率 100% 的行（T5）。

### 2026-07-30 研报通道 Tier4 实测（N-68）

> ⚠️ 2026-08-04 改号：本条原编号 N-59 与上方 trader_position 组（N-59a-r）撞号，改为 N-68。

| # | 现象 | 应对 | 证据 |
|---|---|---|---|
| N-68 | **`news()` 拿不到"独立研报 feeds 文章类"**：全部索引条目一律 `provenance:"feeds"`（`_source`/`fmp_news` 字段名**不存在**，Seeking Alpha/fool.com 也返 `provenance:"feeds"`+`source_name:"media"`）；`category` 是话题噪音标签；`sources=["research"]` 数组被 schema 拒（N-8 同源），无字符串替代 | 独立 Substack 深度只能近似捞：① `social[]` 里 `kol_info.categories` 含 `"research"` 且正文挂 substack 链接（真形态）② `articles[]` 里 `source_quality=="research"`（⚠️ Motley Fool 混入，隔离不干净）。正文恒 `content_truncated`（~300-500字预览，全文需原始 URL）。**结构化评级(`analyst ratings`)与整篇研报卡(`research reports`)是另两个通道，不能当 feeds 兜底** | 实测 2026-07-30（news 逐条字段核对） |

> ~~**N-41 补充（研报卡 TP 水分族）**：研报卡 `target_price.currency` 同币种存在多写法（TWD vs NT$）~~ ✅ **已修（2026-08-12，随 N-84 销案）**：`currency` 已归一 ISO（实测 `TWD`/`KRW`），原始写法保留在 `text`（`"NT$3,650"`）。**归一步骤可以从各 Skill 流程里撤掉**；此段留存防回归。
>
> **N-38/N-66 现场复现**（研报卡 research_reports 通道，Tier4 实证）：NVDA `report_limit:10`、`subject 6 + mention 4`；台积电枢纽票 `subject 10 / mention 0`（mention 被 subject 挤没）；机构名不归一（`Morgan Stanley` vs `Morgan Stanley & Co. LLC`）+ 同日同 TP 近重复（Citi $300×2 不同 event_id）→ 榜面"23 家"钻取去重实只 3 家。**net_direction 是叙事雷达（谁被点名）不是机构共识**（点名受益股天然正向：NVDA beneficiary:73/negative:14 恒 positive·N-39）。`verbosity="detail"` 单标的实测 65K 字符必炸批 + `limit≥20` 超时。
> 🔄 **08-12 追注**：本段的「榜面 23 家钻取实只 3 家」算术当时受 10 篇死顶约束——**现可翻页枚举完再算**（N-81）；机构名不归一（Morgan Stanley vs & Co. LLC）**08-12 复测样本内未复现但样本不足，未销案**。

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

### 2026-08-01 r0 覆盖雷达首跑实测新增（N-60~N-61）

| 编号 | 内容 | Workaround | 来源 |
|---|---|---|---|
| N-60 | **榜面 `target_price_coverage` 不是「专题报告多寡」的代理指标——高 TP 覆盖是研究文化差异，不是覆盖深度**。<br>⚠️ 这条是**被实测证伪的直觉**，写在这里防止重犯：榜上三星 `with_numeric_target=30`、台积电 29，而其余八只全在 **11–15**，看起来像"亚洲两强被研究得更深"。<br>**实际钻取三只对照，subject/mention 完全相同**：三星（TP 30）`subject 6 / mention 4`、GOOGL（TP 14）`subject 6 / mention 4`、NVDA（TP 15）`subject 6 / mention 4`。**TP 覆盖差 2.1 倍，专题数一模一样。**<br>**真因**：亚洲研究所在**综述类报告**里也照列目标价——实测 Nomura《Morning News & Views - Asia》给三星 `mention_target_price: KRW670,000`，Goldman《The 720》给 `₩490,000`，**都是 mention 级 TP**。美股票的 mention 报告则很少带 TP。 | **不要用 `target_price_coverage` 推断专题密度**，它只说明"有多少篇报告写了数字目标价"（含 mention 级）。<br>要判主/配角**只能钻取看 `subject_report_returned_count`**（r0 层 2）。<br>该字段仍可用于："这只票有多少家给了可比的数字锚"——但须注明含 mention 级 | 实测 2026-08-01（四路对照）<br>request_id：`89742e42…`(榜) / `812dc7db…`(三星) / `6cd57dc4…`(GOOGL) / `ffdd0aa8…`(NVDA) |

### 2026-08-04 query 语言实测（N-69）——全仓 sweep 后的验证轮

> 来源：全仓 N-8 sweep 把数组写法改成 query 串后，对三种"改写时新造、SSOT 无实测记录"的 query 形态做验证。**三种里两种当场失败**，故单独立条。

| # | 现象 | 应对 | 证据 |
|---|---|---|---|
| N-69 | 🔴 **【query 解析家族·主条②】query 里的英文意图词会被当 ticker 劫持，或让整个调用返空——中文意图词则干净**。三组对照实测：<br>① `metrics(query="DXUSD EMA 50")` → `keywords:["EMA"]`，**DXUSD 被整个静默丢弃**，返回的 90 条指标全是 **Emera Inc（EMA，$52-54 加拿大公用事业股）** 的；改 `query="NVDA 均线 指标"` → `keywords:["NVDA"]` 干净，返回 NVDA 全部 9 个指标。<br>② `signal(query="insider trading", asset_type="tradfi")` → `results:{}`、`total:0`、**`status:"ok"` 不报错**；改 `query="内部人交易"` → 正常返回全市场 insider 行（`keywords:null` = 无 ticker 扫描），API/EDU 等。<br>③ `metrics(query="NVDA 历史走势 30 day chart")` → `keywords:["NVDA","DAY"]`，**"day" 被劫持成 Dayforce(DAY)**——NVDA 数据仍返回，但白占一个批量名额（红线 4 上限 5）；去掉英文尾巴改 `query="NVDA 历史走势"` 即干净。<br>📌 与 N-14（`beat`→HeartBeam、`BEAT`）同源，但 N-14 只记了"财报类英文词"，本条证明**这是 query 解析的普遍行为**：任何英文词都可能撞上真实 ticker。 | **query 一律「ticker + 中文意图词」**：`"<T> 均线 指标"` / `"<T> 历史走势"` / `"<T> 财报 分析师评级"`；无 ticker 的全市场扫描用纯中文意图词（`"内部人交易"`）。<br>⛔ 禁止在 query 里放英文指标名/意图词（EMA/RSI/SMA/day/chart/insider/trading/beat/miss…）。<br>✅ **调用后照例核对 `meta.filters_applied.keywords`**——本条三种故障里有两种只能靠它发现（一种丢标的、一种多标的）。<br>💡 副产品：技术指标**一次 fanout 给全部 9 个**（adx/rsi/dema/wma/williams/ema/tema/sma/standarddeviation），红线 8 原"各自单调"是不必要的额度浪费。 | 实测 2026-08-04（6 次对照调用）<br>request_id：`fabbc973…`(EMA劫持) / `86647250…`(中文均线) / `e0df942c…`(insider空) / `ce3cf1dd…`(内部人交易) / `440722c0…`(DAY劫持) |
| N-70 | **`news()` 返回**无 `cluster_id` 字段**（证伪 06 号 Skill 长期记载的 `cluster_id_v2/v3` 多源去重字段）。实测可用字段仅：`title` / `content`(恒 truncated) / `source_url` / `source_name` / `source_quality` / `provenance` / `published_ts` / `category` / `source_lang`，social 桶另加 `kol_info`。 | 多源去重只能按 `source_url` + 标题近似判重，**不存在服务端聚类 id**。任何"按 cluster 去重"的规格都是虚构的 | 实测 2026-08-04（`a1a09a5c…`；同次复核 N-25 成立：`limit=1` 返 2 条 = 1 article + 1 social） |
| N-71 | ➡️ **并入 N-8（数组参数家族·主条）**。原记录：服务端 `no_match` 建议照做必报错（实测 08-04，`28a68c92…`）——根因与修法已并入 N-8 | 见 N-8 | 存根（2026-08-04 归并）|
| N-72 | **`has_more:false` 与 `status:"partial"` 会同时出现，两个字段互相打架——不能用 `has_more` 判完整性**。<br>实测 earnings_calendar（`country=US`，5 天窗口）同一份返回里：`pagination.has_more:false`（没有更多了）+ `status:"partial"` + warning *"country candidate cap 500 reached before full leaf coverage could be proven"*（覆盖完整性未被证明）。仅返回 5 条。<br>⚠️ 另有一处不一致：`country`/`date_from`/`date_to` **确实生效**，但 `meta.filters_applied` **没有回显它们**（只回显 `asset_type`/`keywords`/`query`）——回显不全，靠 warning 兜底 | **判完整性只看 `status`**：`partial` 即不完整，无论 `has_more` 说什么。<br>⛔ 产出措辞不得写「本周全部 X」，只能写「本周 X（服务端提示覆盖不完整）」并转述 warning 原因 | 实测 2026-08-04<br>request_id：`ad0458ae…` |

### 2026-07-29 研报解读实测新增（N-37~N-41）

> 本组是 `Research Reader/` 各支 Skill 的口径地基。**核心结论：MCP 研报侧只开放「一个被连带污染的全量榜 + 每票 10 篇切片」，做不了发现型信号，只能做单标的深度。** 库内四族信号（错位/时钟/信念/水分）建立在状态层全量折叠之上，**搬不到 MCP 侧**——实测只有水分族（TP 离散）能干净地搬。

| 编号 | 内容 | Workaround | 来源 |
|---|---|---|---|
| N-38 ⚠️部分修复 | 🔄 **08-12 第三腿修复：`limit` 死顶变单页顶**——`meta.pagination.next_cursor` 已可翻页枚举完（N-81），「钻取所见是下界」只在未翻页时成立。<br>🆕 **2026-08-04 复验：家数腿的「虚高」证据已消失，但仍只能当上界**。实测 NVDA 7d 榜面 `distinct_institution_count:8` / 28 篇，钻取 10 篇去重见 **5 家**（Goldman/MS/Nomura/Citi/Bernstein）。旧口径 **25→3（8.3 倍）**，新口径 **8→5（1.6 倍）**，差额可由 10 篇硬顶完全解释。⛔ **不能判已修**——硬顶使精确验证在结构上不可能；措辞从「虚高」改为「**钻取所见是下界**」。<br>**`time_range` 腿已于 2026-08-03 修复**（实测 NVDA 不传=subject6/mention4，`7d`=subject0/mention10，`date_from` 正确回显）。**`report_limit:10` 硬顶与机构名不归一两条仍在**（实测榜面 25 家 → 钻取去重仅 3 家）。~~原记：钻取硬顶 `report_limit: 10`，`limit` 与 `time_range` 双双失效~~。`7d`+默认 limit 与 `30d`+`limit=30` 两次调用返回的 `event_id` **完全一致**（恒 6 subject + 4 mention）；后者的 `meta.filters_applied` 里 **`time_range` 连回显都没有**（被整个丢弃）。<br>**叠加两层损耗后真评家数只剩个位数**：NVDA 榜单声称 23 家机构 / 11 家有数字目标价，钻取实际只见 **BofA / MS / Citi 三家**——6 条 subject 按 N-3（机构+标题+日期）去重后**只剩 3 条**。<br>⚠️ **机构名不归一**：同一家出现 `"Morgan Stanley"` 与 `"Morgan Stanley & Co. LLC"` 两种写法；`rating_current` 同样不归一（`"Buy"` / `"BUY"` / `"Attractive"` / `"Overweight; Top Pick"` 混用）。库内有 `institution_alias_v0.json`（12 家）做归一，MCP 侧没有 | **任何"N 家机构"的表述必须标成下界**（"可见的 3 家"而非"3 家"）。机构名先归一再去重，否则同一家会被算成两家。**需要全覆盖的信号（错位/信念族）在 MCP 侧不成立，不要做** | 实测 2026-07-29（两组参数交叉验证）<br>request_id：`555d5409…`(7d/默认) / `be2c7554…`(30d/limit=30) |
| N-39 | ⚠️ **部分修复（2026-08-04）：字段已改名且语义诚实化，但底层性质未变、仍不可当方向引用**。<br>🔄 `direction_counts`/`net_direction` → **`mention_impact{counts:{adverse,beneficiary,mixed,neutral}, dominant}`**（旧名已不存在）。新名**自己说明这是 mention 层影响、不是机构共识**，且每条 mention 现在带 `mention_context{mention_direction, rationale, context_snippet}` 可追溯到原文依据——**误读成本大降，但读法不变：一律不读**。实测同一标的换窗口仍换 `dominant`（NVDA 7d=`neutral` / 07-01→07-15=`beneficiary`）。<br>原始记录：**榜单的方向字段是连带混算的假共识，不可当"机构看多"引用**。实测 NVDA `beneficiary 67 / negative 11 / neutral 40 / other 7` → `net_direction: "positive"`，但这是 **mention 层面**的计数——正踩研报库自己定的**连带红线**（实测现役观点 87% 是连带 rank1，研报点名"受益股"天然带正向，一投方向票每层全染多）。<br>与 N-19（榜单高位 ≠ 有专题报告，GOOGL 排第 2 而 `subject_reports=0`）是同一病根的两个表象 | **方向结论只能用钻取后 `subject_reports[].rating_current` 重算**，且按 N-38 标成下界。榜单的 `net_direction` 只能当"**叙事雷达**"（谁被反复点名），**不能当方向共识** | 实测 2026-07-29 |
| N-40 | **`signal()` 的 kol_call 按 ticker 查，目标 ticker 自己的行可能整个不在返回里**（比 N-5 的"裂成多行"更狠）。实测 `signal(query="NVDA", asset_type="tradfi")` 返回 8 行 kol_call，**无一行 `symbol=="NVDA"`**——全是 IREN / ARM / CRWD / CRWV / INTC / NBIS / ORCL / OSCR。而命中的原帖内容是 `"BUY: - $NVDA - $SOFI …"`，**$NVDA 明明列在 BUY 首位**。只按 `symbol` 字段过滤会得到"该标的零 KOL 观点"的假结论 | **必须回读 `content` 判断目标 ticker 的方向，不能只信 `symbol` 字段**。`symbol` 只表示这一行被归给谁，不表示原帖只讲了它。配合 N-5 按 `source_url` 去重后逐帖读 content | 实测 2026-07-29（request_id `908aadc9…`）|
| N-41 | **`detail.catalysts[].time_std` 可排序但格式不统一，且带无法锚定的哨兵值**。⚠️ **本条已于同日按三标的 60 条样本改写——初版按单标的（NVDA 20 条）写的规则实跑覆盖率仅 77%**。<br>**`sort` 共 10 种形态**（60 条全量）：`YYYY-MM-DD`(22) / `YYYY-MM`(11) / `YYYY`(9) / **`YYYY-MM-DDThh:mm:ss±hh:mm`(4，ISO datetime)** / **`YYYY-QN`(4)** / `YYYY-HN`(3) / **`YYYY-MM-DD+`(2，开区间)** / **`YYYY-MM-DD-<语义后缀>`(2，如 `2026-07-23-upcoming-earnings-call`)** / **`YYYY-FQN`(2，财季≠自然季)** / `YYYYHN`(1，无连字符)。另有 `CY` 前缀变体。<br>⛔ **`"9999"` 哨兵与四位年份形态完全相同**（都是 `YYYY`），**只能按值判不能按形态判**——必须先查 `sort=="9999"` 再做形态匹配。<br>**`type` 共 22 种取值**（不是初版写的 12 种），且**三组同义异写**：`half-year`/`half_year`/`half_year_range` ｜ `event_relative`/`relative_event` ｜ `quarter`/`quarter_range`/`fiscal_quarter`。<br>⛔ **最大的坑是精度降级**：`type` 的语义粒度常**粗于** `sort` 的字面粒度。实测 INTC `sort="2026-09-30" type="quarter"` 与 `sort="2026-10-01" type="quarter"`——**直接读 sort 会渲染成"9 月 30 日""10 月 1 日"，实为"Q3 末/Q4 内某时"**，凭空造出精确度。初版只防了 `type=year` 一种，被 `quarter` 打穿。<br>✅ **正面发现**：`catalysts[].security` **可以 ≠ query ticker**——查 NVDA 顺带拿到 AMD 的竞品事件日；查 INTC 拿到 AAPL 财报日、台积电 N3→N2 迁移、SK 电讯 AI 工厂投产。**一次钻取能收获跨标的催化剂** | 归一按序：①`sort=="9999"` 或缺失 → 待锚定桶 ②剥 `CY` 前缀、尾部 `+`、尾部语义后缀 ③ISO datetime 截到日（时刻可留展示，实测 4 条都是财报电话会准确开始时间，是本数据最精确的一类）④`YYYYHN`→`YYYY-HN` ⑤按形态定基础精度 ⑥**按 `type` 语义向下降级**（year/relative_year→年；quarter/quarter_range/fiscal_quarter→季；half-year/half_year/half_year_range→半年；month→月）。<br>**修正后实测归一成功率 58/60 = 97%**（初版规则为 46/60 = 77%），逐标的 NVDA 19/20、INTC 20/20、GOOGL 19/20；精度分布 日 24 / 月 10 / 季 10 / 半年 5 / 年 9 / 待锚定 2。**自检：待锚定率应 ≈3%，>15% 说明遇到本表未收录的新形态，先补规则再出图**。<br>⚠️ 精度降级实测拦下 **8 条**（`2028-01-01`+year→年、`2026-09-30`+quarter→Q3、`2026-07-01`+half-year→H2 等）——**不降级这 8 条全会被渲染成假的精确日期** | 实测 2026-07-29（初版 NVDA 20 条 → 同日 NVDA+INTC+GOOGL **60 条**交叉验证改写，规格写成脚本实跑复验）|

### 2026-07-29 三标的端到端实跑新增（N-62~N-64）

> 来源：`Research Reader/` 三支 Skill 写完后对 **NVDA / INTC / GOOGL / F** 四个标的做端到端实跑（含把客户端规格写成脚本执行）。本组全部是**规格实跑才暴露、只读字段看不出来**的问题。

| 编号 | 内容 | Workaround | 来源 |
|---|---|---|---|
| N-62 | **N-3 的「机构+标题+日期」去重去不掉「快评 + 完整版」重复**（N-3 的补充，非替代）。同一家机构对同一事件常发两篇：盘后快评 + 次日完整版。**标题不同所以 N-3 三元组不同，去重规则整个失效**，该机构被算成两家。<br>实测 INTC：Goldman Sachs **2026-07-23 两篇同为 TP 150**——《…First Take: Strong quarter across the board…》与《…Strong quarter across the board, with margin upside…》。同日、同机构、同目标价、标题近似但不相同。<br>跨日变体：Citi 07-23《2Q26 Earnings Quick Take: Beat-and-Raise》与 07-24《Transformation in Progress; Maintain Buy》同为 TP 130。 | **追加一道：同机构 + 同日 + 同 TP → 强制合并**（保留信息更全的一篇）。跨日的快评/深度对不强制合并，**按机构取最新一篇**即可自然消解。<br>不做这道：INTC 7 条 subject 会被读成 7 家，实际只有 **5 家** | 实测 2026-07-29（INTC 端到端实跑）|
| N-63 | **`revision_summary.list_changes[]` 字段确实存在**（⚠️ 修正此前"MCP 侧无此字段、停覆信号做不了"的错误断言）。结构：`{action, list, security}`。<br>实测出现两种 `action`：`initiate`（Bernstein 2026-07-27 "Asia Quant + Fundamental Portfolio for 2H26" 组合建仓名单，同一份报告在 NVDA 与 GOOGL 的钻取里都出现）、`add`（J.P. Morgan 把 LIG D&A 加入 Positive Catalyst Watch）。<br>**未见到停止覆盖类 action**（drop/remove/terminate），但字段结构与库内时钟族·停覆信号所依赖的是同一套。 | 表述为「**样本内未出现，机制上可能支持**」，**不要写成"做不了"**。遇到停覆类 action 时按库内时钟族读法处理（"机构不再看它"本身是信号）；**同时不承诺一定能抓到** | 实测 2026-07-29（四标的扫 `list_changes`）|
| N-64 | **`subject_reports` 数量是时点状态，会日间剧变——N-19 的「GOOGL subject=0」不是恒定特性**。<br>实测对照：2026-07-23 GOOGL 榜单第 2、66 篇提及、`subject_reports=0`（N-19 原始记载）；**2026-07-29 复测 GOOGL `subject_reports=6`**（Barclays / Morgan Stanley / Bernstein / Citi×2 / Goldman Sachs）。<br>同日 **F(Ford) 才是 subject=0 的案例**：`report_returned_count=3`（连 10 篇上限都没给满），3 篇全是 mention。<br>另：`report_returned_count` **不保证等于 10**——有货才给。 | **每次当场看返回的 `subject_report_returned_count`，绝不照抄历史结论**。N-19 的判定逻辑（榜单高位≠有专题报告，须查两层比例）仍然成立，**但它举的 GOOGL 例子已过期**。<br>`subject=0` 时降级为 mention 叙事，且 **mention 报告的 `detail.catalysts` / `key_caveat` / `consensus_diff` 照样可用**（实测 F 的两条最硬的基准问题就出自 mention 报告）| 实测 2026-07-29（GOOGL 复测 + F 对照）|

### 2026-07-29 产业链读穿实测新增（N-65~N-67）

> 来源：为 `Research Reader/r4` 做的四标的交叉验证（NVDA / INTC / GOOGL / **2330.TW**）。本组解释**研报里的跨标的关系数据到底能不能用、怎么用**。

| 编号 | 内容 | Workaround | 来源 |
|---|---|---|---|
| N-66 🔄可绕过 | **10 篇单页硬顶是 `subject` 与 `mention` 共享名额——专题覆盖多的"枢纽票"首页拿不到跨标的数据**。🔄 **08-12 起可翻页取到被挤出首页的 mention（N-81），「拿不到」降级为「首页拿不到」**；收窄窗口腾名额从唯一手段降为备选。⚠️ 这条与"查枢纽收割整条链"的直觉完全相反。<br>实测对照：<br>· **2330.TW 台积电**（榜单第 4，70 篇提及 / 17 家机构）→ `subject 10 / mention 0` → 关系边 **0**、跨标的修正 **0**<br>· **INTC**（榜单第 6）→ `subject 7 / mention 3` → 跨标的修正 **16 条**、对手方 **16 个**<br>· NVDA（榜单第 1）→ `subject 6 / mention 4` → 关系边 4、真链修正 6<br>**根因**：跨标的关系数据（`by_name` 跨标的条目、`mention_context`）**几乎只存在于 mention 报告**——实测 30 篇 subject 的 `by_name` 恒为 1 条（标的自己）。专题报告一多，mention 就被挤出 10 篇窗口 | **不要用榜单排名挑标的做产业链分析**——排名越高越可能是"全 subject 零 mention"。**调用后先读 `mention_report_returned_count`**，为 0 时只能从 subject 的 `catalysts` 捞跨标的节点（实测 2330.TW 仅 4 条），并说明是名额被挤占而非该票没有产业链 | 实测 2026-07-29（四标的对照）|
| N-67 | **汇编型报告的 `revision_summary.by_name[]` 是「同框噪音」，不是产业链**。实测查 NVDA 得到 12 条带 `old→new` 的跨标的修正，内容为**印尼棕榈油、印度银行、印度钢铁、印尼制药、韩国船舶**——与英伟达毫无关系，只是同处一份《Asia Morning News and Research Views》。<br>**可用 `subject_name` + `report_type` 判别**：<br>· 🚫 汇编：`subject_name` 含 `morning news`/`portfolio`/`quant`/`weekly`/`daily`/`views`（实测 `"Asia Morning News and Research Views"`、`"Asia Quant + Fundamental Portfolio for 2H26"`）<br>· ✅ 专题：`subject_name` 是具体公司或产业主题（实测 `"Global AI memory strategic partnerships"`、`"Taiwan mature-node foundries and semiconductor design"`、`"Nokia"`）<br>**闸的效果**：NVDA 30 噪音 / 6 真链、GOOGL 17 / 5、**INTC 0 / 16**。不加闸时 NVDA 输出 **83% 是无关名字**。<br>另两条同批发现：①**`by_name` 的 `old_target_price` 覆盖率仅 25/96 = 26%**——只有 new 的是"当前目标价"不是"被改价"，两者必须分开表述；②**`catalysts[].security` 不保证是 ticker**，实测出现板块名 `"AI SEMICONDUCTOR SUPPLY CHAIN"` 与逗号多值 `"373220.KS, 006400.KS"` | 过闸后再用 `by_name`；**`mention_context.rationale` 无论过不过闸都保留**（汇编报告的 rationale 照样是真信息，被丢的只是名单）。关键词表是启发式需持续补充，判别原则：**这份报告有没有统一研究主题**。<br>`security` 清洗：含空格且无 `.` 后缀 → 板块名单列；含 `,` → 拆分 | 实测 2026-07-29（四标的 96 条 by_name 逐条判读）|

**本组的正面发现**：`mention_context.rationale` 质量远高于预期——给的是**机制描述而非标签**，每条都是一条带方向的 A→B 因果边（实测：*"NVIDIA is Nokia's development partner for the O-RAN-compliant AI-RAN platform"*、*"Intel Foundry is seeing improving customer interest because TSMC leading-edge capacity is tight"*）。⚠️ 但**必须读全句**——实测存在自带否定的边：*"Intel is a potential 3nm collaboration partner for UMC, **but Bernstein considers a joint project unlikely**…"*，只读前半句会把否定读成肯定。<br>另一实用副产品：过闸后的 `by_name` 能**顺带白拿链上其他标的的目标价**（实测查 INTC 拿到 NVDA `TP 315` / AVGO `TP 550` / AAPL `TP 350`），但那是**单家读数不是共识**，引用须标出处。

**上一组的正面发现（省额度）**：`metrics(query="<T> analyst ratings price target", asset_type="tradfi")` **一次调用（1 额度）同时返回** `consensus_price`（targetConsensus/High/Low/Median）+ `analyst_grades`（20 行，带 `gradingCompany`/`action`/`newGrade`/`previousGrade`，**这才是可靠的评级动作流，覆盖面远超研报侧的 3 家**）+ `beat_miss` + `eps_trend` + `latest_quarter` + `next_earnings_estimate` + `valuation_block` + `market.snapshot`。跨源印证的**维度1（共识）+ 维度4（基本面）+ 价格腿一次拿全**。<br>⚠️ 但 `consensus_price` 仍无分析师家数字段（N-16 复核成立）；家数改由 `analyst_grades` 按 `gradingCompany` 去重估算并注明是估算（实测 INTC 20 条 grades / **17 家**，覆盖面远超研报侧的 5 家，且能抓到研报窗口外的真动作——Goldman Sachs 2026-06-25 **Sell→Neutral upgrade**）。

**另两条同批实测（附在此处，未单独编号）**：

- ⛔ **`valuation_block.dcf` 在亏损期给出荒谬值，且无任何字段标注失效**。实测 INTC `dcf = 2.95` vs 现价 `86.57`——**差 29 倍**（该季 GAAP 净亏 $110.33 亿，现金流折现模型直接崩）。**自检：`dcf` 偏离现价 >5 倍即判失效**，不进任何输出。
- ⚠️ **N-33 的「同季确认」判据必须用 N-34 的 gap，不能直接比日期**。`beat_miss.date` 是**财报公布日**、`latest_quarter.date` 是**财季结束日**，**两者天然不相等**——朴素比日期会把每个正常样本都判成"不同季"，从而**作废掉本该生效的 N-29 GAAP 错位检测**。正确判据：`gap = beat_miss.date − latest_quarter.date < 90 天 = 同季`。实测 INTC gap = 26 天（07-23 公布 / 06-27 季末）→ 同季，N-29 检测生效并成功抓出 `epsActual 0.42`（非 GAAP，+100%）与 `latest_quarter.eps −2.16`（GAAP 巨亏）的反号错位。

### 研报通道（2026-08-07 立单 → 2026-08-12 复测）

> ⚠️ **本批编号已于 2026-08-12 由 N-70~N-77 改为 N-78~N-85** —— 立单时撞了 2026-08-04 批已占用的 N-70/71/72（cluster_id / 数组参数 / has_more×partial，CHANGELOG 有引用）。
> 本批立单仅 5 天且无仓内外部引用，故让号。**引用本批时用新号。**
>
> 复测结论：**P0 四条 + P1 五条全部已修**（→ 归档区）。
> **P2 三条 dev 未动，产品侧 2026-08-12 决定不修、结案**（N-85 + 下方 crypto / `excluded_counts` 两条另记）——
> 判据：三条的实际消费方都查过，对仓内为零影响或已被现有读法吸收。
> 🔴 **结案 ≠ 行为消失**：三条的规避动作仍然有效，照守；**只是不再作为待修项在复核时上报**。
> 复测新发现的 ticker 解析扩展问题另立 **N-86**（下表首行）。

| ID | 现象 | 调用侧怎么办 | 证据 |
|---|---|---|---|
| N-86 🔴 | **ticker 解析会静默扩展出额外候选，每个候选摊成一个平级结果块，且顺序不保证主匹配在前**。<br>实测 `ASML.AS` → `keywords:["ASML.AS","ASML"]`，**`[0]` 是空块、数据在 `[1]`**；`NOKIA.HE` → `keywords:["NOKIA.HE","HE","NOK"]` 但只有 2 个块（keywords 与块不一一对应），且这次好块在 `[0]`；`2330.TW` → `["2330.TW","TW"]`，而 **`TW` 是可解析的真实标的（Tradeweb）**——独立验证返回 `no_research_reports` 而非 `ticker_unresolved`。<br>不扩展的：`5274.TWO` / `6857.T` / `005930.KS` / `1810.HK`。<br>⚠️ 机制未明：两个假设（「后缀可解析就拆」「恰好 2 字母才拆」）都被实测证伪——`T` 单独可解析但 `6857.T` 不拆；`NOKIA.HE` 多出的 `NOK` 是 ADR 别名不是后缀。<br>⚠️ 扩展本身在干活：`ASML.AS` 库里查不到，是靠扩展出的 `ASML` 才拿到报告的，**不能简单当解析错误** | 🔴 **三条硬规矩**：<br>① **禁止用 `research_reports[0]` 取数**——顺序不保证主匹配在前<br>② **逐块比对 `query_ticker` 与你查的标的，只认相等的块**<br>③ **禁止用 `meta.total` 判条数**——它数的是结果块，扩展时会虚高 | 实测 2026-08-12<br>`e005bd86…`(ASML.AS) / `cc03abdf…`(NOKIA.HE) / `6158d03d…`(2330.TW) / `cd7bbe63…`(TW 独立) / `ba70be87…`(HK 对照) |
| N-85 ⚪ | **【2026-08-12 产品侧决定不修，已接受】行为仍在，规避照守。** 参数校验不一致：`time_range="banana"` ✅ 正确报错（`expected <number><unit> where unit is h\|d\|w\|m\|y`）；`verbosity="compact"` / `"ultra"` ❌ **静默降级成 standard**，无 warning，meta 回显 standard，照扣额度。<br>✅ **合法值已实测确认**：`concise` / `standard` / `detail` 三个都真实生效（`concise` 实测内容确被截断、meta 回显 `"concise"`）。仓内 Skill 用的就是这三个，**当前无踩坑** | `verbosity` 只用 `concise`/`standard`/`detail`。**拼错不会报错**，只会静默返回 standard——单标的 `detail` 实测 65K 字符，拼错可能撑爆上下文而不是报错。按返回体积做流控时以 `meta.verbosity` 回显为准 | 立单 2026-08-07 `ce90a05d…`<br>复测未修 2026-08-12<br>**结案：不修**（仓内只用三个合法值，仅剩拼错时的掩盖风险）|

**同批另记（未单独编号，状态为 2026-08-12 复测后）**

- ✅ **`date_from` + `date_to` 可精确取窗，且独立于 `time_range`**（此前无记录的可用能力）。实测 `date_from=2026-08-01, date_to=2026-08-03` → `eligible_event_count: 48`、`time_scope:"report_date_window"`、榜单顺序整个变（AMZN 第 1）。**按自然周/事件窗取数用这个，比 time_range 精确**。req `af242e96…`
- ✅ **【已修】N-65 `affected_names` 现在有内容了**。`detail.affected_names` 返回 `{items:[{name, ticker, direction, rating, context_snippet}], total, truncated}`；实测 BofA 一篇 `total:17, truncated:true`（截断如实标注）。**产业链名单终于可取**，`revision_summary.by_name[]` / `mention_context` 这两条替代路径不再是唯一选择。复测 2026-08-12 `faf6dc57…`
- ✅ **【已修】`rating_current` 值域问题由新字段 `stance_normalized` 解决**：`positive` / `neutral` / **行业报告给 `null`**（实测 UBS「Constructive industry view」→ null，语义正确）。原始值仍在 `rating_current`。**做评级分布统计直接用 `stance_normalized`，不必自建映射表**。复测 2026-08-12
- ⚪ **【已决不修·2026-08-12】crypto 无研报**：`asset_type="crypto"` 查研报 → `results:{}`、`total:0`、**无 warning**、扣 1 额度。研报通道是 tradfi 专属，**别在 crypto 侧浪费额度**——这条规避照守，但不再作为待修项上报（仓内本就从不在 crypto 侧查研报，零影响）。req `686dab2f…`（08-07）/ `3731e6c5…`（08-12 复测同样）
- ⚪ **【已决不修·2026-08-12】`excluded_counts` 的 key 是复合路径串且随窗口伸缩**：7d 两个 key、累计四个 key。**硬编码 key 读取会在切窗口时静默漏字段**——**按整个对象求和则不受影响**（r0 就是这么读的）。因此结案不修：**读法保持「整体求和、不硬编码 key」即可**。
- 📊 **入榜量会飘，禁止在对外文案写死**：7d 窗口实测 08-06 = 163、08-07 = **126**、08-12 = **168**（滚动窗口，旧报告出窗即掉）；08-01→08-03 = 48；累计 08-07 = 770 → 08-12 = 913。**入榜率约三分之一**（08-12 的 7d：收 168，剔 314 篇只有标题 + 32 篇待入库）。
- 🔴 **榜首标的可能一篇专题报告都没有**（N-19 的极端案例）：08-07 实测 NVDA 7d 排第 1、25 篇提及/6 家机构，钻取 10 篇**全是 mention**，subject 为空。<br>⚠️ 08-12 复测 NVDA 7d 已有 2 篇 subject（高盛 2Q Preview、BofA）——**那是数据变了不是修复**，榜面仍然只给 `mentioned_report_count`、不给 `subject_report_count`。**贴文/文案里「被最多研报写到」必须和「最多机构在研究它」严格区分**。<br>💰 代价已量化：`r0_coverage-radar` 因此对 Top 3 强制预检，每跑一次多烧 3 额度（2 → 5）。<br>✅ **2026-08-12 产品侧决定：不向 dev 提「榜单暴露 `subject_report_count`」，维持现状。** 这 3 额度是**已接受的固定成本，不是待办**——后续复核不必再提。
- ⚠️ **【停更佐证】`out_of_scope` / `ignored_over_page` 两个桶跨期不动**：08-07 与 08-12 的累计榜均为 `70` / `12` 逐位相同，同期 `eligible_event_count` 从 770 涨到 913。**这为 N-61 的「疑似停更」提供了跨期证据**，不要把这两个桶的绝对值说成「本期排除了多少」。

### 🗄️ 已修 / 已作废归档（销案不删条，防回归自查用）

#### 2026-08-12 销案批 · 研报通道 P0/P1 全清（N-78~N-84）

> 立单 2026-08-07（原编号 N-70~N-76，因撞号改为 N-78~N-84）→ **2026-08-12 复测确认全部修复**。
> ⚠️ **这批的旧规避动作已全部作废，继续套用会主动降低产出质量**（例如 N-79 的「mention 层目标价一律不引用」——现在有专门字段了）。

| ID | 原问题 | 验收证据（2026-08-12） |
|---|---|---|
| N-78 ✅ | ticker 解析失败静默 fallback 到全市场榜单，无 warning | `query="ZZZZ research reports"` → `warnings:[{severity:"info", source:"metrics_fundamentals_research_report_most_mentioned", reason:"ticker_unresolved", keyword:"ZZZZ", message:"The requested ticker could not be resolved; aggregate research-report results were returned."}]`。**结构化 reason 码，可机读**。req `6b667b6d…` |
| N-79 ✅ | `mention_reports[].target_price` 是报告主体的价，且 mention 层没有「查询标的自己的价」字段 | **歧义字段 `target_price` 已整体移除**，拆成两个自解释字段：`matched_asset_target_price`（查询标的自己的，无则**显式 null**）+ `report_subject_target_price`（报告主体的）。实测 AMD mention 块 `matched_asset_target_price:null` + `report_subject_target_price:{RIOT $35}`。req `15b75b82…` |
| N-80 ✅ | `dominant:"mixed"` 与 `counts.mixed` 语义碰撞 | 平局值改为 **`"tie"`**。实测累计榜 INTC `counts{adverse:17, beneficiary:35, mixed:4, neutral:35}` → `dominant:"tie"`。req `806b7028…` |
| N-81 ✅ | `limit` 无分层配额、无翻页，分不清「真没有 subject」和「被挤掉」 | **加了游标分页**：`meta.pagination{returned, has_more, next_cursor}`。实测带 cursor 重查 AMD（offset 3→6）返回不同报告，且第二页 `subject 1 / mention 2`——**可枚举，歧义消除**。req `b6785932…`(page1) / `15b75b82…`(page2) |
| N-82 ✅ | `with_numeric_target` 恒等于 `with_text_target`（假分列） | **合并为单字段 `with_target_price`**。实测榜单 item：`target_price_coverage:{"with_target_price":7}`。req `166f9dd7…` |
| N-83 ✅ | 同一 ticker 跨窗口返回不同公司名 | 7d 与累计榜逐条一致（`Alphabet Inc.` / `Amazon.com Inc.` / `NVIDIA Corporation` / `Microsoft Corporation` / `Advanced Micro Devices`）。**按 ticker 聚合的旧规避可以放宽，但仍建议保留**（成本为零）。req `166f9dd7…` / `4acab5ac…` |
| N-84 ✅ | 币种写法同一返回体内打架（`NT$` vs `TWD`） | **`currency` 归一到 ISO，原始写法保留在 `text`**——实测 `{"currency":"TWD", "new":3650, "text":"NT$3,650"}`、`{"currency":"KRW", "new":490000}`。修法比工单建议的更好（既归一又不丢原文）。req `6158d03d…` / `2dde95c5…` |
| N-65 ✅ | `detail.affected_names` 有计数、永远没有内容（07-29 实测 30/30 篇全缺；Nomura 31 个名单、Bernstein 26 个全取不到）| 现返回 `{items:[{name, ticker, direction, rating, context_snippet}], total, truncated}`。实测 BofA 一篇 `total:17, truncated:true`——**截断如实标注**。产业链名单可取，`revision_summary.by_name[]`/`mention_context` 降为补充面而非替代面。req `faf6dc57…`<br>原条目自 2026-07-29 活跃区移入（销案不删条）|

**这批修复里值得记一笔的三个做法**（以后提工单可以直接引用为范例）：
① N-79 用**改名**消除歧义，而不是加注释；② N-84 **归一字段 + 原值另存**，两边都不牺牲；③ N-65 的 `affected_names` 补 `truncated` 标志，**截断如实告知**而不是静默截断。

> 下列条目的问题**已被 dev 修复或已被后续条目取代**，从正文移到这里。ID 永久保留（全仓 `见 N-xx` 引用仍可检索）；**回归自查时按各条目内的验收证据复测**。

| 编号 | 内容 | Workaround | 来源 |
|---|---|---|---|
| N-2 | ~~earnings calendar 市场级可用（query+date_from/to），但返回全球交易所混排、无市值字段~~ **❌ 2026-07-27 作废，以 N-22 为准**："市场级可用"的定性是错的——服务端 `ORDER BY date, symbol LIMIT 50` 且不尊重 limit，任何跨天/全市场用途都只能拿到极小的字母前段切片。**过滤规则（无后缀 symbol + revenueEstimated 初筛 + 二次补市值）本身仍有效，但过滤的输入集从一开始就是残缺的** | **见 N-22**：不可作发现腿，不可作"某日/某周全部财报"对外发布 | 实测 2026-07-22 · **2026-07-27 推翻定性** |
| N-11 | ~~指数类 ^GSPC ^IXIC ^DJI ^VIX 可用；^DXY/CLUSD/NGUSD 为 402 Special Endpoint 禁调——与红线 6 的 CLUSD 记载冲突，实现时复核后统一 SSOT~~ **✅ 2026-07-27 复核结案，见 N-30**：CLUSD 现象已非 402 而是 `no_match` 返 0 结果 | 指数白名单 ^GSPC ^IXIC ^DJI ^VIX 可用；**原油相关一律见 N-30** | trend-scout 实测 · **2026-07-27 复核结案** |
| N-17 | 财报日历漏掉当天美股大票：实测 2026-07-23 当日 30 条全被印度/欧洲/OTC 小票占满，而 AAL 的 `next_earnings_estimate.date` 明确是当天，日历却无此股 | limit≥100 + 客户端只留无后缀美股 symbol 并剔优先股(-P) + 对重点标的用 `next_earnings_estimate.date` 交叉验证；名单不全时如实标注 | 实测（2026-07-23 实跑） |
| N-31 | **7 个 v2 Skill 的 `keywords=[...]` 写法全域失效**（N-8 的影响面盘点）：`~/.claude/commands/` 下 08/09/10/11/12/13/14 共 **107 处** `keywords=[...]` 调用示例，按 N-8 全部会被 schema 拒（`-32602`）。模型实跑时会撞错一次再自行改写成 query 串，属"可恢复但每次白烧一次失败调用"| 正确替代形态实测确认：FRED 指标 `query="DGS10"`（服务端正确回填 `keywords:["DGS10"]` 并返数据）；行情 `query="<T1> <T2> ... 行情"`（≤5 个）。**尚未 sweep，待专项处理** | 实测 2026-07-27（keywords 数组复现被拒 + query 替代形态验证） |
| N-61 ✅已修 | ✅ **2026-08-04 实测销案**：桶现在跟随窗口。7d 窗口只返回 `report_title_only.*` 两桶；改传 `date_from=2026-07-01/date_to=2026-07-15` 后**四桶齐全**（`report_ignored.out_of_scope.ignored:54`、`report_ignored.ignored_over_page.ignored:7`）→ 原「12 天不变」的根因是**桶当时不随窗口过滤**，不是管线停更。<br>原始记录：**`excluded_counts` 里有两个桶疑似停更——12 天一个数没变**。跨日对照（同为不传 time_range 的榜单调用）：<br>· `report_ignored.out_of_scope` **恒 70**（07-20 = 08-01）<br>· `report_ignored.ignored_over_page` **恒 12**（07-20 = 08-01）<br>而同期其余三项全在剧烈变动：`eligible_event_count` **299 → 650**（+117%）、`report_title_only.outer` **457 → 1265**（+177%）、`report_title_only.registry_pending` **323 → 118**（**−63%，唯一下降项**）。<br>两个"ignored"桶在总量翻倍时纹丝不动，要么是静态阈值/一次性标注，要么是没有随新批次更新。 | **引用"入榜率"时须注明分母含两个疑似停更的桶**（实测 08-01：650/2115 ≈ 30.7%，其中 82 条来自这两个桶）。<br>不要把 `out_of_scope` / `ignored_over_page` 的绝对值当作"本期被排除了多少"——它更像累计标记或固定值。<br>`registry_pending` 的下降是**正常现象**（待入册的被处理成 title_only 或 eligible），可当管线在推进的信号 | 实测 2026-07-20 vs 2026-08-01 跨日对照<br>request_id：`00de5ec5…`(07-20) / `89742e42…`(08-01) |
| N-37 ✅ | **【2026-08-03 已修复销案】** ~~研报榜 `time_range` 完全无效——它是全量累计榜，不是时间窗榜**。`24h` / `3d` / `7d` 三次调用返回**逐字相同**：NVDA 恒 125 篇 / 23 家机构，`eligible_event_count` 恒 530，`scope` 恒 `"all_batches"`。`meta.filters_applied.time_range` 有回显（24h/3d/7d 各不同）但**对结果零影响**——典型的"参数被接受但被忽略"。<br>⚠️ **由此产生的对外表述错误**：任何把该榜说成"本周/近 7 天研报热议榜"的文案都是错的，它是**建库以来累计**。 | 榜单只能表述为"研报库累计提及最多"，**禁止加任何时间窗定语**。需要时间窗必须钻取后按 `report_date` 客户端过滤 | 实测 2026-07-29（三档窗口交叉验证）<br>request_id：`63ef9e99…`(7d) / `a6b2a68b…`(3d) / `2e682924…`(24h) |
| N-37·状态 ✅ | **【已闭环】** 2026-08-01 报 Dev → **2026-08-03 复测确认修复**。<br>**验收证据**：同日 `24h`(08-02→08-03, eligible **0**) / `7d`(07-27→08-03, **170**) / `14d`(07-20→08-03, **333**) / `30d`(07-04→08-03, **622**) / 不传(**677**) —— 五档全不同；新增 `time_scope`、`date_from`、`date_to`、`window_granularity` 四个透明字段（`report_date_window` vs `all_available_reports`）。**实现比工单建议的更完整。**<br>**回改已完成**：r0 升 **v2.0**（默认窗口改 7d + 主/配角改为「标的×窗口」函数 + 层2 强制）· Research Reader README 边界① · 本文 N-37/37a/37b/38 · c3_research-hot | ⚠️ **N-38 只修了 time_range 腿**，`report_limit:10` 硬顶与机构名不归一仍在 | 闭环 2026-08-03 |
| N-37a ✅ | **【随 N-37 销案】** ~~N-37 的跨日独立佐证：榜面数字单调增长，从不回落**。同窗口（不传 `time_range`）两次跑动对照：<br>· **2026-07-20**：NVDA 榜首 **66 篇 / 20 家**，`eligible_event_count` **299**（req `00de5ec5…`）<br>· **2026-07-29**：NVDA 榜首 **125 篇 / 23 家**，`eligible_event_count` **530**（N-37 原始记载）<br>**9 天内点名数 +89%、入榜基数 +77%,且无任何回落**——若是滚动时间窗榜，旧报告出窗时数字必然下降。这是"累计榜"比"三档窗口返回相同"更直观的证据。<br>另记同次实测的 `excluded_counts`（2026-07-20）：`title_only 457` / `registry_pending 323` / `out_of_scope 70` / `ignored_over_page 12` → **入榜率仅 299/1162 ≈ 26%** | ① **禁止跨日比较榜面绝对值**（"NVDA 这周被提及次数翻倍了"是错的，那是累计量增长），只能比**名次结构**变化。<br>② 对外须说明榜单只覆盖**已结构化的那部分研报**（入榜率约 26%），不是全市场卖方覆盖度 | 实测 2026-07-20 + 2026-07-29 跨日对照<br>request_id：`00de5ec5…`(07-20 榜单) |
| N-37b ✅ | **【随 N-37 销案，2026-08-03 复测 status 正常】** ~~传 `time_range` 不只是无效，还会把 `status` 降级成 `partial`——而且 warning 来自一个跟研报完全无关的子系统**。实测 `time_range="30d"` 那次返回 `status:"partial"`，degraded 警告的 `source` 是 **`metrics_macro_fmp_calendar_fuzzy`**（宏观经济日历的模糊匹配腿），message 为 `"could not fully enforce time_range: candidate cap reached"`。<br>同一批的 `24h` 与不传两次都是 `status:"ok"`。<br>⚠️ **排障陷阱**：看到 partial + 这条 warning 会以为研报路径出了问题，实际是 fanout 到宏观日历那条腿的噪音，**跟榜单结果无关**（三次返回的 items 逐字相同）。 | **这给「不传 `time_range`」多了一条硬理由**：传了不但控不住窗口，还污染状态位、引入误导性 warning。<br>若在别处看到 `metrics_macro_fmp_calendar_fuzzy` 的 partial，先确认本次调用是不是根本不需要宏观腿 | 实测 2026-08-01（r0 首跑）<br>request_id：`7e0aece4…`(30d/partial) / `5396593d…`(24h/ok) / `89742e42…`(不传/ok) |

## 附表 A：中英文 → FRED series_id 翻译表

> 红线 3 的配套字典（原宿主 07_macro-analyzer 已删，表迁至此）。用法：用户说指标名 → 查本表转 series_id → `metrics(query="<series_id>", limit=N)` 直查（⚠️ 2026-08-04 按 N-8 改写，原 keywords 数组形态已被 schema 拒；query 只放纯 series_id，禁中文/混合语言）。字典未命中才回退 query 兜底并人工 review 命中的 series。

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
| WTI 原油 | `USO` | ⚠️ **N-30 结案（2026-07-30 复测仍成立）**：~~`CLUSD`~~ 返 0、~~`BZUSD`~~ 在 query 里被静默丢弃、~~`OIL`~~ alias 错抓 iPath ETN——只 `USO` 可用（WTI 近月期货 ETF，**代理指标非现货价**，引用须说明口径）。market 类，非 FRED。旧「N-11 402／优先 BZUSD」记载已作废 |
| 黄金期货 | `GCUSD` | ⚠️ 不是 GOLD（会错抓 Gold.com 美股）。market 类，非 FRED |

> 📋 **生产 skill 侧的 caveat 审计状态**（每条坑对每个 skill 审过/修过没、上次审到 N 几）记在本机 `~/.claude/skills/_shared/followin-caveat-audit.md`——本文件是 caveat 定义的 SSOT，那份是"落地覆盖"的 SSOT，两者配套。
