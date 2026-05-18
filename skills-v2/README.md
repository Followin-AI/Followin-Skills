# Followin MCP — Skills v2 (Flagship Bundle)

> 基于 **FollowX MCP** 的 5 个旗舰 Skill —— 覆盖美股深度分析、宏观看盘、信号背离扫描

完整产品介绍 + 接入文档详见仓库根目录 [`USER_GUIDE.md`](../USER_GUIDE.md)。

---

## 📦 这个 Bundle 包含什么

5 个开箱即用的 Skill，**全部基于 FollowX MCP 协议**，在 Claude / Cursor / Windsurf 等 AI 客户端中通过自然语言即可触发：

| # | Skill 文件 | 一句话定位 | 触发示例 |
|---|---|---|---|
| **14** | [`multi-agent-stock-analysis_v2`](./14_multi-agent-stock-analysis_v2.md) | **21 个 AI Agent** 协同决策 | "帮我全面分析 NVDA" |
| **11** | [`us-stock-earnings-report_v2`](./11_us-stock-earnings-report_v2.md) | 美股财报三维分析（财务 + 媒体 + 宏观）| "看下 AAPL 财报" |
| **13** | [`us-stock-divergence-scan_v2`](./13_us-stock-divergence-scan_v2.md) | 信号背离扫描（价格 × 内部人 × 媒体）| "背离扫描" / "内部人悄悄买入" |
| **08** | [`btc-macro-dashboard_v2`](./08_btc-macro-dashboard_v2.md) | BTC 宏观 0-100 评分 | "BTC 现在几分" |
| **09** | [`gold-macro-dashboard_v2`](./09_gold-macro-dashboard_v2.md) | 黄金宏观 0-100 评分 | "黄金宏观怎么样" |

---

## 🛠 依赖：FollowX MCP 4 工具

5 个 Skill 全部基于 **FollowX MCP** 协议，调用以下 4 个工具：

| 工具 | 能力 |
|---|---|
| **`mcp__followx__metrics`** | 行情 / 宏观指标 / 美股财报（12 块真聚合）/ 技术指标 / 经济日历 |
| **`mcp__followx__news`** | 多源新闻 + Trending + TG 频道聚合（**自动按 10 类主题分类**）|
| **`mcp__followx__signal`** | KOL 喊单 / 顶级交易员实盘 / 链上鲸鱼 / 内部人 + 政客交易 fanout |
| **`mcp__followx__twitter`** | 15+ Twitter 子工具（高级搜索 / 用户档案 / 关系图谱 / 地区趋势 / 线程上下文）|

**TG 频道智能分类（10 类）**：交易信号 / 实盘跟踪 / 市场结构 / 宏观研判 / 跨市场 / 资讯聚合 / 叙事追踪 / 项目研究 / 链上数据 / Meme 打新

详见 [`USER_GUIDE.md`](../USER_GUIDE.md) §"MCP 4 个核心工具" 章节。

---

## 🎯 5 个 Skill 详细介绍

### 🥇 14. Multi-Agent Stock Analysis（最炸）

**21 个 Agent 架构**（对标 ai-hedge-fund）：

```
              数据采集（fundamentals + 内部人 + news + 宏观）
                          │
    ┌─────────────────────┼─────────────────────┐
    │  Group A: 传奇投资者  │  Group B: 现代大师    │
    │  Buffett / Graham    │  Damodaran           │
    │  Munger / Burry      │  Druckenmiller       │
    │  Ackman / Wood       │  Taleb / Pabrai      │
    │  Lynch / Fisher      │  Jhunjhunwala        │
    │  (8 人)              │  (5 人)              │
    ├─────────────────────┼─────────────────────┤
    │  Group C: 量化分析师                       │
    │  Valuation / Fundamentals / Technicals    │
    │  Sentiment / News / Growth                │
    │  (6 人)                                   │
    └─────────────────────┬─────────────────────┘
                  19 路 signal + confidence
                          │
                ⑳ 风控经理（仓位约束）
                          │
                ㉑ 组合经理（LLM 综合决策）
```

**输出**：
- 19 位分析师独立投票（Bullish / Neutral / Bearish + 置信度 0-100）
- 风控经理给出仓位上限（基于 Beta / 波动率 / 流动性 / 宏观风险）
- 组合经理最终决策（STRONG BUY / BUY / HOLD / SELL / STRONG SELL）+ 持有周期 + 关键观察点

**触发**：`帮我全面分析 NVDA` / `TSLA 值不值得买` / `多维度看 AAPL`

---

### 🥇 11. US Stock Earnings Report

**核心差异化**：**1 次调用拿全 12 块** fundamentals 真聚合
- 三表（利润表 / 资产负债表 / 现金流）4 季度历史
- DCF 估值 + 关键财务指标 TTM
- 分析师评级（最近 20 条）+ 共识价（median / high / low）
- Beat/Miss 历史 + EPS 趋势
- 同行（peers）对比
- 下次财报预期（EPS + Revenue）

**三维分析**：财务 Beat/Miss + 媒体情绪 + 宏观背景

**触发**：`帮我看 AAPL 财报` / `TSLA earnings` / `英伟达财报分析`

---

### 🥇 13. US Stock Divergence Scan

**4 种背离信号**：

| 信号 | 含义 |
|---|---|
| **Silent Buy** | 内部人主动买入 > \$100K + 媒体无报道 → 知情人看好但市场未反应 |
| **Sentiment Mismatch** | 股价走势与媒体情绪方向相反（利空不跌 / 利好不涨）|
| **Unreported Drop** | 大市值股 -8%+ 暴跌 + 主流媒体无报道 |
| **Unreported Surge** | 中市值股 +20%+ 暴涨 + 媒体几乎无关注 |

**关键能力**：
- 涨跌幅榜过滤掉微盘妖股 / 杠杆 ETF / 仙股
- **Insider 三源 fanout**：Form 4 + Senate + House 一次拿全
- 跨数据源交叉验证（metrics + signal + news）

**触发**：`背离扫描` / `有没有没新闻却大涨的` / `内部人悄悄买入`

---

### 🥈 08. BTC Macro Dashboard

**4 层加权 0-100 评分**：

| 层级 | 权重 | 核心指标 |
|---|---|---|
| 实际利率 | 35% | 10Y TIPS 实际利率 / 通胀预期 / Fed 政策方向 |
| 流动性 | 25% | M2 / 联邦基金利率 / 信用利差 |
| 通胀预期 | 20% | 10Y BEI / 核心 CPI |
| 美元 / 避险 | 20% | DXY / VIX |

**输出**：综合分数 + 4 层各自得分 + 主要支撑 / 拖累 + 矛盾度判断 + 下次关键事件提醒

**触发**：`BTC 宏观怎么样` / `BTC 现在几分`

---

### 🥈 09. Gold Macro Dashboard

**与 BTC Dashboard 同结构，黄金特殊逻辑**：

| 维度 | BTC 看 | 黄金看 |
|---|---|---|
| VIX | 飙升 = 利空 | **飙升 = 利多**（避险）|
| 通胀脉冲 | 中性 | **正向**（→ 实际利率受压 → 黄金受益）|
| 加密原生层 | ETF / 稳定币 | 央行购金 / GLD 持仓 / 上海金溢价 |
| 第一驱动力 | 全球流动性 | **实际利率（TIPS）** |

**4 层加权**：实际利率 35% / 美元避险 30% / 黄金原生 25% / 经济脉冲 10%

**触发**：`黄金宏观怎么样` / `黄金现在几分`

---

## 📂 安装方法

### 方法 1：复制到全局 commands 目录（推荐）

```bash
cp *.md ~/.claude/commands/
```

适用：所有项目都能调用这套 Skill。

### 方法 2：复制到项目 commands 目录

```bash
cp *.md /path/to/your-project/.claude/commands/
```

适用：仅当前项目使用。

### 方法 3：直接 fork / clone 本仓库使用

```bash
git clone https://github.com/Followin-AI/Followin-Skills.git
cd Followin-Skills
cp skills-v2/*.md ~/.claude/commands/
```

---

## ⚙️ MCP 接入（5 分钟）

### Step 1：注册 + 获取 API Key

访问 [Followin MCP 官网] → 注册账户 → 获取 API Key

### Step 2：选择 AI 客户端配置

**Claude Desktop** —— 编辑 `~/Library/Application Support/Claude/claude_desktop_config.json`：

```json
{
  "mcpServers": {
    "followx": {
      "type": "sse",
      "url": "https://mcp.followin.io/v2/sse",
      "headers": {
        "x-api-key": "YOUR_API_KEY_HERE"
      }
    }
  }
}
```

**Cursor** —— 编辑 `~/.cursor/mcp.json`（同样的 JSON 结构）

**Claude Code（命令行）**：
```bash
claude mcp add followx https://mcp.followin.io/v2/sse \
  --scope user \
  --transport sse \
  --header "x-api-key: YOUR_API_KEY_HERE"
```

**Windsurf** —— 编辑 `~/.codeium/windsurf/mcp_config.json`（结构相同，字段名用 `serverUrl`）

### Step 3：重启客户端 → 开始问

直接说 `帮我全面分析 NVDA` / `BTC 宏观几分` 即可。

---

## 💰 定价 & 额度（快速参考）

| Plan | 价格 | 决策工具额度 | 适合 |
|---|---|---|---|
| **Free** | \$0 | 50 次（**一次性试用**）| 体验产品 |
| **Basic** | \$9.9 / 月 | 1,000 次 / 月 | 个人日常 |
| **Pro** | \$39 / 月 | 5,000 次 / 月 | 资深交易者 |
| **Max** | \$99 / 月（即将）| 50,000 次 / 月 | 机构 / AI Agent |

**关键事实**：
- ✅ **信息流永久免费**（实时快讯 / 热点 / KOL 观点 / 社群讨论 / 多语言原文），**不计入额度**
- ✅ 只有 4 个决策工具计入额度
- ✅ 年付立省 20%

**典型 quota 消耗**：
- 一次完整 Skill 分析（14 / 11 / 13）≈ 6-10 quota
- 一次单查询（08 / 09）≈ 1-2 quota
- Free 50 quota = 够 5-8 次完整分析（约 1 周深度体验）

完整定价 + FAQ 详见 [`USER_GUIDE.md`](../USER_GUIDE.md)。

---

## 🎯 自然语言触发对照

无需记任何命令 — 直接说人话即可：

| 你说 | 自动触发 |
|---|---|
| "帮我全面分析 NVDA" | → Skill 14 Multi-Agent |
| "AAPL 财报怎么样" | → Skill 11 Earnings |
| "今天有没有内部人悄悄买入" | → Skill 13 Divergence Scan |
| "BTC 宏观环境怎么样" | → Skill 08 BTC Dashboard |
| "黄金现在几分" | → Skill 09 Gold Dashboard |

---

## 📅 版本

- **v2.0**（2026-05-13）：从老 MCP（premium-mcp）迁移到 FollowX MCP，调用次数减少 60-80%，删除 schema caveat 和媒体 users 列表

每个 Skill 文件头 frontmatter 含详细元信息（trigger / not_trigger / mcp / args）。

---

## 🔗 相关资源

- **完整用户指南**：[`USER_GUIDE.md`](../USER_GUIDE.md)
- **MCP 标准文档**：[modelcontextprotocol.io](https://modelcontextprotocol.io)
- **Followin 主站**：[followin.io](https://followin.io)
- **主仓库**：[github.com/Followin-AI/Followin-Skills](https://github.com/Followin-AI/Followin-Skills)

---

## 📮 反馈

Bug / 需求 → [Followin-Skills issues](https://github.com/Followin-AI/Followin-Skills/issues)
