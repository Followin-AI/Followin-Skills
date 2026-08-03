# Changelog

All notable changes to Followin Skills are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Entries are dated; the 1.x version numbers below the fold belonged to the retired npm package.
## 2026-08-03（晚）— 目录改名：`Live Positions/` → `Trader Diligence/`

**改名理由是命名不一致，不是措辞偏好。** 兄弟目录全部是「领域 + 干什么的」——Earnings **Screener**、Premarket **Tracker**、Research **Reader**、Twitter **Workflow**；只有 `Live Positions` 是**数据名**，读起来像个数据集而不是工具。而这支真正的产品是那六道闸（判断），不是那张持仓表（数据）。

`Trader Diligence` 与中文名「实盘尽调台」一一对应，也与 skill 文件 `live-position-diligence.md` 同源。

**排除过的候选**：`Copy-Trade Checker`（与「不做跟单账本」直接打架）· `Smart Money Tracker`（榜上多为 tier D 亏损户，"smart" 背不动）· `Position Auditor`（会被读成"审计我自己的持仓"）。

**skill 文件名与 `name:` 字段不动**（`/live-position-diligence` 触发词不变）——改的是 bundle 目录，不是 skill 本身。

## 2026-08-03（晚）— 尽调卡全流程实跑：4 个 Skill 缺陷 + 1 条新 caveat（升 v1.5）

**按 v1.4 把 20 条仓位从头跑到尾出一张真卡**，撞出的问题全部来自「跑」而非「读」：

| # | 缺陷 | 实测证据 | 处置 |
|---|---|---|---|
| ① | **上一条 CHANGELOG 的规模数写错了** | 实为 **20 仓 / 13 个显示名（归一后 12 人）**，此前记成 18 仓 / 11 人 | caveats + CHANGELOG + Skill 头三处同步改正 |
| ② | **闸① 绝对陈旧判据在周一失去区分力** | 命中率 **33%（周六）→ 65%（周一，13/20）** | 产出里必须注明当日周几与命中率 |
| ③ | 🔴 **闸① 判据②「组内落后」存在结构性失明** | 它相对**组内最新**算，整组一起冷掉时恒等于抓不到：CXMT 组龄 3.15 天 → 4/4 绝对陈旧但组内落后**仅 1 条**；**XYZ100 组龄 3.26 天 → 3/3 绝对陈旧但组内落后 0 条**。照 v1.3「跨周末以组内落后为主」执行，**XYZ100 整组会被判为"新鲜"** | **新增判据③「组整体陈旧」**：组自己的 `latest_event_time` ≥3 天 → 整组标待核 |
| ④ | **闸③ 的 `agreement` 判据只覆盖了一半成因** → 见 **N-59r** | CL 组 `agreement:unknown` 而 `positions_returned(2)==active_trader_count(2)`，**无人双向**，v1.3 判据完全落空 | 闸③ 改写，新增 caveat |
| ⑤ | **N-59q 在按人聚合层被二次放大，模式① 表格无「下界」列** | JS 聚合显示 **$0**，实际持 ETH **25x** + CXMT 10x；T13 显示 $0，实际持 XYZ100 **20x**。裸按金额排序会把**全榜杠杆最高的一档**静默排到榜尾 | 表格加「下界」标记，全 null 者不得按 $0 沉底 |
| ⑥ | **自查条目① 会误判「已修」** | 本批 BTC 组 6:1 且 `net_direction=long`（**一致**），只看最大那组会判 N-59j 已修；真正复现的是 CXMT（3:1 偏多 → 报 `short`）| 改为**逐组全扫**，任一组不一致即未修 |

**✅ N-59r（新，正面结论）——`agreement` 的真实计票规则，5 组反推 5/5 全中**：按**交易员**计票不是按腿，每人取唯一方向，**双向的人不计入分子但仍算进 `total_trader_count`**，`ratio = dominant ÷ total`，**可计票的人里没有严格多数（平局）就整体吐 `unknown/0/0`**。
验算：BTC 6÷7=0.857 · CXMT 2÷3=0.667 · XYZ100 1÷2=0.5 · **ETH 双向吃票后平局→unknown** · **CL 无双向、单向本身平局→unknown**。
⇒ 修正 N-59k 原建议的 `positions_returned` vs `active_trader_count` 判据（只能识别双向，识别不了平局）。**反过来这条规则可正面用**：分母是人数，`dominant ÷ ratio` 能反推 `total_trader_count` 交叉校验。

**⚠️ 另标一条阈值失效（非 bug）**：闸③ 的 40%「单人主导」阈值，本批 **5 组里 4 组命中**（47.9 / 59.4 / 76.8 / 62.5%），在当前榜规模下几乎恒真、无筛选力。→ **命中 40% 本身不再当红旗报**，改报具体占比 + 是谁 + 他有没有别的红旗。

**✅ 稳定复现的结论**：前三人占已标名义 **88%**（08-01 为 90%）· 显示名重复（T3=T3′，profile 指纹含 `summary_refreshed_at` 逐字一致）· `actions.close` 全组为 0。

## 2026-08-03 — 实盘侧复验：两条新坑（N-59p/q），Trader Diligence（原 Live Positions）升 v1.4

**复验一次全榜（`c02a7271`，5 组 / 20 仓 / 13 个显示名，归一后 12 人），当场撞出两条新的：**

| 编号 | 发现 | 处置 |
|---|---|---|
| **N-59p** | **`as_of` 不是战绩的刷新时间**——它对同一次返回里所有人统一等于**拉取日**，掩盖了各人 `summary_refreshed_at` 的不同步。实测 T1 `as_of=2026-08-03` 而 `summary_refreshed_at` 停在 **08-01**（落后 2 天），同批其余 12 人全是 08-03。⚠️ **危害精确落在最扎眼的数上**：闸④ 第 5 项要拆的正是 T1 的「98% 胜率 / PF 5510」，而这组数比同表其他人旧 2 天 | 时间锚改用 `summary_refreshed_at`；同表取各人最小值，跨度 ≥1 天须点名最旧的人 |
| **N-59q** | **全组 notional 皆 null 时，rollup 不报缺数据，而是吐 `net_direction:"balanced"` + 金额 0**——「完全没有数据」被渲染成「多空正好平衡、没有敞口」。实测 XYZ100：`positions_without_notional 3/3` → gross 0、balanced，而三条腿**全是 20x**。更阴的是 gross=0 会让它在敞口排序里沉底。✅ 对照 ETH 组 1/4 null 时 gross 正常 → 只有全 null 才退化 | 先判 `positions_without_notional == positions_returned`，命中则五个金额字段整体作废，只报人数与杠杆 |

**💡 `positions_without_notional` 是 dev 新加的字段**——N-59j 与 N-59q 现在都可**机械判定**，闸③ 不必再逐仓手算核对。

**两条旧坑的复验结论（都不能销案）**：
- **N-59l 维持待复验**——触发条件本批未出现：5 个 null-notional 行**全部无 `entry_price`**；唯一两者兼有的行经手算核对 `long.notional` 合计 **2,244,902 与 rollup 逐字相符**，未污染。**未命中 ≠ 已修**。
- **N-59m 机制仍在，且证据更强**——原样本的幽灵仓交易员已掉出榜单，但**本批 5 个 rollup 的 `actions.close` 全部为 `0`**（20 仓、跨 8 天、零个平仓事件），与「close 不回流」完全一致；陈旧仓依旧普遍（最旧 6.2 天，`is_active` 全 true）。**闸① 保留**。

**Trader Diligence v1.3 → v1.4**：闸⑤ 时间锚换字段 · 闸③ 新增形态 4 · 闸⑥ 拆成「标的无价格源」与「平台没给名义」两个来源（实测 XYZ100 两条同时命中，CXMT 只命中前者）· 自查条目 4 → 6 条 · 输出模板与卡头口径同步。

## 2026-08-03 — `time_range` 修复闭环：r0 升 v2.0（破坏性变更）

**Dev 修好了 N-37/N-38 的 `time_range` 腿，r0 的核心前提整体反转。** 五档交叉验收：`24h`(eligible **0**，周末) / `7d`(**170**) / `14d`(**333**) / `30d`(**622**) / 不传(**677**)——全不同。新增 `time_scope`(`report_date_window` vs `all_available_reports`)、`date_from`、`date_to`、`window_granularity` 四个透明字段，**实现比工单建议的更完整**。

**r0 v2.0 四处改动（默认行为变了，属破坏性）：**

| 改动 | 依据 |
|---|---|
| 默认窗口 **不传（累计）→ 7d** | ① `30d/累计 = 622/677 = 92%`，30d 约等于没选窗口（库最早 06-30，仅 34 天）② **只有 7d 能看见新面孔**——实测 `AVGO` 只在 7d 榜出现、`AMD` 在 7d 掉出 ③ `24h` 周末必空，不能做默认 |
| Top 10 → **Top 5** | 7d 榜尾样本太薄：第 10 名仅 **11 篇/8 家**（30d 第 10 名有 70 篇/16 家）|
| 层 2 预检 **可选 → 强制** | 短窗口下 subject 常为 0：实测 NVDA 不传=`6/4`、`7d`=`0/10`——**不预检就把榜首送进 r1，候选层不成立、直接空手** |
| **主/配角改为「标的 × 窗口」的函数** | 同一只票同一天，累计口径是主角票、7 天窗口是纯配角票。v1.x 把它当票的固有属性，实测证明会翻转 |

**💡 顺带白捡一个手段**：10 篇硬顶仍在，但**组成随窗口变**（NVDA 不传 `6 subject+4 mention`、7d `0 subject+10 mention`）→ **收窄窗口可以「腾出」名额给 mention**，这是 N-66（枢纽票拿不到跨标的数据）的一个可用绕法，v1.x 没有。

**仍未修、闸继续保留**：N-38 的 `report_limit:10` 硬顶与机构名不归一（榜面 25 家 → 钻取去重 3 家）· N-39 方向字段（换窗口同一标的从 positive 变 neutral，反而更证明它不是共识）· N-60 · N-61。

**同步回改**：`Research Reader/README`（边界①+⓪段+算钱：r0 从 1 额度变 2，典型路径 6 次调用）· caveats N-37/37a/37b 销案、N-38 标部分修复、`N-37·状态` 闭环 · `Community c3` 恢复传 `time_range="7d"`，可正当说「本週」。

**两处历史失效标注同步跟进**：`docs/产出样张集` 样张 3-1 与 `references/community-post-style` T-1——它们当初的作废理由①（"时间窗是假的 / 不得带时间定语"）**现已不成立**，改标为"重跑即可正当写本週"并补上重跑规格；但理由②（N-39 方向不可用）**至今仍成立**，两份样本的方向列继续封存。
⚠️ **T-1 的抬头保持不带时间定语**——它的数字仍是 07-22 的累计口径，**改标签而不重跑数据等于编造**。

## 2026-08-01 — 新增 `Trader Diligence/`（实盘尽调卡，当时名为 `Live Positions/`）+ 五条新坑，含一条上游 bug 与一条幽灵仓

**新增 [`Trader Diligence/live-position-diligence`](./Trader%20Diligence/live-position-diligence.md)。** 补上宣发两大主角里唯一没有专属 Skill 的那个——此前 `trader_position` 只在 `c4_social-pulse` 里当组件出现。新目录而非并入现有目录，因为它是另一个数据源（`signal` 而非 `metrics`）。

**⚠️ 与 2026-07-30 被否决的方案的边界**：那次否的是**模拟跟单账本**（前向记账、mark-to-market、算收益）；本 Skill 是**只读尽调卡**，明确写死"不算收益、不做账本"，并在正文引用该否决结论。否决理由①说"用户问'这人赚不赚钱'一次裸调用就答完了"——而同一份文档紧接着写「**几个最扎眼的数字恰好最会骗人**」。**后半句才是本 Skill 的产品**：它卖的是六道闸，不是那张表。

**首跑当场撞出三条 N-59 没记过的新坑（5 组 / 21 仓 / 17 名交易员，req `66880966`）：**

| 编号 | 发现 | 性质 |
|---|---|---|
| **N-59j** | **推翻 N-59a 的 workaround**：notional 派生方向在 **null 率为 0 时照样反向**。实测 BTC 组 8 仓全有名义，`long{count:7}` vs `short{count:1}`，但 `net_direction` 报 **short**——空方一人占 gross 的 50.0%，把 7:1 的人数分歧抹平并翻向。⚠️ 且翻转方向的这一仓 `current_symbol_caution` 恰为 `true` | 纪律升级：**notional 方向任何时候都不单独用**，不是"null 率 0 才可用" |
| **N-59k** | **同一交易员双向持仓会把 `agreement` 打崩成 `unknown/0/0`**——而 N-59a 恰恰推荐用它判一致性。实测 ETH 组 `active_trader_count:3` 但 `positions_returned:4`（T1同持多空两腿）。✅ 对照 CXMT 组也有人双向但还有 2 名单向交易员 → 字段正常给 `long/2/0.667`，说明是"能算就算、算不动吐 unknown" | `agreement.ratio: 0` **不可读作"没有共识"**；先用 `positions_returned` vs `active_trader_count` 兜底识别 |
| **N-59l** 🐛 | **疑似上游 bug**：`notional == null` 且该行有 `entry_price` 时，**rollup 把 `entry_price` 当名义加总**。实测 SNDK 组手算 2,678,962 vs rollup **2,680,184.04**，差 **1,222.04 = T1该仓的 entry_price**。**`.04` 小数是铁证**（其余名义全为整数）。5 组逐组核算，4 组干净、仅此一组命中 | 两组对照排除其他解释：null 但**无** entry_price 的行被正确排除（ETH/JS、CXMT/JS）；**同时有**两者的行用的是 notional（BTC/T4）。→ 触发条件精确为 `notional==null && entry_price!=null` |

**当天稍晚又补两条（由用户提供的上游 bot 截图触发）：**

| 编号 | 发现 | 性质 |
|---|---|---|
| **N-59m** 🔴 | **平仓不回流 → 幽灵仓**。上游监控 bot 显示「T5 当前无持仓」，而 MCP 同日仍返回其 SNDK $254万 + SKHY $197万，`is_active:true`、无任何 close 痕迹。**这两仓合计 $451万，是当次全榜第一大敞口（占 38%）**——不过滤就会把幽灵仓写成「最大的钱」。✅ 可从 `event_time` 陈旧度检测：本批 **7/21 仓（33%）≥3 天未动**，涉及名义 $486万（40%）；断层干净（陈旧簇 3.0–4.8 天、活跃簇 ≤1.8 天，中间无仓位）| 坐实 N-59d 留的悬念（「close 机制上可能支持，样本内未出现」）|
| **N-59n** | **同一交易员多个显示名**。「T3」与「T3′」profile 逐字段相同，**连 `summary_refreshed_at` 都是同一秒**。不归一会把 $251万 敞口拆成 $206万 + $45万 两个人 | 按 profile 指纹归一，别用 `trader` 字符串当主键 |

→ **Skill 升 v1.1**：新增**闸① 陈旧**、**闸② 姓名归一**（两者是过滤，必须在其余四闸之前跑）；输出模板改为**按人聚合**并加去噪三原则。
实测对照：同一批数据按标的组织 ≈90 行 / 逐仓列 21 条；按人聚合去噪后 ≈45 行 / 列 6 条，**且多出「前三人占全榜名义 90%」与「显示名重复」两个原始数据看不到的发现**。

**当天再补：模式②交易员视角 + N-59o（Skill 升 v1.2）。** `signal()` 按人名查不生效（N-59e），但**拉全榜本地过滤**足以支撑交易员维度，且能给出标的视角**结构性看不到**的四样东西：跨标的总敞口（T1 $380万 分散在 3 个组）、是否对冲（T1 ETH 双向）、显示名归一（T3=T3′）、以及——

**N-59o：能力圈「陌生区」上游无字段。** `current_symbol_caution` 只在标的落入 `caution_symbols` 时为 true；**落入 `focus_symbols`、或两个名单都不在，返回值完全一样（`false`）**——消费端分不清「他擅长这个」与「系统对他毫无判断」。实测 19 仓三分类：**擅长 12（63%）· 弱项 3（16%）· 陌生 4（21%）**，而**陌生区 4 仓中 3 仓 ≥10x**（JS 做 ETH 25x / T1 做 SNDK 20x 且为其最高杠杆 / T4 tier D 做 BTC 11x），**3 仓属跨资产类别**。
⚠️ 表述已校准：`focus_symbols` 导出口径未文档化，陌生区只能写「系统无判断」，**不能写「他不擅长」**；真正该顶出的是组合 `陌生区 × ≥10x`。

**另给「四项 sanity check」补了第 5 条**：`pnl_ratio_infinite` 只覆盖"零亏损"一端，**有限的极大值一样骗人**——实测T1 `pnl_ratio: 5510.64` / 胜率 98%。⚠️ 该员 07-20 还是 `∞` / 100% / tier **P**，08-01 变成 `5510.64` / 98% / tier **A**——**多出的那一笔亏损让分母不再为 0，tier 直接从 provisional 跳到 A**。→ `pnl_ratio > 100` 与 `infinite` 同等对待；**tier 会因单笔样本跃迁，当次读数用，别当稳定标签**。

**顺带修**：顶层 README 的 Research Reader 计数 **4 → 5**（r0 于 07-31 加入后未同步），routing 表补 `r0` 与 `Live Position Diligence` 两行。

## 2026-07-31 — 新增 `r0 覆盖雷达`（研报侧唯一发现器）+ 全仓修掉「本周研报榜」错误口径

**新增 [`Research Reader/r0_coverage-radar`](./Research%20Reader/r0_coverage-radar.md)。** Research Reader 从四支变五支：**r0 管"该读谁"，r1–r4 管"怎么读透"**，补掉 README 此前自认的边界①「不帮你选股」。

**为什么值得单独一支——它的产品是四道闸，不是那张榜。** 榜单能力本身 `Community c3` 层 1 早已在用，但 c3 是运营向繁体贴文（"仅供运营使用、群成员不直接交互"），投研用户碰不到；而用户裸问 MCP「谁被研报提得最多」会拿到 `NVDA 125 次点名 · 23 家机构 · 净方向 positive`——**这三个数字没有一个能按字面读**：不是本周（建库累计，N-37）、不是 23 家（钻取去重后只剩 3 家，N-38）、也不是看多（点名受益股天然带正向，N-39）。**r0 = 这个能力唯一安全的用法**，与 r2「口径审计器」同一文化。

**顺带产出一个别处没有的读数：主角票 vs 配角票。** `subject` 多 = 卖方专门研究它 → 进 r1；`mention` 多而 `subject` 少甚至为 0 = **它出现在别人的故事里** → 进 r4，进 r1 会空手（候选层不成立）。实测 GOOGL 排名第二、当天 `subject_reports=0`，正是配角票。

**⚠️ 销掉 2026-07-29 挂的 TODO：「c3 文案待修，本次未改动」。** 本次全仓修完，且发现错误口径**扩散到 5 个文件**、并多出一处此前未记的问题：

| 文件 | 修了什么 |
|---|---|
| `Community Skill/c3_research-hot` | 抬头/描述/层 1 小节/七段骨架标题去时间定语；**层 1 调用去掉 `time_range="7d"`**（传了只制造虚假信心）；**新增：层 1 不再输出多空方向**——排版示例里的 `多 22：空 0` 按 N-39 移除；防坑镜像补 N-37/N-39 两条 |
| `references/community-post-style.md` | T-1 已核可样例的抬头与首句（排版语气结构未动，仍是逐字基准）|
| `docs/产出样张集.md` | 两处场景表 + 4 个断掉的锚点 + **样张 3-1 整篇判失效**（见下）|
| `Community Skill/README.md` | 周更内容清单里的「本週研報熱點」|
| `references/followin-mcp-caveats.md` | **新增 N-37a** |

**⛔ `docs/产出样张集.md` 的样张 3-1（研报榜贴）整篇失效，已折叠存档 + 挂待重跑。** 修的过程中发现它比预想严重——**两根支柱同时塌**：贴文标题「本週機構在研究誰｜7/17–7/23」与首句「過去 7 天 383 份券商研報裡」踩 N-37；而十档榜每一行的「方向：偏正向（受惠 54／看空 6）」、整段「三個值得注意的地方」（最一致的是台积电 / 分歧最大的是英特尔 / 四档中性标的）、「今日名詞：受惠/看空/中性」那张卡、以及底稿表的「净方向」列，**全部建立在 N-39 判死的 `direction_counts` 上**。
这不是改字能修的——样张标称"真实数据实跑产出，非示意稿"，改数字等于编造。故**保留原样张作历史存档并折叠**，顶部挂失效说明与正确形态指引，标注「待按修正后规格重跑替换」。

**顺带修掉 4 个断锚点**（`产出样张集` 内，标题改名后链接未跟，其中 3 个是历史遗留、1 个是本次改标题造成）。核对方式：GitHub 锚点是**逐个空格转 dash 不合并连续空格**，用 `\s+` 归一会误判全部断链。

**N-37a（N-37 的跨日独立佐证）**：同窗口两次跑动，NVDA 榜首 **07-20 为 66 篇 / eligible 299** → **07-29 为 125 篇 / eligible 530**，9 天 **+89% / +77% 且无回落**。滚动窗口榜在旧报告出窗时数字必然下降，**单调增长即累计**——比"三档窗口返回相同"更直观。同次实测 `excluded_counts` 显示**入榜率仅 299/1162 ≈ 26%**，故榜单只覆盖已结构化的那部分研报，不是全市场卖方覆盖度。→ 衍生两条纪律：**禁止跨日比较榜面绝对值**（只能比名次结构）、对外须说明入榜率。

## 2026-07-30 — 否决：不在 `trader_position` 上做模拟跟单账本（仅留 caveats N-59）

**方案写完、真跑通建账、然后被自己的数据毙掉。** 曾计划新增独立 Skill `Copy Ledger/`（把顶级交易员的开/加/减/平仓事件记成等额虚拟仓、每日 mark-to-market、按 tier 分层算战绩）。文件已写完并实跑过 `init`（真建 17 仓账本），**评估后整体删除**，只保留数据面结论。留此条是为了拦住下一次重新提这个方案。

**三条否决理由，全部来自实测数据：**

1. ⛔ **被同一次 API 返回里的字段占优。** 账本要跑一个月才能给每个交易员凑出个位数样本，而同一份 `trader_position` 返回里，`profile.overall` 已经给了这 15 名交易员**合计 829 笔已平仓**的胜率与盈亏比。用 n=3 去估一个官方已用 n=22~431 估过的量，是退化不是补充。用户问"这人赚不赚钱"，**一次裸调用就答完了**。
2. ⛔ **核心产出"验证 tier 评级区分度"方法论上不成立。** 15 名交易员摊在 6 个 tier 上，按「层内 ≥3 人且最大单人占比 <50%」这道闸**六层全不通过**（A 2 人/64%、**B 1 人**、**C 1 人**、D 3 人但一人占 90%、P 5 人/69%、未评级 3 人/50%）。层的表现 = 那个人的表现，**混淆变量而非样本量问题**，攒几个月也不解决。且账本样本对 tier 口径本身有偏：这些人合计每天平仓约 10.8 笔，日频快照只能干净跟到持仓过夜的慢仓，而 tier 是按全部成交算的。
3. ⛔ **可观测性太低，且 1/3 标的根本无法计价。** 日频轮询覆盖率仅 **9–28%**（N-59i）；建账日 17 仓里 **6 仓（35%）** 取不到价格源，**5/15 名交易员一个可计价仓都没有**，账本对他们永远给不出收益数字。

**保留下来的**：

- **caveats `N-59a~i` 九条** + 一组「展示交易员档案前的四项 sanity check」（`pnl_ratio_infinite` 陷阱 / 小样本高盈亏比 / `current_symbol_caution` / 杠杆 ≥10x，附 `n<10` 不给百分比）。这些独立于被否决的方案，任何消费 `trader_position` 的地方都适用。
- 最咬人的几条：notional 派生的 `long_notional_ratio`/`net_direction` **只统计有名义的行、null 行被静默排除，会给出反向结论**（CXMT 3 多 1 空却报比率 1）；`entry_price` 覆盖率仅 **6%**（只在 `action=open` 行）；取价有**两种静默失败**且都返 `status:"ok"`（keyword 被整个剔除 / 进了 keyword 但无返回行）→ 必须做请求与返回的差集自查；榜单**分钟级变动**（18 分钟内 SNDK 4 人→5 人），"全榜没有它"≠"已平仓"；`profile` 是**日快照**而仓位是实时的，且 `last_30d` 是**滚动窗口**、其增量不等于当期成交数（须用 `overall.n_trades` 增量）。
- ⚠️ **方法论教训**：本轮先实测了数据（对），但**直到第三次追问才去测"免费基线已经给了什么"**（错）。必要性评估必须带上"什么都不做、直接读字段"这个对照组——否则会为一个已被现成字段解决的问题造工具。

## 2026-07-30 — 目录改名：`Research Desk/` → `Research Reader/`、新增 `Twitter Workflow/`

- **改名**：`Research Desk/` → `Research Reader/`（更直白：一看就知道是「读研报」，与 `Earnings Screener`/`Premarket Tracker` 同构）；`Twitter Ops/` → `Twitter Workflow/`（去掉 Ops 行话）。
- **同步新增** `Twitter Workflow/`（7 个 Skill，从 `Apatheticco/twitter-ops-template` 同步的推特日运营工作流；8 段 live 数据端到端验证过，端点/字段坑记为 caveats N-47~N-58）。
- 历史 CHANGELOG 条目中的 `Research Desk` 路径已一并更新为 `Research Reader` 以保持链接可用；条目里的名字在当时实为旧名。

## 2026-07-29 — Research Reader 文档面向用户重写 + 新增产出样张

- **README 改成给用户看的**：目录 README 178 → 134 行。删掉三轮实测过程叙述、6 个规格缺陷表、「为什么库内四族信号搬不过来」整节、每条结论后挂的实测证据——这些是维护者视角，已在本 CHANGELOG 与 caveats 里，README 只留指路链接。结构改为：**解决什么问题 → 四支各干什么 → 跑出来长什么样 → 怎么用 → 两条用前须知**。根 README 两处同步压缩。
- **新增 [`docs/研报投研台样张.md`](./docs/研报投研台样张.md)**：沿用 `docs/产出样张集.md` 的规格（真实数据、标日期与额度、非示意稿）。英特尔单票、2026-07-29 一次跑动、3 次计费调用，四支产出全放出——r1 完整读数卡（含四维对撞表与净信号三问）、r2 七篇逐篇地基 + 交叉读法、r3 时间线（本标的 + 关联标的 + 分布读法）、r4 关系边 + 16 条同链修正。
- 样张文末附「这批样张暴露的真实约束」三条（枢纽票反而没产出 / 同框名字彼此无关 / 最理想字段拿不到），与社群样张集同一体例。
- 目录 README 内联 r1 领读段作为预览，其余指向样张集。

## 2026-07-29 — `Research Signal/` → `Research Reader/`（改名 + 改定位）

**名字比东西大，改回来。** 四支 Skill 里没有一支是 signal——按库内自己的定义，signal 是**规则触发、离散、能扫描**的（错位/时钟/信念/水分，拿一个池子跑一遍看谁亮灯）。而 r1–r4 全都**必须先点名一只票才开工**，没有任何一支能主动告诉你"这只票现在有情况"。它们是**投研工具**：校准读法（r1）／文本审计（r2）／信息整理（r3）／关系抽取（r4）。

- **目录改名**：`Research Signal/` → `Research Reader/`（研报投研台）；`r1_cross-source-signal-card.md` → `r1_cross-source-readout.md`，产物「信号卡」→「读数卡」。安装路径随之变为 `cp "Research Reader"/*.md ~/.claude/commands/`。
- **触发词修正**：r1 的 `研报信号` / `research signal` 移除——**这个错配会在真实使用里咬人**：喊"信号"的人期待的是**发现**（告诉我哪只票有情况），拿到的却是"请先告诉我看哪只"。
- **⚠️ 保留的 signal 原语**：r1 里的四个告警（TP 离散 >1.8x、孤儿、GAAP 口径错位、真修正检出）**是货真价实的规则触发闸**，但它们只能对已选定的票亮灯、扫不了池子，所以**没有发现价值，降级为 checklist 勾选项**。这不是"做得不够 signal"，是**这份数据不支持 signal 形态**（N-37/38/39 三座山）。
- 命名源自最初的《信号生成器·Signal 板块旗舰引擎》方案，当时假设能做发现型——该假设已被实测证伪，名字此前没跟着改。
- 历史 CHANGELOG 条目中的路径已一并更新以保持链接可用；条目里的"Research Reader"在当时实为"Research Signal"。

## 2026-07-29 — 新增独立 Skill：美股盘前自选追踪

- **新增 [`Premarket Tracker/`](./Premarket%20Tracker/premarket-watchlist-automation.md)**：
  根据自选股、持仓、时区与时间创建或更新盘前周期任务；无自动化能力时降级为即时报告。
- 报告固定覆盖市场背景、单票异动/催化、持仓对应计划、组合相关性风险、来源与刷新条件。
- 对齐 Followin 当前工具路由：结构化行情/研报走 `metrics`，一般社媒热度走 `news(twitter)`，
  `twitter` 只处理命名账号/指定推文，`signal` 省略 categories 做 fanout，`subscription` 明确为拉取式未读箱。
- 新增盘前数据边界：美东 04:00 前不把最近收盘或实时快照称为真实盘前成交；休市日明确标注。

## 2026-07-29 — `Research Reader/` 新增 r4 产业链读穿（三件套 → 四件套）

- **新增 [`r4_supply-chain-readthrough.md`](./Research%20Reader/r4_supply-chain-readthrough.md)**：单标的产业链关联图。
  三层产出——**关系边**（`mention_context.rationale`，为什么这份报告提到它 + 方向）、**同链修正**（过闸后的 `by_name`，链上谁被改了价）、
  **跨标的催化剂**（`catalysts[].security ≠ ticker`）。与 r1–r3 共用同一次研报调用，**0 额外额度**。
- **⚠️ 本支是先撞完数据才动笔的——原设计被实测推翻两次**（caveats N-65/N-66/N-67）：
  - **N-65**：`detail.affected_names` **计数有、内容永远没有**（实测 30/30 篇全缺）。最理想的产业链名单（Nomura 一篇标了 31 个名字）一个都取不到，只能改用三个替代数据面。
  - **N-66**：**10 篇硬顶是 subject 与 mention 共享的，"枢纽票"反而拿不到产业链**。实测 2330.TW（榜第 4 / 70 篇 / 17 家）返回 `subject 10 / mention 0` → 关系边 **0 条**；而榜第 6 的 INTC 拿到 **16 条**跨标的修正。跨标的数据几乎只存在于 mention 报告，专题一多就把它挤没了。**不要用榜单排名挑标的。**
  - **N-67**：**汇编报告的 `by_name` 是「同框噪音」不是产业链**。查 NVDA 得到的 12 条跨标的修正是印尼棕榈油 / 印度银行 / 韩国船舶——只是同处一份《Asia Morning News》。按 `subject_name` 加汇编闸后：NVDA 30 噪音/6 真链、GOOGL 17/5、**INTC 0/16**；不加闸时 NVDA 输出 **83% 是无关名字**。
- **同批两条数据特性**：`by_name` 的 `old_target_price` 覆盖率仅 **26%**（25/96）——"当前目标价"≠"被改价"，须分开表述；`catalysts[].security` **不保证是 ticker**（实测出现板块名 `"AI SEMICONDUCTOR SUPPLY CHAIN"` 与逗号多值）。
- **正面发现**：`mention_context.rationale` 质量远超预期，是**带方向的机制描述**而非标签（"英伟达是诺基亚 AI-RAN 平台的开发伙伴"）。⚠️ 但**必须读全句**——实测有自带否定的边（"…是 UMC 的潜在 3nm 伙伴，**但 Bernstein 认为不太可能**"）。副产品：过闸后可顺带白拿链上其他标的目标价（查 INTC 得到 NVDA $315 / AVGO $550 / AAPL $350），但那是单家读数非共识。

## 2026-07-29 — 新增 `Research Reader/`：研报投研台

- **新增 [`Research Reader/`](./Research%20Reader/)**（3 个 Skill，独立目录）：
  **r1 跨源印证读数卡**（研报候选 × 共识/市场/KOL 与内部人/基本面四维对撞，3 额度，输出校准读法不给买卖建议）、
  **r2 口径审计器**（只审结论的地基：基准是谁 / 口径边界 / 自陈偏差，可复用 r1 返回 0 额度）、
  **r3 催化剂时间线**（`detail.catalysts[].time_std` 归一后按精度分桶，补 N-22 财报日历判废留下的前瞻腿缺口）。
- **⚠️ 明确不做研报扫描器**，理由是数据可见性而非实现难度。库内四族信号（错位/时钟/信念/水分）建立在状态层全量折叠之上，
  **实测只有水分族（TP 离散）能干净地搬到 MCP 侧**，已并入 r1 当检查项；错位族与信念族因只有 3–5 家可见而不成立。
  （停覆信号最初判为"MCP 无对应字段"，**同日第二轮实测推翻**——见下方 N-63。）
- **caveats 登记表新增 N-37 ~ N-41 共 5 条**（含 request_id 与复现方式）：
  研报榜 `time_range` 完全无效（24h/3d/7d 逐字相同，实为全量累计榜）、钻取硬顶 `report_limit=10` 且 `limit`/`time_range` 双双失效、
  榜单 `net_direction` 被连带污染不可当方向共识、`signal()` 的 kol_call 可能整个缺失目标 ticker 自己的行（须回读 `content`）、
  `catalysts[].time_std.sort` 格式 ≥6 种且含 `"9999"` 哨兵。
- **⚠️ 顺带发现一处对外表述错误**：`Community Skill/c3_research-hot` 把研报榜称为「本週研報熱點 / 過去 7 天」，
  而该榜实为建库以来累计（N-37）。**c3 文案待修，本次未改动**。
- **正面发现（省额度）**：`metrics(query="<T> analyst ratings price target")` 一次调用即返回
  `consensus_price` + `analyst_grades` + `beat_miss` + `eps_trend` + `next_earnings_estimate` + `valuation_block` + `market.snapshot`，
  跨源印证的维度 1 + 维度 4 + 价格腿一次拿全。

### 同日第二轮：端到端实跑（INTC / GOOGL / F）修 6 个规格缺陷

把三支 Skill 的客户端规格**写成脚本对真数据实跑**，并刻意换标的（NVDA 是写规格时的样本，自测等于过拟合）。暴露并修正：

- **N-62（新）**：N-3 的「机构+标题+日期」去重**去不掉「快评 + 完整版」**——GS 对 INTC 同日发两篇同 TP、标题不同的报告，5 家被读成 7 家。追加「同机构+同日+同 TP 强制合并」。
- **N-33 同季判据修正**：`beat_miss.date`（公布日）与 `latest_quarter.date`（财季结束日）**天然不等**，朴素比日期会把每个正常样本判成"不同季"，**作废掉本该生效的 N-29 GAAP 错位检测**。改用 N-34 的 `gap < 90 天`。INTC 实测 gap=26 天 → 检测生效，抓出 `epsActual 0.42`(非GAAP,+100%) vs `latest_quarter.eps −2.16`(GAAP 净亏 110 亿) 的反号。
- **N-41 改写**：初版按单标的（NVDA 20 条）写的 `time_std` 归一规则，换标的后**覆盖率仅 77%**。按三标的 **60 条**重写：`sort` **10 种形态**（新增 ISO datetime / `YYYY-QN` / `YYYY-FQN` / 开区间 / 语义后缀）、`type` **22 种取值**（不是 12 种）含三组同义异写。**最大的坑是精度降级**：初版只防 `type=year`，被 `type=quarter` 打穿——`sort="2026-09-30"` 被渲染成"9 月 30 日"，实为"Q3 末某时"，凭空造精确度。
- **N-63（新）**：`revision_summary.list_changes[]` **字段确实存在**，此前写"MCP 无此字段、停覆信号做不了"是**错误断言**。实测只见 `initiate`/`add`，未见停覆类 action → 改为「样本内未出现，机制上可能支持」。
- **N-64（新）**：`subject_reports` 数量**日间剧变**——N-19 记的「GOOGL subject=0」（07-23）在 **07-29 复测为 6**；同日 **F 才是 subject=0** 且只返回 3 篇。判定逻辑仍成立，**但举的例子已过期**。
- **r2 四轴分类不可规则化**：写成正则跑 INTC 7 篇**错 4 篇**（Bernstein "强是靠 mix/ASP 不是销量" 这条教科书级口径边界被判成 🟢）。改为 LLM 语义判断 + 校准样本库，正则降级为召回提示。
- **另两条**：`valuation_block.dcf` 亏损期给荒谬值（INTC `2.95` vs 现价 `86.57`，差 29 倍）且无失效标注 → 列入不可引用；`rating_action` 全 `reiterate` ≠ 无修正（INTC 大摩 75→84 +12%、伯恩斯坦 100→110 +10%），两者须分开读。
- **顺带**：r1 的水分族检查首次真触发——INTC TP 84–200 离散 **2.38x**，并抓出真多空对决（同日 HSBC Buy $200 vs 大摩 Equal-weight $84，后者低于当时股价 3%）。

### 同日第三轮：输出层加解读要求

原三支的输出模板偏字段陈列——r1 只有末尾的「净信号」算解读，r2/r3 基本是把 caveat 和时间桶排出来就完了。三支统一补两层：

- **【🔎 领读】置顶**（三支都加）：2–4 句判断，写在最前不是最后补。回答"最该停下看哪条、哪些看着显眼其实可忽略"。
- **r1**：每个数据块后强制配一句「所以」——对撞不是把四维读数并列，是指出**它们矛盾在哪、谁该让位于谁**。
- **r2 新增【🧩 交叉读法】**：只有把几篇放一起才看得出的东西。三问——地基强弱与结论激进程度是否倒挂（⚠️**最该警惕：目标价越高、地基越薄**）／几篇的 caveat 是否指向同一盲区（⇒"市场整体在盲区里定价"）／哪些结论跨过可疑地基还站得住。
- **r3 新增【🧩 分布读法】**：**催化剂的疏密与远近本身就是读数**。四问——近 90 天有无真检验点（近乎为零＝短期不由自身事件驱动，这是硬判断不是"没找到"）／重心在近处还是全堆远期／谁被多家独立点名（＝这批研报的公共押注）／已过期桶的兑现率。
- 三支硬要求各配一张 **❌复述 / ✅解读对照表**，例句全部取自 INTC 实跑的真句子。判别标准：**把数字换成别的数，这话还成立吗——成立是复述，不成立才是解读**。

**修正后已用同一脚本复验**：去重 INTC 7→6→**5 家**（N-62 生效）｜同季判据 INTC/NVDA gap=26/24 天 → 闸1 均正确生效｜催化剂归一 **77% → 97%**（58/60），精度降级拦下 8 条假精确日期。
⚠️ **连带修正一处自伤的数字**：r3 原写"只有 10% 精确到日"——那是坏归一器造成的假象（23% 被误扔进待锚定桶）。修好后真实分布为**日 40% / 月 17% / 季 17% / 半年 8% / 年 15% / 待锚定 3%**，README 与 Skill 正文均已改。「不是日历」的结论不变（仍有 60% 粗于日级）。

## 2026-07-29 — 新增独立 Skill：财报季超预期扫描

- **新增 [`Earnings Screener/`](./Earnings%20Screener/earnings-season-screener.md)**（根目录独立 Skill，不属于任何 bundle）：
  无需指定 ticker 的财报季发现器。异动榜 + 新闻反向捞双腿发现 → 四道业绩硬闸 → Top N 逐字稿深扫 →
  业绩闸与关键词闸叠加判定。含反向关键词减分与 GAAP 口径错位检测。
- **⚠️ 废弃市场级财报日历**：实测其等效 `ORDER BY date ASC, symbol ASC LIMIT 50` 且 `limit` 入参不被尊重，
  按字母序截断导致 GOOGL/MSFT/NVDA/TSLA 在密集日必然出局；客户端五种杠杆全部无效。
  受影响的 `Base Skill/02`、`Community Skill/c1`、`c2` 已改为「关注池 + `next_earnings_estimate` 核实」，
  并写入对外发布铁律：只能写「我们盯的这几家」，严禁写「今日/本周财报一览」。
- **caveats 登记表新增 N-22 ~ N-36 共 15 条**，另作废 N-2、结案 N-11、强化 N-28。
  其中多条修正了此前的错误定性（如 N-23 从"批量截断"拆分为"截断 + 上游字典缺失"两种独立故障）。
- **原油符号全面改写**：`CLUSD` 返 0 结果、`BZUSD` 静默丢弃、`OIL` alias 返回 ETN，只剩 `USO` 可用。
- `mover` 榜从 `biggest gainers/losers` 改为 `most active stocks`（前者实测返回垃圾数据）。

## [Unreleased]

### Ideas
- On-chain data skill (Glassnode / CryptoQuant integration)
- Polymarket API integration to replace web search for FedWatch probabilities
- Deribit options data skill for implied expectations layer

---

## [2026-07-24] — `skills-community/` → `Community Skill/`

### Changed
- **`Base Skill/Skill/` flattened to `Base Skill/`** — the nested "Skill" folder was redundant; both bundles now keep their .md files at the top of their own folder. Install command: `cp "Base Skill"/*.md ~/.claude/commands/`.
- Bundle folders now named symmetrically: **`Base Skill/` + `Community Skill/`**, shared assets in `references/`. Future scenario bundles get their own top-level folder — one repo as the shelf, folders as the products (decided against a repo split: both bundles share the caveats SSOT, and split copies are how `skills-v2/` rotted).
- Install command in the community README is now `cp "Community Skill"/*.md ~/.claude/commands/` (folder name contains a space).

---

## [2026-07-24] — Directory layout: `.claude/` → `Base Skill/` + top-level `references/`

### Changed
- **`.claude/commands/` → `Base Skill/Skill/`** — the base bundle now lives in a visible, product-named folder instead of a hidden dotdir, mirroring `skills-community/`.
- **`.claude/references/` → top-level `references/`** — the caveats SSOT and post-style guide serve both bundles, so shared assets moved out from under any single bundle's folder.
- Install source path is now `cp "Base Skill/Skill"/*.md ~/.claude/commands/` (note the quotes — the folder name contains a space). The target stays `~/.claude/commands/`.
- All repo-internal path references swept (READMEs, skill authority pointers, community README, 样张集, caveats header). `~/.claude/…` consumer-install paths are untouched.

### Note
- Cloning the repo and opening it in Claude Code **no longer auto-loads the skills** — `.claude/commands/` was Claude Code's convention path for project-local commands. Copy the files into your own `~/.claude/commands/` (or your project's `.claude/commands/`) as the README describes.

---

## [2026-07-24] — Remove Macro Analyzer (07); flagship count 7 → 6

### Removed
- **Root slimmed: `package.json` and `.mcp.json.example` deleted.** package.json had no function left after the installer retirement (no bin/scripts/deps; `private: true`) — its one remaining job, the MIT declaration, moved to a proper `LICENSE` file. The example file was a third copy of the 10-line MCP config both READMEs carry inline. Installer-era changelog entries (1.0.0–1.6.0, ~215 lines) collapsed into a stub pointing at git history; Node block dropped from `.gitignore`.
- **`07_macro-analyzer` deleted** — same criterion that removed Breaking News: its analysis layer (indicator → sector impact) is model-native reasoning. What made it look skill-worthy was the FRED series_id translation dictionary it hosted — but that is reference data, not workflow, and the caveats SSOT (red line 3) already pointed at it from outside the skill.

### Changed
- **Terminology: the individual-trader bundle is now 基础 Skill / Base skills** (was 旗舰 / Flagship) in both READMEs. Historical changelog entries keep the old term.
- **The 21-entry 中英文 → FRED series_id dictionary moved to the caveats SSOT as Appendix A**, with two dangerous entries corrected in transit: `BAMLH0A0HYM2` (credit spread) marked unusable per B-33 — a direct keywords query silently returns M2SL instead — and `CLUSD` flagged 402 per N-11 with `BZUSD`/`USO` as the working alternatives. The old table listed both with no warning.
- Red line 3 now points to Appendix A; `02`/`03` intent-routing rows that sent macro-impact queries to `macro-analyzer` now state there is no dedicated skill — the model calls `metrics`+`news` directly.

### Fixed
- **`04_btc-macro-dashboard` carried a v2-era row** telling readers to query FRED with natural language (`metrics(query="<指标中文或英文>")` / "不再维护 series_id 映射") — contradicting red line 3, the skill's own execution steps, and its own anti-pattern demo at line 181. Now uses the keywords form.
- **Stale renumbering leftovers the previous sweep missed** (`转 08_BTC宏观看盘` / `09_黄金监控看盘` inside 07's routing table — moot after deletion; `-v2` command headings in 01/02/03/06).
- **Dangling v1-skill references in frontmatter descriptions**: 02 routed "今天有哪些财报" to 情报中心 and 03 routed "有什么异常" to 热点舆情/代币舆情聚合 — all three were v1 skills deleted in `bd978a6`. 03 additionally contradicted itself by claiming "有什么异常" in its ✅-routing row while its description excluded it; resolved in favor of exclusion.

---

## [2026-07-24] — Flagship skills renumbered 01–07 ⚠️ breaking

### Removed
- **`02_breaking-news` (Breaking News Analysis) deleted.** It was the last skill with no MCP dependency — pure prompt-level analysis that the model does without a skill file.

### Changed
- **All flagship skills renumbered into recommended-onboarding order, and the `_v2` filename suffix dropped** (it no longer distinguished anything once `skills-v2/` was removed). Anyone who copied these into `~/.claude/commands/` should delete the old files before copying the new ones — otherwise both sets will be live and compete for the same triggers.

  | New | Old | Skill |
  |---|---|---|
  | `01_multi-agent-stock-analysis` | `14_…_v2` | Multi-Agent Stock Analysis |
  | `02_us-stock-earnings-report` | `11_…_v2` | US Stock Earnings Report |
  | `03_us-stock-divergence-scan` | `13_…_v2` | US Stock Divergence Scan |
  | `04_btc-macro-dashboard` | `08_…_v2` | BTC Macro Dashboard |
  | `05_gold-macro-dashboard` | `09_…_v2` | Gold Macro Dashboard |
  | `06_macro-morning-brief` | `10_…_v2` | Macro Morning Brief |
  | `07_macro-analyzer` | `12_…_v2` | Macro Analyzer |

- `.claude/references/14_agent-prompts.md` → `01_agent-prompts.md`, matching its owning skill.
- Cross-references swept: skill-to-skill citations, the caveats SSOT header and its B-33 rollback instructions, and both READMEs' skill tables and routing guides.

### Fixed
- **Dangling route to a deleted skill.** `06_macro-morning-brief` sent crypto-daily requests to "Skill 04 crypto-daily-brief" — that skill was deleted back in `bd978a6`, and after renumbering `04` is the BTC Macro Dashboard, so the pointer had become actively wrong. It now states plainly that this repo has no crypto-daily skill.
- **Duplicate caveat entries removed.** N-22/N-23/N-24, added earlier the same day, restated N-4 (signal fanout quota), N-5 (kol_call `source_url` splitting), and N-8 (array-param serialization) — all already registered on 2026-07-22. The 2026-07-24 re-verifications were merged into the original entries instead, including a correction: N-4's "fanout 全 4 类" returned only three categories in this run because `trader_position` had no rows for the ticker, so consumers must key off what actually comes back rather than assuming all four.

---

## [2026-07-24] — Repository cleanup

### Removed
- **npm installer retired.** Deleted `bin/cli.js` and the `bin` / `postinstall` / `files` /
  `publishConfig` fields from `package.json`; the package is now marked `private`. Setup moved to
  [followin.io/en/mcp](https://followin.io/en/mcp). The published `@followin/skills@1.6.0` is
  unaffected but is no longer the recommended install path.
- **`skills-v2/` deleted.** It was a stale duplicate of `.claude/commands/` carrying instructions
  that later testing disproved — notably `metrics(query=…)` for FRED series (a confirmed semantic
  trap) and a live `BAMLH0A0HYM2` call that silently returns M2SL instead (B-33). `.claude/commands/`
  is now the single authoritative copy.
- **`mcp-testing/` deleted** — abandoned scaffold: 11 personas defined, 2 run reports, 9 empty
  directories, last touched 2026-05-27.
- **`docs/superpowers/` deleted** — internal plans, specs, and regression logs, not intended as
  public documentation.
- **`USER_GUIDE.md` deleted** — merged into `README.md` / `README.zh-CN.md`. Its pricing table had
  drifted from the current credit-based model; the READMEs now link to the official pricing page
  rather than restating numbers that go stale.

### Fixed
- **READMEs rewritten to match the actual inventory.** Both language versions claimed 13 skills and
  documented six (01, 03, 04, 05, 06, 07) that were deleted back in `bd978a6`, while omitting skill
  14 entirely. They now document the 8 skills that exist, plus the 6-module community bundle.
- **Stale "Technical Notes" removed** — documented the v1 MCP surface (`finance_tool_quote`,
  `fred_get_series`, `search_finance_news`, …), none of which exists on the current
  `metrics` / `news` / `signal` / `twitter` / `subscription` toolset.
- **`.mcp.json.example` updated** to the single merged `followin` server at
  `https://mcp.followin.io/v2/sse`, replacing the retired two-server `followin-mcp` + `premium-mcp`
  layout with API keys in the query string.

---

## 1.0.0 – 1.6.0 (2026-03-23 → 2026-04-15) — npm installer era

Seven releases of the retired `@followin/skills` installer (multi-client setup presets,
MCP auto-config, install-layout changes). Removed from this file along with the installer —
the full entries remain in git history:

```bash
git log --follow -p -- CHANGELOG.md
```
