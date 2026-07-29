# Premarket Tracker — 美股盘前自选追踪

**一句话**：告诉 AI 你的自选股、持仓和盘前时间，它会用 Followin MCP 每天整理行情、异动、新闻、研报与公开信号，并按持仓状态给出条件化计划。

## 适用场景

- 每天盘前跟踪自选股
- 监控重大新闻、财报/研报变化和社媒热度
- 空仓时生成带触发条件与失效逻辑的观察计划
- 已有持仓时生成持有、加减仓、止损或对冲的观察条件

## 使用方式

```text
请帮我创建美股盘前追踪自动化。
自选股：DRAM, SNDK, MU, NOK, MRVL
持仓：目前全部空仓
时间：美股交易日盘前，北京时间 20:30
```

用户只提供自选股和持仓也可以；Skill 会采用美股开盘前约一小时的默认时间，并提醒美国夏令时切换。

## 客户端边界

- Codex 等带自动化工具的客户端：创建或更新周期任务。
- 没有自动化能力的客户端：立即生成一次同结构报告，不假装任务已创建。
- Followin MCP 不执行券商订单；本 Skill 只做研究与条件化计划。

## 安装

连接 Followin MCP 后，将 Skill 文件复制到命令目录：

```bash
cp "Premarket Tracker/premarket-watchlist-automation.md" ~/.claude/commands/
```

Followin MCP 官方接入：[followin.io/en/mcp](https://followin.io/en/mcp)。

- **Skill 本体**：[`premarket-watchlist-automation.md`](./premarket-watchlist-automation.md)
- **MCP 调用红线与已知问题**：[`references/followin-mcp-caveats.md`](../references/followin-mcp-caveats.md)
