---
name: competitor-watch
description: "监控外部账号 — 对标账号（学 voice / hook / Pattern）与行业基线（看自己在第几格）分开管理，周频扫描产出可借鉴的爆款拆解和差异化机会。Use when the user mentions 竞对监控, 竞品分析, 对标账号, 同行在发什么, competitor monitoring, competitive analysis, account comparison, benchmark against peers, what are others tweeting, or any request to analyze or track other accounts."
---

# 监控与对标 Competitor Watch

⚠️ **名字叫 competitor，但实际不是"和谁竞争"**。外部账号只有两种角色：

| 角色 | 心智模型 | 时间投入 | 学什么 | 互动政策 |
|---|---|---|---|---|
| 🎯 **BENCHMARK 对标** | **老师** | 80% | 调性 / hook / Pattern / 选题结构 | 个人号可互动（走 engagement 的 Outbound）|
| 📏 **BASELINE 基线** | **坐标** | 20% | **只看基线数据**（中位 / 爆款 / WoW），不学 voice | **不互动** |

不要用"敌我"框架思考外部账号——**要么是老师，要么是坐标**。

**基线账号为什么不互动**：它们多是机构/团队号，评论区被搬运号刷屏、作者本人不接 reply，互动收益 ≈ 0，还等于给对方送流量。互动池只放有人格 face 的个人 KOL。

> **数据源**：Followin MCP 的 `twitter` 工具，走 `action` 路由（另外 4 个工具 `metrics`/`news`/`signal`/`subscription` 本 Skill 基本用不到）。

---


## 0. 直接触发时的自检（本 Skill 可不经 `twitter-ops` 调度器）

⚠️ 用户可能直接说「竞对在发什么」而不走调度器，那边的初始化闸门**不会执行**。
开工前按 `config.md` §开工四检 逐条走一遍：

**① 账号锚定** = `ACCOUNT`（唯一权威，仍是占位符就停下来让用户填）
**② 目录** = `STATE_DIR`，🔴 不得指向 `/tmp`（硬检查）
**③ 时钟** 一律 shell 现取（`date +%F` / `date +%G-W%V`），全程复用同一组值，**不许凭模型的日期认知推算**
**④ 依赖文件「存在但仍是占位符 / 带 `INIT-STATUS: template-default`」= 视同未配置** → 记 `n/a` + 显式标注

🔴 **四条的完整判据与后果只维护在 `config.md` 一处，本文不复述**——
样板复制到七个文件会给人"全仓已覆盖"的错觉，而实际覆盖的只是最容易复制的那部分。

---

## 1. 名单

名单存 `references/competitor-list.md`（⚠️ 需初始化）。建议规模：**BENCHMARK 5–6 个 + BASELINE 4–5 个**，超过 12 个既扫不动也读不完。

选 BENCHMARK 的标准：粉丝量落在你的 **1.3x–10x 甜蜜区**（量级悬殊的顶流是"仰望型"陷阱，学不动也够不着）、定位与你有交集、**并且你真的从他身上抄到过东西**。每月用"最近 30 天有没有实际借鉴痕迹"审一次名单——**零借鉴的账号直接移出，别占位置**。

## 2. 周扫

每周固定一天早上跑（可用定时任务注册）：

```
1. 拉每个账号 user_tweets（覆盖 7 天，必须翻 cursor）
2. 取 7 天内**非 reply 且非转推**的原创推 → 算 中位 / max / >10K 条数 / Top 3
> 🔴 **必须剔转推**：`include_replies=false` **只过滤回复，不过滤转推**（实测 `@elonmusk` 首页 20 条里 14 条是 `RT @`）。
> 口径是「非 reply **且非转推**的原创推」。判转推**首选 `retweeted_tweet` 非空**（结构判据，实测更稳）；无该字段回退 `text` 以 `RT @` / `RT@` 开头。
> 不剔的后果是**静默产出错误数据**：中位数/ER/Top3 全建在别人的推文上（实测 max 11.1M 是一条 `RT @grok`），
> 而报告数字齐全、格式正确，看不出问题。
> ⚠️ 连带影响 §3 爆款拆解：不剔转推会把**对标账号转的别人的推**拆成「老师本周的 voice/Pattern」去学。
3. 落盘 `$STATE_DIR/competitor-watch-$(date +%G-W%V).json`，标 vs 上周 Δ%
```

> 🔴 **文件名钉死成 `competitor-watch-$(date +%G-W%V).json`**（如 `competitor-watch-2026-W31.json`）。
> 周编号必须用 `date +%G-W%V` 现取，**不许凭记忆写周数**。下游（performance-review）靠这个名字找文件，
> 名字浮动 = 下游永远找不到 = 永远走"当场补扫"慢路径。

| 用途 | 写法 |
|---|---|
| 账号信息（粉丝/简介/存活） | `twitter(action="user_info", user_name="X")` |
| 近期推文 | `twitter(action="user_tweets", user_name="X", include_replies=false)` + `cursor` 翻页 |
| 批量粉丝对比 | `twitter(action="batch_user_info", user_ids="id1,id2")`（**传数字 ID，不是用户名**）|
| 对方有没有提到你 | `twitter(action="search", query="from:对方 你的关键词", query_type="Latest")` |

⚠️ 数据量大，**走 Agent 子进程 + jq 汇总**。`user_tweets` 首页只有约 20 条，高频号一周要翻好几页；翻不到窗口起点时改用 `twitter(action="search", query="from:账号", time_range=...)`。

**账号存活性检查（每次必做）**：**先判名单是否仍是占位符**（`@[账号1]` 这类）→ 是则记「未配置，去填 competitor-list.md」**不报停更**；名单已填的前提下，`user_info` 返回 not found，**或**最新推距今 >30 天 → 报警「疑似停更/改名，需人工核实 handle」，**禁止标 N/A 了事**。停更账号采到的是死数据，会连续多周被误读成"我们的采集出问题了"。核实后更新名单。

### 输出 schema

```json
{
  "week": "YYYY-Www",
  "scanned_at": "ISO8601",
  "accounts": {
    "账号": {
      "role": "BENCHMARK | BASELINE",
      "followers": 0,
      "this_week": {"count": 0, "median": 0, "max": 0, "over_10k": 0, "retweets_dropped": 0},
      "prev_week": {"count": 0, "median": 0, "max": 0, "over_10k": 0, "retweets_dropped": 0,
                    "source": "rescanned | inherited",
                    "source_scanned_at": "ISO8601"},
      "wow_median_pct": 0, "wow_count_pct": 0,
      "top3": [{"text": "...", "views": 0, "pattern": "模式名"}]
    }
  },
  "industry_verdict": "普跌 | 普涨 | 分化",
  "best_learnable": [{"account": "X", "tweet": "...", "views": 0, "lesson": "一句可执行的启发"}]
}
```

### 兜底硬规则

定时任务会漏跑——没注册成功、机器关机、任务静默失败都很常见。**下游读这份数据前必须先检查文件在不在，不在就当场 inline 补扫**。别假设"文档里写了自动跑"就等于真的跑了；定时是快路径，兜底补扫才是不漏的保证。

> 🔴 **只检"在不在"不够，必须检"多老"。** 读到文件后先看 `scanned_at`：
> **距今 >8 天 → 当作不存在，重扫。** 隔了两三周才跑的时候，文件是"在"的，
> 但里面的 `this_week` 其实是三周前的一周——它会被当成本周基线，
> 而 `prev_week` 只能从更早的文件继承，于是 `wow_median_pct` 和 `industry_verdict`
> （普跌/普涨/分化，驱动全局路径决策的那个判定）**静默算错**。
>
> **一周内跑第二次**：同名文件会被覆盖，此时 `prev_week` 若从被覆盖前的值继承，
> 继承到的是"3 天前的本周"，Δ% 全废。所以 `prev_week` 必须标 `source`：
> `rescanned` = 本次真的重扫了上周窗口（推荐）；`inherited` = 从旧文件继承，
> 必须同时写 `source_scanned_at`，且报告里要显式披露实际间隔天数。

### 落盘前自查（任一 FAIL 就返工，不许"数字齐了就算跑完"）

```
① 文件名 = competitor-watch-$WEEK.json，$WEEK 由 date +%G-W%V 现取
② scanned_at 已写，且是本次真实时间
③ 每个账号 this_week.retweets_dropped 是实数（写 0 = 声明确实一条转推都没有）
④ prev_week.source 已标 rescanned / inherited；标 inherited 的必须同时有 source_scanned_at
⑤ 读到旧文件时已核 scanned_at 距今 ≤8 天，超期已重扫
⑥ 占位符账号（@[账号1] 这类）记「未配置」而非「停更」
⑦ 死号/取不到数据的账号已显式标注，无编造数字
⑧ 对标表同时有「发文量 Δ%」和「中位 Δ%」两列
```

**这份清单是本 Skill 唯一的机检。** 上面那些 🔴 规则如果没有它，就只能靠每次自觉——
而全仓已经出过一次「规则写了、下游没接、报告照样通过」的事故。

## 3. 分析

**发布模式**：频率、时间分布、内容类型比例、话题覆盖范围。
**互动表现**：中位/平均互动、高互动推的共同特征、互动率、粉丝增长趋势。
**内容质量**：信息源是一手还是转述、观点独特性、数据使用密度、风格辨识度。

⚠️ **看中位不看平均**，并且**同时看发文量 Δ% 和中位 Δ%**——加量 +50% 而中位 -18% 是摊薄，不是内容变差。
⚠️ **逆势上涨的账号要交叉验互动率**：views 涨但 Top3 只有个位数点赞 = 分发侧抬升、不是内容共鸣，**标为不可复用**，别照抄。

### 爆款拆解（每周至少 2 条）

```
### 🔥 @账号 — [推文摘要]
数据：❤️ X | 🔄 X | 💬 X | 👁 X
为什么爆：① 话题（为什么这个话题火）② 角度（独特切入点）③ 时机 ④ 格式（排版/线程/图文）
可借鉴：角度 A（你会怎么写）／角度 B（反向或补充）
边界：借鉴结构和角度，内容必须原创
```

### 周报骨架

```
## 竞对周报 — 日期范围
### 数据对照表（含发文量 Δ% + 中位 Δ%，自家一行加粗）
### 话题覆盖对比（你 / 各账号 → 找出全员空白区）
### 你的差异化优势（2 条）
### 改进机会（他们做得好而你没做的）
### 本周值得借鉴的爆款（2–3 条 + 借鉴思路）
```

**周报的重点是「老师本周教了什么 voice / Pattern」**，基线数据只占一张表，不是分析主线。

## 4. 下游

- **选题环节**：读 `best_learnable` 借鉴方向；同时用名单做**撞车查重**——同主题对标账号刚发过就砍掉或换角度。查 BENCHMARK 是"避免和老师撞"，查 BASELINE 是"避免和行业地板撞"。
- **performance-review**：读本文件的 `top3` / `best_learnable` / `industry_verdict` 作**定性**参照。
  🔴 **数字不给它用**——`this_week` 和 `prev_week` 都不参与它的 WoW 计算。
  见 `../performance-review/SKILL.md` Step 0：**WoW 的两个窗口必须来自同一次采集**。
  拿本文件的 `this_week`（最多 7 天前）配它现采的 `prev_week`，就是两次采集拼出来的 Δ%，
  会**系统性高估本周表现**，甚至翻转结论方向。省那一轮拉取不值得。
- **engagement**：**只有 BENCHMARK 里的个人号**能进互动名单，BASELINE **永远不进**。

← 反向输入：互动中发现的新账号 → 评估后加入名单；热点扫描 → 检查对标账号是否已覆盖该话题。

## 关键原则

- **学习不抄袭**：借鉴策略和角度，内容必须原创。
- **两种角色别混**：从老师身上学 voice，从坐标身上只取数字。
- **零借鉴 = 该移出名单**：名单是工具不是收藏夹。
- **数据说话**：用互动数据判断什么有效，不靠主观感觉。
- **定期而非实时**：每周一次深度分析就够，天天盯着只会焦虑。

## 参考文件

- `references/competitor-list.md` — 监控名单（⚠️ 需初始化：填你自己的对标与基线账号）
