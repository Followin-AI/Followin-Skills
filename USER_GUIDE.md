# Followin MCP User Guide

> AI-Native 全球市场信息与交易决策平台
> 一个 MCP，连接全球市场信息与决策

---

## 📖 这份文档是什么

如果你是：
- **AI Agent 开发者** —— 想给你的 Agent 接入实时金融市场数据
- **量化 / 半量化交易者** —— 想用 Claude/Cursor 等 AI 客户端做日常分析
- **资深个人投资者** —— 想让 AI 帮你做更专业的研究

这份 User Guide 帮你 **5 分钟搞清楚**：
- Followin MCP 能干什么（4 个工具）
- 我们准备好的 5 个旗舰 Skill 怎么用
- 怎么接入到自己的 AI 客户端

---

## 🎯 Followin MCP 是什么

**一句话**：把全球金融市场的实时数据 + 决策信号 + 社交情报，**一次接入** 给你的 AI Agent。

**和别家的区别**：
- ✅ **信息流永久免费**（实时快讯 / 热点话题 / KOL 观点 / 社群讨论）
- ✅ 决策工具按额度计费，不为高频低价值数据买单
- ✅ 覆盖 **6 大类资产** —— Crypto + 美股 + 宏观 + 大宗 + 外汇 + 财报
- ✅ 5 分钟接入任何兼容 MCP 协议的 AI 客户端（Claude / Cursor / Windsurf / Cline / ChatGPT...）

---

## 🛠 MCP 4 个核心工具

Followin MCP 由 4 个工具组成，覆盖从行情到社交情报的全链路：

### 1️⃣ `metrics()` — 行情 / 宏观 / 财报数据引擎

**做什么**：
- **实时行情**：Crypto / 美股 / ETF / 全球指数 / 外汇 / 大宗商品
- **美股基本面**："1 次调用拿全 12 块"（三表 + 估值 + 同行 + 分析师评级 + Beat/Miss + 共识价 + EPS 预期）
- **宏观经济**：核心宏观指标直连（CPI / GDP / 利率 / 失业 / 国债收益率曲线...）
- **经济日历**：本周重大宏观事件 + 历史值 + 预期值
- **技术指标**：RSI / EMA / SMA / 布林带等

**典型用例**：
```
"NVDA 财报怎么样" → fundamentals comprehensive 一次拿全
"CPI 是多少" → 宏观指标直查
"^VIX 多少" → 实时
"美股涨幅榜" → sort_by=change_pct
```

### 2️⃣ `news()` — 多源新闻聚合 + Trending

**做什么**：
- **多源聚合**：传统媒体 + Crypto 媒体 + Twitter + Telegram + 长文/博客
- **Trending 模式**（sort_by="popularity"）：自动话题聚类，含信源数 + 热度 + 关联代币
- **多语言**：原文支持中 / 英 / 日 / 韩 / 越，AI 自动翻译
- **TG 频道聚合**：100+ 加密 Telegram 频道实时聚合，**自动按 10 类主题分类**

**TG 频道 10 类智能分类**（query 自动识别意图）：

| 类别 | 内容定位 | 触发词例 |
|---|---|---|
| **交易信号** | 买入 / 卖出信号 | "交易信号"、"买卖信号" |
| **实盘跟踪** | KOL 喊单 / 跟单 | "KOL 喊单"、"跟单"、"实盘" |
| **市场结构** | 资金费率 / 持仓量 / 多空比 | "资金费率"、"持仓量"、"多空比" |
| **宏观研判** | CPI / 利率 / 关税 / 地缘 | "宏观怎么看"、"CPI 影响"、"美股 BTC 联动" |
| **跨市场** | 美股 / 黄金 / 大宗 / 加密联动 | "跨市场"、"美股"、"黄金"、"大宗" |
| **资讯聚合** | 实时快讯 / 头条 | "最新动态"、"今日资讯" |
| **叙事追踪** | 板块 / 主线 / 概念 | "叙事"、"板块"、"主线"、"narrative" |
| **项目研究** | 基本面 / Tokenomics | "项目研究"、"基本面"、"tokenomics" |
| **链上数据** | 鲸鱼 / 聪明钱 / 链上异动 | "链上"、"鲸鱼"、"聪明钱"、"巨鲸" |
| **Meme 打新** | 新币首发 / Meme 拉盘 | "新 Meme"、"打新"、"meme 机会" |

**典型用例**：
```
"TG 上聊什么" → sources=["telegram"]（综合全景）
"做合约的看什么" → 自动命中 实盘跟踪 + 交易信号 + 市场结构
"宏观怎么看" → 自动命中 宏观研判 + 跨市场
"鲸鱼在干嘛" → 自动命中 链上数据
"有什么新 Meme" → 自动命中 Meme 打新
"今天热点话题" → sort_by="popularity"
"特朗普关税推文" → query="Trump tariff", sources=["twitter"]
```

### 3️⃣ `signal()` — 实盘 / 喊单 / 内部人 / 机构持仓

**做什么**：
- **KOL 喊单** (`kol_call`)：含具体标的 + 价位 + 理由
- **顶级交易员实盘** (`trader_position`)：CEX 顶级交易员 + 链上鲸鱼地址跟单
- **内部人交易 fanout** (`insider_trading`)：自动聚合 **3 类**
  - 公司高管 Form 4
  - 美国参议员（Senate）
  - 美国众议员（House）
- **13F 机构持仓** (`institutional`)：暂未完全接通

**典型用例**：
```
"Pelosi 最近交易" → insider_trading + Pelosi
"KOL 在喊什么" → kol_call
"BTC 鲸鱼仓位" → trader_position + BTC
```

### 4️⃣ `twitter()` — 全套 Twitter 社交情报

**做什么**（15+ 子工具）：
- **高级搜索**：关键词 / KOL / 时间范围全量历史检索
- **用户深度档案**：注册时间 / 用户名变更 / 验证身份
- **关系图谱**：互关验证 / 谁关注谁
- **完整线程上下文**：reply + quote + retweeter 全套
- **地区热门趋势**（woeid 切换）
- **推文互动数据**：回复 / 引用 / 转发用户

**典型用例**：
```
"@elonmusk 最近怎么说" → user_tweets
"check Vitalik 和 cz_binance 互关吗" → check_follow
"\$NVDA 最近热议" → advanced_search
"美国今日 Twitter trends" → trends woeid=23424977
```

---

## 🚀 5 个旗舰 Skill（推荐入门顺序）

我们打包了 5 个开箱即用的 Skill，覆盖你最高频的研究需求：

### 🥇 Skill 14 — Multi-Agent Stock Analysis（**最炸**）

**触发**：`帮我全面分析 NVDA` / `TSLA 值不值得买` / `多维度看 AAPL`

**做什么**：
**21 个 AI Agent** 独立研判，模拟一个完整的 AI Hedge Fund 决策流程：

```
                数据采集（fundamentals + 内部人 + news + 宏观）
                          │
    ┌─────────────────────┼─────────────────────┐
    │  Group A: 传奇投资者  │  Group B: 现代大师    │
    │  Buffett / Graham    │  Damodaran / Wood   │
    │  Munger / Burry      │  Lynch / Fisher     │
    │  Ackman / Wood       │  Druckenmiller      │
    │  Lynch / Fisher     │  Taleb / Pabrai     │
    │  (8 人)              │  Jhunjhunwala       │
    │                      │  (5 人)              │
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
- 19 位分析师独立投票（Bullish / Neutral / Bearish + 置信度）
- 风控经理给出仓位上限（基于 Beta + 波动率 + 流动性）
- 组合经理最终决策（STRONG BUY / BUY / HOLD / SELL / STRONG SELL）+ 持有周期 + 关键观察点

**适合谁**：所有美股投资者，特别是想"一次看完所有维度"的用户

---

### 🥇 Skill 11 — US Stock Earnings Report

**触发**：`帮我看 AAPL 财报` / `TSLA earnings` / `英伟达财报分析`

**做什么**：单股财报三维分析

1. **财务 Beat/Miss**：EPS / Revenue 实际 vs 预期，连续 4 季度趋势
2. **媒体情绪**：财报前后媒体报道聚合
3. **宏观背景**：当前利率环境 + 板块景气度

**核心差异化**：**fundamentals 真聚合** —— 一次 MCP 调用拿全 12 块：
- 三表（利润表 / 资产负债表 / 现金流）4 季度历史
- DCF 估值 + 关键财务指标 TTM
- 分析师评级（最近 20 条）+ 共识价（median / high / low）
- Beat/Miss 历史 + EPS 趋势
- 同行（peers）对比
- 下次财报预期（EPS + Revenue）

**适合谁**：财报季高频研究的交易者

---

### 🥇 Skill 13 — US Stock Divergence Scan

**触发**：`背离扫描` / `有没有没新闻却大涨的` / `内部人悄悄买入`

**做什么**：扫描全市场，找 4 种背离信号：

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

**适合谁**：阿尔法猎人 / 反共识交易者

---

### 🥈 Skill 08 — BTC Macro Dashboard

**触发**：`BTC 宏观怎么样` / `BTC 现在几分`

**做什么**：评估 BTC 当前宏观环境，输出 **0-100 综合评分**

**4 层加权评分**：

| 层级 | 权重 | 核心指标 |
|---|---|---|
| 实际利率 | 35% | 10Y TIPS 实际利率 / 通胀预期 / Fed 政策方向 |
| 流动性 | 25% | M2 / 联邦基金利率 / 信用利差 |
| 通胀预期 | 20% | 10Y BEI / 核心 CPI |
| 美元 / 避险 | 20% | DXY / VIX |

**输出**：
- 综合分数 0-100（>65 偏多 / 50-64 中性偏多 / <50 偏空）
- 4 层各自得分 + 主要支撑 / 拖累
- 矛盾度判断（低 / 中 / 高）
- 下次关键事件提醒

**适合谁**：BTC 长线持有者 + 趋势交易者（每周回访 3-5 次的留存王）

---

### 🥈 Skill 09 — Gold Macro Dashboard

**触发**：`黄金宏观怎么样` / `黄金现在几分`

**做什么**：与 BTC Dashboard 同结构，但**黄金特殊逻辑**：

| 维度 | BTC 看 | 黄金看 |
|---|---|---|
| VIX | 飙升 = 利空 | **飙升 = 利多**（避险）|
| 通胀脉冲 | 中性 | **正向**（→ 实际利率受压 → 黄金受益）|
| 加密原生层 | ETF / 稳定币 | 央行购金 / GLD 持仓 / 上海金溢价 |
| 第一驱动力 | 全球流动性 | **实际利率（TIPS）** |

**输出**：0-100 综合评分 + 4 层加权（实际利率 35% / 美元避险 30% / 黄金原生 25% / 经济脉冲 10%）

**适合谁**：黄金 ETF / 商品交易者

---

## 🎯 Skill 怎么用？

### 在 Claude / Cursor 等 AI 客户端里直接说：

| 你说 | 自动触发 |
|---|---|
| "帮我全面分析 NVDA" | → Skill 14 Multi-Agent |
| "AAPL 财报怎么样" | → Skill 11 Earnings |
| "今天有没有内部人悄悄买入" | → Skill 13 Divergence Scan |
| "BTC 宏观环境怎么样" | → Skill 08 BTC Dashboard |
| "黄金现在几分" | → Skill 09 Gold Dashboard |

Skill 会自动调用对应的 Followin MCP 工具组合，**不需要你记住任何 API 细节**。

---

## ⚙️ 快速接入（5 分钟）

### Step 1：注册 + 获取 API Key

访问 [Followin MCP 官网] → 注册账户 → 获取 API Key

### Step 2：选择你的 AI 客户端

#### Claude Desktop

编辑 `~/Library/Application Support/Claude/claude_desktop_config.json`：

```json
{
  "mcpServers": {
    "followin": {
      "type": "sse",
      "url": "https://mcp.followin.io/v2/sse",
      "headers": {
        "x-api-key": "YOUR_API_KEY_HERE"
      }
    }
  }
}
```

#### Cursor

编辑 `~/.cursor/mcp.json`：

```json
{
  "mcpServers": {
    "followin": {
      "url": "https://mcp.followin.io/v2/sse",
      "headers": {
        "x-api-key": "YOUR_API_KEY_HERE"
      }
    }
  }
}
```

#### Claude Code（命令行）

```bash
claude mcp add followin https://mcp.followin.io/v2/sse \
  --scope user \
  --transport sse \
  --header "x-api-key: YOUR_API_KEY_HERE"
```

#### Windsurf

编辑 `~/.codeium/windsurf/mcp_config.json`：

```json
{
  "mcpServers": {
    "followin": {
      "serverUrl": "https://mcp.followin.io/v2/sse",
      "headers": {
        "x-api-key": "YOUR_API_KEY_HERE"
      }
    }
  }
}
```

### Step 3：重启客户端，开始用

直接问"NVDA 财报怎么样" / "BTC 宏观几分" 即可。

---

## 💰 定价 & 额度

| Plan | 价格 | 决策工具额度 | Rate Limit | 适合 |
|---|---|---|---|---|
| **Free** | \$0 | **50 次**（一次性试用）| 10/分钟 | 体验产品 |
| **Basic** | **\$9.9 / 月** | 1,000 次 / 月 | 60/分钟 | 个人日常 |
| **Pro** | **\$39 / 月** | 5,000 次 / 月 | 200/分钟 | 资深交易者 / 小团队 |
| **Max** | **\$99 / 月**（即将）| 50,000 次 / 月 | 1,000/分钟 | 机构 / AI Agent 24/7 |

**关键事实**：
- ✅ **信息流永久免费**（实时快讯 / 热点话题 / KOL 观点 / 社群讨论 / 多语言原文）
- ✅ 只有 **4 个决策工具** 计入额度（KOL喊单+实盘+内部人 / TG频道聚合 / X深度检索 / 金融数据引擎）
- ✅ 年付立省 20%

**典型消耗参考**：
- 一次完整 Skill 分析（14 / 11 / 13）≈ 6-10 quota
- 一次单查询（08 / 09 / 12）≈ 1-2 quota
- Free 50 quota = 够 5-8 次完整分析（约 1 周深度体验）

---

## ❓ FAQ

**Q：Free 50 次能用一个月吗？**
A：Free 是**一次性试用额度**，**不会每月刷新**。50 次足够把每个核心工具深度体验 10 次以上，验证产品价值。验证后建议升级 Basic（\$9.9 / 月，1,000 次按月刷新）。

**Q：信息流真的无限免费？**
A：是的。实时快讯 / 热点话题 / 深度文章 / KOL 观点 / 社群讨论 / 多语言原文 6 类信息流**永久免费 不计入额度**。

**Q：支持哪些 AI 客户端？**
A：遵循标准 MCP 协议，**支持所有兼容 MCP 的客户端**。已验证：Claude Desktop / Cursor / Windsurf / Cline / Claude Code / ChatGPT / Continue / Zed。

**Q：5 个 Skill 是预装吗？**
A：是的。安装 MCP 后 Skill 自动可用，**通过自然语言触发**，不需要记任何命令。

**Q：如何取消订阅？**
A：账户设置中随时取消，当前计费周期结束前仍可正常使用。降级后保留剩余试用额度 + 全部信息流无限免费。

---

## 🔗 相关资源

- **MCP 标准文档**：[modelcontextprotocol.io](https://modelcontextprotocol.io)
- **Followin 主站**：[followin.io](https://followin.io)
- **API 参考**：（待补充）
- **Skill 源码**：（待补充）

---

## 📮 反馈与支持

发现 bug / 需求建议 / 想要新功能 — 欢迎到 [Followin 社群] / [Discord] 反馈。

我们对 Skill 的迭代速度承诺：**重要 bug 48 小时内修复**。
