# Run Report — leo-btc (2026-05-27)

环境: Followin MCP `/v2/sse` · today=2026-05-27 SGT

## 一、6 Step Verdict

| Step | Intent | Verdict | 关键问题 |
|---|---|---|---|
| 1 | BTC 日线 90 天 | **FAIL** | B-17 interval=1day 失效（返回小时级）+ B-18 disambig（混入美股 BTC Inc）+ B-19 数据陈旧 86 天 |
| 2 | BTC 4h K + RSI 14 | **PARTIAL** | B-17 interval=4hour 失效（返回 daily RSI）；RSI 数值本身合理（38.6） |
| 3 | BTC 1min 最近 1 天 | **FAIL** | B-17 interval=1min 失效（间隔 3-5min 不等）+ B-18 混入美股 BTC + 仅返回 4 小时 |
| 4 | BTC trader_position 4h | **PARTIAL** | 仅 5 条（探针密度远低），数学自洽 ✅，但 keywords=[BTC] 过滤后命中率低 |
| 5 | BTC news 1h 多源 | **FAIL** | B-20 返回 0 条，status=degraded（与之前探针 3 条不一致，时效抖动） |
| 6 | xyz: 链上美股 | **PASS** | xyz:SNDK / MRVL / DRAM 均有数据；xyz:MU 缺失（最近无动作）；Followin 独家维度验证 ✅ |

**通过率：1/6 PASS · 2/6 PARTIAL · 3/6 FAIL**

---

## 二、本次发现的 4 个新 Bug

### 🔴 P0 — B-17 `interval` 参数完全失效

**Repro 1**: keywords=[BTC] interval=1day limit=50
- 期望：每行 timestamp 间隔 24 小时
- 实际：返回小时级数据（00:00 / 01:04 / 02:03 / 03:01...）
- 数据范围：2026-02-27 → 2026-03-01（**仅 50 小时**）

**Repro 2**: keywords=[BTC] interval=4hour period=14
- 期望：4h RSI
- 实际：daily RSI（每天一个值，30 天）

**Repro 3**: keywords=[BTC] interval=1min time_range=1d
- 期望：1440 个 1 分钟 K
- 实际：~50 行，时间间隔 3-5 分钟不等

**结论**：interval 参数对 crypto 路径不生效，所有 OHLCV 历史查询都拿不到用户要的粒度。**这直接打死 Skill 04 (BTC dashboard) 的盘面分析**。

### 🔴 P0 — B-18 BTC keyword disambig 失败（crypto + 美股 BTC Inc 双返回）

**Repro**: keywords=[BTC] 不传 asset_type
- 实际返回：50 条 crypto BTC + 50 条 tradfi "BTC" (BTC Inc 美股 ticker, $33/股)
- meta.total=100 但 limit=50（limit 字段对单 asset_type 生效）
- 用户 query="BTC daily 90 days" 显然指 crypto，但 MCP 不能 disambig

**对照 M/S/AI 那一批已修复**：那批是 tradfi 默认走对，这次 BTC 反向问题——主流 crypto 反而被美股污染。

### 🟠 P1 — B-19 crypto OHLCV 历史数据严重陈旧

**实测**：
- Step 1: crypto BTC 日线数据停在 **2026-03-01**（today=2026-05-27 → 滞后 **86 天**）
- Step 3: crypto BTC 1min K 数据停在 **2026-05-27 04:09**（vs 当前应近 now → 滞后约 12-15h）
- 数据源：`_source: tradingagents` — 上游 tradingagents 数据滞后

**对比** signal.trader_position 是 `_meta.freshness: realtime`，时间戳就在几分钟前——同样是 BTC，市场数据陈旧但鲸鱼数据实时。**结构性数据源问题**。

### 🟠 P1 — B-20 news query 时效抖动

**Repro**: news query="BTC" time_range=1h
- 第 1 次（前一探针）：返回 3 条多语言版本
- 第 2 次（本次 step 5）：返回 0 条 status=degraded
- 同样的查询，几十分钟后结果完全不同

**可能根因**：SSE 间歇连接 / 上游索引器滞后 / OpenSearch 索引刷新延迟

---

## 三、对比 success_criteria

| Criterion | 目标 | 实际 | 命中 |
|---|---|---|---|
| BTC OHLCV 5 天与 Binance 100% 对齐 | 100% | **无法验证**（interval 失效，数据陈旧 86 天） | ❌ |
| RSI 14 vs TradingView 偏差 <0.5 | 偏差<0.5 | 拿到的是 daily RSI 不是 4h，**任务不对齐** | ⚠️ N/A |
| 鲸鱼仓位数学自洽率 100% | 100% | 抽 2 笔验证：Benson BTC 3.76M / 76530 × 3x ≈ Δ 自洽 ✅；100%胜率 0.4957 BTC × 74600 ≈ 36993 ✅ | ✅ |
| xyz 链上美股至少 3 个 ticker 有非空 | ≥3 | SNDK / MRVL / DRAM 3 个有 (MU 无动作期) | ✅ |

**2/4 通过，2/4 因 B-17 / B-19 失效**

---

## 四、给 Dev 的 P0 工单建议

```
B-17 (P0): interval 参数失效（crypto market path）
  影响范围：Skill 01/04/08/skill 涉及 BTC/ETH 任何粒度盘面分析
  期望：interval=1day 返回严格 daily, 4hour 返回严格 4h, 1min 严格 1min
  
B-18 (P0): BTC/ETH 等主流 crypto ticker 被美股 ticker 污染
  影响范围：所有 crypto 价格 / OHLCV 查询
  建议：crypto ticker 白名单 + 默认 asset_type=crypto for top-100 by mcap
  
B-19 (P1): tradingagents 数据源滞后
  影响范围：所有 crypto OHLCV 历史
  建议：切到 binance / coingecko 直连或加 freshness SLA 监控
  
B-20 (P1): news query 同查询时效抖动 0 → N
  影响范围：所有 news 调用稳定性
  建议：增加 retry + 索引刷新监控
```

---

## 五、Run Artifacts

完整 raw I/O 在主会话 transcript：
`~/.claude/projects/-Users-jimyzwjyw-Desktop-Followin-Skills/830c43e9-2479-4a4b-9126-a57ba8ac69ec.jsonl`

测试时间：2026-05-27（leo-btc 6 step 并行执行）
