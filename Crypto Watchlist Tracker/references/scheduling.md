# 每日两次跟踪的定时设置｜Scheduling the twice-daily tracker

Read this reference only when the user asks to create, update, inspect, pause, or remove recurring watchlist monitoring.

## Default schedule

- Timezone: user-specified; otherwise `Asia/Shanghai`.
- Morning run: every day at `09:00`.
- Evening run: every day at `21:00`.
- Crypto runs seven days a week.
- Destination: current task/thread unless the user explicitly requests another destination.

Use the client's native automation/task tool. Prefer two named tasks because separate morning and evening prompts are easier to inspect and update:

- `Crypto Watchlist Morning — <list name>`
- `Crypto Watchlist Evening — <list name>`

If the scheduler supports one task with two daily times and preserves mode context, one task is acceptable.

Before creating anything, search for an existing task with the same purpose or watchlist. Update it rather than creating duplicates. When the user changes the watchlist, timezone, official accounts, or destination, update both runs consistently.

## Prompt template

Embed the resolved configuration in the task prompt; do not rely on an external unstated default.

```text
Use $crypto-watchlist-tracker and Followin MCP to run the {MORNING_OR_EVENING} crypto watchlist report.

Watchlist: {WATCHLIST}
Timezone: {TIMEZONE}
Official accounts, if supplied: {OFFICIAL_ACCOUNTS_OR_NONE}
Destination: current task/thread

Use the previous successful report in this task as the comparison baseline. If none exists, use the latest 12 hours and label the output an initial snapshot.

Refresh every asset's Followin-covered project/news events, live price and 24-hour market data, technical indicators, KOL calls, current trader positions, and new trader actions. Deduplicate events and posts, keep event time separate from publication time, and distinguish current long/short posture from open/add/reduce/close actions.

Output the report using the skill's report-format reference. Include effective window, timezone, data timestamps, sample sizes, missing leaves, and Followin request IDs. Followin failure must be disclosed; never invent current data. Do not place orders or provide unconditional buy/sell instructions.
```

## Completion confirmation

After creating or updating the schedule, return:

- task IDs or equivalent scheduler identifiers;
- timezone and both run times;
- watchlist and optional official-account mapping;
- destination;
- whether Followin connectivity was verified;
- whether an immediate initial report was also run.

If the client has no automation capability, run one on-demand report and explicitly state that the 09:00/21:00 schedule was not created.
