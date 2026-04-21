# L3 — Frugal / Scrappy Lens

**Question:** 50 qualified parent installs to Play internal testing in 14 days via organic IG Reels. $0–$500, ~10 hrs/week, one founder + agents.

---

## 1. Free distribution surfaces (where parents of 4–8yo actually are)

| Surface | Rough reach | Effort | "Winning" looks like |
|---|---|---|---|
| **Instagram Reels (organic)** — hashtags: #toothbrushing, #pickyeater, #gentleparenting, #momsofboys, #momhack, #bedtimeroutine | Algorithmic, uncapped | 6–8 hr/wk | 1 Reel >10k views = ~30–80 profile visits = ~5–15 installs at our CR |
| **r/Parenting** (4.5M), **r/Mommit** (1.2M), **r/daddit** (900k), **r/ScienceBasedParenting** (360k), **r/toddlers** (180k), **r/Parenting4to9YearOlds** (~15k, tight fit) | 6.7M aggregate | 1–2 hr/wk | 1 genuine story post → 50–200 upvotes → 20–60 installs if link survives |
| **r/AndroidApps** (400k), **r/androidtesting** (~25k — explicit internal-tester recruiting) | ~425k | 1 hr/wk | Internal-tester posts pull 10–40 testers in a day — unusually high fit for our exact ask |
| **FB groups** — "Tired as a Mother" (~250k), "Big Little Feelings community", "Respectful Parenting Community" (~80k), "Moms of Little Boys Support Group" (~120k), regional "Mom groups of [City]" | 1M+ aggregate | 2–3 hr/wk | Admin-approved post → 30–150 comments → 10–30 installs (FB link suppression is brutal; bio-link + DM pattern works better) |
| **Kid-tech / parenting Substacks & blogs** — Techcrunch-for-parents style: *Screen Time Consultant* (Emily Cherkin), *Ask The Kid Whisperer*, *Parent Data* (Emily Oster), *What Fresh Hell: Laughing in the Face of Motherhood* podcast | 50k–500k each | 3–5 hr per pitch | 1 mention = 20–100 installs over a week (hunch) |
| **Pediatric dentist offices** — local, Oliver's own dentist first. QR poster in waiting room | 20–100 parents/wk per office | 2 hr setup + print | 5–15 installs per office per month; compounds |
| **PTA / school parent email chains** — Oliver's 2nd-grade class list, neighborhood elem schools | 30–200 parents per list | 1 hr outreach | Warm referral; 20–40% CR from these. Highest install-per-hour channel |
| **Product Hunt (Kids/Family)**, **AlternativeTo**, **AppAgg** (Android-specific) | 5k–30k eyeballs on launch day | 3 hr prep | PH launch drags 50–200 signups if feature-of-the-day (hunch: hard without warm list) |
| **Discord** — *Indie Parenting Apps*, *r/androiddev* Discord, *Flutter Community* parent builders channel | Small (5–20k), engaged | 1 hr/wk | Feedback not installs — use for QA recruiting, not volume |

---

## 2. Agent-runnable zero-cost plays

### Play A — Reels content engine (the core ask)
- **Agent action:** Claude-Code executor generates 3 Reels scripts/week from a locked format library (hook/payoff templates: "Things my 7yo hates #7: brushing teeth… until this"). Writes caption + first-comment CTA ("link in bio for Android early test"). Drafts on-screen text overlays. Saves gameplay clip specs (what to film, what beats to cut on).
- **MCP needed:** ElevenLabs (have it — use Buddy/George voice for continuity); ai-image-gen (have it — thumbnail stills); claude-in-chrome (have it — schedule via Creator Studio or Meta Business Suite web). **Missing:** native Instagram Graph API MCP — workaround: Chrome MCP drives Meta Business Suite web for scheduling. Also missing: CapCut/video-editing MCP — Jim edits on phone (10 min/Reel).
- **Human-in-loop:** Jim films 60 sec of gameplay + says one line to camera (face-of-brand risk: agreed NOT Jim — use hero/mascot voiceover + hands-only shots of phone/brushing). Approves caption.
- **MVP week 1:** 5 Reels posted (daily Mon–Fri). Track views, profile visits, link-in-bio clicks. Kill the 3 worst formats by day 10.

### Play B — r/androidtesting internal-tester recruiting
- **Agent action:** Agent drafts an honest post — "Brush Quest, Android-only early access, 7yo dad building it, looking for 20 testers with kids 4–8" — follows sub rules exactly (GPlay link, package name, tester group join link). Monitors comments, drafts replies for Jim's approval.
- **MCP needed:** claude-in-chrome (have it — Reddit web). **Missing:** dedicated Reddit MCP — Chrome MCP is sufficient but slower.
- **Human-in-loop:** Jim approves post copy + replies every 12 hrs.
- **MVP week 1:** One post in r/androidtesting + one cross-post to r/AndroidApps "apps I'm building" thread. Expected: 15–40 testers, 10–20 convert to real installs (distinct from the 50 parent target — these are testers-of-convenience, dilute quality). Filter for parents in replies.

### Play C — Reddit parent-story posts (Reels amplifier)
- **Agent action:** Agent writes a first-person story post for r/Parenting / r/Mommit: "My 7yo wouldn't brush for 2 min until we gamified it — share what worked for you." Self-link policy is strict on these subs — comment the Reel URL only if asked, keep the post itself link-free. Drafts 3–5 responses to plausible top comments.
- **MCP needed:** claude-in-chrome. **Missing:** Reddit API MCP — would let agent track karma/removals automatically.
- **Human-in-loop:** Jim posts from his own account (age matters for mod trust). Approves responses.
- **MVP week 1:** 2 posts across r/Parenting, r/Mommit, r/daddit. 1 will get removed (odds). Reels in profile bio catches downstream traffic from the survivor.

---

## 3. Money traps to avoid

- **Don't run Meta/Google App Install ads until organic hits ≥1 Reel >50k views.** Without creative-market fit, CPI for a kids-app parent targeting will be $6–12. $500 buys ~60 installs on a cold account with no pixel — worse ROI than hustle.
- **Don't pay a "mom influencer" <50k followers for a flat $200–$500 post.** Engagement there is often 1–2% and conversion to installs is near zero without a warm relationship. Free collab (app + $20 Amazon gift card) performs the same or better.
- **Don't buy Product Hunt launch services / "upvote packages."** PH kids/family has thin traffic for our ICP, and paid upvoting violates ToS. Free launch only.

---

## 4. Ranked takeaway (volume per hour)

| Rank | Play | Confidence | Installs/hr (hunch) |
|---|---|---|---|
| 1 | **r/androidtesting post** (Play B) | HIGH | 8–15 |
| 2 | **PTA/local school email** (Oliver's school) | HIGH | 5–10 (caps ~30 total) |
| 3 | **IG Reels content engine** (Play A) | MEDIUM | 2–6 — but only channel with no ceiling |
| 4 | **Reddit parent stories** (Play C) | MEDIUM | 2–5 |
| 5 | Pediatric-dentist QR posters | MEDIUM | 1–3, compounds over months |
| 6 | FB mom groups | LOW | 1–2 (link suppression + admin moderation) |
| 7 | Substack pitches | LOW | 0–5, long tail |

**Ship this week (if forced to pick one):** r/androidtesting post + 1 Reel the same day pointing to the tester link. That single combo should deliver 15–25 of the 50 installs by day 3 and buys time for the Reels engine to find creative-market fit.

---

## 5. Failure modes

- **Grinding Reels without a winning hook.** Algorithmic distribution is free but not linear — 20 mediocre Reels = 2k views total; 1 viral Reel = 500k. Without a hook iteration discipline (kill formats at <1k views in 48h), Jim burns 10 hrs/week for ~5 installs.
- **Mixing tester recruiting with parent marketing.** r/androidtesting installs count toward the 50 but are low-quality — they uninstall after 3 days. If the PRD's success metric is "50 installs" without a D3-retention gate, we'll hit the number and have nothing to show for it. Fix: require D3 brush event on 30 of 50.
- **Link suppression eats the win.** FB groups + Reddit parent subs shadow-remove Play Store links. Plan for it: send traffic to brushquest.app landing page (already live, QR + email capture) as the bridge, not the raw Play URL. Otherwise you'll "post everywhere" and see zero referrer attribution — the classic frugal-scrappy failure.
