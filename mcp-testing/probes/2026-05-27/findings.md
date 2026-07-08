# Followin MCP 能力探针 — 2026-05-27

环境：Claude Code · followin MCP `/v2/sse` · today=2026-05-27

## 一、能力确认（works as advertised）

| 能力 | 实测结果 |
|---|---|
| `metrics` 基础行情（quote） | ✅ M/S/AI/LITE/CRCL/ORCL/MU/BABA 都返回真实 tradfi quote（FMP batch_quote） |
| `metrics` fundamentals 真聚合 | ✅ next_earnings_estimate / beat_miss / consensus_price / eps_trend / latest_quarter / profile_block 一次拿全 |
| `metrics` macro (FRED) | ✅ VIXCLS / DGS10 / FEDFUNDS / M2SL / DFII10 / T10YIE 全部回填 |
| `metrics` 经济日历 | ✅ keywords=["earnings_calendar"]+macro 走 `metrics_macro_calendar`，但返回的是**宏观日历**（ISM PMI / Bill Auction），**不含财报日历** |
| `signal` insider 三源 fanout | ✅ 单次调用同时返回 `_source: corporate_insider` (Form 4) + `_source: congress _chamber: house` (Pelosi PTR) |
| `signal` kol_call + trader_position | ✅ 实时仓位（梭教授 SNDK x5 / pension-usdt.eth ETH 空头变动）+ KOL 看多看空文本 |
| `news` TG 分类 | ✅ 每条带 `_tg_category` 字段：资讯聚合 / 项目研究 / 交易信号 / 链上数据 / 实盘跟踪（实测看到 5 类） |
| `twitter` trends | ✅ woeid=1 worldwide trends 30 条 |

---

## 二、确认存在的 Bug / 限制（按严重度）

### 🔴 P0 — 影响核心 Skill

**B-01 `min_market_cap` filter 直接 0 结果**  
- repro: `sort_by=change_pct, asset_type=tradfi, min_market_cap=10_000_000_000`  
- 上游 mover 端点不返回 marketCap 字段 → 过滤器把 50 行全砍掉  
- 提示文："MinMarketCap=10000000000 filter excluded all 50 gainers rows (check upstream marketCap field)"  
- 影响 **Skill 03 背离扫描** 的过滤逻辑

**B-02 大批量 detail verbosity 直接撑爆 token 上限**  
- repro: keywords=15 张大票 × verbosity=detail × query="全面分析" → **744,008 chars**，超出工具结果上限  
- 影响 **Skill 01 21-Agent 全面分析**（典型场景就是一次拉 N 个对比）  
- 缓解：客户端必须降级为 concise / 分批，但工具本身无 streaming，也无"按 token 预算自动裁剪"

### 🟠 P1 — 用户体感差

**B-03 NEXT 被误判为 crypto**  
- NEXT 是英国大票（NEXT plc，伦敦零售），但 fundamentals 路径直接返回  
  `{"reason":"fundamentals only for stock / etf","asset_kind":"crypto","symbol":"NEXT"}`  
- 上次报修的 M/S/AI/MDB/LITE/CRCL/ORCL/MU/BABA 全部已修复（不带 asset_type 时正确返回美股）

**B-04 asset_type=tradfi 时 warning 自相矛盾**  
- 用户传 `asset_type=tradfi, keywords=["SOL","ETH"]`  
- 系统**确实**返回了 tradfi 匹配（SOL=Emeren Group 美股 / ETH=Grayscale ETF）  
- 同时却报警 "excluded keywords [SOL(crypto),ETH(crypto)]"  
- → Agent 看到 warning 会以为查询失败，但其实数据已经在 results 里

**B-05 keywords 重复同义词浪费配额**  
- 传 ["VIX","VIXCLS","^VIX"] 三个别名 → 全部 resolve 到同一 VIXCLS series，返回 3×10 行重复数据  
- 应该 dedupe 后只返回一次

**B-06 news 无匹配查询 → 静默返回 trending 兜底**  
- query="obscure_nonexistent_xyz12345_query" → 返回 5 条 WSJ/CNBC 大头条（French CPI、ECB warning 等），不带任何 "no_match" 标记  
- Agent 无法识别"没搜到，给了通用兜底"  
- 影响所有需要精确 query 的 news 调用

### 🟡 P2 — 数据质量 / 表达问题

**B-07 经济日历 vs 财报日历语义不分**  
- keywords=["earnings_calendar"]+macro → 返回宏观日历（ISM/Bill Auction）  
- 财报日历目前**只能反向查询**：keywords=[大票列表] → 读 `next_earnings_estimate` 字段  
- 没有"本周财报 by marketCap"的正向接口

**B-08 dayLow/Open 浮点精度异常**  
- "dayHigh":963.01,"dayLow":903.0201 — 多 4 位小数  
- "open":820.5,"changePercentage":19.29161 — 不一致的精度  
- 影响展示，但不影响计算

**B-09 MU 极端值需要外部交叉验证**  
- MU price=$895.88, marketCap=$1.01T, +19.29% 单日  
- EPS Q3→Q2: $1.69 → $12.25（7倍跳变）  
- 真实还是上游 FMP 异常数据？默认 Skill 应做合理性校验

### 🟢 P3 — 元数据噪声

**B-10 `_skipped_sources_ids` 列表过长**  
- 每个 fundamentals 返回都列出 14 个 "no_match" sources  
- 信息量低、占 token，应在 verbosity=concise 时省略

**B-11 metadata 重复**  
- `warnings` + `warnings_legacy` 同字段两份  
- 应统一

---

## 三、未实测但需要后续覆盖

- [ ] news 各 source_lang（ko/ja/vi/pt）的覆盖密度
- [ ] signal `institutional` (13F) 数据时效性
- [ ] twitter user_tweets/thread 深度链路
- [ ] sse 长会话稳定性（>30 min）
- [ ] keywords 数量上限（doc 说 20，实测能否更多）
- [ ] interval=1min 数据可用回看窗口
- [ ] 跨时区 time_range 边界

---

## 四、原始 raw I/O 索引

所有探针调用的完整请求/响应已在主会话 transcript：  
`/Users/jimyzwjyw/.claude/projects/-Users-jimyzwjyw-Desktop-Followin-Skills/830c43e9-2479-4a4b-9126-a57ba8ac69ec.jsonl`

超大响应文件（B-02 的 744K 字符）：  
`/Users/jimyzwjyw/.claude/projects/-Users-jimyzwjyw-Desktop-Followin-Skills/830c43e9-2479-4a4b-9126-a57ba8ac69ec/tool-results/mcp-followin-metrics-1779875809806.txt`
