# Followin MCP 调用规范 + 已知问题登记（Skills v2 共享 SSOT）

> 7 个 v2 Skill（08/09/10/11/12/13/14）共享的调用红线与已知问题单一事实源。
> 各 Skill 内联的 caveat 是本文件的本地镜像，**如有冲突以本文件为准**。
> 维护纪律：MCP 行为每次变更 → 先改本文件 → 再 sweep 7 个 Skill 的内联镜像。

## 调用红线（全 Skill 通用）

1. **asset_type 必须显式**：美股/大宗 `asset_type="tradfi"`，加密 `asset_type="crypto"`。不带会 fanout 双返污染（实测 BTC→美股 BTC Inc $33；AMN/WEST→crypto 山寨币 0.005 USDT）。**唯一例外：`news()` 不要传 asset_type**（is_tradfi 字段几乎全 false 老 bug，加 tradfi 返 0 results——0 篇不报错，比报错更危险）。例外扩展（2026-07-22 实测）：news 趋势模式（空 query）传 asset_type="tradfi" 可用且 quota=0；实体搜索亦 quota=0。"不传 asset_type"仅约束搜索模式的过滤语义。
2. **SSE 并发 ≤4**：单批 ≤4 路 MCP 并行，超了 session 可能挂。
3. **FRED macro 走 keywords 直查**：`keywords=["<series_id>"]` + `categories=["macro"]`。禁止 query 中文/混合自然语言（4 类语义陷阱：含 series_id 也被错抓 / 中文混淆 / degraded / 静默兜底）。中英文 → series_id 翻译表见 Skill 12。
4. **B-31 边界**：FRED macro series **不要批量**（静默丢条目），各自单独 fire；market 行情快照可批量但**上限 10 个 keywords**（实测 2026-06-12：传 18 个被静默截断到 10，`meta.warnings` 有 `keyword_count_over_max` 提示——必须检查该 warning，超出分批）。不要在同一次调用里混 market ticker 和 FRED series。
5. **news() query 三原则**：2-3 个核心名词；纯中文或纯英文不混搭；不写"影响/解读/分析/impact"等元词（embedding 过拟合 0 results）。单符号会被同名公司劫持（"CPI"→CPI Card PMTS），用双词消歧。news 无 sort_by 参数（相关性走 search_depth，默认 standard）。
6. **商品 ticker**：黄金 `GCUSD`（GOLD 错抓 Gold.com 美股 $42）；白银 `SIUSD`；原油 `CLUSD`（WTI）/ `BZUSD`（布油）；**不要用 GOLD/SILVER/OIL alias**。⚠️ CLUSD 被 trend-scout 2026-07 实测 402 Special Endpoint；原油优先 BZUSD/USO，CLUSD 待复核（N-11）。
7. **fundamentals comprehensive 必须显式 `query="全面分析"`**（或 `"comprehensive analysis"` 精确双词）：不带 query 走 default 只返 5 block；带 query 返 14 block（仅缺 stock_peers）。`query="comprehensive"` 单词无效。
8. **历史 OHLCV / 技术指标各自单调**：历史必须 `query="历史走势 30 day chart"` + `time_range`；RSI/EMA/SMA 用 `query="RSI 14"` / `"EMA 50"` / `"SMA 200"` 单独调，不要靠默认 fanout（撞错路径无 fallback）。历史路径支持多 ticker 批量（实测 2026-06-12：3 ticker × limit 各自完整返回，无丢条；~20 个上限未实测）。
9. **mover 榜**：biggest gainers/losers 上游缺 marketCap 且全是仙股（trend-scout v1.8.0 实测）——弃用；改 `query="most active stocks"`，但实测（2026-07-22 2026-07-22 回归）board 行亦不带 marketCap（trend-scout 旧版记载已失效）——候选 ticker 需二次批量快照补市值后再过滤：marketCap ≥$1B + 剔杠杆 ETF（name 含 2X/3X/Long/Short/Bull/Bear/Daily/Leveraged）+ 仙股 <$5。movers 仅美股。
10. **经济日历**：`metrics(keywords=["economic calendar"], categories=["macro"])`。query 别带"本周"——实测（2026-06-12）"本周"被解析成 lookback 7 天，返回**已发布历史**而非前瞻日历。
11. **news() 无匹配时不返回空，返回语义兜底的不相关内容**（实测 2026-06-12：查 Quhuo/Navios 返回的是 BoJ/伊朗等宏观新闻填充）。**所有"报道 ≤ N"类判定必须按 LLM 逐条判断后的相关报道数计数，不能用 raw count**——否则填充内容会把"无声异动"误判成"有报道"。
12. **研报查询 query 必须含研报意图词**（"research reports" / "研报"等）：实测（2026-07-15）query 只放报告标题（如 `query="Can semi cap work if memory doesn't"` + keywords=["MU"]）**不会路由到 research-report 路径**，掉进 CORE fundamentals 默认全家桶（三表/估值/profile），且照常计 1 次额度。**钻取指定报告的正确姿势 = 保持 `query="research reports"` + `verbosity="detail"` 重查，客户端从结果挑目标报告**；无按 event_id/标题取单份的入参。返回分 `subject_reports`（主题报告）与 `mention_reports`（提及报告）两层。

## 已知问题登记（含 Dev 修复后回滚指引）

| 编号 | 症状 | 状态 | Workaround | Dev 修复后回滚动作 |
|---|---|---|---|---|
| B-18 | `keywords=["BTC"]` 不带 asset_type 时 fanout 到美股 BTC Inc（$33）污染 | Dev 待修 | 必传 `asset_type="crypto"` | 保留（显式总是更稳）|
| B-31 | FRED macro 批量 keywords 静默丢条目（如 BAMLH0A0HYM2 被丢）| Dev 待修 | series 单独 fire | 恢复批量（省调用数）|
| B-33 | BAMLH0A0HYM2 不在 FRED 字典，keywords 直查被错抓到 M2SL；CPIMEDSL 同类（被错抓 headline CPI）| Dev 待修 | 09 ⑦ 信用利差标"不可用"+ 权重重分配；11 Healthcare 退用 CPIAUCSL | 09 Batch 1 恢复调用 + ⑦ 恢复 5% 权重；11 Healthcare 换回 CPIMEDSL |
| — | news() 传 asset_type 返 0 results（is_tradfi 几乎全 false）| Dev 待修 | news 一律不传 asset_type | 各 Skill news 调用恢复 asset_type 过滤（防 crypto 混入）|
| — | fundamentals comprehensive 缺 stock_peers | 已上报 | 输出"同行"部分标数据不可用 | 恢复 peers 展示 |
| — | OIL/GOLD/SILVER alias 错路由 | Dev 待修 | 用 CLUSD/BZUSD/GCUSD/SIUSD 具体 ticker | 可继续用具体 ticker（无需回滚）|
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
| N-4 | signal 不带 categories 默认 fanout 全 4 类且只计 1 额度（省额度利器）；kol_call tradfi 聚合原生可用（top_calls 多空计数） | 不带 categories 时走 fanout 全 4 类、只计 1 额度 | 实测 2026-07-22 |
| N-5 | kol_call 原帖按提及 fanout 成多行（同 URL 不同 symbol/方向）；按 source_url 去重、symbol 字段归属 | 按 source_url 去重/symbol 归属 | 实测 2026-07-22 |
| N-6 | insider/congress 行无视 time_range（7d 返回 2020 年记录）；客户端按 transactionDate 过滤强制 | 客户端按 transactionDate 过滤强制 | 实测 2026-07-22 |
| N-7 | 13F institutional 申报季中期 investorsHolding 环比为残缺假信号（实测 NVDA 6234→1441）；申报季内禁止引用环比 | 申报季禁引环比 | 实测 2026-07-22 |
| N-8 | keywords/categories/sources 数组参数 2026-07-20 起全域被序列化成字符串遭 schema 拒；统一走 query 串，服务端自解析（meta.filters_applied.keywords 可验证） | query 串替代；Dev 修复后回退 | trend-scout v1.11.x + 2026-07-22 复现（N-8）|
| N-9 | biggest gainers/losers 上游缺 marketCap 且全是仙股，禁用；改 `query="most active stocks"`，但实测（2026-07-22 2026-07-22 回归）board 行亦不带 marketCap（trend-scout 旧版记载已失效），需二次批量快照补市值后过滤；红线 9 的过滤清单继续沿用 | 改 query="most active stocks"；客户端 marketCap ≥$1B 过滤 + 剔杠杆 ETF + 仙股 <$5 | trend-scout 实测（N-9）＋2026-07-22 回归修正 |
| N-10 | metrics time_range <1d 返一个月前旧数据 bug；小时级用 interval 参数或只用实时快照 | 小时级用 interval/实时快照 | trend-scout 实测（N-10）|
| N-11 | 指数类 ^GSPC ^IXIC ^DJI ^VIX 可用；^DXY/CLUSD/NGUSD 为 402 Special Endpoint 禁调——与红线 6 的 CLUSD 记载冲突，实现时复核后统一 SSOT | 指数白名单 ^GSPC ^IXIC ^DJI ^VIX 可用；^DXY/CLUSD/NGUSD 402 | trend-scout 实测（N-11）|
| N-12 | query 串批量会静默丢弃部分 ticker（实测 2026-07-22：9 个 ticker 空格拼串仅解析出 5 个，ONDS 连续两次被跳过且无任何 warning） | 批量调用后必须核对 `meta.filters_applied.keywords` 与请求清单一致，缺失者单独补调 | 实测（2026-07-22 回归） |
| N-13 | signal consensus 聚合疑似对 time_range 不敏感（3d 与 24h 共四次调用返回 total_posts/多空比/榜单完全一致；可能数据池小到收敛，证据不足定性） | 对外表述窗口用词保守（"近幾日"而非精确小时数）；后续以 3d vs 30d 大窗口差异复验 | 实测（2026-07-22 回归，待复验） |
| N-14 | query 串里的普通英文词会被当 ticker 抽取：实测 `query="GOOGL earnings beat miss analyst ratings"` 解析出 `keywords=["GOOGL","BEAT"]`，把仙股 HeartBeam(BEAT,$0.55) 行情混入快照 | query 只放 ticker + 中文意图词（如 `"GOOGL 财报 分析师评级"`）；禁用 beat/miss/hold/buy/now/all 等会撞 ticker 的英文词；调用后核对 `meta.filters_applied.keywords` | 实测（2026-07-23 GOOGL 财报夜实跑） |
| N-15 | 财报当晚 `fundamentals.beat_miss` 仍是上一季数据（实测 GOOGL 7/22 盘后发 Q2，当晚返回的仍是 4/29 Q1），FMP 侧延后更新 | 当晚"实际 vs 预期"一律取 `news()` 媒体/披露原文（0 额度），metrics 只用于盘后快照与目标价；次日后才可用 beat_miss 复核 | 实测（2026-07-23 GOOGL 财报夜实跑） |
| N-16 | `consensus_price` 无分析师家数字段（仅 targetConsensus/High/Low/Median），而 c3/c6 规则要求"目标价必带家数+分歧幅度" | 家数不可得时明确标注"家数未提供"，只给区间+中位；需要家数时改由 `analyst_grades` 近 N 条按机构去重估算并注明是估算 | 实测（2026-07-23） |
| N-17 | 财报日历漏掉当天美股大票：实测 2026-07-23 当日 30 条全被印度/欧洲/OTC 小票占满，而 AAL 的 `next_earnings_estimate.date` 明确是当天，日历却无此股 | limit≥100 + 客户端只留无后缀美股 symbol 并剔优先股(-P) + 对重点标的用 `next_earnings_estimate.date` 交叉验证；名单不全时如实标注 | 实测（2026-07-23 实跑） |
| N-18 | 指数 query 串产生重复行：`"^GSPC ^IXIC ^DJI ^VIX"` 解析出 5 个 keywords（多一个裸 VIX），^VIX 返回两条相同行 | 客户端按 symbol 去重后再引用 | 实测（2026-07-23） |
| N-19 | 研报榜排名基于 mention count，钻取时可能 `subject_reports=0` 只有 `mention_reports`（实测 GOOGL 榜单第 2、66 篇提及，但主题报告为 0，4 篇全是行业报告里的提及） | 榜单高位≠有专题报告；钻取后必须检查 subject/mention 两层比例，只有 mention 时贴文须写明"是被行业报告提及，不是专题研究" | 实测（2026-07-23） |

