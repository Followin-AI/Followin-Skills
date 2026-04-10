---
name: US Stock Divergence Scan
description: 信号背离扫描 — 发现价格、内部人交易与媒体报道之间的不一致。触发词必须明确指向"背离/静默异动/内部人买入"场景，如"背离扫描"、"有没有没新闻却大涨的"、"内部人悄悄买入"。泛问"有什么异常"走热点舆情，个股异动走代币舆情聚合。
trigger: 美股背离扫描、美股价格背离、美股背离信号、美股静默异动、美股无新闻异动、美股内部人买入、美股内部人悄悄买、美股没新闻大涨、美股没新闻大跌、美股silent moves、美股silent buy
not_trigger: 策略信号、KOL、喊单、热点、日报、财报、earnings、今天有什么消息、市场在关注什么
mcp: finance_tool_stable_request, finance_tool_biggest_gainers, finance_tool_biggest_losers, finance_tool_insider_trading_search, search_finance_news
---

# /divergence-scan

信号背离扫描 — 发现价格、内部人交易与媒体报道之间的不一致

## 参数

| 参数 | 必填 | 说明 |
|------|------|------|
| scope | 否 | 扫描范围，默认 `all`。可选 `sp500`、`nasdaq`、`watchlist` |
| days | 否 | 回溯天数，默认 7 |

## 意图路由

| 用户说的 | 走哪个Skill |
|---------|-----------|
| 背离扫描、异常信号、silent moves、有什么异常 | ✅ 本Skill（divergence-scan） |
| XX财报、XX earnings | ❌ 转 earnings-report |
| CPI影响、非农解读、宏观数据分析 | ❌ 转 macro-analyzer |
| 宏观日报、美股早报 | ❌ 转 morning-brief |

本Skill 聚焦**多标的批量扫描价格/内部人/媒体之间的背离信号**，不做单股财报、不做宏观指标解读、不做综合日报。

## 数据层工具映射

> **重要**: 大部分 `finance_tool_*` 工具 schema 已修复，可直接调用。
> 仍有 schema 问题的工具（`profile`、`stock_price_change`）需通过 `finance_tool_stable_request` 访问。

| 用途 | 调用方式 | 说明 |
|------|----------|------|
| 当日涨幅最大 | `finance_tool_biggest_gainers` | 直接调用，无参数 |
| 当日跌幅最大 | `finance_tool_biggest_losers` | 直接调用，无参数 |
| 公司基本信息 | `finance_tool_stable_request` path=`profile` | 市值、行业、公司名 |
| 多时间框架涨跌幅 | `finance_tool_stable_request` path=`stock-price-change` | 5D/1M/3M 涨跌幅 |
| 内部人交易搜索 | `finance_tool_insider_trading_search` | 直接调用，无参数。**`stable_request` path=`insider-trading` 返回 404，必须用此直调工具。`insider_trading_latest` 和 `insider_trading_transaction_type` 权限被拒，也不可用** |
| 媒体交叉验证 | `search_finance_news` | 关键词搜索 31 家财经媒体 |

## 四种背离信号

### 信号一：Silent Buy（内部人静默买入）

内部人大额买入 + 媒体无报道 = 知情人看好但市场未反应

```
检测:
1. finance_tool_insider_trading_search → 过去 [days] 天
2. 过滤条件:
   - transactionType = "P-Purchase"（排除 M-Exempt/S-Sale/F-InKind/A-Award/G-Gift 等非主动买入）
   - price × securitiesTransacted > $100K
3. 对每个 ticker 调 search_finance_news:
   - keyword: [companyName]（优先用公司名而非 ticker）
   - 时间: [days]天内
4. 判定: 主动买入 > $100K 且报道 ≤ 2 篇
```

### 信号二：Sentiment Mismatch（情绪错配）

股价走势与媒体情绪方向相反

```
检测:
1. 从 biggest_gainers/losers 中筛选 marketCap > $1B 的标的
   - 用 finance_tool_stable_request path="profile" 确认市值
2. 对每个 ticker 调 search_finance_news:
   - keyword: [companyName]
   - 获取 5-10 篇
3. Claude 根据 title + content 判断情绪倾向
4. 判定:
   - 股价涨 >5% 但文章情绪偏负面 = 利空不跌
   - 股价跌 >5% 但文章情绪偏正面 = 利好不涨
```

### 信号三：Unreported Drop（无声暴跌）

大市值股大幅下跌 + 主流媒体几乎无报道

```
检测:
1. 从 biggest_losers 中筛选 marketCap > $1B
2. 对每个 ticker 调 search_finance_news
3. 判定: 跌幅 >8% 且报道 ≤ 3 篇
```

### 信号四：Unreported Surge（无声暴涨）

显著涨幅 + 主流媒体几乎无报道 = 市场尚未关注的异动

```
检测:
1. 从 biggest_gainers 中筛选 marketCap > $500M
2. 对每个 ticker 调 search_finance_news
3. 判定: 涨幅 >20% 且报道 ≤ 2 篇
```

## 执行步骤

### Step 1: 数据拉取（并行）

```
并行调用:
1. finance_tool_biggest_gainers
2. finance_tool_biggest_losers
3. finance_tool_insider_trading_search
```

### Step 2: 市值过滤

```
从 Step 1 的 gainers/losers 中:
- 提取所有 ticker（去重）
- 用 finance_tool_stable_request path="profile" params={symbol: "TICKER"} 获取 marketCap
  - 可批量: 每次最多查 5 个 ticker，并行调用
- 过滤规则:
  - Sentiment Mismatch / Unreported Drop: marketCap > $1B
  - Unreported Surge: marketCap > $500M
  - Silent Buy: 不限市值（内部人买入本身就是信号）
- 丢弃不达标的 ticker，减少后续 API 调用量

如果 gainers/losers 中无 marketCap > $1B 的标的:
- 跳过 Sentiment Mismatch 和 Unreported Drop
- 在报告中注明"今日大市值股无极端异动"
```

### Step 3: 多时间框架补充（1次批量调用）

```
对 Step 2 保留的所有 ticker，用逗号拼接后一次查完:
- finance_tool_stable_request path="stock-price-change" params={symbol: "AAPL,TSLA,NVDA,..."}
- ✅ 已验证 stock-price-change 支持逗号分隔多 symbol 批量查询
- 获取 5D/1M/3M 涨跌幅
- 用于判断是单日异动还是持续趋势
```

### Step 4: 内部人交易筛选

```
从 Step 1 的 insider_trading_search 结果中:
- 只保留 transactionType = "P-Purchase"
- 计算 value = price × securitiesTransacted
- 只保留 value > $100K
- 如果当日无 P-Purchase，结果标注"今日无主动买入"
- 不回溯更早数据（控制 API 调用量）
```

### Step 5: 媒体交叉验证

```
对 Step 2-4 筛出的 ticker（去重后）:
- 调 search_finance_news
  - keyword: companyName（从 profile 获取，优于 ticker）
  - count: 5
  - not_before_ts: [days]天前的 unix 时间戳
- 控制量: 总 ticker > 15 个时，优先处理:
  a. 内部人买入金额 top 5
  b. 涨跌幅最极端的 top 10
- 每个 ticker 最多查一次
```

### Step 6: 信号判定

```
逐个 ticker 判定:

Silent Buy:
  insider P-Purchase > $100K && article_count ≤ 2

Sentiment Mismatch:
  |price_change| > 5% && marketCap > $1B
  && Claude 判断的情绪方向与价格相反

Unreported Drop:
  price_change < -8% && marketCap > $1B && article_count ≤ 3

Unreported Surge:
  price_change > +20% && marketCap > $500M && article_count ≤ 2

排序规则:
  多信号命中 > 单信号
  市值越大越前
  涨跌幅绝对值越大越前
```

### Step 7: 输出报告

```
## 🔍 背离信号扫描 — [日期]

扫描范围: [scope] | 回溯: [days]天
检测标的: [N]只 | 发现信号: [M]个

---

### ⚡ Sentiment Mismatch（情绪错配）

| Ticker | 公司 | 市值 | 日涨跌 | 月涨跌 | 媒体情绪 | 错配类型 | 报道数 |
|--------|------|------|--------|--------|---------|---------|--------|

**分析**: [对每个标的的核心判断，包括驱动因素和风险]

---

### 🔕 Silent Buy（内部人静默买入）

| Ticker | 公司 | 买入人 | 职位 | 买入金额 | 报道数 |
|--------|------|--------|------|---------|--------|

> 如无信号: "今日无主动买入（P-Purchase）记录"（一行带过）

---

### 📉 Unreported Drop（无声暴跌）

| Ticker | 公司 | 市值 | 跌幅 | 报道数 |
|--------|------|------|------|--------|

> 如无大市值命中: "今日无 $1B+ 市值标的极端下跌"（一行带过）

---

### 🚀 Unreported Surge（无声暴涨）

| Ticker | 公司 | 市值 | 涨幅 | 报道数 |
|--------|------|------|------|--------|

> 如无命中: "今日无 $500M+ 市值标的无声暴涨"（一行带过）

---

### ⚠️ 多重信号（同时命中 2+ 信号）
[重点标注，如有]

### 📋 总结
[2-3 句话概括今日背离格局 + 宏观背景]
```

## 输出规则

- **有信号的部分展开分析**，包括驱动因素、风险判断、后续关注点
- **无信号的部分一行带过**，不展开解释
- 信号排序: Sentiment Mismatch > Silent Buy > Unreported Drop > Unreported Surge
- 情绪判断标注为"Claude 推断"以区分机器 sentiment
- 背离信号不是交易建议，是"值得进一步研究"的线索

## 注意事项

- **大部分 FMP 工具已可直接调用**；`profile` 和 `stock_price_change` 仍需通过 `finance_tool_stable_request`（schema 未修复）
- **insider trading 只能用 `finance_tool_insider_trading_search` 直调**，`stable_request` path=`insider-trading` 返回 404
- **`finance_tool_insider_trading_latest` 和 `finance_tool_insider_trading_transaction_type` 权限被拒**，不可用
- biggest_gainers/losers 包含大量小微市值股，**必须用 profile 过滤市值后再做新闻交叉验证**
- insider_trading_search 返回所有交易类型，**只有 P-Purchase 才是主动买入信号**
- search_finance_news 的 keyword 用 companyName 效果远好于 ticker（如 "Avis Budget" > "CAR"）
- 去重: 同一 ticker 在多个筛选中出现，只查一次 search_finance_news
- stock-price-change 提供 1D/5D/1M/3M/6M/YTD/1Y 涨跌幅，用于区分单日闪崩和持续下跌
