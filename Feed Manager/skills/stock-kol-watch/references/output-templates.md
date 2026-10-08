# 输出模板 — Output Templates

> **三份模板**：日报（按日期）+ 每标的笔记（累积，Tickers/）+ 每板块笔记（累积，Sectors/）。
> 实际内容由 LLM 根据当日数据填充，模板只锁结构和命名。
> ⚠️ 日报实际采用**三区骨架**（状态区 OVERWRITE + 事件流区 APPEND + 底部元信息区 OVERWRITE，见 SKILL Step 9.6）。下面的 Part 编号是内容块的名字，不是标题序号——模板 A 的标题直接写 Part 名。

## 日报固定 Part

```
Part 0.5  持仓监控
Part 1    跨账号共识主题
Part 2    每账号深度（800-2000 字/A+/A 账号）
Part 4    综合判断
Part 6    决策摘要（⚠️ 有持仓时强制；无持仓整段省略）
Part 7    板块/赛道汇总（⚠️ 强制）
```

---

## 模板 A — 日报 `$VAULT/Daily/YYYY-MM-DD.md`

```markdown
---
date: YYYY-MM-DD
type: daily-report
window_utc: ... → ...
roster_coverage: N/N 拉取（✅/⚪/❌）
batches: 1
---

# YYYY-MM-DD 日报

=== 🟦 状态区（OVERWRITE 到最新）===

## TLDR（1-3 条本窗口最重要的）

## 持仓快照（Part 0.5，如有持仓）
| 标的 | 数量 | 成本 | 现价 | 浮盈/亏 | 本窗口信号 | thesis 健康度 |

## 板块汇总（Part 7）
| 板块 | 强度 | 本窗口催化 | 持仓连带 | 反方信号 |

## 决策摘要（Part 6，含 Risk Budget；无持仓整段删掉）

## 外部对照（Step 6.6，可选；没跑就删掉这节；<5 帖写"外部池 N 帖，不作对照"）
| 标的 | roster 内 | 外部池 多/空/帖数 |

=== 🟨 事件流区（APPEND 批次块）===

## 📜 信号事件流
### 批次#1 — HH:MM（窗口 ...）
#### 🔧 校准（如有修正：X 从 A→B）
#### <Part 1 共识主题 / Part 2 每账号深度，每条带 @账号 + UTC + URL + verbatim 要点>
<!-- 跨本地 0 点的批次：前一日的推文写进前一日日报，块名 "### 批次#N — HH:MM（跨 0 点补入，拉取于 <运行日 时刻>）" -->

=== 📋 元信息区（OVERWRITE）===

## 📍 拉取批次（每次拉取追加一行）
| 批次 | 本地时间 | 窗口(UTC) | 覆盖 | 关键新增 |
## 📎 数据来源
## ✅ 收尾门禁
- 账号覆盖：N/M（✅a ⚪b ❌c）—— <逐账号：@x ✅12 · @y ⚪0 · …>
- 完整性审查：遗漏 X · 落盘 ticker T · 落盘 sector S（critic 子代理 / 内联自查）
<!-- sector-sync: 板块A, 板块B --> （逗号分隔更新过的板块文件名；无则写 none）
```

> Part 1（共识主题）/ Part 2（每账号深度）/ Part 4（综合判断）按需嵌入。瘦窗口可精简，但 Part 7 板块汇总**强制**；Part 6 决策摘要**有持仓时强制、无持仓整段省略**。
> 收尾门禁两行是给 hook 机读的，**字段名和格式照抄、字母换成整数**：`账号覆盖` 要满足 a+b+c=M、a+b=N；`完整性审查` 的遗漏必须是 0，T = 本批写过的 `Tickers/` 文件数，S = sector-sync 声明的板块数（`none` 记 0）。照抄占位字母会被拦。

### Part 6 · 决策摘要 ⚠️ 有持仓时强制（无持仓整段省略）

```
A. 持仓策略表
| 标的 | 浮盈/亏 | 多空源数 | Posture | 触发升级 | 触发降级 | 关键价位 |
Posture（7 选 1，与 SKILL Step 10.5 同一套）：🟢 ADD/HOLD-conviction｜🟡 HOLD-attention/TAKE-PROFIT-watch｜🟠 TRIM/RE-EVALUATE｜🔴 EXIT-watch
⚠️ 每个 trigger/触发价/数量必须带 [数据] 或 [原则] 来源。

B. 重点关注标的（未持仓）：2-3 个排序 + 理由 + 触发买入条件 + 与持仓关系。
C. 跨标的协同 / 换仓建议（如有）。
```

### Part 7 · 板块/赛道汇总 ⚠️ 强制

```
每板块：当日强度 [🟢🟢/🟢/⚪/🔴 + 数据依据] / 关键催化（KOL 引用 + 数据点）/ 用户持仓连带（直接/间接/无）/ 反方信号。
板块强度排名（综合）。
用户组合板块暴露 vs 当日板块强势对照表。
```

---

## 模板 B — 每标的笔记 `$VAULT/Tickers/<TICKER>.md`

**新建门槛**（SKILL Step 10.B）：当日 ≥2 位不同 roster 账号提及，或用户持仓/挂单；不够门槛只记在日报里。**首次创建**用完整模板；**已存在**只追加「价格快照」一行 + 「KOL 观点」一节，不动「我的仓位」。

```markdown
---
ticker: TICKER
name: Company Name
exchange: NYSE/NASDAQ
tags: [tag1, tag2]
sector: [[Sectors/<板块>]]    # 该板块文件已存在才写；还没建档就删掉这一行，建档后补上
created: YYYY-MM-DD
---

# TICKER — Company Name

## 价格快照
| 时间 | 价格 | 涨跌幅 | 市值 | 区间(52w) | 前收 |
<!-- 追加新行，不覆盖旧行 -->

## 🎯 目标价追踪 ⚠️ 持仓标的必填

### Consensus Snapshot — YYYY-MM-DD [数据源]
| 来源 | 目标价 | snapshot 日期 | vs 当前 | 含义 |
| Consensus median/high/low | $X | ... | ±N% | ... |
| 52w 高 / 50d MA / 200d MA / 用户成本 | $X | — | ±N% | ... |
> ⚠️ caveat：consensus 只返回当前 aggregated 数字，不返回每家投行 PT 日期。中位数真实性取决于多少家最近 reaffirmed 过。

### KOL 隐性目标 [数据：roster 推文]
| KOL | 日期 | 引用 | 隐含 PT |

### 三档风险信号
| 🟢 加仓 | （带依据的升级条件） |
| 🟡 观察 | （当前价位条件） |
| 🔴 TRIM | （关键 thesis 破裂 OR 跌穿关键 MA [数据]） |

### 下次财报：YYYY-MM-DD（EPS/营收预期 + 看点）

### ⚠️ 数据源误识别处理
如返回 "asset_kind: crypto"（同名 token 误识别，如 LITE≠Litecoin）→ 标"暂无 PT 数据，待手动补"。**不要编 PT 数字。**

> 进阶：每家投行 PT 变动历史 / 评级分布 ingest / 实盘持仓追踪段 → [advanced-extensions.md](advanced-extensions.md)。

## KOL 观点
### YYYY-MM-DD
#### @account
[tweet](URL)
- 引用核心论点（保留数字术语）

## 风险与反方观点
<!-- 累积，新风险加末尾，不删旧 -->

## 我的仓位
> 由用户填入。Claude **不要自动修改**；用户告诉买卖才追加一行。
| 日期 | 操作 | 价格 | 数量 | 备注 |

## 后续追踪
- [ ] 财报 / 事件驱动
- [ ] 验证 KOL thesis 关键数据点
```

---

## 模板 C — 每板块笔记 `$VAULT/Sectors/<板块>.md`

**新建触发**（见 SKILL Step 10.9 建档标准，满足任一才建，避免空文件）。
**已存在**只更新强度评级表 + 追加 thesis + 更新代表标的价格 + 追加 KOL 历史/反方（不删旧）。

```markdown
---
sector: <板块名>
代表标的: A / B / C
代表 ETF: 暂无 / XXX
created: YYYY-MM-DD
status: 🟢🟢 / 🟢 / ⚪ / 🔴
user_position: ✅ 持有 / ❌ 暂无
last_updated: YYYY-MM-DD
---

# <板块名>

## 📖 板块简介 ⚠️ 强制（散户视角，去黑话）
**一句话**：[这板块干什么]
**为什么 AI 时代重要**：[2-3 条产业逻辑]
**散户该懂的术语**（3-6 个，每个 ≤2 行）
**产业链分工**（上游→中游→下游）
**用户怎么参与**：美股标的 / 海外标的 / 观察池
**反方风险**（2-3 条）

## 当前强度评级（按日期，最新在上）
| 日期 | 评级 | 龙头当日 | 关键事件 |
<!-- 每次跑追加一行，不删旧行 -->

## 累积 thesis（跨日，最新在上）
### YYYY-MM-DD — thesis 主题名
[KOL tweet](URL)
- 关键论点 / 数据 / 原话

## 板块代表标的
| 标的 | 价格快照 | 当日 | 用户持仓 | 备注 |

## KOL 提及历史（按时间累积，不删）
## 反方信号（按时间累积，不删）
## 板块催化日历
## 用户暴露（直接 / 间接 / 总暴露占组合 N%）
## 关联板块
## 后续追踪
```

---

## 落盘命令片段

vault 路径（Obsidian）：`obsidian eval code="app.vault.adapter.basePath"`，或直接用 `$KOL_VAULT` 环境变量。
写文件用 Python 处理 UTF-8 + 大段中文更稳：
```python
import pathlib
pathlib.Path(f"{VAULT}/Daily/{date}.md").write_text(content, encoding="utf-8")
```
累积文件（Tickers/Sectors）追加新段可用 `cat >> file <<'EOF'`（注意 heredoc 用单引号防变量展开）。
