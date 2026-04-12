# Brush Quest GTM Engine v3.0

**Date:** 2026-04-03
**Status:** FINAL -- all 5 founder decisions resolved
**Author:** Synthesized from 6 rounds (11 agents) of strategy, critique, and operational planning
**For:** Jim Chabas, solo founder (full-time employed elsewhere)
**Production launch target:** April 11, 2026
**Monthly budget ceiling:** $1,000-2,000

This document replaces all previous rounds (R1-R5). It is the only GTM document Jim needs.

---

## How to Use This Document

This is not a strategy deck. It is an operating manual. Use it the way you use a cookbook: find the section for what you need to do next, follow the steps, check the result.

**If you are starting today:** Read "The Engine at a Glance," then go directly to "Week 0: Setup" and start checking boxes.

**Every Monday morning:** Open "Jim's Weekly Rhythm" for your current month. Do the Monday tasks.

**Every month:** Copy the "Monthly Review Template" and fill it in. Use the "Metrics Dashboard" section to mark Green/Yellow/Red. Use the "Channel Activation Tree" to decide what to add or cut.

**When something goes wrong:** Go to the "Contingency Playbook" and find your scenario.

**When you hit a decision point:** Check the "Phase Transitions" section for prerequisites.

The document is long because it is complete. You do not need to read it end-to-end. Use the table of contents.

---

## Core Messaging Framework

These 6 messages appear in every parent-facing touchpoint: Play Store listing, landing page, dentist materials, PR pitches, social content, and share cards. They are ordered by priority -- lead with #1, close with #6.

### 1. "No ads. No tracking. No data collected from your child."

The headline trust signal. Above the fold on the landing page, in the Play Store short description, on the first screenshot, in bold on every dentist handout. Parents evaluating kids apps are looking for reasons to say no. Remove the biggest one immediately.

### 2. "2 minutes of better screen time."

Pre-empts the screen time guilt that is the #1 psychological barrier to parent adoption. This is not more screen time -- it replaces 10 minutes of arguing with 2 minutes of guided brushing. Every testimonial should acknowledge screen time: "I know, another app. But hear me out -- 2 minutes and he actually brushes."

### 3. "Works with any toothbrush."

The differentiator against Oral-B and Philips, whose apps require their branded hardware. Brush Quest works with the $3 toothbrush from Target. This belongs in the first three lines of the Play Store description.

### 4. "Built by a dad who was tired of the bedtime brushing battle."

The authentic origin story. Not a marketing department, not a toothbrush company. A real dad, for his real kid. This story is the backbone of PR pitches, the Reddit post, the dentist conversation, and the TikTok content.

### 5. "Recommended by pediatric dentists."

Unlocked once 3+ dentists are actively partnered. The highest-trust endorsement in the category. No parent second-guesses a dentist recommendation. Do NOT use this message until the partnerships exist.

### 6. "Still fun after a week. 10 worlds. 70 monsters. Heroes that evolve."

Addresses the "tried and abandoned" fatigue. Every parent has downloaded 3-5 apps their kid abandoned. The depth of content is the retention differentiator, positioned as the answer to "will my kid stick with it?"

### Competitive Framing

Used in PR and dentist conversations. Never name competitors in public marketing.

| Competitor Type | Their Weakness | Brush Quest's Answer |
|----------------|---------------|---------------------|
| **Free brand apps** (Oral-B, Colgate) | Marketing tools for toothbrush sales; kids get bored in a week; require specific toothbrush | "Built to change behavior, not sell toothbrushes. Works with any toothbrush. 10 worlds of content." |
| **Simple timer apps** (dozens, free) | Timer tells kids WHEN to stop, not WHERE to brush. No engagement. | "A timer doesn't teach technique. Brush Quest guides through every section and makes it an adventure." |
| **Pokemon Smile** (discontinued 2024) | Shut down. Content-thin. | "Actively developed by a solo founder. Updated weekly." |

**Short response for "Why not just use Oral-B's free app?":**

> "Free apps sell toothbrushes. Brush Quest builds habits. Works with any toothbrush."

**Full response (for PR, in-person, detailed comments):**

> "Free brushing apps are marketing tools built by toothbrush companies. They do the minimum -- a 2-minute timer with stickers -- because their real product is the toothbrush. Kids get bored in a week. Brush Quest is the product: 10 worlds, 70 monsters, heroes that evolve, a mouth guide that teaches WHERE to brush. It works with any toothbrush and it is built by a dad who uses it with his own kids every day."

---

## The Engine at a Glance

**What:** A GTM engine for one person with 8 hours/week and zero existing audience.

**How:** Three things in sequence: **earn trust** (months 1-3), **build proof** (months 4-6), **scale what works** (months 7-12).

**Starting channels:** Play Store listing optimization, in-app review prompt, one Reddit origin story. Everything else activates only when trigger metrics are met.

**Automation:** Claude Code drafts content; Jim reviews, edits, and posts. Two cron jobs. Google Sheets CRM. Buffer for Instagram scheduling. That is the entire stack.

**Year 1 realistic targets:**

| Metric | Month 1 | Month 3 | Month 6 | Month 12 |
|--------|---------|---------|---------|----------|
| Total installs | 30-75 | 200-500 | 1,000-3,000 | 5,000-20,000 |
| Monthly active users | 20-50 | 100-300 | 500-1,500 | 2,500-10,000 |
| D7 retention | 25%+ | 30%+ | 35%+ | 35%+ |
| Play Store rating | 4.5+ | 4.5+ | 4.5+ | 4.5+ |
| Reviews | 5-10 | 25-50 | 75-200 | 300-1,000 |

**Year 1 cash cost (no paid ads):** $575-1,300 total. Paid ads add $3,000-15,000 if triggered.

**The 3 rules:**
1. If D7 retention drops below 20%, STOP ALL GTM and fix the product. Nothing else matters.
2. Never run more than 3 active channels simultaneously. Focus beats breadth.
3. Recovery week every 4th week is non-negotiable. The worst outcome is not slow growth -- it is Jim burning out in Month 3.

---

## Week 0: Setup (Detailed Checklist)

**Purpose:** Build the infrastructure so Week 1 is execution, not setup.
**Time budget:** 10-12 hours of GTM setup over 3-5 days, plus 8-10 hours of engineering (done during normal coding hours).
**Cash budget:** ~$375-500.
**This is NOT GTM time. This is infrastructure.**

### Day 1: Digital Infrastructure (3 hours)

**Hour 1: Accounts and Alerts**

- [ ] Create TikTok account: @brushquest. Set up profile (bio, profile pic, link to brushquest.app). Do NOT post yet. (20 min)
- [ ] Create Instagram business account: @brushquest. Same setup. (15 min)
- [ ] Set up Google Alerts: "Brush Quest", "brushquest", "kids brushing app", "Brusheez", "Jim Chabas". Delivery: once a day, to Gmail. (10 min)
- [ ] Set up Talkwalker Alerts: same keywords. (10 min)
- [ ] Turn on Play Console email notifications: all 1-3 star reviews. (5 min)

**Hour 2: Tools Setup**

- [ ] Set up Buffer free tier: connect Instagram. (30 min)
  - Note: Buffer free tier = 3 channels, 10 posts per channel queue. Reels CANNOT be scheduled on free tier -- only $6/mo Essentials plan. Feed posts only through Buffer for now.
- [ ] Set up AppFollow free tier: connect Brush Quest Play Store listing. (20 min)
- [ ] Sign up for HARO/Connectively: select "Technology", "Lifestyle", "Family/Parenting" categories. (10 min)

**Hour 3: CRM and Templates**

- [ ] Create Google Sheets CRM with 3 tabs. (30 min total)
  - **Dentist Partners tab:** Practice Name | Dentist Name | Email | Phone | Address | Distance (mi) | Source | Ref Code | Date First Contact | Contact Method | Status (dropdown: researched/contacted/follow-up/active/declined/dormant) | Cards Delivered | Cards Delivered Date | Last Contact | Next Action | Next Action Date | Installs (est) | Notes
  - **Press/Media tab:** Outlet | Reporter Name | Email | Beat | Recent Article URL | Date Pitched | Pitch Angle | Status (researched/pitched/follow-up/published/declined) | Coverage URL | Notes
  - **Weekly Metrics tab:** Week | Installs (total) | Installs (this week) | Play Store Rating | Review Count | D7 Retention | D30 Retention | TikTok Views | Instagram Followers | Dentist Partners (active) | Top Channel | Notes
  - Conditional formatting: yellow when Next Action Date is within 3 days of today; red when past due; green when Status = "active"
- [ ] Create Gmail canned responses: 5 templates. (15 min)
  1. Positive review thanks
  2. Bug report acknowledgment
  3. Feature request acknowledgment
  4. Screen time concern response
  5. Privacy question response
- [ ] Populate dentist tab: identify 10 pediatric dentists within 15 miles. Start with Oliver's dentist. (15 min)

### Day 2: Content Infrastructure (2.5 hours)

**Hour 4: Claude Code GTM Setup**

- [ ] Create directory structure (5 min):
  ```
  docs/gtm-content/
    batches/
    templates/
    assets/
    outreach/dentists/
    outreach/press/
    competitor-scans/
    metrics/
  ```
- [ ] Write `docs/gtm-content/templates/weekly-batch.md` prompt template. (15 min)
- [ ] Write `docs/gtm-content/templates/dentist-outreach.md` prompt template. (15 min)
- [ ] Write `docs/gtm-content/templates/pr-pitch.md` prompt template. (15 min)
- [ ] Write `docs/gtm-content/templates/review-response.md` prompt template. (10 min)
- [ ] Write `docs/gtm-content/assets/messaging-framework.md` -- copy the 6 core messages from this document. (10 min)
- [ ] Write `docs/gtm-content/assets/competitive-responses.md` -- copy competitive framing from this document. (10 min)
- [ ] Write `docs/gtm-content/assets/hashtag-sets.md`: pre-research 5 hashtag groups (parenting, dental health, indie app dev, kids activities, dad life). (20 min)

**Hours 5-6: Pre-generate Content**

- [ ] Generate 50 Monster of the Week captions (one per monster) in a single Claude session. Save to `docs/gtm-content/assets/monster-captions.md`. (45 min)
- [ ] Draft Reddit origin story for r/Daddit. Save to `docs/gtm-content/outreach/reddit-daddit-draft.md`. Do NOT post. (60 min)
- [ ] Run the first weekly batch generation manually to test the prompt. Refine until output quality is good. (30 min)

### Day 3: Outsource Design + Play Store (3-4 hours)

**Hour 7: Commission Fiverr Work**

- [ ] Commission media kit PDF: app screenshots, Jim's headshot, logo, one-page fact sheet. Find a designer with kids/education portfolio. Budget: $75-150. (30 min browsing + briefing)
- [ ] Commission partner info sheet PDF: one-page dentist-facing document. Budget: $50-75. (15 min briefing)
- [ ] Commission "prescription card" design: small card, professional look, space for dentist to write their name, QR code placeholder. "Dr. ___ recommends Brush Quest for better brushing habits. Scan to download." Budget: $50-75. (15 min briefing)
- [ ] Order QR code business cards from Vistaprint: use `brushquest.app/go?ref=general` URL. Budget: $50 for 250 cards. (15 min)

**Hours 8-10: Play Store Listing Polish**

- [ ] Write short description (80 chars): "No ads. Guides brushing. Works with any toothbrush. Kids love it. Free." (15 min with Claude)
- [ ] Write full description using the messaging framework. Lead with outcomes, not features. Include "works with any toothbrush" and "no data collection." (45 min with Claude)
- [ ] Create 8 parent-facing screenshots: (30 min evaluation; creation may be Fiverr or Canva)
  1. Hero shot: gameplay with "Turn brushing into an adventure" overlay
  2. Outcome: "Kids ask to brush. Parents get their evenings back."
  3. Trust: "Free. No ads. No data collection from your child."
  4. How it works: visual flow (tap BRUSH > fight monsters > win stars)
  5. Mouth guide: "Guides your child through every section of their mouth"
  6. Depth: "10 worlds. 70 monsters. Heroes that evolve."
  7. Parental controls: timer settings, sound toggle, stats
  8. "Works with any toothbrush. Built by a dad, for his kid."
- [ ] Create a feature graphic. (30 min with Canva or Fiverr)
- [ ] Record 30-second Play Store preview video: screen recording of a full brush session with parent voiceover. (1 hour)
- [ ] Submit to "Designed for Families" program in Play Console. (15 min)
- [ ] Submit to Common Sense Media for review (free, 4-8 week review). (30 min)
- [ ] Apply for Parents' Choice Award ($150 fee, 8-12 week review). (30 min)

### Day 4: Engineering (4 hours)

These are product work hours, not GTM time.

- [ ] **In-app review prompt** -- the #1 growth feature. (2-3 hrs)
  - Package: `in_app_review: ^2.0.9`
  - Create `lib/services/review_prompt_service.dart`
  - Trigger: after 5th brush session, user NOT prompted before, 3+ days since first brush, `InAppReview.isAvailable()` returns true
  - Call from `victory_screen.dart` AFTER victory animation completes (do not interrupt the celebration). Wait 1 second, then `requestReview()`.
  - Analytics: `logReviewPromptShown()`
- [ ] **UTM redirect page** at `docs/go/index.html` for dentist card attribution. (1-2 hrs)
  - Reads `ref` query param, constructs Play Store URL with UTM parameters
  - URL format: `brushquest.app/go?ref=REFCODE` where REFCODE matches dentist CRM column
  - Also supports: `?ref=reddit`, `?ref=tiktok`, `?ref=press-alameda`, `?ref=share`

### Day 5: Engineering continued

- [ ] **GTM analytics events** -- add to analytics_service.dart. (1 hr)
  - `logShareCardGenerated(milestone)`, `logShareCardShared(milestone)`, `logReviewPromptShown()`, `logFirstBrushComplete()`, `logDayNReturn(dayN)`
- [ ] **Claude Code remote triggers** -- set up with `/schedule` skill. (1 hr)
  - Sunday 9am PT: weekly content batch (creates PR with `docs/gtm-content/batches/YYYY-MM-DD.md`)
  - 1st Monday 8am PT: monthly competitor scan (creates PR with `docs/gtm-content/competitor-scans/YYYY-MM.md`)
- [ ] **Share card generation** -- the only truly viral mechanic. (4-5 hrs, may extend to Day 6)
  - Packages: `share_plus: ^10.1.4`
  - Approach: `RepaintBoundary` + `toImage()` + `Share.shareXFiles()`
  - Trigger moments for v1: 7-day streak, new hero unlocked, all monsters in a world defeated
  - Card design: dark space background, hero image, achievement text, "Space Ranger" title (NOT child's real name), Brush Quest logo + "brushquest.app" text
  - Analytics: `logShareCardGenerated`, `logShareCardShared`

### Week 0 Summary

| Category | Jim's Time | Cash Spend |
|----------|-----------|------------|
| Digital infrastructure (accounts, tools, CRM) | 3 hrs | $0 |
| Content infrastructure (templates, pre-gen) | 2.5 hrs | $0 |
| Fiverr commissions (briefing + review) | 2 hrs | $225-350 |
| Play Store listing polish | 3-4 hrs | $150 (Parents' Choice) |
| Engineering (review prompt, UTM, share card, analytics, cron) | 8-10 hrs | $0 |
| **TOTAL** | **~19-22 hrs** | **~$375-500** |

Engineering hours (8-10) are product work, not GTM time. The GTM setup itself is 10-12 hours.

---

## Month 1 (April 2026): Three Things, Done Well

**Theme:** Launch to production. Nail the store listing. Get the first real users.
**GTM budget:** 8 hrs/week maximum.
**Cash budget:** $0 (Week 0 spend already happened).

### The Only 3 Things That Matter

**1. Play Store listing is polished and live**

- Monitor impressions, store listing visitors, and install conversion rate weekly.
- Respond to every review within 24 hours (5 min per review, using Gmail templates).
- If CVR < 15% after 2 weeks: rewrite the short description and swap screenshot order.

**2. Reddit origin story on r/Daddit (timed with production launch)**

- Post the story drafted in Week 0.
- Engage authentically with every comment for 48 hours (budget 3-4 hours over 2 days).
- Do NOT mention the app in the first paragraph. Tell the story. The app link goes at the end.
- One week later: post on r/AndroidApps with a different angle (indie dev, technical story).
- One week after that: post on r/Parenting (if r/Daddit went well).
- ONE subreddit per week maximum. Reddit flags cross-posting as spam.

**3. First 5 dentist outreach attempts**

- Start with Oliver's dentist (warm intro — can visit in person since it's convenient).
- Email 4 more local practices using Claude-drafted personalized emails.
- Goal: 2-3 say yes. Mail prescription cards to responsive practices (or drop off when convenient, not as a dedicated trip).
- Do NOT email 20 dentists. Five genuine conversations > twenty cold emails.

### Month 1 Weekly Rhythm

**Rule: Mornings are for building (product). Afternoons are for GTM. One zero-GTM day per week.**

| Day | Activity | Time |
|-----|----------|------|
| **Monday** | Check Play Store reviews + respond. Send 1-2 dentist emails (Claude drafts). Check install numbers. Scan dentist CRM for follow-ups. | 1.5 hrs |
| **Tuesday** | Film 1 video with Oliver (if cooperative). If not cooperative, skip -- do not force it. | 30 min |
| **Wednesday** | Edit + post video to TikTok (CapCut). Manually cross-post to Instagram Reels (download, re-upload, paste caption). | 45 min |
| **Thursday** | Review Claude's content batch PR. Approve/tweak. Copy-paste approved posts into Buffer. Reply to social comments. | 45 min |
| **Friday** | **Zero GTM.** No outreach, no social, no metrics. | 0 min |
| **Saturday** | Optional: second video filming with Oliver (30 min). No GTM obligations. | 0-30 min |
| **Sunday** | Claude content batch generation (auto-PR). Review + metrics tracker update. | 1 hr |
| **Total** | | **~5.5-7 hrs** |

Remaining 1-2.5 hours are buffer for overflow.

**Recovery week (Week 4):** Half the GTM activities. Skip dentist outreach and video filming. Sunday batch + review responses only.

### What Jim Does NOT Do in Month 1

Explicitly deferred. Not because they are bad ideas, but because one person cannot do them well alongside the 3 core activities.

- Pinterest, Facebook Groups, HARO, podcast pitching, micro-influencer outreach, UGC campaigns, PTA outreach, Product Hunt, partner landing page, press page, IndieHackers

### Month 1 Success Metrics

| Metric | Realistic | Stretch |
|--------|-----------|---------|
| Total installs | 30-75 | 150+ |
| Play Store rating | 4.5+ | 4.7+ |
| Reviews | 5-10 | 20+ |
| Reddit origin story upvotes | 50-200 | 500+ |
| Dentist partners saying yes | 2-3 | 5 |
| TikTok videos posted | 6-8 | 12 |
| D7 retention | 25%+ | 35%+ |

**If D7 retention is below 20%: STOP ALL GTM. Fix the product. No amount of distribution saves a leaky bucket.**

---

## Month 2-3 (May-June 2026): Validate and Double Down

**Theme:** What produced installs? Do more. Cut what didn't work.
**GTM budget:** 8 hrs/week. Recovery week in Weeks 8 and 12.
**Cash budget:** $0-100/mo (card reprints, gas). Plus $295 for Mom's Choice Award in Month 3.

### Month 2: Add Only These

Everything from Month 1 continues. Add:

- **HARO/Connectively: weekly check, not daily.** Claude scans Monday morning, flags relevant queries. Jim reviews in 15 min. (15 min/week)
- **1 PR pitch per week.** Alameda Sun first (lowest bar), then Berkeleyside, then East Bay Times. Claude drafts, Jim personalizes and sends. (30 min/week)
- **IndieHackers "how I built it" story.** One-time, 2 hours writing + 1 hour engaging with comments.
- **Build share card feature** if not done in Week 0.
- **If Reddit origin story > 200 upvotes:** post a "1 month later" update on r/Daddit.

### Month 2 Decision Points

- Is TikTok getting traction (avg 500+ views)? Yes: continue 2/week. No: reduce to 1/week, reallocate to dentist outreach.
- Are dentist partners generating installs? Check UTM data. If yes: this is the primary channel.
- Total installs < 50 from all GTM effort: the problem is the store listing or the product, not distribution. Pause GTM. Fix the funnel.

### Month 3: First Scaling Decisions

- **Product Hunt launch** IF 20+ reviews and 4.3+ stars. One-time: 4-6 hours over 2 days.
- **Show HN post** 3-7 days after Product Hunt.
- **A/B test store listing** IF 500+ installs. Short description variants first.
- **Expand dentist outreach to 20 total** via email-only.
- **Mom's Choice Award application** ($295, 6-8 week review).

### End of Month 3: The Cut

Any channel producing zero measurable installs gets cut. No "but it might work eventually." Rank by installs per hour of Jim's time. Keep the top 2-3. Drop everything else.

---

## Month 4-6 (July-September 2026): Scale Proven Channels

**Theme:** More of what works. Back-to-school push. Trigger-based channel additions only.
**GTM budget:** 6-8 hrs/week. Recovery week every 4th week.
**Cash budget:** $100-500/mo (tools + small tests if retention proves out).

### Add When Triggers Are Met

| New Activity | Trigger | Time Cost |
|-------------|---------|-----------|
| Grandparent Facebook messaging | Premium tier live OR 1,000+ installs | 1 hr/week |
| Facebook Group participation | 500+ followers on any platform | 30 min/week |
| Podcast pitching | DEFERRED — requires marketing hire | N/A |
| HARO daily scanning (upgrade) | HARO weekly checks produced 1+ pickup | 10 min/day |
| PTA outreach (Sept back-to-school) | 5+ active dentist partners | 2 hrs/week for 3 weeks |
| Paid ads: Google App Campaigns $500/mo | D7 > 35% AND premium live AND 4.3+ stars AND CVR > 25% | 30 min/week |
| Paid ads: Facebook/Instagram $500/mo | Google campaigns profitable 2+ weeks | 30 min/week |
| Expand dentists to 50 (Northern CA) | 10+ active partners with measurable installs | 2 hrs/week |
| Printable coloring pages on website | 500+ installs | 3 hrs one-time (outsource design) |

### Back-to-School Sprint (August-September)

- PTA program kit ready (outsource design).
- "Get back in the brushing routine" content angle.
- Dentist card replenishment at high-traffic practices.
- If award badges earned: add to all materials.

---

## Month 7-12 (October 2026 - March 2027): Compound and Expand

**Theme:** Compounding growth from proven channels. Seasonal pushes. Begin iOS and B2B2C exploration.
**GTM budget:** 5-7 hrs/week (systems running, Jim focuses on high-leverage).
**Cash budget:** $500-2,000/mo (scaled based on proven ROI, not aspirational).

### Seasonal Calendar

| Month | Hook | Content Angle | PR Angle |
|-------|------|--------------|----------|
| **October** | Halloween (candy season) | "Candy season is here. Brush Quest has your back." | Halloween + dental health = natural press hook |
| **November-December** | Holiday gifting | Gift subscription flow. "Gift the habit." | Holiday gift guide pitches (pitch in October) |
| **January** | New Year resolutions | "Start the year with a brushing habit" | Health resolution angle |
| **February** | National Children's Dental Health Month | **MAXIMUM press effort. Pitch in January.** Every dentist gets refreshed materials. | THE golden month for dental press |
| **March** | Daylight Saving Time | "Routines are messed up? At least brushing is handled." | Light lifestyle angle |

### Expansion Triggers

| Activity | Trigger |
|----------|---------|
| iOS port begin | Android growing + D7 > 30% for 2+ months + $5-10K available |
| Store listing localization (Spanish) | Play Console shows 10%+ international visitors |
| Micro-influencer partnerships ($100 each) | 200+ installs, 50+ reviews, 4.3+ stars, 1+ organic UGC exists |
| Scale paid ads to $2K-5K/mo | LTV:CAC > 2x proven over 4+ weeks |
| Delta Dental exploratory conversation | 5K+ MAU, D30 > 20%, 50+ dentist partners |
| kidSAFE/PRIVO certification | Revenue covers the $2-5K/year cost |
| Additional award submissions | Revenue covers $200-300 application fees |

---

## Channel Playbooks

### Channel: ASO (Play Store Optimization)

**Status:** Always on. This is infrastructure, not a channel.

**What to do:**
- Monthly: review keyword performance in AppFollow. (10 min)
- Quarterly: refresh screenshots based on which messages are converting.
- If CVR < 15%: rewrite short description, swap screenshot order.
- If CVR < 15% after 2 A/B tests over 8 weeks: the problem is deeper -- investigate screenshots, rating, reviews.

**Kill condition:** Never.

### Channel: Play Store Reviews

**Status:** Always on.

**Cadence:** Check 3x/week (Mon/Wed/Fri, 5 min each). Respond to every review within 24 hours.

**Green:** 4.5+ stars, reviews on track (10+ Month 1, 50+ Month 3, 200+ Month 6).
**Yellow:** 4.0-4.5 stars. Review velocity declining.
**Red:** < 4.0 stars. OR 3+ negative reviews in a week on the same issue.

**Red response:** (1) Respond to every negative review with empathy + fix timeline. (2) Ship a patch for the most common complaint within 48 hours. (3) Pause GTM -- sending traffic to a < 4.0 listing wastes effort. (4) After fix, reply to negative reviews: "Fixed in the latest update." Resume GTM when rating returns to 4.3+.

**Kill condition:** Never.

### Channel: In-App Review Prompt

**Status:** Always on (after engineering build in Week 0).

**The only growth mechanic that scales without Jim's time.** Runs forever once built.

Adjust trigger timing based on data: if D7 retention is low, move from 5th brush to 7th to capture happier users.

**Kill condition:** Never.

### Channel: Reddit

**Activation:** App live on Play Store production track.

**Playbook:**
1. Post the drafted origin story on r/Daddit. Tell the story. App link at the end, not the beginning.
2. Engage authentically with every comment for 48 hours.
3. ONE subreddit per week maximum. Reddit flags cross-posting as spam.
4. If > 200 upvotes: post r/AndroidApps 1 week later (different angle: indie dev, technical story).
5. If > 500 upvotes: post r/Parenting 1 week after that.

**Key rule:** Claude generates draft post text. Jim MUST rewrite in his own voice. Reddit users detect marketing copy instantly.

**Automation possible:** NOTHING. Reddit API ToS prohibits automated posting for marketing. Accounts using automation get shadowbanned.

**Stop if:** < 20 upvotes on 2 posts to different subreddits after 4 weeks. The topic didn't land.

### Channel: TikTok

**Activation:** App live on Play Store AND Jim has filmed 1 test video.

**Cadence:** 2 videos/week. Batch-film on one day. Cross-post every video to Instagram Reels.

**Workflow per video (~55 min total):**
1. Film with Oliver (30 min). 3 proven formats: reaction, gameplay, behind-the-scenes.
2. Edit in CapCut (15 min).
3. Upload to TikTok manually with pre-generated caption (5 min). No free API for TikTok posting.
4. Download video. Re-upload to Instagram Reels (5 min).

**Automation possible:** Caption generation, hashtag suggestions, posting time recommendations, content concepts. That is all. Filming, editing, uploading are 100% manual.

**Green:** Avg 500+ views/video after Month 1. 1+ video > 5K views in any month.
**Yellow:** Avg 200-500 views/video. No breakout videos.
**Red:** Avg < 200 views/video after 20+ posts.

**Yellow action:** Experiment with hooks. Test: (1) start with kid's reaction, (2) bold text overlay, (3) relatable parent frustration. Give each format 3-4 videos.
**Red action:** After 20+ posts with < 200 avg views, reduce to 1/week, reallocate time.
**Kill after:** 3 months with < 50 total attributable installs from social. Cut organic social entirely.

### Channel: Instagram

**Activation:** TikTok content creation is active.

**Workflow:**
- Feed posts: Claude generates caption in batch. Jim approves. Copy-paste into Buffer. Buffer posts at scheduled time.
- Reels: Cross-post from TikTok (download, re-upload, paste caption). 5 min per Reel. Cannot schedule Reels on Buffer free tier.

**Stop if:** Instagram generates < 10% of social installs after 2 months. Stop cross-posting.
**Upgrade:** When posting 5+ videos/week, pay for Repurpose.io ($25/mo) to automate cross-posting.

### Channel: Local Dentist Outreach

**Activation:** App live on Play Store AND prescription cards printed.

**Cadence:** 5 new outreach attempts/month. 1-2 in-person visits/month.

**Playbook:**
1. Start with Oliver's dentist (warm intro, highest conversion). Can visit in person since it's convenient.
2. Email 4 more local practices using Claude-drafted personalized emails.
3. For each partner: generate unique ref code, create QR code (goqr.me or `npx qr`), place on prescription card.
4. Mail cards + info sheet to responsive practices (or drop off when convenient — email-first, not visit-first).
5. Monthly check-in emails to active partners (Claude drafts, Jim sends).

**CRM workflow:** Monday morning, open Google Sheets, sort by Next Action Date. Yellow = due soon, red = overdue. 3-5 minutes.

**Green:** > 20% conversion (1 in 5 attempts results in a partner).
**Yellow:** 10-20% conversion.
**Red:** < 10% conversion.

**Red action:** Talk to the 1-2 partners who DID say yes -- why? Talk to 1-2 who said no -- what would change their mind? Revise materials. Do not increase volume on a broken pitch.

**Stop if:** < 2 partners after 15 outreach attempts (month 2-3). Pivot to email-only at scale. Revisit messaging.

### Channel: Local PR

**Activation:** 10+ reviews AND 4.0+ stars.

**Cadence:** 1 pitch/week. Claude drafts, Jim sends via email. **Brand-led, not founder-led** — Jim does not do in-person interviews or photo ops. Email Q&A only if a journalist requests it.

**Order:** Alameda Sun (lowest bar) > Berkeleyside > East Bay Times.

**Stop if:** 0 responses after 6 pitches over 6 weeks. Rework pitch angle. Try seasonal hook.
**Kill after:** 0 published pieces after 12 pitches. Defer PR until a natural news hook (award, milestone).

### Channel: National Parenting PR

**Activation:** 1+ local press clip AND 50+ reviews AND 4.3+ stars.

**Targets:** Scary Mommy, Fatherly, Romper, Today's Parent.

**Cadence:** 2 pitches/week.

**Kill after:** 0 published pieces after 20 pitches over 2 months. Redirect time to podcasts.

### Channel: Product Hunt

**Activation:** 20+ reviews AND 4.3+ stars AND share card feature built.

**One-time event.** 4-6 hours over 2 days. Show HN post 3-7 days later.

**Stop if:** < 50 upvotes after 24 hours. Do not relaunch.

### Channel: Podcasts

**Activation:** DEFERRED. Requires a marketing hire who can be the public voice. Jim will not do podcast interviews while employed full-time elsewhere.

**When to revisit:** When revenue supports a marketing hire ($2K+/month revenue) and that person is onboarded.

### Channel: PTA/Schools

**Activation:** 5+ active dentist partners AND June-August (preparing for September).

**Cadence:** 2 hrs/week for 3 weeks (kit creation + outreach). Then 30 min/week.

**Kill after:** 2 PTA programs with < 10 installs each.

### Channel: Grandparent (Facebook)

**Activation:** Premium tier live OR 1,000+ installs.

**Cadence:** 1 hr/week (Claude drafts, Jim posts). "Gift the habit" messaging.

**Stop if:** < 50 page followers after 6 weeks. Test $50 boosted posts.
**Kill after:** $200 on boosts with < 20 installs.

### Channel: Google App Campaigns (Paid)

**Activation:** ALL prerequisites must be met:
1. D7 retention > 35% for 2+ consecutive weekly cohorts
2. Premium tier live with $1+ ARPU
3. Play Store 4.3+ stars with 50+ reviews
4. Play Store CVR > 25%
5. 200+ organic installs
6. $500/month available without stress

**Starting budget:** $500/mo. Google App Campaigns only. Do NOT split across platforms.

**First test:** 14 days at $15/day. US, English, parents 5-10. Let Google's ML optimize.

**Success:** CPI < $2.50 AND D7 of paid users > 25% AND 50+ installs.
**If CPI $2.50-4.00:** Test 3 creative sets, 7 days each. If none break $2.50: pause, A/B test listing, retry in 30 days.
**Kill:** CPI > $4.00 after 3 creative tests OR paid user D7 < 15%.

### Channel: Facebook/Instagram Ads (Paid)

**Activation:** Google campaigns profitable for 2+ weeks (CPI < LTV/3).

**Starting budget:** $500/mo. 3 ad creatives. Run 2 weeks.

**Kill:** CPI > $5.00 after 3 creative tests. Redirect budget to Google.

### Channel: TikTok Ads (Paid)

**Activation:** Facebook/Instagram ads profitable 4+ weeks AND 3+ organic TikToks with 10K+ views.

**Approach:** Boost top organic performers at $200/mo.

**Kill:** $400 spent with < 50 installs.

### Channel Rotation (When Things Fail)

1. If social fails: double down on dentists + PR
2. If dentists fail: double down on social + ASO
3. If PR fails: try Product Hunt + IndieHackers + Show HN
4. If all organic fails: fix the product (retention), then try paid
5. If paid fails: unit economics need fundamental improvement

---

## Automation Stack

### Tier 1: Truly Automated (Runs Without Jim)

| What | Tool | Setup | Notes |
|------|------|-------|-------|
| Brand mention alerts | Google Alerts + Talkwalker Alerts | 15 min | Google Alerts misses Reddit -- check manually 2x/week |
| Play Store review notifications | Play Console built-in email | 5 min | Bulletproof |
| Firebase analytics (passive) | Firebase (already integrated) | 0 min | Already set up |
| Buffer posts on schedule | Buffer (after Jim loads queue) | 30 min | Free tier: 10 posts/channel |
| Referral tracking | Firebase UTM attribution | 2-4 hrs eng | 50-70% accurate on Android -- accept the loss |
| In-app review prompts | Android native API | 2-3 hrs eng | Runs forever |
| Share cards at milestones | In-app | 4-5 hrs eng | Runs forever |

### Tier 2: AI-Assisted (Claude Drafts, Jim Reviews)

| What | Jim's Time | Frequency |
|------|-----------|-----------|
| Weekly content batch | 60-75 min (review + copy-paste into Buffer) | Sunday |
| Dentist outreach emails | 5-8 min per email | As needed |
| PR pitch drafts | 10-15 min per pitch | 1/week |
| Review response drafts | 5 min per review | As needed |
| Monthly dentist impact emails | 20 min at 5 partners, 1 hr at 20+ | Monthly |
| Monthly competitor scan | 5 min to read report | Monthly |

### Tier 3: Jim Does It, With Templates

| What | Template | Jim's Time |
|------|----------|-----------|
| Film video with Oliver | Shot list: 3 formats (reaction, gameplay, BTS) | 30-45 min/video |
| Post to TikTok | Posting checklist + caption from batch | 15 min/video |
| In-person dentist visits | Script: 5 talking points, 3 objections + responses | 30-45 min + drive |
| Reddit engagement | Guidelines: be authentic, reply to all, never defensive | 15-30 min/thread |
| Play Store A/B tests | Template: hypothesis, variants, metric, sample size | 15 min to set up |
| Weekly metrics check | Spreadsheet template with formulas | 10 min/week |

### Tier 4: Deferred Until Revenue

| What | Trigger |
|------|---------|
| Social media management hire | Revenue > $2K/month |
| Video editing outsourcing | 5+ videos/week AND revenue > $1K/month |
| Paid influencer campaigns | Revenue covers cost + proven organic traction |
| PTA program management at scale | 5+ schools requesting |
| iOS port | Android growing + $5-10K available |
| Paid CRM (HubSpot) | 100+ partner contacts |

### Cron Jobs (Only 2)

**Job 1: Weekly Content Batch**
- Schedule: Sunday 9:00 AM PT
- What: Claude generates week's social content as a PR to `docs/gtm-content/batches/YYYY-MM-DD.md`
- Jim reviews: GitHub PR notification on phone. Read, edit, merge. Copy approved posts to Buffer.
- Setup: 30-45 min (write prompt template, test one run, refine)

**Job 2: Monthly Competitor Scan**
- Schedule: 1st Monday of each month, 8:00 AM PT
- What: Claude WebFetches competitor Play Store listings, diffs against baselines, outputs report
- Competitors tracked: Brush DJ, Pokemon Smile (check if listed), Oral-B, Philips Sonicare Kids, Brusheez
- Jim reviews: 5 min to read. Merge PR.
- Setup: 30 min (create baseline snapshots, write prompt)

**Cron jobs NOT implemented (and why):**
- HARO scanner: requires Gmail OAuth, misses afternoon queries, manual 2x/day check is faster
- Review response drafter: at < 50 reviews/month, canned templates are faster than reading drafts
- Partnership follow-up: opening Google Sheets takes 3 min, OAuth setup takes 2 hrs
- Metrics dashboard: can't access Play Console or Firebase via API at free tier
- Keyword rank tracking: no free API exists

### Content Batch File Format

Each weekly PR contains a file with this exact structure:

```markdown
# Content Batch: Week of [DATE]

Generated: [DATETIME] PT
Status: DRAFT -- Jim to review

## Instagram Posts (schedule in Buffer)

### Post 1: [Monster of the Week]
- **Type:** Image post (use [monster file] from assets/)
- **Caption:** [Generated caption]
- **Hashtags:** [From hashtag-sets.md]
- **Best time:** [Day + time]
- **Status:** [ ] APPROVED  [ ] SKIP  [ ] EDIT NEEDED

### Post 2: [Tip/Educational]
[Same format]

### Post 3: [Behind-the-scenes / Dad story]
[Same format -- may include "[Needs Jim's input]" placeholder]

## TikTok Captions (Jim films, these are caption options)

### Video 1: [Concept]
- **Caption Option A:** [Generated]
- **Caption Option B:** [Generated]
- **Sound suggestion:** [If applicable]
- **Status:** [ ] FILMED  [ ] SKIP

## Reddit (manual posting, NOT scheduled)
### Thread: [Only if genuine reason to post this week]
- **Subreddit:** (one per week max)
- **Body:** [Draft -- Jim must rewrite in own voice]
- **Status:** [ ] POST  [ ] SKIP

## Dentist Follow-up Reminders
[Auto-generated from context if available]

## Notes for Jim
[Trending topics, seasonal hooks, etc.]
```

### Tools Stack

**Use Now (Free):**

| Tool | Purpose | Setup |
|------|---------|-------|
| Google Alerts | Brand + competitor monitoring | 10 min |
| Talkwalker Alerts | Backup monitoring (better for social) | 10 min |
| Google Play Console | Install metrics, reviews, A/B tests | Already set up |
| Firebase Console | Retention, analytics, crashes | Already set up |
| Google Sheets | CRM, metrics tracking | 30 min |
| Gmail canned responses | Review reply templates | 15 min |
| CapCut | Video editing | Already available |
| goqr.me | QR code generation | 2 min per code |
| Claude Code | Content drafting, outreach personalization | Already paying |

**Use in Month 1 (Free):**

| Tool | Purpose | Limits | Setup |
|------|---------|--------|-------|
| Buffer | Instagram scheduling | 3 channels, 10 posts/channel, no Reels | 30 min |
| AppFollow | Review monitoring, basic ASO | 1 app, limited keywords | 30 min |
| HARO/Connectively | Journalist query matching | Free | 20 min |

**Use When Triggered (Paid):**

| Tool | Cost | Trigger |
|------|------|---------|
| Buffer Essentials | $6/mo/channel | 10-post queue becomes bottleneck |
| Canva Pro | $13/mo | Need branded templates with Fredoka font |
| Repurpose.io | $25/mo | 5+ videos/week |
| Yet Another Mail Merge | Free for 50/day | 50+ dentist monthly emails become tedious |

**Do Not Use:**

| Tool | Why Not |
|------|---------|
| HubSpot CRM | 3 hrs setup for something Google Sheets does in 30 min |
| Sensor Tower / App Annie | $79-199/mo. Not until revenue covers it |
| Hootsuite / Sprout Social | $99+/mo. Buffer free does the job |
| X/Twitter API | $100/mo. Buffer free can schedule X posts |
| Adjust / AppsFlyer | Needed when running 3+ paid channels. Month 6+ at earliest |

---

## Metrics Dashboard and Decision Rules

### The Dashboard Is Not Software. It Is a Routine.

**Daily check (2 minutes, phone, with coffee):**
1. Play Store Console app: any new reviews? If 1-3 stars, respond within 24 hours.
2. Email: scan for Google Alerts. Most days: nothing.

That is it. Do NOT check social metrics daily -- it is a dopamine trap.

**Monday morning routine (15 minutes):**

| Step | Tool | Time | Record |
|------|------|------|--------|
| 1 | Play Console | 2 min | This week's installs, cumulative, rating |
| 2 | Play Console | 2 min | New reviews, respond to un-responded |
| 3 | Firebase Console | 3 min | D1, D7, D30 retention, DAU |
| 4 | TikTok app | 2 min | Views this week, followers, best video |
| 5 | Instagram app | 2 min | Followers, reach, best post |
| 6 | Google Sheets CRM | 3 min | Who needs follow-up (yellow/red rows) |
| 7 | Google Sheets Metrics | 1 min | Enter this week's numbers |

### Core Metrics with Green/Yellow/Red Thresholds

#### Daily Installs

| | Month 1 | Month 3 | Month 6 | Month 12 |
|---|---------|---------|---------|----------|
| **Green** | 2+/day | 5+/day | 15+/day | 50+/day |
| **Yellow** | 1-2/day | 3-5/day | 8-15/day | 25-50/day |
| **Red** | < 1/day | < 3/day | < 8/day | < 25/day |

- **Green:** Keep doing what you are doing. Focus on retention.
- **Yellow:** Which channel dried up? Seasonal? Reddit post aged off? Diagnose before acting.
- **Red:** Emergency. Check: (1) listing broken? (2) bad review tanked rating? (3) algorithm change killed a channel? Fix the most likely cause.

#### D1 Retention

| | Green | Yellow | Red |
|---|-------|--------|-----|
| Threshold | > 40% | 30-40% | < 30% |

- **Red:** STOP GTM. First session is broken. Run through app as new user. Time every screen. Check crash reports.

#### D7 Retention

| | Green | Yellow | Red |
|---|-------|--------|-----|
| Threshold | > 30% | 20-30% | < 20% |

- **Red:** STOP ALL GTM. This overrides every other priority. Fix the product. Do not resume until D7 > 25% for 2 consecutive weekly cohorts.

#### D30 Retention

| | Green | Yellow | Red |
|---|-------|--------|-----|
| Threshold | > 20% | 12-20% | < 12% |

- **Red:** App is a novelty, not a habit. Add push notifications, new mid-game content, social/competitive element. Do not scale spend until D30 > 15%.

#### Session Completion Rate

| | Green | Yellow | Red |
|---|-------|--------|-----|
| Threshold | > 85% | 70-85% | < 70% |

- **Red:** 2-minute session is too long or not engaging enough. Test shorter timer, more dramatic final phase, mid-session rewards.

#### Sessions Per User Per Week

| | Green | Yellow | Red |
|---|-------|--------|-----|
| Threshold | > 10 | 5-10 | < 5 |

Target is 14 (2x/day, 7 days). Red means users install but don't make it routine.

#### Play Store Rating

| | Green | Yellow | Red |
|---|-------|--------|-----|
| Threshold | 4.5+ | 4.0-4.5 | < 4.0 |

- **Red:** Emergency. Respond to negatives, ship patch in 48 hrs, pause GTM, resume when > 4.3.

#### Social Media Engagement (TikTok)

| | Green | Yellow | Red |
|---|-------|--------|-----|
| Threshold | 500+ avg views | 200-500 avg views | < 200 avg views after 20 posts |

#### Dentist Partnership Conversion

| | Green | Yellow | Red |
|---|-------|--------|-----|
| Threshold | > 20% | 10-20% | < 10% |

#### Email List Growth

| | Green | Yellow | Red |
|---|-------|--------|-----|
| Threshold | 10+/week | 3-10/week | < 3/week |

Note: email is low priority at < 500 installs. Defer optimization until Month 3+.

#### Cost Per Install (When Paid Starts)

| | Green | Yellow | Red |
|---|-------|--------|-----|
| Threshold | CPI < LTV/3 | CPI between LTV/3 and LTV/2 | CPI > LTV/2 |

- **Red:** Pause campaign. Test 3 different creatives. If all produce red CPI, kill channel.

#### LTV:CAC Ratio (When Measurable)

| | Green | Yellow | Red |
|---|-------|--------|-----|
| Threshold | > 3:1 | 2:1 to 3:1 | < 2:1 |

- **Red:** Pause paid acquisition. Focus on product. Organic-only until ratio improves.

### Trigger Points (Phase Gates)

| Trigger | Threshold | What It Activates |
|---------|-----------|-------------------|
| D7 < 20% | ALARM | STOP all growth. Fix product. |
| 500 total installs | Gate | A/B test store listing |
| 20+ reviews, 4.3+ stars | Gate | Product Hunt. Micro-influencer outreach (free product). |
| D7 > 35% + premium + 4.3+ stars + CVR > 25% | Gate | Paid acquisition ($500/mo/channel) |
| < 5 installs/month from any platform after 8 weeks | Kill | Stop that platform |
| < 50 installs from social after 3 months | Kill | Cut organic social |
| Any social post > 10K views | Signal | Make more of that content type |
| 1+ press hit | Signal | Add podcast pitching. Use clip everywhere. |
| 10+ active dentist partners | Signal | Create /dentists page. Build "Advisory Board" (3 dentists). |
| 5K+ MAU, D30 > 20% | Gate | Insurance exploratory conversations |

---

## Monthly Review Template

Copy this template on the first Sunday of each month. Fill it in. 60 minutes total.

**Pre-work (10 min, the night before):** Pull numbers from Play Console, Firebase, TikTok, Instagram, Buttondown, Google Sheets CRM, bank statement.

```markdown
## Month [X] Review -- [DATE]

### Scorecard

| Metric | This Month | Last Month | Trend | Status |
|--------|-----------|------------|-------|--------|
| Total installs (cumulative) | | | | G/Y/R |
| Installs this month | | | +/-% | G/Y/R |
| Play Store rating | | | | G/Y/R |
| Review count (cumulative) | | | | G/Y/R |
| D1 retention | | | +/-pp | G/Y/R |
| D7 retention | | | +/-pp | G/Y/R |
| D30 retention | | | +/-pp | G/Y/R |
| Session completion rate | | | | G/Y/R |
| Sessions/user/week | | | | G/Y/R |
| MAU | | | | |
| TikTok followers | | | | |
| TikTok avg views/video | | | | G/Y/R |
| Instagram followers | | | | |
| Email subscribers (total) | | | | |
| Active dentist partners | | | | |
| Revenue (if premium live) | | | | |

Greens: __ | Yellows: __ | Reds: __
If 3+ Reds: this is a crisis review. Skip to Decisions.

### Channel Ranking (installs per hour of Jim's time)

1. [Channel]: [X] installs / [Y] hours = [Z] installs/hr
2. [Channel]: [X] installs / [Y] hours = [Z] installs/hr
3. [Channel]: [X] installs / [Y] hours = [Z] installs/hr
4. [Channel]: [X] installs / [Y] hours = [Z] installs/hr

Top channel next month: invest more time in [X].
Bottom channel: below kill threshold? If yes, kill it.

### Decision Points

- New channels ready to activate? (Check Channel Activation triggers)
- Channels to deactivate? (Check kill conditions)
- Pending decisions now have enough data? (Check Phase Transitions)
- Time allocation still right? Shift hours between channels?

### Decisions Made

- ACTIVATED: [channel] because [trigger met]
- KILLED: [channel] because [kill threshold hit]
- CONTINUED: [channel] despite [concern] because [reason]
- CHANGED: [X] from [old] to [new] because [data]

### Next Month: Top 3 Priorities

1. [Action] -- Expected outcome: [X]. Measure: [Y].
2. [Action] -- Expected outcome: [X]. Measure: [Y].
3. [Action] -- Expected outcome: [X]. Measure: [Y].

### Budget

- Tools: $[X]
- Ads (if active): $[X]
- Outsourcing: $[X]
- Awards/applications: $[X]
- Total: $[X]

### Seasonal hooks next month

[Check seasonal calendar. Plan content/PR angles now.]

### Reflection

- What surprised me this month?
- What did I spend time on that produced nothing?
- Am I burning out? (If yes: next month is recovery -- half GTM, double product)
- "The most important thing I learned about my users this month is ___"
```

---

## Phase Transitions

### Phase 0 to Phase 1: Pre-Launch to Validation

**"The app is live. Now prove someone wants it."**

**Required (ALL):**
- [ ] App live on Play Store production track
- [ ] Play Store listing finalized (8 screenshots, full description, preview video)
- [ ] In-app review prompt built and deployed
- [ ] Share card feature built and deployed
- [ ] Week 0 infrastructure complete
- [ ] First batch of prescription cards printed

**Expected timeline:** 1-2 weeks after internal testing is stable.

### Phase 1 to Phase 2: Validation to Monetize

**"People want it and keep using it. Now charge for it."**

**Required (ALL):**
- [ ] 200+ total installs
- [ ] D7 retention > 25% for 4+ consecutive weekly cohorts
- [ ] 20+ Play Store reviews with 4.3+ average
- [ ] At least 1 channel producing 5+ installs/week reliably
- [ ] Session completion rate > 80%
- [ ] Jim has identified the top 2 channels by installs-per-hour

**Expected timeline:** Month 2-4 (realistic). Month 2 (if Reddit goes viral).

**Phase 2 actions:** Launch premium tier. Track free-to-paid conversion, ARPU, churn. Begin LTV calculation. Product Hunt. National PR pitches (if local clip exists). Prepare paid acquisition prerequisites.

### Phase 2 to Phase 3: Monetize to Growth Engine

**"The unit economics work. Now pour fuel on the fire."**

**Required (ALL):**
- [ ] Premium tier live 60+ days
- [ ] LTV > $3
- [ ] D7 retention > 30%
- [ ] D30 retention > 18%
- [ ] Play Store CVR > 25%
- [ ] 500+ total installs
- [ ] 50+ reviews with 4.3+ stars
- [ ] 1 organic channel producing 15+ installs/week
- [ ] Monthly revenue > $200

**Expected timeline:** Month 5-8 (realistic). Month 4 (if monetization converts well).

**Phase 3 actions:** Start Google App Campaigns at $500/mo. Scale dentists to 50+. Begin iOS planning. Grandparent channel. Back-to-school push. Consider first VA hire if revenue > $2K/mo.

---

## Growth Projections (3 Scenarios)

### Assumptions

All scenarios assume: App launches April 2026, Jim executes 6-8 hrs/week consistently, no paid ads until Phase 3, premium launches Month 3-4.

**Conservative:** Reddit gets 100-200 upvotes (20-40 installs). No viral moments. TikTok averages 200-500 views. 3-5 dentist partners by Month 3. No significant press. Premium conversion: 3%. D7: 25%.

**Baseline:** Reddit does well (500+ upvotes, 100-200 installs). 1 TikTok gets 5K-20K views in first 6 months. 10-15 dentist partners by Month 6. 1-2 local press hits. Product Hunt generates 100-300. Premium conversion: 5%. D7: 30%.

**Optimistic:** Reddit goes viral (1000+ upvotes, 500+ installs). 2-3 TikToks break 50K views. 30+ dentist partners by Month 6. 1 national media hit. Award badge earned. Premium conversion: 7%. D7: 35%.

### Month-by-Month

| Month | Conservative | Baseline | Optimistic |
|-------|-------------|----------|------------|
| | Installs / MAU / Rev | Installs / MAU / Rev | Installs / MAU / Rev |
| **1 (Apr)** | 30 / 20 / $0 | 75 / 50 / $0 | 250 / 175 / $0 |
| **2 (May)** | 50 / 35 / $0 | 125 / 90 / $0 | 400 / 280 / $0 |
| **3 (Jun)** | 80 / 55 / $0 | 225 / 150 / $50 | 700 / 490 / $150 |
| **4 (Jul)** | 110 / 70 / $30 | 375 / 250 / $150 | 1,200 / 840 / $400 |
| **5 (Aug)** | 150 / 90 / $50 | 525 / 350 / $250 | 1,800 / 1,260 / $700 |
| **6 (Sep)** | 200 / 120 / $70 | 750 / 500 / $400 | 2,800 / 1,960 / $1,200 |
| **7 (Oct)** | 260 / 150 / $90 | 1,000 / 650 / $550 | 4,000 / 2,800 / $1,800 |
| **8 (Nov)** | 330 / 180 / $110 | 1,300 / 850 / $700 | 5,500 / 3,850 / $2,500 |
| **9 (Dec)** | 420 / 220 / $140 | 1,700 / 1,100 / $900 | 7,500 / 5,250 / $3,500 |
| **10 (Jan)** | 520 / 270 / $170 | 2,200 / 1,400 / $1,100 | 10,000 / 7,000 / $4,500 |
| **11 (Feb)** | 650 / 330 / $200 | 2,800 / 1,800 / $1,400 | 13,000 / 9,100 / $6,000 |
| **12 (Mar)** | 800 / 400 / $250 | 3,500 / 2,300 / $1,800 | 17,000 / 11,900 / $8,000 |

**Cumulative installs at Month 12:** Conservative ~3,600. Baseline ~14,600. Optimistic ~64,150.

**Revenue:** Premium at $3.99/mo or $29.99/yr. Revenue = MAU x conversion rate x $3.99. Numbers are gross (before Play Store 15% cut).

**Context:** The median Play Store app gets < 1,000 lifetime installs. 5,000-20,000 in Year 1 is a strong outcome for a bootstrapped solo founder. 50,000+ is exceptional.

**What moves the needle between scenarios:** The difference between Conservative and Baseline is usually ONE thing going well. The difference between Baseline and Optimistic is TWO OR MORE things going well simultaneously plus paid ads working. Jim cannot plan for this, but he can increase the surface area of luck by consistently shipping content and pitches.

### Annual Cash Budget Summary

| Period | Tools + Design | Paid Ads | Total |
|--------|---------------|----------|-------|
| Month 1 (setup) | $375-500 | $0 | $375-500 |
| Month 2-6 | $50-300 total | $0-3,000 | $50-3,300 |
| Month 7-12 | $150-500 total | $0-30,000 | $150-30,500 |
| **Year 1 (conservative, no ads)** | **$575-1,300** | **$0** | **$575-1,300** |
| **Year 1 (with ads at Month 6)** | **$575-1,300** | **$3,000-15,000** | **$3,575-16,300** |

---

## Contingency Playbook

### Scenario 1: Zero Installs After 1 Month

**Early warning (Week 2):** Play Store impressions < 100/week. Reddit < 10 upvotes. Zero installs from dentist cards.

**This is a discovery problem, not a growth problem.**

**Response:**
1. Check the basics: search Play Store for "kids brushing app." If Brush Quest is not in the first 50 results, ASO is broken. Rewrite listing with higher-volume keywords.
2. If impressions exist but installs are zero: listing is not compelling. Rewrite short description. Change first screenshot. Ask 3 parent friends to evaluate the listing.
3. Force 20 installs manually: every parent Jim knows. Family, friends, coworkers, school parents. Not scalable, but provides retention data and first reviews.
4. If all 20 manual users churn within a week: product problem, not marketing. Observe Oliver using the app. Time engagement. Note boredom points. Fix before doing anything else.

### Scenario 2: Retention Is Terrible (D7 < 15%)

**Early warning:** Kids complete first brush but don't return. Oliver stops wanting to use it. Reviews mention "liked it for a day."

**Response:**
1. STOP all GTM.
2. Interview 5 parents. Ask: "What happened? When did your kid stop asking to use it?" Usually one of: novelty wore off, too hard/easy, parent forgot, sibling conflict.
3. Check session-level data: where do they drop? Session 1? 3? 7?
4. Ship one targeted fix per week for 3 weeks:
   - Push notifications (parent-opted-in) as reminder
   - "Daily surprise" for first 7 days (different monster, bonus reward)
   - Reduced session length option (60 seconds)
   - Sibling mode if siblings compete for phone
5. If D7 still < 15% after 3 cycles: core game loop is not engaging. Consider multiplayer, parent co-op, story mode.

### Scenario 3: A Competitor Launches With More Funding

**Response:**
1. Do NOT panic. Do NOT try to out-feature them.
2. Lean into what they cannot copy: "Built by a dad" (authenticity). "No tracking" (corporate apps always collect data). "Works with any toothbrush." "Indie dev who responds to every review."
3. Speed: ship features before they finish sprint planning.
4. Rally early users: "We're the indie alternative."

### Scenario 4: Play Store Flags the App

**Most likely causes:** COPPA/privacy issues, ad SDK detected, camera permission flagged, description claims without documentation.

**Response:**
1. Respond within 24 hours.
2. Read the specific violation. Do NOT guess.
3. Privacy: update policy with explicit "no data collection from children."
4. Camera: provide justification. If rejected, make camera optional.
5. Content claims: soften. "Recommended by dentists" becomes "Loved by families" unless documented.
6. Worst case (removed): appeal immediately, make APK available on website, use Amazon Appstore as backup.

### Scenario 5: Jim Burns Out on GTM

**Early warning:** Skips 2+ GTM sessions. Spends "GTM time" on product. Dreads Monday. Stops checking metrics.

**Response:**
1. Normal. Expected. Not a character flaw.
2. Activate recovery mode: 2 weeks of zero GTM. Product only.
3. Minimum maintenance: respond to Play Store reviews (5 min, 3x/week). Everything else pauses.
4. After 2 weeks: "Which ONE GTM activity do I actually enjoy?" Do ONLY that for the next month.
5. For everything else: automate (Claude + Buffer), outsource (Fiverr, VA), or kill it.
6. If no GTM activity is enjoyable: hire a part-time marketing person ($1,500-2,500/mo) or go "build in public" on Twitter and let ASO + in-app reviews grow the app organically.

**Prevention (already in the plan):** Recovery week every 4th week. Zero-GTM Fridays. Never exceed 8 hrs/week Months 1-3. Celebrate every milestone explicitly.

### Scenario 6: Nothing Works After 6 Months

**Definition:** 6 months in, < 500 installs, D7 < 20%, revenue < $50/month.

**Before giving up, verify these are NOT the cause:**
1. Play Store listing is bad (ask 5 strangers to rate 1-10)
2. Critical bug Jim missed (test on 3 different phones)
3. Jim never actually executed the plan (200 hours of real GTM work over 6 months?)
4. Target audience is wrong (maybe 4-5 or 9-10 year olds love it, but 7-year-olds don't)

**If all check out:**
1. Expand scope: brushing + handwashing + sunscreen = "kids health habits" app
2. Change monetization: free app with dentist referral fees (B2B2C)
3. License the platform: white-label for dental practices
4. Open-source and move on. This is not failure. This is learning.

**The honest math:** month-over-month growth rate matters more than absolute numbers. Going from 50 to 100 installs/month (100% growth) is a better signal than 500 but flat.

---

## Cross-Channel Feedback Loops

These loops compound over time. Feed data from one channel into the next.

1. **Social --> PR:** Which posts get engagement? That theme leads the next PR pitch.
2. **PR --> Social + Dentist:** Every press clip becomes a social post ("As seen in..."), goes in the media kit, and gets mentioned in dentist emails.
3. **Dentist Feedback --> Messaging + Product:** Dentist questions and objections become social content, PR angles, and Play Store copy.
4. **Play Store Reviews --> Everything:** Parent quotes become social proof everywhere. Complaints inform the roadmap. Parent language becomes ASO keywords.
5. **ASO Data --> Paid Ads:** Keywords that drive organic installs become paid ad keywords. A/B test winning headlines become ad headlines.
6. **User Milestones --> Share Cards --> New Users:** In-app events trigger share cards. Parent shares. New parent discovers app. Track: share_triggered > share_completed > referral_install. This is the only truly viral mechanic.

---

## Award Submission Calendar

| Award | Cost | When | Review Time | Why |
|-------|------|------|-------------|-----|
| Common Sense Media | Free | Week 0 | 4-8 weeks | Parents' #1 vetting site. A 4-5 star CSM rating > 100 Play Store reviews. |
| Parents' Choice Award | $150 | Week 0 | 8-12 weeks | Silver/Gold seal = major trust signal on screenshots. |
| Google Play "Teacher Approved" | Free | Month 2 | Varies | Badge in Play Store Kids tab. Requires Designed for Families first. |
| Mom's Choice Award | $295 | Month 3 | 6-8 weeks | Recognized seal for kids products. |
| NAPPA | $195 | Month 4-6 | Varies | Good PR hook. Apply when revenue covers it. |
| Kidscreen Awards | $225 | March deadline | Annual | "Oscars" of kids digital media. Year 2 play. |

---

## Outsource Guide

Jim should NOT create these himself. A designer does it better in 2 hours for $75. Jim would spend 6+ hours and produce something worse.

| Asset | Outsource To | Cost | When |
|-------|-------------|------|------|
| Media kit (PDF) | Fiverr | $75-150 | Week 0 |
| Partner info sheet (PDF) | Fiverr | $50-75 | Week 0 |
| Prescription card design | Fiverr | $50-75 | Week 0 |
| QR code business cards | Vistaprint | $50 for 250 | Week 0 |
| TikTok thumbnail template | Fiverr | $25-50 | Optional, Week 0 |
| Printable coloring pages | Fiverr illustrator | $50-100 | Month 4+ (500+ installs) |
| PTA program kit | Fiverr | $75-100 | Month 4+ (5+ dentist partners) |
| Video editing (batch) | Fiverr/Upwork | $100-200/mo | Month 6+ (5+ videos/week) |

---

## Decisions (Resolved 2026-04-03)

### 1. Oliver and Theo on Camera — DECIDED: Both (a) and (b) OK

Jim is comfortable with both full-face and over-the-shoulder footage. **Default to (b) over-the-shoulder** for routine content (lower effort, protects flexibility). Use (a) full face for high-impact moments (first reaction video, key TikToks). This gives maximum creative range.

**Rule:** Use judgment per video. Over-the-shoulder is the default. Full face when the reaction IS the content.

### 2. Jim as Public Face — DECIDED: No

Jim has another full-time job. He will NOT be the podcast-appearing, press-photographed public face.

**What this changes:**
- Podcast strategy → **DEFERRED** until a marketing hire exists. Remove from Month 4-6 activation.
- PR pitches → Brand-led, not founder-led. The origin story ("built by a dad") still appears in copy, but Jim does not do interviews. If a journalist insists on a call, Jim can do brief email Q&A only.
- Reddit → Posts can reference "I built this for my kid" without Jim's full name/photo. Use a pseudonymous or brand account.
- Dentist outreach → Email-only is fine. In-person visits only when convenient (e.g., Oliver's dentist), not as a scalable channel requiring Jim's physical presence.
- **Future:** When revenue supports hiring a marketing person ($2K+/month), that person becomes the public face and unlocks podcasts, video appearances, and conference circuits.

### 3. Monthly GTM Budget Ceiling — DECIDED: $1,000-2,000/month

Jim wants to give the app a fair shot. This is generous for a bootstrapped founder and means:
- Paid ads can trigger as early as Month 3-4 (if retention metrics are met) at $500-1,000/month
- Premium tools and outsourcing are available without stress
- Total Year 1 ceiling: ~$12,000-24,000 (but actual spend gated on metrics, not calendar)
- **Hard rule:** Never exceed $2,000/month. Scale within this ceiling by reallocating between channels, not increasing total spend.

### 4. UGC Featuring Other People's Children — DECIDED: Conservative/Safe

**Policy:** Zero legal risk tolerance.
- Reshare/retweet from original parent post: OK (platform-native sharing, parent controls their content)
- Download and repost child faces: NEVER
- Repost screen recordings or hands-only: OK with credit
- Solicit UGC featuring children: NOT until attorney-reviewed consent form exists
- Legal consultation: Budget $500-1,000 when organic UGC reaches 50+ posts
- If in doubt: don't use it

### 5. Production Launch — DECIDED: End of next week (~April 11, 2026)

**Week 0 starts now.** The setup checklist should be executed April 3-10, with production launch targeting April 11. The Reddit origin story and dentist outreach activate the week of April 14.

**Revised timeline:**
- April 3-10: Week 0 (infrastructure, Fiverr commissions, engineering, listing polish)
- April 11: Production launch on Google Play
- April 14: Week 1 begins (Reddit post, first dentist emails, TikTok filming starts)
- May 11: Month 1 review

---

## Appendix: Templates

### Dentist Outreach Email (Claude personalization template)

```
Subject: Free brushing app for your young patients

Hi Dr. [NAME],

I saw on your website that [SPECIFIC DETAIL -- e.g., "you specialize in pediatric
anxiety management" or "you've been in Alameda for 15 years"]. That resonated with me.

I'm a dad in [CITY] who built a free app called Brush Quest to help my 7-year-old
actually enjoy brushing. It's a 2-minute guided brushing game -- shows kids WHERE
to brush with a mouth guide, turns it into a space adventure. No ads, no data
collection, works with any toothbrush.

Would you be open to trying it and, if you like it, recommending it to families who
struggle with brushing? I have small cards I can drop off -- they look like a
prescription recommendation with a QR code.

No pressure either way. Just a dad trying to help more kids brush better.

Best,
Jim Chabas
Brush Quest -- brushquest.app
```

### PR Pitch Template (Claude customization per journalist)

```
Subject: [SPECIFIC HOOK -- e.g., "Bay Area dad builds app after nightly brushing battle"]

Hi [JOURNALIST NAME],

I read your piece on [RECENT ARTICLE TITLE] in [OUTLET] and thought you might find
this story interesting.

I'm a solo founder in Alameda who built a free kids toothbrushing app after my
7-year-old turned bedtime brushing into a 10-minute battle every night. The app --
Brush Quest -- turns 2 minutes of brushing into a space adventure where kids fight
cavity monsters.

What makes this different from the toothbrush company apps:
- Works with any toothbrush (not a hardware sales tool)
- Guides kids through each section of their mouth
- 10 worlds of content so kids don't get bored after a week
- Zero ads, zero data collection from children
- Built by one dad, used by his own kids every day

[IF APPLICABLE: Local angle -- several local pediatric dentists are recommending it.]

Happy to chat or send a demo. I can also share my experience as a solo technical
founder building a kids app -- the COPPA compliance journey alone is a story.

Jim Chabas
brushquest.app | @brushquest
```

### Weekly Metrics Snapshot (for Google Sheets or markdown)

```
# Weekly Metrics: [DATE]

## App (Play Console + Firebase)
- Installs this week:
- Total installs:
- Play Store rating:
- Review count:
- D7 retention:
- D30 retention:
- DAU:
- Session completion rate:

## Social
- TikTok followers:
- TikTok views this week:
- Instagram followers:
- Instagram reach this week:

## Partnerships
- Active dentist partners:
- New contacts this week:
- Dentist ref installs (Firebase):

## Decisions
- What worked:
- What to stop:
- What to try next week:
```

### Competitive Response Cheat Sheet

**"Just use the free Oral-B app"**
> "Totally fair! The Oral-B app is a good start. We built Brush Quest because our kid got bored with timers after a week. The 10 worlds and monster battles kept him going. Whatever gets your kid brushing is a win."

**"There are free timer apps"**
> "A timer tells your kid WHEN to stop. Brush Quest tells them WHERE to brush, makes it fun enough they WANT to brush, and tracks progress. It's the difference between an alarm clock and a personal trainer."

**"Why should I pay for a brushing app?"**
> "The free version works great for most families. Premium unlocks extra worlds and heroes for kids who are really into it. But the core brushing guidance is free -- no paywall on good habits."

**"Is this just more screen time?"**
> "2 minutes. That's it. It replaces 10 minutes of arguing about brushing with 2 minutes of guided brushing that ends with clean teeth. Not more screen time -- better screen time."

### Seasonal Content Calendar

| Month | Hook | Content Angle | PR Angle |
|-------|------|--------------|----------|
| **January** | New Year resolutions | "Start the year with a brushing habit" | Family health goals |
| **February** | Children's Dental Health Month | Maximum push. Refresh all materials. | **GOLDEN MONTH.** Pitch in January. |
| **March** | Daylight Saving Time | "Routines disrupted? Brushing is handled." | Lifestyle |
| **April** | Dental Hygiene Month | Dental facts, hygienist appreciation | Professional angle |
| **June-August** | Summer break | "Summer doesn't mean cavities" | Back-to-school prep (August) |
| **September** | Back to school + Grandparents' Day (Sep 7) | PTA launch. Grandparent gift angle. | Roundups |
| **October** | Halloween | "Candy season. Brush Quest has your back." | Natural press hook |
| **Nov-Dec** | Holidays | "Gift the habit." | Gift guide pitches (October) |

---

*This is the operating document. It replaces all previous rounds. Update monthly as data comes in. The numbers are realistic estimates that MUST be validated with real data. Never scale spend based on projections alone -- only on measured unit economics. The engine starts with 3 activities, learns fast, and scales only what works.*
