---
name: US Stock Divergence Scan
description: 信号背离扫描 — 发现价格、内部人交易与媒体报道之间的不一致。触发词必须明确指向"背离/静默异动/内部人买入"场景，如"背离扫描"、"有没有没新闻却大涨的"、"内部人悄悄买入"。泛问"有什么异常"、单一个股异动不在本Skill范围。
trigger: 美股背离扫描、美股价格背离、美股背离信号、美股静默异动、美股无新闻异动、美股内部人买入、美股内部人悄悄买、美股没新闻大涨、美股没新闻大跌、美股silent moves、美股silent buy、US stock divergence scan、divergence scan、silent moves、silent buy、anomaly signals、unreported drop、unreported surge
not_trigger: 策略信号、KOL、喊单、热点、日报、财报、earnings、今天有什么消息、市场在关注什么、strategy、KOL calls、trending、daily brief、earnings report、what's hot、market focus
mcp: mcp__followin__metrics, mcp__followin__news, mcp__followin__signal
args: scope, days
---

# /divergence-scan

信号背离扫描 — 发现价格、内部人交易与媒体报道之间的不一致（Followin MCP 版）

## 参数

| 参数 | 必填 | 说明 |
|------|------|------|
| scope | 否 | 扫描范围，默认 `all` |
| days | 否 | 回溯天数，默认 7 |

## 意图路由

| 用户说的 | 走哪个Skill |
|---------|-----------|
| 背离扫描、异常信号、silent moves | ✅ 本Skill（泛问"有什么异常"不算——须明确指向背离/静默异动/内部人场景）|
| XX财报、XX earnings | ❌ 转 earnings-report |
| CPI影响、非农解读 | ❌ 无专门 Skill——模型直接用 metrics(macro)+news 分析，series_id 字典见 caveats 附表 A |
| 宏观日报、美股早报 | ❌ 转 morning-brief |

本Skill 聚焦**多标的批量扫描价格/内部人/媒体背离信号**。

> 🔗 **通用调用红线 + 已知问题登记**：以 `~/.claude/references/followin-mcp-caveats.md` 为准（仓库内 `references/`）。本文内联 caveat 是其镜像，冲突时以该文件为准。

## 数据层 — Followin MCP 三工具映射

> 🔒 **本 Skill 全程只查美股（tradfi），所有 `metrics()` 调用必须带 `asset_type="tradfi"`**
> 不带的话同名 ticker 会被错路由到 crypto 山寨币（实测 AMN→0.00479 USDT / WEST→0.00541 USDT），数据完全错位。

| 用途 | 调用 | 参数 |
|------|------|------|
| 当日异动榜（涨跌合一）| `metrics()` | 🔄 `query="most active stocks"`, **`asset_type="tradfi"`**, `limit=30` —— ⚠️ **`biggest gainers/losers` 已弃用**（2026-07-27 实测返 VYNE +2656%、SGLY +1429%、"Fidelity 短期债券 ETF" +2009%，全是仙股与数据错误）。异动榜一次同时含涨跌两侧，按 `changesPercentage` 正负分组，**省掉原来的两次调用** |
| 个股报价 + 市值 | `metrics()` | `keywords=["AAPL","TSLA",...]`, `categories=["market"]`, **`asset_type="tradfi"`** 一次最多 **10 个**（实测 18→10 静默截断，超出分批并检查 `keyword_count_over_max` warning）|
| 多时间框架历史 | `metrics()` | `keywords=["AAPL"]`, `categories=["market"]`, `query="历史走势 30 day chart"`, `time_range="1m"`, **`asset_type="tradfi"`** |
| 内部人交易 | `signal()` | `categories=["insider_trading"]`, `keywords=["AAPL"]`, **`asset_type="tradfi"`** |
| 媒体交叉验证 | `news()` | `query="[companyName 2 词]"`, `time_range="1w"` ⚠️ **不要传 asset_type**（实测加 tradfi 返 0 results）|

> **关键变化（vs v1）**：
> - 6 个老工具 → 3 个 Followin 工具
> - 删除 `stable_request` 兜底（profile / stock-price-change 都直接走 metrics）
> - 删除 31 家媒体 users 列表
> - insider 走 `signal()` 而不是 `insider_trading_search`（已实测 AAPL/NVDA 真实数据）
> - 价格 + 市值一次返回（snapshot 字段含 `marketCap`），不用单独调 profile

## 四种背离信号（保留）

### 信号一：Silent Buy（内部人静默买入）
内部人主动买入 + 媒体无报道 = 知情人看好但市场未反应

```
检测（⚠️ 必须全量扫描，不要只查涨跌榜 ticker — Silent 的本义是价格未动，上榜 = 已动）:
1. signal(categories=["insider_trading"], asset_type="tradfi", time_range="1w",
          limit=50, sort_by="amount")           # 1 次全量，替代旧版按榜单 ticker 逐个单查
2. 客户端过滤（实测 2026-06-12）:
   - formType="4" 且 transactionType="P-Purchase"（⚠️ formType 3 是初始持仓/期权申报
     不是交易，会聚簇污染——实测 SPCX 一家占 13 条）
   - price × securitiesTransacted > $100K
   - congress 记录（provenance="congress"）结构不同: type="Purchase" 且 amount 区间下限 ≥ $50K
   - 按 ticker 去重（同一人多笔合并金额）
3. 排除已上当日涨跌幅榜的 ticker（价格已动 ≠ silent；榜内 ticker 有内部人买入 → 归"多重信号"）
4. 对剩余 ticker 调 news(query="[companyName] 2-3 词", sources=["media","twitter"], time_range="1w")
   ⚠️ 本 Skill 必须同时取 media + twitter，**不可收窄成 media-only**：
      判定依据是"这只票有没有人在说"，只看媒体会把"推特热议但无媒体报道"的票
      误判成无声异动（假阳性）。research/telegram 不算美股公开报道，故排除
5. 判定: 主动买入 > $100K 且报道 ≤ 2 篇
   ⚠️ 报道数必须按红线 11 逐条 LLM 判相关性后计数，不能用 raw count（语义兜底会塞不相关内容）
```

### 信号二：Sentiment Mismatch（情绪错配）
股价走势与媒体情绪方向相反

```
检测:
1. metrics(query="most active stocks", asset_type="tradfi", limit=30) 拿异动榜（🔄 一次含涨跌两侧）
2. 客户端过滤: 先剔 ETF/杠杆，再二次调用补 marketCap > $1B（⚠️ 异动榜行**不带** marketCap）
3. 对每个 ticker 调 news 拿 5-10 篇
4. Claude 根据 title + content 判断情绪
5. 判定:
   - 涨 >5% 但情绪偏负面 = 利空不跌
   - 跌 >5% 但情绪偏正面 = 利好不涨
```

### 信号三：Unreported Drop（无声暴跌）
大市值股大幅下跌 + 主流媒体几乎无报道

```
检测:
1. metrics(query="most active stocks", asset_type="tradfi", limit=30) 取 changesPercentage < 0 一侧（🔄 可复用上一信号的结果，不必重调）
2. 客户端过滤 marketCap > $1B（需二次调用补）
3. 对每个 ticker 调 news
4. 判定: 跌幅 >8% 且报道 ≤ 3 篇
```

### 信号四：Unreported Surge（无声暴涨）
显著涨幅 + 主流媒体几乎无报道 = 市场尚未关注的异动

```
检测:
1. metrics(query="most active stocks", asset_type="tradfi", limit=30) 取 changesPercentage > 0 一侧（🔄 可复用前面的结果）
2. 客户端过滤 marketCap > $500M（⚠️ 需二次调用补市值；微盘妖股问题在异动榜依然存在，2026-07-27 实测 STAK +602% 市值仅 $0.93 亿）
3. 对每个 ticker 调 news
4. 判定: 涨幅 >20% 且报道 ≤ 2 篇
```

## 执行步骤

### Step 1: 拉涨跌幅榜 + 全量内部人扫描（3 路并行）

```
1. metrics(query="most active stocks", asset_type="tradfi", limit=30)   # 🔄 一次含涨跌两侧，替代原来的 gainers + losers 两次调用
2. （原 biggest losers 一路已并入上面，省 1 次调用）
3. signal(categories=["insider_trading"], asset_type="tradfi", time_range="1w",
          limit=50, sort_by="amount")
```
🔒 必须带 `asset_type="tradfi"`，否则同名 ticker 会被错路由到 crypto。

⚠️ **mover 榜只返回 7 个字段**（symbol / name / price / change / changesPercentage / exchange / _sub_category），**没有 marketCap** — 必须 Step 2 二次调用补市值。

### Step 2: 第一轮客户端过滤 + 补市值（关键）

mover 榜默认含 **3 类污染**，必须先过滤：

```python
# 污染 1：微盘妖股（pump-and-dump）
# 污染 2：杠杆 ETF 衍生品（不是真实异动信号）
# 污染 3：仙股（< $5）

LEVERAGED_KEYWORDS = ["2X", "3X", "Long", "Short", "Bull", "Bear", "Daily", "Leveraged"]

filtered = [
    x for x in (gainers + losers)
    if x.price > 5                                          # 排除仙股
    and x.exchange in ["NYSE", "NASDAQ", "AMEX"]            # 排除 OTC
    and not any(k in x.name for k in LEVERAGED_KEYWORDS)    # 排除衍生品
]

# 提取 ticker 列表（去重）
tickers = list({x.symbol for x in filtered})
```

然后**二次调用补市值**：
```
metrics(
  keywords=tickers[:10],         # ⚠️ 一次最多 10 个（实测 18→10 静默截断），超出分批
  categories=["market"],
  asset_type="tradfi"             # 🔒 必须，否则 AMN/WEST 等 ticker 会错路由到 crypto 山寨币
)

# 再用 marketCap 二次过滤
final_gainers = [x for x in result if x.marketCap > 500_000_000 and x.changePercentage > 20]
final_losers  = [x for x in result if x.marketCap > 1_000_000_000 and x.changePercentage < -8]
```

### Step 3: Silent Buy 候选构建（用 Step 1 的全量扫描结果，0 次新调用）

⚠️ **不要按涨跌榜 ticker 逐个查 insider** — 上榜 = 价格已动，永远扫不到真正的 Silent Buy（v2 旧版的设计缺陷）。聚簇问题用 `limit=50` + 客户端去重解决（实测 50 条 ≈ 30+ distinct ticker）。

```
candidates = [
  x for x in insider_scan          # Step 1 第 3 路的结果
  if (
    # SEC Form 4 主动买入
    (x.formType == "4" and x.transactionType == "P-Purchase"
     and x.price * x.securitiesTransacted > 100_000)
    # 或 国会议员买入（congress 记录结构不同：type / amount 是区间字符串）
    or (x.provenance == "congress" and x.type == "Purchase"
        and amount_lower_bound(x.amount) >= 50_000)
  )
  and x.symbol not in movers_tickers     # 价格静默才算 Silent
]
# 按 ticker 去重（同一人多笔合并金额）
# formType="3"（初始申报/期权，如实测 SPCX 13 条）直接丢弃 — 不是交易
```

榜内 ticker 如同时有内部人买入 → 不算 Silent Buy，归入"多重信号"段落加注。

### Step 4: 多时间框架补充（可选 1 次批量）

对 Step 2 保留的 ticker 一次性查历史走势区分单日异动 vs 持续趋势：
```
metrics(
  keywords=[ticker_list],         # ⚠️ 最多 10 个，超出分批
  categories=["market"],
  asset_type="tradfi",            # 🔒 必须（本 Skill 红线，漏传会错路由 crypto）
  query="历史走势 30 day chart",   # 历史 OHLCV 必须靠该 query 路由（同 11/14 实测）
  time_range="1m"
)
```

### Step 5: 媒体交叉验证

```
对去重后的 ticker = Step 2 榜单幸存者 + Step 3 Silent Buy 候选（合计 ≤15 个，超出按 insider 金额 + 涨跌幅 top 排序裁剪）:

news(
  query="[companyName] [行业关键词或主营]",   # 2 个核心名词，纯英文
  time_range="1w" 或 [days]天前的 ts,
  limit=5
  # ⚠️ 不要传 asset_type — 实测加 tradfi 返 0 results（is_tradfi 字段几乎全 false 老 bug）
  #   0 results 会让"报道 ≤ N"判定全部假阳性，比报错更危险
)

⚠️ query 设计三原则（实测验证，避免 0 results）:
1. 2-3 个核心名词，不超过 4 词
2. 纯中文 or 纯英文，不混搭
3. 不写"impact / 影响 / 解读" — embedding 过拟合 0 results
4. 单股票符号会被同名公司劫持（"CPI" → CPI Card），用全名

举例:
  AAPL    → query="Apple iPhone"
  TSLA    → query="Tesla Musk"
  NVDA    → query="NVIDIA AI chips"
  AVAX    → query="Avalanche blockchain"
```

### Step 6: 信号判定

```
Silent Buy:        insider P-Purchase > $100K && 不在当日涨跌榜 && articles ≤ 2
Sentiment Mismatch: |Δ| > 5% && mktCap > $1B && 情绪与价格相反
Unreported Drop:   Δ < -8% && mktCap > $1B && articles ≤ 3
Unreported Surge:  Δ > +20% && mktCap > $500M && articles ≤ 2

排序: 多信号命中 > 单信号；市值大者前；涨跌绝对值大者前
```

### Step 7: 输出报告

```
## 🔍 背离信号扫描 — [日期]

扫描范围: [scope] | 回溯: [days]天
检测标的: [N] 只 | 发现信号: [M] 个

---

### ⚡ Sentiment Mismatch（情绪错配）
| Ticker | 公司 | 市值 | 日涨跌 | 月涨跌 | 媒体情绪 | 错配类型 | 报道数 |

**分析**: [核心判断 + 驱动因素 + 风险]

---

### 🔕 Silent Buy（内部人静默买入）
| Ticker | 公司 | 买入人 | 职位 | 买入金额 | 报道数 |

> 无信号时一行带过: "今日无主动买入（P-Purchase）记录"

---

### 📉 Unreported Drop（无声暴跌）
| Ticker | 公司 | 市值 | 跌幅 | 报道数 |

> 无信号时: "今日无 $1B+ 市值标的极端下跌"

---

### 🚀 Unreported Surge（无声暴涨）
| Ticker | 公司 | 市值 | 涨幅 | 报道数 |

> 无信号时: "今日无 $500M+ 市值标的无声暴涨"

---

### ⚠️ 多重信号（同时命中 2+ 信号）
[重点标注]

### 📋 总结
[2-3 句话概括今日背离格局 + 宏观背景]
```

## 输出规则

- **有信号的部分展开分析**，包括驱动因素、风险判断、后续关注点
- **无信号的部分一行带过**，不展开解释
- 排序: Sentiment Mismatch > Silent Buy > Unreported Drop > Unreported Surge
- 情绪判断标注为"Claude 推断"
- 背离信号不是交易建议，是"值得进一步研究"的线索

## 注意事项（v2 — Followin MCP）

- 🔒 **本 Skill 全程美股，所有 metrics/signal 调用必须带 `asset_type="tradfi"`** —— 实测 AMN/WEST 等 ticker 不带会错路由到 crypto 山寨币（AMN→0.00479 USDT / WEST→0.00541 USDT）
- ⚠️ **`news()` 例外：不要传 asset_type**（实测加 tradfi 返 0 results，is_tradfi 字段几乎全 false 老 bug）——0 篇会让四种信号的"报道 ≤ N"判定全部假阳性
- 🔄 **mover 榜改用 `query="most active stocks"`**：`biggest gainers/losers` 已弃用（2026-07-27 实测全是仙股与数据错误，连"Fidelity 短期债券 ETF"都显示 +2009%）。异动榜同样**marketCap 缺失**（不要传 `min_market_cap` — 上游 null 会被全屠），必须二次调用补市值
- **异动榜三类污染必须过滤**：(1) 微盘妖股（实测 STAK +602% 市值 $0.93 亿）(2) 杠杆 ETF (3) 仙股
  - ⚠️ ETF 正则须为 `ETF|ETN|UltraPro|Ultra|Leveraged|\dX|Bull|Bear|Daily` —— **只判 "ETF" 单词会漏**（`ProShares UltraPro QQQ`/TQQQ 与 `ProShares - UltraPro Short QQQ`/SQQQ 的 name 都不含 "ETF"）
  - ⚠️ **慎用"仙股 <$5"闸**：实测误杀 GRAB（$3.31 但市值 $131 亿）。市值闸更准，价格闸只在市值不可得时兜底
- **`signal(insider_trading)` 全量扫描有聚簇但可用**（旧实测 20 条全 SHFS；2026-06-12 复测 50 条中 SPCX Form 3 占 13 条、仍有 30+ distinct ticker）——对策：`limit=50` + `sort_by="amount"` + 客户端按 ticker 去重 + 只留 `formType="4"` 的 `P-Purchase`（Form 3 是初始申报不是交易）。**不要回退到按榜单 ticker 单查**：既扫不到真 Silent Buy，调用数还多 ~15 倍
- **`signal(insider_trading)` 三源 fanout 完整**（已实测 2026-05-27 重新验证）：SEC Form 4（公司高管，14 条 / NVDA 1m）+ congress 政客披露（Pelosi 配偶 NVDA $1M-$5M Sale）一次返 15 条
- **`news()` query 三原则**：2-3 核心名词 / 不混搭中英 / 不写元词（影响/解读/impact）
- ⚠️ **news() 无匹配不返回空，返回语义兜底的不相关填充**（实测查 Quhuo/Navios 返的是 BoJ/伊朗宏观新闻）——**"报道 ≤ N"判定必须按逐条判断后的相关报道数计，不能用 raw count**，否则无声异动会被填充内容误判成"有报道"
- **避免高并发**：单次 ≤ 4 个 MCP 调用并发，否则 SSE session 可能挂
- **insider transactionType 类型**：
  - `P-Purchase` ✅ 主动买入（信号）
  - `S-Sale` ❌ 卖出
  - `M-Exempt` / `A-Award` / `F-InKind` ❌ 非主动（行权/授予/扣税）
  - `G-Gift` ❌ 赠予
  - `J-Other` ❌ 其他
