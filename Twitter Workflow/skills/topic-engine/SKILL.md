---
name: topic-engine
description: "Transform trending topics into tweet angles — the bridge between trend-scout's raw intelligence and tweet-composer's content creation. Generates scored, data-backed angles with hooks for every topic. Use this skill whenever the user mentions topic selection, angle generation, what to tweet about, 选题, 角度, 切入点, content ideas, tweet ideas, 今天发什么, 写什么内容, 开角度, 找切入点."
---

# 话题引擎 Topic Engine

trend-scout（采集）→ **topic-engine（选题 + 开角度）** → tweet-composer（撰写）。
不采集数据，但可回调 MCP 补数据。

## 0. 使用前必填（占位配置）

| 变量 | 含义 |
|---|---|
| `BENCHMARK_KOLS` | 层 B 对标白名单·标杆组（3-5 个同语种同赛道优质账号） |
| `BASELINE_KOLS` | 层 B 对标白名单·基线组（2 个更挑、更策展的媒体/策展号） |
| `CATEGORY_CAP` | **单批 Top 5 内**单赛道占比上限（如「Crypto ≤40%」）——⚠️ 不是"周"上限，全仓按单批理解 |
| `MAIN_ENGINE_TYPES` | **战略角色**代号（轴 B），值填在 `config.md`，配额定义见 `twitter-ops/references/operations-plan.md` §三·轴 B。本文用 `#主引擎` / `#跟报` / `#叙事` 指代。⚠️ 与该文件轴 A 的**内容形态**（锐评/数据分析等）是两个正交维度，一条推文两个都要标，别混用 |
| `WORK_DIR` | 落盘目录，**默认 = `STATE_DIR`**（同一个目录，别设成两个）。⚠️ **建议留空 = 跟随 `STATE_DIR`**（两者默认值相同，分别填极易只改一个，导致读候选与写产物分裂到两处）。**跨周文件（quota-$WEEK）必须落持久目录，别放 `/tmp`**（重启即清） |
| `BRIEF_DIR` | trend-scout 简报目录（选题表追加到这里） |

> 🔑 **未配置通则（下文所有引用 `config.md` 变量的约束都按这条走，不再逐处重复）**：
> 变量未配置 → 该约束记 `n/a`、跳过、**在 Top 5 markdown 与简报里显式标注**，不阻塞产出。
> 既不静默放行（降级要让人看见），也不每轮吐一个用户消不掉的红色告警
> （**告警一旦消不掉就会训练出对告警的失敏**）。⚠️ **但"已配置却执行失败"是硬 FAIL**，
> 两者别混。

> **别把高频全量搬运号放进 `BASELINE_KOLS`**：它们发的是新闻流不是策展，撞它们几乎对每条题都判 hit，零差异化信号。基线组要选"更挑、更策展"的。

---


### 🕐 时钟（🔴 每轮开工第一件事，先于一切采集）

本文所有 `$DATE` / `$WEEK` / `now` **必须来自 shell 现取的这一组值**，
取一次、全程复用：

```bash
DATE=$(date +%F)           # 2026-07-30
WEEK=$(date +%G-W%V)       # 2026-W31 —— ISO 周编号，跨年不漂
NOW_MS=$(( $(date +%s) * 1000 ))
```

🔴 **禁止凭模型自己的日期认知推算日期或周数。** 模型的日期偏差常达数月，
而这几个值被当**文件名**用——猜错就写进错误日期的文件，于是「今日简报是否已存在」查重扑空、
下游读不到今日产物、回填链断，**而全程不报错、产物格式齐全**。
凡是要写「今晚 / 明天 / 本周」这类相对时间，也一律以 `$DATE` 为基准换算，不凭印象。

> 周编号只认 `%G-W%V` 一种格式（`2026-W31`）。全文任何周文件名都用它拼，
> **不许出现 `2026-31` / `2026-W31` 混用**——同一份文件的读写路径不一致，
> 结果是每天都判「缓存缺失」、每天重建、每天多喊一次告警。

## 1. 过程纪律（违规即重跑）

核心价值 = **3 角度备选 + Pattern 匹配 + 多样性校验**。
**禁止**：直接出推文（那是 tweet-composer 的活）/ 每选题只给 1 角度 / 角度缺 5 要素 / 无 Pattern 编号 / 无 3 角度对比表 / 无打分明细 / 无 Top 5 一览表 / 无多样性校验 / 跳过第零步 / 只落盘不追加简报 / **凑不满 5 条时静默交付**（⚠️ 「必须满 5 条」不是硬规则——候选不够时按 §8 降级到 Top 3 并显式警告是**合规**的；违规的是**不声明就少给**）。
> 🔑 **readlog 必须落 schema**：每份 reference 一行 `{file, status: filled|partial|placeholder|missing, escape_fired, skipped_items[]}`。这是占位符规则唯一的机检凭据——只写「已读」等于没有审计轨迹。

用户说"快速选一条" → 不接：本 skill 产出是"选题 + 3 角度 + 打分"，要快条直接调 tweet-composer。

**必跑 6 步**：⓪ 账号上下文 → ① 候选池 + 排序 → ② Pattern 匹配 → ③ 角度 5 要素 → ④ 双层打分 + 排序 → ⑤ 落盘 4 文件 + Top 5 markdown → ⑥ 追加简报。

**执行顺序硬规则**（砍 / 豁免类操作的先后）：
```
1. 纯交易排除 + 纯地缘跟报排除（最先）
2. 时效硬过滤（>48h 淘汰；24-48h 先跑层 B 单项检查，🔴 即砍省计算）
3. 第零步账号上下文 → Pattern 匹配 → 角度生成
4. 双层打分（含扩散斜率）→ 加分项
5. 层 B 差异化 4 标签
6. 抢先豁免判定（只作用于已过前两关的候选；纯交易 / 🔴 永不豁免）
7. 配比三态校验 → Top 5 输出 → 简报追加
```

## 2. 输入

- **强制**：读 `$STATE_DIR/trend-scout-candidates/$DATE-latest.txt`（`$DATE` 来自 §0 时钟；该文件内容为当次 candidates json 的绝对路径）→ candidates.json（首扫 ≥12 / 刷新 ≥7；**但 `concentrated_day=true` 时按独立事件数算、不要求 ≥12**，见下）。`STATE_DIR` 取自 `config.md`，**与 trend-scout 写入的是同一个目录**。**禁止跳过 json 直接读简报挑话题**。

  > 🔴 **读到了不等于能用——必须查"多老"，不只查"在不在"。**
  > 原先所有时效闸都在 trend-scout 的**写入侧**（基准是扫描时刻），读取侧只判「文件缺失」，
  > 于是**文件存在即通过，无论多老**；而它叫 `-latest.txt`，名字本身就在诱导拿到上周的池子。
  >
  > **硬闸**：① 文件名日期必须 == `$DATE`，不等 = 没有今日候选池 → 先跑 trend-scout，**不许退读昨天**；
  > ② 取**顶层** `scan_ts_ms`（trend-scout §5.3 必填），`NOW_MS − scan_ts_ms > 6h` 拒绝；
  > 字段缺失按「格式不合规」重跑，**不许当作"没超时"放行**。
  >
  > **逃生口（披露后放行，非静默放行）**：MCP 挂 / 限速 / 用户就要早上那批料 → 输出顶部写
  > 「⚠️ 本轮建在 Nh 前的候选池上（采集于 HH:MM），时效分未按当前时间重算」+ 逐条标出受影响的 `base_timeliness`。
  >
  > （不查的后果：昨天 20h 的料今天 44h，落进「24–48h 保留」通道却带着昨天算的分；
  > 下游重拉价格只换数字不换判断，角度已经建在旧价上。）
- 简报 Markdown 仅作上下文（分歧矩阵 / 宏观 / 社区风向）；用户突发点名可越过 json。
- json 缺失 / 数量不足 → 不允许自己挑话题，要求重跑 trend-scout。
  🔴 **例外：`concentrated_day=true`（trend-scout §5.0 标的高集中度日）不算"数量不足"，不要求重跑**——
  那天原始候选够、只是同实体合并后独立事件少（Fed/财报季/崩盘）。重跑不会变多，只会逼出碎片。
  此时按实际独立事件数正常选题，Top 5 markdown 顶部继承那句「⚠️ 高集中度日」标注。
  （判别：读候选池顶层 `concentrated_day` 字段；缺该字段且候选 <floor = 真数量不足，照常要求重跑。）
- 处理范围：按 raw_score 降序取前 `max(8, 60%)` 条。
- 价格只用简报「实时数据区」数字；叙事区价格是历史叙述。

**纯交易排除（兜底，上游已预排除）**：单一交易事件（爆仓 / 抄底 / 清算 / 建仓 / 仓位变动 / 喊单 / 清算地图 / 技术面阈值 / 资金费率）且**本候选 title/one_liner 文本内**无叙事 layer（宏观锚 / 项目生态 / KOL 冲突 / 跨源共识；**不可继承同实体历史轮**）→ 砍，不进打分，砍掉的 ID 显式列出。

**纯地缘跟报排除**（实测这类跟报互动 median 全线沉底）：军事 / 地缘 **follow-up**（第 N 轮打击 / 又一次升级 / 持续交火 / 常规化播报）且**本候选无独家角度**（时间线拼图 / 量级换算 / 跨语言共识 / 跨界传导（地缘→油价→实际利率→风险资产）/ 反共识读法，≥1 命中才算有角度；**不可继承同实体首发轮的角度**）→ 砍。
**豁免**（真 BREAKING 不是跟报）：首发突发（`first_seen <6h`）/ 带 ≥2 `exclusive_details` / `🌉跨界传导` 或 `✅多源确认` 标签。
判定靠**角度有无**，不靠"是不是地缘题材"：首发轮带时间线拼图 + 跨语言共识的该留，次日"第二轮打击"纯播报的该砍。

**时效硬过滤**：≤24h 正常 / 24-48h 先层 B 检查（🔴 即砍）且需 ≥2 可验证数字才保留 / >48h 淘汰（特例：持续发展事件只写最新进展；周期数据仅发布当日 24h 有效）。过滤后可用 <2 → 警告 + 三选项（重跑首扫 / 突发 / 手动补）。

## 3. 第零步：账号上下文（强制必读）

按需 grep 源文档，**不得凭记忆复述**；文件不存在 **或文件存在但仍是占位符** → warn 继续，对应加分项跳过。
> 🔑 **必须同时判占位符**：新克隆时这些 reference 文件**全都存在**、内容全是 `[主领域]` `[数字]` 这类模板值。只判"文件不存在"的话逃生**永不触发**，模型会把 `[主领域] 50-60%` 当成真配置读进去并据此打分——**不报错、不阻塞、直接产垃圾**。判定方法见 twitter-ops §0 判定原则③。

| 文档 | 用途 |
|---|---|
| `twitter-ops/references/voice-guide.md` | 调性 ±0.3 |
| `twitter-ops/references/operations-plan.md` | 周配额 / 红线 / 频次预算（**配比唯一权威**） |
| `twitter-ops/references/content-calendar.md` | 每日固定节奏 / 周度内容矩阵（判断本条题**该排在哪个时段/哪一天**）|
| `performance-review/references/patterns.md` | Pattern 实证 + 反模式 |
| `performance-review/references/audience-profile.md` | 受众画像 + 时段矩阵 |
| `<WORK_DIR>/account-weekly-progress-$WEEK.json` | 配额缺口 +0.2 |
| `<WORK_DIR>/account-pending-topics.json` | 待发清单占 Top 5 名额（**有条件**，见下）|
| `<WORK_DIR>/account-today-published-count-$DATE.txt` | ≥4 → 硬叫停警告 |

> 🔴 **这三个文件本模板里没有任何 Skill 会写**——它们是你自己发布流程的产出（可选外部输入）。
> 出厂全走「缺失 → 跳过」，这是**预期行为不是故障**，但必须在输出标一行
> 「配额/叫停闸未接数据源」，**不许静默当成"检查通过"**。同理「本周已发帖落盘」也不产出
> （影响 🅰️ 主引擎缺口 +0.5 与周单主题上限预警两处）。
>
> 文件名必须带 `$WEEK` / `$DATE`，因为这三个闸都会被**陈值反向触发**：
> `today-published-count` 原先名字带 today 却无日期戳且无重置规则 → 昨天的 4 今天误触发硬叫停；
> `weekly-progress` 原先是通配符 → 可能拿三周前的进度当本周；
> `pending-topics` 原先**无条件**占位且无日期戳 → 三周前的条目会一直占 Top 5 名额，
> 且不受 §2 时效过滤（那节只管 candidates）。**改为有条件**：条目须带 `added_on`，
> `$DATE − added_on > 7 天` 降级为普通候选参与打分；无 `added_on` 一律按超期处理。

## 4. Pattern 匹配（16 模板，详见 `references/angle-templates.md`）

16 个模板的编号、名称与时效窗口见 `references/angle-templates.md` 顶部速查表。

匹配组合：突发→7+2+3 / KOL-大户分歧→1+2+10 / 数据驱动→2+11+3 / 行业争议→5+1+6 / 周期信号→4+2+10 / 新叙事→6+9+8。**每话题 3 角度，Pattern 不重复。**

**#12 要点**：由 trend-scout 叙事榜 ≥3.0 的板块触发；4 模式（深度成因 / 跨界映射 / 对照差异化 / 反向风险）；hook 必含数字；Thread 优先；禁"X 板块全解析 / 新风口 / 我觉得"。

## 5. 角度 5 要素（每角度必填）

核心观点（一句话强立场）/ 反共识维度（时间·反向·结构·意图·延伸 选一，**3 角度不重叠**）/ Hook（<140 字符，数字开头 / 反直觉 / 提问 / 嘲讽）/ 反向风险（1-2 句）/ 结尾金句（陈述式判断，不开放提问）。
数据不足回调 Followin MCP（**tradfi 必传 `asset_type`，单 ticker 单调用**）。

## 6. 双层打分

```
最终分 = raw_score × 0.30 + reweight × 0.70   （clamp ≤5.0，溢出记脚注）
reweight = 时效×0.4 + 数据×0.3 + 争议×0.2 + 热度×0.1
时效 = base_timeliness × diffusion_factor   ← 必须显式列来源判定
```
**base**：<4h=5 / 4-12h=4 / 12-24h=3 / 24-48h=2。
**diffusion_factor**：财报会 / 监管机构 / 央行 0.5 → 头部通讯社 0.6 → 一线加密媒体 0.7 → 项目官号 0.75 → 国际 KOL 0.85 → 私域 / TG 0.9 → 中文小 KOL / 链上事件 0.95 → 多源独家 1.0。
⚠️ **"14h 全网热点给时效 5/5"是自查必抓错误。**

### 加分项（单候选总加分 cap +1.0）
| 项 | 分 | 判定要点（均须显式回答，禁裸加分） |
|---|---|---|
| 📌 bookmark | +0.3 | 30 天复用三问：对照表/矩阵/阈值清单？方法论手册？历史档案？情绪戏剧 / 单点快讯 / 当日点评 / 价格快照**全不算** |
| 👤 人物钩子 | +0.3 | 首句含顶级 IP 人物 |
| 🎭 调性 | ±0.3 | 4 题：合 voice-guide？合高表现模式？懂行朋友调性？避开低表现坑？命中红线 → -0.3。**情绪化 / BREAKING / 嘲讽是加分项不是扣分项** |
| 🎯 配额缺口 | +0.2 | 匹配当周最大 1-2 缺口类型 |
| 🅰️ 主引擎缺口 | +0.5 | **统计源以"实际已发"为准**：读本周已发帖落盘逐条判型统计——手动模式下"选过"≠"发过"；缺文件**或仍是占位符**时 fallback 已选数（偏乐观）。本周已发 `#主引擎` < 周锚且当前候选属该类型 → +0.5。与 🎯 **不叠加，取高**；两源都缺→跳过 |
| 🌉 跨界传导 | +0.5 | Q1 ≥2 市场域 + 传导逻辑？Q2 ≥2 数据钉子？Q3 280 字讲清？三问显式 |
| 📐 框架公式 | +0.3 | 框架先行 / 时间尺度对比 / 三催化剂 + 大佬原话 任一。**强制激活**：产业链 / 框架型候选（产业链 / 光通信 / 存储 / AI capex / 算力 / 定价权 / 渗透率）3 角度里必须 ≥1 个套此公式，漏套 warn |
| 💡 thesis | +0.5 | hook 是论点句（转折对立结构 / 可证伪 / 指向二阶含义，≥2 命中）非描述句。每候选显式判定；描述句候选 ≥1 角度必须改写成论点句 |

**跟报型 thesis 硬门槛**：`content_type ∈ {#跟报, #叙事}` 且层 B ∈ {🟠,🔴} → 主推 hook 必须论点句，否则 B/C 须有论点句改写；都没有 → 不进 Top 5（独家 / 🟡 不受约束）。
> ⚠️ **层 B 未配置时这道闸会静默关闭**（标签恒 🟢 → 条件永不触发）。此时改为**无条件对所有 `#跟报`/`#叙事` 候选要求论点句**，并在输出标注「层 B 未配置，thesis 门槛按保守口径执行」——**宁可严一点，也不要让质量闸在新用户处悄悄消失**。

## 7. 层 B 差异化严判（默认必跑 + 2h 缓存）

`BENCHMARK_KOLS + BASELINE_KOLS` × `twitter(action="user_tweets")` 近 24h → 落盘 `<WORK_DIR>/topic-engine-layer-b-$DATE.json`（含 `scan_timestamp`，<2h 复用缓存）。EXPECTED_KOL 数从配置派生，**勿写死**。

- **必抽数**：单账号原始返回 65-172K 字符 → **Agent 子进程内立刻 jq** 抽 `text`(280字) / `userName` / `createdAt` / `viewCount`；per-account cap：媒体号 20、个人 KOL 30。子进程返回 >10K 字符 → 拒收重跑。**禁止跳过基线组省 token。**
- **🔴 必须剔转推**：jq 抽取时剔掉转推（`include_replies=false` **只过滤回复不过滤转推**）。判据：**首选 `retweeted_tweet` 字段非空**（结构性，2026-07-30 实测确认——非转推时为 `null`，转推时含被转原文与真实作者 `retweeted_tweet.author.userName`）；该字段缺失时回退 `text` 以 `RT @` / `RT@` 开头。实测 stacy_muur 20 条里 7 条转推（35%），两个判据 7/7 重合。
  **这里漏剔的后果最狠**：对标账号**转的别人的推**会被算成"标杆已发"，
  配上基线组再一命中就是 🔴 双 hit ——**"直接砍，永不豁免"**。
  于是你的选题被一条**别人的转推**砍掉，而砍的理由在输出里看起来完全成立。
  回执里加 `"retweets_dropped": <数>`，自查按它判有没有真剔。
- **🧾 子进程回执（必做）**：主进程先生成 `SCAN_TS`（ms epoch，与 `scan_timestamp` 同值）显式传给每个层 B Agent；**每个 Agent 扫完 + jq 后用 Bash 落回执** `<WORK_DIR>/topic-engine-lb-receipt-<userName>-$DATE.json` = `{"userName":"…","raw_count":<原始推文数>,"retweets_dropped":<剔掉的转推数>,"scan_ts":<SCAN_TS>}`。自查按 `scan_ts == layer-b.scan_timestamp 且 (raw_count>0 或 scanned_empty) 且 retweets_dropped 是实数` 计 distinct KOL 数，须 ≥ EXPECTED_KOL，否则 FAIL。（只数自己写进 json 的 `scanned_kols` 长度 = 手写几个名字就能过、零真扫凭据。）
  - **`scanned_empty`**：某 KOL 近 24h 真没发推 → 回执加 `"scanned_empty": true`，区分"扫了·窗口内 0 条"（合法）与"压根没扫"（缺回执）——只看 `raw_count>0` 会把空返回误判成源挂。`layer-b.json` 必须含 ms epoch 的 `scan_timestamp`（回执绑定依赖它）。
- **4 标签**：🟢 独家（0 命中）/ 🟡 标杆已发（可借鉴角度）/ 🟠 基线已发（需差异化）/ 🔴 双 hit（**直接砍，永不豁免**）。
  🔴 **命中判定的粒度：按「角度/标的」匹配，不按「主题」匹配**（实测：粒度直接决定砍还是留）。
  - **算命中**：同一 `$TICKER`/实体 + 同一角度/数据点（如对标发过「$MU 崩 9%」，你也写 $MU 崩盘 = 撞车）。
  - **不算命中**：同一大主题但**不同标的/不同角度**——对标发「SK hynix 稼动率」，你写「美股 $MU/$SNDK 崩盘」，
    是同一个存储下行周期但不同标的、不同数据，**这正是差异化本身，不该砍**。
  - ⚠️ **双 hit 砍是破坏性动作，粒度不确定时默认「不砍、判 🟠 待差异化」**——
    宁可多留一条要你补差异化的候选，也不要用一个松匹配砍掉本可以发的独家角度
    （同 §0.5「别拿未定义标准执行破坏性动作」）。砍之前必须能说出「撞的是哪条推的哪个具体角度」。
  - ⚠️ **跨语言/跨写法是同一实体**：`三星 = Samsung = 삼성`、`美联储 = Fed = FOMC`——
    匹配要认全，别因写法不同漏判命中（实测 qinbafrank 中文「9票赞成3票反对」↔ Kobeissi 英文「votes 9-3」是同一事件）。
  - **标杆内部分歧不影响判定**：任一标杆命中即算「标杆已发」，不因另一标杆沉默而降格（实测确认）。
- **层 A 免费信号**：trend-scout 主 list 内自然出现的对标推文先查一遍（无额外调用）。
- **架构原则**：对标差异化只在本 skill 做；**禁止**以"对标在讲什么"为选题灵感；禁用自家产品的机械信号作灵感（自吹嫌疑）。
- **同主题查重切 Pattern**：跟报型候选（🟠/🔴/同梯队已发）对照 `<WORK_DIR>/twitter-published-patterns-$WEEK.json`，entity 重复时主 Pattern 必须切换（如 #5→#2/#3/#16）。文件不存在 **或仍是占位符** → 跳过。

## 8. Top 5 输出与配比

- **Top 5 是目标不是硬下限**——这里的"候选"指**过滤后可用条数**（≠ §2 的池子总数 12/7，别混）：
  可用 ≥5 → Top 5；**3-4 → 降级 Top 3 + 显式警告**；<3 → 拒绝出选题给三选项。
  极端可 Top 6（分差 <0.1 或豁免触发）。降级是合规路径，§1「禁止」列表禁的是**不声明就少给**。
- **差异化硬约束**：🔴 不进 Top 5；🟢 + 🟡 至少各 1。
  - ⚠️ 两个 KOL 白名单**均未配置** → 记 `n/a`（见 §0 通则）。无对标账号则所有候选恒为 🟢，「🟡 至少 1」数学上不可满足。
  - 配了名单却扫失败 → 仍是硬 FAIL（同 trend-scout P0 的意图：防的是静默漏扫，不是逼你凑名单）。
- **配比三态**：`CATEGORY_CAP`（**单批 Top 5 内单赛道占比上限**，🔴 硬——作用域见本节末，全仓统一按"单批"不按"周"）/ 单批同类 ≥80%（🔴 硬砍）/ 单批单赛道 ≤40% + ≥3 categories（🟡 软，警告不砍）/ **抢先豁免**（🟢 凌驾软规则）。
  🔴 **concentrated_day 例外**：高集中度日（trend-scout §5.0）单赛道天然扎堆（Fed+财报日 investing 常 ≥60%），此时 `CATEGORY_CAP` 与「≥80% 硬砍」**降级为软提醒不硬砍**——否则会把当天最该发的美股/宏观题砍掉。降级要显式标注「⚠️ 高集中度日，配比闸降级」。
- **抢先豁免**：`first_seen <2h` + `reweight ≥4.5` + 🟢 独家 三条件全中 → 强占名额不计配比（仍受 80% 上限），脚注显式标注。纯交易 / 🔴 永不豁免。
- **大事件强制位**：候选池含**行业级大事件** → **强制占 Top 5 一位**（不需抢先豁免三条件，仍须过纯交易排除 + 层 B）。🔴 判据不许凭"感觉大"：需**同时**满足 ① 主体是该赛道市值/份额前列者 ② 事件是产品/模型/重大落地首发（非迭代、非预热）③ **≥3 个不同信源在 24h 内报道**。三条缺一即按普通候选走打分。
- **周单主题上限预警**（防单引擎依赖）：出选题前读本周已发帖落盘，统计**单一主题 / 实体占比**。>60% → 本批优先非该主题 + 软提醒；>80% → 红色提醒 + 本批强制至少 1 条非该主题（除非该主题当日有 `raw ≥4.5` 抢先级 BREAKING）。文件缺 **或仍是占位符** → 跳过（宁缺勿误）。
- 连续 ≥2 轮单赛道 ≥40% → 末尾红色提醒「上游信号偏单赛道，建议 trend-scout 专项扫」——**不在本端硬砍**。
- **每条标注**：金字塔档位（**定义就在这一行，不在别的文件里**——★×5 顶层 = 新品首测 / 真 BREAKING；★×4 = 异动 / KOL 冲突 / 宏观×交易；★×3 = 有独家角度的常规题；★×2 底层不上）+ **内容类型代号（轴 B 战略角色，见 operations-plan §三·轴B）** + 预期 views 档位 + 对标借鉴提示。
- `CATEGORY_CAP` 未配置 → `n/a`（§0 通则）。**作用域钉死为「单批 Top 5 内的单赛道占比上限」**——trend-scout 与本 skill 都按这个理解，别各按各的。
- **周配额锚**（operations-plan 权威）：`MAIN_ENGINE_TYPES` 合计 ≥70% / 主引擎 ≥3 条（`ACCOUNT_ENGINES` 未配置 → 该项 `n/a`，§0 通则）/ 叙事型 2-3 / Bookmark 型 ≥3-4 / 日报 ≤10% / Thread 单批 ≤1。
- 末尾附：频次预算检查（当日已发 vs `operations-plan.md` §二 的日上限；🔴 **只认 §二 的「日发推目标：工作日 `[X]` 条」，该节带 `INIT-STATUS` = 视同未配置；时段表/§七的 10 条/engagement 的 1–2 条都不是日上限**。未配置就停下来问用户要一个数字，别拿别处的数字凑）+ **一次到位决策块**（选哪条 / 什么形式 / 什么时间，三变量一次答）。

## 9. 落盘 + 简报追加

> ⚠️ **字段名以下表为准，禁止凭记忆另起命名**（字段名漂移曾致每次返工、简报满屏 null）。

| 文件 | 精确字段 |
|---|---|
| `topic-engine-layer-b-$DATE.json` | `scanned_kols[]`(≥EXPECTED_KOL) · `candidates_labels[]{id,label}` · `scan_timestamp`(ms epoch，回执绑定锚) |
| `topic-engine-lb-receipt-<userName>-$DATE.json` | `{userName, raw_count, scan_ts, scanned_empty?}` 子进程真扫凭据 |
| `topic-engine-quota-$WEEK.json` | `week_published_count` · 各类型 count · `category_pct`(0-1) · `main_engine_pct`(0-1)。**跨周文件 → 持久目录** |
| `topic-engine-top5-$DATE.json` | `top5[]{rank,id,title,content_type,pyramid_tier,layer_b_label,viral_potential,raw_score,reweight,final_score,layer_b_evidence,bonus,time_window?,angles[]}` · `angles[]{letter,pattern(整串如 "#4 历史平行线"),hook,reverse_consensus,counter_risk,closing_line,when_to_pick}` · 可选顶层 `diversity{}` `execution_order[]` `cut_candidates{}` |
| `topic-engine-readlog-$DATE.txt` | 第零步 Read 凭证 |
| 简报追加 `## 🏆 选题表 · HH:MM` | 7 段：元信息 / 一览表(12 列) / 多样性 / 配额警示 / 5 个选题块(共 15 角度) / 执行序 / 接驳；frontmatter `modes` 加"选题" |

> **latest 索引兜底**：`$DATE-latest.txt` **缺失时**补写（`echo <json 绝对路径> >`）。
> 🔴 **仅限缺失——文件已存在时绝不改写**：这是 trend-scout 的命名空间，两方都写会把 latest 指回更旧的 json。

## 10. 输出前自查（任一不过禁止输出，补做重跑）

⓪ 第零步文档已读（有 readlog）① 候选池接力（模式自适应 floor）② 层 B 落盘 + ②.r 子进程回执真扫凭据 **+ ②.rt 每份回执 `retweets_dropped` 是实数**（没有它就没人知道剔转推有没有真跑，而漏剔会让别人的转推凑成 🔴 双 hit 直接砍掉你的选题）③ 配比（`CATEGORY_CAP` / 主引擎 ≥70%，**两者未配置各记 n/a 不阻塞**）④ Top5 结构完整（**降级态见 §8：候选 3-4 → Top 3 + 警告，此时 ④ 按"已按 §8 降级并标注"计 PASS**）④.5 每个 angle 6 字段齐 ④.6 叙事型周配额 ⑤ 至少 1 条高传播潜力 ⑥ 简报追加（5 块 / 15 角度 / 7 段 / frontmatter）。

## 11. 接驳

→ tweet-composer：每角度含核心观点 / 数据支撑 / Hook / 形式建议 / 反向风险，拿到即写、无需再选题。
关键原则：**时效 > 一切**（6h 话题价值 10 倍于 24h）/ 绝不预测价格 / 数据为王 / 分歧 = 价值 / 开头金句决定成败。

## 参考文件
- `references/angle-templates.md` — 16 Pattern 详解与 Hook 模板
- `twitter-ops/references/operations-plan.md` — 配比与周配额权威
- `performance-review/references/patterns.md` — 高表现模式实证
