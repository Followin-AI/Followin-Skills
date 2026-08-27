# list-Agent prompt 模板（逐字填占位符，禁手拼）

派 list-Agent 时把下面整段**逐字**复制进 prompt，只替换 `<>` 占位符。

> 🔴 **禁手拼。** 手拼出过两类事故：复用过期 `scan_ts`（4.5h 前的值让 age 变负、velocity 静默失真 3.4×）、
> 时区规范漏写（近 8h 推文 age 全变负）。两次都不报错，只是排序悄悄失效。

---

## 占位符

| 占位符 | 取值 |
|---|---|
| `<LIST_ID>` | `config.md` 的 `LIST_IDS` 对应行 |
| `<LIST_NAME>` | `main` / `tech` / `master` |
| `<NOW_MS>` | 主进程 §0 时钟取的 `NOW_MS`，**取完立刻派 Agent** |
| `<DATE>` | 主进程 §0 时钟取的 `DATE` |
| `<TOP_N>` / `<TOP_M>` | 双轨条数，见下表 |
| `<THRESHOLD_MS>` | 窗口起点 epoch ms |

双轨条数：首扫 主 17+3 / 科技 10+3 / 大师 4+1；刷新 主 7+3 / 科技 5+2。

---

## 模板正文

```
任务边界：调 twitter(action="list_timeline", list_id=<LIST_ID>) → jq 汇总 → 只返回 ≤N 行精简文本，不解释。
action 写死 list_timeline（本次只拉这一个端点；它与 list_tweets 各缺一半，合并策略是主进程的事，见下方端点铁律）。
scan_ts_ms = <NOW_MS>（主进程刚取的，禁止自己取或复用历史值）
DATE = <DATE>    THRESHOLD_MS = <THRESHOLD_MS>

── createdAt 解析规范（🔴 实测过，别改写）──
返回格式：createdAt = "Fri Jul 17 06:30:30 +0000 2026" —— RFC-822 风格，非 ISO8601，offset 恒为 +0000。
✅ jq 正确写法（**去掉 %z**，让 mktime 按 UTC 处理——offset 恒 +0000 无需解析）：
   .createdAt | sub(" \\+0000 ";" ") | strptime("%a %b %d %H:%M:%S %Y") | mktime
🚫 **绝对禁止 `strptime("... %z ...")|mktime`**：jq 的 `%z`+`mktime` 会掺入运行机器的本地时区——
   实测 UTC 下正确、**+8 时区偏 +28800s、-5 时区偏 -14400s**。
   这个偏移**不会让 age 变负**（8h 偏移 < 大多数推文 age），所以「age 为负」那道守卫**抓不到它**，
   velocity 排序会静默失真而全程无告警。这是最隐蔽的一类，务必用上面去 %z 的写法。
   （备用等价写法：正则重组成 ISO `\(.y)-\(.mon)-\(.d)T\(.t)Z` 再 `fromdateiso8601`，同样 TZ 无关。）
🚫 也禁止先转本地时区显示、再当 UTC 重新解析。

── velocity 双轨 ──
velocity = (likeCount + 2*retweetCount + 0.5*replyCount) / max(age_hours, 0.25)

RT 封顶（结构解，替代黑名单打地鼠）：转推判据 = `retweeted_tweet` 非空（首选）或 text 以 "RT @"/"RT@" 开头 →
  velocity_final = min(velocity, 本批次非RT贴最高velocity)
  转发仍是背书信号（保留参与排序），但不许凭被转对象的爆款互动霸榜
  （典型病例：自己原创互动个位数~几百，靠 RT 外部爆款借到 5 万赞 velocity）

双轨 = velocity_final DESC top <TOP_N> + createdAt DESC top <TOP_M>
     → unique_by(.id) → createdAt DESC
<30min 推文无论 velocity 硬保留

⚠️ age 为负 = 报错信号，禁止 abs() 静默转正。
   算出 age_hours < 0 必须在返回里标：
   "⚠️ age 为负 (N 条)：scan_ts 过期或时区解析错 → 本次 velocity 不可信"
   仅 0 ≤ age < 0.25 才用 max(age,0.25) 防除零。
   （abs 会掩盖两类真错误：scan_ts 已过期 / 时区解析写错。
     兜底函数会把 bug 变成静默失真——负 age 物理上不可能，它出现就说明前提坏了，该炸不该修。）

── 噪音过滤（按内容判定，不维护点名黑名单）──
剔纯政治 / 社会 RT（科技 list 与大师 list 都要剔）：单条政治转推 velocity 可达数万，
  直接霸榜双轨首位、把真信号挤出榜。
剔软性内容：纯鸡汤 / 人生感悟 / 无市场信息的原创贴（"剔政治 RT"管不到非转推软贴）。
jq 变量只用 as，不用 $ENV。

── 返回格式（逐字段给出）──
{"list":"<LIST_NAME>","list_id":"<LIST_ID>","raw_count":<原始推文数>,
 "scan_ts_ms":<NOW_MS>,"top_velocity":<最高velocity>,
 "handles":["<本list筛出的去重@用户名，不带@>"]}
+ 每条候选一行：createdAt / handle / velocity_final / text(≤280字)

只返回精简文本，不解释。
```

---

## 端点铁律：`list_timeline` 与 `list_tweets` 都不完整

| | `list_timeline`（主用） | `list_tweets`（补拉） |
|---|---|---|
| 大致倾向 | 收纯 RT，弃 reply | 收 reply，弃纯 RT |
| 稳定吗 | **不稳定**——对照组 list 用 `list_timeline` 也返回了 `isReply: true` 的条目 |
| 实测缺口 | 重叠窗口内**丢了一条正常原创长推**（既非 reply 也非 RT），还漏掉一个 40.6k 粉的成员 |

**日常首扫用 `list_timeline` 就够。** 但两点要记住：

1. **`list_tweets` 不是"错的那个"**，它是"另一半"。某个 list 产出明显偏低、
   或要复核"某人今天真的没发推"时，补拉一次并**按 `id` 合并去重**。
2. 名字相近、都返回数据、都不报错——**用哪个都不会有报错提示你样本残缺**，
   而双轨排序会建在残缺样本上，简报看起来完全正常。这是本仓最贵的坑之一。

⚠️ **`list_timeline` 返回里没有 `inReplyToUserId`**，判 reply 用 `isReply` / `inReplyToId`。
（`user_tweets` 端点**有** `inReplyToUserId` / `inReplyToUsername`——同一个 MCP 工具、
不同 action 字段集不同。**别把一处的字段观察套到另一处。**）

⚠️ **`quoted_tweet` 三层嵌套，第三层是空壳**（只有 id，`author: {}` / `text: ""`）。
同一条推会在同一页里既作为顶层 item、又作为别人的 `quoted_tweet` 出现 → **必须按 `id` 去重**。

⚠️ **`entities.symbols` 不可靠**：实测一条正文提了近 10 个代币，`symbols` 只列出 1 个。
别拿它当提取标的的唯一来源。

---

## 回执（自查 ⑪.a 的唯一凭据）

Agent 扫完 + jq 后用 Bash 落回执到
`$STATE_DIR/trend-scout-list-receipt-<LIST_NAME>-$DATE.json`。

回执是子进程亲手产出的真凭据（不真派 Agent 就没有），`scan_ts_ms` 绑定本次扫描杜绝复用旧回执。
三栈齐 + `raw_count>0` + `scan_ts` 匹配 → 自查 ⑪.a PASS。
`handles` 用于交叉验 `source_list` 真伪（⑪.a 一律 PASS 之后，source_list 准确性会失去机检）。

---

## 噪音号：能判什么、不能判什么

- **三型**：持续霸榜型（高频政治、velocity 稳定占首位）/ burst 占位型（某时段刷屏）/
  单号吞噬型（一个号占单页 80%+ 且窗口内 0 条原创观点）
- ⚠️ **单日样本判不了**：burst 型占比取决于扫描时刻是否落在 burst 上（同号昨天 12/20、今天 5/20）
- ⚠️ **Agent 端整号剔除不会多拿一条有效数据**（每页条数固定，剔了不补别人），
  真收益只有「防双轨首位被零价值贴占据」
- 🔒 **真解是源头把号移出 list**（实测移出一个单号吞噬型后，该 list 信噪比 18%→54%、产能 4.5→6.7 条/天），
  但 **MCP 无 list 写权限 → 必须人工在 Twitter UI 做，Skill 只能建议**
