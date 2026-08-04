---
name: Macro Morning Brief
description: 每日财经早报（宏观/美股维度）— 宏观+新闻+异动三源聚合晨间简报。触发词：宏观日报、宏观早报、美股早报、美股日报、morning brief、morning briefing、今日市场。纯"日报"/"加密日报"不在本 Skill 范围内（本仓库无加密日报 Skill）。
trigger: 宏观日报、宏观早报、美股早报、美股日报、morning brief、morning briefing、今日市场、每日财经简报、macro morning brief、US stock daily、macro daily、financial morning brief
not_trigger: 策略信号、KOL、喊单、热点、加密日报、加密早报、日报、BTC宏观、黄金宏观、财报、earnings、strategy、KOL calls、trending、crypto daily、crypto brief、BTC macro、gold macro、earnings report、背离扫描/divergence（→03）
mcp: mcp__followin__metrics, mcp__followin__news
args: watchlist
---

# /morning-brief

每日财经早报 — 三源聚合晨间简报（Followin MCP 版）

## 意图路由

| 用户说的 | 走哪个 |
|---|---|
| 宏观日报 / 宏观早报 / 美股日报 / 美股早报 / morning brief / 今日市场 | ✅ 本 Skill |
| 日报 / 加密日报 / 加密早报 | ❌ 不在本 Skill 范围——本仓库已无加密日报 Skill，如实告知用户并建议改问宏观/美股早报，或直接用 `news()` 趋势模式（空 query + `asset_type="crypto"`，0 额度）|

不带"宏观/美股"修饰的纯"日报" → 默认指加密日报，属本 Skill 范围外。

## 参数

- `watchlist`（可选）：逗号分隔 ticker，默认从用户 memory 读取

> 🔗 **通用调用红线 + 已知问题登记**：以 `~/.claude/references/followin-mcp-caveats.md` 为准（仓库内 `references/`）。本文内联 caveat 是其镜像，冲突时以该文件为准。

## 数据层 — Followin MCP 三工具映射

🔒 **本 Skill 全程美股，metrics 调用必须带 `asset_type="tradfi"`**（除 BTC/ETH 等 crypto symbol）
🔒 **N-8（2026-08-04 实测仍复现）**：`keywords` / `categories` / `sources` 数组入参被 schema 拒，一律走 query 串（series_id/ticker 并入 query）；调用后核对 `meta.filters_applied.keywords` 差集

| 用途 | 调用 |
|---|---|
| 国债收益率（2Y / 10Y / 30Y）| `metrics(query="DGS2", limit=5)` + `metrics(query="DGS10", limit=5)` + `metrics(query="DGS30", limit=5)` 每 series 单独 fire（⚠️ N-8 数组被拒走 query 纯 series_id 串；红线 3 禁中文/混合语言 query——原 `query="treasury rates 美债收益率曲线"` 中英混搭违规；纯英文 "treasury rates" 有 N-14 撞 ticker 风险，优先 series_id 方案。批量会静默丢条目 B-31）|
| VIX 实时 | `metrics(query="^VIX 行情", asset_type="tradfi")` |
| 原油 + 美元 + watchlist | 🔄 `metrics(query="USO DXUSD AAPL TSLA ... 行情", asset_type="tradfi")` ⚠️ **`BZUSD` 已失效（静默丢弃，不报错）**，改用 USO；**一批最多 5 个 symbol**（超出静默截断且无任何 warning，N-23）；调用后核对 `meta.filters_applied.keywords` 差集 |
| 经济日历 | `metrics(query="economic calendar", country="US")` ⚠️ **必须传 `country="US"`，否则返非美事件（N-32）**；不要写"本周经济数据"——实测（2026-06-12）"本周"被解析成 lookback 7 天，返回**上周已发布历史**而非前瞻日历 |
| 异动榜 | 🔄 `metrics(query="most active stocks", asset_type="tradfi", limit=30)` ⚠️ **`biggest gainers/losers` 已弃用**（2026-07-27 实测返回 VYNE +2656%、SGLY +1429%，连"Fidelity 短期债券 ETF"都显示 +2009%，全是垃圾数据）。仍需二次调用补 marketCap |
| 财经新闻 | `news(query="<2-3 关键词>", time_range="1d", limit=10)` ⚠️ 不要传 asset_type；`sources` 数组被 schema 拒且无字符串替代（N-8）——早报**只解析 `articles` 桶、忽略 `social` 桶**（news 实返 2N 条 = articles + social 两桶，N-25；推特风向属 c4/14 的情绪层，混入会让早报变成情绪聚合）|

> **关键变化（vs v1）**：
> - 9 个老调用 → 5-7 个 Followin 调用
> - 删除 31 家媒体 users 列表
> - 删除 schema 修复 caveat（^VIX 不能批量、BZUSD 必须 batch、profile 走 stable_request 等都消失）
> - **`news()` 已支持 query 自然语言**，不需要"每个概念单独搜"
> - 经济日历直接 metrics 拿，不用 stable_request

## 执行步骤

### Step 1: 数据拉取（4 路并行，每批 ≤4 防 SSE 挂）

**Batch 1：国债 + VIX（4 个并行）**
```
1. metrics(query="DGS2", limit=5)     # FRED series 每个单独 fire（B-31）；query 纯 series_id，禁中文/混合语言（N-8/红线 3）
2. metrics(query="DGS10", limit=5)
3. metrics(query="DGS30", limit=5)
4. metrics(query="^VIX 行情", asset_type="tradfi")   # market ticker 不与 FRED series 混批（红线 4）
```

**Batch 2：商品/美元 + 日历 + 涨跌榜 + 新闻（4 个并行）**
```
5. metrics(query="USO DXUSD "+watchlist+" 行情", asset_type="tradfi")   # 🔄 BZUSD 已失效；每批 ≤5 symbol（静默截断无 warning），调用后核对 meta.filters_applied.keywords 差集
6. metrics(query="economic calendar", country="US")   # ⚠️ N-32：必须传 country="US" 否则返非美事件；别带"本周"，会变 lookback 历史
7. metrics(query="most active stocks", asset_type="tradfi", limit=30)   # 🔄 biggest gainers/losers 已弃用（返垃圾数据）
8. news(query="<根据宏观信号选 query>", time_range="1d", limit=8)
```

**Batch 3：第二路新闻（+ Step 2 的补市值调用放本批）**
```
9. news(query="stock market", time_range="1d", limit=8)    # 泛市场第二路，避免单一主题选题偏置
   # ⚠️ sources 数组被 schema 拒且无字符串替代（N-8）——两路 news 都只解析 articles 桶、
   #    忽略 social 桶（news 实返 2N 条两桶，N-25）：早报要权威报道，不混 twitter 情绪；
   #    news 实体搜索 quota=0，拆两路不增额度
```

⚠️ **`news()` query 设计**（实测验证）：
- 2-3 个核心名词，纯英文或纯中文
- 不写"影响 / 解读 / 分析" 等元词
- query 选择规则：
  - DGS10 变化 > 5bps → query="treasury yield"
  - VIX > 25 或日变化 > 10% → query="VIX volatility"
  - 原油日变化 > 3% → query="oil crude"
  - 有重要日历事件 → query="<事件名>"，例 "CPI inflation" / "Fed FOMC"
  - 地缘热点 → query="tariff trade" / "Iran"

### Step 2: 涨跌榜过滤（同 Skill 03）

mover 榜不返 marketCap，必须二次调用：
```
metrics(query="<gainers/losers tickers 空格拼接> 行情", asset_type="tradfi")
# N-8：keywords 数组被拒，ticker 并入 query 串；一批 ≤5 个（静默截断无 warning），超出分批，
# 调用后核对 meta.filters_applied.keywords 差集

客户端过滤:
- exchange in ["NYSE","NASDAQ","AMEX"]
- name 正则命中 `ETF|ETN|UltraPro|Ultra|Leveraged|\dX|Bull|Bear|Daily` 任一即剔
  （⚠️ 只判 "ETF" 单词会漏：TQQQ/SQQQ 的 name 都不含 "ETF" 字串）
- marketCap > $500M（市值闸为主）
- price > $5 仅在 marketCap 不可得时兜底——实测 GRAB $3.31 但市值 $131 亿，会被价格闸误杀
```

### Step 3: 分析与聚合

1. **宏观环境**：
   - 10Y-2Y 利差（正/负 = 正常/倒挂）
   - VIX 水平（<15 低 / 15-25 正常 / 25-35 偏高 / >35 恐慌）
   - 原油 + 美元趋势方向

2. **新闻热点**：
   - 两路 news（信号驱动 + 泛市场）合并后再多源去重（⚠️ 2026-08-04 实测 news 返回**无 cluster_id 字段**，可用字段仅 title/source_url/source_name/published_ts——按 `source_url` 去重 + 标题近似判重）
   - 提取 top 3 热门话题（不要只从单一 query 的结果选题）
   - Claude 推断每篇情绪聚合

3. **Watchlist + 异动**：
   - watchlist 涨跌 > 2% 标异动
   - 大盘涨跌榜过滤后保留
   - watchlist × 新闻 tags 交叉匹配

### Step 4: 输出报告

```
## 📊 财经早报 [日期]

### 宏观环境
| 指标 | 值 | 数据日期 |
|---|---|---|
| 10Y 国债 | X.XX% | YYYY-MM-DD |
| 2Y 国债 | X.XX% | YYYY-MM-DD |
| 利差 | XXbps | 正常 / 倒挂 |
| VIX | XX.X | 最近收盘 / 实时（按 _quote_session 判）|
| WTI（USO 代理）| $XX.XX | 非现货价；最近收盘 / 实时（按 _quote_session 判）|
| 美元指数 | XXX.X | 最近收盘 / 实时（按 _quote_session 判）|

> ⚠️ N-48 判据：早报跑在盘前时，metrics 返回的是**上一个 regular 收盘**（`_quote_session:"regular_inactive"` + `_quote_cache:"last_regular"`）——只有交易时段才标"实时"，否则一律标"最近收盘"；盘后/盘前的真实价以新闻为准。
> ⚠️ N-30：布油 BZUSD 已失效；USO 是 WTI 近月期货 ETF 代理指标，引用须说明口径。

### 📅 本周经济日历
| 日期 | 事件 | 预期 | 前值 | 重要性 |
|---|---|---|---|---|

### 🔥 今日热点 (Top 3)
1. [话题] — N 家媒体报道
   情绪判断: [正面 / 负面 / 中性]
   代表: "[标题]" — [来源]
2. ...
3. ...

### 📈 Watchlist 异动
| Ticker | 价格 | 涨跌% | 相关新闻 |
|---|---|---|---|

### 🏆 市场涨跌榜（已过滤市值 <$500M + 杠杆 ETF）
涨幅前 5: ...
跌幅前 5: ...

> 如过滤后 <3 个，注"今日大市值股无极端异动"

### 情绪分布
正面: XX 篇 | 中性: XX 篇 | 负面: XX 篇
整体市场情绪: [偏乐观 / 中性 / 偏悲观]

### ⚠️ 值得关注
- [交叉分析洞察]
- [即将发布的重要数据提醒]
```

## 注意事项（v2 — Followin MCP）

- 🔒 美股调用必须带 `asset_type="tradfi"`（除 BTC/ETH 等 crypto symbol）
- ⚠️ **`news()` 不要传 asset_type**（实测加 tradfi 返 0 results）
- 🔄 **mover 榜改用 `query="most active stocks"`**：`biggest gainers/losers` 已弃用（实测返 VYNE +2656%、"Fidelity 短期债券 ETF" +2009% 等垃圾数据）。异动榜同样**不返 marketCap**（不要传 `min_market_cap` — 上游 null 会被全屠），必须二次调用补
- ⚠️ **杠杆 ETF 污染**：过滤正则用 `name` 命中 `ETF|ETN|UltraPro|Ultra|Leveraged|\dX|Bull|Bear|Daily` 任一即剔 —— ⚠️ **不要只判 "ETF" 单词**，实测 `ProShares UltraPro QQQ`(TQQQ) / `ProShares - UltraPro Short QQQ`(SQQQ) 的 name 都不含 "ETF" 字串
- ⚠️ **经济日历必须传 `country="US"`**，否则返回 CN/JO/KR/MY 等非美事件（N-32）；国债 series_id 直查可用，但 **VIX / 美元等行情在盘前返回的是上一 regular 收盘（N-48）**，不要标"实时"（按 `_quote_session` 判）
- ❌ **布油 `BZUSD` 已失效**（2026-07-27 实测：query 串里被静默丢弃，不报错也不返数据——原"100% 命中"的记载已过期）。原油改用 `USO`（WTI 近月期货 ETF 代理，非现货价，引用须说明口径）
- ✅ **FRED 字典未命中走 fred_search_fallback** → 改用 `query="<series_id>"`（纯 series_id 串）兜底
- ⚠️ **B-31/红线 4 边界**：FRED macro series **不要批量**（静默丢条目），DGS2/DGS10 等各自单独 fire，且不与 market ticker 混批；market 行情快照可批量但**上限 5 个**（走 query 串时超出被**静默截断且无任何 warning**——旧"10 个 + `keyword_count_over_max` warning"是 keywords 数组时代行为，已失效）；watchlist 长时分批并核对 `meta.filters_applied.keywords` 差集
- 避免高并发：单批 ≤ 4 防 SSE 挂

## 输出约束（保留 v1）

- 数据来源透明（每个指标标 source）
- 不喊单 / 不预测
- 数字不编（用"约/接近"弱化）
- 经济日历事件标重要性 ⭐
- 多源同事件合并去重
