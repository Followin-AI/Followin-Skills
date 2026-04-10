---
name: Macro Morning Brief
description: 每日财经早报（宏观/美股维度）— 宏观+新闻+异动三源聚合晨间简报。触发词：宏观日报、宏观早报、美股早报、美股日报、morning brief、morning briefing、今日市场。纯"日报"/"加密日报"走 06_日报_v2，不在本 Skill 范围内。
trigger: 宏观日报、宏观早报、美股早报、美股日报、morning brief、morning briefing、今日市场、每日财经简报
not_trigger: 策略信号、KOL、喊单、热点、加密日报、加密早报、日报、BTC宏观、黄金宏观、财报、earnings
mcp: finance_tool_quote, finance_tool_batch_quote_short, finance_tool_treasury_rates, finance_tool_economic_calendar, finance_tool_biggest_gainers, finance_tool_biggest_losers, finance_tool_stable_request, search_finance_news
---

# /morning-brief

每日财经早报 — 三源聚合晨间简报

## 意图路由

收到日报/早报类请求时，先判断维度再执行：

| 用户说的 | 走哪个Skill |
|---------|-----------|
| 宏观日报、宏观早报、美股日报、美股早报 | ✅ 本Skill（morning-brief） |
| morning brief、morning briefing、今日市场 | ✅ 本Skill（morning-brief） |
| 日报、加密日报、加密早报、出个日报 | ❌ 转 06_日报_v2 |

如用户输入包含"宏观"或"美股"修饰词，走本Skill；无修饰词的纯"日报"默认为加密日报，走 06_日报_v2。

## 参数

无必填参数。可选：
- `watchlist`: 逗号分隔的 ticker 列表，如 `AAPL,TSLA,NVDA`（默认使用用户 memory 中的 watchlist）

## 数据层工具映射

> **重要**: 大部分 `finance_tool_*` 工具 schema 已修复，可直接调用。
> 仍有 schema 问题的工具（`profile`）需通过 `finance_tool_stable_request` 访问。

| 用途 | 调用方式 | 参数 | 说明 |
|------|----------|------|------|
| 国债全期限 | `finance_tool_treasury_rates` | 无参数（可选 from/to） | 1次返回全部期限(2Y/10Y等)+60天历史 |
| VIX 实时 | `finance_tool_quote` | `symbol: "^VIX"` | ⚠️ ^VIX 不能批量 |
| 布油+美元+Watchlist | `finance_tool_batch_quote_short` | `symbols: "BZUSD,DXUSD,[watchlist]"` | 合并1次拉取 |
| 涨幅榜 | `finance_tool_biggest_gainers` | 无参数 | 需过滤市值 |
| 跌幅榜 | `finance_tool_biggest_losers` | 无参数 | 需过滤市值 |
| 经济日历 | `finance_tool_economic_calendar` | 无参数 | 返回全量数据（~2.4MB），需后处理过滤 |
| 公司信息(市值过滤) | `finance_tool_stable_request` | path=`profile`, params=`{symbol: "TICKER"}` | ⚠️ schema 未修复，仍需 stable_request |
| 财经新闻 | `search_finance_news` | keyword + users(array) + count | 多轮精准搜索 |

### 关键 path 对照表

| 需求 | 正确 path | 正确 params 键 | 错误示例（不可用） |
|------|----------|---------------|------------------|
| 批量报价 | `batch-quote-short` | `symbols` (逗号分隔) | ~~`batch-quote`~~, ~~`finance_data_batch_quote`~~ |
| VIX | `quote` | `symbol: "^VIX"` | ~~`index-quote`~~ (404) |
| 布油 | `quote` | `symbol: "BZUSD"` | ~~`commodities-quote`~~ (404) |
| 经济日历 | **直调 `finance_tool_economic_calendar`** | 无参数，无法过滤 | ~~`stable_request` path=`economic_calendar`~~ (404) |

## search_finance_news 关键词策略

⚠️ 不支持复合关键词（"tariff Iran oil" 返回空）。每个概念必须单独搜索。

**改用多轮精准搜索：**
```
第1轮: 搜索当前市场主题关键词（2-3个调用）
- 从 FRED + FMP 宏观数据中提取当日最大变动的方向
- 例如: VIX 飙升 → keyword: "volatility"
       原油大涨 → keyword: "oil"
       国债收益率突破关键位 → keyword: "treasury"

第2轮: 搜索地缘/事件驱动热点（1-2个调用）
- 基于经济日历和 Claude 的时事知识
- 例如: "tariff", "Fed", "earnings", "Iran" (每个单独搜)

每轮获取 10 篇，合计 20-30 篇。
users 参数必须为 array，填入全部31家媒体用户名。
```

## 执行步骤

### Step 1: 并行拉取实时 + 准实时数据（8-9个调用）

同时发起以下调用：

**国债收益率（1个 FMP 调用，替代 3 个 FRED 调用）：**
```
finance_tool_treasury_rates（无需参数，返回全部期限 + 60天历史）

→ 从返回数据中提取:
  - year10 → 10Y国债
  - year2 → 2Y国债
  - 利差 = year10 - year2（计算值）
→ 美元指数改用 FMP DXUSD（在下方 batch-quote-short 中已包含），不再调 FRED DTWEXBGS

✂️ 已移除 3 个 FRED 调用：DGS10、DGS2（→treasury-rates 一次搞定）、DTWEXBGS（→DXUSD）
```

**FMP 实时数据（2个直调）：**
```
1. finance_tool_quote:
   symbol: "^VIX"
   → 实时 VIX（⚠️ ^VIX 不能批量，会被静默过滤，必须单独调用）

2. finance_tool_batch_quote_short:
   symbols: "BZUSD,DXUSD,[watchlist逗号分隔]"
   → 布伦特原油 + 美元指数 + watchlist 报价合并一次拉取

4. finance_tool_economic_calendar (直接调用，无参数)
   → ⚠️ 返回全量数据 (~2.4MB)，包含全球所有事件
   → 需要用 Agent 工具或 bash 后处理：过滤 country="US" + 本周日期
   → 如果数据过大无法处理，降级方案：用 Claude 时事知识 + 新闻文章中提及的事件补充本周日历
```

**涨跌榜（2个直调，无参数）：**
```
finance_tool_biggest_gainers
finance_tool_biggest_losers
→ ⚠️ 返回结果几乎全是微市值股，必须后续用 profile 过滤
```

### Step 2: 市值过滤 + 新闻关键词确定

**涨跌榜过滤：**
```
从 biggest_gainers/losers 中:
- 先看返回数据中是否自带 marketCap 字段
- 如无，对涨跌幅最极端的 top 10 调 finance_tool_stable_request:
  path: "profile"
  params: {symbol: "[TICKER]"}
- 过滤掉 marketCap < $500M 的标的
- 保留大市值异动标的进入报告
```

**新闻关键词选择：**
```
根据 Step 1 的宏观数据，识别当日最显著变动:
- DGS10 变化 > 5bps → keyword 候选: "treasury"
- VIX > 25 或日变化 > 10% → keyword 候选: "volatility"
- 原油日变化 > 3% → keyword 候选: "oil"
- 经济日历有重要事件 → keyword 候选: 事件缩写 "CPI" "Fed" "NFP"
- Claude 根据近期时事 → keyword 候选: 地缘热点如 "tariff" "Iran"

选择 3-4 个最相关的关键词，每个单独调用 search_finance_news:
- count: 10
- not_before_ts: 24小时前的 unix 时间戳(秒)
- users: 全部31家媒体
```

### Step 3: 分析与聚合

1. **宏观环境判断**：
   - 计算 10Y-2Y 利差（正/负 → 正常/倒挂）
   - VIX 水平（<15 低波动, 15-25 正常, 25-35 偏高, >35 恐慌）
   - 原油和美元趋势方向

2. **新闻热点提取**：
   - 从多轮搜索结果中去重（同一 source_url）
   - 按 title + content 提取高频话题
   - 利用 tags 字段识别被多篇文章提及的 ticker/项目
   - Claude 推断每篇情绪，聚合为 top 3 热门话题

3. **Watchlist + 市场异动**：
   - 标记 watchlist 中涨跌幅 > 2% 的异动股
   - gainers/losers 过滤掉市值 < $500M
   - 交叉匹配 watchlist 与新闻 tags

### Step 4: 生成报告

```
## 📊 财经早报 [日期]

### 宏观环境
| 指标 | 值 | 来源 | 数据时效 |
|------|---|------|---------|
| 10Y国债 | X.XX% | FRED DGS10 | [日期] |
| 2Y国债 | X.XX% | FRED DGS2 | [日期] |
| 利差 | XXbps | 计算值 | [正常/倒挂] |
| VIX | XX.X | FMP quote | 实时 |
| 布油 | $XX.XX | FMP quote | 实时 |
| 美元指数 | XXX.X | FRED DTWEXBGS | [日期] |

### 📅 本周经济日历（via stable_request economic_calendar）
| 日期 | 事件 | 预期 | 前值 | 重要性 |
|------|------|------|------|--------|
| ... | ... | ... | ... | ⭐⭐⭐ |

> 如经济日历 stable_request 无法按日期过滤，改用 Claude 知识补充本周关键事件

### 🔥 今日热点 (Top 3)
1. [热点话题] — 被 X 家媒体报道
   情绪判断（Claude 推断）: [正面/负面/中性]
   代表文章: "[标题]" — [来源] [source_url]
2. ...
3. ...

### 📈 Watchlist 异动
| Ticker | 价格 | 涨跌幅 | 相关新闻 |
|--------|------|--------|---------|
| AAPL   | $XXX | +X.X%  | "[标题]" (来源) |

### 🏆 市场涨跌榜（当日，已过滤市值 <$500M）
涨幅前5: ...
跌幅前5: ...

> 如过滤后可选标的 <3 个，注明"今日大市值股无极端异动"

### 情绪分布（Claude 推断）
正面: XX篇 | 中性: XX篇 | 负面: XX篇
整体市场情绪倾向: [偏乐观/中性/偏悲观]

### ⚠️ 值得关注
- [交叉分析洞察]
- [经济日历即将发布的重要数据提醒]
```

## 注意事项

- **大部分 FMP 工具已可直接调用**；`profile` 仍需通过 `finance_tool_stable_request`（schema 未修复）
- **VIX 用 `quote` path + `symbol: "^VIX"`**，不存在 `index-quote` path
- **原油用 `quote` path + `symbol: "BZUSD"`**，不存在 `commodities-quote` path
- **ETF/股票批量报价用 `batch-quote-short` path + `symbols` 参数**
- **经济日历用 `economic_calendar` path + `from`/`to` 参数**避免全量返回（无参数直调返回 2.4MB）
- **`fred_get_series` 的 limit 必须传 integer**（如 `5`），不能传 string
- **FRED 数据可能有 null 值**，跳过处理
- **`search_finance_news` 不支持复合关键词**，每个概念单独搜索
- **`search_finance_news` 的 users 参数必须为 array 类型**
- **biggest_gainers/losers 几乎全是微市值股**，必须用 profile 过滤 marketCap > $500M 后再展示
- **经济日历降级方案**：若直调 `finance_tool_economic_calendar` 返回数据过大（>1MB）无法处理，改用 Claude 时事知识 + 新闻文章中提及的经济事件补充本周日历，并标注"经济日历数据来源: Claude 知识 + 新闻报道"
- **FRED 可能间歇性返回 500 错误**，降级方案：用 `finance_tool_stable_request` path=`economic-indicators` 获取替代数据
