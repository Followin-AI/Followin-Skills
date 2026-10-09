#!/bin/bash
# stock-kol-watch 收尾门禁（机械强制）
# Stop hook 调用。今天跑过日报（Daily/<today>.md mtime=今天）则强制校验：
#   (1) Daily-Index / Macro / _Sectors-Index mtime=今天；
#       Portfolio.md **仅在确有持仓时**才要求 mtime=今天（无持仓的用户没东西可改，
#       强制它只会训练出"为过门禁而 touch 文件"——正是本门禁要消灭的行为）
#       _last-pull.md：last_cutoff_utc 必须是合法 ISO 时间戳（如 2026-10-08T15:09:03Z），且 mtime=今天
#   (2) 日报「✅ 收尾门禁」段的两行计数字段（格式见 references/output-templates.md 模板 A）：
#       - 账号覆盖：N/M（✅a ⚪b ❌c）   → 要求 a+b+c=M、a+b=N、M>0（算术对不上 = 覆盖表是糊的）
#         且 M = references-roster.md 表格里含 @账号 单元格的行数（任一列以 @ 开头；名单文件缺失也拦）
#       - 完整性审查：遗漏 X · 落盘 ticker T · 落盘 sector S
#         → X 必须为 0；Tickers/ 今天动过的文件数 ≥ T；S = sector-sync 声明的板块个数
#       只查标题文字的旧版拦不住任何事——模板自带"完整性审查"四个字，照抄就过
#   (3) 日报含 <!-- sector-sync: 板块A, 板块B --> 声明（逗号分隔；兼容空格分隔），
#       且声明的每个 Sectors/<X>.md mtime=今天
#   (4) 跨 0 点收尾（23:xx 开跑、0 点后结束）：当天日报不存在时，改查 3 小时内改过的昨天日报，
#       上面所有"mtime=今天"放宽为"昨天或今天"
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

OK_DAYS=" $TODAY "
fresh() { case "$OK_DAYS" in *" $(mday "$1") "*) return 0 ;; esac; return 1; }

DAILY="$VAULT/Daily/$TODAY.md"
if [ ! -f "$DAILY" ] || [ "$(mday "$DAILY")" != "$TODAY" ]; then
  # 跨 0 点收尾：23:xx 开跑、0 点后才结束会话 → 当天日报还不存在，旧版在这里静默放行，
  # 一份没补齐的日报照样过（2026-10-08 用 date 垫片模拟 0 点后收尾实测：Macro 过期也 rc=0）。
  # 昨天的日报若在 3 小时内改过，就当它是这次运行的日报来查；昨天、今天两个日期都算"新"。
  YDAY=$(date -d yesterday +%Y-%m-%d 2>/dev/null || date -v-1d +%Y-%m-%d 2>/dev/null)
  YDAILY="$VAULT/Daily/$YDAY.md"
  [ -n "$YDAY" ] && [ -f "$YDAILY" ] && [ -n "$(find "$YDAILY" -mmin -180 2>/dev/null)" ] || exit 0
  DAILY="$YDAILY"; OK_DAYS=" $YDAY $TODAY "
fi

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
  fresh "$VAULT/$f" || MISS+=("mtime过期: $f")
done

# Portfolio：有持仓才强制 mtime（Step 10.8 要求每批重算现价/浮盈）；无持仓只要求文件在
if has_holdings "$VAULT/Portfolio.md"; then
  fresh "$VAULT/Portfolio.md" \
    || MISS+=("mtime过期: Portfolio.md（有持仓 → Step 10.8 必须重算现价/浮盈/Risk Budget）")
elif [ ! -f "$VAULT/Portfolio.md" ]; then
  MISS+=("缺文件: Portfolio.md（Step 0.0 种子文件未建）")
fi

# _last-pull.md：下一批靠它定窗口下界（Step 1 / P3）。2026-10-08 复跑时它停在半截占位符
# "2026-10-08THH:MM:SSZ" 照样过了旧门禁——坏了下一批就定不了窗口，所以查格式 + 今天动过。
LP="$VAULT/_last-pull.md"
if [ ! -f "$LP" ]; then
  MISS+=("缺文件: _last-pull.md（Step 0.0 种子文件未建）")
else
  CUT=$(sed -n 's/^last_cutoff_utc:[[:space:]]*//p' "$LP" | head -1 | tr -d '\r' | sed -E 's/[[:space:]]+$//')
  printf '%s' "$CUT" | grep -qE '^[0-9]{4}-(0[1-9]|1[0-2])-(0[1-9]|[12][0-9]|3[01])T([01][0-9]|2[0-3]):[0-5][0-9]:[0-5][0-9](\.[0-9]+)?(Z|[+-][0-9]{2}:?[0-9]{2})$' \
    || MISS+=("_last-pull.md 的 last_cutoff_utc 不是合法 ISO 时间戳（现为『${CUT:-空}』）→ 写本批 Step 2 发起拉取的 UTC 时刻，如 2026-10-08T15:09:03Z")
  fresh "$LP" || MISS+=("mtime过期: _last-pull.md（Step 11 必须更新窗口起点）")
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
  COV_M=$2
fi

# M 必须等于名单里的账号数（references-roster.md 表格里任一列以 @ 开头的行）。
# 不能只认首列：Step 0.0 让 starter 名单连「档位（预设）」列整张复制，那张表首列是「角色」、@账号在第二列
# （2026-10-09 临时 vault 实跑：只认 `^| @` 时 5 人 starter 数成 0，合规日报被拦）。
# 方括号里只放 ASCII（hook 常跑在 C locale），CJK 角色名靠 .* 跨过去。
# 整个漏掉一个账号时 ✅+⚪+❌=M 照样自洽，只有拿名单对数才看得出来
ROSTER="$VAULT/references-roster.md"
if [ ! -f "$ROSTER" ]; then
  MISS+=("缺文件: references-roster.md（账号覆盖的 M 没法和名单对数；Step 0.0 种子文件未建，或名单不在 \$KOL_VAULT 根目录）")
elif [ -n "${COV_M:-}" ]; then
  RN=$(grep -cE '^\|(.*\|)?[[:space:]]*@[^|[:space:]]' "$ROSTER")
  if [ "$RN" -eq 0 ]; then
    MISS+=("references-roster.md 的表格里没有以 @账号 开头的单元格，账号覆盖的 M 没法核对 → 按 vault-skeleton 或 starter 的表格格式写名单（账号列写成 @handle）")
  elif [ "$COV_M" -ne "$RN" ]; then
    MISS+=("账号覆盖写的 M=$COV_M，但 references-roster.md 有 $RN 个账号——有账号没进覆盖表（或名单改了没同步），补拉 / 补列后改成 N/$RN")
  fi
fi

INT=$(grep -E "完整性审查(：|:).*遗漏" "$DAILY" 2>/dev/null | head -1)
# 容忍模型常见的写法漂移：「遗漏：0」「落盘 Ticker 0」「落盘ticker 0」（2026-10-08 临时 vault 实测，
# 旧写法把这几种都报成"缺字段"，字段明明在）。数字前允许空格 / 全半角冒号；ticker / sector 不分大小写。
num_of() { printf '%s' "$INT" | grep -oiE "$1( |：|:)*[0-9]+" | head -1 | grep -oE '[0-9]+'; }
LOST=$(num_of "遗漏"); DECL_T=$(num_of "落盘 *ticker"); DECL_S=$(num_of "落盘 *sector")
if [ -z "$INT" ]; then
  MISS+=("缺字段: 日报无『完整性审查：遗漏 X · 落盘 ticker T · 落盘 sector S』(Step 10.95 未落)")
elif [ -z "$LOST" ] || [ -z "$DECL_T" ] || [ -z "$DECL_S" ]; then
  MISS+=("完整性审查那行读不出三个整数（遗漏=${LOST:-?} ticker=${DECL_T:-?} sector=${DECL_S:-?}）：照模板写成『遗漏 0 · 落盘 ticker T · 落盘 sector S』，字母换成整数")
else
  [ "$LOST" -eq 0 ] || MISS+=("完整性审查报遗漏 $LOST 条 → 补落盘后把遗漏改回 0 再结束")
  TT=0
  for f in "$VAULT"/Tickers/*.md; do
    [ -f "$f" ] && fresh "$f" && TT=$((TT + 1))
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
    elif ! fresh "$sf"; then
      MISS+=("sector-sync 声明了 $s 但 Sectors/$s.md 今天没更新（只改日期≠sweep）")
    fi
  done
  if [ -n "$DECL_S" ] && [ "$DECL_S" -ne "$SC" ]; then
    MISS+=("完整性审查写落盘 sector $DECL_S 个，sector-sync 声明了 $SC 个——两处对不上")
  fi
fi

if [ ${#MISS[@]} -gt 0 ]; then
  echo "🚪 stock-kol-watch 收尾门禁未通过：今天跑了日报（Daily/$(basename "$DAILY")），但：" >&2
  for m in "${MISS[@]}"; do echo "  ❌ $m" >&2; done
  echo "请补齐再结束。详见 SKILL Step 10.9 / 10.95。" >&2
  exit 2
fi
exit 0
