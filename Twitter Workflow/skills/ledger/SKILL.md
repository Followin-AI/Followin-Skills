---
name: ledger
description: "把 Twitter Ops 各节点的产出写进飞书多维表格台账，并回读三类查询（7 天撞题查重 / Pattern ≥2 次闸 / P0 落地率与流水线断点）。全仓唯一允许调 lark-cli 的地方。Use this skill whenever another skill needs to persist candidates/angles/tweets/gate results to the Base, or needs 落地率、断点告警、撞题查重、Pattern 命中数, or the user says 写台账, 台账, 落地率, 断点, 日更卡片, ledger."
---

# 台账 ledger — 全仓唯一的 lark-cli 出口

**别的 skill 不许直接调 `lark-cli`。** 一处收敛的理由不是洁癖：写入侧有三条**必须一致**的规则（去重、降级、门禁），
散进四个 skill 就会变成四份实现、四种走样，而且**走样全都不报错**——
写重了不报错、写丢了不报错、门禁挡住了被当成失败放弃也不报错。

> 表结构、字段清单、为什么这么设计 → `docs/internal/twitter-ops-飞书多维表格数据层方案-2026-08-10.md`（对内文档，不在公开仓）。
> 本文件只管**怎么调**。

## 0. 开工前

### 0.1 配置

从 `Twitter Workflow/config.md` 的 `LARK_BASE` 读，**不凭记忆填 token**。

🔴 **`app_token` 留空或仍是 `___` → 整条台账腿跳过**，各节点照常跑、产出照常出，
只在输出末尾加一行「本轮未写台账：LARK_BASE 未配置」。**只 warn 不拦**——
这跟 `LIST_IDS` 是同一处理，别把「能记录得更好」写成「不许跑」。

### 0.2 身份分工（🔴 两条腿别混）

| 场景 | 身份 | 为什么 |
|---|---|---|
| 建表 / 改字段 / 建视图 | `--as user` | 需要 `base:table:*` `base:field:*`，且建出来的东西归属你 |
| **运行期读写记录** | `--as bot` | bot token 不过期，能挂 cron。user 的 refresh token 会过期，**过期时静默断掉** |

bot 能写的前提是**该应用已被加成这张 Base 的协作者（可编辑）**。
这一步只能在飞书界面点，CLI 做不了。没加的话 bot 的写入会被拒，而**读可能还是通的**——
所以别拿「bot 能读」推断「bot 能写」，要验就插一条再删。

### 0.3 时钟

日期一律用调度器传下来的 `$DATE` / `$WEEK` / `$NOW_MS`，**不自己取、不凭模型认知推算**。
理由同 `config.md` §开工四检③。

## 1. 🔴 写入铁律：先查后写

**`+record-upsert` 这个命令名会骗人。** 官方文档原话：

> 有 `--record-id` 就一定更新；不传就一定创建，**不会自动查重或按业务键 upsert**。

**Bitable 没有唯一约束。** 业务键的唯一性 100% 靠这个 skill 自觉。
漏一次的后果不是「多一行」——是把 `performance-review/references/vault.md` 里
担心了一整段的那个 bug（同一条推文重复入库 → 一次偶发爆款被计成 2 次 → 被 `patterns` 的「≥2 次」闸
升格成"稳定模式" → 反哺选题打分）**从 markdown 搬进数据库，而且在数据库里更难发现**。

### 1.1 去重键

| 表 | 去重键 |
|---|---|
| `candidates` | `候选ID` + `扫描日` |
| `angles` | `角度键`（= `候选ID/角度档`，如 `c-0731-03/A`）|
| `tweets` | **`tweet_id`** |
| `patterns` | `Pattern编号` |
| `gate_log` | 不去重，**每次验收都是一行新记录**（打回率要靠行数算）|

### 1.2 标准写入流程

```
① 按去重键查 → +record-list --filter-json   （🔴 不是 +record-search，见 §1.3）
② data.data 非空 → 取 record_id → +record-upsert --record-id <id>   （更新）
③ data.data 为空 → +record-upsert 不带 --record-id                  （新建）
```

查重命令（**实测可用**）：

```bash
lark-cli base +record-list --base-token <T> --table-id <tbl> \
  --filter-json '{"logic":"and","conditions":[["tweet_id","==","<值>"]]}' \
  --format json --as bot
```

### 1.3 三个会让你查错的坑

🔴 **① 查重不能用 `+record-search`。**
它强制要 `--keyword`（**加了 `--filter-json` 也照样要**），而 keyword 是模糊匹配——
查 `123` 会命中 `1234`。**用模糊匹配做去重 = 把不同的记录判成同一条**。用 `+record-list --filter-json`。

🔴 **② 查 `record_id` 不能用 `+data-query`。**
它返回的是**按维度分组的行，不含 `record_id`**。`+data-query` 只用于 §3 那两个聚合 KPI。

🔴 **③ `+record-list` 默认输出 markdown 表格，且 JSON 是列式的。**

两件事，都会让"按常识写的解析代码"当场炸或者更糟——**默默解析出错的值**：

**(a) 默认不是 JSON。** 尽管全局 help 写着 `--format json (default)`，
`+record-list` / `+record-search` 的实际默认值是 `markdown`。**每次都显式加 `--format json`**。

**(b) JSON 是列式的，不是 `[{字段名: 值}]`。** 实测结构：

```
data.data           = [[值, 值, …], …]   ← 每行是位置数组，不是对象
data.fields         = ["tweet_id", "素材等级", …]   ← 列名，按位置对齐
data.field_type_list= ["text", "formula", …]
data.record_id_list = ["recXXXX", …]     ← 🔴 与 data.data 的行按下标一一对应
```

所以取值要 `row[data.fields.index("tweet_id")]`，取 record_id 要 `data.record_id_list[行下标]`。
**`data.data[i]` 里没有 record_id**——先查后写要的那个 id 在另一个数组里，靠下标 zip。
另注意数字类字段（含 `ER` 这类公式）**回读是字符串**（`"0.05"`），要比较大小先转数值。

## 2. 各节点写什么

| 时机 | 写入 | 备注 |
|---|---|---|
| trend-scout 落盘后 | `candidates` 批量 | `部署来源` 必填 |
| 父 Agent / lint 验收后 | `gate_log` 一行 | **通过也要写**，否则算不出打回率 |
| topic-engine 出角度后 | `angles` 批量 + 回写 `candidates.是否P0` / `落地状态=已选题` | |
| tweet-composer 出终稿后 | `tweets` 一行，`tweet_id` 暂空 | |
| 用户确认已发后 | 补 `tweets.tweet_id` + `candidates.落地状态=已发布` | |
| performance-review 回填 | 更新 `tweets` 的五个数据字段 + `回填轮次` | |

批量走 `+record-batch-create` / `+record-batch-update`，但**批量之前仍要逐条查重**（§1.2）。

### 2.1 CellValue 格式

| 字段类型 | 写法 | 坑 |
|---|---|---|
| `link`（`↔候选` `↔推文`）| `[{"id":"<record_id>"}]` | 🔴 **传 record_id，不是记录标题**。要先查到目标记录 |
| `select` | `"选项名"` / 多选 `["A","B"]` | 🔴 **只能写字段里已存在的选项**。写不存在的选项会失败——`标签` `缺项` 这类枚举多的字段尤其容易踩 |
| `datetime` | `"2026-08-11 09:30"` | |
| `formula` / `lookup` / `created_at` | **别写** | 只读。写了会出现在返回的 `ignored_fields` 里，静默不生效 |

## 3. 回读：只有三处

台账的价值在这三处——**光写不读，这套东西就只是个更贵的日志文件**。

**① 7 天撞题查重**（替掉 topic-engine 现在「现拉推文、拉不到记 WARN」）

`+record-list --filter-json`，按 `发布时间` 过滤近 7 天，取 `↔角度` 反查选题。
拉不到照旧记 WARN，**不许当 PASS 划过去**——这条规则不因为换了数据源就放宽。

**② Pattern「≥2 次」闸**

直接读 `patterns.命中推文数`（lookup + counta）和 `状态`（公式）。
🔴 **不要自己再数一遍**。这个字段存在的全部意义就是把数数从模型手里拿走。

**③ P0 落地率 / 流水线断点**（Evose 当初因为没有文件系统砍掉的两块）

```
落地率分母 = candidates 里 是否P0=true 且 扫描日 在窗口内
落地率分子 = 其中 落地状态=已发布 且 关联推文.发布时间 − 扫描时间 ≤ 24h
断裂       = now − max(tweets.发布时间) > 24h
```

走 `+data-query --dsl`。⚠️ 它用的是 **LiteQuery DSL**（`{"type":1,"conjunction":"and","conditions":[{"field_name":...,"operator":"is","value":[...]}]}`），
**跟 `--filter-json` 的 tuple 结构不是一回事**，别把两种语法互相套。

🔴 **checkbox 的 value 要传字符串 `["true"]`，不是布尔 `[true]`。**
传布尔会得到 `failed to parse lite filter`——报错信息只说"语法有问题"，不会告诉你是哪个字段的哪个值，
所以看到这个错先怀疑 checkbox。（`是否P0` 就是 checkbox，落地率的分母全靠它。）

**「≤24h」那一半靠 `candidates.落地小时数`**（两跳链式跨表公式，已建好并实测）：

```
分母：filters = 是否P0 is ["true"]
分子：filters = 是否P0 is ["true"] AND 落地小时数 isLessEqual ["24"]
```

🔴 **写这个公式时踩的坑，改公式前必看：**

**(a) `DAYS()` 实测会截断到整天**，尽管指南写着 "includes decimals"。
30 小时会被算成 24（`DAYS` 返回 1，×24）。**改用日期序列号直接相减**——
Bitable 的 datetime 底层就是带小数的天数序列号（实测 `46247.9513888889`）：

```
ROUND((MIN([↔选题角度].[↔推文].[发布时间]) - [扫描时间]) * 24, 1)
```

这个坑最阴的地方是**它不报错**，只是把所有跨天的落地都压成 24 的整数倍，
于是「25 小时才发」和「刚好 24 小时」在数据里长得一模一样，落地率虚高。

阈值沿用 `twitter-ops/SKILL.md` §8：≥70% 🟢 / 40–70% 🟡 查断点 / <40% 🔴 列未落地 P0 + 归因。
归因现在有据可查——`gate_log` 能看出卡在哪个节点。

## 4. 失败了怎么办

🔴 **写台账失败绝不阻塞流水线。** 台账是旁路，不是关键路径。

1. 写失败 → 在本节点产出末尾加一行「本轮台账写入失败：<原因>」
2. 待写内容落 `$STATE_DIR/lark-pending/$DATE-<表名>-<序号>.json`
3. **下一轮开工第一件事先补写 pending**，成功后删文件
4. 读回失败 → 退回该查询原本的本地办法，**并在输出显式标注降级**

不许静默跳过。`§0 公共铁律`那句「缺的东西照实写『本轮未取到』，不要留白、也不要编一个填上」，
在这里同样适用。

## 5. CLI 门禁（三个，全部实测撞过）

**① 高风险写返回 exit 10，这不是错误。**

不带 `--yes` 调 `+record-delete` / `+field-update` / `+table-delete` 会返回退出码 `10` +
`{"error":{"type":"confirmation","subtype":"confirmation_required"}}`。

- 🔴 **不许看到非 0 退出码就当失败放弃**
- 🔴 **更不许无脑补 `--yes` 静默重试**——那等于把门禁关掉
- 正确做法：把 `error.action` / `error.risk` / 关键参数摆给用户，**等明确同意**，然后在原 argv 末尾追加 `--yes` 重试

**② 建 `formula` / `lookup` 字段要 `--i-have-read-guide`。**

`+field-create --json` 的 `type` 是 `formula` 或 `lookup` 时，不带这个 flag 直接 fail fast。
读的是 `~/.claude/skills/lark-base/references/formula-field-guide.md` / `lookup-field-guide.md`。

**③ 🔴 改跨表公式时，绝对不要回灌 `+field-get` 读到的表达式。**

官方指南写着「`+field-update` 前先 `+field-get`，再按目标完整状态提交」。
**这条在跨表链式公式上会把字段改坏。** 实测：字段能正常出值，但 `+field-get` 读回来是

```
[↔选题角度].[↔推文].[Bitable_Formula_InvalidReferenced]
                      ↑ 本该是 [发布时间]
```

对侧表的字段引用解析不出来。照着这个 PUT 回去 = 亲手把能用的公式写成坏的，
**而且 PUT 会成功、不报错**。改跨表公式一律**从头写完整表达式**，改完回读一条真记录验值。

**④ ⚠️ `+table-create --fields` 不检 `--i-have-read-guide`。**

同一件事、两条路、两种校验：建表时塞公式字段**不会**被拦。
**所以「建表没报错」不等于「公式写对了」**——建完必须回读一条真记录，看值算没算出来。
（本 Base 的两个公式就是这么验的：`ER=0.039`、`X_Score下界=2640`。）

## 6. 日更卡片

`lark-cli im +messages-send --as bot`，目标群从 `LARK_BASE` 的 `chat_id` 读。
内容口径见方案 §6。**bot 必须已在该群里**——实测未入群时 `+chat-list` 返回 `chats: null`，
发送会失败。

## 7. 自查

```
[ ] 每一次写入前都真的查过重了？（不是"应该没有重复"）
[ ] 查重用的是 +record-list --filter-json，不是 +record-search？
[ ] 所有读命令都显式带了 --format json？
[ ] 运行期写入用的是 --as bot，不是 user？
[ ] link 字段写的是 record_id，不是标题？
[ ] select 写的选项在字段里真的存在？
[ ] 写失败时产出里如实写了那一行，pending 也落盘了？
[ ] 遇到 exit 10 时，是拿给用户确认，而不是自己加 --yes 或当失败放弃？
```
