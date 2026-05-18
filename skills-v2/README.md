# Followin MCP — Skills v2 (Flagship Bundle)

基于 **FollowX MCP** 的 5 个旗舰 Skill，覆盖美股深度分析、宏观看盘、信号背离扫描三大场景。

## 📦 包含 5 个 Skill

| # | Skill | 一句话定位 | 触发示例 |
|---|---|---|---|
| **14** | `multi-agent-stock-analysis_v2` | **21 个 AI Agent** 协同决策（8 传奇 + 5 现代 + 6 量化 + 风控 + 组合经理）| "帮我全面分析 NVDA" |
| **11** | `us-stock-earnings-report_v2` | 美股单股财报三维分析（财务 Beat/Miss + 媒体情绪 + 宏观背景）| "看下 AAPL 财报" |
| **13** | `us-stock-divergence-scan_v2` | 信号背离扫描（价格 × 内部人 × 媒体三维异常）| "背离扫描" / "内部人悄悄买入" |
| **08** | `btc-macro-dashboard_v2` | BTC 宏观环境 0-100 评分（4 层加权）| "BTC 现在几分" |
| **09** | `gold-macro-dashboard_v2` | 黄金宏观环境 0-100 评分（黄金特殊逻辑）| "黄金宏观怎么样" |

---

## 🛠 依赖的 MCP 工具

5 个 Skill 全部基于 **FollowX MCP** 4 个工具：
- `mcp__followx__metrics` — 行情 / 宏观 / 美股财报（comprehensive 真聚合）
- `mcp__followx__news` — 多源新闻 + Trending + TG 频道聚合
- `mcp__followx__signal` — KOL 喊单 / 实盘 / 内部人三类 fanout
- `mcp__followx__twitter` — 15+ Twitter 子工具

**MCP 接入**：
```
https://mcp.followin.io/v2/sse
```

详细接入参考主仓库 `USER_GUIDE.md`。

---

## 📂 安装方法

### 方法一：复制到全局 commands 目录（推荐）

```bash
cp *.md ~/.claude/commands/
```

适用：所有项目都能调用这套 Skill。

### 方法二：复制到项目 commands 目录

```bash
cp *.md /path/to/your-project/.claude/commands/
```

适用：仅当前项目使用。

### 方法三：直接放入 Skills 仓库

如果你已经 clone 了 [Followin-Skills](https://github.com/Followin-AI/Followin-Skills)，可直接使用本目录下的 Skill 文件。

---

## 🎯 Skill 简介

### 14. Multi-Agent Stock Analysis（最炸）

**21 个 Agent 架构**（对标 ai-hedge-fund）：

```
Group A: 传奇投资者 (8)
  Buffett / Graham / Munger / Burry / Ackman / Wood / Lynch / Fisher

Group B: 现代大师 (5)
  Damodaran / Druckenmiller / Taleb / Pabrai / Jhunjhunwala

Group C: 量化分析师 (6)
  Valuation / Fundamentals / Technicals / Sentiment / News / Growth

⑳ 风控经理 — 仓位约束（基于 Beta / 波动率 / 流动性 / 宏观风险）
㉑ 组合经理 — LLM 综合决策
```

**输出**：19 路独立投票 + 风控仓位上限 + 组合经理最终决策（STRONG BUY / BUY / HOLD / SELL / STRONG SELL）

---

### 11. US Stock Earnings Report

**核心差异化**：**1 次调用拿全 12 块** fundamentals 真聚合
- 三表（利润表 / 资产负债表 / 现金流）4 季度历史
- DCF 估值 + 关键财务指标 TTM
- 分析师评级（最近 20 条）+ 共识价
- Beat/Miss 历史 + EPS 趋势
- 同行（peers）对比
- 下次财报预期

**三维分析**：财务 Beat/Miss + 媒体情绪 + 宏观背景

---

### 13. US Stock Divergence Scan

**4 种背离信号**：

| 信号 | 含义 |
|---|---|
| **Silent Buy** | 内部人主动买入 > \$100K + 媒体无报道 |
| **Sentiment Mismatch** | 股价走势与媒体情绪方向相反 |
| **Unreported Drop** | 大市值股 -8%+ 跌 + 主流媒体无报道 |
| **Unreported Surge** | 中市值股 +20%+ 涨 + 主流媒体无关注 |

**关键能力**：**Insider 三源 fanout**（Form 4 + Senate + House 一次拿全）

---

### 08. BTC Macro Dashboard

**4 层加权 0-100 评分**：

| 层级 | 权重 | 核心指标 |
|---|---|---|
| 实际利率 | 35% | 10Y TIPS / 通胀预期 / Fed 政策 |
| 流动性 | 25% | M2 / FedFunds / 信用利差 |
| 通胀预期 | 20% | 10Y BEI / 核心 CPI |
| 美元 / 避险 | 20% | DXY / VIX |

---

### 09. Gold Macro Dashboard

**与 BTC Dashboard 同结构，黄金特殊逻辑**：

| 维度 | BTC 看 | 黄金看 |
|---|---|---|
| VIX | 飙升 = 利空 | **飙升 = 利多**（避险）|
| 通胀脉冲 | 中性 | **正向**（→ 实际利率受压 → 黄金受益）|
| 第一驱动力 | 全球流动性 | **实际利率（TIPS）** |
| 加密原生层 | ETF / 稳定币 | 央行购金 / GLD / 上海金溢价 |

---

## 📅 版本

- **v2.0** — 2026-05-13：从老 MCP（premium-mcp）迁移到 FollowX MCP，调用次数减少 60-80%，删除 schema caveat 和媒体 users 列表
- 详见各 Skill 文件头 frontmatter

---

## 📮 反馈

Bug / 需求 → [Followin-Skills issues](https://github.com/Followin-AI/Followin-Skills/issues)
