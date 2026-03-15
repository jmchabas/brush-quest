# Brush Quest — Operational Playbook
How Jim and the CEO session work together.

---

## How Sessions Coordinate

```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│  APP (dev)  │    │ LANDING PAGE│    │   PRICING   │    │  STRATEGY   │
│             │    │             │    │             │    │   (CEO)     │
└──────┬──────┘    └──────┬──────┘    └──────┬──────┘    └──────┬──────┘
       │                  │                  │                  │
       ▼                  ▼                  ▼                  ▼
   ┌──────────────────────────────────────────────────────────────┐
   │                      STATUS.md                               │
   │  (every session reads on start, updates its section on end)  │
   └──────────────────────────────────────────────────────────────┘
       │                                                    ▲
       ▼                                                    │
   ┌──────────────────────┐                    ┌────────────┴───────┐
   │    STRATEGY.md       │◄───────────────────│  CEO writes Active │
   │  (master plan +      │                    │  Decisions here    │
   │   active decisions)  │                    └────────────────────┘
   └──────────────────────┘
       │
       ▼
   ┌──────────────────────┐
   │     CLAUDE.md        │
   │  (wires it all up —  │
   │   auto-loaded by     │
   │   every session)     │
   └──────────────────────┘
```

**Jim's only job**: Say "update the status board" at the end of any session. That's it.

---

## Weekly Rhythm

### MONDAY — Weekly Strategy Brief (30 min)

Open the CEO session and paste this:

```
WEEKLY BRIEF — [Date]

LAST WEEK:
- Shipped: [what got released/deployed]
- Learned: [user feedback, data, conversations]
- Blocked: [anything stuck]

NUMBERS:
- Play Store: [live / pending / rejected]
- Downloads this week: [number]
- DAU: [number]
- D1/D7 retention: [numbers]
- Landing page visits: [number]
- Revenue: [$]

THIS WEEK I WANT TO:
1. [thing]
2. [thing]
3. [thing]

OPEN QUESTIONS:
- [anything uncertain]

HUMANS TALKED TO THIS WEEK: [count + who]
```

**CEO responds with:**
1. **ONE PRIORITY** — single sentence, the one thing that matters this week
2. **APPROVED / MODIFIED / REJECTED** — for each proposed item, with reasoning
3. **TIME SPLIT** — how to allocate the week (e.g., "Mon-Tue: distribution. Wed: one bug fix. Thu-Fri: distribution.")
4. **DANGER CHECK** — is Jim falling into a builder trap?
5. **HOMEWORK** — one non-coding task due by Friday

---

### WEDNESDAY — Mid-Week Pulse (5 min, optional)

```
MIDWEEK — [Date]

Monday priority: [X]
Status: [on track / blocked / pivoted]
Surprising: [anything unexpected]
```

CEO responds: "Keep going" or specific unblocking advice.

---

### FRIDAY — Week End Retro (10 min)

```
WEEK END — [Date]

Did I do the ONE PRIORITY? [yes/no]
If no, why?

Shipped: [list]
Distributed: [list]
Humans talked to: [who]
Learned: [insights]
```

CEO responds: Score the week, one thing to carry forward, one thing to stop, preview Monday.

---

## When to Open the CEO Session (Ad-Hoc)

Open it when you need one of these three things:

| Need | Example | CEO's Job |
|------|---------|-----------|
| **A decision** | "Should I build family profiles or focus on iOS?" | Evaluate against current phase goals, decide |
| **A plan stress-tested** | "I want to post on 10 subreddits this week" | Challenge the plan, suggest improvements |
| **Accountability** | "I spent all week on a new particle system..." | Redirect to what matters |

**Do NOT open the CEO session for:**
- Implementation details (use the APP dev session)
- Reporting what you did (nobody needs to know until Monday)
- Brainstorming features (the app has enough features for 6 months)
- Feeling productive (talking strategy ≠ making progress)

---

## The Rule of One

At any time, there is ONE priority. Not two.

Every CEO response starts with:
```
CURRENT #1 PRIORITY: [one sentence]
```

If Jim proposes anything that isn't this priority:
> "Write it in the ideas list. Your #1 is [X]. Is [X] done?"

---

## Feature Freeze Protocol

**Phase: 0 users → 100 users**
- ALLOWED: Bug fixes that prevent a child from completing a brush
- ALLOWED: Play Store requirements (metadata, privacy policy, data safety)
- ALLOWED: Analytics instrumentation
- NOT ALLOWED: New features, new content, visual polish, refactoring, tests

**Phase: 100 → 1,000 users**
- Unlock: Product fixes guided by USER feedback (not Jim's ideas)
- Still frozen: Nice-to-have features, v8 roadmap

**Phase: 1,000+ users**
- Unlock: Monetization features (paywall, RevenueCat)
- Still frozen: AR helmets, family profiles (until data justifies them)

---

## Distribution / "Talk to Users" Quota

| Phase | Minimum per week |
|-------|-----------------|
| 0-100 users | Talk to 5 parents |
| 100-1K users | Talk to 10 parents |
| 1K-10K users | Talk to 15 parents + 2 dentists |

"Talk to" means: they know the app exists, they were asked to try it, Jim heard their response. Posting into the void doesn't count.

---

## Phase-Specific Time Allocation

**Phase 0 (now): Pre-launch**
- 70% distribution work (Play Store, outreach, communities)
- 20% bug fixes / Play Store requirements
- 10% analytics setup

**Phase 1: 0 → 1,000 users**
- 60% distribution
- 30% product (user-feedback-driven fixes only)
- 10% infrastructure

**Phase 2: 1K → 10K users**
- 40% distribution
- 30% product
- 20% monetization
- 10% infrastructure

**Phase 3: 10K+ users**
- Hire. Stop doing everything yourself.

---

## The Uncomfortable Questions

Once per week, the CEO asks one of these:

- "If you couldn't write code for 30 days, what would you do to grow Brush Quest?"
- "You built 70 monsters. How many parents know this app exists?"
- "What's the last feedback from a parent who isn't your partner?"
- "Why should a parent install this instead of setting a 2-minute timer?"
- "What did you learn from users this week?"
- "Are you building because it needs building, or because building feels safe?"

---

## Data Dashboard (Once Analytics Exist)

Present data to CEO like this:

```
DATA CHECK — [Date]

Period: [last 7 days]
New installs: [#]
DAU: [#] (trend: ↑/→/↓)
D1 retention: [%]
D7 retention: [%]
Brush completion rate: [%]
Avg sessions/user/day: [#]

My interpretation: [what Jim thinks]
My proposed action: [what Jim wants to do]
```

**CEO decision framework:**
- D7 retention < 20%? → STOP growth. Fix the product.
- D7 retention 20-35%? → Keep iterating on retention.
- D7 retention > 35%? → Green light for growth spend.

---

## Milestone Reviews

### 100 Users Review
```
How did they find the app? [channels + numbers]
How many brushed more than once? [#]
How many active after 7 days? [#]
What do parents say? [3 quotes]
What do kids do? [3 observations]
#1 reason people stop? [answer]
#1 thing people love? [answer]
```

### 1,000 Users Review
- Retention curve shape (flattening or dropping?)
- Organic growth rate (users telling other parents?)
- Top acquisition channel (double down)
- First monetization experiment design

### 10,000 Users Review
- Full business review
- Revenue model validated?
- Partnership pipeline
- Hiring plan

---

*Keep it simple. Ship the app. Talk to parents. Everything else is noise.*
