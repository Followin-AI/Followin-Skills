# 数据源 & RSS 列表

> 🔴 **这份清单不是调用白名单，是"背景知识"。**
> 本 Skill 的采集**只走 §2 的 MCP 工具白名单**（`metrics` / `news` / `signal` / `twitter`），
> 自查⑩「零废弃工具调用」检的就是这一条。下面列的站点绝大多数**没有对应的 MCP 调用路径**——
> 它们的用途是：看到某条料时判断"这个源可信度如何"、决定是否需要人工去核实。
>
> ⚠️ **不要因为这里列了某个站点，就去尝试抓它的 RSS 或网页。**
> 本模板对外声明的是「数据源只需要一个 MCP」；擅自加源会让产出不可复现，
> 也会让「某源连续 2 次 degraded 就标注」这类审计规则失效（无法审计不在体系内的源）。

## 加密新闻

### 英文
| 来源 | URL | 更新频率 | 特点 |
|------|-----|---------|------|
| CoinDesk | coindesk.com | 实时 | 综合性最强 |
| The Block | theblock.co | 实时 | 机构视角、数据好 |
| Cointelegraph | cointelegraph.com | 实时 | 覆盖面广 |
| Decrypt | decrypt.co | 每日 | 叙事性强 |
| DL News | dlnews.com | 每日 | 深度报道 |

### 中文
| 来源 | URL | 更新频率 | 特点 |
|------|-----|---------|------|
| 金色财经 | jinse.cn | 实时 | 中文最快 |
| Odaily | odaily.news | 实时 | 项目分析深 |
| PANews | panewslab.com | 实时 | 综合覆盖 |
| BlockBeats | theblockbeats.info | 实时 | 快讯速度快 |
| 吴说 | wublock.com | 每日 | 独家消息多 |

## 宏观经济数据源

### 官方来源
| 来源 | 关注内容 | 频率 |
|------|---------|------|
| 美联储 (federalreserve.gov) | FOMC决议、会议纪要、点阵图 | 每6周/按需 |
| 美国劳工部 (bls.gov) | CPI、PPI、非农就业 | 月度 |
| 美国财政部 (treasury.gov) | 国债拍卖、TGA余额 | 每日/周度 |
| ECB (ecb.europa.eu) | 利率决议、经济展望 | 每6周 |
| 日本央行 (boj.or.jp) | 利率、YCC政策 | 按需 |

### 经济日历
| 工具 | URL | 用途 |
|------|-----|------|
| Investing.com 日历 | investing.com/economic-calendar | 每日关键数据发布时间 |
| ForexFactory | forexfactory.com/calendar | 外汇+宏观数据 |
| TradingEconomics | tradingeconomics.com | 全球宏观数据汇总 |

## 链上数据平台

### 综合数据
| 平台 | API | 用途 |
|------|-----|------|
| CoinGecko | api.coingecko.com | 价格、市值、交易量（免费） |
| DeFiLlama | api.llama.fi | TVL、协议数据、DEX交易量（免费） |
| Dune | dune.com/api | 自定义链上查询（有免费额度） |

### 鲸鱼 & 资金流
| 平台 | 用途 |
|------|------|
| Whale Alert | 大额转账实时追踪 |
| Lookonchain | 聪明钱地址追踪 |
| Arkham Intelligence | 实体标签+资金流向 |
| Nansen | 钱包标签+热钱追踪 |

### DeFi 专项
| 平台 | 用途 |
|------|------|
| DeBank | DeFi投资组合追踪 |
| Token Terminal | 协议收入和估值数据 |
| L2Beat | L2 TVL和安全性对比 |

### 交易所资金流
| 平台 | 用途 |
|------|------|
| CryptoQuant | 交易所流入/流出、矿工数据 |
| Glassnode | 链上指标（MVRV、SOPR等） |
| Coinalyze | 期货持仓、资金费率 |

## CT KOL 监控列表

> ⚠️ **本节是结构模板，不是推荐名单。** 下表按「你需要哪几类视角」分组，账号自己填。
> 别直接抄别人的关注列表——名单要匹配你的账号定位，否则扫回来的东西你既没观点也接不上话。

| 视角类别 | 你需要几个 | 选号标准 | 你的账号 |
|---|---|---|---|
| 宏观 × 加密 | 2–3 | 能把美联储/流动性和币价挂钩，不只喊单 | `@___` |
| 链上数据 | 2–3 | 自己跑数据、给图表，不是转述别人的 | `@___` |
| 交易观点 | 2–3 | 明确给方向和理由，且事后认账 | `@___` |
| 研究机构 | 1–2 | 出研报、有方法论 | `@___` |
| 中文圈 | 2–3 | 你的目标读者实际在看谁 | `@___` |

**选号三条**：
1. **粉丝量在你的 1.3–10 倍之间**——太小学不到东西，太大玩法不可复制
2. **发文频率适中**——高频全量搬运号会把你的扫描结果淹没
3. **零借鉴即移出**——连续几周没从他那儿拿到任何可用角度，就换掉

**辅助工具**：Twitter Lists 建私密列表分组关注；链上类可配合 Nansen Smart Money 等地址追踪工具。

## RSS 订阅建议

```
# 加密新闻 RSS
https://www.coindesk.com/arc/outboundfeeds/rss/
https://www.theblock.co/rss.xml
https://cointelegraph.com/rss
https://decrypt.co/feed

# 宏观
https://www.federalreserve.gov/feeds/press_all.xml

# 中文
https://www.odaily.news/rss
https://www.panewslab.com/rss
```

## API 调用示例

### CoinGecko — 24h涨跌幅Top币种
```
GET https://api.coingecko.com/api/v3/coins/markets?vs_currency=usd&order=price_change_percentage_24h_desc&per_page=10
```

### DeFiLlama — TVL变化排行
```
GET https://api.llama.fi/protocols
```

### Dune — 自定义查询
```
GET https://api.dune.com/api/v1/query/{query_id}/results
```

## 每日检查清单

### 快速扫描（5-10分钟）
- [ ] CoinGecko 24h 涨跌幅 Top 10
- [ ] DeFiLlama TVL 变化 Top 10
- [ ] Whale Alert 过去12h大额转账
- [ ] 今日经济数据日历
- [ ] CT 热门话题/趋势

### 深度挖掘（按需）
- [ ] Glassnode/CryptoQuant 链上指标变化
- [ ] 交易所资金费率和持仓量
- [ ] KOL 观点汇总（多空分歧）
- [ ] 项目重大更新/升级/解锁

### 信息质量检查
- [ ] 一手源还是二手源？
- [ ] 数据可验证吗？
- [ ] 是否有对立观点？


---

# MCP 坑位（实测档案）

> 这些是端点的实际行为记录，不是调用白名单。SKILL.md 只留结论，细节在这里。

## 国债 / 宏观 query 的误抽与重复行

- ⚠️ **该 query 会触发误抽 + 重复行**（实测）：`curve` 被当成 **Curve 代币 `CRV`**，`keywords` 解析成 `["US","YIELD","CRV"]`，meta 还会报 `asset_type=tradfi 但所有 keyword 落到 crypto 家族`。
- **后果是返回 3 行内容完全相同的曲线**（每个 keyword 各一行，靠 `_resolved_from_keyword` 区分）。数据本身是对的，但**读之前必须按 `_resolved_from_keyword` 去重**，否则会把同一条曲线当成三个独立数据点。那条 crypto 警告是误报，不用理会。
- 想避开误抽可改用不含歧义词的写法（如 `query="treasury rates"`），但**去重这一步照做**——多 keyword 解析出来就会多行。

## 商品符号

- ⚠️ **商品符号实测（黄金/原油拿不到一手价）**：`CLUSD` 返 0 结果 · `BZUSD` 在 query 串里**静默丢弃** · `GCUSD` 单调亦返 0 · `OIL`/`GOLD` 别名会解析成 **iPath 原油 ETN / Gold.com 股票**（不是商品）。
  **可用替代**：原油走 `USO`（WTI 近月期货 ETF，**代理指标非现货**，引用须标口径）；黄金优先试 `query="gold price"` 拿 `GCUSD` 行（会同时命中 Gold.com 股票，按 symbol 筛）。
  🔒 **拿不到就按「价格数据铁律」处理**：简报标「未取到一手价」，**禁止引用新闻里的涨跌幅当数据**。

## 异动榜

- **异动榜**：`metrics(query="most active stocks", asset_type="tradfi")`，**不传 `min_market_cap`**（间歇被 schema 拒 `-32602`）；⚠️ **返回行不含 `marketCap`**（实测：只有 symbol/name/price/change/changesPercentage），**必须二次批量快照补市值**后再按 ≥$1B 过滤，否则杠杆 ETF（BITO/SOXL/TSLL/NVD 等）会混进候选。另需按 name 剔 ETF/杠杆产品——正则 `ETF|ETN|UltraPro|Ultra|Leveraged|\dX|Bull|Bear|Daily`，⚠️ 只判 "ETF" 单词会漏（`ProShares UltraPro QQQ` 不含该字串）。`biggest gainers/losers` 端点全是仙股与数据错误，**禁用**。

## signal 的 query 不做类型路由

- ⚠️ **`signal` 的 query 串不做数据类型路由**（实测）：传 `query="congress senator stock purchase disclosure"`，`meta.filters_applied.keywords` 回 **null**，返回的是**默认全类 fanout**（insider_trading + institutional + kol_call + trader_position），而 `insider_trading` 里全是 `provenance:"corporate_insider"` 的 Form 4，**一条议员交易都没筛出来**。
- **想要议员交易只能客户端筛**：拿到 `insider_trading` 后按 `provenance` 字段自己分流，别指望用自然语言描述让服务端替你过滤。**query 写得再具体也不改变返回内容**——这是白花心思。


---

# 板块热度分（0–5 分）

下游 topic-engine #12（≥3.0 触发）
和 deathnote（连续 4 周 <2.0）用的就是这个分，**没有这套口径它们的阈值就是空的**：

| 项 | 分值 | 判据（全部可从本次扫描数据直接数出来） |
|---|---:|---|
| 候选数 | 0–2 | 本板块本次候选 0 条 = 0；1–2 条 = 1；≥3 条 = 2 |
| KOL 广度 | 0–1.5 | 提到该板块的**不同** KOL 账号数：≤1 = 0；2 = 0.75；≥3 = 1.5 |
| 跨语言 | 0–1 | 只有单一语种 = 0；中英（或任意 ≥2 语种）都有 = 1 |
| 硬数据支撑 | 0–0.5 | 该板块至少 1 条候选带 metrics 实时数字 = 0.5 |

合计封顶 5.0，保留 1 位小数。**0 hit 板块记 0.0，不是 n/a**——deathnote 要的就是连续低分。
⚠️ 这四项都必须来自**本次扫描**，不许继承上一轮的分（板块热度是时点量）。

🔴 **但「周」级消费者要用当周最高分，不是最后一次的分。** 分是时点量，而 deathnote 判的是
「连续 4 周 <2.0」——一周内首扫 + 多次刷新会算出好几个分，刷新档的候选 floor 是全板块合计 ≥7，
单板块几乎不可能再 ≥3 条，于是**早上 3.5 分的热板块会被晚上刷新重算成 0.5**。
规则：`narrative-watchlist-$WEEK.json` 里每个板块记 `score_latest` 和 `score_week_max` 两个值，
**deathnote 只看 `score_week_max`**；topic-engine #12 的 ≥3.0 触发看 `score_latest`（它要的是当下热度）。
