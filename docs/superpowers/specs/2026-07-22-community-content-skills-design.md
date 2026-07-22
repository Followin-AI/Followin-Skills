# 社群内容运营 Skill Bundle（skills-community）设计文档

> 日期：2026-07-22
> 状态：设计定稿，待实现
> 背景：美股新手交易社群（首例：Lynette 团队）需要可持续的内容供给。本 bundle 交付对方团队自己跑：对方配自己的 Followin MCP key，在 Claude 客户端用自然语言触发，产出直接可粘贴的社群贴文。对 Followin 是 MCP 获客案例。

## 1. 需求与边界

对方原始诉求（三个愿望）：
1. 每日重点新闻消息
2. 即将有重大发布的标的
3. 大事件下来时重点影响的标的
前置诉求：让新手可以大略学习和科普。

已确认的决策：
- **v1 范围**：早报 + 事件预告 + 研报热议 + 推特热议/信号，共 4 模块；实盘交易跟踪留 v2。
- **产出形态**：直接可复制粘贴的繁体中文社群贴文，运营零加工即发。网站二次加工由对方自理。
- **科普形态**：嵌入式——每篇贴文自带白话解释（"可以粗略理解成…"句式）+ 每篇末尾一张"今日名詞"卡（从当天内容里抽一个术语）。不做独立科普课程模块。
- **额度**：不设硬约束，质量优先。实测下来全套月耗约 180 点，Basic（1000/月）绰绰有余，作为对外话术优势保留。

## 2. 架构（方案 B）

```
skills-community/
├── README.md                 # bundle 索引 + 安装 + 触发词对照（对齐 skills-v2 模式）
├── c1_daily-brief.md         # 每日早报（日跑）
├── c2_event-radar.md         # 事件预告（周跑）
├── c3_research-hot.md        # 研报热议榜 + 单标的研究笔记（周跑）
└── c4_social-pulse.md        # 热议标的温度计：推特喊单 × 实盘 × 内部人（周跑）
.claude/references/
├── followin-mcp-caveats.md   # 既有 SSOT，新增本次实测 caveat（见 §6）
└── community-post-style.md   # 新增 SSOT：贴文风格规范
```

维护纪律沿用现行模式：MCP 行为变更 → 先改 caveats SSOT → sweep 各 skill 内联镜像（镜像只抄用到的条目）。风格规范同理。

## 3. 共享风格规范（community-post-style.md）

内容清单：
- **语言**：繁体中文，台湾用词表（本益比/標的/財報/雲端/晶片/記憶體…），禁止简体词混入。
- **白话红线**：不用术语、英文字段名、内部黑话；检验标准 = 不炒股的朋友能听懂。术语首次出现必须跟白话翻译。
- **贴文骨架**（所有模块共用）：
  1. 标题：📌 + 栏目名 + 标的/主题
  2. 一句話先懂（≤40 字结论）
  3. 模块正文（各 skill 自定义 2-4 节）
  4. 接下來看什麼（可验证的前瞻观察点）
  5. 今日名詞卡（术语 + "可以粗略理解成…" + 一句局限提醒）
  6. 免责声明（固定文案：整理自公開研報與市場數據，僅做資訊分享，不構成投資建議）
- **长度**：单篇 500-800 字（社群一屏内）；c3 研究笔记可放宽到 1000 字。
- **多空平衡**：任何看多内容必须带一条空方视角或风险；跨源数据打架时明说（"三個溫度計指向不同方向"），不硬圆。
- **禁止事项**：不给买卖指令、不给仓位建议、不预测短线涨跌、不使用"必涨/起飞/上车"类词汇。

## 4. 四个模块设计

### c1 每日早报（日跑，盘前）

调用序列（实测额度 ≈4/天）：
| 步骤 | 调用 | 额度 |
|---|---|---|
| 1 | `news(空 query, asset_type="tradfi", time_range="24h")` 热点趋势榜 | 0（实测） |
| 2 | `metrics(query="biggest gainers")` / `"biggest losers"` 各一次 | 2 |
| 3 | `metrics(query="earnings calendar", asset_type="tradfi", date_from=今日, date_to=明日)` 拿当日财报名单，按 c2 同款规则过滤 | 1 |
| 4 | 过滤后重点股（≤10）`metrics(keywords=[…], asset_type="tradfi")` 快照 | 1 |

产出结构：昨夜三件事（每件带"为什么和你有关"）→ 涨跌榜看点（过滤后）→ 今日看什么（当天财报/数据）→ 今日名詞卡。

防坑规则：
- movers 按 caveats 红线 9 过滤（杠杆 ETF/仙股 <$5/微盘）。
- 趋势榜内容含代币化股票与加密混排（实测 SKHYx、LAB 代币），按"美股正股白名单"原则剔除。
- news 搜索模式不传 asset_type（红线）；趋势模式（空 query）可传，见新 caveat N-1。

### c2 事件预告（周跑，周日/周一）

调用序列（≈3/周）：
| 步骤 | 调用 | 额度 |
|---|---|---|
| 1 | `metrics(query="earnings calendar", asset_type="tradfi", date_from/date_to=未来7天)` | 1 |
| 2 | 初筛 shortlist ≤10 批量快照补市值 | 1 |
| 3 | `metrics(keywords=["economic calendar"], categories=["macro"])` | 1 |

财报日历过滤（新 caveat N-2）：只留无交易所后缀的美股 symbol → `revenueEstimated > $1B` 初筛 → 市值排序取 Top 5-8。
经济日历 query 严禁带"本周"（红线 10）。

产出结构：本周财报（谁、哪天、市场在赌什么）→ 本周宏观数据（哪天、为什么重要）→ 每个事件一句"影响哪些标的" → 名词卡。

### c3 研报热议榜 + 研究笔记（周跑）

两层产出，调用序列（≈4-6/周）：
| 步骤 | 调用 | 额度 |
|---|---|---|
| 1 | `metrics(query="research reports most mentioned stocks", asset_type="tradfi", time_range="7d")` 聚合榜 | 1 |
| 2 | 对榜单 Top 3-5 逐个 `metrics(keywords=[TICKER], query="research reports", verbosity="detail", time_range="7d")` | 各 1 |

层 1 周榜贴：本周机构最密集讨论标的（提及篇数/机构家数/多空方向/目标价覆盖）。
层 2 研究笔记贴（对标 lynette.io 页面结构，数据纵深更强）：一句話先懂 → 最新動態（融合 c4 推特层，见下）→ 機構怎麼看（多机构目标价区间标准化 + 对现价上行/回撤，注明分歧）→ 空方在擔心什麼（研报 risks + bear scenario）→ 接下來看什麼（catalysts 时间线）→ 名词卡。

防坑规则：
- 同一报告可能双 event_id 入库（实测花旗重复），按 机构+标题+日期 去重（新 caveat N-3）。
- detail 返回自带实时行情快照，上行空间就地计算，不再花额度。
- 非美股 ticker（2330.TW、005930.KS）默认保留但标注市场，运营可删。
- 研报查询 query 必含研报意图词（既有红线 12）。

### c4 热议标的温度计（周跑，可事件驱动加跑）

调用序列（≈4-6/周）：
| 步骤 | 调用 | 额度 |
|---|---|---|
| 1 | `signal(query="consensus", asset_type="tradfi", time_range="3d")` 无 categories 一次拿全四类（新 caveat N-4） | 1 |
| 2 | 对喊单榜 Top 3-5 逐个 `signal(keywords=[TICKER], query="详细仓位", asset_type="tradfi", time_range="7d")` 四维钻取 | 各 1 |
| 3 | （可选）`news(query="<TICKER> <公司名>", time_range="24h")` 补推特层原文 | 0（实测） |

产出结构：本周推特在吵什么（喊单聚合榜 + 多空比）→ 每个标的的温度计三格：
- 推特情緒（喊单方向比 + A 级 KOL 代表观点，正反都放）
- 真金白銀（实盘持仓方向/人数/杠杆——数据薄就明说薄）
- 內部人動向（近 90 天 S-Sale/P-Purchase，剔除 F-InKind）
→ 跨源打架时明写结论（"情緒滿格 ≠ 大錢進場"）→ 名词卡。

防坑规则（本次实测新增，详见 §6）：
- kol_call 按提及展开，一条推文裂成多行：按 source_url 去重、按 symbol 字段归属（N-5）。
- insider/congress 行无视 time_range，必须客户端按 transactionDate 过滤（N-6）。
- 13F 申报季中期数据残缺，禁止引用环比（N-7）。
- trader_position 过滤 tier 为空/notional null 的行；美股覆盖日级剧变，只能当天现拉、按 underlying 合并符号分裂（既有 caveat）。
- stock_perp 是代币化股票永续，呈现时标注"鏈上股票永續交易員"而非"美股交易員"。
- signal query 不放"KOL"等元词（会被解析成 crypto 关键词，实测空返）。

## 5. 错误处理与数据诚实

- SSE 并发 ≤4（红线 2）；每次调用后检查 `meta.warnings`（keyword_count_over_max 等）。
- 任一数据维度为空/薄：贴文对应板块降级为一句诚实说明（"本週實盤數據樣本太薄，不足以下判斷"），禁止编造或沿用旧数据。
- news 无匹配时返回语义兜底内容（红线 11）：所有"无报道/热议"判定按 LLM 逐条相关性判断，不用 raw count。
- 所有价格/目标价必须来自当次调用返回，禁止使用模型记忆里的数字。

## 6. caveats SSOT 回写清单（本次实测 2026-07-22，共 7 条新增/修订）

| 编号 | 内容 | 动作 |
|---|---|---|
| N-1 | news 趋势模式（空 query）传 asset_type="tradfi" 可用且 0 额度；"news 不传 asset_type"红线仅适用搜索模式。实体搜索（query="NVDA Nvidia"）实测也 0 额度 | 修订红线 1 例外条款 |
| N-2 | earnings calendar 市场级可用（query+date_from/to），但返回全球交易所混排、无市值字段；过滤 = 无后缀 symbol + revenueEstimated 初筛 + 二次调用补市值 | 新增红线 |
| N-3 | 研报同一份报告可双 event_id 重复入库；按 机构+标题+日期 去重 | 新增登记 |
| N-4 | signal 不带 categories 默认 fanout 全 4 类且只计 1 额度（省额度利器）；kol_call tradfi 聚合原生可用（top_calls 多空计数） | 新增红线 |
| N-5 | kol_call 原帖按提及 fanout 成多行（同 URL 不同 symbol/方向）；按 source_url 去重、symbol 字段归属 | 新增红线 |
| N-6 | insider/congress 行无视 time_range（7d 返回 2020 年记录）；客户端按 transactionDate 过滤强制 | 新增登记（Dev 待修） |
| N-7 | 13F institutional 申报季中期 investorsHolding 环比为残缺假信号（实测 NVDA 6234→1441）；申报季内禁止引用环比 | 新增红线 |

另：F-InKind/M-Exempt 为缴税代扣非主动减持，扩充既有 insider 条目的解读规则。

## 7. 验收标准

1. **可复现**：干净 Claude 客户端 + Followin MCP key + skill 文件，一句触发词跑通各模块，产出完整贴文。
2. **风格合规**：繁体、大白话检验（不炒股的朋友能听懂）、≤800 字（c3 笔记 ≤1000）、名词卡与免责声明必在。
3. **数据诚实**：抽查贴文中每个数字可回溯到当次 MCP 返回；§4 各模块防坑规则全部生效（用 MU/NVDA 实测样本做回归）。
4. **额度**：单轮消耗不超过 §4 各表标称值 +2。
5. **触发准确**：各 skill 触发词互不误撞（"跑早報"≠"跑溫度計"），frontmatter 含 not_trigger。

## 8. v2 backlog（不在本期）

- 实盘交易跟踪模块（trader_position 深挖，等美股覆盖变厚）
- 事件驱动即时贴（大事件落地 → 受影响标的速报）
- 结构化数据双轨输出（对方网站直接入库渲染）
- 简体版风格包（其他社群复用）

## 9. 实测记录索引

本设计的全部调用路径均于 2026-07-22 在线实测验证，样本：NVDA（研报钻取/新闻/推特）、MU（四维交叉）、市场级（趋势榜/财报日历/研报聚合榜/喊单聚合）。额度实测：news 搜索与趋势 0 消耗，metrics/signal 每次 1 消耗，signal 无 categories fanout 亦为 1。
