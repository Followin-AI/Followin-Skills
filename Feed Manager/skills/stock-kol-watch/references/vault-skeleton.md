# Vault 骨架 — 首次初始化种子文件（8 个）

> 🅰️ 旗舰版**首次运行必做**：SKILL 引用的这些文件若不存在，按下面的种子结构创建（空骨架即可，内容随后跑日报填充）。
> **没有这一步，收尾门禁 hook 会因为这些文件不存在而第一天就拦死你**（mtime 检测不到 → 全部判过期）。
> 创建后由流程更新；用户买卖动作触发 Decisions-Journal / Portfolio 更新。

所有文件落在 `$KOL_VAULT/` 下（`Daily/` `Tickers/` `Sectors/` `Weekly/` 为子目录）。

---

## references-roster.md — 你的关注名单（🅰️ 模式从这里读 roster）

```markdown
---
type: roster
updated: YYYY-MM-DD
note: 你的关注名单。starter + 建/评/养方法见 references/account-roster.md。
---
# 我的关注名单（roster）

| 账号 | 模块 | 档位 | 备注/独特 alpha |
|------|------|------|----------------|
| @你的账号1 | 半导体 | A+ | ... |
| @你的账号2 | 宏观 | A | ... |

> 至少保留 1-2 个稳定唱空/质疑的账号，避免全员看多。
```

## Portfolio.md — 持仓总览（含挂单小表 + Risk Budget）

```markdown
---
type: portfolio-dashboard
updated: YYYY-MM-DD
---
# Portfolio Dashboard
## 持仓总表
| 标的 | 名称 | 板块 | 数量 | 成本均价 | 现价 | 市值 | 浮盈/亏 | % |
|------|------|------|------|---------|------|------|---------|---|
## 📋 挂单/待触发（如有）
| 标的 | trigger [依据] | 当前价 | 距离 | 状态 |
## 💰 现金（⚠️ 含货基/近现金，算 Risk Budget 的分母）
| 项目 | 金额 | 占组合 |
| 现金 | $0 | — |
| 货币基金/近现金 | $0 | — |
| 组合总值 | $0 | 100% |
## ⚠️ Risk Budget 红线
| 维度 | 当前 | 红线 | 状态 |
| 单标的最大 | — | ≤30% | — |
| 单板块最大 | — | ≤35% | — |
| 现金 ratio | — | ≥20%(事件密集期) | — |
```

## Decisions-Journal.md — 决策日志（决策学习闭环核心）

```markdown
---
type: decisions-journal
updated: YYYY-MM-DD
---
# Decisions Journal
> 每个买卖决策记录 why + 情绪 + 替代选项 + 事后回顾。回顾段当时不填，到期才填。
## 📑 决策模式归纳索引（长期累积，回顾反哺）
1. （模式名）—（触发条件）—（历史命中）
---
## #N <标的> <操作> <日期>
- **决策**：买/卖 X 股 @ $Y
- **why**：thesis + 信号源
- **当时情绪**：
- **替代选项**：
### 1 周后回顾（YYYY-MM-DD prompt）  ← 到期填，标 ✅对/❌错/⚪未定
### 1 月后回顾（YYYY-MM-DD prompt）
### 3 月后回顾（YYYY-MM-DD prompt）
```

## Pre-Trade-Checklist.md — 买卖前 5 项 gate

```markdown
---
type: pre-trade-checklist
trigger: 用户表达买卖意图时，先跑完此 checklist 再 act
---
# Pre-Trade Checklist — 操作前 gate
## 🛑 5 项强制检查（任一 🔴 必须暂停讨论再决定）
1. **Macro 状态**：红灯数？（≥3 → 暂停新仓）
2. **板块强度 vs 5 天前**：升/平/降 + 反方是否增多？
3. **thesis KOL 是否仍多**：原 thesis KOL 7 天内仍主动多？
4. **Risk Budget 红线**：操作后是否突破单标的/单板块/现金 ratio？
5. **决策模式 + 反向 prior**：属哪个已有模式？强制 5 问——
   - 买入后 24h 跌 -5% 我会怎么做？
   - 30 天后 thesis 被证伪，最大下行多少？
   - trade 的另一方看到了什么？
   - 这是不是在追涨/杀跌？
   - 若此刻完全空仓，会重新建这个仓位吗？
> 每项给 🟢🟡🔴 + 建议；列完整状态让用户自己决定，不替决定。用户在 🔴 下仍执行 → 记进 Decisions-Journal。
```

## Macro.md — 宏观监控（喂 Pre-Trade gate #1）

```markdown
---
type: macro-monitor
updated: YYYY-MM-DD
---
# Macro 监控
## 红灯监控（每次跑日报重检）
| 指标 | 当前 | 红灯触发 | 状态 |
| 10Y / 2Y 利率 | — | — | — |
| VIX | — | — | — |
| DXY | — | — | — |
| 行业 ETF（如 SOXX/SMH）| — | — | — |
## 事件日历
```

## Daily/Daily-Index.md — 日报 TLDR 索引（唯一 TLDR 落点）

```markdown
---
type: daily-index
update_frequency: 每次跑日报后追加/重写当日行
---
# Daily Index — 日报 TLDR 索引
| 日期 | 关键事件 TLDR | 用户决策 | 价格关键节点 |
|------|------------|---------|------------|
```

## Sectors/_Sectors-Index.md — 全板块覆盖 manifest

```markdown
---
type: sectors-index
updated: YYYY-MM-DD
note: 跑日报 Step 10.9 逐行过，每板块落 ✅已更新/⚪无信号/🆕待建档 三态之一。
---
# Sectors Index — 全板块覆盖清单
| 板块 | 文件 | 状态 | 用户持仓连带 | 最新信号 |
|------|------|------|-------------|---------|
| （你关心的固定板块，逐个列）| ❌待建 | — | — | — |
## 建档标准
A. 用户持仓/挂单有该板块标的 → 必建
B. 7 天内 ≥3 条独立硬信号且覆盖 ≥2 标的 → 建
不到阈值只记 index，不建空文件。
```

## _last-pull.md — 窗口状态（防断档 P3）

```markdown
---
type: pull-state
last_cutoff_utc: YYYY-MM-DDTHH:MM:SSZ
last_pull_local: YYYY-MM-DD HH:MM
last_pull_window: Nh
gap_flag: none
---
# Last Pull State
> 跑日报 Step 1 读 last_cutoff_utc 定窗口下界；跑完 Step 11 更新本文件。
> ⚠️ **只存上面 4 行机器状态**，不写批次 TLDR（TLDR 唯一归宿 = `Daily/Daily-Index.md`）。
## 历史（最近 5 次）
| 拉取时间 | 窗口 | 断档 |
```
