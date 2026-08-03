# 进阶扩展 — Advanced Extensions

> 这些层在原版实战系统里都在跑，但**不属于核心主链**——新用户前两周用不到，且各自带维护成本。
> 用核心版顺手了、明确感到某个缺口，再按需加回。每层给：是什么 / 怎么加 / 已知陷阱（都是实跑踩出来的）。
> §2 / §7 的参数与陷阱**均为对 followin MCP 的实测结果**，不是照抄文档——包括一条实测否决（§7）。

---

## 1. 实盘仓位源（原 Step 5.6）

**是什么**：一个可信的实盘仓位数据流（某交易员公开仓位 / 自建监控），把每标的的方向×杠杆 / 仓位价值 / 开仓价落到对应 Ticker 的「实盘持仓追踪」段。实盘比推文口头观点硬一档，适合做信号分层的高层级。

**怎么加**：在 Step 5.5 之后并入；Ticker 模板加「实盘持仓追踪」段；如有多层信号源（付费实盘 > 公开实盘 > 推文），建立分层权重——高层级可对冲低层级反方。

**陷阱**：
- **价值列 ≠ 成本**：快照"价值" = shares × 当前市价。判断加减仓**只看变动事件流**，不看快照价值增减（价格跌时价值也跌，会误判成减仓）。
- **同源计 1**：实盘交易员同时在你推特 roster 里 → 推文+实盘是同一人两个 channel，信号源只算 1 个。
- **高频 whip-saw**：某实盘 4 天进出同标的 4 次——单次动作无跟随价值，只看净敞口与板块轮向。
- 实盘 ≠ 投资建议，只记录事实。

## 2. 卖方研报 ingest（原 Step 5.6.5 · 已按实测重写）

**是什么**：两层——① consensus PT 聚合数字；② **结构化投行研报**（Bernstein / Goldman / JPM / Morgan Stanley / Nomura / UBS 等），带 thesis、催化剂、caveat、与 consensus 的差异、以及**逐个标的的目标价改动 old→new + change_pct**。写进 Ticker「目标价追踪」+ `Research/Read/`。

**怎么加**（followin 参考实现，⚠️ 下列参数均实测通过）：

```
# ① consensus 聚合
metrics(query="<T> analyst price target", asset_type="tradfi")
    → targetConsensus / targetHigh / targetLow / targetMedian

# ② 结构化研报（必须带日期窗口，见陷阱 1）
metrics(query="<T> broker research reports", asset_type="tradfi",
        date_from="YYYY-MM-DD", date_to="YYYY-MM-DD", limit=10)
```

研报返回的可用字段：`institution / analyst / report_date / report_title / report_type`（company update｜strategy｜industry model update｜tracker）、`thesis / novelty / latest_catalyst / key_caveat / consensus_diff`、`rating_current / rating_action`、`revision_summary.by_name[]`（**含 old_target_price → new_target_price + change_pct + ticker**）、`mention_context.mention_direction`（beneficiary｜negative｜neutral｜competitor）。

**节奏（实测结论，别每日拉）**：实测 MU 在 08-01~08-03 三天窗口返回 **0 篇**（`warnings:["no_research_reports"]`）。研报是**低频事件流**，日频拉只会天天空转。
→ 🟠 **事件触发**（财报后 / 评级潮 / 板块级消息）+ 🔵 **周维度盘点**。

**⚠️ 陷阱（全部实测到）**：
1. **默认无时间窗口**：不传 `date_from/date_to` 时返回 `time_scope:"all_available_reports"`——会把一周前的研报当成今日新增。**日报/周报引用必须传窗口**，传了会变成 `time_scope:"report_date_window"`。
2. **`mention` ≠ `subject`**：实测 MU 返回 `mention_report_returned_count:10` 但 `subject_report_returned_count:0`——10 篇全是**别家公司的研报里提到 MU**（KIOXIA/SK海力士/UMC/策略周报），没有一篇以 MU 为主体。**写成"MU 有 10 篇研报"是错的**；引用时必须写明"出自 <subject> 的研报，MU 为 mention"。
3. **`content_truncated: true`**：thesis/novelty/consensus_diff 都是**截断摘要**，不是全文。可以引用要点，**不能当 verbatim 原文**。
4. **`revision_summary` 里的 PT 改动可能不是你查的那只**：`by_name[]` 列的是该研报覆盖的**所有**标的（如 UMC 47→88、Vanguard 94→146）。挑出你要的 ticker，别把别人的目标价安到自己标的上。
5. **承销商水分**：IPO 新股静默期满后多家投行集中 Buy——先查发布方是否承销商 + 时点是否静默期刚过。
6. consensus 只给当前聚合数，不给每家 PT 日期——中位数真实性取决于多少家最近 reaffirmed。新 IPO quiet period 内标"暂无 coverage"。

## 3. 独立研究 ingest（原 Step 5.6.6）

**是什么**：第三方独立分析师的长文 thesis（如 Substack 深度）——区别于卖方（偏多、利益相关），独立研究给"完整推理 + 中立裁决"，是 KOL 争议的第三方裁决源 + 反方深度的主要来源。落 `Research/Read/`，反链回 Tickers/Sectors。

**怎么加**（followin 参考实现）：`news(sources=["research"], time_range="2d", verbosity="detail")` 每日宽扫 1 次，挑与持仓/活跃争议相关的取全文。

**陷阱**：
- 返回混两个子源：**独立深度**（`_source:"feeds"`，唯一采用）vs **散户财经媒体**（`_source:"fmp_news"`，标题级噪音，全丢）——需 post-hoc 过滤。
- 窗口别用 `1d`（常扫出 0 条深度漏判），默认 `2d`。
- per-ticker query 命中率低；定向找某标的用其**独特主题短语**，别用纯代码；泛主题 query 可能被同名 ticker 劫持。
- 独立研究本身也无胜率回环——作"加权参考"不作"权威判决"。

## 4. digest 深读外包（原 Step 3.7，省主上下文最大单项）

> ⚠️ 核心版 Step 3 已保留触发规则（digest >20K 字符就派），本节是**完整契约**。
> 实测数据：每条推文均值 ~1.5K 字符 → 8 账号/24h ≈ 9 万字符、12 账号 ≈ 13 万字符（≈5.4 万 token）。**推荐 roster 规模下这条几乎必然触发。**

**是什么**：宽窗口 digest 动辄 25K+ 字符，主 agent 全读烧掉一大块上下文。深读是可外包的"提炼"，裁决不是。

**怎么加**：full 批（digest >20K）同步派 1 个 reader subagent；给它 digest 路径 + 窗口 + A+ 账号名单 + 持仓清单 + 对立账号对。**输出契约四件全要**：① 每账号深度草稿（高优账号逐条展开，关键句 verbatim）② 信号清单（落到哪个文件）③ **反方信号单列** ④ 持仓相关置顶。

**陷阱**：
- 主 agent 责任不可外包：裁决/落盘自己做；落盘前**抽查 3 个关键数字回 digest verbatim 核对**（防二手转录失真）。
- reader 产出 ≠ critic 校验——两者**双盲**，critic 照常独立跑。
- 发现 reader 丢 nuance（反方没带回/数字转录错）→ 当批改回主读。

## 5. RT/QT 候选账号挖掘（原 Step 3.5）

**是什么**：从 roster 账号的 RT/QT 网络自动发掘候选账号，累积到 `Watchlist/Candidate-Roster.md`（被谁引用/日期/主题）。roster 的自我更新管道。

**怎么加**：Step 3 过滤时顺手记 `retweetedTweet/quotedTweet` 的外部作者（排除 roster 自身互引）。**升级判定放周报**：被 ≥2 roster KOL 引用 ≥3 次/7 天 → 提议加入；连续 2 周 0 引用 → archive。排除：段子私人 / 与股票无关 / 默认头像 0 粉 / 机构官方账号。

**陷阱**：日维度只累积，**不做升级判定**（升级是周维度，日频判定必然拍脑袋）。

## 6. 归档与覆盖审计（原 Step 10.9.0 + 三套 Archive）

**是什么**：文件多了以后的长尾管理——① coverage-audit：机械抽 dump 里 cashtag 频次，输出"该建没建"（BUILD 候选）和"久未提没归档"（ARCHIVE 候选）；② Tickers/Sectors/Daily 三套 Archive 目录让 vault 保持可扫。

**怎么加**：跑到 30+ 个 ticker 文件再考虑。归档规则：非持仓 ticker 7 天 0 提及 → 移 `Tickers/Archive/`（KOL 再提 → 移回）；Sector 14 天 0 硬信号且无持仓连带 → 归档；被周报汇总的旧日报 → `Daily/Archive/`。**执行都在周末**，平时只提示候选。

**陷阱**：
- 归档判定用"最后信号日期台账"，**别 grep 文件内日期**（会被未来财报日期污染）。
- 持仓 / 挂单标的永不归档。
- Obsidian `[[日期]]` 链接按 basename 解析跨文件夹有效，但带 `Daily/` 路径前缀的链接移动后会断——移动前先改。

## 7. ❌ 实测否决：trader_position（tradfi）

`signal(query="<T> trader position", asset_type="tradfi")` 在美股上**数据基本是空的**——实测 MU 只返回 1 个交易员，`notional_value_usd: null`、`n_trades: 0`、`profile_confidence: 1/5`、`rating_reason: "no eligible closed-PnL sample yet; unrated"`。

**结论：不要接**。用 1 个无胜率样本的无名交易员的仓位去影响决策，比没有数据更糟。（该接口在 crypto 上可能有数据，但不在本框架辖区。）
