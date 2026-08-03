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
| **[`Earnings Screener/`](./Earnings%20Screener/)** | 1 个独立 Skill | 财报季发现器——不属于任何 bundle，可单独取用（含[目录 README](./Earnings%20Screener/)：方法论映射 + 被否决方案） |
| **[`Premarket Tracker/`](./Premarket%20Tracker/)** | 1 个独立 Skill | 美股盘前自选追踪——按自选股、持仓和时区创建周期报告或即时盘前分析 |
| **[`Feed Manager/`](./Feed%20Manager/)** | 1 个 Skill | **读你自己关注的那些股票账号，让你不再刷完就忘。**每天把他们的推文变成一份简报，再按标的和板块归进累积笔记——"三周前谁在 $85 说的多"五秒能查到。你报的每笔交易自动记一条决策日志，带到期回顾提醒。三道检查防静默遗漏：有账号没拉、有推文没拉全、拉到了却没写进文件。**没有出处的数字一律不写**（含[目录 README](./Feed%20Manager/)）|
| **[`Research Reader/`](./Research%20Reader/)** | 4 个 Skill | 研报投研台——单标的研报深读：能不能信 / 信到什么程度 / 接下来盯哪天 / 还有谁被卷进来（含[目录 README](./Research%20Reader/) 与[产出样张](./docs/研报投研台样张.md)）|
| **[`Twitter Workflow/`](./Twitter%20Workflow/)** | 7 个 Skill | 推特日运营——加密/宏观/美股内容账号的「扫热点→选题→写稿→互动→复盘」流水线，MCP 实时驱动，发布永远人工确认（含[目录 README](./Twitter%20Workflow/)）|
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

**每个财报季，从几百家刚发完财报的美股里，挑出「业绩确实大幅超出华尔街预期」并且「电话会上管理层亲口说了产品不够卖」的那几家，把原话一并给你。**

想手工做这件事，得先从一堆数字里挑出营收利润明显超预期的公司，再去翻每份四五万字的财报电话会记录，
看管理层有没有说过「订单排到明年」「产能跟不上」「价格还能往上走」这类话——一个季度也翻不了几家。

**不需要指定股票代码**，它自己去找：从当天成交最活跃的股票和近期财报报道两条腿捞出候选 → 逐个核对超预期幅度 →
对最好的几家读完整份电话会记录 → **只有「业绩」和「说法」两项都达标的才进名单**。

比人工多做两件事：**同时找反面证据**——实测某标的七类正向表述全中，而同一场会上 CFO 也说了要大幅加码开支、
某块业务在下滑，只盯好话会完整错过这一半；**核对利润口径**——上游数据里两套算法的每股收益并存且不标明，
实测某标的显示"超预期 100%"，同一份数据里按通用会计准则算是**净亏 110 亿美元**。

⚠️ **每个参数都有实测反例支撑**，包括几条被推翻过的：闸门算术曾不自洽导致白烧逐字稿额度；
逐字稿滞后阈值先取 60 天，后被中概 ADR 证伪改为 90 天。版本历史见 [`CHANGELOG.md`](./CHANGELOG.md)。

---

## 独立 Skill —— 美股盘前自选追踪

告诉 AI 自选股、当前持仓和盘前时间，它会用 Followin MCP 整理市场背景、单票异动、重大新闻、研报与公开信号，并按空仓、多仓、空头或期权状态给出条件化计划。

带自动化能力的客户端会创建或更新周期任务；其他客户端立即运行一次同结构报告。美东 04:00 前没有真实盘前成交时只标“最近收盘/实时快照”，休市日不会把旧价格冒充当日盘前。安装：

```bash
cp "Premarket Tracker/premarket-watchlist-automation.md" ~/.claude/commands/
```

完整说明见 [`Premarket Tracker/README.md`](./Premarket%20Tracker/)。

---

## 研报投研台（4 个）

**你手上有一只股票，想弄明白券商研报到底怎么看它。**

研报的结论没什么秘密——媒体两三天就转述完了。难的是结论之外的东西：五家目标价差 2.4 倍到底是分歧还是在算不同的东西、
最乐观那份报告的估值方法根本不在报告里、"业绩强劲"其实强在涨价不是强在销量。这些藏在正文角落，一份份读要一下午。

| # | 模块 | 干什么 |
|---|---|---|
| **r1** | 跨源印证读数卡 | 一份研报说"目标价 350"该不该信——拿全街共识、股价走势、网红与高管动向、最近一季财报四边对撞。输出不给买卖，只答三句：**该锚哪个价、跌是哪种跌、什么信号出现了该改主意** |
| **r2** | 口径审计器 | 不看结论，只看结论的地基：这话是分析师查出来的还是**管理层路演时自己说的**？对比图是实测还是分析师建模算的？报告自己承认了什么对不上？ |
| **r3** | 催化剂时间线 | 研报点名的未来节点排成一条线——新品量产、竞品发布会、投资付款日，**公开财报日历里一个都没有**。按精确度分层，说不清的标着说不清 |
| **r4** | 产业链读穿 | 别人的研报里你这只票被放在什么位置——谁提到它、判它受益还是受损、理由是什么，以及**这条链上还有谁被改了目标价**。实测查英特尔一次顺带拿到联电目标价被上调 87%、世界先进 55% |

四支**共用同一次研报调用**，跑完 r1 之后 r2/r3/r4 都是白送的。单只股票跑满四支 = 3 次计费调用。安装：

```bash
cp "Research Reader"/*.md ~/.claude/commands/
```

⚠️ **它不帮你选股**——四支都得先点名一只票才开工。找标的用财报季扫描或背离扫描。
⚠️ 每只股票最多返回 10 份报告，去重后常剩三到五家。**任何"N 家机构怎么看"都是下限不是全街**，四支都被要求把这句写进输出。

完整说明见 **[`Research Reader/README.md`](./Research%20Reader/README.md)**；四支的实际产出样张（英特尔全链路实跑）见 **[`docs/研报投研台样张.md`](./docs/研报投研台样张.md)**。

---

## 推特日运营（7 个）

**加密/宏观/美股内容账号的日运营。** 把每天那套「扫热点 → 选题 → 写稿 → 互动 → 复盘」做成流水线：数据从 Followin MCP 实时拉、判断按预设规则跑，**稿子出到终稿为止——发布你按按钮**。

| Skill | 触发 | 干什么 |
|---|---|---|
| **twitter-ops** | 「跑一轮」 | 调度器——串流程、管自动/手动切换、检查点停下等你。**「发布必须人工确认」这条红线在这里** |
| **trend-scout** | 「扫一下热点」 | 并行拉 list/新闻/TG 资金流/链上 → 结构化简报。**实时数据区和叙事区强制分开**——硬数字归硬数字 |
| **topic-engine** | 「今天发什么」 | 热点 → 可写角度，按时效/差异化/可信度打分。**层 B 差异化**：拉对标账号近期推文，判你的角度是不是已被写过（撞了就砍或换角度）|
| **tweet-composer** | 「帮我写推文」 | 出稿：单条/Thread/长文拆解。字符预算、事实核查 6 维、发布前终检 |
| **engagement** | 「看看我评论区」 | 两头都管：**Outbound** 去别人高互动帖下抢评论位，**Inbound** 给自己评论区分级 |
| **performance-review** | 「这周数据怎么样」 | 周复盘：行业基线、北极星、内容类型效果、爆款/失败归因，好稿入素材库 |
| **competitor-watch** | 「竞对在发什么」 | 对标账号监控——学手法，看自己在坐标里的位置 |

安装（是 skill 目录，不是 command）：

```bash
cp -rn "Twitter Workflow/skills/"* ~/.claude/skills/    # -n = 不覆盖你已有的同名 skill
```

⚠️ **没有 Twitter list？** `config.md` 给了一个公开示例 list 先跑通，但它是**示例不是默认**（约 17% 内容跑题、产权不在你手上）——跑通一次后换成自己的。
⚠️ **不填会被拦。** 首次「跑一轮」检测到还是模板配置就停下、告诉你缺哪几项，不用先背配置表。

完整说明见 **[`Twitter Workflow/README.md`](./Twitter%20Workflow/README.md)**。7 支全部在 live 数据上端到端验证过；端点/字段坑记在 [`references/followin-mcp-caveats.md`](./references/followin-mcp-caveats.md) 的 N-47~N-58。

---

## 美股信息流管理（1 个）

**你关注了十几个讲股票的人。这支每天替你读一遍，并且记住他们说了什么。**

它不是热点发现器——只读**你指定的账号**。剥掉段子和广告，按标的和板块整理，**而且天天往同一份笔记里加**：跑一周之后，"三周前谁在 $85 说的多"五秒能查到，不用再翻一小时。每条都带 UTC 时间、账号、原推链接。

| 层 | 给你什么 |
|---|---|
| **日报** | 两区结构：状态区覆盖成最新、事件流按批次追加——一天拉三次无缝合并，不会叠成互相矛盾的补丁 |
| **标的 / 板块累积笔记** | 价格历史、谁在什么时候说过什么、**反方单独累积且永不删除**、你自己的仓位记录 |
| **决策闭环** | 每笔交易记录 *为什么* + 1周/1月/3月回顾提醒；教训自动反哺买卖前检查表 |
| **周报** | 持仓/板块演变、KOL 行为、账号质量 review、**你自己的决策对错复盘** |

三道检查自动跑，因为这件事出错的方式全都是无声的。**账号都拉了吗？**——覆盖表逐个标"已拉/无内容/失败"，谁都不能悄悄缺席。**他们的推文拉全了吗？**——一次调用只返 20 条，宽窗口盖不住，脚本会在没回溯到起点时告警。**拉到的都写进文件了吗？**——收尾 hook 会在你结束会话前逐个核对。外加一条贯穿全程的规矩：**每个数字都要能追溯到数据源或明确原则，没依据就不给数字。**

安装（skill 目录，不是命令）：

```bash
cp -rn "Feed Manager/skills/"* ~/.claude/skills/
```

⚠️ **零配置试跑**：用内置 5 个 starter 说「跑个快速简报」，不写任何文件。⚠️ 这 5 个偏半导体、**没有唱空账号**，正式用前补 1-2 个质疑声音——名单变成全员看多是最危险的盲区。

**边界**：这是"你自己名单"的视角。想看全网 KOL 在喊什么 → `Community Skill/c4_social-pulse`；想看真金白银的仓位 → `Trader Diligence`。

完整说明见 **[`Feed Manager/README.md`](./Feed%20Manager/README.md)**。从 [`Apatheticco/stock-kol-watch-framework`](https://github.com/Apatheticco/stock-kol-watch-framework) 同步（开发主源）。主链已在真实数据端到端实跑；两个子代理路径与周报仅模板验证。

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
| `每天盘前跟踪我的自选` / `premarket watchlist` | [盘前自选追踪](./Premarket%20Tracker/premarket-watchlist-automation.md)（独立） | 自选股 + 持仓 + 周期任务或即时盘前报告 |
| `这个目标价能信吗` / `研报解读` | [r1 跨源印证](./Research%20Reader/r1_cross-source-readout.md) | 研报结论 + 四边对撞；只看研报讲了什么走 c3 |
| `这份研报靠谱吗` / `基准是谁` | [r2 口径审计](./Research%20Reader/r2_research-caveat-audit.md) | 审地基不复述结论 |
| `接下来盯什么` / `有什么催化剂` | [r3 催化剂时间线](./Research%20Reader/r3_catalyst-timeline.md) | 研报点名的节点；"XX 哪天发财报"不走这里（日历已判废，见 caveats N-22）|
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
