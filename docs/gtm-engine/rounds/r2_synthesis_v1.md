# Round 2: Unified GTM Engine -- Synthesis v1

**Date:** 2026-04-03
**Status:** DRAFT -- awaiting Jim's review
**Inputs:** R1 Social Media, R1 Partnerships, R1 PR & Earned Media, R1 App Store Growth
**Purpose:** One plan, one timeline, one engine. Replaces all four R1 documents as the operating document.

---

## Executive Summary

Brush Quest's GTM engine is built on a single insight: parents trust other parents and professionals, not ads. The engine has three gears that turn in sequence. **Gear 1 (Months 1-3)** is the credibility machine -- local dentist partnerships, local PR, organic social, and ASO optimization running in parallel to get the first 500 real users, 50+ reviews, and 3-5 press clips. Nothing here costs money; everything costs Jim's time, which is the scarcest resource. **Gear 2 (Months 4-6)** takes what worked and scales it -- 50 dentists across Northern California, PTA programs seeded for the fall, Product Hunt / Hacker News launch, in-app virality mechanics, and the first paid ad experiments once retention metrics prove the product retains. **Gear 3 (Months 7-12)** is the compounding phase -- 200+ dentist partners, iOS launch doubling the addressable market, scaled paid acquisition with proven creative, seasonal PR pushes (October Halloween, February Dental Health Month), and the beginning of B2B2C conversations with Delta Dental of California.

The automation architecture uses Claude Code as the content factory and outreach drafter, Buffer/Repurpose.io as the scheduling layer, and Google Sheets + Firebase as the tracking backbone. Jim's weekly time budget starts at 8-10 hours in Month 1 (heavy on filming and dentist visits) and drops to 5-6 hours by Month 4 as systems take over. The engine is designed so that if Jim does nothing for a week, the automated posts still go out, the dentist cards are still on counters, and the ASO keeps working. The things that stop are the human-touch activities -- responding to comments, recording new video, and building relationships -- which are exactly the things Jim should be doing.

The kill switches are explicit: if D7 retention drops below 20%, ALL growth work stops and Jim fixes the product. If a channel produces fewer than 5 installs/month after 8 weeks, it gets cut. If social produces fewer than 50 installs after 3 months, pivot entirely to partnership-driven distribution. The engine is designed to be honest about what is working and ruthless about what is not.

---

## Unified Channel Priority Ranking

Every tactic from all four strategies, ranked by expected ROI per hour of Jim's time. This is the single prioritization list.

### Tier S: Do These First, No Matter What

| Rank | Tactic | Channel | Expected Impact | Jim Time | Why It's Here |
|------|--------|---------|----------------|----------|---------------|
| 1 | **ASO optimization** (title, description, screenshots, keywords) | App Store | High -- every future install converts better | 4 hrs one-time | Multiplier on everything else. Do before any traffic-driving activity. |
| 2 | **10 local pediatric dentist partnerships** | Partnerships | 90-120 installs/month, highest-trust channel | 6 hrs total (emails + 3-5 visits) | 80% conversion when a dentist says "download this." Nothing else comes close. |
| 3 | **Reddit origin story post** (r/Daddit) | Social / PR | 50-500 installs in 48 hrs, sets the narrative | 1 hr writing + 2 hrs engaging | Single highest-ceiling organic post. Time it with production launch day. |
| 4 | **Local press pitches** (Alameda Sun, Berkeleyside, 5 TV stations) | PR | Clips for media kit + local installs | 2 hrs drafting + sending | Lowest bar for coverage. Creates assets that power every later pitch. |
| 5 | **In-app review prompt implementation** | App Store | Compounds forever; 4.5+ stars unlocks everything | 4 hrs engineering | Without reviews, nothing else works. Gate for paid ads, featuring, and credibility. |

### Tier A: Start in Week 2-4, Run Continuously

| Rank | Tactic | Channel | Expected Impact | Jim Time/Week |
|------|--------|---------|----------------|---------------|
| 6 | **TikTok content** (3x/week, cross-post to Reels) | Social | 500-50K views/video; long-tail discovery | 2 hrs (filming + batch review) |
| 7 | **Share card generation** (in-app, at milestone moments) | App Store / Virality | Each share = free acquisition at highest trust level | 4 hrs engineering one-time |
| 8 | **HARO/Connectively monitoring** | PR | Free media mentions from inbound journalist queries | 15 min/day (Claude scans, Jim responds) |
| 9 | **Common Sense Media submission** | App Store | Parents search here before downloading kids apps | 30 min one-time |
| 10 | **Media kit + /press page creation** | PR | Unlocks all future PR. Journalists self-serve. | 3 hrs one-time |
| 11 | **Google Alerts setup** (brand + competitors + category) | All | Passive monitoring for mentions and opportunities | 15 min one-time |
| 12 | **Parenting publication pitches** (Scary Mommy, Fatherly) | PR | 10K-100K reader reach per article | 30 min/week (Claude drafts, Jim reviews) |

### Tier B: Add at 100-500 Users (Month 2-3)

| Rank | Tactic | Channel | Expected Impact | Jim Time/Week |
|------|--------|---------|----------------|---------------|
| 13 | **Expand to 50 dentists** (Northern CA, email-only) | Partnerships | 1,500 installs/month at scale | 2 hrs/week |
| 14 | **Product Hunt launch** | PR / App Store | 200-1K installs in 48 hrs + press pickup | 4 hrs one-time (prep + launch day) |
| 15 | **Show HN post** | PR / Social | 100-500 installs + tech press discovery | 1 hr + comment engagement |
| 16 | **IndieHackers "how I built it" post** | PR | Establishes credibility in maker community | 2 hrs writing one-time |
| 17 | **Facebook Group participation** (5-10 groups) | Social | 5-15 installs per well-placed comment | 30 min/week |
| 18 | **Podcast pitches** (2-3 parenting + 2-3 maker) | PR | 50-500 installs per appearance | 30 min/week pitching, 45 min per recording |
| 19 | **PTA program prep** (for September back-to-school or February NCDHM) | Partnerships | 50-100 installs per school | 3 hrs one-time (kit creation) |
| 20 | **Play Store listing A/B tests** | App Store | 5-15% CVR improvement per winning test | 15 min/week monitoring |
| 21 | **Pinterest dental fact pins** (batch 30, schedule weekly) | Social | Evergreen traffic for 2+ years | 2 hrs one-time batch |

### Tier C: Only When Trigger Metrics Are Met (Month 3-6)

| Rank | Tactic | Channel | Trigger | Expected Impact |
|------|--------|---------|---------|----------------|
| 22 | **Google App Campaigns** ($500/mo) | Paid | D7 > 35%, premium live, 4.3+ stars | CPI $1.50-3.00, scalable |
| 23 | **Facebook/Instagram ads** ($500/mo) | Paid | Same as above + proven organic creative | CPI $2.00-3.00, rich targeting |
| 24 | **Micro-influencer seeding** (10 accounts, $100 each) | Social | 500+ followers, any organic video > 10K views | 50+ installs per collab if targeted well |
| 25 | **Store listing localization** (Spanish, Portuguese) | App Store | 1,000+ installs, Play Store data shows international interest | Opens Latin America + Brazil |
| 26 | **iOS port + TestFlight beta** | App Store | After Android is stable and proven | Doubles addressable market |
| 27 | **Dental trade publication pitches** | PR / Partnerships | 50+ active dentist partners | Seeds hundreds more dentist recommendations |

### Tier D: Later-Stage (Month 6-12+)

| Rank | Tactic | Channel | Trigger |
|------|--------|---------|---------|
| 28 | iOS App Store launch with full ASO | App Store | TestFlight beta validated |
| 29 | Apple Search Ads | Paid | iOS live, $500/mo |
| 30 | TikTok Ads | Paid | Facebook creative proven |
| 31 | Consumer brand outreach (Hello, Quip) | Partnerships | 10K+ users |
| 32 | Dental chain / DSO outreach | Partnerships | 50+ active dentist partners, outcomes data |
| 33 | Insurance pilot proposal (Delta Dental CA) | Partnerships | 5K+ users, D30 > 20%, clinical validation started |
| 34 | In-app localization (Spanish voice lines) | App Store | Store listing localization showing demand |
| 35 | Paid influencer partnerships ($1K-3K/mo) | Social | Proven ROI from micro-influencer tests |
| 36 | Awards applications (Mom's Choice, NAPPA, Parents' Choice) | PR / App Store | 200+ reviews, 4.5+ stars |

---

## Month-by-Month Execution Calendar

### Month 1 (April 2026): Foundation

**Theme:** Launch to production, establish all channels, get first real users.

**Week 1:**
- [ ] ASO: Finalize Play Store listing (expanded description, 8 screenshots, feature graphic)
- [ ] ASO: Submit to "Designed for Families" program
- [ ] ASO: Set up AppFollow free tier + Google Alerts (brand + competitors)
- [ ] Partnerships: Create partner tracking spreadsheet (Google Sheets)
- [ ] Partnerships: Design and order generic QR code cards (Vistaprint)
- [ ] Partnerships: Create one-page partner info sheet (PDF)
- [ ] Partnerships: Add `/go?ref=` redirect handler to landing page
- [ ] Partnerships: Identify 20 pediatric dentists within 15 miles
- [ ] PR: Create media kit assets (screenshots, demo video, headshot)
- [ ] PR: Draft and finalize press release
- [ ] PR: Set up /press page on brushquest.app
- [ ] PR: Set up media tracking spreadsheet
- [ ] PR: Sign up for HARO/Connectively as expert source
- [ ] Social: Create TikTok account (@brushquest) and Instagram account (@brushquest)
- [ ] Social: Set up Buffer free tier
- [ ] Social: Film 3 initial videos (origin story, Oliver reaction, gameplay montage)
- [ ] Social: Set up Google Form for UGC submissions + release consent

**Week 2:**
- [ ] Partnerships: Send personalized outreach to all 20 dentists
- [ ] PR: Pitch Alameda Sun + Berkeleyside (local papers)
- [ ] PR: Pitch East Bay Times features desk
- [ ] PR: Send tip forms to all 5 Bay Area TV stations
- [ ] PR: Submit app to Common Sense Media for review
- [ ] Social: Begin posting cadence (3 TikToks/week + 2 Reddit posts/week)
- [ ] Social: DM 20 parent friends for app testing + reaction videos
- [ ] ASO: Expand description with SEO additions

**Week 3:**
- [ ] Partnerships: Follow-up emails to non-responders; visit 3-5 responsive practices
- [ ] PR: Follow up on Week 2 pitches (one follow-up each)
- [ ] PR: Pitch Scary Mommy (personal essay), Fatherly (dad-builds-app), Cool Mom Tech
- [ ] PR: Write IndieHackers "how I built it" draft
- [ ] Social: DM 10 micro-influencers (5K-50K followers)
- [ ] Social: Launch "Worst Brushing Story" campaign (#BrushQuestConfessions)

**Week 4 (LAUNCH WEEK -- when app hits production):**
- [ ] ASO: Launch to production on Play Store
- [ ] Partnerships: Drop off cards at all responsive dentist practices
- [ ] PR: Publish IndieHackers post
- [ ] PR: Post on Twitter/X with demo video + story thread
- [ ] PR: Email personal network (every parent Jim knows)
- [ ] Social: Post Reddit origin story on r/Daddit (timed with launch)
- [ ] Social: Post on r/Parenting, r/AndroidApps (staggered, not same day)
- [ ] Social: Create first Pinterest board with 10 dental fact pins
- [ ] Social: Set up Sunday batch workflow with Claude Code

**Jim's time this month:** ~10 hrs/week (heavy on setup, filming, dentist visits)
**Budget:** $0 (except ~$50 for card printing)

---

### Month 2 (May 2026): Validate and Scale What Works

**Theme:** Measure everything. Double down on winners. Cut losers.

**Ongoing weekly:**
- [ ] Social: 3 TikToks + 2 Reddit engagements + 2 Instagram Stories per week
- [ ] PR: Check HARO/Connectively daily (15 min, Claude scans)
- [ ] PR: Send 2-3 pitches/week (Claude drafts, Jim reviews)
- [ ] ASO: Weekly monitoring routine (15 min)
- [ ] Partnerships: Weekly Firebase referral data check

**Month-specific:**
- [ ] Partnerships: Send first monthly impact email to active dentist partners
- [ ] Partnerships: Outreach to next 10 dentists (expand radius to 25 miles)
- [ ] Partnerships: Identify 3 local PTAs for September program; begin outreach
- [ ] Partnerships: Contact 3-5 local parenting bloggers
- [ ] PR: Product Hunt launch (Tuesday or Wednesday, 2+ weeks after IndieHackers post)
- [ ] PR: Show HN post (3-7 days after Product Hunt)
- [ ] PR: Send to AI newsletters (Ben's Bites, The Rundown, TLDR)
- [ ] PR: Pitch 2 parenting podcasts + 2 indie maker podcasts
- [ ] Social: Evaluate pillar performance -- which content types get views/installs?
- [ ] Social: Launch "The Brush Off" challenge if UGC videos exist
- [ ] Social: Join 5 Facebook parenting groups (participate without mentioning app yet)
- [ ] ASO: Implement in-app review prompt logic (after 5th brush session)
- [ ] ASO: Implement share card generation at milestone moments

**Decision point (end of Month 2):**
- If any social content > 10K views: increase that pillar's cadence
- If Reddit origin story > 1K upvotes: write a follow-up post ("1 month later")
- If installs < 10/week from social after 6 weeks of posting: diagnose content vs. platform problem
- If D7 retention < 20%: STOP all growth work, fix the product

**Jim's time this month:** ~8 hrs/week
**Budget:** ~$100/month (contest prizes for #BrushQuestConfessions)

---

### Month 3 (June 2026): Growth Foundation

**Theme:** First A/B tests. Expand dentists to 50. Prep for fall seasonal push.

**Month-specific:**
- [ ] Partnerships: Expand dentist outreach to 50 across Northern California (email-only)
- [ ] Partnerships: Create PTA program kit (flyer, classroom poster, certificates)
- [ ] Partnerships: Build `brushquest.app/dentists` partner landing page
- [ ] Partnerships: Begin pediatrician outreach (adapt dentist playbook)
- [ ] PR: Monthly pitches continue (1/week). Pitch 2 dental podcasts.
- [ ] PR: Compile all coverage to date. Update media kit.
- [ ] Social: Add YouTube Shorts (cross-post from TikTok, no extra effort)
- [ ] Social: Begin mentioning app in Facebook groups (only in response to brushing questions)
- [ ] Social: "30-Day Streak Squad" campaign if users are hitting streaks
- [ ] ASO: First listing A/B test (short description variants, requires 500+ installs)
- [ ] ASO: Apply for Parents' Choice Award ($150)
- [ ] ASO: Reach out to 5 pediatric dentist bloggers for app reviews

**Decision point (end of Month 3 -- CRITICAL GATE):**
- Review all channels. Which are producing installs? Rank by installs/hour-of-Jim's-time.
- If total installs < 500: something fundamental is wrong. Is it product (retention)? Store listing (CVR)? Traffic (not enough eyeballs)?
- If D7 > 35% and 500+ installs: begin paid ad prep
- If social installs < 50 total after 3 months: CUT organic social. Redirect all time to dentist partnerships and PR.

**Jim's time this month:** ~7 hrs/week
**Budget:** ~$250 (contest prizes + Parents' Choice application)

---

### Month 4-5 (July-August 2026): Paid Growth Prep + Back-to-School

**Theme:** Build paid infrastructure. Time back-to-school seasonal push.

- [ ] ASO: Second A/B test (screenshot order or title variant)
- [ ] ASO: Set up Firebase Analytics events for paid attribution
- [ ] ASO: Begin Play Store listing localization (Spanish, Portuguese) if international interest shows
- [ ] Partnerships: 50+ active dentists. Monthly impact emails running.
- [ ] Partnerships: PTA outreach for September back-to-school programs
- [ ] Partnerships: Replenish cards at high-traffic practices
- [ ] PR: Back-to-school pitch angle ("Get back in the brushing routine")
- [ ] PR: Podcast appearances (aim for 1-2 recordings/month)
- [ ] Social: Scale to 5 TikToks/week if engagement warrants
- [ ] Paid: IF trigger metrics met (D7 > 35%, premium live, 4.3+ stars, CVR > 25%):
  - Record UGC-style ad creative
  - Launch Google App Campaigns at $500/month
  - Launch Facebook/Instagram ads at $500/month (2 weeks after Google)
  - Set up attribution tracking
- [ ] App: Implement referral link system (soft referral, no rewards yet)
- [ ] App: Begin iOS port planning

**Jim's time:** ~6 hrs/week
**Budget:** $0-1,000/month (paid ads only if trigger metrics are met)

---

### Month 6-8 (September-November 2026): Scale + iOS + Halloween

**Theme:** iOS doubles the market. Halloween is the best non-February content hook.

- [ ] ASO: iOS TestFlight beta (50-100 testers from email list)
- [ ] ASO: iOS App Store launch with full ASO (if beta validates)
- [ ] ASO: Apple Search Ads campaign ($500/month)
- [ ] Partnerships: First PTA programs running (back-to-school)
- [ ] Partnerships: 100+ active dentist partners
- [ ] Partnerships: Begin approaching small consumer brands (Quip, AutoBrush)
- [ ] PR: October Halloween pitch ("Candy season is here. Is your kid ready?") -- pitch in September
- [ ] PR: Holiday gift guide pitches (pitch in October for November-December inclusion)
- [ ] Social: "Monster of the Week" campaign running continuously
- [ ] Social: Begin paid boosting of top organic content ($500-1K/month)
- [ ] Paid: Scale winning channels. Kill losers. Target $2K-5K/month total if LTV:CAC > 2x.
- [ ] Paid: TikTok Ads test ($500/month)

**Jim's time:** ~6 hrs/week
**Budget:** $2K-5K/month (paid ads + influencer tests)

---

### Month 9-12 (December 2026 - March 2027): Compound + B2B2C Prep

**Theme:** Compounding growth. Begin the insurance play. February is the golden month.

- [ ] Partnerships: 200+ active dentist partners (partner landing page driving inbound)
- [ ] Partnerships: Begin building insurance pitch deck
- [ ] Partnerships: Start clinical validation (survey 500 parents OR dental school partnership)
- [ ] Partnerships: Approach Delta Dental of California for exploratory conversation
- [ ] Partnerships: 5+ school programs completed
- [ ] PR: January pitch wave (New Year health habits + February NCDHM preview)
- [ ] PR: February = maximum press effort (National Children's Dental Health Month)
- [ ] PR: If 10K+ downloads and 4.5+ rating: begin national media push
- [ ] Social: Formal referral program with premium rewards (if premium is live)
- [ ] Social: Scale influencer partnerships ($1K-3K/month for proven-ROI creators)
- [ ] ASO: In-app localization (Spanish voice lines) if listing localization shows demand
- [ ] ASO: Apply for Google Play Indie Games Accelerator
- [ ] Paid: Scale ad spend to $5K-10K/month if LTV:CAC > 3x

**Jim's time:** ~5-6 hrs/week (systems are running, Jim focuses on high-leverage activities)
**Budget:** $5K-10K/month (paid ads + partnerships + influencers)

---

## Automation Architecture

### The Engine Diagram

```
                  FULLY AUTOMATED                    SEMI-AUTOMATED              JIM ONLY
               (runs without Jim)                (Claude drafts, Jim reviews)    (can't delegate)
              ========================          ========================       ========================
SOCIAL        | Dental fact graphics  |         | TikTok/Reels captions |     | Film video (Oliver/Theo)
              | Monster of the Week   |         | Reddit post drafts    |     | Respond to comments/DMs
              | Cross-posting via     |         | Weekly content batch   |     | Facebook Group participation
              |   Repurpose.io        |         | UGC repost selection   |     | Reddit engagement
              | Content calendar      |         | Hashtag research       |     |
              |   reminders           |         |                        |     |
              ========================          ========================       ========================

PARTNERSHIPS  | Monthly partner impact |        | Dentist outreach       |     | In-person dentist visits
              |   emails (drafted)     |        |   emails (personalized)|     | PTA meetings
              | Follow-up task list    |        | PTA materials          |     | Partnership conversations
              |   generation           |        |   (customized)         |     | Podcast recordings
              | Ref code tracking      |        |                        |     |
              ========================          ========================       ========================

PR            | HARO/Connectively     |         | Press pitch drafts     |     | Send pitches (from Jim's email)
              |   scanning            |         | Personal essay drafts  |     | Journalist phone calls
              | Google Alerts         |         | Media kit updates      |     | TV/radio appearances
              | Press clipping        |         | Social amplification   |     | Product Hunt launch day
              |   collection          |         |   of coverage          |     |
              ========================          ========================       ========================

APP STORE     | ASO keyword tracking  |         | A/B test variant       |     | Approve test results
              | Review monitoring +   |         |   creation             |     | Record ad creative video
              |   alerts              |         | Ad headline/description|     | Review negative reviews
              | Competitor monitoring  |         |   variants             |     |   (personal responses)
              | Firebase analytics    |         | Review response drafts |     |
              |   dashboards          |         |                        |     |
              ========================          ========================       ========================
```

### Tool Stack (Cost at Each Phase)

| Tool | Purpose | Month 1 Cost | Month 6 Cost |
|------|---------|-------------|-------------|
| Claude Code | Content generation, outreach drafting, analytics | Already paying | Already paying |
| Buffer (free -> $6/mo) | Social scheduling | $0 | $6 |
| Repurpose.io | Cross-posting TikTok to Reels/Shorts | $0 (manual) | $25 |
| CapCut | Video editing | $0 | $0 |
| Canva (free tier) | Graphics, cards, info sheets | $0 | $0 |
| Google Sheets | CRM, tracking, keyword ranks, metrics | $0 | $0 |
| Google Forms | UGC collection, partner sign-ups | $0 | $0 |
| Google Alerts + Talkwalker | Brand/competitor monitoring | $0 | $0 |
| AppFollow (free tier) | ASO keyword tracking, review monitoring | $0 | $0 |
| Firebase Analytics | In-app events, attribution | $0 | $0 |
| Google Play Console | Install metrics, A/B tests, reviews | $0 | $0 |
| Vistaprint | QR code card printing | ~$50 one-time | ~$25/quarter |
| HARO/Connectively | Journalist query matching | $0 | $0 |
| **Total** | | **~$50** | **~$56/month** |

### Claude Code Cron Jobs (Automated Weekly)

These run as scheduled Claude Code tasks:

| Job | Schedule | What It Does |
|-----|----------|-------------|
| Weekly content batch | Sunday 9am | Generates 7-10 social media posts with captions, hashtags, and image specs. Outputs to a review folder. |
| HARO scanner | Daily 7am | Scans HARO/Connectively daily emails. Flags queries matching: parenting, dental, kids apps, AI, solo founder. |
| Partnership follow-up list | Monday 8am | Reads CRM spreadsheet. Generates task list: who needs follow-up, who needs monthly check-in. |
| Metrics dashboard update | Monday 8am | Pulls Play Console stats, social analytics. Generates one-page weekly report. |
| Review alert responder | Daily 6pm | Checks for new 1-3 star reviews. Drafts personalized responses for Jim to send. |
| Competitor scan | 1st Monday of month | Checks competitor listings for changes, reads their latest reviews. |
| Keyword rank check | Monday 8am | Records Play Store keyword positions for 20 tracked keywords. |

---

## Jim's Weekly Time Budget

### Month 1: ~10 hours/week

| Activity | Time | Frequency |
|----------|------|-----------|
| Film 2 videos (Oliver/Theo/gameplay) | 30 min | 2x/week |
| Review + schedule weekly content batch | 30 min | Sunday |
| Reply to social comments/DMs | 10 min | Daily |
| Dentist outreach (emails + visits) | 2 hrs | Weekly |
| Review + send PR pitches | 30 min | Weekly |
| Check HARO + respond to queries | 15 min | Daily (Mon-Fri) |
| ASO monitoring + review responses | 30 min | Weekly |
| Engineering (review prompts, share cards) | 2 hrs | Weekly |
| **Total** | **~10 hrs** | |

### Month 2-3: ~8 hours/week

| Activity | Time | Frequency |
|----------|------|-----------|
| Film 1-2 videos | 30 min | 1-2x/week |
| Review + schedule content batch | 30 min | Sunday |
| Reply to social comments/DMs | 10 min | Daily |
| Partnership management (emails, follow-ups) | 1.5 hrs | Weekly |
| Review + send PR pitches | 30 min | Weekly |
| HARO monitoring | 15 min | Daily (Mon-Fri) |
| ASO monitoring + A/B tests | 30 min | Weekly |
| Podcast recording (when scheduled) | 45 min | 1-2x/month |
| **Total** | **~8 hrs** | |

### Month 4-6: ~6 hours/week

| Activity | Time | Frequency |
|----------|------|-----------|
| Film 1 video | 20 min | Weekly |
| Review + schedule content batch | 20 min | Sunday |
| Reply to comments/DMs | 10 min | Daily |
| Partnership management | 1 hr | Weekly |
| Review PR pitches + coverage amplification | 20 min | Weekly |
| HARO monitoring | 10 min | Daily (Mon-Fri) |
| ASO + paid ads monitoring | 30 min | Weekly |
| Podcast recording | 45 min | Monthly |
| **Total** | **~6 hrs** | |

### Month 7-12: ~5-6 hours/week

Same as Month 4-6, plus:
- B2B2C relationship building: 1 hr/week (replaces some partnership management time)
- iOS launch activities: burst of 10 hrs over 2 weeks, then back to baseline

---

## Unified Metrics Dashboard

Track weekly in a single Google Sheet with tabs per channel.

### North Star Metrics (check weekly, act on monthly)

| Metric | Month 1 | Month 3 | Month 6 | Month 12 |
|--------|---------|---------|---------|----------|
| **Total installs** | 100+ | 1,000+ | 10,000+ | 100,000+ |
| **Monthly active users** | 50+ | 500+ | 5,000+ | 50,000+ |
| **D7 retention** | 25%+ | 35%+ | 40%+ | 40%+ |
| **D30 retention** | 15%+ | 20%+ | 25%+ | 25%+ |
| **Play Store rating** | 4.5+ | 4.5+ | 4.5+ | 4.5+ |
| **Review count** | 10+ | 50+ | 200+ | 1,000+ |

### Channel-Specific Metrics

**Social Media:**

| Metric | Month 1 | Month 3 | Month 6 |
|--------|---------|---------|---------|
| TikTok followers | 500 | 5,000 | 25,000 |
| Avg views/video | 1,000+ | 5,000+ | 10,000+ |
| Installs from social/week | 10+ | 50+ | 200+ |
| UGC submissions/month | 3+ | 10+ | 25+ |
| Email signups from social | 50 | 200 | 500 |

**Partnerships:**

| Metric | Month 1 | Month 3 | Month 6 | Month 12 |
|--------|---------|---------|---------|----------|
| Active dentist partners | 3-5 | 20+ | 50+ | 200+ |
| Installs from dentists/month | 90-120 | 600+ | 1,500+ | 6,000+ |
| Active school programs | 0 | 1-3 | 5+ | 10+ |
| Partner referral tracking working | Y/N | Y | Y | Y |

**PR & Earned Media:**

| Metric | Month 1 | Month 3 | Month 6 |
|--------|---------|---------|---------|
| Pitches sent | 10+ | 30+ | 60+ |
| Response rate | 15-25% | 15-25% | 15-25% |
| Published coverage pieces | 1-2 | 5+ | 10+ |
| Podcast appearances | 0 | 2+ | 5+ |
| "As seen in" logos for media kit | 0 | 3+ | 5+ |

**App Store / Paid:**

| Metric | Month 1 | Month 3 | Month 6 | Month 12 |
|--------|---------|---------|---------|----------|
| Store listing CVR | 20%+ | 25%+ | 30%+ | 30%+ |
| CPI (paid) | N/A | $3.00 | $2.00 | $1.50 |
| LTV:CAC | N/A | 1.5x | 3x | 5x+ |
| Daily installs (total) | 3-7 | 15-30 | 70-170 | 300+ |

### Trigger Points (Phase Gates)

| Trigger | Threshold | What It Activates |
|---------|-----------|-------------------|
| D7 retention < 20% | Alarm | STOP all growth. Fix product. |
| Any social post > 10K views | Signal | Increase that content type's cadence |
| Email list > 100 from social | Signal | Move to Phase 1 social cadence (5 posts/week) |
| 500 total installs | Gate | Begin A/B testing store listing |
| D7 > 35% + premium live + 4.3+ stars | Gate | Begin paid acquisition ($500/mo per channel) |
| 50+ installs/week from social | Signal | Social is working. Scale it. |
| < 50 social installs after 3 months | Kill switch | Cut organic social. Redirect to partnerships/paid. |
| < 5 installs/month from a platform after 8 weeks | Kill switch | Stop posting on that platform. |
| 10K+ installs, 4.5+ stars | Gate | Begin national media push |
| 5K+ MAU, D30 > 20% | Gate | Begin insurance exploratory conversations |
| LTV:CAC > 3x on paid | Gate | Scale ad spend aggressively |

---

## Cross-Channel Feedback Loops

These are the explicit connections between channels. Data from one channel informs another.

### Loop 1: Social Content --> PR Story Angles
- **Signal:** Which TikTok/Reddit posts get the most engagement?
- **Action:** The top-performing content themes become the lead angle in PR pitches. If "dad builds app" posts outperform "dental facts," lead all pitches with Angle A.
- **Frequency:** Monthly review.

### Loop 2: PR Coverage --> Social Content
- **Signal:** A press article or TV segment publishes.
- **Action:** Immediately repurpose into social content. Share the clip/article. Create "As seen in [outlet]" posts. Screen-record the TV segment. This content converts because it carries third-party credibility.
- **Frequency:** As coverage lands.

### Loop 3: Dentist Feedback --> Product + Messaging
- **Signal:** What questions do dentists ask? What objections come up? What language do they use?
- **Action:** Refine the pitch template, update the info sheet, and feed the language into social content and PR pitches. If dentists say "parents ask me about brushing apps all the time," that becomes a content pillar.
- **Frequency:** After every dentist visit.

### Loop 4: Play Store Reviews --> Everything
- **Signal:** What do parents praise? What do they complain about?
- **Action:**
  - Praise quotes become social proof in PR pitches, social content, and landing page.
  - Common complaints inform product roadmap AND competitor positioning in the store listing ("actively maintained" if competitors aren't updating).
  - Parent language in reviews becomes keyword targets for ASO.
- **Frequency:** Weekly review scan.

### Loop 5: ASO Data --> Paid Ad Targeting
- **Signal:** Which keywords drive installs organically? Which screenshot gets the most clicks?
- **Action:** Organic winners become paid ad keywords and creative. The headline that wins in the A/B test becomes the ad headline.
- **Frequency:** After each A/B test completes.

### Loop 6: Paid Ad Creative --> Organic Social
- **Signal:** Which paid ad creative gets the lowest CPI?
- **Action:** That creative format and messaging becomes the template for organic social posts. If UGC-style parent testimonial video beats gameplay capture in ads, make more organic parent testimonial content.
- **Frequency:** Bi-weekly.

### Loop 7: Social Traction --> Partnership Credibility
- **Signal:** TikTok followers, viral posts, press mentions.
- **Action:** Add these numbers to dentist outreach emails and partner info sheets. "Our TikTok videos on brushing have reached 500K parents" makes the dentist take the partnership more seriously.
- **Frequency:** Update materials monthly.

### Loop 8: User Milestones --> Shareable Moments --> New Users
- **Signal:** In-app events (7-day streak, hero evolution, boss defeat).
- **Action:** Trigger share card generation. Parent shares. New parent discovers app.
- **Measurement:** Track `share_triggered` > `share_completed` > `referral_install` funnel.
- **Frequency:** Continuous (automated in-app).

---

## Open Questions for Jim

These require Jim's input before execution. Not blockers for starting, but need answers within the first 2 weeks.

### Content & Brand

1. **How comfortable is Jim showing Oliver and Theo on camera?** The strategies heavily rely on kid reaction content. Options: (a) full face on camera, (b) over-the-shoulder/hands only, (c) no kid footage. Each dramatically changes the content ceiling. Hands-and-screen is the safe default and still effective.

2. **What is Jim's comfort level with the "founder story" as the primary narrative?** The PR and social strategies both identify "Dad builds app because his kid won't brush" as the #1 angle. Is Jim ready to be the public face of the company? Podcast appearances, TV demos, photo in media kit?

3. **Does Jim have any parent friends who would genuinely try the app in Week 1?** The cold-start content plan calls for DMing 20 parent friends. How many can Jim realistically contact?

### Product

4. **When will the app hit the public/production Play Store track?** The entire engine is gated on this. Internal testing is live as of April 2, but most tactics require a publicly downloadable app.

5. **What is the premium tier timeline?** Paid acquisition is gated on having monetization live (to measure ROAS). The four strategies assume premium ships "after 100 users with D7 > 35%." Is this 2-3 months out?

6. **Is multi-profile (sibling support) on the roadmap before or after the premium tier?** Several virality mechanics (family invite, sibling competition) depend on this.

7. **Share card generation and in-app review prompts -- does Jim want to build these in the first 2 weeks, or defer?** Both are high-impact engineering tasks (~4 hrs each) that compete with GTM execution time.

### Partnerships

8. **Is Jim willing to do in-person dentist visits?** The strategy calls for visiting 3-5 practices in person during Week 3. This is high-impact but time-intensive. If not, email-only outreach still works, just with lower conversion (~20% vs ~40%).

9. **Does Jim already have a relationship with Oliver's dentist or pediatrician?** This would be the ideal first partner -- warm intro, genuine story.

### Budget

10. **What is the monthly GTM budget Jim is comfortable with?** Month 1 is $0-50. By Month 6, the plan calls for $2K-5K/month in paid ads + influencers. Where is Jim's comfort zone? This directly affects how fast paid channels get activated.

---

## Issues and Contradictions Found

### 1. Product Hunt Timing Conflict

**Social strategy** says: "Product Hunt launch in Week 5-8."
**PR strategy** says: "Product Hunt launch Day +3 of production launch."
**App Store strategy** says: "Prerequisite: App must be publicly available on Play Store."

**Resolution:** Product Hunt requires a publicly available app. The PR strategy's "Day +3" timing only works if the app is public by then. The social strategy's Week 5-8 is more realistic because it gives time for the app to leave internal testing, accumulate some reviews, and build the PH community presence (2+ weeks of activity before launch). **Recommendation: Product Hunt in Week 6-8, NOT launch week.** Use launch week for Reddit, personal network, and local press instead.

### 2. Reddit Posting Cadence Overload

**Social strategy** says: 2 Reddit posts/week ongoing.
**PR strategy** says: Reddit origin story + r/AndroidApps + r/Parenting in Launch Week.

**Issue:** Posting the same app to multiple subreddits in the same week will get flagged as spam. Reddit is the most automation-hostile platform.

**Resolution:** ONE Reddit post per week maximum. Launch week: r/Daddit origin story only. Stagger r/Parenting and r/AndroidApps over the following 2 weeks. Never post the same content to multiple subreddits.

### 3. Time Budget Underestimates

Each strategy independently claims a modest time budget:
- Social: 3-4 hrs/week
- PR: 2.5 hrs/week
- Partnerships: 4 hrs/week
- App Store: 2 hrs/week (monitoring + engineering)

**Sum: ~12 hrs/week.** For a solo founder who also needs to ship product updates, respond to user issues, and maintain the codebase, this is aggressive. The month-by-month calendar above sequences activities to keep total time at 8-10 hrs/week in Month 1 and dropping to 5-6 by Month 4.

**Key tradeoff:** In Month 1, Jim must choose between shipping more product features and executing GTM. The plan assumes product is feature-complete enough for production launch and Jim shifts to 60% GTM / 40% product for Months 1-2.

### 4. Paid Growth Trigger Assumes Premium Tier

All four strategies agree: do not spend on paid ads until premium is live and LTV can be measured. But the partnership and social strategies aggressively build the free user base, which creates retention data but no revenue.

**Issue:** If premium takes 4-6 months to ship, Jim will have thousands of users with zero revenue and no ability to validate paid acquisition economics.

**Resolution:** Accept this. The free user base generates the data (retention, engagement, testimonials) needed for everything else. Paid acquisition without LTV measurement is just spending money. Ship premium as soon as D7 > 35% and user count > 100. This should be a top engineering priority alongside GTM.

### 5. Content Volume is Unrealistic at Launch

The social strategy calls for 8 posts/week in Phase 0 (3 TikToks + 2 Reddit + 2 Stories + 1 Pinterest). This is a lot for a solo founder who has never posted on TikTok before.

**Resolution:** Start with 4 posts/week maximum in Week 1 (2 TikToks + 1 Reddit + 1 Story). Increase to the full cadence only after the Sunday batch workflow is established and Jim has a rhythm. Quality over quantity. One viral TikTok is worth more than 10 mediocre ones.

### 6. Dentist Partnership Revenue Model Is Premature

The partnerships strategy details revenue models for dentists ($49/month per location at Phase 3, enterprise pricing for DSOs at Phase 4). These are reasonable long-term visions but should not distract from the Phase 0-1 goal: free distribution with zero friction.

**Resolution:** Do not even mention revenue to dentists until Year 1+ and until a premium tier exists that dentists could gift to patients. For Months 1-12, the dentist value proposition is 100% free, 100% effortless.

### 7. Insurance B2B2C Timeline is Optimistic

The partnerships strategy says "Timeline to first insurance pilot: 12-18 months." This is optimistic for a zero-user app. Insurance companies need:
- 5K+ active users (realistic at Month 8-10)
- Clinical validation (12-24 months even with the cheapest option)
- HIPAA review (if any health data integration)
- SOC 2 certification (6-9 months and $15K-50K)

**Resolution:** Insurance is a Year 2-3 play, not Year 1. Jim should begin the clinical validation path early (survey at 500+ users, dental school conversation at 1,000+ users) but should not invest significant time in insurance outreach until the evidence base is strong. The Delta Dental exploratory conversation at Month 9-12 is fine as a learning exercise, not a deal expectation.

### 8. iOS Timeline Needs Clarification

The App Store strategy says iOS TestFlight at Month 4-5 and launch at Month 6. But the Flutter codebase is Android-only and iOS requires:
- Apple Developer Account ($99/year)
- iOS-specific build configuration
- Parental gate for Apple Kids category
- Privacy nutrition label
- iOS-specific testing
- App Store review (notoriously unpredictable for kids apps)

**Resolution:** iOS is important (doubles the addressable market, higher-spending users) but should not cannibalize Android product quality. Realistic timeline: begin iOS work at Month 3-4, TestFlight at Month 5-6, launch at Month 7-8. This gives time for the Android version to stabilize and accumulate the data that proves the product works.

### 9. Micro-Influencer Strategy Needs Guardrails

The social strategy recommends DM'ing 10 micro-influencers in Week 2-4 and paying $100 each starting Month 4-6. The PR strategy also mentions influencer-adjacent publications.

**Risk:** Sending product to influencers before you have 50+ reviews and a stable product creates a risk of negative public feedback that is hard to walk back.

**Resolution:** Micro-influencer outreach is fine in Month 1, but only as "free trial, honest feedback, no pressure to post." Paid influencer partnerships should wait until the app has 200+ installs, 4.3+ rating, and Jim has seen at least one organic positive UGC post. This likely means Month 3 at the earliest.

### 10. The "Kill Switch" Definitions Need Alignment

Each strategy has its own kill switches with slightly different thresholds:
- Social: < 50 installs after 3 months from social
- Social: < 5 installs/month from a platform after 8 weeks
- PR: No responses after 20 pitches means angle/targeting issue
- App Store: D7 < 20% means stop all growth
- All: D7 < 20% stop everything (from STRATEGY.md)

**Resolution:** The unified kill switches are:
1. **D7 < 20%: STOP ALL GROWTH. Fix the product.** (Applies everywhere.)
2. **< 5 installs/month from any single platform after 8 weeks: Cut that platform.**
3. **< 50 total installs from social after 3 months: Pivot from organic social to partnerships + paid.**
4. **0 PR responses after 20 pitches: Rewrite pitch, test new angles, try different outlets.**
5. **Paid CPI > 2x the target for 2 consecutive weeks: Pause that ad channel, diagnose creative/targeting.**

---

*This is a living document. Update monthly as data comes in. The specific numbers are estimates that MUST be validated with real data. Never scale spend based on projections alone -- only on measured unit economics. The engine is designed to start cheap, learn fast, and scale only what works.*
