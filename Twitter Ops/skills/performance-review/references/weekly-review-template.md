# 周/月度复盘报告模板

复盘报告按这个骨架组织；写完**逐项过一遍文末的自检清单**，不过就返工。

---

## Frontmatter

```yaml
---
date: YYYY-MM-DD
review_type: 周复盘 / 月复盘 / 7 日复盘
account: "@你的账号"
followers: N
period_start: YYYY-MM-DD          # 本期起
period_end: YYYY-MM-DD            # 本期止
prev_period_start: YYYY-MM-DD     # ⭐ 上期起（硬规则）
prev_period_end: YYYY-MM-DD       # ⭐ 上期止（硬规则）
total_tweets: N
tweet_filter: 非 reply 且非转推（RT @ / RT@ 开头一律剔除）
retweets_dropped: 0        # 剔掉几条转推，必须实数；写 0 = 声明确实一条都没有
data_pulled_at: "YYYY-MM-DD HH:MM"

# 北极星
weekly_avg_views: N
weekly_median_views: N
weekly_top_views: N
weekly_breakout_count: N          # >10K 条数
median_mean_ratio: 0.NN           # 健康度，<0.70 触发腰部诊断

# ER（口径必须写明）
er_formula: "(likes+rt+replies)/views"
weekly_er_actual: 0.NNNN          # 原始
er_ex_spam_target: 0.NNNN         # 剔靶标（主判据）
er_conservative: 0.NNNN           # 保守下限
reply_like_ratio: N.NN            # >1.0 触发 spam 预警
spam_target_posts: N              # 单条 reply/like >5 的条数

# 互动
reply_direction_out_in: "N:N"     # 对外:对内
self_reply_rate: 0.NN             # 0~1 纯小数，禁写文字
weekly_net_followers: N           # = 快照文件最后两条之差

# WoW（三值并列，硬规则）
self_WoW: "上周报告值 X（截断·N条）→ 本次重扫同窗 Y（完整·M条）→ 本周 Z"
competitor_median_WoW: { 账号A: {prev: N, this: N, delta_pct: ±N, posts_delta_pct: ±N}, ... }
industry_verdict: 普跌 / 普涨 / 分化
position: 逆势上涨 / 跟随大盘 / 单方面跌
wow_data_gaps: "缺失或截断说明"

skill_landing_count: N            # 本期产出的改动条数
skill_landing_verify_date: YYYY-MM-DD
---
```

## 章节顺序

```markdown
# {账号} {周期} 数据复盘（start–end）

## 🔥 整体定调
vs 自己的历史 baseline：… ｜ vs 同梯队：… → 一句话结论

## ⚡ Step 0 行业基线对照
### 本周 vs 上周 同账户 WoW
| 账号 | 上周中位 | 上周max | 本周中位 | 本周max | 发文量Δ% | 中位Δ% | maxΔ% |
（自家一行加粗；上周值用本次重扫的完整值，并注明与上周报告值的差异来源）
### 三类判定 → 行业 = {verdict}，自家 = {position}
### 必拆解样本：逆势上涨账号的 Top 推 + 必学要素

## 🎯 Step 1 北极星 + 健康度 + ER
### 1.1 目标对照表（4 周 / 12 周 + Δ%）
### 1.2 健康度（+ 腰部诊断章节，仅在 <0.70 时出）
### 1.3 ER 三口径 + reply/like + spam 靶标清单
### 1.4 按天分布 / 全部条目按 views 降序

## 📊 Step 2 数据分析
### 2.1 内容类型效果对比 + 类型状态跨周表
### 2.2 单主题集中度 + 缺位板块
### 2.3 对标差距
### 2.4 算法 5-KPI
### 2.5 互动 5 项（ER / KOL 互动数 / 净增粉 / 作者回复率 / 数据完整性）
### 2.6 Top 3 爆款归因 + Bottom 3 失败分析

## 🛠 Step 3 落地映射（≥3 条）
| # | Finding 来源 | 改哪个 Skill 的哪一节 | 具体改成什么 | 验证日期 | 状态 |
### 用户拍板：A 全收 / B 部分 / C 跳过 / D 修改

## 📝 Step 4 学习日志 append（含上周改动验证 ✅/⚠️/❌）

## 📦 素材入库（S/A 级条目 → vault.md，新模式 → patterns.md）

## 🚀 下期前瞻
```

---

## 落盘前自检清单

```
① 上期起止日期已写
② WoW 三值并列（上周报告值 / 本次重扫 / 本周）
③ Step 0 有 Δ% 列 + 三类判定（禁止只列绝对值）
④ 北极星表在首屏
⑤ 算法 5-KPI 齐，含 BM/L
⑥ 类型状态跨周表（上周 → 本周）
⑦ 落地清单 ≥3 条且每条有验证日期
⑧ 学习日志已 append
⑨ 上周改动的验证状态已标（✅/⚠️/❌）
⑩ ER 写明口径且对照了 floor
⑪ reply/like 已算；>1.0 时三口径齐 + 报告顶部披露"ER 不可采信"
⑫ 周净增粉 = `$STATE_DIR/followers-weekly.json` 最后两条之差，**且两条间隔在 6–9 天内**
   （超出区间必须改写成「N 天净增 X」并标注实际天数——只校验算术不校验区间，
   一周跑两次会把 3 天净增当周净增，数字看起来完全正常）
⑬ 健康度 <0.70 时腰部诊断四要素齐（去头健康度 / 二分定性 / 尾部共性 / 具体动作）
⑭ self_reply_rate 是 0~1 纯小数（写"未实测"之类文字会让统计抠错数字）
⑮ Bottom 3 写满 3 条并标号
⑯ 死号/数据缺失已显式标注，无编造数字
⑰ 已剔转推：`retweets_dropped` 是实数，自家与对标**两侧都剔了**
   （`include_replies=false` 不过滤转推；漏这步会把别人的推当成你的爆款入库）
⑱ 排序口径单位正确：没有 impressions 的输入算出来的是**绝对互动数**，不许标成 "%"
```

**不过 = 返工。** 确实测不到、只能放行的项，必须在报告顶部显式披露，不许当绿灯划过去。

---

## 为什么强制 WoW 而不是只看绝对值

| 只列绝对值 | 加上 WoW Δ% |
|---|---|
| 看到"自家中位 1,651 vs 同梯队 5K–10K" | 看到"自家 **+44%** vs 同梯队 −55%/−56%/+53%" |
| 判定：自家单方面跌 | 判定：**行业分化下行 + 自家逆势上涨** |
| 动作：紧急排查选题 | 动作：**保持路径**，只盯绝对水位差距 |

绝对值反映**水位**，WoW 反映**质量趋势**，两个都要。
