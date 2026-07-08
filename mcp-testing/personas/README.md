# 模拟用户 Persona 模板

**11 个 persona**，覆盖 Followin MCP 的核心用户场景。资产平衡：**美股 4 / 宏观 2 / Crypto 5**。

历史调整（v2 → v3）：
- 砍 `ray`（中文别名是客户端层问题，非 MCP 单点能力测试）
- 砍 `quinn`（量化纯历史回测场景小众；OHLCV/interval/RSI 边界测试已并入 `leo-btc`）
- 加 `leo-btc`（BTC swing trader — 盘面 + 鲸鱼 + 资金面整合）
- 加 `nina-alt`（Alt 季猎人 — alt 涨幅 + 鲸鱼 + KOL + TG 项目研究/叙事）
- 收敛 `yuki` 为中英双语（不再五语言铺开）

## 测试范围（重要）

**只测 MCP 已宣称的能力的信息反馈准确度**，不测能力空白。

5 个 accuracy 维度：

| 维度 | 含义 | 验证手段 |
|---|---|---|
| **数据正确性** | 返回值是否与真实世界一致 | 外部交叉（SEC EDGAR / Yahoo / CNBC / 官方 IR / Binance / CoinGecko / TradingView） |
| **数据新鲜度** | timestamp 是否在合理窗口内 | freshness 字段 vs now |
| **数据完整性** | 应有字段是否非空 | 同 entity 跨字段对齐 |
| **数据一致性** | 同标的跨调用结果对齐 + 数学自洽 | 多次调用同一 symbol；杠杆/清算/价值数学关系 |
| **语义命中率** | 自然语言 query 是否拿到用户想要的 | 用户期望 vs 实际返回 |

每个 persona 配套：

- **画像**：身份 + 痛点 + 决策习惯
- **watchlist**：日常关注的标的
- **trigger style**：他们怎么"说话"（决定 Skill 是否能命中）
- **daily script**：一天典型工作流（5-6 个 step），每个 step 含 `accuracy_check`
- **success criteria**：可外部交叉验证的目标数

## Persona 总览

### 美股 / 宏观（6 人）

| ID | 角色 | 资产偏好 | 核心 accuracy 验证 |
|---|---|---|---|
| **hedy** | 美股短线交易者 | tradfi 大票 | fundamentals 14 sub-source + Form 4 + movers marketCap 过滤 |
| **mark** | BTC 宏观研究员 | BTC + FRED | FRED series vs fred.stlouisfed.org + news categories=[macro] |
| **sarah** | Alpha 全市场猎人 | 跨资产偏 tradfi | movers + insider + news 命中召回 + twitter trends/community |
| **david** | 黄金/大宗交易员 | gold + 美股黄金股 | ETF quote + DCF + key_metrics_ttm + 实际利率数学自洽 |
| **olivia** | 机构 PM | 13F + 明星基金 | institutional + sec_filings + shares_float + EV 数学自洽 |
| **felix** | 空头猎手 | 高估值争议票 | SEC Form 4 + Beat/Miss + transcript + Hindenburg Twitter |

### Crypto（5 人）

| ID | 角色 | 资产偏好 | 核心 accuracy 验证 |
|---|---|---|---|
| **alex** | Crypto 链上猎手 | meme / 链上 | TG 分类 + KOL 喊单原文 + 鲸鱼数学自洽 + twitter list/thread |
| **kevin** | Crypto 资讯散户 | BTC/ETH/SOL/SUI | **news 泛问 + 中文别名 + 兜底行为 + youtube/medium** |
| **yuki** | 中英双语情报官 | crypto 中英两圈 | source_lang + 跨语言去重 + 英→中时间差 |
| **leo-btc** | BTC swing trader | BTC + ETH | **OHLCV/interval/RSI 数学自洽 + 鲸鱼数学自洽 + xyz 链上美股** |
| **nina-alt** | Alt 季猎人 | HYPE/ZEC/MONOPOLY/CARDS | **crypto movers + alt 鲸鱼 + KOL 跨平台 + TG 项目研究/叙事** |

## 覆盖矩阵（MCP 4 工具 × 子能力）

### metrics

| 子能力 | 覆盖 persona |
|---|---|
| market quote (tradfi) | hedy / sarah / olivia / felix / david |
| market quote (crypto) | kevin / alex / mark / leo-btc / nina-alt |
| market OHLCV 历史 (interval + date) | **leo-btc** (含 day/4h/1min 边界) |
| market technicals (RSI 14) | **leo-btc** |
| market movers (tradfi + min_market_cap) | hedy / sarah |
| market movers (crypto + min_market_cap) | **nina-alt** |
| macro FRED | mark / david |
| macro economic calendar | hedy / mark |
| fundamentals 14 sub-source 真聚合 | hedy (NVDA 全测) / david (DCF/TTM) / olivia (sec_filings/float/EV) / felix (transcript) |

### news

| 子能力 | 覆盖 persona |
|---|---|
| sources=[media/feeds] | kevin / sarah / yuki |
| sources=[telegram] + _tg_category | alex / kevin / yuki / nina-alt |
| sources=[twitter] | **已知坏路径 B-12** — 不依赖 |
| sources=[youtube] | **kevin 独家** |
| sources=[medium] | **kevin / mark** |
| categories filter (market/social/event/macro/fundamentals) | mark (categories=macro) |
| source_lang en+zh-cn | yuki |
| search_depth quick vs standard | **kevin 独家** |
| 泛问 / 大白话 / 兜底行为 | **kevin 独家** |

### signal

| 子能力 | 覆盖 persona |
|---|---|
| kol_call (crypto-only) | alex / nina-alt |
| trader_position (top traders + whale traders) | leo-btc / alex / mark / nina-alt |
| insider_trading (Form 4 + Senate + House) | hedy / sarah / felix |
| institutional (13F) | **olivia 独家** |

### twitter (23 actions)

| 子能力 | 覆盖 persona |
|---|---|
| search ($-symbol 精确) | sarah / nina-alt / felix |
| user_info + user_tweets | felix (Hindenburg) |
| trends (woeid) | sarah |
| community_tweets | sarah |
| list_timeline + tweet_thread | alex |

### Followin 独家维度

| 能力 | 覆盖 persona |
|---|---|
| **xyz: 链上美股 (Hyperliquid)** | **leo-btc 独家** |
| **TG 频道 10 类智能分类** | alex / nina-alt |
| **鲸鱼地址人格档案 (`介绍`字段)** | leo-btc / nina-alt |

## 使用方式

### 自动跑（推荐）

用 `../mcp-test-runner.md` Skill：

```
用户输入："跑一下 leo-btc"
→ Skill 自动读 persona YAML，逐 step 触发 MCP，归档 raw I/O，输出 run-report.md
```

支持参数：
- `跑一下 <persona>` — 全部 step
- `测试 <persona> step <n>` — 单 step
- `实测 <persona> 跳过外部交叉` — 仅机器验证

### 手动跑

```bash
cat leo-btc.yaml  # 看 daily_script
# 逐条触发对应 MCP 工具 → 自己记录到 ../runs/<date>/<persona>/<test_id>.yaml
```

## 记录格式（每条调用）

```yaml
test_id: T-2026-05-27-leo-btc-001
persona: leo-btc
step_in_script: 4
user_natural_input: "BTC 鲸鱼和顶级交易员最近 4 小时仓位"
mcp_call:
  tool: mcp__followin__signal
  params: {categories: [trader_position], keywords: [BTC], time_range: "4h"}
mcp_response_summary: |
  返回 86 条；top_traders 含梭教授/欧阳/Paulwei/Benson，
  whale_traders 含 pension-usdt.eth / 100%胜率低回撤 / Loracle，
  数学自洽：清算价 = 开仓价 / (1 + 1/leverage) ✓
mcp_response_raw_path: ./raw/T-2026-05-27-leo-btc-004.json
verdict: PASS | FAIL | PARTIAL | EDGE_CASE
issue_type: routing | data_quality | token_limit | sse | fallback_pollution | intent_misroute | timeout | partial_response | missing_field | schema_drift | math_inconsistency
severity: P0 | P1 | P2 | P3
bug_ref: B-01
notes: |
  备注（包括外部对齐验证的证据链接）
```
