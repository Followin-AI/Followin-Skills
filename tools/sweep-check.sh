#!/bin/bash
# Followin-Skills sweep 门禁 —— 挡"已失效的数组参数写法"混进新提交。
# 背景：N-8（2026-07-20 起 keywords/categories/sources 数组入参被 schema 拒）曾三次 sweep 半途而废，
#       靠人记不住，靠这道机械检查。
# 规则：staged 新增行里出现 keywords=[ / categories=[ / sources=[ 时，
#       该行必须同时含"这是反例/历史记载"的标记之一（❌ / 不要 / 已失效 / 已作废 / 历史 / N-8 / N-31 / ~~ / 旧写法 / 被拒），
#       否则视为新引入的肯定式数组调用，拦下。
# 安装：cp tools/sweep-check.sh .git/hooks/pre-commit && chmod +x .git/hooks/pre-commit
#（若已装隐私扫描等其他 hook，把本脚本内容并进去。）

set -u
MARKER='❌|不要|不传|禁传|已失效|已作废|历史|N-8|N-31|N-68|~~|旧写法|拒|禁用|deprecated'
STAGED=$(git diff --cached --name-only --diff-filter=ACM -- '*.md')
[ -z "$STAGED" ] && exit 0

HITS=""
while IFS= read -r f; do
  [ -f "$f" ] || continue
  BAD=$(git diff --cached -U0 -- "$f" | grep -E '^\+' | grep -vE '^\+\+\+' \
        | grep -nE 'keywords=\[|categories=\[|sources=\[' | grep -vE "$MARKER")
  [ -n "$BAD" ] && HITS="${HITS}\n--- $f ---\n${BAD}"
done <<< "$STAGED"

if [ -n "$HITS" ]; then
  echo "🛑 sweep 门禁：staged 新增内容含肯定式数组参数写法（N-8 已被 schema 拒，须走 query 串）：" >&2
  printf "%b\n" "$HITS" >&2
  echo "" >&2
  echo "改成 query 串形态；确属反例/历史记载请在同行加 ❌/已失效/N-8 等标记。误报可 git commit --no-verify。" >&2
  exit 1
fi
exit 0
