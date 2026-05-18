---
name: US Stock Divergence Scan (v2 — FollowX MCP)
description: 信号背离扫描 — 发现价格、内部人交易与媒体报道之间的不一致。触发词必须明确指向"背离/静默异动/内部人买入"场景，如"背离扫描"、"有没有没新闻却大涨的"、"内部人悄悄买入"。泛问"有什么异常"走热点舆情，个股异动走代币舆情聚合。
trigger: 美股背离扫描、美股价格背离、美股背离信号、美股静默异动、美股无新闻异动、美股内部人买入、美股内部人悄悄买、美股没新闻大涨、美股没新闻大跌、美股silent moves、美股silent buy、US stock divergence scan、divergence scan、silent moves、silent buy、anomaly signals、unreported drop、unreported surge
not_trigger: 策略信号、KOL、喊单、热点、日报、财报、earnings、今天有什么消息、市场在关注什么、strategy、KOL calls、trending、daily brief、earnings report、what's hot、market focus
mcp: mcp__followx__metrics, mcp__followx__news, mcp__followx__signal
args: scope, days
---

# /divergence-scan-v2

信号背离扫描 — 发现价格、内部人交易与媒体报道之间的不一致（FollowX MCP 版）

## 参数

| 参数 | 必填 | 说明 |
|------|------|------|
| scope | 否 | 扫描范围，默认 `all` |
| days | 否 | 回溯天数，默认 7 |

## 意图路由

| 用户说的 | 走哪个Skill |
|---------|-----------|
| 背离扫描、异常信号、silent moves、有什么异常 | ✅ 本Skill |
| XX财报、XX earnings | ❌ 转 earnings-report |
| CPI影响、非农解读 | ❌ 转 macro-analyzer |
| 宏观日报、美股早报 | ❌ 转 morning-brief |

本Skill 聚焦**多标的批量扫描价格/内部人/媒体背离信号**。

## 数据层 — FollowX MCP 三工具映射

> 🔒 **本 Skill 全程只查美股（tradfi），所有 `metrics()` 调用必须带 `asset_type="tradfi"`**
> 不带的话同名 ticker 会被错路由到 crypto 山寨币（实测 AMN→0.00479 USDT / WEST→0.00541 USDT），数据完全错位。

| 用途 | 调用 | 参数 |
|------|------|------|
| 当日涨幅榜 | `metrics()` | `sort_by="change_pct"`, **`asset_type="tradfi"`** |
| 当日跌幅榜 | `metrics()` | `sort_by="-change_pct"`, **`asset_type="tradfi"`** |
| 个股报价 + 市值 | `metrics()` | `keywords=["AAPL","TSLA",...]`, `categories=["market"]`, **`asset_type="tradfi"`** 一次最多 ~20 个 |
| 多时间框架历史 | `metrics()` | `keywords=["AAPL"]`, `time_range="1m"`, `interval="1day"`, **`asset_type="tradfi"`** |
| 内部人交易 | `signal()` | `categories=["insider_trading"]`, `keywords=["AAPL"]`, **`asset_type="tradfi"`** |
| 媒体交叉验证 | `news()` | `query="[companyName 2 词]"`, `time_range="1w"`, **`asset_type="tradfi"`** |

> **关键变化（vs v1）**：
> - 6 个老工具 → 3 个 FollowX 工具
> - 删除 `stable_request` 兜底（profile / stock-price-change 都直接走 metrics）
> - 删除 31 家媒体 users 列表
> - insider 走 `signal()` 而不是 `insider_trading_search`（已实测 AAPL/NVDA 真实数据）
> - 价格 + 市值一次返回（snapshot 字段含 `marketCap`），不用单独调 profile

## 四种背离信号（保留）

### 信号一：Silent Buy（内部人静默买入）
内部人主动买入 + 媒体无报道 = 知情人看好但市场未反应

```
检测:
1. signal(categories=["insider_trading"], time_range="1w")
2. 过滤:
   - transactionType = "P-Purchase"（排除 M-Exempt/S-Sale/F-InKind/A-Award/G-Gift 等）
   - price × securitiesTransacted > $100K
3. 对每个 ticker 调 news(query="[companyName] 2-3 词", time_range="1w")
4. 判定: 主动买入 > $100K 且报道 ≤ 2 篇
```

### 信号二：Sentiment Mismatch（情绪错配）
股价走势与媒体情绪方向相反

```
检测:
1. metrics(sort_by="change_pct") + metrics(sort_by="-change_pct") 拿涨跌幅榜
2. 客户端过滤: marketCap > $1B（snapshot 已带）
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
1. metrics(sort_by="-change_pct") 跌幅榜
2. 客户端过滤 marketCap > $1B
3. 对每个 ticker 调 news
4. 判定: 跌幅 >8% 且报道 ≤ 3 篇
```

### 信号四：Unreported Surge（无声暴涨）
显著涨幅 + 主流媒体几乎无报道 = 市场尚未关注的异动

```
检测:
1. metrics(sort_by="change_pct") 涨幅榜
2. 客户端过滤 marketCap > $500M（注意默认返回的是 NASDAQ 微盘妖股 AEHL +135%、YMAT +110% 等，必须过滤）
3. 对每个 ticker 调 news
4. 判定: 涨幅 >20% 且报道 ≤ 2 篇
```

## 执行步骤

### Step 1: 拉涨跌幅榜（2 路并行）

```
1. metrics(sort_by="change_pct",  asset_type="tradfi", limit=30)
2. metrics(sort_by="-change_pct", asset_type="tradfi", limit=30)
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
  keywords=tickers[:20],         # 一次最多 ~20 个
  categories=["market"],
  asset_type="tradfi"             # 🔒 必须，否则 AMN/WEST 等 ticker 会错路由到 crypto 山寨币
)

# 再用 marketCap 二次过滤
final_gainers = [x for x in result if x.marketCap > 500_000_000 and x.changePercentage > 20]
final_losers  = [x for x in result if x.marketCap > 1_000_000_000 and x.changePercentage < -8]
```

### Step 3: 内部人交易按 ticker 单查（不要查全量榜单）

⚠️ **`signal(insider_trading)` 不带 keyword 时，全量榜单会被同一家小公司 + 多笔 Form 4 拆分塞满**（实测 1w 内 20 条全是 SHFS）。

正确做法：对 Step 2 留下的 tickers 各调一次：
```
对每个 ticker (单批 ≤ 4 防 SSE 挂):
  signal(
    categories=["insider_trading"],
    keywords=[ticker],
    asset_type="tradfi",           # 🔒 必须
    time_range="1w",
    limit=10
  )

客户端过滤:
  insiders_filtered = [
    x for x in result
    if x.transactionType == "P-Purchase"          # 只要主动买
    and (x.price * x.securitiesTransacted) > 100_000
  ]
```

### Step 3: 多时间框架补充（可选 1 次批量）

对 Step 2 保留的 ticker 一次性查历史走势区分单日异动 vs 持续趋势：
```
metrics(
  keywords=[ticker_list],         # 最多 ~20 个
  categories=["market"],
  time_range="1m",
  interval="1day"
)
```

### Step 4: 媒体交叉验证

```
对去重后的 ticker（≤15 个，超出按 insider 金额 + 涨跌幅 top 排序裁剪）:

news(
  query="[companyName] [行业关键词或主营]",   # 2 个核心名词，纯英文
  asset_type="tradfi",                       # 🔒 必须，避免混入 crypto 内容
  time_range="1w" 或 [days]天前的 ts,
  limit=5
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

### Step 5: 信号判定

```
Silent Buy:        insider P-Purchase > $100K && articles ≤ 2
Sentiment Mismatch: |Δ| > 5% && mktCap > $1B && 情绪与价格相反
Unreported Drop:   Δ < -8% && mktCap > $1B && articles ≤ 3
Unreported Surge:  Δ > +20% && mktCap > $500M && articles ≤ 2

排序: 多信号命中 > 单信号；市值大者前；涨跌绝对值大者前
```

### Step 6: 输出报告

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

## 注意事项（v2 — FollowX MCP）

- 🔒 **本 Skill 全程美股，所有 metrics/signal/news 调用必须带 `asset_type="tradfi"`** —— 实测 AMN/WEST 等 ticker 不带会错路由到 crypto 山寨币（AMN→0.00479 USDT / WEST→0.00541 USDT）
- **mover 榜（sort_by）只返回 7 个字段**，**marketCap 缺失**，必须 keywords 二次调用补全
- **gainers/losers 三类污染必须过滤**：(1) 微盘妖股（AEHL/YMAT) (2) 仙股 < $5 (3) 杠杆 ETF（含 2X/3X/Long/Short/Bull/Bear/Daily/Leveraged 关键词的 name）
- **`signal(insider_trading)` 不带 keyword 时榜单聚簇**（同公司多笔 Form 4 塞满列表，1w 实测 20 条全 SHFS），必须按 ticker 单查
- **`signal(insider_trading)` 当前覆盖 SEC Form 4**（公司高管），实测 AAPL/NVDA 完美。⚠️ **政客交易（Pelosi 等 senate/house）尚未接入**，Dev 修复中
- **`news()` query 三原则**：2-3 核心名词 / 不混搭中英 / 不写元词（影响/解读/impact）
- **避免高并发**：单次 ≤ 4 个 MCP 调用并发，否则 SSE session 可能挂
- **insider transactionType 类型**：
  - `P-Purchase` ✅ 主动买入（信号）
  - `S-Sale` ❌ 卖出
  - `M-Exempt` / `A-Award` / `F-InKind` ❌ 非主动（行权/授予/扣税）
  - `G-Gift` ❌ 赠予
  - `J-Other` ❌ 其他
