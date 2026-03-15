Generate the Monday Weekly Strategy Brief automatically.

## Instructions:

1. Read these files in parallel:
   - `STATUS.md` — current workstream states
   - `STRATEGY.md` — check current phase and active decisions
   - `PLAYBOOK.md` — reference the Monday brief template

2. Run these commands in parallel:
   - `git log --oneline --since="7 days ago"` — what shipped last week
   - `git log --oneline --since="14 days ago" --until="7 days ago"` — context from the week before

3. Auto-fill the Monday brief template:

```
WEEKLY BRIEF — [today's date]

LAST WEEK:
- Shipped: [extract from git log]
- Learned: [extract from STATUS.md "What happened" sections]
- Blocked: [extract from STATUS.md blockers]

NUMBERS:
- Play Store: [extract from STATUS.md or note "not yet submitted"]
- Downloads this week: [from STATUS.md or "N/A — pre-launch"]
- DAU: [from STATUS.md or "N/A — pre-launch"]
- D1/D7 retention: [from STATUS.md or "N/A — pre-launch"]
- Landing page visits: [from STATUS.md or "unknown"]
- Revenue: [$0 — pre-monetization]

THIS WEEK I WANT TO:
1. [infer from STATUS.md "Next up" sections — highest priority first]
2. [second priority]
3. [third priority]

OPEN QUESTIONS:
- [extract from STATUS.md "Needs CEO decision" fields]

HUMANS TALKED TO THIS WEEK: [unknown — Jim fills this in]
```

4. Present the filled brief and ask Jim to:
   - Correct anything that's wrong
   - Fill in the NUMBERS and HUMANS sections with real data
   - Add any OPEN QUESTIONS

5. Once Jim confirms, suggest he paste this into a `/ceo` session for the CEO response.
