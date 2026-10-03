#!/bin/bash
# Followin-Skills sweep 门禁 —— 挡"会静默取错数据的 query 串写法"混进新提交。
#
# 规则沿革：
#   2026-08-04  拦肯定式数组参数（当时 N-8：keywords/categories/sources 数组被 schema 拒）。
#   2026-10-02  规则反转（N-105 / N-106 / N-69）：生产端数组入参可用，且是 schema 文档写明的分工
#               （keywords 放标的、query 放意图）；反而是"把标的塞进 query 串"会静默出错。
#
# 现行规则：staged 新增行里，query="…" 的引号内出现下面任一项即拦——
#   (a) *USD 商品 / 美元指数代码：DXUSD GCUSD SIUSD CLUSD BZUSD NGUSD HGUSD
#       → query 串解析会把它们整个丢掉且不报错（N-106），必须放进 keywords 数组。
#   (b) 英文技术指标名或 "day chart"：EMA SMA RSI MACD
#       → 会被当成同名 ticker（N-69：EMA→Emera、RSI→Rush Street、day→Dayforce），改用中文意图词（"均线 指标" / "历史走势"）。
# 该行同时含"这是反例 / 实测记录"的标记之一则放行（见 MARKER）。
#
# 安装：cp tools/sweep-check.sh .git/hooks/pre-commit && chmod +x .git/hooks/pre-commit
#（若已装隐私扫描等其他 hook，把本脚本内容并进去。）
# 自测：tools/sweep-check.sh --worktree   检查未暂存的改动（不拦提交，只打印命中）

set -u
MARKER='❌|不要|禁止|禁写|已失效|已作废|历史|~~|旧写法|实测|静默|丢|劫持|当成|会被|返空|N-69|N-106|deprecated'
BAD_QUERY='query="[^"]*(\b(DXUSD|GCUSD|SIUSD|CLUSD|BZUSD|NGUSD|HGUSD)\b|\b(EMA|SMA|RSI|MACD)\b|day chart)'

if [ "${1:-}" = "--worktree" ]; then DIFF="git diff"; else DIFF="git diff --cached"; fi
FILES=$($DIFF --name-only --diff-filter=ACM -- '*.md')
[ -z "$FILES" ] && exit 0

HITS=""
while IFS= read -r f; do
  [ -f "$f" ] || continue
  BAD=$($DIFF -U0 -- "$f" | grep -E '^\+' | grep -vE '^\+\+\+' \
        | grep -nE "$BAD_QUERY" | grep -vE "$MARKER")
  [ -n "$BAD" ] && HITS="${HITS}\n--- $f ---\n${BAD}"
done <<< "$FILES"

if [ -n "$HITS" ]; then
  echo "🛑 sweep 门禁：新增内容里有会静默取错数据的 query 串写法（N-106 / N-69）：" >&2
  printf "%b\n" "$HITS" >&2
  echo "" >&2
  echo "把标的放进 keywords=[...]，query 只留中文意图词；确属反例 / 实测记录请在同行加 ❌ / 实测 / 已失效 等标记。误报可 git commit --no-verify。" >&2
  exit 1
fi
exit 0
