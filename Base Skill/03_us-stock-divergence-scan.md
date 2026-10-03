---
name: US Stock Divergence Scan
description: 信号背离扫描 — 发现价格、内部人交易与媒体报道之间的不一致。触发词必须明确指向"背离/静默异动/内部人买入"场景，如"背离扫描"、"有没有没新闻却大涨的"、"内部人悄悄买入"。泛问"有什么异常"、单一个股异动不在本Skill范围。
trigger: 美股背离扫描、美股价格背离、美股背离信号、美股静默异动、美股无新闻异动、美股内部人买入、美股内部人悄悄买、美股没新闻大涨、美股没新闻大跌、美股silent moves、美股silent buy、US stock divergence scan、divergence scan、silent moves、silent buy、anomaly signals、unreported drop、unreported surge
not_trigger: 策略信号、KOL、喊单、热点、日报、财报、earnings、今天有什么消息、市场在关注什么、strategy、KOL calls、trending、daily brief、earnings report、what's hot、market focus、BTC宏观（→04）、黄金宏观（→05）、宏观早报/morning brief（→06）
mcp: mcp__followin__metrics, mcp__followin__news, mcp__followin__signal
args: scope, days
---

# /divergence-scan

信号背离扫描 — 发现价格、内部人交易与媒体报道之间的不一致（Followin MCP 版）

## 参数

| 参数 | 必填 | 默认 | 说明 |
|------|------|------|------|
| scope | 否 | `all` | `all` 四种信号都扫；`insider` 只扫内部人静默买入；`price` 只扫三种价格类信号 |
| days | 否 | 7 | 回溯天数：内部人交易按 `transactionDate` 过滤的窗口，也是新闻检索的窗口 |

## 意图路由

| 用户说的 | 走哪个Skill |
|---------|-----------|
| 背离扫描、silent moves、没新闻却大涨/大跌、内部人悄悄买入 | ✅ 本Skill |
| 泛问"有什么异常"、"今天有什么消息" | ❌ 不在范围——先问清是不是要扫背离信号 |
| XX财报、XX earnings | ❌ 转 02 earnings-report |
| 宏观日报、美股早报 | ❌ 转 06 morning-brief |

> 🔗 **通用调用红线 + 已知问题登记**：`~/.claude/references/followin-mcp-caveats.md`（仓库内 `references/`）。本文的调用写法和字段名于 **2026-10-01 逐条实测**；与登记表冲突时，以日期更新的一方为准。

## 调用约定（2026-10-01 实测）

- `metrics` / `signal` 的入参分工：**`keywords` 数组放标的，`query` 放意图词，`categories` 指定数据类别**。每次调用最多 5 个 keywords，丢项会写进 `meta.warnings`——每次调用后读一遍，有缺口就补调。
- 本 Skill 只查美股：所有 `metrics` / `signal` 调用带 `asset_type="tradfi"`，否则同名加密代币会混进来（实测 AMN、WEST 都撞过）。
- 如果客户端不接受数组入参（报 `-32602`）：补市值退回 `query="<T1> <T2> … 行情"`（≤5 个）；内部人全量扫描退回 `query="内部人交易"`。

## 四种背离信号

| 信号 | 含义 | 判定 |
|---|---|---|
| **Silent Buy** 内部人静默买入 | 知情人在买，价格和媒体都没动 | 主动买入合计 > 10 万美元，**不在**当日任何一张榜上，相关报道 ≤ 2 篇 |
| **Sentiment Mismatch** 情绪错配 | 价格和媒体情绪方向相反 | 涨跌幅绝对值 > 5%，市值 > 10 亿美元，情绪方向与价格相反 |
| **Unreported Drop** 无声暴跌 | 大市值股大跌而几乎没人报道 | 跌幅 > 8%，市值 > 10 亿美元，相关报道 ≤ 3 篇 |
| **Unreported Surge** 无声暴涨 | 显著上涨而几乎没人报道 | 涨幅 > 20%，市值 > 5 亿美元，相关报道 ≤ 2 篇 |

**"相关报道数"的口径**：`news()` 返回媒体和社交两桶，两桶都算——判据是"这只票有没有人在说"。但必须**逐条判断是否真的在讲这家公司**后再计数，不能用返回条数：查不到相关内容时 `news()` 不返回空，而是返回一批不相关的热门内容。

## 执行步骤

### Step 1: 拉榜单 + 内部人全量扫描（4 路并行）

```
1. metrics(query="biggest gainers",    asset_type="tradfi", limit=30)
2. metrics(query="biggest losers",     asset_type="tradfi", limit=30)
3. metrics(query="most active stocks", asset_type="tradfi", limit=30)
4. signal(categories=["insider_trading"], asset_type="tradfi", limit=50)
```
`scope=insider` 时仍要拉三张榜（用来排除"价格已动"的票）；`scope=price` 时省掉第 4 路。

- 三张榜的行**只有** symbol / name / price / change / changesPercentage，没有市值也没有交易所，而且大量是仙股和杠杆产品（实测涨幅榜前 6 只有 5 只股价低于 6 美元）。
- 第 4 路必须是**全量扫描**，不要按榜单上的 ticker 逐个查内部人——上榜说明价格已经动了，那样永远扫不到 Silent Buy。
- 第 4 路不要传 `time_range`（服务端无法保证按交易日期截断，会返回 `status:"partial"`），日期在客户端按 `transactionDate` 过滤。返回顺序是按申报时间，不是按金额。

### Step 2: 榜单初筛 + 补市值

1. **按名称剔杠杆与 ETF 产品**：`name` 命中 `ETF|ETN|UltraPro|Ultra|Leveraged|\dX|Bull|Bear|Daily` 任一即剔。只判 "ETF" 一个词会漏——TQQQ（ProShares UltraPro QQQ）的名称里没有 "ETF"。
2. **按信号门槛挑候选**（榜单行里就有涨跌幅，先用它筛，省掉大部分补市值调用）：
   - 涨幅榜：`changesPercentage > 20`
   - 跌幅榜：`changesPercentage < −8`
   - 活跃榜：`|changesPercentage| > 5`
   - 三者去重合并。超过 20 只时按涨跌幅绝对值取前 20，并在报告的"数据缺口"里写明裁掉了几只。
3. **补市值和交易所**，每批 ≤5 个、每轮 ≤4 批并行，**所有候选都要补，不是只补前 5 个**：
   ```
   metrics(keywords=[<T1>…<T5>], query="行情", asset_type="tradfi")
   ```
   快照行带 `marketCap` 和 `exchange`。⚠️ 快照的 `change` 是美元变动量不是百分比；涨跌幅沿用榜单行的 `changesPercentage`。
   调用后对照请求清单：`results.market.snapshot[]` 里没有的 ticker 记为"取不到市值"，按不满足市值门槛处理并列入数据缺口。
4. **终筛**：`exchange` 属于 NYSE / NASDAQ / AMEX，且市值过对应信号的门槛。**不要用股价做门槛**（实测 GRAB 股价 3.31 美元、市值 131 亿美元，会被"低于 5 美元"误杀）。

### Step 3: Silent Buy 候选（用 Step 1 第 4 路的结果，不新增调用）

```
保留:
  SEC Form 4 主动买入:  formType == "4" 且 transactionType == "P-Purchase"
                       且 transactionDate 在最近 [days] 天内
  国会议员买入:         provenance == "congress" 且 type == "Purchase"
                       且 amount 区间下限 ≥ 5 万美元
丢弃:
  formType == "3"（初始持仓申报，不是交易）
  S-Sale（卖出）/ M-Exempt、A-Award、F-InKind（行权、授予、扣税）/ G-Gift / J-Other
```
按 ticker 合并：同一只票的多笔主动买入金额相加（`price × securitiesTransacted`），合计 > 10 万美元的留下。

然后**排除已在三张榜任一张上的 ticker**——价格已动就不算"静默"。榜内 ticker 同时有内部人买入的，放进报告的"多重信号"一节。

50 条里主动买入通常只占少数，候选为 0 是常态，如实写"本期无符合条件的主动买入"，不要放宽条件。

### Step 4: 媒体交叉验证（每批 ≤4 路并行）

对 Step 2 终筛幸存者 + Step 3 候选，逐只：
```
news(query="<CompanyName> <TICKER>", time_range="<days>d", limit=5)
```
- query 用"公司名 + 代码"两个词，纯英文，不写"impact / 影响 / 解读"这类词。
- 不要只用代码单查（短代码会撞上同名的词或公司）。
- **返回里一条都不含目标公司名或代码 = 没查到**。此时相关报道数记 0，不要重试——同一个 query 重试、换措辞返回的都是同一批兜底内容。两只不同的票如果返回了一模一样的内容，说明两只都没查到，不是"有共同报道"。
- 对 Sentiment Mismatch 的候选，根据相关报道的标题和正文判断情绪方向，标"Claude 推断"。

### Step 5: （可选）区分单日异动与持续趋势

对最终命中信号的票，每批 ≤5 个：
```
metrics(keywords=[<T1>…<T5>], query="历史走势", asset_type="tradfi", time_range="1m", limit=25)
```
用首尾收盘算月涨跌，填进报告的"月涨跌"列。不做这一步就把该列标"未取"。

### Step 6: 判定与排序

按上面"四种背离信号"表的判定条件逐只核对。
排序：同时命中多个信号的在前；其次市值大的在前；再次涨跌幅绝对值大的在前。

### Step 7: 输出报告

```
## 🔍 背离信号扫描 — [日期]

扫描范围: [scope] | 回溯: [days] 天
榜单候选: [N] 只 → 过市值门槛 [M] 只 | 内部人记录: [K] 条 → 主动买入 [J] 只
发现信号: [X] 个

---

### ⚡ Sentiment Mismatch（情绪错配）
| Ticker | 公司 | 市值 | 日涨跌 | 月涨跌 | 媒体情绪（Claude 推断）| 错配类型 | 相关报道数 |

**分析**: [核心判断 + 可能的驱动 + 风险]

---

### 🔕 Silent Buy（内部人静默买入）
| Ticker | 公司 | 买入人 | 职位 | 买入金额 | 交易日期 | 相关报道数 |

> 无信号时一行带过: "本期无符合条件的主动买入"

---

### 📉 Unreported Drop（无声暴跌）
| Ticker | 公司 | 市值 | 跌幅 | 相关报道数 |

> 无信号时: "今日无 10 亿美元以上市值标的无声暴跌"

---

### 🚀 Unreported Surge（无声暴涨）
| Ticker | 公司 | 市值 | 涨幅 | 相关报道数 |

> 无信号时: "今日无 5 亿美元以上市值标的无声暴涨"

---

### ⚠️ 多重信号（同时命中 2 个以上，或榜内票同时有内部人买入）
[重点标注]

### 📋 总结
[2-3 句话概括今日背离格局]

### 数据缺口
- [取不到市值的 ticker、因数量上限裁掉的候选、新闻没查到的 ticker；没有就写"无"]
```

## 输出规则

- 有信号的部分展开分析（可能的驱动、风险、后续关注点）；无信号的部分一行带过
- 情绪判断标"Claude 推断"
- 榜单是当日快照：非交易时段跑，反映的是上一个交易日
- 背离信号是"值得进一步研究"的线索，不是交易建议
