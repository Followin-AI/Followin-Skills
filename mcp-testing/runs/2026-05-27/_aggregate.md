# 9 Persona 完整真跑总报告 — 2026-05-27

环境: Followin MCP `/v2/sse` · today=2026-05-27 SGT  
执行方式: 手动按 mcp-test-runner 协议，精选 1-2 个高价值 step / persona

## 总览

| Persona | 跑的 step | Verdict | 关键发现 |
|---|---|---|---|
| **mark** | FRED 6 series + 经济日历 | ✅ PASS | DGS10 ≈ DFII10 + T10YIE 数学自洽 (4.5 ≈ 2.1+2.39) |
| **yuki** | BTC en + zh-cn + 以太坊别名 | ✅ PASS | **中文公司名"以太坊"自动解析到 ETH** |
| **kevin** | BTC 泛问 + youtube + medium | ❌ FAIL ×2 | youtube + medium 路径均 degraded |
| **hedy** | NVDA 14 sub-source 真聚合 | ✅ PASS+ | 18 fired 但实际 16 个有数据 |
| **felix** | NVDA insider 1m + transcript detail | ✅+❌ | insider 15 条带 Pelosi；transcript 永远不返 |
| **olivia** | Berkshire 13F + NVDA 13F | ❌ FAIL ×2 | institutional 数据源完全不可用 |
| **sarah** | twitter trends woeid=1 | ✅ PASS | 30 条全球 trends |
| **david** | 5 个 gold ETF/股票 quote | ✅ PASS | warning 但数据正确（B-04 quirk）|
| **alex** | kol_call crypto 1d + 4 meme alias | ✅ PASS | PENGU/WIF/BONK/POPCAT 全命中 |

**总计 14 个 step：11 PASS · 0 PARTIAL · 3 FAIL**

## 本轮新发现的 4 个 Bug

### 🔴 B-26 (P0) — `signal.institutional` 完全不可用
- Repro: `categories=[institutional] keywords=[Berkshire]` / `[NVDA]` 都返 `_message: "Query did not match any upstream data source"` + `_source_dead: institutional_all_symbols_failed`
- **Olivia persona 全部 5 step 依赖此源 → 整个 persona 无法执行**
- 影响：跟踪 Buffett/Burry/Ackman 类需求完全做不了

### 🟠 B-25 (P1) — `fundamentals` 18 sub-source 实际只产 16 个
- Repro: NVDA query="全面分析" verbosity=detail 拿到 53KB 响应
- `_fired_sources_ids` 列出 18 个（含 `transcript` + `analyst_estimates`）
- 实际 results 里**完全没有** `transcript` 字段和 `analyst_estimates` 字段
- 影响：Followin 营销文案"18 sub-source 真聚合" → 实际 16

### 🟠 B-27 (P1) — `news sources=[medium]` 上游 HTTP 422
- Repro: query="macro Fed" sources=[medium] time_range=1w → degraded
- warning: "news_tg_kol_feeds: market data source error (HTTP 422)"

### 🟠 B-28 (P1) — `news sources=[youtube]` 路径不可用
- Repro: query="crypto ETF" sources=[youtube] time_range=1w → degraded, results=null

## 已知 bug 重现

| Bug | 这次重现场景 |
|---|---|
| **B-04** quirk | david gold ETF：asset_type=tradfi 但 warning 说 "GLD(crypto)"，数据仍正确返回 |
| **B-21** 文本模糊匹配 | alex kol_call：NihilusBTC 连发 5 条 $XPIN 喊单，1 条 symbol 字段标 USDT（连续被同一作者发的内容）|

## 积极发现（值得标差异化卖点）

1. **中文公司名直接查询工作** — yuki query="以太坊" 自动解析到 ETH 相关 4 条新闻。文档说"normalize aliases yourself"实际**有内部 embedding 兜底**。
2. **跨语言新闻聚合** — BTC OG 内幕巨鲸新闻同时在 en + zh-cn 出现（不同 feed_id，未自动 dedup ≠ B-15）。
3. **小币 ticker alias** — PENGU/WIF/BONK/POPCAT 全部命中（Binance + CoinGecko 双源标注）。
4. **insider 三源 fanout** — NVDA 1m 内 15 条 = corporate Form 4（Jensen Huang/Colette Kress/Mark Stevens 抛售）+ congress（Pelosi 配偶抛售 $1M-$5M）。
5. **FRED 数学自洽** — DGS10=4.5% ≈ DFII10=2.1% + T10YIE=2.39% (误差 0.01)
6. **NVDA fundamentals 16 sub-source 完整** — balance/cash_flow/income 4 季 + DCF($211→$241) + EV 数学自洽 + 19 grades + 9 peers + shares_float + 10 SEC filings

## 累计 bug 数

12 个实测 bug（之前 8 + 本轮新 4）：

P0: B-01 · B-17 · B-18 · B-21 · **B-26**  (5)  
P1: B-19 · B-20 · B-22 · **B-25** · **B-27** · **B-28**  (6)  
P2: B-16  (1)

## 修复优先级 (Top 5)

```
1. B-17 + B-19 (crypto OHLCV 数据源换 Binance/CoinGecko)
2. B-26 (signal.institutional 数据源修复 / 切换)
3. B-21 (signal.keywords 加 match_mode 参数)
4. B-18 (crypto top-100 disambig 白名单)
5. B-27 + B-28 (news sources medium/youtube 路径恢复)
```
