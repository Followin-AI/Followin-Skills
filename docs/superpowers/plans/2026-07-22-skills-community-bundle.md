# skills-community Bundle 实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 落地美股新手社群运营 skill bundle：6 个 skill 文件 + 贴文风格 SSOT + caveats 回写 + README 运营手册，全部按已批准 spec（`docs/superpowers/specs/2026-07-22-community-content-skills-design.md`）实现并用 NVDA/MU 实测样本回归验收。

**Architecture:** 纯 Markdown skill 文件（对齐 skills-v2 惯例：YAML frontmatter + 意图路由 + 调用映射 + 执行步骤 + 输出模板 + caveat 内联镜像），双 SSOT（caveats + post-style）供镜像，无任何脚本依赖（对方客户端不保证 Bash/Python）。

**Tech Stack:** Followin MCP（metrics/news/signal）、Markdown、git。

## Global Constraints（每个任务隐含遵守）

- **调用形态铁律**：所有 MCP 调用写法以 query 串为主（`query="NVDA research reports"`），数组形式仅作备注（spec §2；2026-07-20 起数组全域被拒）。skill 文件中出现的每个调用示例都必须同时给出 query 主形态。
- **SSE 并发 ≤4**；调用后检查 `meta.warnings`；session 短挂重试 1 次。
- **产出语言**：贴文模板与样例=繁体中文（台湾用词）；skill 文件说明文字=简体中文（与 skills-v2 一致）。
- **纯文本兼容**：所有对外贴文模板不使用 markdown 加粗/标题/表格，视觉层级只用 emoji + 空行 + 「｜」。
- **frontmatter 惯例**：name / description / trigger / not_trigger / mcp / args（对照 `skills-v2/02_us-stock-earnings-report.md`）。
- **YAGNI**：只实现 spec 有的内容；发现 spec 缺口先停下来问用户，不自行加戏。
- **提交风格**：中文 conventional 风格短消息（对齐仓库近期提交），每个任务至少一次提交。
- **spec 为唯一事实源**：任务里的调用序列、防坑规则、模板骨架与 spec 冲突时以 spec 为准并停下来报告。

## 文件结构（全量新建/修改清单）

| 动作 | 路径 | 职责 |
|---|---|---|
| Create | `skills-community/README.md` | bundle 索引/安装/触发词对照/节奏表/额度预算/置顶帖模板/定时任务示例 |
| Create | `skills-community/c1_daily-brief.md` | 晨/晚双时段早报 + 刷新模式 |
| Create | `skills-community/c2_event-radar.md` | 週報（上周回顾+本周预告） |
| Create | `skills-community/c3_research-hot.md` | 研报热议榜 + 单标的研究笔记 |
| Create | `skills-community/c4_social-pulse.md` | 热议标的温度计 |
| Create | `skills-community/c5_hot-take.md` | 热点扫描菜单 + 速报/财报速读 |
| Create | `skills-community/c6_ticker-check.md` | 运营内部选题速查（产出不对外） |
| Create | `.claude/references/community-post-style.md` | 贴文风格 SSOT |
| Modify | `.claude/references/followin-mcp-caveats.md` | 回写 N-1~N-11 + 红线 1/6/9 修订 + insider 解读扩充 |
| Modify | `docs/superpowers/specs/2026-07-22-community-content-skills-design.md` | 终态标记（Task 11） |

---

### Task 1: 贴文风格 SSOT（community-post-style.md）

**Files:**
- Create: `.claude/references/community-post-style.md`

**Interfaces:**
- Produces: 六个 skill 文件将镜像引用的编号规范：`S-1 语言` `S-2 白话红线` `S-3 贴文骨架(7 段)` `S-4 长度` `S-5 多空平衡` `S-6 禁令` `S-7 五条运营铁律` `S-8 更正贴模板` `S-9 平台兼容` `S-10 名词卡规则` `S-11 免责文案` `S-12 发前自检清单` + `templates 节`（含 4 份已核可样例）。skill 文件内联镜像时按编号引用（"镜像 S-6/S-7/S-12"）。

- [ ] **Step 1: 写文件**

完整内容（spec §3 逐条展开为编号规范；关键固定文案逐字如下）：

```markdown
# 社群贴文风格规范（skills-community 共享 SSOT）

> 6 个 c* Skill 共享的对外文风与合规单一事实源。各 Skill 内联镜像本文件条目，
> 冲突以本文件为准。维护纪律：风格变更 → 先改本文件 → 再 sweep 6 个 Skill 镜像。

## S-1 语言
繁体中文（台湾用词）。用词表：本益比(PE)/標的/財報/雲端/晶片/記憶體/庫存/
營收/獲利/盤前盤後/殖利率/評等/目標價/週線/放空。禁止简体词混入贴文。

## S-2 白话红线
不用术语、英文字段名、内部黑话；术语首次出现必跟白话翻译（"可以粗略理解成…"句式）。
检验标准：不炒股的朋友能听懂。

## S-3 贴文骨架（七段，对外模块通用）
1 标题（📌+栏目名+主题）2 一句話先懂(≤40字) 3 模块正文(2-4节)
4 接下來看什麼 5 今日名詞卡 6 免责声明(S-11) 7(可选)互動鉤子——
只出现在 c1/c5、一天最多一次、问题无立场不诱导买卖方向、c3/c4 严肃内容不加。

## S-4 长度
单篇 500-800 字；c1 晨报与 c3 研究笔记 ≤1000 字；c1 晚间前瞻/刷新 200-400 字；
c5 速报 300-500 字；c6 内部备忘 ≤300 字。

## S-5 多空平衡
任何看多内容必带一条空方视角或风险；跨源数据打架时明说，不硬圆。

## S-6 禁令
不给买卖指令、不给仓位建议、不预测短线涨跌；禁用"必涨/起飞/上车/梭哈/抄底"。

## S-7 五条运营铁律（源自 trend-scout 实战）
铁律1 单源：地缘/政策/监管大消息 ≥2 独立信源才当事实，否则标「消息尚待確認」。
铁律2 价格：当前价/涨跌幅只引本次 MCP 返回值；新闻与 KOL 转述的百分比是二手，必经快照核实。
铁律3 禁凑数：无大事就写「今日平靜」，禁陈货硬凑。
铁律4 时间：宏观/财报时间标 美东+台北 双时区；禁按惯例推算日期。
铁律5 时效：引用行情标「截至 XX:XX」；>12h 旧闻不得当"实时热点"。

## S-8 更正贴模板
「🔁 更正｜MM/DD 那篇〈标题〉
錯在哪：…
正確是：…
原因：…（一句）
造成困擾抱歉，我們對數據負責。」
24h 内主动发；skill 跑动中发现与已发内容矛盾必须提示运营，禁止静默带过。

## S-9 平台兼容（默认纯文本）
不依赖 markdown 加粗/标题/表格；层级靠 emoji（📌🔍🐦⚠️🔥）+ 空行 + 「｜」。
平台确认后可另加渲染增强版。

## S-10 名词卡规则
每篇一张：从当天内容抽 1 个术语；结构=术语名+「可以粗略理解成…」+一句局限提醒。

## S-11 免责文案（逐字固定）
对外贴文版：「⚠️ 以上整理自公開研報與市場數據，僅做資訊分享，不構成投資建議。」
c6 内部备忘尾行：「⚠️ 此為內部備忘，發佈請走 c5/c3 成稿。」

## S-12 发前自检清单（每篇产出前逐项过）
繁体✓ 大白话✓ 字数✓ 名词卡✓ 免责✓ 多空平衡✓ 单源标注✓ 价格可回溯✓

## templates（已核可样例，验收基准）
### T-1 c3 研究笔记样例（NVDA，2026-07-22 核可）
[逐字收录本会话已确认的 NVDA 貼文全文——含「📌 本週研報熱點｜NVDA 輝達」至免责行，
及「推特風向」插入段]
### T-2 c1 晨报骨架样例（2026-07-22 核可）
[逐字收录六段骨架示例：大盤一眼/昨夜三件事/推特風向/漲跌榜看點/今日看什麼/名詞卡]
### T-3 c5 扫描菜单样例
[逐字收录 spec §4-c5 的三条编号菜单示例]
### T-4 c6 内部备忘样例（MU，用本会话实测数据）
「🔍 MU 速查｜7/22 16:40
行情位置：$1,170 附近，52週區間上緣
機構共識：（家數+中位+分歧，按實測填）
近期敘事：DRAM 漲價+SK 海力士會長口徑，推特 24h 9 帖全多
信號面：實盤僅 1 無評級交易員輕倉多；CEO 5-6 月連續真賣出(S-Sale)
→ 📌 建議並入本週溫度計：情緒滿格但真金白銀沒跟上，適合跨源打架敘事
⚠️ 此為內部備忘，發佈請走 c5/c3 成稿。」
```

T-1/T-2/T-3 三处 `[逐字收录…]` 为排版占位说明：**实现时必须把本会话已核可的样例全文逐字粘入**（NVDA 贴文与推特風向段见 spec 评审对话 2026-07-22；T-2/T-3 见 spec §4）。落盘后文件中不得残留方括号占位。

- [ ] **Step 2: 结构校验**

Run: `grep -c "^## S-" .claude/references/community-post-style.md`
Expected: `12`
Run: `grep -c "逐字收录\|\[" .claude/references/community-post-style.md | head -1`
Expected: T-1~T-3 已替换为真实全文，grep "逐字收录" 返回 `0`

- [ ] **Step 3: Commit**

```bash
git add .claude/references/community-post-style.md
git commit -m "feat(community): 贴文风格 SSOT——12 条编号规范 + 4 份核可样例"
```

---

### Task 2: caveats SSOT 回写（N-1~N-11）

**Files:**
- Modify: `.claude/references/followin-mcp-caveats.md`

**Interfaces:**
- Produces: 编号条目 N-1~N-11（skill 文件镜像时按 "红线 N-x" 引用）；红线 1/6/9 修订文本。

- [ ] **Step 1: 检查既有未提交改动**

Run: `git diff .claude/references/followin-mcp-caveats.md | head -30`
该文件工作区已有未提交改动（会话开始时已存在）。若 diff 非空：本任务只在文件上追加/修订下述条目，提交前把完整 diff 给用户过目确认是否连带提交既有改动；用户未确认前只 add 本文件并在提交信息中注明"含既有未提交改动"或按用户指示拆分。

- [ ] **Step 2: 写入修订与新增**

在「调用红线」节修订三条（在原条目后追加句子，不删原文）：
- 红线 1 追加：`例外扩展（2026-07-22 实测）：news 趋势模式（空 query）传 asset_type="tradfi" 可用且 quota=0；实体搜索亦 quota=0。"不传 asset_type"仅约束搜索模式的过滤语义。`
- 红线 6 追加：`⚠️ CLUSD 被 trend-scout 2026-07 实测 402 Special Endpoint；原油优先 BZUSD/USO，CLUSD 待复核（N-11）。`
- 红线 9 整条替换为：`mover 榜：biggest gainers/losers 上游缺 marketCap 且全是仙股（trend-scout v1.8.0 实测）——弃用；改 query="most active stocks"（返回行自带 marketCap），客户端过滤 marketCap ≥$1B + 剔杠杆 ETF（name 含 2X/3X/Long/Short/Bull/Bear/Daily/Leveraged）+ 仙股 <$5。movers 仅美股。`

在「已知问题登记」表后新增「### 2026-07-22 社群 bundle 实测新增（N 系列）」小节，表格逐字（spec §6 两张表合并，列：编号/内容/Workaround/来源）：N-1 趋势模式例外、N-2 财报日历全球混排过滤（无后缀 symbol+revenueEstimated 初筛+二次补市值）、N-3 研报双 event_id 去重（机构+标题+日期）、N-4 signal 无 categories fanout 全 4 类计 1 额度、N-5 kol_call 按提及裂行（source_url 去重/symbol 归属/query 禁元词）、N-6 insider/congress 无视 time_range（客户端按 transactionDate 过滤强制）、N-7 13F 申报季环比假信号（申报季禁引环比）、N-8 数组参数全域被拒（query 串替代；Dev 修复后回退）、N-9 movers 换 most_actives（对应红线 9 修订）、N-10 metrics time_range<1d 返旧数据（小时级用 interval/实时快照）、N-11 指数白名单 ^GSPC ^IXIC ^DJI ^VIX 可用、^DXY/CLUSD/NGUSD 402（红线 6 复核项）。另在 insider 聚簇条目追加：`F-InKind/M-Exempt 为缴税代扣非主动交易；对外表述"内部人卖出"只认 S-Sale，买入只认 P-Purchase。`

- [ ] **Step 3: 校验**

Run: `grep -c "N-1\b\|N-2\b\|N-3\b\|N-4\b\|N-5\b\|N-6\b\|N-7\b\|N-8\b\|N-9\b\|N-10\b\|N-11\b" .claude/references/followin-mcp-caveats.md`
Expected: ≥11

- [ ] **Step 4: Commit（按 Step 1 的确认结果执行）**

```bash
git add .claude/references/followin-mcp-caveats.md
git commit -m "docs(caveats): 回写 2026-07-22 实测 N-1~N-11 + 红线 1/6/9 修订 + insider 解读扩充"
```

---

### Task 3: c1_daily-brief.md（晨/晚双时段早报）

**Files:**
- Create: `skills-community/c1_daily-brief.md`

**Interfaces:**
- Consumes: S-1~S-12、T-2（Task 1）；红线/N 系列（Task 2）
- Produces: 触发词 `早報/晨報/開盤前瞻/刷新` 归此 skill；README（Task 9）引用其额度 7-10/天

- [ ] **Step 1: 写文件**

frontmatter 逐字：

```yaml
---
name: Community Daily Brief (c1 — 社群美股早報·晨晚雙時段)
description: 美股新手社群每日早報。晨報（台北早晨）=昨夜收盘复盘+今日看点六段结构；開盤前瞻（台北21:00前后）=盘前三段精简版；刷新=盘中增量补丁。产出直接可贴社群的繁体贴文。仅供运营使用。
trigger: 早報、晨報、跑早报、社群早报、開盤前瞻、开盘前瞻、刷新、community daily brief
not_trigger: 宏观深度日报（走 macro-morning-brief）、热点扫描（c5）、研报（c3）、温度计（c4）、标的速查（c6）、週報（c2）
mcp: mcp__followin__metrics, mcp__followin__news, mcp__followin__signal
args: mode(晨報|開盤前瞻|刷新，默认晨報)
---
```

正文段落（每段内容按 spec §4-c1 逐项落实，不得省略）：
1. **模式路由表**：晨報=全流程 7 步/開盤前瞻=只跑步骤 1、7（300 字 2-3 点）/刷新=步骤 1、3、4 增量（4h 窗口；无当日晨报 baseline 拒跑并提示先跑晨报；金额级 time_range <1d bug 说明=N-10 镜像）。
2. **调用序列**：spec §4-c1 表 7 行逐字复制（含额度列、most_actives 弃用 gainers/losers 说明、指数白名单 ^GSPC ^IXIC ^DJI ^VIX、批量降级梯引用、经济日历 query 待验注记与降级删除条款）。每行给 query 主形态调用示例。
3. **产出模板**：六段骨架（T-2 样例整段收录为示例输出），标注 S-4 长度、S-3 第 7 段互动钩子规则、盘前引用 extendedHoursQuote 标「盤前」。
4. **防坑镜像**（逐条，标注来源编号）：异动榜三重过滤（N-9）/代币化+加密噪音白名单剔除（c1 实测 SKHYx、LAB）/news 搜索不传 asset_type+趋势可传（红线 1+N-1）/内部人 transactionDate=昨日 且只认 S-Sale、P-Purchase（N-6）/原油 BZUSD、USO（N-11）/单源铁律、价格铁律、禁凑数、双时区、时效（S-7 五铁律全文）。
5. **发前自检**：S-12 清单逐字 + 额度哨兵规则（读 meta.quota，remaining/limit<15% 加内部提醒行，不进贴文）。

- [ ] **Step 2: 结构校验**

Run: `grep -c "asset_type=\"tradfi\"\|僅做資訊分享\|今日平靜\|extendedHoursQuote\|most active stocks" skills-community/c1_daily-brief.md`
Expected: ≥5（五个关键锚点全部在场）
Run: `grep -c "biggest gainers" skills-community/c1_daily-brief.md`
Expected: 仅出现在"弃用说明"上下文（人工确认 1 处以内）

- [ ] **Step 3: Commit**

```bash
git add skills-community/c1_daily-brief.md
git commit -m "feat(community): c1 每日早报——晨/晚双时段+刷新模式"
```

---

### Task 4: c2_event-radar.md（週報）

**Files:**
- Create: `skills-community/c2_event-radar.md`

**Interfaces:**
- Consumes: S-*、红线 10、N-2/N-8；c1 已拉数据（回顾段复用原则）
- Produces: 触发词 `週報/周报/事件预告/本周看点`；README 节奏表周日槽位

- [ ] **Step 1: 写文件**

frontmatter：name `Community Weekly (c2 — 週報：上週回顧+本週看點)`；trigger `週報、周报、事件预告、本周看点、下周有什么、weekly`；not_trigger `早报、热点、研报榜、温度计、速查`；mcp `mcp__followin__metrics, mcp__followin__news`；args 无。

正文：
1. **双段结构**：上半场本週回顧（素材=上周预告贴[对话内引用或运营粘贴]+本周 c1 已有数据，零新增调用，兑现缺口才补拉 ≤1 点；逐条核对格式：`事件→当时预告→实际结果→一句白话解读`）；下半场本週看點=spec §4-c2 表 3 行逐字（财报日历 query+date 窗口、shortlist 补市值、经济日历禁"本周"+query 形态待验注记）。
2. **财报日历过滤规则**（N-2 镜像逐字）：无交易所后缀 symbol → revenueEstimated>$1B → 市值 Top 5-8。
3. **日期核实制度**（spec 逐字）：重点财报日期 news 交叉确认（0 额度）/宏观日期只认返回值+标「以官方公告為準」/周报贴即锚点表、下周先对照上周核差异、变更发更正（引用 S-8 模板）。
4. **产出模板**：回顾段+预告段贴文骨架（S-3 适配：无互动钩子），每事件一行「谁｜哪天(美东+台北)｜市场在赌什么｜影响标的」。
5. 防坑镜像 + S-12 自检 + 额度哨兵。

- [ ] **Step 2: 校验**

Run: `grep -c "本周\"\|本週看點\|revenueEstimated\|以官方公告為準\|美东+台北\|美東" skills-community/c2_event-radar.md`
Expected: ≥4；且 `grep 'query.*本周' skills-community/c2_event-radar.md` 只出现在禁令说明里

- [ ] **Step 3: Commit**

```bash
git add skills-community/c2_event-radar.md
git commit -m "feat(community): c2 週報——上周兑现回顾+本周事件预告"
```

---

### Task 5: c3_research-hot.md（研报榜+研究笔记）

**Files:**
- Create: `skills-community/c3_research-hot.md`

**Interfaces:**
- Consumes: S-*、T-1 样例、红线 12、N-3/N-8
- Produces: 触发词 `研報熱點/研报榜/研究笔记`；c5/c6 引用其成稿路径（"發佈請走 c5/c3 成稿"）

- [ ] **Step 1: 写文件**

frontmatter：name `Community Research Hot (c3 — 研報熱議榜+研究筆記)`；trigger `研報熱點、研报榜、本周研报、研究笔记、给XX写研究笔记、research hot`；not_trigger `单股财报分析（走 earnings-report）、早报、热点速报、温度计`；mcp `mcp__followin__metrics`；args `ticker(可选，指定则跳过榜单直接出笔记)`。

正文：
1. **两层产出**：层 1 周榜贴（调用逐字：`metrics(query="research reports most mentioned stocks", asset_type="tradfi", time_range="7d")`，输出=排名/提及篇数/机构家数/多空方向 direction_counts/目标价覆盖；非美股 ticker 保留但标市场）。层 2 研究笔记（对榜单 Top 3-5 或 args 指定：`metrics(query="<TICKER> research reports", verbosity="detail", time_range="7d", asset_type="tradfi")`，标准客户端备注 keywords 数组形态）。
2. **研究笔记模板**：T-1 NVDA 样例全文收录为基准示例；结构固定=一句話先懂→最新動態→機構怎麼看(多机构目标价区间+家数+分歧幅度+对现价上行——现价用 detail 返回自带快照就地算，不再花额度)→空方在擔心什麼(risks+bear scenario)→接下來看什麼(catalysts 时间线)→名詞卡→免责。
3. **防坑镜像**：红线 12（query 必含研报意图词，禁拿报告标题当 query）/N-3 去重（机构+标题+日期）/subject_reports 与 mention_reports 分层说明/`research_report_limit_capped` warning 检查/S-5 多空平衡/S-7 铁律 2。
4. S-12 自检 + 额度哨兵。

- [ ] **Step 2: 校验**

Run: `grep -c "research reports\|verbosity=\"detail\"\|机构+标题+日期\|機構怎麼看\|一句話先懂" skills-community/c3_research-hot.md`
Expected: ≥5

- [ ] **Step 3: Commit**

```bash
git add skills-community/c3_research-hot.md
git commit -m "feat(community): c3 研报热议榜+单标的研究笔记两层产出"
```

---

### Task 6: c4_social-pulse.md（温度计）

**Files:**
- Create: `skills-community/c4_social-pulse.md`

**Interfaces:**
- Consumes: S-*、N-4/N-5/N-6/N-7、trader_position 既有 caveat（日级剧变/underlying 合并）
- Produces: 触发词 `溫度計/温度计/热议标的/推特在吵什么`

- [ ] **Step 1: 写文件**

frontmatter：name `Community Social Pulse (c4 — 熱議標的溫度計)`；trigger `溫度計、温度计、热议标的、推特在吵什么、社群信号、social pulse`；not_trigger `早报、研报、热点速报、速查、单股财报`；mcp `mcp__followin__signal, mcp__followin__news, mcp__followin__metrics`；args 无。

正文：
1. **调用序列**（spec §4-c4 逐字）：步骤 1 `signal(query="consensus", asset_type="tradfi", time_range="3d")`（N-4：无 categories 一次 fanout 全 4 类计 1 点）；步骤 2 对喊单榜 Top 3-5 `signal(query="<TICKER> 详细仓位", asset_type="tradfi", time_range="7d")`（query 禁"KOL"等元词）；步骤 3 可选 news 补原文（0 点）。
2. **温度计三格模板**：推特情緒（多空比+A 级 KOL 代表观点正反各一）/真金白銀（实盘方向/人数/杠杆；过滤 tier 空+notional null；stock_perp 标注「鏈上股票永續交易員」；数据薄明说薄）/內部人動向（近 90 天客户端过滤 transactionDate；只认 S-Sale、P-Purchase）。跨源打架明写（「情緒滿格 ≠ 大錢進場」句式示例）。
3. **防坑镜像**：N-5（source_url 去重+symbol 归属）/N-6/N-7（13F 申报季禁环比——本模块直接不引用 13F 环比字段，只可引用绝对持仓）/trader_position 当天现拉+underlying 合并（既有 caveat 镜像）。
4. S-12 自检 + 额度哨兵。

- [ ] **Step 2: 校验**

Run: `grep -c "consensus\|详细仓位\|source_url\|鏈上股票永續\|S-Sale" skills-community/c4_social-pulse.md`
Expected: ≥5

- [ ] **Step 3: Commit**

```bash
git add skills-community/c4_social-pulse.md
git commit -m "feat(community): c4 热议标的温度计——喊单×实盘×内部人三格"
```

---

### Task 7: c5_hot-take.md（热点扫描+速报+财报速读）

**Files:**
- Create: `skills-community/c5_hot-take.md`

**Interfaces:**
- Consumes: S-*、T-3 菜单样例、N-1/N-8/N-10、S-7 铁律
- Produces: 触发词 `掃熱點/扫热点/速報/就XX出一篇/XX财报出来了`；c6 备忘的「🔥 建議速報」衔接点

- [ ] **Step 1: 写文件**

frontmatter：name `Community Hot Take (c5 — 熱點掃描+速報+財報速讀)`；trigger `掃熱點、扫热点、扫一下热点、速報、速报、就XX出一篇、XX财报出来了、hot take`；not_trigger `定时早报、周报、研报榜、温度计、内部速查`；mcp `mcp__followin__news, mcp__followin__signal, mcp__followin__metrics`；args `topic_or_ticker(可选，点名则跳过扫描)`。

正文：
1. **两步交互**：第一步扫描（调用逐字：news 空 query+asset_type tradfi+time_range 4h[实现时验证，不通则 24h+按 published_ts 客户端取最近]（0 点）+ signal consensus 24h（1 点））→ 输出 T-3 格式编号菜单（逐字收录样例），出稿建议三档判据逐字：🔥速报=事件驱动+标的明确+≤12h+多源 / 📌并回栏目=板块级慢发酵 / 🚫忽略=纯交易噪音、单源未证、陈货；「判断责任在 skill 不在运营」原则句。第二步成稿（news 实体查 0 点 + 受影响标的快照 1 点 + 可选深钻 1-2 点）。
2. **速报模板**：發生了什麼(两句)→誰受影響(标的+实时价+截至时间戳+传导逻辑)→市場怎麼解讀(多空各一句+来源标注)→接下來看什麼→免责（名词卡可选；互动钩子可选=S-3.7）。
3. **财报速读子型**（spec 逐字）：识别财报事件→`metrics(query="<TICKER> earnings beat miss analyst ratings", asset_type="tradfi")`（路由按 fanout warning 提示词实现时验证）→四句结构：營收/EPS vs 预期(具体数字)→指引→盘后反应→下一个观察点。
4. **防坑镜像**：age gate 机器核 published_ts>12h 剔除（S-7 铁律 5 强化版，禁肉眼）/单源 BREAKING（铁律 1）/纯交易事件无叙事层不入菜单/单事件单贴/c1 全部噪音过滤规则继承。
5. S-12 自检 + 额度哨兵。

- [ ] **Step 2: 校验**

Run: `grep -c "published_ts\|建議速報\|建議忽略\|earnings beat miss\|消息尚待確認" skills-community/c5_hot-take.md`
Expected: ≥5

- [ ] **Step 3: Commit**

```bash
git add skills-community/c5_hot-take.md
git commit -m "feat(community): c5 热点扫描菜单+速报+财报速读"
```

---

### Task 8: c6_ticker-check.md（内部选题速查）

**Files:**
- Create: `skills-community/c6_ticker-check.md`

**Interfaces:**
- Consumes: S-11 备忘尾行文案、T-4 样例、N-5/N-6
- Produces: 触发词 `速查/內部速查/这票值不值得写`

- [ ] **Step 1: 写文件**

frontmatter：name `Community Ticker Check (c6 — 運營內部選題速查)`；description 必须含「产出为内部备忘，不对外发布」；trigger `速查、內部速查、内部速查、这票值不值得写、查一下XX、ticker check`；not_trigger `研究笔记（对外，走 c3）、财报分析、温度计、速报成稿`；mcp `mcp__followin__metrics, mcp__followin__news, mcp__followin__signal`；args `ticker(必填)`。

正文：
1. **定位声明**（spec 逐字）：运营内部工具，产出不对外；两场景（群里热聊判断值不值得写/写贴文前摸底）。
2. **调用序列**（spec §4-c6 逐字三行，query 主形态）。
3. **备忘模板**：T-4 MU 样例全文收录；结构=行情位置→机构共识(家数+中位+分歧幅度，禁单均值)→近期敘事→信號面(可选)→出内容建议三档(🔥衔接 c5 成稿/📌并入 c4、c3/🚫+一句原因)→尾行 S-11 内部版逐字。
4. **防坑镜像**：非美股正股回「不在 bundle 覆蓋範圍」+提示运营别硬接/当日已查复用/共识必带家数分歧（约束所有对外模块的总则出处）/直接复制进群=跳过风格与免责机制警告。
5. 额度哨兵（内部工具同样检查）。

- [ ] **Step 2: 校验**

Run: `grep -c "此為內部備忘\|不在 bundle 覆蓋範圍\|分歧\|不对外" skills-community/c6_ticker-check.md`
Expected: ≥4

- [ ] **Step 3: Commit**

```bash
git add skills-community/c6_ticker-check.md
git commit -m "feat(community): c6 运营内部选题速查——备忘体+出内容建议"
```

---

### Task 9: README.md（bundle 运营手册）

**Files:**
- Create: `skills-community/README.md`

**Interfaces:**
- Consumes: c1-c6 frontmatter 触发词与额度（Task 3-8）
- Produces: 对外交付入口文档

- [ ] **Step 1: 写文件**

必含七节（对齐 skills-v2/README.md 的排版风格）：
1. **定位声明**：仅供运营人员使用；群成员只消费发布内容；不做答疑服务（v1）。
2. **六模块索引表**：# / 文件 / 一句话定位 / 触发示例 / 单次额度（数值取各 skill 文件标称）。
3. **一週運營節奏表**（逐字骨架）：

```
| 时段(台北) | 周一 | 周二 | 周三 | 周四 | 周五 | 周六 | 周日 |
| 早晨 | c1晨報 | c1晨報 | c1晨報 | c1晨報 | c1晨報 | c1晨報(可选) | c2週報 |
| 21:00 | c1前瞻 | c1前瞻 | c1前瞻 | c1前瞻 | c1前瞻 | — | c3研報榜 |
| 盘中随时 | c5扫热点(建议每日1-2次) · c6速查(按需) | 同左 | … | … | … | — | c4溫度計 |
```

（c3/c4 周日槽位可由运营挪到任意固定日，表下注明。）
4. **安装方式**：同 skills-v2 三法（复制到 ~/.claude/commands/ 或项目 commands/ 或 clone），MCP 接入指向根 USER_GUIDE.md。
5. **额度预算**：月耗 600-750 点明细表（晨报/前瞻/周模块/速报/速查分行）+ Basic 可跑余量收窄、财报季建议 Pro 的如实说明。
6. **置頂帖静态模板**（逐字，繁体纯文本）：社群定位一句＋內容時刻表（对应节奏表的成员视角版：每天早上有早報、晚上有開盤前瞻、周日有週報…）＋總免責聲明（S-11 全文＋「本社群所有內容均為資訊分享，不構成投資建議；投資有風險，決策請獨立判斷」）。
7. **Claude Code 定时任务示例**（可选注记）：晨報/前瞻的 schedule 配置示意各一条，注明其他客户端手动触发即可。

- [ ] **Step 2: 校验**

Run: `grep -c "c1\|c2\|c3\|c4\|c5\|c6" skills-community/README.md`
Expected: ≥12；节奏表、置顶帖、额度表三节人工确认在场

- [ ] **Step 3: Commit**

```bash
git add skills-community/README.md
git commit -m "feat(community): README——六模块索引+运营节奏表+置顶帖模板+额度预算"
```

---

### Task 10: 实测回归验收（NVDA/MU 样本）

**Files:**
- Create: `docs/superpowers/specs/2026-07-22-community-regression-log.md`（验收记录）

**Interfaces:**
- Consumes: 全部 skill 文件；本会话实测基线（spec §9）

- [ ] **Step 1: c3 回归（NVDA）**

按 c3 文件执行层 1+层 2（NVDA），实测断言：
- 榜单返回 `research_report_most_mentioned` 聚合，NVDA 在 Top10；
- NVDA detail 返回 subject_reports ≥3 且含 thesis/scenarios/target_price；出现重复 event_id 时去重规则生效（花旗案例基线）;
- 按 T-1 模板产出研究笔记贴，S-12 清单逐项通过；
- 记录 quota 消耗（预期 ≤6）。

- [ ] **Step 2: c4 回归（MU）**

按 c4 文件执行 MU 钻取，实测断言：
- kol_call 裂行经 source_url 去重后条数 < 原始条数；
- insider 含陈年记录（2020 Perdue 基线）且客户端 90 天过滤后不出现；
- 13F 环比字段未被引用；
- trader_position 无评级/null notional 行被过滤（shufen 基线）；
- 产出温度计贴，跨源打架明写。

- [ ] **Step 3: c1 迷你回归 + c5 菜单回归**

- c1：跑步骤 1/3/4/7（跳过日历两步），断言：趋势榜 0 额度、most_actives 过滤后无仙股/杠杆 ETF、指数快照 ^GSPC ^IXIC ^DJI ^VIX 有值、产出六段贴文（缺日历段如实标注）。
- c5：跑扫描两调用，断言菜单每条带三档建议之一、无 published_ts>12h 条目；不成稿（省额度）。
- 顺带验证两处"实现时验证"项并回写 skill 文件：news time_range="4h" 是否可用；经济日历 query 形态是否可用（不通则执行 spec 的降级删除条款）。

- [ ] **Step 4: 写验收记录 + 提交**

`community-regression-log.md` 记录：日期/每步断言结果(PASS、FAIL+处理)/quota 实测总消耗/两处验证项结论/产出样张(早报+研究笔记+温度计贴全文)。FAIL 项修复对应 skill 文件后复测再提交。

```bash
git add docs/superpowers/specs/2026-07-22-community-regression-log.md skills-community/
git commit -m "test(community): NVDA/MU 实测回归验收 + 待验项回写"
```

- [ ] **Step 5: 用户验收 gate**

把三份产出样张贴给用户过目（成色 = 本会话已核可的 NVDA 样例水准）。用户提修改 → 改风格 SSOT/模板 → 该样张复测。通过才进 Task 11。

---

### Task 11: 终态收尾

**Files:**
- Modify: `docs/superpowers/specs/2026-07-22-community-content-skills-design.md`（状态行改「已实现（2026-07-22）+ 回归记录链接」）

- [ ] **Step 1: spec 状态更新 + 全量最终检查**

Run: `ls skills-community/ | wc -l` Expected: `7`
Run: `grep -L "僅做資訊分享" skills-community/c[1-5]*.md` Expected: 空（c1-c5 全部含对外免责；c6 用内部版另验）

- [ ] **Step 2: Commit**

```bash
git add docs/superpowers/specs/2026-07-22-community-content-skills-design.md
git commit -m "docs(spec): 社群 bundle 标记已实现,链接回归记录"
```

---

## Self-Review 记录

1. **Spec 覆盖**：§1 定位/范围→Task 3-9 全落；§2 架构与调用铁律→Global Constraints+各任务；§3 风格 12 条+模板附录→Task 1；§4 六模块→Task 3-8 一一对应；§5 错误处理+额度哨兵→各 skill 第 5 节；§6 caveats→Task 2；§7 验收→Task 10（可复现/风格/数据诚实/额度/触发词五条全体现）；§8 v2 不实现✓；README 置顶帖/节奏表/定时→Task 9。无缺口。
2. **占位扫描**：Task 1 的 T-1~T-3 收录指令已显式标注"落盘后不得残留占位"并有 grep 验证步；其余任务内容均为具体条目。
3. **一致性**：编号体系 S-1~S-12/T-1~T-4/N-1~N-11 三套命名在 Task 1/2 定义、Task 3-8 引用一致；触发词六套互斥（not_trigger 交叉覆盖）；c6 尾行文案与 S-11 内部版逐字一致。
