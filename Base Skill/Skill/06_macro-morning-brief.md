---
name: Macro Morning Brief
description: 每日财经早报（宏观/美股维度）— 宏观+新闻+异动三源聚合晨间简报。触发词：宏观日报、宏观早报、美股早报、美股日报、morning brief、morning briefing、今日市场。纯"日报"/"加密日报"不在本 Skill 范围内（本仓库无加密日报 Skill）。
trigger: 宏观日报、宏观早报、美股早报、美股日报、morning brief、morning briefing、今日市场、每日财经简报、macro morning brief、US stock daily、macro daily、financial morning brief
not_trigger: 策略信号、KOL、喊单、热点、加密日报、加密早报、日报、BTC宏观、黄金宏观、财报、earnings、strategy、KOL calls、trending、crypto daily、crypto brief、BTC macro、gold macro、earnings report
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

| 用途 | 调用 |
|---|---|
| 国债收益率（全期限）| `metrics(query="treasury rates 美债收益率曲线", categories=["macro"])` 一次返 yield curve 全期限 |
| 2Y / 10Y 美债 | `metrics(keywords=["DGS2"], categories=["macro"], limit=5)` + `metrics(keywords=["DGS10"], categories=["macro"], limit=5)` 兜底（⚠️ FRED series 单独 fire，批量会静默丢条目 B-31）|
| VIX 实时 | `metrics(keywords=["^VIX"], categories=["market"], asset_type="tradfi")` |
| 布油 + 美元 + watchlist | `metrics(keywords=["BZUSD","DXUSD","AAPL","TSLA",...], categories=["market"], asset_type="tradfi")` |
| 经济日历 | `metrics(keywords=["economic calendar"], categories=["macro"])` ⚠️ 不要写"本周经济数据"——实测（2026-06-12）"本周"被解析成 lookback 7 天，返回**上周已发布历史**而非前瞻日历 |
| 涨跌幅榜 | `metrics(query="biggest gainers"/"biggest losers", asset_type="tradfi", limit=30)` 二次调用补 marketCap |
| 财经新闻 | `news(query="<2-3 关键词>", sources=["media"], time_range="1d", limit=10)` ⚠️ 不要传 asset_type；早报取权威报道，**不混 twitter**（推特风向属 c4/14 的情绪层，混入会让早报变成情绪聚合）|

> **关键变化（vs v1）**：
> - 9 个老调用 → 5-7 个 Followin 调用
> - 删除 31 家媒体 users 列表
> - 删除 schema 修复 caveat（^VIX 不能批量、BZUSD 必须 batch、profile 走 stable_request 等都消失）
> - **`news()` 已支持 query 自然语言**，不需要"每个概念单独搜"
> - 经济日历直接 metrics 拿，不用 stable_request

## 执行步骤

### Step 1: 数据拉取（4 路并行，每批 ≤4 防 SSE 挂）

**Batch 1：宏观（4 个并行）**
```
1. metrics(query="treasury rates 美债收益率曲线", categories=["macro"])
2. metrics(keywords=["^VIX"], categories=["market"], asset_type="tradfi")
3. metrics(keywords=["BZUSD","DXUSD"]+watchlist, categories=["market"], asset_type="tradfi")
4. metrics(keywords=["economic calendar"], categories=["macro"])   # ⚠️ 别带"本周"，会变 lookback 历史
```

**Batch 2：涨跌榜 + 新闻（4 个并行）**
```
5. metrics(query="biggest gainers", asset_type="tradfi", limit=30)
6. metrics(query="biggest losers",  asset_type="tradfi", limit=30)
7. news(query="<根据宏观信号选 query>", sources=["media"], time_range="1d", limit=8)
8. news(query="stock market", sources=["media"], time_range="1d", limit=8)    # 泛市场第二路，避免单一主题选题偏置
   # ⚠️ 两路都显式 sources=["media"]：早报要权威报道，不混 twitter 情绪；news 实体搜索 quota=0，拆两路不增额度
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
metrics(keywords=[gainers/losers tickers], categories=["market"], asset_type="tradfi")

客户端过滤:
- price > $5
- exchange in ["NYSE","NASDAQ","AMEX"]
- name 不含 "2X"/"3X"/"Long"/"Short"/"Bull"/"Bear"/"Daily"/"Leveraged"（剔除杠杆 ETF）
- marketCap > $500M
```

### Step 3: 分析与聚合

1. **宏观环境**：
   - 10Y-2Y 利差（正/负 = 正常/倒挂）
   - VIX 水平（<15 低 / 15-25 正常 / 25-35 偏高 / >35 恐慌）
   - 原油 + 美元趋势方向

2. **新闻热点**：
   - 两路 news（信号驱动 + 泛市场）合并后再多源去重（cluster_id_v2 / cluster_id_v3）
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
| VIX | XX.X | 实时 |
| 布油 | $XX.XX | 实时 |
| 美元指数 | XXX.X | 实时 |

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
- ⚠️ **mover 榜（`query="biggest gainers"` / `query="biggest losers"`）不返 marketCap**（不要传 `min_market_cap` 参数 — 上游 marketCap 为 null 会被全屠），必须 keywords 二次调用补
- ⚠️ **杠杆 ETF 污染**（涨幅榜 17.5% 是 2X/3X 衍生品），客户端过滤 LEVERAGED_KEYWORDS
- ✅ **国债 / VIX / 布油 / 美元 / 经济日历都已 100% 命中**（实测验证）
- ✅ **FRED 字典未命中走 fred_search_fallback** → 改用 `keywords=["<series_id>"]` 兜底
- ⚠️ **B-31 边界**：FRED macro series **不要批量**（静默丢条目），DGS2/DGS10 等各自单独 fire；market 行情快照可批量但**上限 10 个**（实测 18→10 静默截断，watchlist 长时分批并检查 keyword_count_over_max warning）
- 避免高并发：单批 ≤ 4 防 SSE 挂

## 输出约束（保留 v1）

- 数据来源透明（每个指标标 source）
- 不喊单 / 不预测
- 数字不编（用"约/接近"弱化）
- 经济日历事件标重要性 ⭐
- 多源同事件合并去重
