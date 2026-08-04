---
name: US Stock Earnings Report
description: 单股财报三维分析（财务Beat/Miss + 媒体情绪 + 宏观背景）。必须指定具体股票代码或公司名才触发，如"帮我看AAPL财报"、"TSLA earnings"、"英伟达财报分析"。泛问"今天有哪些财报"不在本Skill范围——⚠️ 且**市场级财报日历已实测不可用（N-22）**，不要直查；要按名单核实财报日期请用 next_earnings_estimate 逐只查。
trigger: 帮我看XX财报、XX财报分析、XX财报速查、XX earnings、XX earnings report、[股票代码]财报、[公司名]财报、[ticker] earnings、earnings report、earnings analysis、show me [ticker] earnings、look at [ticker] earnings
not_trigger: 全面分析、多维度分析、值不值得买、深度分析（→01）、策略信号、KOL、喊单、热点、日报、背离扫描、divergence、strategy、KOL calls、trending、daily brief、divergence scan、morning brief
mcp: mcp__followin__metrics, mcp__followin__news, mcp__followin__signal
args: ticker
---

# /earnings-report $ARGUMENTS

单股财报分析 — 财务数据 + 媒体覆盖 + 宏观背景三维（Followin MCP 版）

## 参数

| 参数 | 必填 | 说明 |
|------|------|------|
| ticker | 是 | 股票代码，如 AAPL、TSLA、NVDA |

## 意图路由

| 用户说的 | 走哪个Skill |
|---------|-----------|
| XX财报、XX earnings、财报分析 | ✅ 本Skill |
| CPI影响、非农解读 | ❌ 无专门 Skill——模型直接用 metrics(macro)+news 分析，series_id 字典见 caveats 附表 A |
| 宏观日报、美股早报 | ❌ 转 morning-brief |
| 背离扫描 | ❌ 转 divergence-scan |

> 🔗 **通用调用红线 + 已知问题登记**：以 `~/.claude/references/followin-mcp-caveats.md` 为准（仓库内 `references/`）。本文内联 caveat 是其镜像，冲突时以该文件为准。

## 数据层 — Followin MCP 三工具映射

🔒 **本 Skill 全程美股，所有调用必须带 `asset_type="tradfi"`**（避免 ticker 错路由到 crypto 山寨币）
🔒 **N-8（2026-08-04 实测仍复现）**：`keywords` / `categories` / `sources` 数组入参被 schema 拒，一律走 query 串（ticker/series_id 并入 query）；调用后核对 `meta.filters_applied.keywords` 差集

| 用途 | 调用 |
|------|------|
| **基本面真聚合**（含 profile / 三表 / 估值 / 评级 / shares_float / beat-miss / consensus / eps_trend / latest_quarter / next_earnings / financial_growth / sec_filings — 14 block，唯独缺 stock_peers）| `metrics(query="<T> 全面分析", asset_type="tradfi")` |
| 行情快照（price / change / volume / dayHigh/Low / yearHigh/Low / marketCap）| `metrics(query="<T> 行情", asset_type="tradfi")`（批量 ≤5 个，超出静默截断且无任何 warning——红线 4）|
| 多时间框架历史 OHLCV | `metrics(query="<T> 历史走势", asset_type="tradfi", time_range="1y")` |
| 技术指标（按需）| `metrics(query="<T> 相对强弱 指标", asset_type="tradfi", period=14)` 或 `query="<T> 均线 指标"` |
| 媒体覆盖 | `news(query="<companyName> <ticker>", time_range="2w", limit=10)` 读 `articles` 桶（sources 数组被拒无字符串替代 N-8；news 实返 2N 条 = articles + social 两桶 N-25；**不要带 asset_type**，实测会返 0）|
| 推特风向（可选）| `news(query="<companyName> <ticker>", time_range="1w", limit=10)` 读 `social` 桶 |
| **机构研报·结构化**（目标价 / rating_action / thesis / key_caveat / latest_catalyst）| `metrics(query="<TICKER> research reports", asset_type="tradfi", verbosity="detail", time_range="7d")` ⚠️ warning 误报见 N-21 |
| **研报原始文章**（官方尽调编排的 `news(["research"])` 一环，quota=0）| `news(query="<companyName> <ticker>", time_range="2w", limit=10)`——`sources=["research"]` 被 schema 拒且无字符串替代（N-8/N-59），研报类客户端近似识别：articles 桶 `source_quality=="research"`（Motley Fool 会混入）+ social 桶 `kol_info.categories` 含 "research" |
| **信号面 fanout**（内部人 Form 4 + 国会 + 13F + KOL 喊单，**一次 1 额度拿三类**）| `signal(query="<T>", asset_type="tradfi", limit=20)` — **省略 `categories` 才 fanout**（N-4 不变；N-59f：signal 的数组入参同样被拒，走 query 串）|
| 宏观（按行业）| `metrics(query="DGS10", limit=5)` 等（见行业映射表；FRED query 只放纯 series_id，每 series 单独 fire）|

## EPS 数据源说明（保留 v1）

⚠️ Followin fundamentals 聚合返回两种 EPS：

| 来源 | 字段 | 含义 | 用途 |
|------|------|------|------|
| `beat_miss` block | epsActual / epsEstimated | **Adjusted EPS** | Beat/Miss 判定 |
| `latest_quarter` block | eps | **GAAP Diluted EPS** | 趋势分析 |
| `income_statement` block | epsdiluted | **GAAP EPS 历史** | 4Q YoY/QoQ 对比 |
| `eps_trend` block | eps（4 quarters）| **GAAP EPS 趋势** | 趋势表 |

**规则**：
- Beat/Miss 判定：用 `beat_miss.epsActual` vs `beat_miss.epsEstimated`
- 趋势表：两列并列 `Adj. EPS`（来源 beat_miss）+ `GAAP EPS`（来源 income_statement）
- Adjusted 与 GAAP 差异 > 30% 在分析中标注

### ⚠️ 四条财报陷阱（硬闸，Beat/Miss 判定前必读）

1. **N-15 财报当晚 beat_miss 仍是上一季**（实测 GOOGL 盘后发 Q2，当晚返回的仍是 Q1，FMP 侧延后更新）——财报当晚的"实际 vs 预期"一律取 `news()` 媒体/披露原文，metrics 只用于盘后快照与目标价；**次日后才可用 beat_miss 复核**。
2. **N-29 反号即口径错位**：`beat_miss.epsActual` 与 `latest_quarter.eps` **反号即判定口径错位**（非 GAAP vs GAAP，实测 INTC 0.42 vs −2.16——只看 beat_miss 会把巨亏季读成"完美超预期"），强制标注"该超预期为非 GAAP 口径"。原"差异 >30% 标注"规则保留，但**反号才是硬判据**。
3. **N-33 null 伪装成 -100%**：`revenueActual` 为 null 时服务端把 null 当 0 减，输出 `revenue_surprise_pct: -100`——那是缺失不是暴跌。**第 4 道检查 = `revenueActual` 非 null 才可读 surprise_pct**；见 -100 一律先当缺失查证。同季确认用 `gap = beat_miss.date − latest_quarter.date < 90 天`（公布日 vs 季末日天然不相等，**不能直接比日期相等**）；不同季则 N-29 反号判定作废并标"口径无法核对"。
4. **N-54 最新季 YoY 不在 4 季窗口**：季度数组只返最近 4 季，最新季 YoY 的对比季（去年同期）拿不到——趋势表只做 QoQ，YoY 一律标"需外源"；**别把 3 季前那季当去年同期**。

## 执行步骤

### Step 1: fundamentals 真聚合（1 次拿全 14 个 block）

⚠️ **必须显式带 `query="[T] 全面分析"`** 才走 `comprehensive` intent（N-8：keywords/categories 数组被拒，ticker 并入 query 串）。query 不含意图词走 default 只返 5 block。

```
metrics(query="[T] 全面分析", asset_type="tradfi")
→ intent_label="comprehensive"，含 14 block：
   1. beat_miss (Adj EPS Beat/Miss)
   2. consensus_price (目标价共识)
   3. eps_trend (4Q EPS)
   4. latest_quarter (Q 最新)
   5. next_earnings_estimate (下次财报预测)
   6. income_statement (4Q × 30+ 字段)        ← 利润表
   7. balance_sheet (4Q × 60+ 字段)            ← 资产负债表
   8. cash_flow (4Q × 35+ 字段)                ← 现金流量表
   9. financial_growth (FY × 4 年增速)
   10. valuation_block (dcf + ev + key_metrics_ttm + ratios_ttm)
   11. profile_block (CEO / sector / IPO / beta / website)
   12. sec_filings (近 10 条 SEC 文件)
   13. analyst_grades (20 条评级历史)
   14. shares_float (流通股)
   ❌ stock_peers (Followin MCP 当前不可得，已上报 dev 修复)
```

**等价 trigger**：`query="[T] comprehensive analysis"` 也可（精确双词）。

⚠️ **不要用的 trigger**：
- 不带 query → `_intent_label: "default"`，只返 5 block
- `query="comprehensive"` 单词 → default

**可选追加**（按需展开单独 sub-intent，ticker 并入 query）：
- `query="[T] 现金流量表"` → cashflow_detail + financial_growth
- `query="[T] 公司简介 profile"` → profile_block
- `query="[T] 评级变化 grades"` → analyst_grades 30 条
- `query="[T] 流通股 shares float"` → shares_float

**Batch B — market 行情 + 历史 + 技术指标**：
```
2. metrics(query="[T] 行情", asset_type="tradfi")
   → 现价 snapshot: price / change / volume / dayHigh/Low / yearHigh/Low / marketCap
   → ⚠️ change 是美元变动量不是百分比（N-47），百分比自算 change/previousClose×100

3. metrics(query="[T] 历史走势", asset_type="tradfi", time_range="1y")
   → 1y daily OHLCV，自算多周期涨跌（1D/5D/1M/3M/6M/YTD/1Y）

4. metrics(query="[T] 相对强弱 指标", asset_type="tradfi", period=14)
   → ⚠️ 实测（2026-08-04, N-69）该调用**一次 fanout 返回全部 9 个指标**（adx/rsi/dema/wma/williams/ema/tema/sma/standarddeviation），按 `indicator` 字段筛，**不必分开调用**。禁写英文指标名（"EMA 50"/"SMA 200" 会被劫持成同名 ticker）。
```

### Step 2: 媒体覆盖

```
news(
  query="[CompanyName] [TICKER]",   # 例: "Apple AAPL" / "Tesla TSLA" / "NVIDIA NVDA"
  time_range="1w" 或 "2w",
  limit=10
  # news 无 sort_by（相关性走 search_depth，默认 standard）
  # ⚠️ 不要传 asset_type="tradfi" — 实测会返 0 results（is_tradfi 字段几乎全 false 老 bug）
)

⚠️ query 三原则:
1. 2-3 个核心名词
2. 公司名 + ticker（提升精度，避免泛搜）
3. 不写"earnings 影响 解读"等元词
```

### Step 3: 宏观背景（按行业）

从 fundamentals 拿 `profile_block.sector` 和 `industry`，按映射调宏观：

> 🔒 v4 修复：行业宏观 **全部走 query 纯 series_id 串直查**（N-8：`keywords=[...]` 数组被 schema 拒；
> query 禁中文/混合语言——"WTI 原油" 返 crypto OIL + ETN / "30 年抵押贷款" 错抓 DGS30 国债即中文语义陷阱的实测翻车记录）。
> ⚠️ FRED series 每个单独 fire（批量静默丢条目 B-31），且**不与 market ticker（^VIX 等）混批**（红线 4）。

| Sector | 调用 |
|---|---|
| Technology | `metrics(query="DGS10", limit=5)` + `metrics(query="^VIX 行情", asset_type="tradfi")`（FRED 与 market 拆两条，不混批）|
| Semiconductors | + `metrics(query="USO", asset_type="tradfi")` 🔄 + `metrics(query="PCEPILFE", limit=5)` |
| Energy | `metrics(query="USO", asset_type="tradfi")` 🔄 ⚠️ CLUSD 已失效，见 N-30 |
| Financials | `metrics(query="DGS10", limit=5)` + `metrics(query="DGS2", limit=5)`（每 series 单独 fire）|
| Consumer | `metrics(query="RSAFS", limit=5)` + `metrics(query="CPIAUCSL", limit=5)` |
| Real Estate | `metrics(query="MORTGAGE30US", limit=5)` ⚠️ 不要写 "30 年抵押贷款" |
| Healthcare | `metrics(query="CPIAUCSL", limit=5)` ⚠️ CPIMEDSL 暂不在 Followin 字典（被错抓到 headline CPI，B-33），退而用 headline CPI |
| 其他 | `metrics(query="DGS10", limit=5)` + `metrics(query="^VIX 行情", asset_type="tradfi")`（拆两条，不混批）|

### Step 4: 三维分析

#### 维度一：财报表现（Beat / Miss / In-line）

从 `beat_miss` 取 Adjusted EPS:
```
- Beat:   epsActual > epsEstimated × 1.02
- Miss:   epsActual < epsEstimated × 0.98
- In-line: ±2% 内
```

从 `income_statement` 取 4 quarters GAAP EPS / Revenue 计算 QoQ（⚠️ N-54：最新季 YoY 的对比季不在 4 季窗口，YoY 需外源，别把 3 季前当去年同期）。

趋势:
- 是否连续 beat？
- Revenue / EPS QoQ 增速加速 / 减速？（YoY 需外源，N-54）
- Adjusted vs GAAP 差异 > 30%？反号即口径错位（N-29 硬判据）

#### 维度二：媒体覆盖与情绪

从 news() 10 篇文章，Claude 逐篇分析：
- 情绪偏向（正面 / 负面 / 中性）
- 高频关键词
- 代表性报道（标题 + 来源 + URL）
- 标注"Claude 推断"

#### 维度三：宏观一致性 + 价格动量

1Y 时间序列计算多周期涨跌：
```
1D = (今日 - 昨日) / 昨日
5D = (今日 - 5 日前) / 5 日前
1M = (今日 - 21 日前) / 21 日前
3M = (今日 - 63 日前) / 63 日前
6M = (今日 - 126 日前) / 126 日前
YTD = (今日 - 年初) / 年初
1Y = (今日 - 252 日前) / 252 日前
```

交叉验证:
- 财报 Beat + 情绪正面 + 宏观顺风 + 价格上行 = 强多信号
- 财报 Beat + 情绪负面 = 市场在担心什么？
- 财报 Miss + 价格未跌 = 已 price in？
- 财报 Beat + 宏观逆风 + 价格下行 = 板块 beta 拖累

### Step 5: 输出报告（同 v1 格式）

```
## 📋 [TICKER] 财报速查 — [CompanyName]

### 基本信息
行业: [sector] / [industry] | 市值: $[mktCap] | 当前价: $[price] ([change/previousClose×100]%，自算)
CEO: [ceo] | IPO: [ipoDate] | Beta: [beta]
⚠️ N-47：snapshot 的 change 是美元变动量不是百分比——别拿 change 去和新闻里的 % 交叉核实（会得到假的"核实通过"）

### 价格动量
| 1D | 5D | 1M | 3M | 6M | YTD | 1Y |
|----|----|----|----|----|-----|-----|

### 最新季度财报 [Q? FY????]
| 指标 | 实际 | 预期 | 差异 | 判定 |
|------|------|------|------|------|
| EPS (Adjusted) | $X.XX | $X.XX | +X.X% | ✅ Beat |
| EPS (GAAP) | $X.XX | — | — | 参考 |
| Revenue | $X.XB | $X.XB | +X.X% | ✅ Beat |

> ⚠️ Adjusted 与 GAAP EPS 差异 XX%（仅在 >30% 时显示）

### 趋势（最近 4 季度）
| 季度 | Revenue | QoQ | Adj. EPS | QoQ | GAAP EPS | Beat/Miss |
|------|---------|-----|----------|-----|----------|-----------|

> ⚠️ N-54：4 季窗口拿不到最新季的去年同期，本表只做 QoQ；YoY 如需展示须标"数据源外部"

### 关键比率 (TTM)
PE: XX.X | PS: X.X | ROE: XX.X% | D/E: X.X | Gross Margin: XX.X%

### 📈 长期增长预期
| 期间 | 预期 EPS | 预期 Revenue | EPS 增速 |
|------|---------|-------------|---------|

隐含 PEG: [当前 PE / 预期年化 EPS 增速]

### 🏢 公司画像（profile_block）
- 主营: [description 摘要 200 字]
- 同行: 数据不可用（comprehensive 缺 stock_peers，Dev 待修）

### 📊 分析师评级（analyst_grades 最近 10 条）
- maintain Buy: X 家
- upgrade Buy: X 家
- downgrade Hold: X 家

### 📰 媒体覆盖 (近 2 周, N 篇报道)
情绪判断（Claude 推断）: [偏正面/中性/偏负面]
正面: X篇 | 负面: X篇 | 中性: X篇
热门话题: [关键词1], [关键词2]

代表性报道:
- "[标题]" — [来源] ([日期])

### 🌐 宏观背景
- [宏观指标]: [值] → 对[sector]影响: [利好/利空/中性]

### 🔍 三维交叉判断
[综合 Beat/Miss + 情绪 + 宏观 + 动量的结论]
[如有不一致信号，明确指出分歧点和可能原因]
```

## 输出规则

- Beat/Miss 数据来源标 `beat_miss block (Adjusted EPS)`
- 趋势表同时展示 Adjusted 和 GAAP EPS
- Adjusted 与 GAAP 差异 > 30% 专门标注
- 情绪判断标"Claude 推断"
- 财报分析不是交易建议，是"值得进一步研究"的线索

## 注意事项（v2 — Followin MCP）

- 🔒 **`asset_type="tradfi"` 必须**（除 news），否则 ticker 名同 crypto 山寨币会错路由
- ⚠️ **news() 不要传 asset_type**（实测加 tradfi 返 0 results，is_tradfi 字段几乎全 false 老 bug）
- ✅ **fundamentals 真聚合**：**必须显式 `query="<T> 全面分析"`**（N-8：ticker 并入 query 串）才走 comprehensive intent（query 不含意图词走 default 只 5 block）；comprehensive 返 14 block，仅缺 stock_peers（Followin dev 待修）
- 单独 sub-intent 触发词（仅在不需要全套时用，ticker 并入 query）：
  - `query="<T> 利润表"` = income_statement only（1.4K tokens 节省）
  - `query="<T> 资产负债表"` = balance_sheet only
  - `query="<T> 现金流量表"` = cashflow + financial_growth
  - `query="<T> 估值"` = valuation_block only
  - `query="<T> 评级变化"` = analyst_grades only
- **多周期涨跌**：用 `query="<T> 历史走势"` + `time_range="1y"` 拿 1y daily OHLCV 自算（market snapshot 不含 priceAvg50/200）
- **技术指标 RSI / EMA / SMA**：一次 `query="<T> 均线 指标"` 即 fanout 全部 9 个指标，按 `indicator` 字段筛（实测 2026-08-04） / `query="<T> 均线 指标"`（不要靠默认 fanout）
- **`news()` query 三原则**：2-3 核心名词 / 不混搭中英 / 不写元词；`sources=` 数组已被 schema 拒且无字符串替代（N-8/N-59）——**分源改在客户端做**：报道读 `articles` 桶、风向读 `social` 桶（news 实返 2N 条两桶，N-25）
- **避免高并发**：单批 ≤ 4 路并发，否则 SSE 可能挂
- **`metrics()` FRED 字典未命中走 fred_search_fallback** → 改用 `query="<series_id>"`（纯 series_id 串）兜底
- 🆕 **研报层 warning 是误报（N-21）**：研报调用的 `meta.warnings` 会报 `default_fanout_fallback`／"returning the CORE fundamentals set"，但 `results.fundamentals.research_reports` 数据齐全。**以 payload 为准，不要因为这条 warning 重试**——重试白烧 1 次额度
- 🆕 **信号面必须单次 fanout（N-4）**：`signal()` **省略 `categories`** 即一次返回 `insider_trading` + `institutional`(13F) + `kol_call` 三类，**合计只计 1 次额度**。按类分 3 次调 = 3 倍额度且数据完全相同
- 🆕 **13F 环比字段季内不可引用（N-7，2026-07-24 复核仍有效）**：`investorsHolding` / `ownershipPercentChange` / `putCallRatioChange` 在申报季中期是残缺假信号（实测 NVDA 6234→1441→1882 持续回补）。**只引用绝对值与持仓结构，不引用任何环比**
- 🆕 **KOL 喊单先去重（N-5）**：多标的推文按 symbol 裂成多条（同一 `source_url` 出现 3 次），统计多空前必须按 `source_url` 去重，否则一条低信号推文被计成三个独立喊单
