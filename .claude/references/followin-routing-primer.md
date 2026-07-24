# Followin MCP 官方路由 Primer

> **来源**：Followin MCP 服务器自身发布的 server instructions（客户端连接后即收到），
> 与 [followin.io/zh-Hans/mcp/docs](https://followin.io/zh-Hans/mcp/docs) 「进阶 — 让你的 AI 路由更准」
> 一节提供的可复制 CLAUDE.md 片段同源。
>
> **本文件是官方基准，不是本仓库的产物。** 仓库内 Skill 的编排以此为对齐依据；
> 当官方 primer 与本仓库实测结论冲突时，见文末「与实测结论的边界」一节。

---

## 路由（意图 → 工具）

| 意图 | 工具 |
|---|---|
| 价格、报价、OHLCV 历史、技术指标、宏观数据、基本面（含分析师评级/目标价、财报日历、同行）| `metrics` |
| 新闻 / 评论 / 研报 / 推文 / 频道贴文 | `news` |
| 谁在买：KOL 喊单 / 鲸鱼 / 内部人 / 13F 持仓 | `signal` |
| 关注 / 订阅 / 提醒 / 监控 KOL 喊单标的，或查看已关注标的与未读数 | `subscription`（关注收件箱；无服务端推送）|
| 对指定账号或推文的原始 Twitter 操作 | `twitter` |

## 命名约定

- 美股 `asset_type="tradfi"`；加密 `asset_type="crypto"`。

## 常用编排

```
美股尽调 = metrics(["market"]) + metrics(["fundamentals"])
         + news(["twitter"]) + news(["research"])
         + signal(["insider_trading"])

加密监控 = metrics(["market"]) + signal(["kol_call"], query="consensus")
         + signal(["trader_position"]) + news(["media"])
```

---

## 与实测结论的边界

官方 primer 是**意图路由层**的简版指引，工具自身的 description 才是详细契约。以下几处
本仓库实测后采取了更具体的做法，**不构成与官方冲突，而是同一契约的细化**：

| 主题 | 官方 primer | 工具 description（详细契约）+ 本仓库实测 | 仓库做法 |
|---|---|---|---|
| 研报 | 尽调编排里写 `news(["research"])` | `news` 的 BOUNDARIES 明确：`sources=["research"]` 只适合**研报来源的原始文章检索**；**结构化券商研报**（报告卡 / 目标价 / rating_action / thesis / catalysts / caveats）属 `metrics(categories=["fundamentals"])` | **两者都用**：`news(sources=["research"])` 取原始文章（quota=0），`metrics` 取结构化报告字段供输出模板使用（红线 12、N-19、N-21）|
| signal 分类 | 编排里按类显式传 `categories` | 实测 2026-07-24：**省略 `categories` 会 fanout 到 insider_trading + institutional + kol_call 三类，合计仍只计 1 额度** | 需要多于一类时**单次 fanout**，只要一类时才显式传 categories（N-22）|
| news 的 asset_type | 约定层统一写 tradfi/crypto | 实测：`news()` 传 asset_type 返 0 results（`is_tradfi` 字段几乎全 false 的上游 bug）；趋势模式例外 | **news 搜索模式一律不传 asset_type**（红线 1）|

完整调用红线与已知问题登记见 [`followin-mcp-caveats.md`](./followin-mcp-caveats.md)——那份文件是本仓库
Skill 行为的单一事实源，本文件是它的上游参照。
