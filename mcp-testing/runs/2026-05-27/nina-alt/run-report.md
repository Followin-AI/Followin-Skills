# Run Report — nina-alt (2026-05-27)

环境: Followin MCP `/v2/sse` · today=2026-05-27 SGT  
执行方式: 手动按 mcp-test-runner Skill 协议（验证 Skill 可行性）

## 一、Step Verdict 汇总

| Step | Intent | Verdict | bug_refs |
|---|---|---|---|
| 1 | Crypto 涨跌榜 (min_market_cap=100M) | **FAIL** | B-01（重现） |
| 2 | HYPE/ASTER/ZEC 鲸鱼仓位 (signal trader_position 4h) | **PARTIAL** | **B-21（新）** |
| 3 | ZEC/HYPE KOL 喊单 (signal kol_call 1d) | **PARTIAL** | **B-21** |
| 4 | TG 频道 4h（10 类分类） | **PASS+** | B-16（重现） |
| 5 | TG 叙事追踪类过滤 | **PARTIAL** | 时段空窗 |
| 6 | Twitter $MONOPOLY OR $CARDS OR $XPIN 1d | **PARTIAL** | **B-22（新）** |

**通过率：1/6 PASS · 4/6 PARTIAL · 1/6 FAIL · 0 完全 PASS**

## 二、本轮新发现的 2 个 Bug

### 🔴 B-21 — `signal.keywords` 是文本模糊匹配，不是 symbol 精确匹配

**Repro**: signal categories=[trader_position] keywords=[HYPE,ASTER,ZEC] time_range=4h

**期望**: 7 条返回都是 HYPE/ASTER/ZEC 的实际持仓变动

**实际**: 全部 7 条匹配都是 **`_match_reason: matched_text`** —— 在`text`字段或 `介绍` 字段中**文本出现** HYPE/ASTER/ZEC，但**实际持仓品种**是：
- 麻吉大哥 **ETH** 清算（介绍提到 "偏好交易HYPE和ETH"）
- 山寨空军车头 **xyz:CBRS** 减仓 + USDC 提现（介绍提到 "持有包括HYPE、ASTER、UNI及ETH等空单"）
- ai_9684xtpa 报告 **HYPE** 鲸鱼累积（这条真匹配到 HYPE）

Step 3 同样：query=ZEC/HYPE 返回的 3 条 `symbol` 字段分别为 SPACEX / BTC / MONOPOLY，**只在 content text 出现 ZEC/HYPE**。

**影响**: 用户问"HYPE 鲸鱼最近怎么动" → 拿到的是"任何提到 HYPE 的人的任意品种仓位变动"。**精确性大问题，下游 Skill 决策会被错误信号污染**。

**建议**: 加 `match_mode` 参数（exact_symbol vs text_fuzzy 二选一），默认 exact_symbol。

### 🟠 B-22 — `twitter.search` 的 `OR` 操作符存疑

**Repro**: twitter action=search query="$MONOPOLY OR $CARDS OR $XPIN" time_range=1d

**期望**: 三个 ticker 的推文混合返回

**实际**: 20 条全部命中（带 $ 符号）但 **$MONOPOLY 0 条**，全部是 $CARDS 和 $XPIN。

**两种解释**:
- (A) OR 操作符不生效，被识别成 AND 或精确短语
- (B) $MONOPOLY 在 1d 窗口内确实没人发——这种解释下应该返回其他两个 ticker 的内容混合

**额外问题**: spam 占比高。20 条中 ~10 条是 $XPIN airdrop farming + $CARDS moonshot vote farming（用户 `followers<300`、内容模板化）。`search` 工具没有质量分层。

## 三、已知 bug 重现

### B-01 — `min_market_cap` 失效（重现）
Step 1: keywords=null, sort_by=change_pct, asset_type=crypto, min_market_cap=100M  
→ 返回 `_message: "Query did not match any upstream data source"`，**实际跑到了 macro 路径**（提示需要 indicator keyword）  
→ 跟之前美股 movers + min_market_cap 失败一致

### B-16 — 同帖多 _tg_category（重现）
- `cybertruck666@telegram` 同条 ("Strategy 평단 아래로 복귀") 同时标 "交易信号" + "实盘跟踪"
- `JoshuaDeukKOR@telegram` 同条 同时标 "宏观研判" + "市场结构"  
→ dedup_dropped_count=6 起到部分作用，但同帖跨 category 没去重

## 四、Skill 验证结论

### ✅ Skill 协议工作正常
- 并行 wave 1 (4 不同工具) 顺利触发，未撞 FMP rate limit
- 串行 step 3 在 step 2 之后正确执行  
- step 5 客户端复用 step 4 数据 → 节省 1 quota
- 总消耗 = 5 个 MCP call（step 1+2+3+4+6，step 5 客户端 filter）
- bug 自动 cross-ref 工作：B-01/B-16 已知，B-21/B-22 候选可立即标新编号

### ⚠️ Skill 需要优化的点
- **B-21 类问题需要在 accuracy_check 加自动断言**：检查 `symbol` 字段是否在 keywords 列表内 / `_match_reason` 不应是 `matched_text` 单一
- **OR 操作符问题**应该在 twitter search step 加默认 assertion：每个 OR 项目都至少 N 条命中

## 五、给 Dev 的工单优先级（含新 bug）

```
B-21 (P0) — signal.keywords 文本模糊匹配
  影响：所有 signal 跨标的查询的精确性
  期望：默认 exact_symbol 匹配，提供 match_mode 参数
  
B-22 (P1) — twitter.search OR 操作符存疑
  影响：跨标的 twitter 搜索
  待 Dev 确认是 query parser 问题还是数据本身缺失

B-01 (P0) — min_market_cap 失效（crypto path 重现）
  影响：所有 movers scan 类查询
  
B-16 (P2) — 同帖多 _tg_category 跨 category 重复
  影响：news telegram 聚合统计
```

## 六、Run Artifacts

- raw response 索引在 transcript（请求 ID: c28bd12b... / 6b6f41d1... / 01271d1a... / 等）
- 主 transcript: `~/.claude/projects/-Users-jimyzwjyw-Desktop-Followin-Skills/830c43e9-2479-4a4b-9126-a57ba8ac69ec.jsonl`
