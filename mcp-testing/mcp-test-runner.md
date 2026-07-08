---
name: mcp-test-runner
description: Auto-runner for Followin MCP persona accuracy testing. Reads a persona YAML, fires every step's MCP call, archives raw I/O, applies machine-checkable assertions, flags external-cross-check items for human review, outputs a structured run report.
trigger:
  - 跑一下 <persona>
  - 测试 <persona> step <n>
  - 实测 persona
  - run persona
  - mcp test runner
not_trigger:
  - 单条 MCP 工具调用（直接用 mcp__followin__* 即可）
mcp:
  - mcp__followin__metrics
  - mcp__followin__news
  - mcp__followin__signal
  - mcp__followin__twitter
args:
  persona: required — persona id (hedy / mark / alex / sarah / david / yuki / kevin / olivia / felix / leo-btc / nina-alt)
  step: optional — specific step number to run; omit = run all
  skip_external: optional — true = skip "needs_human_verify" assertions entirely; default = flag them
---

# MCP Test Runner

把 `mcp-testing/personas/<persona>.yaml` 里的 daily_script 转成可一键执行的测试流——保留 raw I/O，跑 accuracy_check 中机器可验证的部分，外部交叉项标 `needs_human_verify` 留人工。

## 触发场景

| 用户说 | 解释 |
|---|---|
| "跑一下 leo-btc" | 全 6 step |
| "测 hedy step 3" | 仅 step 3 |
| "实测 nina-alt 跳过外部交叉" | 跑全部但只机器验证 |
| "重新跑 felix step 6" | 单 step |

## 工作流

### 1. 解析 persona
读 `mcp-testing/personas/<persona>.yaml`。若文件不存在，列出所有可用 persona 让用户选。

### 2. 创建 run 目录
```
mcp-testing/runs/<YYYY-MM-DD>/<persona>/
├── raw/                 # 每个 step 的原始 MCP response (json)
└── run-report.md        # 最终报告
```

如果当日目录已存在，追加 `-r2`、`-r3` 后缀避免覆盖（同一 persona 当日多次 run 留痕）。

### 3. 逐 step 执行

**串行规则**（基于 leo-btc 真跑撞 FMP rate limit 的教训）：
- 同一 step 内的 MCP 子调用可并行
- **跨 step 强制串行**——尤其是连续 `metrics market` 路径，FMP 4 并发即限流
- 不同工具（market / news / signal / twitter）可并行

对每个 step：
1. 打印 step 头：`step N · intent · natural_input`
2. 解析 `expected_skill` → 转成具体 MCP 工具调用参数
3. Fire tool call
4. 保存 raw response 到 `raw/T-<date>-<persona>-<step>.json`（使用 Bash + jq 或 Write 工具落盘）
5. 跑 `accuracy_check` 断言（见 §4）
6. 输出 step verdict：PASS / FAIL / PARTIAL / EDGE_CASE / NEEDS_HUMAN

### 4. 断言分类

机器可自动验证的断言：
- **数学自洽**：仓位价值 ≈ 数量 × 当前价 ±N%；杠杆/开仓/清算价数学关系
- **schema 完整性**：字段非空 / 字段类型正确 / 数组长度合理
- **时间窗校验**：timestamp 在请求 time_range 内 / freshness 与现在差距
- **粒度检查**：interval 间隔严格性（参考 leo-btc 实测 crypto 只有 1h 的边界）
- **响应状态**：status=ok vs degraded / `_skipped_sources_ids` 占比
- **去重**：跨语言重复（feed_id 不同但 content 高重合）
- **路由命中**：返回 entity 是否与请求 keyword 匹配（不混入同名美股/crypto）

需要人工外部交叉验证（**仅记录断言文本 + 关键字段值**，不执行调用）：
- "与 SEC EDGAR / FRED / Binance / CoinGecko / Yahoo Finance / TradingView / WhaleWisdom / Investing.com 对齐"
- "原文可在 TG 频道 web / Twitter 找到对应"
- 任何包含"vs <外部站点>"的表达

### 5. 已知 bug 自动 cross-ref

跑断言时，如果发现：
- crypto OHLCV 返回非 1h 间隔 → 标 `B-17 (crypto granularity)`
- BTC 同时返回 crypto + tradfi BTC Inc → 标 `B-18 (disambig)`
- crypto market 数据时间戳 > 1 天前 → 标 `B-19 (data staleness)`
- news status=degraded 或 results=null → 标 `B-20 (news fluctuation)`
- mover 返回 min_market_cap 过滤后仍含微盘 → 标 `B-01`
- detail verbosity 触发 token 超限 → 标 `B-02`
- 同帖多 _tg_category → 标 `B-16`
- news(sources=[twitter]) 返回 0 status=degraded → 标 `B-12`

参考 `mcp-testing/probes/2026-05-27/findings.md` 完整 bug 清单。

### 6. 输出格式

每个 step 落盘的 YAML 记录：
```yaml
test_id: T-2026-05-27-leo-btc-001
persona: leo-btc
step_in_script: 1
user_natural_input: "BTC 日线 最近 90 天"
mcp_call:
  tool: mcp__followin__metrics
  params: {keywords: [BTC], interval: 1day, limit: 50, asset_type: crypto}
fired_at: 2026-05-27T16:23:00Z
mcp_response_summary: |
  返回 50 条，全部为 1 小时间隔（非日线）。
  数据时间窗 2026-02-27 → 2026-03-01，停在 86 天前。
  meta.status=ok 但 interval 参数被忽略。
mcp_response_raw_path: ./raw/T-2026-05-27-leo-btc-001.json
verdict: FAIL
bug_refs: [B-17, B-19]
machine_checks:
  - "interval=1day 但返回 1h 间隔" → FAIL
  - "数据时间窗在 time_range 内" → FAIL (停 86 天前)
human_verify:
  - "5 天与 Binance 100% 对齐" → SKIP (前置失败)
notes: |
  Crypto OHLCV 实际只有 1h K (已知限制 B-17)，该 step 设计需调整。
```

最终 `run-report.md`：
- 每 step 摘要表
- 通过率
- 触发的所有 bug_refs（去重）
- 触发新 bug 候选（无 bug_ref 匹配的 FAIL）
- 给 Dev 的精确反馈段

## 使用样例

### 跑全 persona
```
用户："跑一下 leo-btc"
Skill：
  1. 读 leo-btc.yaml，发现 6 step
  2. step 1 (metrics market) → 串行
  3. step 2 (metrics market + technicals) → 串行 (避 FMP rate limit)
  4. step 3 (metrics market) → 串行
  5. step 4 (signal) + step 5 (news) 可并行
  6. step 6 (signal) → 串行
  7. 输出 run-report.md
```

### 跑单 step
```
用户："测 hedy step 6"
Skill：
  1. 读 hedy.yaml，定位 step 6
  2. 跑 NVDA fundamentals 14 sub-source
  3. 检查 fired_sources_ids 是否含至少 12 个
  4. 输出单 step 报告
```

### 跳过外部交叉
```
用户："实测 nina-alt 跳过外部交叉"
Skill：
  跑全部 step
  仅执行 machine_checks
  human_verify 项全部标 SKIPPED
```

## 注意事项

- **不要并行所有 step**：FMP rate limit 实测 4 并发即触发，需按工具类型分组串行
- **raw response 必须落盘**：原始数据是后续手动审计的唯一依据，不要省
- **不要"修复"未对齐的数据**：如果 accuracy_check FAIL，原样记录，不要为了让通过率好看而调整断言阈值
- **bug_refs 引用现有清单**：新 bug 候选另起 B-21 开始编号，写进 findings.md
- **遇到 SSE 断开/timeout**：标 EDGE_CASE，记录后跳过该 step，继续下一 step
- 输出报告中文，便于本地阅读
