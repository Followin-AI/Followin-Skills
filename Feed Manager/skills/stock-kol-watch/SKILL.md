---
name: stock-kol-watch
description: Stock KOL Watch — 把一组自选股票 KOL 账号的近 N 小时推文，转成"一份合并日报 + 每标的累积笔记 + 每板块累积笔记"的决策辅助系统。触发词：跑一下 KOL / 拉最新数据 / KOL watch / 股票观察 / 美股观察 / 快速简报 / 补一下昨晚的 / 开盘前汇总 / 跑日报 / stock KOL watch。
version: 2.0-framework
---

# Stock KOL Watch — 股票 KOL 观察日报框架

> 把你**固定关注的一组股票 KOL 账号**的近 N 小时推文，转成"**一份合并日报 + 每个标的一份累积笔记 + 每个板块一份累积笔记**"。
> 这是一套**信息整理 + 决策辅助**方法论，不是 signal generator——它帮你把散落的 KOL 信号结构化、可追溯、可复盘，**判断权永远在你手里**。

> ⚠️ **这是脱敏框架版**。原版深度耦合作者的个人配置（vault 路径、实盘群、付费源、具体关注名单）。本版只保留核心主链；进阶层 7 节（实盘仓位源 / 卖方研报 ingest / 独立研究 ingest / digest 深读外包 / RT-QT 候选挖掘 / 归档审计 / 一条实测否决项）已移至 [references/advanced-extensions.md](references/advanced-extensions.md)，用顺手了再按需加回。

---

## 🅰️🅱️ 运行模式（先选，🅱️ 是零门槛入口）

| | 🅱️ 快速简报（默认，无 vault） | 🅰️ 旗舰版（持久化 / vault） |
|---|---|---|
| **产出** | **只在对话里**出一份当日简报，不落文件 | 日报 + 标的/板块累积笔记 + 决策闭环 + 周报，全部落盘 |
| **依赖** | 只需 Claude + 数据源 MCP + 一份 roster | Markdown vault + hook + 跨会话状态 |
| **价值** | 即开即用——**单次就有用** | 累积、可复盘、决策学习闭环——**几天/几周后复利** |

**怎么选**：说"快速简报 / 试一下"→ 🅱️；说"完整版 / 跑日报"→ 🅰️；没说 → 看 `KOL_VAULT` 是否设置（设了 🅰️，没设 🅱️ 并一句话告知"想长期累积可配 vault"）。

**🅱️ 精简流程**：Step 1（定窗口，默认近 24h）→ Step 2（拉满 roster + 覆盖表）→ Step 3（窗口过滤）→ Step 4-7（识别 / 报价 / 持仓信号 / 共识 / 板块 / 每账号深度）→ Step 9（综合判断）→ 直接在对话里输出简报：

```
# 快速简报 — <窗口>
## 覆盖：N/N（✅/⚪/❌ 账号覆盖表）
## TLDR：1-3 条最重要
## 持仓信号（仅当用户当场报了持仓）
## 跨账号共识主题（每条带 @账号 + UTC + URL + verbatim 要点）
## 板块强度速览
## 决策摘要（lite）：持仓 posture + 重点关注标的（带依据，不喊单）
## 每账号亮点
```

**🅱️ 跳过**：Step 0.0/0 的 vault 相关、Step 9.6 合并协议、Step 10 全部落盘、10.7-10.95、`_last-pull` 更新。
**🅱️ 仍然遵守**：拉取覆盖门禁 / 不编数字 / 数据带源 / 不替用户决定（买卖意图仍在对话里跑 Pre-Trade 5 gate）/ 持仓信号需用户当场口头报持仓 / 明确告知"本次不落盘"。

---

## 🔧 配置（🅰️ 首次必做）

1. **vault 路径**：`export KOL_VAULT="/path/to/your/vault/Stock-Watch"`，下文用 `$VAULT` 指代。
2. **roster**：内置 5 人公开参考 starter（[references/account-roster.md](references/account-roster.md) 顶部，⚠️ 示例非推荐），可即刻跑；建议尽快换成自选的 8-15 个（**自带多空冲突，别全员看多**）。
3. **数据源**：参考实现用 `mcp__followin__*`（推文/行情）。换别的推文/行情 MCP 把对应调用替换即可，方法论不变。
4. **（可选）收尾门禁 hook**：把 [scripts/daily-gate-check.sh](scripts/daily-gate-check.sh) 配成 Stop hook，机械校验落盘。

---

## 🔒 铁律（违反 = 当次产出不可信）

1. **不喊单、不预测价格、不替用户做买卖决定**。KOL 喊了就引用带源，自己不背书。"我的仓位"数量/成本只按用户报的记，不主动改。不删旧日报。
2. **不编数字**：所有具体价格/数量/阈值/百分比必须带 `[数据]` 或 `[原则]` 来源标签；没依据 = 只给定性方向，或直说"不知道，取决于你的风险承受能力/时间窗口/现金头寸"。
   | ✅ 允许 | ❌ 禁止 |
   |--------|--------|
   | "回调到 50d MA $X [数据源] 建仓" | "回调到某价位建仓"（拍的数）|
   | "TRIM 使仓位回到 30% [集中度原则]" | "TRIM 2 股"（拍的数）|
3. **数据带源**：每条引用必带 UTC 时间戳 + 账号 + 原推 URL，否则无法回头验证。
4. **剥离废话**：段子/鸡汤/纯情绪/纯转发吐槽/商业推广不入正文；拿不准倾向剔除，宁缺毋滥。
5. **重大事件后等完整数据**：财报/政策/黑天鹅后第一次拉的可能是初期反应——1h 内再拉一次完整区间（day high/low/close），双源交叉验证，不 single snapshot 下判断。
6. **全量拉取**：默认拉满整个 roster，不许挑几个核心账号代替（详见 Step 2 门禁）。

**MCP 路由**（参考实现；⚠️ 调用签名**只写在各 Step 执行现场，一处维护**）：推文 → Step 2；报价 + 目标价 → Step 5；外部共识对照 → Step 6.6。

⚠️ **两个 schema 级坑，对所有 metrics 调用生效（实测，照直觉传参会直接失败）**：
1. **数组参数会被 schema 拒**（`keywords=[...]` / `categories=[...]` 报 `has type "string", want array"`）→ **一律走 `query` 字符串**。
2. **只写 ticker 会路由到 fundamentals 拿不到价格**（返回三表+估值，无 price 字段）→ query 里**必须带 "live stock price quote" 这类明确意图词**。

---

## 落盘结构（🅰️）

```
$VAULT/
├── Daily/YYYY-MM-DD.md        <-- 日报（两区结构，日内多批合并）
├── Daily/Daily-Index.md       <-- 日报 TLDR 索引（30 秒回查，唯一 TLDR 落点）
├── Portfolio.md               <-- 持仓总览 + 挂单小表 + Risk Budget
├── Macro.md                   <-- 宏观红灯监控（喂 Pre-Trade gate #1）
├── Decisions-Journal.md       <-- 决策日志（含 1w/1m/3m 回顾）
├── Pre-Trade-Checklist.md     <-- 买卖前 5 项 gate
├── references-roster.md       <-- 你的关注名单（Step 2 从这读）
├── Tickers/*.md               <-- 个股累积笔记
├── Sectors/*.md               <-- 板块累积笔记
├── Sectors/_Sectors-Index.md  <-- 全板块覆盖清单 manifest
├── Weekly/YYYY-W##.md         <-- 周报（5 节）
└── _last-pull.md              <-- 窗口状态（防断档）
```

种子结构见 [references/vault-skeleton.md](references/vault-skeleton.md)（8 个种子文件）。

---

## Roster

**🅰️ 从 `$VAULT/references-roster.md` 读名单；🅱️ 用用户当场给的名单。** skill 自带的 [references/account-roster.md](references/account-roster.md) 是方法论模板 + starter，不是某人的真实名单。

- 默认拉满整个 roster。用户说"加 XX / 去掉 YY"→ 本次运行调整，询问是否更新 roster 文件（不主动改）。
- **认知冲突对**（同一标的强多 vs 强空的两个账号）= 高信号，遇到必成对拉，不许只拉一边就给定调。
- 建名单 / 评级 rubric / 画像方法 / 何时增删 → [references/account-roster.md](references/account-roster.md)。
- **评级/画像 = 周维度**（周报时做，日频绝不动评级；日频只累积事件）。

---

## 时间窗口

- **默认按用户本地自然日切分**（设你的时区）：一份 `YYYY-MM-DD.md` 覆盖本地 0:00→24:00，一天多次拉取都合并进同一份（Step 9.6）。
- **窗口下界从 `_last-pull.md` 读，不手动估**（Step 1 / P3）。
- 用户说"拉 12h / 最近一周"按指令。周末/节假日数据稀薄，跑前提醒。
- **闭市/瘦窗口也要拉**：预期产出少 ≠ 不拉（非交易时段 KOL 仍在发推，且常是深度长文时段）。

---

## 工作流（按顺序）

### Step 0.0 — 首次初始化（🅰️ 首次运行必做）

**触发**：`$KOL_VAULT/Portfolio.md` 不存在（或用户说"初始化 vault"）。
1. 建目录 `$KOL_VAULT/{Daily,Tickers,Sectors,Weekly}`。
2. 按 [references/vault-skeleton.md](references/vault-skeleton.md) 创建 8 个种子文件（空骨架，今日 mtime——否则门禁 hook 第一天就拦死）。
3. 问用户：**持仓（标的/成本/数量）+ 现金口径（⚠️ 含货基/近现金）+ roster + 时区**，填 `Portfolio.md` 和 `references-roster.md`。
4. `_last-pull.md` 的 `last_cutoff_utc` 设为"现在 − 24h"。

### Step 0 — 开局扫描（每批必做）

```bash
cat "$VAULT/Portfolio.md"                              # 持仓权威源（数量/成本/现金）
grep -l "我的仓位" "$VAULT/Tickers/"*.md               # 有仓位记录的 ticker（与 Portfolio 交叉核对）
ls "$VAULT/Sectors/"*.md                               # 已建板块
grep -E "回顾.*prompt" "$VAULT/Decisions-Journal.md"   # 决策回顾到期
```

> ⚠️ **持仓以 `Portfolio.md` 持仓总表为准**，Ticker 的「我的仓位」段是分标的流水（两者对不上 → 当场问用户，别自己挑一个信）。

- 到期未填的回顾 → 日报顶部加"📅 今日决策回顾提醒"（不强制立刻填，只提醒）。
- **P7 回顾必反哺**：某条回顾被填（用户给"对/错+为什么"）→ 强制三连：① 更新该决策回顾字段 + 标 ✅/❌/⚪；② 新教训 → 更新「决策模式归纳索引」；③ 涉及"下次先检查 X" → 写进 Pre-Trade-Checklist 对应 gate。
- **P1 仓位对账**：每批开头问一句"**持仓有变动吗？**"；每周末贴完整持仓表逐行确认。持仓/成本只来自用户口头告知——成交忘说 = 浮盈/占比/thesis 全链静默错。**现金口径必须完整**（含货基/账户外现金）；🔴 **分母没核实 = 不报 Risk Budget 红线 %**，只给定性 + 标"待确认"。

### Step 1 — 参数 + 窗口（P3）

指令模糊（"跑一下 KOL"）→ 一句话确认窗口和名单；明确说"跑/补一下/按默认"→ 直接执行。
**P3**：读 `_last-pull.md` 的 `last_cutoff_utc` = 窗口下界；窗口 = [它, now]；`>36h` → 日报标"⚠️ 断档 Nh"。跑完 Step 11 必更新 `_last-pull.md`——**只存机器状态 4 行 + 窗口历史表，❌ 不写批次 TLDR**（TLDR 唯一归宿 = `Daily-Index.md`；同一段话写两处必然漂移）。

### Step 2 — 并行拉取（整个 roster）

```
mcp__followin__twitter(action="user_tweets", user_name="<handle>", include_replies=false)
```

全部账号**并行调用**。返回 JSON 常超 token 限制被落盘到 tool-results——正常现象，不要重试；3 个以下账号失败 → 只重试这几个。
⚠️ **配额意识**：`twitter` 调用有月度配额（返回的 `meta.quota` 里有 `used/limit/remaining`，实测某账户 limit=2500；`metrics` 近乎无限）。每批消耗 ≈ roster 数 + 翻页数，`remaining` 低于当月预估用量时提醒用户，别默默烧完。
**P2**：roster 里最高质量的几个 A+ 账号用 `include_replies=true`（alpha/反方常在回复里），回复条标 `[reply]`。

⚠️ **P2.5 — 一次调用只返一页（实测 20 条），必须处理翻页**：高产账号或宽窗口（断档补拉）时，这 20 条**盖不住整个窗口**，剩下的会被**静默漏掉**——覆盖表照样显示"✅ 已拉 N 条"，看不出缺口。
- Step 3 的脚本会机械检测并告警（"本页最早一条仍晚于 cutoff"）。
- 见到告警 → 对该账号用返回里的 `next_cursor` 再拉一页，直到最早一条早于 cutoff，把多页 dump 一起喂给脚本（跨文件自动去重）。
- **这条不能省**：账号级覆盖门禁保证"每个账号都拉了"，保证不了"每个账号的窗口都拉全了"。

#### 🚪 拉取覆盖门禁（⚠️ 强制）

> 落盘门禁只保证"拉到的都写了"，保证不了"该拉的都拉了"。输入端的漏更隐蔽——日报看起来完整，实际单边信息。

- **默认拉满整个 roster**，除非用户明确说"只看 X"。
- 列**覆盖表**，每个账号显式标 ✅ 已拉 / ⚪ 已拉无信号 / ❌ 拉取失败，**不许有账号缺席**。A+ 账号漏拉零容忍。
- **来源可追溯**：引用某账号 = 本次必须有实际 `user_tweets` 调用；用户手动喂的标 `[用户提供，非当日拉取]`。
- ⚠️ **search ≠ 拉取**：`twitter search` 只作补充，绝不替代 user_tweets 全量（`$cashtag` 检索对不带 $ 标签的中文 KOL 系统性失效）。
- 认知冲突对必须成对拉。

### Step 3 — 过滤时间窗口（固化脚本，禁内联重写）

```bash
python3 ~/.claude/skills/stock-kol-watch/scripts/filter_tweets.py \
    --cutoff <last_cutoff_utc> --out /tmp/digest_<日期批次>.txt <dump 文件...>
```

脚本递归找 tweet 对象 → 按 `author.userName` 多数票识别主账号 → 过滤去重（**跨文件共享**，同账号被重试成两个 dump 不会重复）→ 每条带 UTC+本地双时戳 + `[RT]/[QT]/[reply]` 标记 + URL → stderr 输出每账号计数（直接喂覆盖表）。
- 第二时戳默认用**本机时区**；跑在别的时区（如服务器 UTC）想要固定口径 → 加 `--tz-offset 8 --tz-label SGT`。
- **`[QT]`/`[自引 QT]` 标记要认真读**：实测宏观类账号 7-11 成的推文是引用推——被引原文是数字的出处（"同源不是共识"靠它判），**自引**则是该账号在回看自己早先的判断（跨批验证/改口的最强信号）。没有标记的才是纯原创。
- schema 变了改脚本本身（`find_tweets()`/`parse_dt()`/`dedupe_key()`/`mark_of()`），别回退内联重写。

**📦 digest 太大就外包深读**：实测每条推文均值 ~1.5K 字符，**8-15 个账号的 24h digest ≈ 9-17 万字符（3.5-6.7 万 token）**——主 agent 全读会吃掉一大块上下文。
**规则（单一阈值，别留空档）**：digest **>20K 字符 → 派 1 个 reader 子代理**做逐条提炼，主 agent 不读全文（契约见 [references/advanced-extensions.md](references/advanced-extensions.md) §4）；**≤20K 主 agent 直读**。拿不准就派。**裁决/落盘不可外包**，落盘前抽查 3 个关键数字回 digest verbatim 核对。
（实测参考：5 账号 / 19 条 / 22.8h 窗口 = 21.5K 字符——**5 个账号就已过线**。）

### Step 4 — 识别投资内容

**保留**：`$TICKER` cashtag / 基本面·技术面·催化剂·估值 / 相关宏观（监管、降息、ETF）/ 供应链非美股标的（作"延伸标的"放共识，不单独建 ticker）。
**剔除**：段子 / 鸡汤 / 纯情绪 / 纯 RT 无评论 / 推广 / 无关内容（如加密交易所安全事件之于美股辖区）。
⚠️ **赞助推文不等于推广贴**：实测遇到"完整宏观分析 + 文末一行 `本条由@XX赞助`"——**内容照收，但必须标注赞助方**（利益相关是打折项，读者要知道）。整条就是广告才剔除。
⚠️ **自吹型自引**（"我早说过了/我给你们指明了方向"）无新增论据 → 剔除，但**原始论点若在窗口内另有原帖，收原帖**。

### Step 5 — 提取标的 + 抓报价

```
mcp__followin__metrics(query="<TICKER> live stock price quote", asset_type="tradfi", verbosity="concise")
```

`asset_type="tradfi"` 必传；多 ticker 单调用并行，不要 batch。返回 `price / change / open / previousClose / dayHigh / dayLow / yearHigh / yearLow / marketCap / volume`。

⚠️ **三个必踩的坑（全部实测过）**：
1. **`change` 是绝对美元，不是百分比**。实测 META `change: 31.13` / `previousClose: 556.71` → 真实涨幅 **+5.59%**，不是 +31%。**涨幅要自己算** `change / previousClose`，直接把 `change` 当 % 报出去 = 编数字（违反铁律 2）。
2. **KOL 会打错 cashtag**。实测 `$APPL`（苹果实为 AAPL）查询返回 `total: 0`、空 results。**看到 0 结果先怀疑代码拼写**，标"代码存疑，未取到数据"，**不要拿相似公司的价格顶替**。
3. **同名 crypto token 劫持**（LITE≠Litecoin）→ query 带公司全名。仍失败 → 标"暂无数据"，**不编**。

**持仓标的额外**：另发一次 `query="<公司全名> analyst price target"` 取 consensus PT（返回 `targetConsensus/High/Low/Median`）。⚠️ consensus 只给当前聚合数，不含各家 PT 日期。

### Step 5.5 — 持仓标的特别处理

持仓标的**共识阈值降为 1**（单账号提及也保留），逐条标操作信号：

| 信号 | 触发 |
|------|------|
| 🟢 加仓 setup | 新增独立账号验证 / 新催化剂 / 数据超预期 |
| 🟡 观察 | 接近 52w 高/关键阻力 / 共识拥挤 / 板块轮动 |
| 🟠 减仓 | 原 thesis KOL 止盈转口风 / 反方独立账号入场 / 数据证伪 |
| 🔴 止损 | 核心 thesis 破裂 / 基本面恶化 / 黑天鹅 |

每个信号带账号 / UTC / URL / 原话片段。**只摆信号，不做决策**。

> 想要第三方深度层（实盘仓位源 / 卖方评级 ingest / 独立研究 ingest）→ [references/advanced-extensions.md](references/advanced-extensions.md)，核心版不跑。

### Step 6 — 跨账号共识主题

找 **≥2 独立账号**讨论同一标的/主题。每个主题：时间正序引用（UTC + 账号 + URL + 论点）+ 标直接论点 vs 间接论据 + 综合判断（共识强度 强/中/弱 + 风险点）。
⚠️ 多账号引用同一份机构数据 = **同源不是共识**（看首发时间）。

### Step 6.5 — 板块识别

自下而上聚类。触发（任一）：≥2 KOL 讨论同一概念 / ≥3 只同类标的 ±5% 波动 / 当日板块级 catalyst。
**评级**：🟢🟢 极强（龙头 +10%+ / 多源 / 硬 catalyst）｜🟢 强（龙头 +3-10% / ≥2 KOL 看多）｜⚪ 平｜🔴 弱（龙头 -5%+ / 系统性做空信号）。
维护 `Sectors/_Sectors-Index.md` manifest；**建档标准**：A 用户持仓该板块 → 必建；B 7 天内 ≥3 条独立硬信号（不同源）且覆盖 ≥2 标的 → 建；不到阈值只记 Daily + index 标注，不建空文件。硬信号 = KOL 主动观点 / 卖方评级变动 / 财报 / 政策并购事件，**纯价格波动不算**。

### Step 6.6 — 🪞 回音室检测（持仓 + 重点关注标的）

> **为什么进核心**：roster 是你自己挑的，**最危险的失效是它悄悄变成全员看多**（starter roster 就有这个缺口）。Step 6 的"跨账号共识"只能证明**你名单内部**一致，证明不了名单外也这么看。这一步用一个外部 KOL 池做机械对照。

```
signal(query="<TICKER> consensus", asset_type="tradfi", verbosity="concise")
```

返回 `bullish_count / bearish_count / neutral_count / total_posts` + `top_calls` 板（当前最被提及的标的及其多空分布）。

**怎么用**：
- **roster 一致 + 外部池也一致** → 共识确实广泛，但**要警惕 priced-in**（配合"52w 高位共识常已 priced-in"那条坑）。
- **roster 一致 + 外部池有明显反方** → 🔴 **你的名单有盲区**，去把反方观点找出来读，别直接采信自己名单。
- `top_calls` 里出现你没覆盖的标的 → 观察池候选。

⚠️ **三条使用纪律**：
1. **不能当独立信源计数**：这个 KOL 池与你 roster **可能重叠**，无法核实 → 只作**方向性对照**，不写成"N 个独立源确认"（同源计数是 F13）。
2. **看绝对值不看比率**：实测出现过 `bull_bear_ratio: 19` 而 `bearish_count: 0` —— 分母为 0 的比率没有意义。**报 `19多/0空/20帖`，不报 "19 倍"**。
3. **样本量必须一起报**：20 帖的 19:0 和 500 帖的 19:0 不是一回事。`total_posts < 20` 时标"样本薄，仅供参考"。

### Step 7 — 每账号深度 ⚠️ 强制逐条展开

**绝不允许"一句话画像总结"**。每个账号：
1. 画像（本期，1-2 句对比上次变化）
2. **干货逐条**：1️⃣2️⃣3️⃣ 每条有信息量的推文单独展开（UTC/链接/bullet 要点/保留所有数字术语）
3. 废话明确标"→ 跳过"
4. 信号质量 A+~D + 升降
5. 可跟进 item

长度参考：A+/A 级 800-2000 字；B 级 400-1000 字；C 级 100-300 字（瘦窗口按实际内容缩放，不硬凑）。

### Step 9 — 综合判断

信号质量排序 / 新增观察池标的 / 多空交锋 / 板块强度 ranking。

### Step 9.6 — 🔁 日内多批合并协议（🅰️ 落盘前必读）⚠️ 强制

> 一天拉 2-3 次，若把"新信号"和"当前状态"混着 append，会叠成层层补丁、自相矛盾。根因：状态和事件没分区。

**日报分三区，不同合并动作**：

| 区 | 内容 | 动作 |
|----|------|------|
| **🟦 分析层（顶部）** | TLDR / 持仓（价/浮盈/新信号/健康度/Posture）/ 决策摘要 / 观察池 / 关键多空分歧 / 板块强度 | **OVERWRITE 到最新**，不留旧值 |
| **🟨 事件流（中部）** | 信号按批次分块（每账号深度+共识） | **APPEND 新批次块**，只写本次净新增 |
| **📋 元信息（底部）** | 批次表 / 账号覆盖表 / 收尾门禁 | OVERWRITE；门禁标记必留 |

**合并 6 步**：① 读 `_last-pull` 定窗口 → ② 全量拉（Step 2 门禁）→ ③ 事件流 append `### 批次#N — HH:MM` 块（与既有批次去重）→ ④ 状态区 OVERWRITE 成当前值 → ⑤ **矛盾处理**：新数据推翻旧结论 → 状态区直接改（不留旧值），事件块记一行 `🔧 修正：X 从 A→B（原因）`——**绝不在状态区留两个矛盾值** → ⑥ 更新批次表 + `_last-pull` + `Daily-Index` 当日行。

**铁律**：状态区只有"现在"没有"曾经"；同一信号只在首次批次写一次；事件流按批次 append 天然有序。

**📎 多批次小贴士**：① dashboard 顶部日期快讯条**只留最新 1 条**（历史 TLDR 归 Daily-Index，同一事实写 N 处必然漂移）；② 瘦批次（价格没动/无新建文件）少写不少拉——状态区只 OVERWRITE 有实质变化的小节；③ 事件流太长可把历史批次折叠进 `<details>`（`<summary>` 后空一行）。

### Step 10 — 落盘（3 层）

> ⚡ **提速铁律**：不同文件的 Edit/Read 同一条消息并行发（满落盘应是 2-3 个并行批次，不是十几次串行往返）；先 Read 再 Edit；报价等数据拉取一个并行批次发全。

**A. 主日报** `Daily/YYYY-MM-DD.md`——按 [references/output-templates.md](references/output-templates.md)。
**B. 每标的** `Tickers/<TICKER>.md`——不存在则按模板创建；存在则价格快照追加一行 + KOL 观点追加新日期小节 + **不动"我的仓位"段**。frontmatter 必须有 `sector: [[Sectors/<板块>]]` 反链。
**C. 每板块** `Sectors/<板块>.md`——满足任一必更新（不只是日报里写一笔）：① 当日板块汇总出现 ② 用户对该板块标的有买卖 ③ 重大 KOL thesis/反方 ④ 代表标的财报/事件。必更新段：强度评级历史追加一行 / thesis 追加 / 代表标的价格 / 反方信号（不删旧）。

### Step 10.5 — 决策摘要（日报 Part 6）⚠️ 强制

**A. 持仓策略表**：标的 / 浮盈亏 / 多空源数 / Posture / 触发升级 / 触发降级 / 关键价位。
Posture（7 选 1）：🟢 ADD / HOLD-conviction｜🟡 HOLD-attention / TAKE-PROFIT-watch｜🟠 TRIM / RE-EVALUATE｜🔴 EXIT-watch。
**B. 重点关注标的（未持仓）**：2-3 个排序 + 理由 + 触发买入条件。
**C. 跨标的协同 / 换仓建议（如有）。**
⚠️ 每个 trigger / 触发价 / 数量必须带 [数据] 或 [原则] 依据。

### Step 10.6 — 板块汇总（日报 Part 7）⚠️ 强制

每板块：当日强度 [评级 + 数据依据] / 关键催化（KOL 引用 + 数据点）/ 用户持仓连带（直接/间接/无）/ 反方信号。日报写当日快照，Sectors/ 累积跨日演变。

### Step 10.7 — 周报（周末，5 节）

周六/周日 + 本周 `Weekly/YYYY-W##.md` 不存在 → 问"要不要跑本周周报？"。

1. **持仓与板块演变**（本周价格/信号/thesis 变化）
2. **KOL 行为**（口风转变 / 关键 call / 事件日志追加）
3. **账号评级 review**（⚠️ 评"信号质量"非胜率；评级变动需用户确认；画像按 [references/account-roster.md](references/account-roster.md) 5 维精修）
4. **决策质量复盘**（P7：到期回顾对/错 + 模式命中——评用户决策，不评 KOL 胜率）
5. **下周日历 + 周策略**

开头先做 carry-over 检查（上周 open loops 是否关闭）。

### Step 10.8 — 衍生状态校准（每批最后）

1. 持仓现价 + 浮盈重算（Ticker 价格快照追加 + Portfolio 更新，含挂单小表 trigger 距离）
2. Risk Budget 占比重算（单标的/单板块/现金 ratio）→ 突破红线 → 警报进决策摘要
3. Sectors 强度按当日走势 + thesis + 反方重评，追加评级行
4. Macro 红灯重检（利率/VIX/DXY/行业 ETF）
5. `Daily-Index.md` 追加当日行 TLDR（日期/关键事件/用户决策/价格节点）

### Step 10.9 — 🚪 收尾门禁 ⚠️ 强制

> 写完日报容易当成终点，漏掉 Sectors / Ticker。本门禁把"逐文件确认"变成强制最后一步，用 mtime 实测代替"我以为写了"。

跑完 Step 10 + 10.8 后，逐项 `ls` mtime，当日有信号的文件 mtime 必须=当天：

| 类别 | 判定 |
|------|------|
| 持仓 ticker | 有价变/新信号 → mtime=当天；确无 → 汇报点名"X 无新信号故未改" |
| **Sectors 全板块扫描** | 逐行过 `_Sectors-Index`，每行落 ✅已更新 / ⚪无信号 / 🆕有信号未到建档阈值，**不许沉默跳过**。日报底部写机器可读声明 `<!-- sector-sync: 板块A, 板块B -->`（**逗号分隔**，无则 `none`；文件名带空格的板块必须用逗号）——hook 逐个验声明文件 mtime。⚠️ 只改 index 日期 ≠ sweep |
| dashboard | **Daily-Index / Macro 每批必更新**；**Portfolio 仅在有持仓时必更新**（Step 10.8 要重算现价/浮盈/Risk Budget）。无持仓的用户 Portfolio 没东西可改，hook 不强制——**别为了过门禁去 touch 空文件** |

**硬规则**：漏掉 ≠ 判定无信号——每个持仓 ticker + 相关 Sector 都必须被显式 touch 一次思考；mtime 实测优先于记忆；写不进时建桥接文件 `Tickers/_<标的>-待补-<日期>.md` 标红"待补"。
配了 hook 的，结束会话时 `daily-gate-check.sh` 会机械复核这一切。

### Step 10.95 — 🔬 完整性审查 critic — 条件触发

> 门禁只查"文件碰没碰"，查不了"dump 里每条材料是否都被提炼对"。本 pass 补提炼正确性。

**✅ 派 subagent**：当日首个完整拉取 / 财报·政策事件日 / 新建 ≥1 ticker 或 sector / 信号量大。**⏭️ 内联自查**：同日瘦增量批（主 agent 对照 dump 与落盘扫一遍，汇报"内联自查 0 遗漏"）。拿不准 → 派。

spawn prompt 用 [references/critic-prompt.md](references/critic-prompt.md) 模板填空。任务：反扫 dump 列全部材料信号 → 对照落盘找遗漏（特查：非持仓板块信号 / 反方信号 / 被一句带过的数字）+ P4 一致性（同一事实在 Daily/Portfolio/Ticker/Sector 四处一致）+ P9 数字抽查（4-6 个回 dump verbatim 比对）+ 板块同步交叉校验。
遗漏非空 → 补落盘 + 再跑门禁；为空 → 汇报"完整性审查：0 遗漏"。

### Step 11 — 简短汇报

- 拉了 N 账号 / 过滤后 M 条；共识 X 个 / 标的 Y 个 / 板块更新 Z 个
- **⭐ 开头置顶「本批最重要 1-3 条」**（最强信号 / 最大分歧 / 最有反向转向——用户只看一行就看这个）
- **⚡ 明确交易决策类推文单列**（买卖/加减仓/止损/挂单，带账号+原话+价位+实盘 or 口头）；无则显式写"本批无"
- 门禁结果逐项（已更 / 判定无信号点名 / 待补标红）+ 落盘路径
- 不把全文复制到对话。

---

## 🛑 用户表达买卖意图时（Pre-Trade Checklist）⚠️ 强制

**触发**：用户说"我想加仓 X / 考虑止损 Y / X 现在能买吗"（**还没执行**）。
**必做**：先跑 Pre-Trade-Checklist 5 项 gate（① Macro 红灯数 ② 板块强度 vs 5 天前 ③ thesis KOL 是否仍多 ④ Risk Budget 红线 ⑤ 决策模式归纳 + 反向 prior 5 问）。每项给 🟢🟡🔴 + 建议。
**绝不允许**跳过 checklist 直接给"加仓 X 股"建议。**允许**列完整状态后让用户自己决定；用户在 🔴 下仍执行 → 记录到 Decisions-Journal。

## 用户仓位变动追踪

用户告知买卖（"买了 X N 股 @ Y"），立即：① `Tickers/<X>.md` "我的仓位"追加一行 ② `Portfolio.md` 持仓总表 ③ 对应 `Sectors/<板块>.md`（用户暴露/评级/thesis）④ `Decisions-Journal.md` 新增决策 #N（含 1w/1m/3m 回顾 prompt）。完成后 `ls -la $VAULT/Sectors/*.md` 确认相关板块当日更新过。

## 止损 policy 框架

用户问"X 给我个止损策略"——**不能编百分比**。可选 trigger 类型：① 技术位（52w 低/关键 MA）[数据] ② KOL 信号（原 thesis KOL 撤回/转空）[数据] ③ 基本面（财报 miss/重大监管）[数据] ④ 板块同步性（单独跌+板块未跟 = momentum 破位；板块同步跌 = 系统事件）[数据]。
多触发组合：第一破减半 / 第二破全出 / thesis 源出局全出。落 `Tickers/<X>.md` 形成 v1/v2/v3 累积版本。

---

## 容易踩的坑（速记）

- "NOW" 是 ServiceNow 不是副词——ticker 提取看上下文。
- **KOL 打错的 cashtag**（实测 `$APPL` ≠ AAPL）——查询返回 0 结果时先怀疑拼写，别拿相似公司顶替。
- **行情返回的 `change` 是美元不是百分比**——涨幅自己用 `change/previousClose` 算（实测 META 31.13 → +5.59% 而非 +31%）。
- 同作者一天 5+ 条同标的 = 叙事完整但无独立验证，标"集中输出待验证"。
- 账号改口（几小时内翻向）单独标注——比观点本身更有信息量。
- 52w 高位的 KOL 共识常已 priced-in。
- IPO 新股无技术分析（"52w 低"就是上市以来低点）。
- 个股单独跌+板块未跟 = momentum 破位；板块同步跌 = 系统事件——决策含义相反。

> 📚 完整失效模式库 → [references/failure-modes.md](references/failure-modes.md)：19 个实跑踩过的坑按"症状→根因→修法"归档，本框架多数"⚠️ 强制"规则的出处都在里面。

## 不做什么

- 不喊单、不预测价格、**不编数字**（带 [数据]/[原则] 标签是硬约束）。
- 不替用户更新仓位表（除非用户告知）。不删旧日报。

## 进阶扩展

用顺手了想加层 → [references/advanced-extensions.md](references/advanced-extensions.md)：7 节——实盘仓位源 / 卖方研报 ingest / 独立研究 ingest / digest 深读外包 / RT-QT 候选挖掘 / 归档审计 / 一条实测否决项（trader_position）。每节含"是什么 + 怎么加回来 + 节奏建议 + 实测陷阱"；**各层的节奏与参数不在此镜像，唯一权威在那个文件**。
