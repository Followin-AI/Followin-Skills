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

> 🔗 **通用调用红线 + 已知问题登记**：`~/.claude/references/followin-mcp-caveats.md`（仓库内 `references/`）。本文的调用写法和字段名于 **2026-10-03 实跑验证**；与登记表冲突时，以日期更新的一方为准。

## 调用约定（2026-10-03 实测）

- `metrics` / `signal` 的入参分工：**`keywords` 数组放标的，`query` 放意图词，`categories` 指定数据类别**。每次调用最多 5 个 keywords。缺口以"请求清单与返回 `symbol` 的差集"为准——`meta.warnings` 偶有误报（实测 5 只美股全部正常返回，warning 却说"都解析成了加密币"），只作参考。
- 本 Skill 只查美股：所有 `metrics` / `signal` 调用带 `asset_type="tradfi"`，否则同名加密代币会混进来（实测 AMN、WEST 都撞过）。
- 如果客户端不接受数组入参（报 `-32602`）：补市值退回 `query="<T1> <T2> … 行情"`（≤5 个）；内部人全量扫描退回 `query="内部人交易"`。

## 四种背离信号

| 信号 | 含义 | 判定 |
|---|---|---|
| **Silent Buy** 内部人静默买入 | 知情人在买，价格和媒体都没动 | 主动买入合计 > 10 万美元，**不在**当日任何一张榜上，相关报道 ≤ 2 篇 |
| **Sentiment Mismatch** 情绪错配 | 价格和媒体情绪方向相反 | 涨跌幅绝对值 > 5%，市值 > 10 亿美元，情绪方向与价格相反 |
| **Unreported Drop** 无声暴跌 | 大市值股大跌而几乎没人报道 | 跌幅 > 8%，市值 > 10 亿美元，相关报道 ≤ 3 篇 |
| **Unreported Surge** 无声暴涨 | 显著上涨而几乎没人报道 | 涨幅 > 20%，市值 > 5 亿美元，相关报道 ≤ 2 篇 |

**"相关报道数"的口径**：`news()` 返回媒体和社交两桶，两桶都算——判据是"这只票有没有人在说"。但必须**逐条判断是否真的在讲这家公司**后再计数，不能用返回条数（见 Step 4）。

**这四个信号的覆盖边界**（2026-10-03 实测，报告里要如实写）：
- 三张榜每张最多约 30 行、以小盘股为主：跌幅榜传 `limit=50` 也只返回 31 行，最低到 −12.6%。**跌幅在 −8% 到榜单末行之间的大市值股看不到**，Unreported Drop 对大票覆盖很弱。
- 内部人全市场入口只返回最近约 1 个申报日、最多 50 条，同一家公司的多笔申报会挤占名额（实测 50 条只有 9 家公司，其中一家占 25 条，主动买入 0 条）。**Silent Buy 的结论只能写"最近一个申报日内未见"，不能写"近 [days] 天无内部人买入"。**

## 执行步骤

### Step 1: 拉榜单 + 内部人全量扫描（4 路并行）

```
1. metrics(query="biggest gainers",    asset_type="tradfi", limit=30)
2. metrics(query="biggest losers",     asset_type="tradfi", limit=30)
3. metrics(query="most active stocks", asset_type="tradfi", limit=30)
4. signal(categories=["insider_trading"], asset_type="tradfi", sort_by="amount", limit=50)
```
`scope=insider` 时仍要拉三张榜（用来排除"价格已动"的票）；`scope=price` 时省掉第 4 路。

- 三张榜的行**只有** symbol / name / price / change / changesPercentage，没有市值也没有交易所，而且大量是仙股和杠杆产品（实测涨幅榜前 6 只有 5 只股价低于 6 美元）。
- 第 4 路必须是**全量扫描**，不要按榜单上的 ticker 逐个查内部人——上榜说明价格已经动了，那样永远扫不到 Silent Buy。
- 第 4 路不要传 `time_range`（服务端无法保证按交易日期截断，返回 `status:"partial"` 且内容不变）；query 里写"主动买入"之类的意图词也不起作用。`sort_by="amount"` 按金额降序：它**不扩大申报日覆盖**（实测按金额、按时间两种排序 Form 4 都只覆盖同一个申报日），作用只是把小额授予、赠与挤出去并带出金额大的议员交易；第 50 行金额约 13 万美元，略高于 10 万的买入仍可能被大额卖出挤掉。日期在客户端过滤（见 Step 3）。

### Step 2: 榜单初筛 + 补市值

1. **按名称剔杠杆、反向与 ETF 产品**：`name` 匹配 `(?i)\bETF\b|\bETN\b|Ultra|Leverag|\d+X\b|Bull|Bear|Daily|Short|Inverse|Target` 即剔（不区分大小写）。只判 "ETF" 一个词会漏——TQQQ 叫 ProShares UltraPro QQQ，RWM 叫 ProShares - Short Russell2000。代码为 5 个字母且以 `R` / `U` / `W` 结尾、名称含 `Acquisition Corp` / `Merger Corp` / `Right` / `Unit` / `Warrant` 的，按 SPAC 权证、权利证或单位剔掉（实测 GSRVR 是 GSR V Acquisition Corp. 的权利证，名称里没有 "Right"）。
2. **按最宽的信号门槛挑候选**（四个信号里最宽的是情绪错配的 ±5%，具体门槛到 Step 6 再卡）：
   - 涨幅榜：`changesPercentage > 5`
   - 跌幅榜：`changesPercentage < −5`
   - 活跃榜：`|changesPercentage| > 5`
   - 涨幅榜、跌幅榜整张通常都在 ±5% 以外，这道门槛对它们基本不起筛选作用；三张榜合并后候选通常 55~60 只，补市值固定约 10 次。
   - 三者去重合并，**全部补市值**。超过 50 只时先保留活跃榜的候选，再按股价从高到低取够 50 只——股价只用来排先后、不用来剔除。**不要按涨跌幅绝对值裁剪**：涨跌幅最大的几乎全是小盘股，实测按它取前 20 会把唯二过 10 亿门槛的 SPCX（+7.4%）、CTVA（−5.2%）裁掉。裁掉的写进数据缺口。
3. **补市值和交易所**，每批 5 个、每轮 ≤4 批并行：
   ```
   metrics(keywords=[<T1>…<T5>], query="行情", asset_type="tradfi")
   ```
   快照行带 `marketCap` 和 `exchange`。⚠️ 快照的 `change` 是美元变动量不是百分比；涨跌幅沿用榜单行的 `changesPercentage`。
   调用后对照请求清单：`results.market.snapshot[]` 里没有的 ticker 记为"取不到市值"，按不满足市值门槛处理并列入数据缺口。
4. **终筛**：`exchange` 属于 NYSE / NASDAQ / AMEX，且市值过对应信号的门槛。**不要用股价做门槛**（实测 GRAB 股价 3.31 美元、市值 131 亿美元，会被"低于 5 美元"误杀）。
5. **公司行为、流动性与 SPAC 标记**（只对过了市值门槛的票做；不剔除，先标出来）：
   - `marketCap < price × volume`（市值比一天成交额还小），或 `yearHigh ÷ price > 5`：标"市值或价格疑受分拆 / 并股影响"。核实方法：看相关报道，或看 `previousClose` 是否已是分拆 / 并股后的价格——已调整的，当日涨跌幅照常使用。实测 CTVA 10-01 分拆，yearHigh ÷ price = 7.6，但前收盘已是分拆后价格，−5.2% 是真实跌幅；WHLR 并股后快照市值只有 6,309 美元。对过门槛前的全部候选做这一步会误标一大片小盘股（实测 50 只里 30 只），没有意义。
   - `price × volume < 1,000 万美元`（当日成交额不足 1,000 万）：标"低流动性"。这类票命中 Unreported Drop / Surge 时必须跑 Step 5 看近一个月走势；近一个月有 ≥ 3 天单日涨跌幅超过当日幅度的 2/3，判为"常态波动"，不计入信号，写进数据缺口。实测 MAAS 市值 60 亿，当日成交只有约 300 万美元，一个月里 4 天单日涨跌超过 9%，−13% 是它的日常波动而不是"大票没人报道"。
   - 名称含 `Acquisition Corp` / `Merger Corp` 的是 SPAC（借壳空壳公司），按 Step 4 的 SPAC 规则查新闻。

### Step 3: Silent Buy 候选（用 Step 1 第 4 路的结果，不新增调用）

```
保留:
  SEC Form 4 主动买入:  formType == "4" 且 transactionType == "P-Purchase"
                       且 transactionDate 在最近 [days] 天内
  国会议员买入:         存在 `_chamber` 字段（senate / house）且 type == "Purchase"
                       且 symbol 非空（买对冲基金份额等无代码的不算）
                       且 disclosureDate 在最近 [days] 天内（议员交易滞后 2~4 周才申报，按披露日不按交易日）
                       且 amount 区间下限 ≥ 10 万美元
丢弃:
  formType == "3"（初始持仓申报，不是交易）
  S-Sale（卖出）/ M-Exempt、A-Award、F-InKind（行权、授予、扣税）/ G-Gift / J-Other
```
按 ticker 合并：同一只票的多笔 Form 4 主动买入金额相加（`price × securitiesTransacted`），合计 > 10 万美元的留下。议员交易的金额是区间字符串，不相加，报告里写成区间并注明"披露于 X 日"。

然后**排除已在三张榜任一张上的 ticker**——价格已动就不算"静默"。榜内 ticker 同时有内部人买入的，放进报告的"多重信号"一节。

50 条里主动买入通常只占少数，候选为 0 是常态，如实写"最近一个申报日内未见符合条件的主动买入"，不要放宽条件。

### Step 4: 媒体交叉验证（每批 ≤4 路并行）

对 Step 2 终筛幸存者 + Step 3 候选，逐只：
```
news(query="<CompanyName> <TICKER>", time_range="<days>d", limit=5)
```
- query 用"公司名 + 代码"两个词，纯英文，不写"impact / 影响 / 解读"这类词。
- 不要只用代码单查（短代码会撞上同名的词或公司）。
- **怎么判"没查到"**：返回为空、`status:"degraded"`，或返回里一条都不含目标公司名或代码，都记 0，不要重试——同一个 query 重试、换措辞返回的都是同一批兜底内容。两只不同的票如果返回了一模一样的内容，说明两只都没查到，不是"有共同报道"。
- **不论 `meta.filters_applied.entity_filter_applied` 是 true 还是 false 都要逐条判断**：为 false 时是语义召回，无关内容比例更高；为 true 时也会混进无关内容（实测 SPCX 10 条里 6 条是被 "Space" 带进来的英国预算、仓储公司报道）。
- **SPAC 要换名字查**：用榜单上的 SPAC 名称查几乎全是无关内容（实测 "Armada Acquisition Corp. II XRPN" 10 条里只有 1 条相关），用合并对象的名字查才准（"Evernorth XRPN" 10 条里 7 条相关）。先从第一次返回里那 1~2 条相关报道找合并对象的名字，再用"<合并对象名> <TICKER>"重新计数。找不到合并对象就不判 Unreported，放进报告末尾的"SPAC 合并行情"备注。
- 对 Sentiment Mismatch 的候选，根据相关报道的标题和正文判断情绪方向，标"Claude 推断"。

### Step 5: （可选）区分单日异动与持续趋势

对最终命中信号的票，每批 ≤5 个：
```
metrics(keywords=[<T1>…<T5>], query="历史走势", asset_type="tradfi", time_range="1m", limit=25)
```
用首尾收盘算月涨跌，填进报告的"月涨跌"列。**不要用日线里的 `changePercent`**——它是当天开盘到收盘，不是对比前一天收盘（实测 XRPN 同一天日线写 +35.9%，榜单是 +68.3%）。不做这一步就把该列标"未取"。

### Step 6: 判定与排序

按上面"四种背离信号"表的判定条件逐只核对。情绪错配分两类：价格涨而情绪偏负面记"利空不涨反涨"，价格跌而情绪偏正面记"利好不涨反跌"。情绪错配要求相关报道 ≥ 1 篇；0 篇时没有情绪可判，不算错配。

**接近门槛的静默异动**：市值 > 10 亿、涨跌幅绝对值 > 10%、相关报道 = 0，但没命中任何一个信号的票（例如涨 15%，不够无声暴涨的 20%），列进报告末尾的备注，不算信号。实测 IMOS（+14.6%、29 亿、零报道）就卡在这个空档里。
排序：同时命中多个信号的在前；其次市值大的在前；再次涨跌幅绝对值大的在前。

### Step 7: 输出报告

```
## 🔍 背离信号扫描 — [日期]

扫描范围: [scope] | 回溯: [days] 天
榜单候选: [N] 只（去重后、裁剪前）→ 过市值门槛 [M] 只
内部人记录: [K] 条（Form 4 [k1] 条，filingDate [最早]~[最晚]，[n1] 家公司；议员 [k2] 条，disclosureDate [最早]~[最晚]，[n2] 个有代码的标的）→ 主动买入 [J] 只
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

### 📝 备注
- 接近门槛的静默异动：[Ticker 市值 涨跌幅，报道 0 篇；没有就省略]
- SPAC 合并行情：[没有就省略]

### 📋 总结
[2-3 句话概括今日背离格局]

### 数据缺口
- [取不到市值的 ticker、因数量上限裁掉的候选、新闻没查到的 ticker、判为"常态波动"排除的票；没有就写"无"]
- 跌幅榜只到 [末行%]，跌幅在 −8% 到 [末行%] 之间的大市值股不在扫描范围内
- 内部人 Form 4 只覆盖 [n] 个申报日
```

## 输出规则

- 有信号的部分展开分析（可能的驱动、风险、后续关注点）；无信号的部分一行带过
- 情绪判断标"Claude 推断"
- 榜单是当日快照：非交易时段跑，反映的是上一个交易日
- 背离信号是"值得进一步研究"的线索，不是交易建议
