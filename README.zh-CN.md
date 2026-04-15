# Followin Skill 用户指南

[English](./README.md) | **简体中文**

13 个 AI Agent 技能,覆盖加密交易、宏观分析与市场情报 —— 由 **Followin MCP** 和 **Premium MCP** 驱动。

所有技能同时支持**中英文**触发词,输出语言跟随你的提问语言。

## 跨 AI 工具的可移植性

整个包分为两层:

1. **MCP 服务器**(Followin MCP + Premium MCP)—— 提供底层数据和工具,适用于**任何兼容 MCP 的 AI 客户端**:Claude Code、Claude Desktop、Cursor、Windsurf、Cline、Continue.dev、OpenCode、OpenClaw 等。
2. **Skill 文件**(`.claude/commands/` 下的 13 个 markdown 文件)—— 采用 Claude Code 的 slash command 格式编写。可直接放入 Claude Code 及其它兼容该格式的客户端;对于使用其它规则/命令格式的工具,markdown 内容本身依然完全可移植 —— 把对应字段粘到工具自己的格式里就行。

## 一键安装

```bash
npx @followin/skills setup
```

按提示粘贴你的 Followin API key,然后重启客户端。完成 —— 13 个 skill 文件已安装,两个 MCP 服务器(`followin-mcp` + `premium-mcp`)已配置并通过连接验证。

其它客户端(默认是 Claude Code 全局):

```bash
npx @followin/skills setup --client cursor          # 在你的项目目录下运行
npx @followin/skills setup --client windsurf        # 在你的项目目录下运行
npx @followin/skills setup --client claude-desktop  # 仅 MCP
npx @followin/skills setup --client claude-code-project
npx @followin/skills setup --client opencode        # 仅 skill,不配 MCP
```

Cursor 和 Windsurf 的规则文件会被**自动转换**为它们各自的原生格式(`.cursor/rules/*.mdc` 和 `.windsurf/rules/*.md`)—— 在你想放置规则的项目目录内运行 `setup` 即可。Claude Desktop 暂时只支持 MCP,因为它还没有稳定的 skill 文件路径规范。

运行 `npx @followin/skills clients` 查看所有预设。需要 Node.js 16+ (macOS / Linux / Windows)。API key 以明文存于客户端配置文件中(权限 `chmod 600`)—— 不要 commit 该文件。

<details>
<summary><b>手动安装</b> —— 适用于没有预设的客户端(Cline、Continue.dev …),或者你更喜欢自己改 JSON</summary>

**Skill 文件** —— `npx @followin/skills path` 可打印源目录路径,也可以用 `install --target ~/your/dir`。Cursor / Windsurf / Cline / Continue.dev 的 `.md` 文件无法直接拖入,需要把每个文件的 body 复制进各工具的原生规则格式。(其实你完全可以跳过 skill 文件 —— 只要 MCP 接通了,模型靠工具本身就能回答大多数问题。)

**MCP 配置** —— 把下面这段贴入你的客户端 MCP 配置文件,把 `YOUR_API_KEY_HERE` 替换为你自己的 key:

```json
{
  "mcpServers": {
    "followin-mcp": {
      "type": "sse",
      "url": "https://mcp.followin.io/sse?api_key=YOUR_API_KEY_HERE",
      "headers": { "X-API-Key": "YOUR_API_KEY_HERE" }
    },
    "premium-mcp": {
      "type": "sse",
      "url": "https://premium-mcp.followin.io/sse?api_key=YOUR_API_KEY_HERE",
      "headers": { "X-API-Key": "YOUR_API_KEY_HERE" }
    }
  }
}
```

| 客户端 | 配置文件路径 |
|---|---|
| Claude Code | `~/.claude/settings.json`(或项目级 `.mcp.json`) |
| Claude Desktop | `~/Library/Application Support/Claude/claude_desktop_config.json` · `%APPDATA%\Claude\claude_desktop_config.json` |
| Cursor | `~/.cursor/mcp.json` |
| Windsurf | `~/.codeium/windsurf/mcp_config.json` |
| Cline | Cline 面板 → MCP Servers(齿轮图标) |
| Continue.dev | `~/.continue/config.yaml`(JSON 转 YAML) |

API key 同时以 `?api_key=` 查询参数和 `X-API-Key` header 两种方式发送,以兼容不同客户端。改完配置后请重启客户端。

</details>

---

## Followin MCP — 加密资讯与舆情

Followin MCP 接入 Followin 加密货币资讯平台,提供以下数据能力:

- **热点风向标** — 当前热门话题 Top10,含热度值、关联代币、价格变动
- **热门资讯流** — 热门快讯和热门文章排行
- **首页信息流** — 最新快讯和深度文章,支持筛选重要内容
- **代币维度内容** — 按代币查看重要事件、新闻、社区讨论
- **代币 KOL 观点** — 按代币查看推特 KOL 的观点和分析
- **日报精选** — 每日精选内容汇总
- **关键词搜索** — 搜索平台上的文章、快讯、推文,支持类型过滤和时间范围
- **情报中心** — 结构化数据频道:代币解锁、宏观经济、上币监控、项目大事件、量价异动、资金费率

基于这些能力,构建了 5 个 Skill:

### 01 Followin Intel Center(情报中心)

一站式查询市场事件数据:代币解锁、宏观经济数据、上币/下架公告、项目大事件、量价异动、资金费率。按你关心的维度精准过滤,不用翻完整个信息流。

**怎么问:**
- `本周有什么大额解锁`
- `最近有哪些币上了交易所`
- `资金费率异常的币有哪些`
- `情报中心概览` — 6 个频道各取最重要的 1-2 条

**6 个数据频道:**

| 频道 | 覆盖内容 |
|---|---|
| 代币解锁 | 解锁日期、数量、占流通市值比例、风险等级 |
| 宏观经济 | CPI/PPI/利率发布、政策动向、关税政策 |
| 上币/下架 | 交易所上币、下架公告 |
| 项目大事件 | 安全事件、协议升级、项目重大动态 |
| 量价异动 | 成交量倍数、警示价、异常波动 |
| 资金费率 | 资金费率数据、空头挤压风险、板块分布 |

### 02 Breaking News Analysis(突发新闻分析)

粘贴一条加密新闻,告诉你它影响哪些币、利多还是利空、影响有多大、能持续多久。适合看到消息后快速判断要不要行动。不依赖 MCP 数据,纯 AI 分析,可选 Web 搜索做补充验证。

**怎么问:**
- 直接粘贴一段新闻,然后说 `分析一下这条新闻`
- `分析新闻影响`
- `这个消息利多还是利空`

**两种模式:**
- **Flash 模式** — 短新闻(1-3 句话):快速利多/利空判断 + 关键标的
- **Deep 模式** — 长文章或显式请求:完整因果链、二阶效应、历史对比

每个利多/利空判断都会附带一个**反方观点** —— 什么条件会推翻这个论断。

### 03 Trending News & Topics(热点舆情)

现在市场在关注什么?从热点风向标和热门资讯流交叉提取当前最受关注的事件,**多平台共振**的热点优先置顶 —— 在两个数据源里都出现的话题最重要。

**怎么问:**
- `今天有什么热点`
- `市场在关注什么`
- `昨夜有什么爆点`
- `ETH最近有什么消息` — 聚焦到某个代币/话题

**两种模式:**
- **概览**(默认)—— 当前热门事件全景
- **聚焦** —— 指定代币或话题:`ETH 有什么消息`、`AI 板块在关注什么`

事件按重要性排序(宏观/监管 > 板块整体 > 单个项目),共振话题恒置顶部。

### 04 Crypto Daily Brief(加密日报)

生成一条可直接发布的每日加密市场简报。从热点风向标 + TG 日报精选筛选过去 12 小时最重要的 8-10 条事件,交叉验证后输出口语化、有态度的简报,1 分钟抓住焦点。

**怎么问:**
- `出个日报`
- `加密早报`
- `日报`

**核心规则:**
- 第 1 条永远是 BTC 价格走势,用编辑笔触而非冷数据
- 至少保证 2-3 条宏观/AI 相关内容(避免被山寨币占满)
- ~1/3 的条目附带一行编辑点评
- Top 10 之外的山寨币最多 2-3 条

> 想看宏观/美股早报?说 `宏观早报` 或 `美股日报`,会路由到 Skill 10。

### 05 Token Buzz & Views(代币舆情聚合)

指定一个代币,一次性看完它的快讯、深度文章、推特 KOL 观点、社群讨论四个维度。适合想深入了解某个币最近发生了什么。

**怎么问:**
- `BTC有什么新闻`
- `ETH最近什么情况`
- `SOL社群在讨论什么` — 只看某个维度
- `HYPE相关文章`

> 想看 KOL 对某个币的交易策略判断?说 `KOL怎么看BTC`,会路由到 Skill 06(策略信号)。

---

## Premium MCP — 交易策略与宏观分析

Premium MCP 聚合多个专业数据源:

- **顶级交易员实盘** — 顶级合约交易员的实时持仓数据(方向、杠杆、仓位规模)
- **链上巨鲸** — Hyperliquid 链上可验证的巨鲸/知名交易员仓位(开仓价、清算价、精确仓位)
- **KOL 喊单策略** — KOL 公开发布的交易策略(入场/目标/止损)
- **TG 频道聚合** — 70+ 个 Telegram 频道,按 10 个分类划分
- **加密货币实时价格** — 批量获取加密货币 USD 实时价格
- **FRED 宏观数据** — 美联储经济数据库,覆盖利率、通胀、就业、GDP、国债收益率等数百个序列
- **金融市场数据** — 美股/ETF/指数/外汇/商品实时行情、财务报表、财报 Beat/Miss、分析师预测、关键比率、内部人交易、经济日历、国债收益率、涨跌榜
- **31 家财经媒体搜索** — 按关键词搜索 Reuters、Bloomberg、CNBC、WSJ、FT 等主流财经媒体的报道
- **Twitter 数据** — 用户推文、搜索、关注关系、Space 等

基于这些能力,构建了 8 个 Skill:

### 06 Trading Strategy & Signal(策略信号)

三个数据源交叉验证:CEX 交易员实盘仓位 + Hyperliquid 链上巨鲸 + KOL 公开喊单。核心原则:**真金白银的仓位永远比嘴上喊单可信**。

**怎么问:**
- `SOL能不能做` — 三源交叉验证,最完整
- `现在有什么机会`
- `KOL怎么看ETH` — 只看 KOL 喊单
- `大户在做什么` — 只看实盘仓位
- `鲸鱼今天在建仓什么`

**信号分级:**

| 信号类型 | 含义 | 置信度 |
|---|---|---|
| 共振 | 交易员 + KOL 同向 | 最高 |
| 仅交易员 | 交易员有仓位,KOL 静默 | 高 |
| 矛盾 | 交易员 vs KOL 反向 | 谨慎(信交易员) |
| 仅 KOL | KOL 在喊,交易员未跟进 | 较低 |

### 07 TG Channel Intel(TG 频道情报)

从 70+ 个 Telegram 频道中提取市场情报,按话题聚类、提炼观点、识别共识与分歧。频道按质量分级(高/中),高质量频道观点优先展示。支持中文、英文、韩语、越南语四种语言频道,比如可以问 `今天韩语频道在聊什么`。

**10 个频道分类:** 宏观研判、市场结构、项目研究、叙事追踪、交易信号、实盘跟踪、链上数据、Meme 打新、跨市场、资讯聚合

**按用户画像自动路由:**

| 你是谁 | 怎么问 | 会看哪些频道 |
|---|---|---|
| 二级交易者 | `做交易的频道在说什么` | 交易信号、实盘跟踪、市场结构 |
| 关注宏观的 | `宏观怎么看` | 宏观研判、跨市场 |
| 追信息流的 | `TG上有什么最新动态` | 资讯聚合、叙事追踪 |
| 研究项目的 | `最近有什么项目值得看` | 项目研究 |
| 看链上数据的 | `链上有什么动静` | 链上数据 |
| Meme 玩家 | `有什么新Meme` | Meme 打新 |
| 不确定 / 全都要 | `TG上在聊什么` | 全部分类 |

也可以聚焦到某个标的:`TG上怎么看BTC`

### 08 BTC Macro Dashboard(BTC 宏观看盘)

基于 15 个指标、4 个层级,给出 BTC 当前宏观环境的 0-100 量化评分:全球流动性(35%)、市场环境(30%)、加密原生资金流(25%)、经济数据脉冲(10%)。50 分中性,高于 50 偏多,低于 50 偏空。

**4 层评分:**
- **第 1 层 — 流动性方向(35%)**:净流动性趋势、美联储政策、FedWatch 概率、M2 走势
- **第 2 层 — 市场环境(30%)**:DXY、纳指、VIX、实际利率(TIPS)、收益率曲线、黄金
- **第 3 层 — 加密原生资金(25%)**:BTC 现货 ETF 净流入、稳定币市值趋势
- **第 4 层 — 经济数据脉冲(10%)**:CPI/PCE 意外值、就业意外值

包含**矛盾检测** —— 当不同层级指标方向不一致时会标注出来。

**怎么问:**
- `BTC宏观` / `BTC宏观看盘`
- `BTC宏观评分` — 只要分数
- `BTC宏观环境怎么样`

> ⚠️ 重度调用:需拉取 10+ 条 FRED 序列、多个市场行情、DeFiLlama API、Web 搜索。不建议高频触发。

### 09 Gold Macro Dashboard(黄金宏观看盘)

基于 15 个指标、5 个层级,给出黄金当前宏观环境的 0-100 量化评分:实际利率与货币政策(40%)、美元与外汇(15%)、央行购金与实物需求(25%)、避险情绪(15%)、经济数据脉冲(5%)。

**与 BTC 看盘的关键差异:**
- 黄金的 #1 驱动是**实际利率**(TIPS 收益率),不是流动性
- **VIX 评分方向相反**:VIX 飙升对黄金利多(避险),对 BTC 利空(风险偏好下降)
- **央行购金**是黄金独有的结构性因素(BTC 看盘没有)
- **COT 持仓是反向指标**:净多头极端 = 利空(过度拥挤)

**怎么问:**
- `黄金宏观` / `黄金宏观看盘`
- `黄金宏观评分` — 只要分数
- `黄金宏观环境怎么样`

> ⚠️ 重度调用:需拉取 8+ 条 FRED 序列、市场行情,以及 FedWatch/COT/ETF/央行数据的 Web 搜索。不建议高频触发。

### 10 Macro Morning Brief(宏观早报)

每日宏观财经早报:全期限国债收益率、VIX、原油、美元指数、经济日历、媒体热点、市场涨跌榜 —— 一份报告掌握开盘前的宏观全貌。

**怎么问:**
- `宏观早报` / `美股早报`
- `美股日报` / `宏观日报`
- `morning brief`

**报告结构:**
1. 宏观环境表(10Y/2Y 收益率、利差、VIX、布伦特原油、美元指数)
2. 经济日历(从全球数据中过滤出美国相关事件)
3. 媒体三大热点(含情绪与代表性文章)
4. Watchlist 涨跌(可通过 `watchlist` 参数自定义)
5. 市场涨跌榜(过滤市值 > $500M)
6. 情绪分布与整体市场氛围

> ⚠️ 重度调用:8-9 个并行数据拉取 + 多轮新闻搜索。建议每日开盘前用一次。

### 11 US Stock Earnings Report(美股财报分析)

单只个股财报三维分析:财务 Beat/Miss + 媒体情绪 + 宏观背景。覆盖利润表趋势、Adjusted vs GAAP EPS、分析师前瞻预测、关键比率、价格动量、过去 14 天媒体报道。

**怎么问:**
- `帮我看AAPL财报`
- `TSLA earnings`
- `英伟达财报分析`
- `MSFT 财报`

**核心特性:**
- **Beat/Miss 用 Adjusted EPS**(取自 `earnings` 端点,不是 GAAP)
- **趋势表同时展示** Adjusted EPS 和 GAAP EPS
- **前瞻 PEG** 由分析师预测计算
- **价格动量**横跨 7 个时间窗(1D 到 1Y)
- **媒体情绪**取自 31 家财经媒体(Claude 推断)
- **宏观交叉验证**按板块定制(例如科技股 = 10Y 收益率 + VIX)

> ⚠️ 重度调用:每只股票需 7+ 个并行数据调用。建议在财报季用于快速过单只股票。

### 12 Macro Analyzer(宏观指标影响)

某个宏观指标发布后,对哪些板块和 ETF 有什么影响?完整链路:FRED 数据趋势 → 板块 ETF 实际表现 → 媒体解读。内置 20+ 个常用指标的映射。

**怎么问:**
- `CPI影响` / `非农解读`
- `利率影响` / `GDP解读`
- `关税分析`
- `宏观分析` / `指标分析`

**内置指标映射(节选):**

| 指标 | FRED 序列 | 利多板块 | 利空板块 | 关键 ETF |
|---|---|---|---|---|
| CPI | CPIAUCSL | 能源、原材料、地产 | 科技、可选消费 | XLE, XLB, XLK, XLY, TIP |
| 非农就业 | PAYEMS | 可选消费、金融 | 公用事业、地产 | XLY, XLF, XLU, XLRE |
| 联邦基金利率 | FEDFUNDS | 金融 | 地产、公用、科技 | XLF, XLRE, XLU, XLK |
| 10Y 收益率 | DGS10 | 金融 | 科技、地产、公用 | XLF, XLK, XLRE, TLT |
| WTI 原油 | DCOILWTICO | 能源 | 航空、运输 | XLE, JETS, USO |
| 失业率 | UNRATE | 必需消费、公用 | 可选消费、金融 | XLP, XLU, XLY, XLF |
| GDP | GDPC1 | 工业、可选消费 | 公用事业 | SPY, QQQ, IWM |

**两种验证模式:**
- **实时模式**(数据 < 7 天):ETF 走势反映市场对实际数据的反应
- **预期模式**(数据 > 7 天):ETF 走势反映市场对下次发布的定价

### 13 US Stock Divergence Scan(美股背离扫描)

批量扫描美股市场中价格、内部人交易、媒体报道之间的不一致信号,挖掘大多数投资者错过的机会。

**4 种信号类型:**

| 信号 | 检测内容 | 阈值 |
|---|---|---|
| **Silent Buy** | 内部人买入 > $100K + 媒体报道 ≤ 2 篇 | 任意市值 |
| **Sentiment Mismatch** | 价格走势与媒体情绪相反 | 市值 > $1B,价格变动 > 5% |
| **Unreported Drop** | 大市值股暴跌但几乎无人报道 | 市值 > $1B,跌幅 > 8%,文章 ≤ 3 篇 |
| **Unreported Surge** | 显著涨幅但几乎无人关注 | 市值 > $500M,涨幅 > 20%,文章 ≤ 2 篇 |

**怎么问:**
- `美股背离扫描`
- `有什么异常信号`
- `美股静默异动`
- `Unreported drop` / `Unreported surge`

**处理流程:** 拉取涨跌榜 + 内部人交易 → 按市值过滤 → 与 31 家财经媒体交叉验证 → 标注背离。命中多个信号的股票会优先展示。

> ⚠️ 所有 skill 中调用最重的一个:每只候选股都要做市值过滤 + 单独的新闻搜索。不建议高频触发。

---

## 快速对照表

| 我想知道... | 中文怎么说 | English | Skill |
|---|---|---|---|
| 今天加密市场发生了什么 | `出个日报` | `Crypto daily` | 04 |
| 现在市场在关注什么 | `今天有什么热点` | `What's hot today` | 03 |
| BTC/ETH/SOL 最近什么情况 | `BTC有什么新闻` | `Any news on BTC` | 05 |
| 大户和 KOL 在做什么方向 | `策略信号` / `SOL能不能做` | `What are traders doing` | 06 |
| TG 频道在讨论什么 | `TG上在聊什么` | `What's TG talking about` | 07 |
| 本周有什么解锁/上币 | `本周有什么解锁` | `Any token unlocks this week` | 01 |
| 这条新闻影响什么币 | 粘贴新闻 + `分析一下` | Paste news + `Analyze this` | 02 |
| BTC 宏观环境打几分 | `BTC宏观` | `BTC macro` | 08 |
| 黄金宏观环境打几分 | `黄金宏观` | `Gold macro` | 09 |
| 今天美股/宏观有什么动态 | `宏观早报` | `Morning brief` | 10 |
| 某只美股财报怎么样 | `帮我看AAPL财报` | `AAPL earnings` | 11 |
| CPI 出来了影响什么 | `CPI影响` | `CPI impact` | 12 |
| 美股有什么异常信号 | `美股背离扫描` | `Divergence scan` | 13 |

---

## Skill 路由指南

有些请求听起来很像但会路由到不同的 skill。路由规则如下:

| 你说 | 路由到 | 原因 |
|---|---|---|
| `ETH 有什么消息` | 05 Token Buzz | 在问某个币的资讯 |
| `KOL 怎么看 ETH` | 06 Trading Strategy | 在问交易策略/方向 |
| `今天有什么热点` | 03 Trending News | 在问全市场热点 |
| `出个日报` | 04 Crypto Daily | 在生成每日简报 |
| `宏观早报` | 10 Macro Morning Brief | 宏观/美股早报 |
| `TG 怎么看 BTC` | 07 TG Channel Intel | 显式提到 TG/Telegram |
| `CPI影响` | 12 Macro Analyzer | 在分析具体宏观指标 |
| `美股背离扫描` | 13 Divergence Scan | 在扫描价格/媒体背离 |
| `AAPL财报` | 11 Earnings Report | 单只股票财报分析 |

---

## 技术备注

**通过测试确认的 MCP 工具行为:**
- `finance_tool_quote` 调 `^VIX` 和 `^IXIC` —— 不能批量,必须单独调用
- `finance_tool_batch_quote_short` —— 用于 `DXUSD`(quote 返回 402),支持逗号分隔的 symbol
- `finance_tool_stable_request` —— `profile`、`analyst-estimates`、`stock-price-change` 必须用这个端点(schema 未固定)
- `finance_tool_insider_trading_search` —— 唯一可用的内部人交易端点;`stable_request` 路径 `insider-trading` 返回 404
- `fred_get_series` —— `limit` 必须为整型(不是字符串);用 `sort_order: "desc"` 拿最新数据
- `search_finance_news` —— 不支持复合关键词,每个概念分开搜;`users` 必须为数组
- `finance_tool_economic_calendar` —— 返回约 2.4MB 的全球数据,需后处理过滤美国相关事件

---

## 反馈与问题

- GitHub Issues: https://github.com/Followin-AI/Followin-Skills/issues
- npm 包: https://www.npmjs.com/package/@followin/skills
