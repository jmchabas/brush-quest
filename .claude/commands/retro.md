Generate the Friday Week-End Retro automatically.

## Instructions:

1. Read these files in parallel:
   - `STATUS.md` — current workstream states and blockers
   - `STRATEGY.md` — check the current #1 priority

2. Run these commands in parallel:
   - `git log --oneline --since="monday"` — what shipped this week
   - `git diff --stat HEAD~10..HEAD` — scope of changes

3. Auto-fill the Friday retro template:

```
WEEK END — [today's date]

CURRENT #1 PRIORITY WAS: [extract from STATUS.md]
Did I do it? [assess based on git log and STATUS.md]
If not, why? [infer from blockers]

SHIPPED:
- [list from git log, grouped by workstream]

DISTRIBUTED:
- [unknown — Jim fills this in: posts, outreach, conversations]

HUMANS TALKED TO:
- [unknown — Jim fills this in]

LEARNED:
- [extract insights from STATUS.md "What happened" sections]

BLOCKERS GOING INTO NEXT WEEK:
- [extract from STATUS.md blockers tracker]
```

4. Present the filled retro and ask Jim to:
   - Fill in DISTRIBUTED and HUMANS TALKED TO
   - Add any LEARNED insights not captured in STATUS.md
   - Confirm or correct the priority assessment

5. Once Jim confirms, suggest he paste this into a `/ceo` session for scoring and next-week preview.
