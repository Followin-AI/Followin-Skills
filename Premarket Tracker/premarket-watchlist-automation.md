---
name: US Stock Premarket Watchlist Automation
description: 用 Followin MCP 创建或更新美股自选股盘前追踪自动化，按持仓状态生成盘前报告、异动与重大新闻提醒、条件化交易计划。适用于“每天盘前跟踪自选股”“监控我的美股持仓”“创建盘前自动化”“premarket watchlist”等请求；用户只需提供自选股和持仓状态。
trigger: 美股盘前追踪、盘前自选、盘前自动化、每天盘前跟踪、自选股跟踪、监控我的持仓、美股盯盘、premarket watchlist、premarket tracker、daily stock watchlist、monitor my holdings
not_trigger: 宏观早报、社群早报、開盤前瞻、开盘前瞻、财报季扫描、单股财报分析、多Agent深度分析、背离扫描、crypto morning brief、macro morning brief、earnings screener、earnings report、divergence scan
mcp: mcp__followin__metrics, mcp__followin__news, mcp__followin__signal, mcp__followin__twitter, mcp__followin__subscription
args: watchlist, positions, schedule, timezone
---

# /premarket-watchlist-automation $ARGUMENTS

用 Followin MCP 为用户的美股自选股和持仓创建盘前追踪任务。用户只需提供自选股与当前持仓；没有指定时间时，采用其所在时区中“美股常规交易开盘前约 1 小时”的工作日时间。

## 使用边界

- 有自动化工具时，创建或更新周期任务；先查找同名或同一 watchlist 的任务，避免重复。
- 没有自动化工具时，立即运行一次同结构的盘前报告，并说明当前客户端不能创建周期任务。
- Followin MCP 是主要证据层。不可用或鉴权失败时，明确说明，不得伪造 Followin 数据。
- Followin MCP 不执行券商订单。只输出条件化研究计划，不得声称已下单、成交或修改仓位。

## 先收集四项输入

1. **Watchlist**：股票代码列表，例如 `DRAM, SNDK, MU, NOK, MRVL`。
2. **Positions**：每只股票为空仓（无持仓）、多仓、空头或期权；已有仓位尽量记录数量、均价、止损和目标。用户只说“全部空仓”时，将所有标的视为仅观察。
3. **Schedule**：默认美股交易日开盘前约 1 小时。Asia/Shanghai 时区在美国夏令时通常为工作日 20:30，冬令时通常为 21:30；创建任务时说明夏令时切换。
4. **Destination**：默认回到当前任务；只有用户明确要求时才使用其他目标。

用户为空仓时，不追问均价和数量。缺少非必要字段时先建立第一版任务，不要因过度澄清而停住。

## 创建或更新自动化

1. 查找已有的盘前任务；watchlist 与目的相同则更新，不另建重复任务。
2. 验证 Followin MCP 已连接。Codex 环境可先运行：

   ```bash
   codex mcp get followin
   ```

3. 使用客户端提供的自动化工具创建或更新任务，不手写不可执行的自动化指令。
4. 将 watchlist、positions、schedule、timezone、输出结构和失败处理全部写入任务提示词。
5. 返回任务 ID、运行时间、标的列表和持仓假设。

推荐的 Streamable HTTP 配置：

```toml
[mcp_servers.followin]
url = "https://mcp.followin.io/v2/mcp"
env_http_headers = { "x-api-key" = "FOLLOWIN_MCP_TOKEN" }
```

若用户接受把 key 存进配置，也可使用：

```toml
[mcp_servers.followin]
url = "https://mcp.followin.io/v2/mcp"
http_headers = { "x-api-key" = "YOUR_API_KEY_HERE" }
```

不得在报告、日志或回复中输出真实 API key。

## Followin 调用顺序

所有美股结构化调用都传 `asset_type="tradfi"`；`news` 不传 `asset_type`。

1. **`metrics` 市场层**：指数或 ETF 市场背景、自选股当前价/最近收盘、涨跌、成交量、历史走势与技术指标。
2. **`metrics` 基本面层**：近期财报、下一次财报日期、估值、分析师评级与结构化研报。
3. **`news(sources=["media"])`**：最近 24 小时到 7 天的重大新闻、公告与催化。
4. **`news(sources=["twitter"])`**：市场级或标的级社媒热度；按原帖 URL 去重后再统计。
5. **`news(sources=["research"])`**：研报来源的原始文章；目标价、评级和结构化 thesis 仍以 `metrics` 为准。
6. **`signal`**：省略 `categories`，一次 fanout 获取可用的内部人、13F 与 KOL 喊单；只解读实际返回的类别。
7. **`twitter`**：仅在用户点名账号、指定推文或需要原始线程时使用，不拿它替代一般社媒搜索。
8. **`subscription`**：用户要求维护 KOL 喊单关注收件箱时使用。它是拉取式未读箱，不是服务端主动推送。

## 每次报告的固定结构

### 1. 市场背景

- 指数/ETF、行业主题和风险偏好；只写 Followin 实际返回的可验证数据。
- 美国节假日或休市日明确写“今日休市”，不把最近收盘冒充当日盘前。

### 2. 单票追踪

每只股票给出：

- 盘前价或最近可验证价格、涨跌和成交量/异动。
- 关键技术位与触发条件。
- 最近催化、重大新闻、公司公告、财报/研报变化。
- 去重后的社媒热度、KOL/内部人/机构信号及样本量。

美东 04:00 之前没有可验证盘前成交时，必须标为“最近收盘/实时快照”，不得称为真实盘前价。字段缺失就略过，不用旧数据补齐。

### 3. 持仓对应计划

- **空仓**：给“等待 / 试仓 / 突破 / 反转”中的条件化计划，包括触发价、失效价/止损逻辑、初始仓位范围和优先级。
- **多仓 / 空头 / 期权**：根据用户提供的均价、数量和风险预算，给持有、加减仓、止损或对冲观察条件。
- 明确区分“交易设置”和“中长期投资逻辑”。
- 不承诺收益，不把社媒热度写成确定性信号。

### 4. 组合视角

- 排出当天最值得关注的 1–2 个机会。
- 列出需要回避的标的或事件风险。
- 提醒同一行业、同一因子或同一事件造成的相关性风险。

### 5. 来源与刷新条件

- 明确哪些事实来自 Followin MCP，补充公共来源时单独标注。
- 给出下一次需要刷新报告的时间、事件或价格条件。
- 结尾注明“仅供研究参考，不构成个性化投资建议”。

## 自动化提示词模板

```text
使用 Followin MCP 作为主要数据源，监控美股自选股：{WATCHLIST}。

当前持仓：{POSITIONS}。
时区：{TIMEZONE}。如果标记为空仓，只给条件化入场计划，不给持有或减仓建议。

每次运行输出简洁中文盘前报告：
1. 市场背景：指数/ETF、行业主题和风险偏好。
2. 单票：盘前价或最近可验证价格、涨跌/异动、关键技术位、近期催化、重大新闻、结构化研报变化、去重后的社媒与公开信号。
3. 持仓计划：空仓给触发价、失效/止损逻辑、初始仓位范围与优先级；已有多仓、空头或期权则按持仓状态给条件化管理计划。
4. 组合视角：当天优先关注的 1–2 个机会、需要回避的风险和相关性风险。
5. 来源纪律：明确标注 Followin MCP 来源。Followin 不可用时直接说明，不得编造。

美东 04:00 前没有真实盘前成交时，把价格标为最近收盘或实时快照；休市日明确写休市。Followin MCP 不执行订单，不得声称已经下单。

结尾给出下一次刷新条件，并注明仅供研究参考，不构成个性化投资建议。
```

## 完成时确认

返回：

- 创建或更新的任务 ID。
- 运行时区与具体时间。
- Watchlist 和 positions 摘要。
- 是否完成 Followin MCP 验证。
- 若只运行了一次报告，明确说明未创建周期任务。
