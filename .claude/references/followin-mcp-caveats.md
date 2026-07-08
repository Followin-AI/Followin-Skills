# Followin MCP 调用规范 + 已知问题登记（Skills v2 共享 SSOT）

> 7 个 v2 Skill（08/09/10/11/12/13/14）共享的调用红线与已知问题单一事实源。
> 各 Skill 内联的 caveat 是本文件的本地镜像，**如有冲突以本文件为准**。
> 维护纪律：MCP 行为每次变更 → 先改本文件 → 再 sweep 7 个 Skill 的内联镜像。

## 调用红线（全 Skill 通用）

1. **asset_type 必须显式**：美股/大宗 `asset_type="tradfi"`，加密 `asset_type="crypto"`。不带会 fanout 双返污染（实测 BTC→美股 BTC Inc $33；AMN/WEST→crypto 山寨币 0.005 USDT）。**唯一例外：`news()` 不要传 asset_type**（is_tradfi 字段几乎全 false 老 bug，加 tradfi 返 0 results——0 篇不报错，比报错更危险）。
2. **SSE 并发 ≤4**：单批 ≤4 路 MCP 并行，超了 session 可能挂。
3. **FRED macro 走 keywords 直查**：`keywords=["<series_id>"]` + `categories=["macro"]`。禁止 query 中文/混合自然语言（4 类语义陷阱：含 series_id 也被错抓 / 中文混淆 / degraded / 静默兜底）。中英文 → series_id 翻译表见 Skill 12。
4. **B-31 边界**：FRED macro series **不要批量**（静默丢条目），各自单独 fire；market 行情快照可批量但**上限 10 个 keywords**（实测 2026-06-12：传 18 个被静默截断到 10，`meta.warnings` 有 `keyword_count_over_max` 提示——必须检查该 warning，超出分批）。不要在同一次调用里混 market ticker 和 FRED series。
5. **news() query 三原则**：2-3 个核心名词；纯中文或纯英文不混搭；不写"影响/解读/分析/impact"等元词（embedding 过拟合 0 results）。单符号会被同名公司劫持（"CPI"→CPI Card PMTS），用双词消歧。news 无 sort_by 参数（相关性走 search_depth，默认 standard）。
6. **商品 ticker**：黄金 `GCUSD`（GOLD 错抓 Gold.com 美股 $42）；白银 `SIUSD`；原油 `CLUSD`（WTI）/ `BZUSD`（布油）；**不要用 GOLD/SILVER/OIL alias**。
7. **fundamentals comprehensive 必须显式 `query="全面分析"`**（或 `"comprehensive analysis"` 精确双词）：不带 query 走 default 只返 5 block；带 query 返 14 block（仅缺 stock_peers）。`query="comprehensive"` 单词无效。
8. **历史 OHLCV / 技术指标各自单调**：历史必须 `query="历史走势 30 day chart"` + `time_range`；RSI/EMA/SMA 用 `query="RSI 14"` / `"EMA 50"` / `"SMA 200"` 单独调，不要靠默认 fanout（撞错路径无 fallback）。历史路径支持多 ticker 批量（实测 2026-06-12：3 ticker × limit 各自完整返回，无丢条；~20 个上限未实测）。
9. **mover 榜**（`query="biggest gainers"/"biggest losers"`）只返 7 字段、无 marketCap；**不要传 `min_market_cap`**（上游 null 会被全屠）；keywords 二次调用补市值；客户端过滤微盘妖股 / 仙股 <$5 / 杠杆 ETF（name 含 2X/3X/Long/Short/Bull/Bear/Daily/Leveraged）。movers 仅美股，无 crypto 榜。
10. **经济日历**：`metrics(keywords=["economic calendar"], categories=["macro"])`。query 别带"本周"——实测（2026-06-12）"本周"被解析成 lookback 7 天，返回**已发布历史**而非前瞻日历。
11. **news() 无匹配时不返回空，返回语义兜底的不相关内容**（实测 2026-06-12：查 Quhuo/Navios 返回的是 BoJ/伊朗等宏观新闻填充）。**所有"报道 ≤ N"类判定必须按 LLM 逐条判断后的相关报道数计数，不能用 raw count**——否则填充内容会把"无声异动"误判成"有报道"。

## 已知问题登记（含 Dev 修复后回滚指引）

| 编号 | 症状 | 状态 | Workaround | Dev 修复后回滚动作 |
|---|---|---|---|---|
| B-18 | `keywords=["BTC"]` 不带 asset_type 时 fanout 到美股 BTC Inc（$33）污染 | Dev 待修 | 必传 `asset_type="crypto"` | 保留（显式总是更稳）|
| B-31 | FRED macro 批量 keywords 静默丢条目（如 BAMLH0A0HYM2 被丢）| Dev 待修 | series 单独 fire | 恢复批量（省调用数）|
| B-33 | BAMLH0A0HYM2 不在 FRED 字典，keywords 直查被错抓到 M2SL；CPIMEDSL 同类（被错抓 headline CPI）| Dev 待修 | 09 ⑦ 信用利差标"不可用"+ 权重重分配；11 Healthcare 退用 CPIAUCSL | 09 Batch 1 恢复调用 + ⑦ 恢复 5% 权重；11 Healthcare 换回 CPIMEDSL |
| — | news() 传 asset_type 返 0 results（is_tradfi 几乎全 false）| Dev 待修 | news 一律不传 asset_type | 各 Skill news 调用恢复 asset_type 过滤（防 crypto 混入）|
| — | fundamentals comprehensive 缺 stock_peers | 已上报 | 输出"同行"部分标数据不可用 | 恢复 peers 展示 |
| — | OIL/GOLD/SILVER alias 错路由 | Dev 待修 | 用 CLUSD/BZUSD/GCUSD/SIUSD 具体 ticker | 可继续用具体 ticker（无需回滚）|
| — | insider 全量扫描聚簇（同公司多笔 filing 连排；2026-06-12 实测 SPCX Form 3 占 50 条中 13 条）| 数据特性 | `limit=50` + `sort_by="amount"` + 客户端按 ticker 去重 + 只留 formType="4" 的 P-Purchase | —（数据特性，非 bug）|
| — | 经济日历 query 带"本周"触发 lookback 返历史 | 行为特性 | 用 keywords 形式（红线 10）| —（语义解析特性）|

> 完整 bug 复现记录见 Obsidian《FollowX MCP - Skill v2 烟雾测试 Bug Report - 2026-06-01》（已提交 dev）。
