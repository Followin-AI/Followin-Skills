# Followin Skills

[English](./README.md) | **简体中文**

> **接入方式已迁移** —— 连接 Followin MCP 的官方入口现为 **[followin.io/en/mcp](https://followin.io/en/mcp)**（注册即发 API Key，约 5 分钟接入，文档见[这里](https://followin.io/en/mcp/docs)）。本仓库原有的 npm 安装器已下线，仓库现在就是 Skill 文件本身。

面向加密交易、宏观分析与美股情报的 AI Agent 技能集 —— 由 **Followin MCP** 驱动。

所有技能同时支持**中英文**触发词，输出语言跟随你的提问语言。

---

## 仓库内容

| Bundle | 文件数 | 面向 |
|---|---|---|
| **[`Base Skill/`](./Base%20Skill/)** | 6 个 Skill | 个人交易者 / 分析师 —— 宏观看盘、财报分析、背离扫描、多 Agent 决策 |
| **[`Community Skill/`](./Community%20Skill/)** | 6 个 Skill | 社群运营 —— 面向美股新手社群的可直接发布贴文（繁体中文产出）|
| **[`Earnings Screener/`](./Earnings%20Screener/)** | 1 个独立 Skill | 财报季发现器——不属于任何 bundle，可单独取用 |
| **[`references/`](./references/)** | 4 个文件 | 共享单一事实源：官方路由 primer、MCP 调用红线、Agent 人设、贴文风格 |

全部为纯 Markdown，无构建步骤，除 MCP 服务器外无任何运行时依赖。

---

## 接入

**1. 获取 API Key** —— 在 [followin.io/en/mcp](https://followin.io/en/mcp) 注册。

**2. 连接 MCP 服务器。** 官方端点是 **Streamable HTTP** 传输的 `https://mcp.followin.io/v2/mcp`，用 `x-api-key` 头鉴权。

Claude Code：

```bash
claude mcp add followin https://mcp.followin.io/v2/mcp --scope user --transport http --header "x-api-key: YOUR_API_KEY_HERE"
```

其他客户端 —— 把下面这段粘进对应配置文件，替换 `YOUR_API_KEY_HERE`：

```json
{
  "mcpServers": {
    "followin": {
      "type": "http",
      "url": "https://mcp.followin.io/v2/mcp",
      "headers": { "x-api-key": "YOUR_API_KEY_HERE" }
    }
  }
}
```

> **SSE 旧端点**：不支持 Streamable HTTP 的老客户端仍可用 `"type": "sse"` + `https://mcp.followin.io/v2/sse`（头相同）。2026-07-24 实测可用，但官方文档给的是上面的 Streamable HTTP 端点，新接入优先用它。

| 客户端 | 配置文件 |
|---|---|
| Claude Code | `~/.claude.json`（全局）或 `<项目>/.mcp.json` |
| Claude Desktop | `~/Library/Application Support/Claude/claude_desktop_config.json` · `%APPDATA%\Claude\claude_desktop_config.json` |
| Cursor | `~/.cursor/mcp.json` |
| Windsurf | `~/.codeium/windsurf/mcp_config.json`（字段用 `serverUrl` 而非 `url`）|
| Cline | Cline 面板 → MCP Servers（齿轮图标）|
| Continue.dev | `~/.continue/config.yaml`（JSON 转 YAML）|

改完重启客户端。

**3. 安装 Skill 文件**（可选）—— 把需要的文件复制进客户端的命令目录：

```bash
cp "Base Skill"/*.md ~/.claude/commands/
```

Skill 采用 Claude Code 的 slash-command 格式（YAML frontmatter + Markdown 正文），可直接放入 Claude Code 与 OpenCode。Cursor / Windsurf / Cline 需要把正文复制进各自的原生规则格式 —— Markdown 本身完全可移植。

> **第 3 步可以整个跳过。** MCP 接通后，模型靠工具本身就能回答大多数问题。Skill 额外提供的是**实测过的调用序列、打分口径和输出模板**。

---

## MCP：5 个工具

| 工具 | 覆盖范围 |
|---|---|
| **`metrics`** | 实时行情与报价（加密 / 美股 / ETF / 全球指数 / 外汇 / 大宗）、历史 OHLCV、技术指标、FRED 宏观指标、经济日历、美股基本面（三表 / 估值 / 同行 / 分析师评级 / Beat-Miss / EPS 预期），以及**结构化券商研报**（报告卡 / 目标价 / thesis / catalysts / caveats）|
| **`news`** | 四源聚合 —— `media` / `twitter` / `telegram` / `research`，含 trending 模式、多语言原文、100+ 加密 TG 频道自动归入 10 类主题 |
| **`signal`** | KOL 喊单、顶级交易员与鲸鱼持仓、内部人交易（Form 4 + 参议院 + 众议院）、13F 机构持仓 |
| **`twitter`** | 高级搜索、用户档案与时间线、互关验证、完整线程上下文、地区热门趋势 |
| **`subscription`** | KOL 喊单标的的关注收件箱 —— 订阅 / 列表 / 未读查询（拉取式，无服务端推送）|

**几条关键约定**：

- 美股传 `asset_type="tradfi"`，加密传 `asset_type="crypto"`，且必须显式传 —— 唯一例外是 `news()`，它不应该收到这个参数。
- **结构化券商研报走 `metrics`，不走 `news`**。`news(sources=["research"])` 是研报来源的**原始文章**检索；报告卡、目标价、thesis/catalyst 这些结构化字段来自 `metrics(categories=["fundamentals"])`。
- **`signal()` 省略 `categories` 会 fanout** 到内部人交易 + 13F 机构持仓 + KOL 喊单，**三类合计只计 1 次额度** —— 比分三次带过滤条件调用更省，且数据完全相同。

完整调用红线与已知问题登记见 [`references/followin-mcp-caveats.md`](./references/followin-mcp-caveats.md)。

---

## 基础 Skill（6 个）

按推荐入门顺序编号 —— 01 最深，06 最轻。

| # | Skill | 怎么问 | 依赖工具 |
|---|---|---|---|
| **01** | [多 Agent 深度分析](./Base%20Skill/01_multi-agent-stock-analysis.md) | `NVDA 值不值得买` · `全面分析 NVDA` | `metrics` `news` `signal` |
| **02** | [美股财报分析](./Base%20Skill/02_us-stock-earnings-report.md) | `AAPL 财报` · `AAPL earnings` | `metrics` `news` `signal` |
| **03** | [美股背离扫描](./Base%20Skill/03_us-stock-divergence-scan.md) | `美股背离扫描` · `内部人悄悄买入` | `metrics` `news` `signal` |
| **04** | [BTC 宏观看盘](./Base%20Skill/04_btc-macro-dashboard.md) | `BTC 宏观` · `BTC macro` | `metrics` |
| **05** | [黄金宏观看盘](./Base%20Skill/05_gold-macro-dashboard.md) | `黄金宏观` · `Gold macro` | `metrics` |
| **06** | [宏观早报](./Base%20Skill/06_macro-morning-brief.md) | `宏观早报` · `Morning brief` | `metrics` `news` |

### 01 —— 多 Agent 深度分析

19 位虚拟分析师（8 位传奇投资者 + 5 位现代大师 + 6 位量化分析师）独立打分，风控经理约束仓位，组合经理综合决策 —— 合计 21 个 Agent，对标 ai-hedge-fund 架构。11 路调用序列已完整覆盖官方尽调编排。分析师人设见 [`references/01_agent-prompts.md`](./references/01_agent-prompts.md)。

### 02 —— 美股财报分析

单股财报三维分析：财务 Beat/Miss + 媒体情绪 + 宏观背景，另加机构研报层与信号面 fanout（内部人 / 13F / KOL 喊单）。必须点名具体代码或公司名才触发。

### 03 —— 美股背离扫描

发现价格、内部人交易与媒体报道三者之间的不一致 —— 也就是"没人报道却在动"的标的。可传 `scope` 与 `days`。

### 04 / 05 —— BTC / 黄金宏观看盘

把当前宏观环境打成 0–100 分并给出分层拆解，让"环境怎么样"有个数而不是一句感觉。两者都通过 `metrics` 拉 FRED 指标与行情快照。

### 06 —— 宏观早报

宏观 + 新闻 + 异动三源聚合的每日晨间简报，可传 `watchlist`。这是**宏观/美股**维度的早报；本仓库没有加密日报 Skill。



---

## 独立 Skill —— 财报季超预期扫描

把「财报季挨个看业绩大增公司、扫电话会高景气表述」这套人肉选股法自动化。**无需指定 ticker 的发现器**：
异动榜 + 新闻反向捞双腿发现 → 四道业绩硬闸 → Top N 逐字稿深扫 → **业绩闸与关键词闸叠加**才算数。

比原方法多两样：**反向关键词减分**（防确认偏误——实测某标的七类正向词全中，但 CapEx 上修与库存减记同样出自 CFO 之口）
和 **GAAP 口径错位检测**（防把 GAAP 净亏 110 亿美元的季度读成「完美超预期」）。

⚠️ **每个参数都有实测反例支撑**，包括几条被推翻过的：闸门算术曾不自洽导致白烧逐字稿额度；
逐字稿滞后阈值先取 60 天，后被中概 ADR 证伪改为 90 天。版本历史见 [`CHANGELOG.md`](./CHANGELOG.md)。

---

## 社群运营 Bundle（6 个）

面向**运营人员**的独立 bundle，服务美股新手社群，产出为可直接复制粘贴的繁体中文贴文。完整操作手册 —— 模块索引、每周运营节奏、额度预算、置顶帖模板 —— 见 **[`Community Skill/README.md`](./Community%20Skill/README.md)**。

| # | 模块 | 产出 |
|---|---|---|
| **c1** | 每日早報 | 晨報 · 開盤前瞻 · 盤中刷新 |
| **c2** | 週報 | 上周"预期 vs 兑现"回顾 + 本周日历 |
| **c3** | 研報熱議榜 | 每周研报密集度榜 + 深度研究笔记 |
| **c4** | 熱議標的溫度計 | 推特情绪 × 真金白银 × 内部人三维交叉，或全市场讯号汇总 |
| **c5** | 熱點掃描 | 热点菜单 + 300–500 字速报贴 + 财报速读 |
| **c6** | 選題速查 | 运营内部备忘 —— 这个标的值不值得写？*（不对外发布）* |

---

## 路由

听起来相近但会走到不同 Skill 的请求：

| 你说 | 路由到 | 为什么 |
|---|---|---|
| `NVDA 值不值得买` | 01 多 Agent | 点名标的 + 买卖决策 |
| `AAPL 财报` / `AAPL earnings` | 02 财报分析 | 点名标的 + 财报 |
| `背离扫描` / `Divergence scan` | 03 背离扫描 | 价格/媒体/内部人不一致 |
| `BTC 宏观` / `BTC macro` | 04 BTC 看盘 | 单一资产的宏观评分 |
| `宏观早报` / `Morning brief` | 06 宏观早报 | 宏观/美股维度的每日简报 |
| `财报季扫描` / `earnings screener` | [财报季扫描](./Earnings%20Screener/earnings-season-screener.md)（独立）| **无 ticker 的发现器**；点名单股走 Base Skill 02 |
| `CPI 影响` / `CPI impact` | *（无专门 Skill）* | 指标解读是模型自带能力——直接调 `metrics`+`news`；FRED 字典见 caveats 附表 A |

每个 Skill 的 frontmatter 都带显式的 `trigger` 与 `not_trigger` 列表 —— 这是相邻 Skill 不互相抢词的关键。

---

## 维护纪律

`references/followin-mcp-caveats.md` 是 MCP 调用红线与已知上游问题的**单一事实源**。各 Skill 内联的 caveat 是它的本地镜像，**冲突时以该文件为准**。

MCP 行为变更时：**先改这个文件，再 sweep 各 Skill 的内联镜像**。登记表同时记录了每个问题的"Dev 修复后回滚动作"，上游修好后可以据此撤掉 workaround。

---

## 定价与支持

套餐、额度与限速：**[followin.io/en/mcp](https://followin.io/en/mcp)** · 文档见 [followin.io/en/mcp/docs](https://followin.io/en/mcp/docs)。

Bug 与需求：[GitHub Issues](https://github.com/Followin-AI/Followin-Skills/issues)。

MIT 许可。
