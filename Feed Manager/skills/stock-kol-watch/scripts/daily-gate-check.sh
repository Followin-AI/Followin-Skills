#!/bin/bash
# stock-kol-watch 收尾门禁（机械强制）
# Stop hook 调用。今天跑过日报（Daily/<today>.md mtime=今天）则强制校验：
#   (1) Daily-Index / Macro / _Sectors-Index mtime=今天；
#       Portfolio.md **仅在确有持仓时**才要求 mtime=今天（无持仓的用户没东西可改，
#       强制它只会训练出"为过门禁而 touch 文件"——正是本门禁要消灭的行为）
#   (2) 日报「✅ 收尾门禁」段的两行计数字段（格式见 references/output-templates.md 模板 A）：
#       - 账号覆盖：N/M（✅a ⚪b ❌c）   → 要求 a+b+c=M、a+b=N、M>0（算术对不上 = 覆盖表是糊的）
#       - 完整性审查：遗漏 X · 落盘 ticker T · 落盘 sector S
#         → X 必须为 0；Tickers/ 今天动过的文件数 ≥ T；S = sector-sync 声明的板块个数
#       只查标题文字的旧版拦不住任何事——模板自带"完整性审查"四个字，照抄就过
#   (3) 日报含 <!-- sector-sync: 板块A, 板块B --> 声明（逗号分隔；兼容空格分隔），
#       且声明的每个 Sectors/<X>.md mtime=今天
# 退出码 2 = 阻止 stop 并把 stderr 反馈给模型。非日报会话静默 exit 0。
#
# 配置：设环境变量 KOL_VAULT 指向你的 vault 根（含 Daily/ Sectors/ 等子目录）。
#   export KOL_VAULT="/path/to/your/vault/Stock-Watch"

# KOL_VAULT 未设 = 没在用本 skill（或跑 🅱️ 快速简报模式）→ 静默放行。
# 这是全局 Stop hook，绝不能在无关会话里报错刷屏。
[ -z "${KOL_VAULT:-}" ] && exit 0
VAULT="$KOL_VAULT"
[ -d "$VAULT" ] || exit 0
TODAY=$(date +%Y-%m-%d)
# 跨平台 mtime → YYYY-MM-DD：先试 GNU/Linux，失败回退 BSD/macOS。
# ⚠️ 顺序不能反：GNU stat 的 -f 是"查文件系统"开关，BSD 写法在 Linux 上会把文件系统信息打到
#    stdout 再报错退出（按 GNU 手册语义推断，未在 Linux 实机测）——mday 输出不是纯日期，连第一道
#    "今天跑过日报吗"都判否，门禁在 Linux 上静默放行、从不拦（用仿 GNU 的 stat 垫片实测过这条链）。
#    反过来 BSD stat 不认 -c，报错只走 stderr、stdout 为空，回退干净（macOS 实测）。
mday() {
  local d
  d=$(stat -c "%y" "$1" 2>/dev/null) && { printf '%s\n' "${d%% *}"; return 0; }
  stat -f "%Sm" -t "%Y-%m-%d" "$1" 2>/dev/null
}

DAILY="$VAULT/Daily/$TODAY.md"
[ -f "$DAILY" ] || exit 0
[ "$(mday "$DAILY")" = "$TODAY" ] || exit 0

MISS=()

# Portfolio「持仓总表」里有没有真实持仓行：首列长得像证券代码
#   ✅ AAPL / BRK.B / 0700.HK / 6758.T（港股·日股·A股是数字打头，别只认字母——
#      漏判会让门禁对这些用户静默失效，假阴性比假阳性危险）
#   ❌ 表头「标的」(CJK) / 分隔线「-----」/ 占位符「—」(全角破折号) — 均不以 [A-Z0-9] 开头
has_holdings() {
  [ -f "$1" ] || return 1
  awk '
    /^##[[:space:]]*持仓总表/ { inpos = 1; next }
    /^##/                    { inpos = 0 }
    inpos && /^\|/ {
      n = split($0, a, "|"); t = a[2]; gsub(/[[:space:]]/, "", t)
      if (t ~ /^[A-Z0-9][A-Z0-9.-]{0,9}$/) found = 1
    }
    END { exit(found ? 0 : 1) }
  ' "$1"
}

# (1) 每次日报必更新的文件 mtime=今天
for f in "Daily/Daily-Index.md" "Macro.md" "Sectors/_Sectors-Index.md"; do
  [ "$(mday "$VAULT/$f")" = "$TODAY" ] || MISS+=("mtime过期: $f")
done

# Portfolio：有持仓才强制 mtime（Step 10.8 要求每批重算现价/浮盈）；无持仓只要求文件在
if has_holdings "$VAULT/Portfolio.md"; then
  [ "$(mday "$VAULT/Portfolio.md")" = "$TODAY" ] \
    || MISS+=("mtime过期: Portfolio.md（有持仓 → Step 10.8 必须重算现价/浮盈/Risk Budget）")
elif [ ! -f "$VAULT/Portfolio.md" ]; then
  MISS+=("缺文件: Portfolio.md（Step 0.0 种子文件未建）")
fi

# (2) 收尾门禁段的计数字段
# ⚠️ 正则里不用含中文 / emoji 的方括号字符集（[：:] 之类）：hook 进程常跑在 C locale，
#    多字节字符在方括号里会被拆成单字节，整条匹配静默失败。一律用 (A|B) 分支。
VS=$(printf '\xef\xb8\x8f')   # emoji 变体选择符 U+FE0F，有的编辑器会在 ✅⚪❌ 后面带上
COV=$(grep -oE "账号覆盖(：|:) *[0-9]+ */ *[0-9]+ *(（|\() *✅($VS)? *[0-9]+ *⚪($VS)? *[0-9]+ *❌($VS)? *[0-9]+" "$DAILY" 2>/dev/null | head -1)
if [ -z "$COV" ]; then
  MISS+=("缺字段: 日报无『账号覆盖：N/M（✅a ⚪b ❌c）』(Step 2 拉取覆盖未落，或照抄了模板占位符)")
else
  set -- $(printf '%s' "$COV" | grep -oE '[0-9]+')
  if [ $(( 10#$3 + 10#$4 + 10#$5 )) -ne "$2" ] || [ $(( 10#$3 + 10#$4 )) -ne "$1" ] || [ "$2" -eq 0 ]; then
    MISS+=("账号覆盖算术不对: $1/$2 但 ✅$3 ⚪$4 ❌$5（应 ✅+⚪=N、✅+⚪+❌=M）")
  fi
fi

INT=$(grep -E "完整性审查(：|:).*遗漏" "$DAILY" 2>/dev/null | head -1)
num_of() { printf '%s' "$INT" | grep -oE "$1 *[0-9]+" | head -1 | grep -oE '[0-9]+'; }
LOST=$(num_of "遗漏"); DECL_T=$(num_of "落盘 ticker"); DECL_S=$(num_of "落盘 sector")
if [ -z "$INT" ] || [ -z "$LOST" ] || [ -z "$DECL_T" ] || [ -z "$DECL_S" ]; then
  MISS+=("缺字段: 日报无『完整性审查：遗漏 X · 落盘 ticker T · 落盘 sector S』(Step 10.95 未落)")
else
  [ "$LOST" -eq 0 ] || MISS+=("完整性审查报遗漏 $LOST 条 → 补落盘后把遗漏改回 0 再结束")
  TT=0
  for f in "$VAULT"/Tickers/*.md; do
    [ -f "$f" ] && [ "$(mday "$f")" = "$TODAY" ] && TT=$((TT + 1))
  done
  [ "$TT" -ge "$DECL_T" ] || MISS+=("声明落盘 ticker $DECL_T 个，但 Tickers/ 今天只动过 $TT 个文件")
fi

# (3) 板块同步声明
SYNC_LINE=$(grep -oE '<!-- sector-sync:[^>]*-->' "$DAILY" 2>/dev/null | head -1)
if [ -z "$SYNC_LINE" ]; then
  MISS+=("缺声明: 日报无 <!-- sector-sync: ... --> (改 _Sectors-Index 日期≠sweep)")
else
  SECTORS=$(printf '%s' "$SYNC_LINE" | sed -E 's/<!-- sector-sync: *//; s/ *-->//')
  # 逗号分隔（推荐——板块名可含空格，如 "AI ASIC"）；无逗号时整串若正好是一个板块文件名就当一个
  # （否则单独声明 "AI ASIC" 会被拆成 AI / ASIC 两个），再不是才退回空格分隔（向后兼容）
  SECTORS=$(printf '%s' "$SECTORS" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')
  case "$SECTORS" in
    *,*) OLDIFS=$IFS; IFS=','; set -- $SECTORS; IFS=$OLDIFS ;;
    *)   if [ -f "$VAULT/Sectors/$SECTORS.md" ]; then set -- "$SECTORS"; else set -- $SECTORS; fi ;;
  esac
  SC=0
  for s in "$@"; do
    s=$(printf '%s' "$s" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')
    [ -z "$s" ] && continue
    [ "$s" = "none" ] && continue
    SC=$((SC + 1))
    sf="$VAULT/Sectors/$s.md"
    if [ ! -f "$sf" ]; then
      MISS+=("sector-sync 声明的 $s.md 不存在")
    elif [ "$(mday "$sf")" != "$TODAY" ]; then
      MISS+=("sector-sync 声明了 $s 但 Sectors/$s.md 今天没更新（只改日期≠sweep）")
    fi
  done
  if [ -n "$DECL_S" ] && [ "$DECL_S" -ne "$SC" ]; then
    MISS+=("完整性审查写落盘 sector $DECL_S 个，sector-sync 声明了 $SC 个——两处对不上")
  fi
fi

if [ ${#MISS[@]} -gt 0 ]; then
  echo "🚪 stock-kol-watch 收尾门禁未通过：今天跑了日报（Daily/$TODAY.md），但：" >&2
  for m in "${MISS[@]}"; do echo "  ❌ $m" >&2; done
  echo "请补齐再结束。详见 SKILL Step 10.9 / 10.95。" >&2
  exit 2
fi
exit 0
