# Crypto Watchlist Tracker｜币圈自选每日跟踪

使用 Followin MCP，在每天 **09:00** 和 **21:00** 生成适合手机阅读的自选币早报与晚报：项目与新闻事件、价格与技术面、KOL 喊单、交易员当前仓位和本时段新交易动作。

## 它解决什么问题

普通行情提醒只告诉你“涨了多少”。这个 Skill 进一步回答：

- 为什么涨跌，是否出现项目公告、安全事件、上币、解锁或监管变化；
- RSI、均线、MACD、ATR 和布林带显示的是趋势延续还是过热；
- KOL 嘴上看多或看空时，真实交易员是开仓、加仓、减仓还是对冲；
- 相比早上或昨晚，哪些情况真正发生了变化。

默认输出是简洁早报/晚报，不机械罗列 RSI、EMA、MACD 等全部数值。只有指标异常或出现拐点时，才会点出一至两个关键指标；可见内容统一标注由 Followin MCP 提供，原始来源和请求 ID 留作按需追溯。

## 默认设置

- 时区：`Asia/Shanghai`
- 时间：每天 09:00、21:00，包括周末
- 单个报告最多：10 个币种
- 数据源：Followin MCP；报告只承诺覆盖 Followin 已索引来源，不声称覆盖全网
- 输出：中文或跟随用户语言

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
cp -R crypto-watchlist-tracker ~/.codex/skills/
```

Claude Code 等使用项目级 Skill 目录的客户端，也可以复制到对应的 `.claude/skills/crypto-watchlist-tracker/`。

使用前先连接 Followin MCP：[followin.io/en/mcp](https://followin.io/en/mcp)。

## 边界

- 不执行交易所下单；
- 不把 KOL 喊单或单个技术指标写成确定性买卖建议；
- 交易员名义仓位使用数据源披露值，不反推保证金；
- 没有上期报告时只生成“初始快照”，不伪造环比变化；
- Followin 不可用时直接披露缺口，不用记忆中的旧数据冒充当前更新。

---

## English

The skill updates a user-defined crypto watchlist at **09:00** and **21:00** local time. Each run combines Followin-covered project/news events, live price and technical data, KOL calls, current trader positioning, and new `open/add/reduce/close` actions. It supports native recurring tasks when the client provides automation, or an immediate one-off report otherwise.
