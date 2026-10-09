# Crypto Watchlist Tracker｜币圈自选每日跟踪

使用 Followin MCP，在每天 **09:00** 和 **21:00** 生成适合手机阅读的自选币早报与晚报：项目与新闻事件、价格与技术面、KOL 喊单、交易员当前仓位和本时段新交易动作。

## 它解决什么问题

普通行情提醒只告诉你“涨了多少”。这个 Skill 进一步回答：

- 为什么涨跌，是否出现项目公告、安全事件、上币、解锁或监管变化；
- RSI、均线、MACD、ATR 和布林带显示的是趋势延续还是过热；
- 哪些推特 KOL 给出了有依据的观点，而不是推广、复读新高或纯喊单；真实交易员是开仓、加仓、减仓还是对冲；
- 相比早上或昨晚，哪些情况真正发生了变化。

默认输出是简洁早报/晚报，不机械罗列 RSI、EMA、MACD 等全部数值。只有指标异常或出现拐点时，才会点出一至两个关键指标；报告末尾统一标注“数据来源：Followin MCP”，正文不重复加来源前缀，原始来源和请求 ID 留作按需追溯。

## 默认设置

- 时区：`Asia/Shanghai`
- 时间：每天 09:00、21:00，包括周末
- 单个报告最多：10 个币种
- 数据源：Followin MCP；报告只承诺覆盖 Followin 已索引来源，不声称覆盖全网
- 输出：中文或跟随用户语言
- KOL 喊单统计：只对 BTC、ETH 调用和展示（其余币量太少，不调、不写这一栏）；固定取近 24 小时（上游只覆盖 24 小时），与早晚报的覆盖窗口分开标注
- 推文核验：每期最多 3 个币，因为推特接口走单独且较小的额度；当期有重大事件的币优先——重大事件只认现货 ETF 单日净流入或净流出 ≥1 亿美元（按运行时已公布的最近一个交易日算），或代币解锁 ≥ 流通量 0.5%（团队解押后的场外大宗转让不算解锁，如 HYPE 375 万枚）；都不满足按 24 小时涨跌幅绝对值排
- 样本过小：BTC/ETH 喊单少于 5 帖、某币交易员少于 3 人时只写“样本过小”，不写方向

## 使用示例

```text
用 $crypto-watchlist-tracker 创建币圈自选跟踪。
自选币：BTC、ETH、SOL、HYPE
时区：Asia/Shanghai
每天早上9点和晚上9点更新，继续发在当前任务里。
```

可选补充官方 X 账号：

```text
官方账号：ETH=ethereum，SOL=solana
```

带自动化能力的客户端会创建或更新两个周期任务；没有自动化能力时，会立即运行一次同结构报告，并明确说明没有创建定时任务。

## 安装

将整个 Skill 目录复制到个人 Skill 目录：

```bash
cp -R "Crypto Watchlist Tracker/crypto-watchlist-tracker" ~/.codex/skills/
```

Claude Code 等使用项目级 Skill 目录的客户端，也可以复制到对应的 `.claude/skills/crypto-watchlist-tracker/`。

使用前先连接 Followin MCP：[followin.io/en/mcp](https://followin.io/en/mcp)。

## 边界

- 不执行交易所下单；
- 不把 KOL 喊单或单个技术指标写成确定性买卖建议；
- 交易员名义仓位使用数据源披露值，不反推保证金；
- 没有上期报告时只生成“初始快照”，不伪造环比变化；
- Followin 不可用时直接披露缺口，不用记忆中的旧数据冒充当前更新；
- 上线时间短的币（如 HYPE）长期均线标“历史不足，不可用”；日线不足 50 根时 MACD（26/9）一律标“历史不足”（20–49 根也一样，与布林带等一致）、不足 20 根时 20 日布林带也标“历史不足”；不接外部数据源补；
- 写入或读取 Followin 自选收件箱（subscription）前先征得用户同意：写入会持久保存，读取也会改变未读状态。

---

## English

The skill updates a user-defined crypto watchlist at **09:00** and **21:00** local time. Each run combines Followin-covered project/news events, live price and technical data, KOL calls, current trader positioning, and new `open/add/reduce/close` actions. It supports native recurring tasks when the client provides automation, or an immediate one-off report otherwise.
