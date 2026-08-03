#!/bin/bash
# stock-kol-watch 收尾门禁（机械强制）
# Stop hook 调用。今天跑过日报（Daily/<today>.md mtime=今天）则强制校验：
#   (1) Daily-Index / Macro / _Sectors-Index mtime=今天；
#       Portfolio.md **仅在确有持仓时**才要求 mtime=今天（无持仓的用户没东西可改，
#       强制它只会训练出"为过门禁而 touch 文件"——正是本门禁要消灭的行为）
#   (2) 日报含"账号覆盖表"+"完整性审查"标记
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
# 跨平台 mtime → YYYY-MM-DD：先试 BSD/macOS，失败回退 GNU/Linux
mday() {
  stat -f "%Sm" -t "%Y-%m-%d" "$1" 2>/dev/null && return 0
  stat -c "%y" "$1" 2>/dev/null | cut -d' ' -f1
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

# (2) 日报内容标记
grep -q "账号覆盖表" "$DAILY" 2>/dev/null || MISS+=("缺标记: 日报无『账号覆盖表』(Step 2 拉取覆盖未落)")
grep -q "完整性审查" "$DAILY" 2>/dev/null || MISS+=("缺标记: 日报无『完整性审查』(Step 10.95 未落)")

# (3) 板块同步声明
SYNC_LINE=$(grep -oE '<!-- sector-sync:[^>]*-->' "$DAILY" 2>/dev/null | head -1)
if [ -z "$SYNC_LINE" ]; then
  MISS+=("缺声明: 日报无 <!-- sector-sync: ... --> (改 _Sectors-Index 日期≠sweep)")
else
  SECTORS=$(printf '%s' "$SYNC_LINE" | sed -E 's/<!-- sector-sync: *//; s/ *-->//')
  # 逗号分隔（推荐——板块名可含空格，如 "AI ASIC"）；无逗号则退回空格分隔（向后兼容）
  case "$SECTORS" in
    *,*) OLDIFS=$IFS; IFS=','; set -- $SECTORS; IFS=$OLDIFS ;;
    *)   set -- $SECTORS ;;
  esac
  for s in "$@"; do
    s=$(printf '%s' "$s" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')
    [ -z "$s" ] && continue
    [ "$s" = "none" ] && continue
    sf="$VAULT/Sectors/$s.md"
    if [ ! -f "$sf" ]; then
      MISS+=("sector-sync 声明的 $s.md 不存在")
    elif [ "$(mday "$sf")" != "$TODAY" ]; then
      MISS+=("sector-sync 声明了 $s 但 Sectors/$s.md 今天没更新（只改日期≠sweep）")
    fi
  done
fi

if [ ${#MISS[@]} -gt 0 ]; then
  echo "🚪 stock-kol-watch 收尾门禁未通过：今天跑了日报（Daily/$TODAY.md），但：" >&2
  for m in "${MISS[@]}"; do echo "  ❌ $m" >&2; done
  echo "请补齐再结束。详见 SKILL Step 10.9 / 10.95。" >&2
  exit 2
fi
exit 0
