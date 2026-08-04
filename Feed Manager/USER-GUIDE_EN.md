<!-- Language: English | 中文: USER-GUIDE.md -->
**Language / 语言**: English (this file) · [中文](USER-GUIDE.md)

# Operating Manual

> This is the **operating manual**: configuration details, the full command table, and what to do when something goes wrong.
> Don't know what this is yet → read the [Feed Manager section in the repo README](../README.md#feed-manager-1-skill) first (the folder README is in Chinese). Want the workflow spec the AI follows → [SKILL.md](skills/stock-kol-watch/SKILL.md).

After installing (`cp -rn "Feed Manager/skills/"* ~/.claude/skills/` from the repo root), if you just want a single trial run, say "run a quick brief on these 5 accounts" — no configuration needed. **Everything below is only for long-term accumulation (🅰️ mode).**

---

## 1. Configuration

### 1.1 Vault path

```bash
export KOL_VAULT="/path/to/your/vault/Stock-Watch"
```

Put it in `~/.zshrc` / `~/.bashrc` to persist. Everything lands under it. Once this is set, "run KOL watch" defaults to the persistent mode.

### 1.2 Where your account list lives

The 5 built-in starters are at the top of [account-roster.md](skills/stock-kol-watch/references/account-roster.md). **Copy them into `$KOL_VAULT/references-roster.md`** — the copy inside the skill directory is a template; the running workflow reads the one in your vault. Edit that file to change your list.

⚠️ Those 5 lean semiconductors and include **no bear voice**. Add 1–2 steady skeptics before real use, or your list will systematically show you only reasons to be long.

### 1.3 The close-out gate hook (optional, strongly recommended)

Add to `~/.claude/settings.json`:

```json
{ "hooks": { "Stop": [ { "hooks": [ { "type": "command",
  "command": "KOL_VAULT=/path/to/your/vault/Stock-Watch bash ~/.claude/skills/stock-kol-watch/scripts/daily-gate-check.sh",
  "timeout": 15 } ] } ] } }
```

⚠️ **Inline the vault path in the command.** Don't count on it reading your zshrc export — the hook process may not inherit it, and when it doesn't, the gate **silently never runs** and you get no warning.

**What it enforces**: when you try to end a session after running the daily, it mechanically checks the following and blocks you if anything is missing — turning "I think I wrote it" into "the system won't let me cut corners."

| Check | Notes |
|-------|-------|
| `Daily-Index.md` / `Macro.md` / `_Sectors-Index.md` touched today | the three files that change every batch |
| `Portfolio.md` touched today | **only enforced when you actually hold something**; no positions reported → no block |
| The brief contains a coverage table + completeness review | proves the pull and verification steps weren't skipped |
| Sector files named in the brief's `sector-sync` line really were updated | prevents "bumped the index date but never touched the sector note" |

**Verify your install once**: deliberately backdate `Macro.md` (`touch -t 202601010900 $KOL_VAULT/Macro.md`), then end a session in which you ran the daily — **getting blocked means it works**. If you're not blocked, the hook isn't firing; check the path.

---

## 2. First run (cold start)

A fresh vault is empty. The first time, just say:

> **"Initialize the vault, then run KOL watch"**

It will:

1. Create the directories (`Daily/` `Tickers/` `Sectors/` `Weekly/`) + **8 seed files**
   `references-roster` · `Portfolio` · `Decisions-Journal` · `Pre-Trade-Checklist` · `Macro` · `Daily/Daily-Index` · `Sectors/_Sectors-Index` · `_last-pull`
2. Ask for your **holdings, cash (incl. money-market), and timezone**
3. Pull the list once and produce the first daily brief

After that it's one sentence a day.

> 💡 You can run it with no positions at all — you still get the daily brief and sector notes, just with the holdings sections empty. Watching for a while before buying anything is a perfectly reasonable way to use it.

---

## 3. Full command table

### Pulling data

| You say | It does |
|---------|---------|
| "run KOL watch" / "pull the latest" | Full pull → daily brief → update ticker/sector notes → recalibrate prices → pass the gate → report the top 3 |
| "catch up on last night" | Incremental pull from the last checkpoint, **merged into the same day's brief** (never two files contradicting each other) |
| "pull 12h" / "pull the last week" | Uses your window instead of the default natural-day split |
| "today just @XX and @YY" | Pulls only those two — the coverage table marks the rest as not pulled rather than pretending they were |

### Trades and decisions

| You say | It does |
|---------|---------|
| "I bought 100 XXXX @ $85" | Updates the holdings table + ticker note + sector note, and **creates a decision entry** with 1-week / 1-month / 3-month review prompts |
| "I sold…" / "I closed XXXX" | Same, and records the close in the decision journal |
| "should I buy / add to XXXX now?" | Runs the 5 pre-trade checks, lays out the state, **and lets you decide** |
| "give me a stop-loss plan for XXXX" | Offers 4–5 **sourced** trigger candidates for you to pick from |
| "review for decision #3: I was wrong, because…" | Updates the review field + folds it into the decision-pattern index + writes the lesson into your pre-trade checklist |

### Looking things up

| You say | It does |
|---------|---------|
| "show me everything on XXXX" | Reads `Tickers/XXXX.md` (price history + who said what when + bear cases + your position) |
| "how has the XXXX sector evolved" | Reads the strength-rating table in `Sectors/<sector>.md` |
| "what has @XX been saying lately" | Reads that account's section in the daily briefs |
| "what happened over the past week" | Reads `Daily/Daily-Index.md` (one TLDR line per day) |

### Maintenance

| You say | It does |
|---------|---------|
| "add @XX" / "drop @YY" | Adjusts for this run and asks whether to write it into the list file (**never edits it unilaterally**) |
| "run the weekly" (it also asks on weekends) | 5 sections: holdings/sector evolution, KOL behavior, account-quality review, **your own decision-quality review**, next week's calendar |
| "@XX has been getting worse lately" | Logs the observation; **rating changes are a weekly-cadence decision** and need your confirmation |

---

## 4. Where the output lives

| You want | Open |
|----------|------|
| What happened today | `Daily/YYYY-MM-DD.md` |
| A 30-second look back over recent days | `Daily/Daily-Index.md` |
| Full portfolio + pending orders | `Portfolio.md` |
| Everything on one ticker | `Tickers/<TICKER>.md` |
| How a sector evolved | `Sectors/<sector>.md` |
| Every decision + its reviews | `Decisions-Journal.md` |
| What to check before trading | `Pre-Trade-Checklist.md` |
| This week's review | `Weekly/YYYY-W##.md` |

The daily brief itself has two zones: **the top is "current state"** (overwritten to the latest values on every pull) and **the bottom is "what happened"** (appended per batch, never deleted). So if you pull three times a day, the top always reflects the latest read and the middle holds the full signal log.

---

## 5. When something goes wrong

**I forgot to report a fill and only remembered days later**
Just say "I bought N XXXX at $Y on <date>, forgot to mention it." It backfills and dates the decision entry correctly. **Sooner is better** — while the position is wrong, your P&L, position weights and thesis health all drift wrong, **with no alarm whatsoever** (it has no broker connection, so it has no way to catch it).

**I didn't run it for several days**
Just say "run KOL watch" as usual. It reads the last checkpoint, and if the gap exceeds 36 hours it flags the gap length at the top of the brief and widens the window. ⚠️ If a prolific account posted a lot during the gap, one pull may not reach far enough back — the script warns ("earliest item on this page is still later than the cutoff"); when you see that, have it paginate.

**The gate blocked me from ending the session**
Something that should have been updated wasn't. It lists exactly what's missing — have it finish, then end. **Don't work around it by touching files** — preventing exactly that is the only reason the gate exists.

**One account failed to pull**
The coverage table marks it ❌. For a few failures, just have it retry those accounts; no need to re-run the whole batch.

**It refuses to give me a specific price level**
By design. Numbers with no data or stated principle behind them don't get written; you get direction instead. If you want a number, give it a computable anchor ("based on the 50-day MA" / "sized to bring the position back to 30%").

**I want to replace my whole list**
Edit `$KOL_VAULT/references-roster.md`; it takes effect on the next run. Methodology for building, rating and maintaining a list → [account-roster.md](skills/stock-kol-watch/references/account-roster.md).

**I want the advanced layers (live positions, broker research, etc.)**
See [advanced-extensions.md](skills/stock-kol-watch/references/advanced-extensions.md) — 7 sections, each with how to wire it and the known traps. The core deliberately ships without them; add them once the basics are routine.

---

## 6. Checklist

1. `export KOL_VAULT=...`
2. Copy the 5 starters into `$KOL_VAULT/references-roster.md` (and add a bear)
3. Configure the hook (optional) + verify it once
4. Say "initialize the vault and run KOL watch", tell it your holdings and cash (incl. money-market)
5. Then it's one sentence a day; **report every fill**
