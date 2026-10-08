#!/bin/bash
# Followin-Skills sweep 门禁 —— 挡"会静默取错数据的 query 串写法"混进新提交。
#
# 规则沿革：
#   2026-08-04  拦肯定式数组参数（当时 N-8：keywords/categories/sources 数组被 schema 拒）。
#   2026-10-02  规则反转（N-105 / N-106 / N-69）：生产端数组入参可用，且是 schema 文档写明的分工
#               （keywords 放标的、query 放意图）；反而是"把标的塞进 query 串"会静默出错。
#   2026-10-03  补 (c)(d) 两条与 (b) 的 metrics 扩展（N-113 / N-118 / N-108 / N-109 / N-14）。
#   2026-10-08  补 (e)(f)(g) 三条日历 / 新闻写法（N-128 / N-133 / N-145）。
#
# 现行规则：staged 新增行里，query="…" 的引号内出现下面任一项即拦——
#   (a) *USD 商品 / 美元指数代码：DXUSD GCUSD SIUSD CLUSD BZUSD NGUSD HGUSD
#       → query 串解析会把它们整个丢掉且不报错（N-106），必须放进 keywords 数组。
#   (b) 英文技术指标名或 "day chart"：EMA SMA RSI MACD
#       → 会被当成同名 ticker（N-69：EMA→Emera、RSI→Rush Street、day→Dayforce），改用中文意图词（"均线 指标" / "历史走势"）。
#       metrics(...) 的 query 里另拦 ADX / beat / miss（N-14：beat 被当成 ticker BEAT；news 的 query 不拦）。
# 另外两条不限于 query 引号内——
#   (c) signal(...) 带了参数却没有 categories
#       → 只传 ticker / query 不再自动展开四类，返回空（N-113 / N-118）。正文里泛指的 signal() 不拦。
#   (d) 已不存在的字段 / 失效 series：beat_miss  latest_quarter  WTREGEN
#       → 改用 fiscal_quarters[0].earnings_surprise / financial_statement（N-109）、WDTGAL（N-108）。
#   (e) 经济日历 metrics(…economic calendar…) 没带 sort_by="hot"
#       → 按时间排，国债拍卖、官员讲话把 50 行占满，CPI / 非农被挤出去（N-128）。
#   (f) 财报日历 metrics(…earnings calendar…) 传了 country=
#       → 按注册地过滤，漏掉 ACN 这类外国注册的美股（N-133）。不传 country，客户端过滤代码。
#   (g) news 搜索（query 非空）带 asset_type="tradfi"
#       → 召回下降且挡不住加密噪音（N-145）。只在趋势模式（query=""）传。
# (e)(f)(g) 只看同一行里写全的调用式；跨行拆开写的调用拦不到。
# 该行同时含"这是反例 / 实测记录"的标记之一则放行（见 MARKER）。
#
# 安装：cp tools/sweep-check.sh .git/hooks/pre-commit && chmod +x .git/hooks/pre-commit
#（若已装隐私扫描等其他 hook，把本脚本内容并进去。）
# 自测：tools/sweep-check.sh --worktree   检查未暂存的改动（不拦提交，只打印命中）

set -u
MARKER='❌|不要|禁止|禁写|已失效|已作废|历史|~~|旧写法|实测|静默|丢|劫持|当成|会被|返空|返回空|旧的|不存在|不再|换代|改用|回退|退回|N-69|N-106|N-108|N-109|N-113|deprecated'
BAD_QUERY='query="[^"]*(\b(DXUSD|GCUSD|SIUSD|CLUSD|BZUSD|NGUSD|HGUSD)\b|\b(EMA|SMA|RSI|MACD)\b|day chart)'
BAD_METRICS='metrics\([^)]*query="[^"]*\b(ADX|beat|miss)\b'
BAD_FIELD='beat_miss|latest_quarter|WTREGEN'
CAL_ECON='metrics\([^)]*economic calendar[^)]*\)'
CAL_EARN='metrics\([^)]*earnings calendar[^)]*\)'
NEWS_SEARCH='news\(query="[^"]+"[^)]*\)'

if [ "${1:-}" = "--worktree" ]; then DIFF="git diff"; else DIFF="git diff --cached"; fi
FILES=$($DIFF --name-only --diff-filter=ACM -- '*.md')
[ -z "$FILES" ] && exit 0

HITS=""
while IFS= read -r f; do
  [ -f "$f" ] || continue
  ADDED=$($DIFF -U0 -- "$f" | grep -E '^\+' | grep -vE '^\+\+\+' | grep -vE "$MARKER")
  [ -z "$ADDED" ] && continue
  BAD=$(printf '%s\n' "$ADDED" | grep -nE "$BAD_QUERY|$BAD_FIELD"
        printf '%s\n' "$ADDED" | grep -niE "$BAD_METRICS"
        printf '%s\n' "$ADDED" | grep -noE 'signal\([^)]+\)' | grep -v 'categories'
        printf '%s\n' "$ADDED" | grep -noE "$CAL_ECON" | grep -v 'sort_by="hot"'
        printf '%s\n' "$ADDED" | grep -noE "$CAL_EARN" | grep 'country='
        printf '%s\n' "$ADDED" | grep -noE "$NEWS_SEARCH" | grep 'asset_type="tradfi"')
  [ -n "$BAD" ] && HITS="${HITS}\n--- $f ---\n${BAD}"
done <<< "$FILES"

if [ -n "$HITS" ]; then
  echo "🛑 sweep 门禁：新增内容里有会静默取错数据的调用写法（N-106 / N-69 / N-113 / N-109 / N-128 / N-133 / N-145）：" >&2
  printf "%b\n" "$HITS" >&2
  echo "" >&2
  echo "把标的放进 keywords=[...]，query 只留中文意图词；signal 显式传 categories；beat_miss / latest_quarter 改用 fiscal_quarters[0]；经济日历加 sort_by=\"hot\"；财报日历去掉 country；news 搜索去掉 asset_type=\"tradfi\"；确属反例 / 实测记录请在同行加 ❌ / 实测 / 已失效 等标记。误报可 git commit --no-verify。" >&2
  exit 1
fi
exit 0
