# Round 5: Sequencing Logic and Metrics Framework

**Date:** 2026-04-03
**Role:** Growth metrics and operations expert
**Inputs:** R4 Synthesis v2, R3 Solo Founder Critique
**Purpose:** The operating manual. Not strategy -- execution rules. Tells Jim exactly what to do next based on data.

---

## 1. The Channel Activation Tree

Every channel has an entry condition, a rationale, and a kill condition. Jim does not decide "should I try TikTok this week?" -- he checks the tree. If the conditions are met, he activates. If not, he waits.

### Always-On Channels (Active from Day 1)

```
CHANNEL: ASO Optimization
  STATUS: Always on
  BECAUSE: Every other channel drives people to the Play Store listing.
           A 5% CVR improvement compounds across all traffic forever.
  CADENCE: Monthly review of keywords + quarterly screenshot refresh
  KILL CONDITION: Never. This is infrastructure, not a channel.
```

```
CHANNEL: Play Store Review Monitoring + Responses
  STATUS: Always on
  BECAUSE: Reviews are social proof. Responding shows the app is maintained.
           Every unanswered 1-3 star review costs future installs.
  CADENCE: Check 3x/week (Mon/Wed/Fri, 5 min each). Respond within 24 hours.
  KILL CONDITION: Never.
```

```
CHANNEL: In-App Review Prompt
  STATUS: Always on (after engineering build)
  BECAUSE: The only growth mechanic that scales without Jim's time.
           Runs forever once built.
  KILL CONDITION: Never. Adjust trigger timing based on data
           (e.g., move from 5th brush to 7th if D7 retention is low).
```

### Phase 0-1 Channels (Month 1-2)

```
CHANNEL: Reddit Origin Story (r/Daddit)
  IF: App is live on public Play Store production track
  THEN: Post the drafted origin story on r/Daddit
  BECAUSE: Highest-ceiling single free tactic. One authentic post can
           generate 50-500 installs in a weekend with zero ongoing commitment.
  CADENCE: One post. Engage with comments for 48 hours. Then move on.
  FOLLOW-UP: If >200 upvotes, post r/AndroidApps 1 week later (different angle).
             If >500 upvotes, post r/Parenting 1 week after that.
  STOP IF: <20 upvotes after 24 hours. The topic didn't land. Don't repost.
           Try a different angle on r/AndroidApps in 2 weeks.
```

```
CHANNEL: Local Dentist Outreach
  IF: App is live on public Play Store AND prescription cards printed
  THEN: Start with Oliver's dentist (warm intro). Email 4 more local practices.
  BECAUSE: Highest-trust distribution channel in the kids dental category.
           One receptive dentist = 2-5 installs/month on autopilot.
  CADENCE: 5 new outreach attempts/month. 1-2 in-person visits/month.
  STOP IF: <2 partners after 15 outreach attempts (month 2-3).
           Pivot to email-only at scale instead of in-person visits.
           Revisit messaging -- the pitch may need rework, not more volume.
```

```
CHANNEL: TikTok Content
  IF: App is live on Play Store AND Jim has filmed 1 test video
  THEN: Post 2 videos/week starting Week 2 of Month 1
  BECAUSE: Algorithmic discovery means even zero-follower accounts can
           reach parents. Low floor, high ceiling.
  CADENCE: 2 videos/week. Batch-film on one day. Cross-post to Reels.
  STOP IF: Average views <200 after 20 videos (roughly Week 10).
           Reduce to 1/week and reallocate time to dentist outreach.
  KILL AFTER: 3 months with <50 total attributable installs from social.
              Cut organic social entirely. Go all-in on dentists + ASO.
```

```
CHANNEL: Instagram Cross-Posting
  IF: TikTok content creation is active
  THEN: Cross-post every TikTok to Instagram Reels (manual, 5 min each)
  BECAUSE: Marginal effort for double the distribution surface.
           Some parents are on Instagram but not TikTok.
  CADENCE: Same as TikTok (every video gets cross-posted).
  STOP IF: Instagram generates <10% of social installs after 2 months.
           Stop cross-posting. Focus TikTok only.
  UPGRADE: When posting 5+ videos/week, pay for Repurpose.io ($25/mo)
           to automate cross-posting.
```

### Phase 1 Channels (Month 2-3)

```
CHANNEL: PR Pitches (Local Media)
  IF: App has 10+ reviews AND 4.0+ stars
  THEN: Pitch Alameda Sun first (lowest bar), then Berkeleyside, then East Bay Times
  BECAUSE: Local press is the easiest entry point. "Local dad builds app"
           is a story every community paper wants to tell.
  CADENCE: 1 pitch/week. Claude drafts, Jim personalizes and sends.
  STOP IF: 0 responses after 6 pitches over 6 weeks.
           Rework the pitch angle. Try a seasonal hook instead of the origin story.
  KILL AFTER: 0 published pieces after 12 pitches. Local press is not biting.
              Defer PR entirely until a natural news hook appears
              (award win, milestone, seasonal moment).
```

```
CHANNEL: Product Hunt Launch
  IF: 20+ reviews AND 4.3+ stars AND share card feature built
  THEN: Schedule a Product Hunt launch (4-6 hours over 2 days)
  BECAUSE: One-time burst with long-tail SEO benefit.
           Product Hunt audience skews technical but includes parents.
  CADENCE: One launch. Show HN post 3-7 days later.
  STOP IF: <50 upvotes after 24 hours. Do not try to relaunch.
           PH audience was not the right fit. Move on.
```

### Phase 2 Channels (Month 4-6, trigger-gated)

```
CHANNEL: PR Pitches (Parenting Media)
  IF: 1+ local press clip published AND 50+ reviews AND 4.3+ stars
  THEN: Pitch parenting outlets (Scary Mommy, Fatherly, Romper, Today's Parent)
  BECAUSE: National parenting media drives high-intent installs.
           The local press clip proves the story is publishable.
  CADENCE: 2 pitches/week. Batch on Monday.
  STOP IF: 0 responses after 10 pitches.
           Rework angle. Try a seasonal hook or data-driven story
           ("We tracked 1,000 brushing sessions -- here's what we learned").
  KILL AFTER: 0 published pieces after 20 pitches over 2 months.
              Parenting media is not receptive. Redirect time to podcasts.
```

```
CHANNEL: PR Pitches (Tech Media)
  IF: 1,000+ installs AND 1+ press clip AND a clear "indie dev" story angle
  THEN: Pitch TechCrunch, The Verge, Mashable (solo dev angle, not product review)
  BECAUSE: Tech press drives a different audience (gift-givers, tech-forward parents).
           Only worth it with proof of traction.
  CADENCE: 1 pitch/week.
  STOP IF: 0 responses after 8 pitches.
           Tech media requires bigger numbers. Revisit at 10K+ installs.
```

```
CHANNEL: Podcast Pitching
  IF: 1+ published press clip (gives credibility) AND Jim is comfortable doing interviews
  THEN: Pitch 2 podcasts/week (dad/parenting + indie dev categories)
  BECAUSE: Long-form storytelling. Parents who listen to parenting podcasts
           are high-intent. Evergreen discovery via podcast search.
  CADENCE: 2 pitches/week. Budget 45 min per recording when booked.
  STOP IF: 0 bookings after 10 pitches.
           Rework the pitch. Add a data angle or timely hook.
  KILL AFTER: 3 podcast appearances with <20 attributable installs total.
              The audience is not converting. Redirect time.
```

```
CHANNEL: PTA/School Outreach
  IF: 5+ active dentist partners (proves the materials work in professional settings)
       AND it is June-August (preparing for September back-to-school)
  THEN: Create PTA program kit (outsource design). Approach 3-5 local schools.
  BECAUSE: Schools are a multiplier -- one PTA presentation reaches 50-200 parents.
           But the materials must be proven with dentists first.
  CADENCE: 2 hrs/week for 3 weeks (kit creation + outreach). Then 30 min/week.
  STOP IF: 0 schools respond after 5 approaches.
           The pitch needs rework. Try approaching through a dentist partner
           who has a relationship with the school.
  KILL AFTER: 2 PTA programs completed with <10 installs each.
              The conversion funnel is broken. Revisit materials.
```

```
CHANNEL: Grandparent Channel (Facebook)
  IF: Premium tier live OR 1,000+ total installs (enough to justify the time)
  THEN: Create Facebook page. Post 2-3x/week targeting grandparent demographics.
        "Gift the habit" messaging.
  BECAUSE: Grandparents are the #1 gift-givers for kids digital content.
           Facebook is where they are. This channel has almost no competition.
  CADENCE: 1 hr/week (Claude drafts, Jim posts).
  STOP IF: <50 page followers after 6 weeks of consistent posting.
           Facebook organic reach may be too low. Test $50 boosted posts.
  KILL AFTER: $200 spent on boosted posts with <20 installs.
              Facebook is not converting grandparents at viable economics.
```

### Phase 3 Channels (Month 7-12, trigger-gated)

```
CHANNEL: Award Submissions (Beyond CSM/Parents' Choice)
  IF: Revenue covers application fees ($200-300 each)
       AND app has 4.5+ stars with 100+ reviews
  THEN: Apply to Mom's Choice ($295), NAPPA ($195), Google Play Teacher Approved (free)
  BECAUSE: Award badges are permanent trust signals on screenshots.
           They convert fence-sitting parents.
  CADENCE: 1 application per quarter. Track review timelines.
  STOP IF: First 2 applications result in no award. Revisit product quality.
```

```
CHANNEL: Paid Ads -- Google App Campaigns
  IF: D7 retention >35%
      AND premium tier live (revenue to fund spend)
      AND 4.3+ stars
      AND Play Store CVR >25%
      AND at least $500/month available for ad spend
  THEN: Start Google App Campaigns at $500/month
  BECAUSE: Google's ML optimizes for installs. But only worth it when
           the funnel converts and users retain.
  CADENCE: Set up campaign. Monitor weekly. Adjust bids monthly.
  FIRST TEST: Run for 2 weeks at $15/day. Measure CPI.
  STOP IF: CPI >$3.00 after 2 weeks of optimization.
           The store listing is not converting paid traffic.
           Fix listing first, then retry.
  KILL AFTER: CPI >$2.00 consistently after 4 weeks AND LTV <$4.00.
              Paid acquisition is not viable at current economics.
```

```
CHANNEL: Paid Ads -- Facebook/Instagram
  IF: Google App Campaigns profitable for 2+ weeks (CPI < LTV/3)
  THEN: Start Facebook/Instagram ads at $500/month
  BECAUSE: Facebook allows demographic targeting (parents of 5-10 year olds).
           But test Google first -- it's simpler and self-optimizing.
  CADENCE: Weekly creative refresh. Monthly budget review.
  FIRST TEST: 3 ad creatives. Run for 2 weeks. Measure CPI per creative.
  STOP IF: CPI >$4.00 after 2 weeks (FB typically higher CPI than Google).
  KILL AFTER: CPI consistently 2x Google with similar retention.
              Redirect budget to Google.
```

```
CHANNEL: Paid Ads -- TikTok
  IF: Facebook/Instagram ads profitable for 4+ weeks
      AND Jim has 3+ high-performing organic TikToks (10K+ views)
  THEN: Boost top-performing organic TikToks at $200/month
  BECAUSE: TikTok ads work best when they look like organic content.
           Only worth it with proven creative.
  CADENCE: Boost 1-2 top performers per week. $10-15/day each.
  STOP IF: CPI >$5.00 (TikTok tends to be expensive for app installs).
  KILL AFTER: $400 spent with <50 installs. Platform is not cost-effective.
```

```
CHANNEL: Dental Insurance Outreach
  IF: 5,000+ MAU AND D30 >20% AND 50+ dentist partners
  THEN: Exploratory conversations with Delta Dental, Cigna dental benefits
  BECAUSE: Insurance companies want to reduce claims. A proven brushing habit
           tool is valuable to them. But they need proof at scale.
  CADENCE: 1-2 emails/month. This is a long sales cycle (6-12 months).
  STOP IF: 0 responses after 5 outreach attempts. Revisit at 20K+ MAU.
```

```
CHANNEL: Brand Partnerships
  IF: 10,000+ MAU AND clear brand story AND proven engagement metrics
  THEN: Approach kid-friendly brands (toothpaste companies, vitamin brands)
  BECAUSE: Co-marketing with established brands gives distribution leverage.
           But brands only partner with proven products.
  CADENCE: 1 outreach/month. Long sales cycle.
  STOP IF: 0 responses after 5 attempts. Not enough traction yet. Revisit at 50K MAU.
```

---

## 2. The Metrics Framework

### Core Metric: Daily Installs

| Attribute | Detail |
|-----------|--------|
| **What it measures** | New app installations per day. The most direct measure of whether GTM is working. |
| **Why it matters** | It is the input to everything else -- without installs, retention, reviews, and revenue are zero. |
| **Where to find it** | Google Play Console > Statistics > Installs by device |
| **How often to check** | Daily glance (30 seconds). Weekly deep-dive (10 min). |
| **Green** | Month 1: 2+/day. Month 3: 5+/day. Month 6: 15+/day. Month 12: 50+/day. |
| **Yellow** | 50-75% of green threshold. Trend flat or declining for 7+ days. |
| **Red** | <50% of green threshold OR 14+ day declining trend. |
| **Green action** | Keep doing what you are doing. Focus on retention. |
| **Yellow action** | Check by channel: which source dried up? Is it seasonal? Did a Reddit post age off? Did a dentist remove your cards? Diagnose before acting. |
| **Red action** | Emergency review. Check: (1) Is the Play Store listing broken? (2) Did a bad review tank the rating? (3) Did a channel get killed by algorithm change? Fix the most likely cause. If unclear, A/B test the store listing. |

### Core Metric: D1 Retention

| Attribute | Detail |
|-----------|--------|
| **What it measures** | % of users who open the app the day after installing. First-session experience quality. |
| **Why it matters** | If users don't come back on Day 1, the app failed to hook them. Everything downstream is zero. |
| **Where to find it** | Firebase Analytics > Retention > Day 1 cohort |
| **How often to check** | Weekly (every Monday, part of metrics review). |
| **Green** | >40% |
| **Yellow** | 30-40% |
| **Red** | <30% |
| **Green action** | First session is working. Focus on D7 and engagement depth. |
| **Yellow action** | Review the first-session flow. Is onboarding confusing? Is the first brush too long? Is the app crashing? Check crash reports in Play Console. |
| **Red action** | STOP GTM. The first session is broken. Run the app as a new user. Time every screen. Find where users drop. Fix it. Do not acquire new users until D1 > 30%. |

### Core Metric: D7 Retention

| Attribute | Detail |
|-----------|--------|
| **What it measures** | % of users who open the app 7 days after installing. Habit formation signal. |
| **Why it matters** | THE metric for a habit app. If kids are not coming back after a week, the game loop is not engaging enough. This gates all paid acquisition and scaling decisions. |
| **Where to find it** | Firebase Analytics > Retention > Day 7 cohort |
| **How often to check** | Weekly. Requires 7+ days of data per cohort, so first meaningful read is Week 2. |
| **Green** | >30% |
| **Yellow** | 20-30% |
| **Red** | <20% |
| **Green action** | Product-market fit signal. Safe to invest in growth. Begin preparing for paid acquisition prerequisites. |
| **Yellow action** | Investigate: are kids getting bored? Is the unlock curve too slow? Too fast? Check session completion rates and drop-off points. Survey 3-5 parents if possible. |
| **Red action** | STOP ALL GTM. This overrides every other priority. D7 <20% means the product does not retain. Possible causes: (1) game is too repetitive by day 3-4, (2) unlock pacing is wrong, (3) audio/visual bugs making it annoying, (4) parents turning it off because kid lost interest. Fix the product. Do not resume GTM until D7 >25% for 2 consecutive weekly cohorts. |

### Core Metric: D30 Retention

| Attribute | Detail |
|-----------|--------|
| **What it measures** | % of users who open the app 30 days after installing. Long-term habit signal. |
| **Why it matters** | Determines LTV and viability of paid acquisition. A brushing app that loses users after 2 weeks is a novelty, not a habit tool. |
| **Where to find it** | Firebase Analytics > Retention > Day 30 cohort |
| **How often to check** | Monthly. First meaningful data at Week 6. |
| **Green** | >20% |
| **Yellow** | 12-20% |
| **Red** | <12% |
| **Green action** | Strong signal. This user base will generate reviews, word-of-mouth, and revenue. Invest confidently. |
| **Yellow action** | Check: where do users drop between D7 and D30? Is there a content wall (ran out of worlds/heroes)? Is the unlock curve stalling? Add a re-engagement nudge (notification, new content). |
| **Red action** | The app is a novelty, not a habit. Before scaling, add (1) push notifications for streak preservation, (2) new content to the mid-game, (3) a social/competitive element. Do not scale spend until D30 >15%. |

### Core Metric: Session Completion Rate

| Attribute | Detail |
|-----------|--------|
| **What it measures** | % of started brush sessions that run to completion (all 4 quadrants finished). |
| **Why it matters** | If kids are quitting mid-brush, the game is not engaging enough to hold attention for 2 minutes. This is the product's core promise. |
| **Where to find it** | Firebase Analytics custom event: `brush_completed` / `brush_started`. Must instrument these events. |
| **How often to check** | Weekly. |
| **Green** | >85% |
| **Yellow** | 70-85% |
| **Red** | <70% |
| **Green action** | The core game loop works. Kids are finishing brushes. |
| **Yellow action** | Check which quadrant has the highest drop-off. Is it always the last one (fatigue)? Is a specific phase buggy? Is the timer too long for younger kids? Consider making the last quadrant shorter or more exciting. |
| **Red action** | The 2-minute session is too long or not engaging enough. Test: (1) shorter timer option (60 seconds for younger kids), (2) more dramatic final-phase boss battle, (3) mid-session rewards. This is a product problem, not a GTM problem. |

### Core Metric: Average Sessions Per User Per Week

| Attribute | Detail |
|-----------|--------|
| **What it measures** | How many times the average active user brushes with the app per week. Target is 14 (2x/day, 7 days). |
| **Why it matters** | Frequency drives habit formation, star accumulation, content progression, and review likelihood. A user who brushes 1x/week is not forming a habit. |
| **Where to find it** | Firebase Analytics: weekly `brush_completed` events / weekly active users. |
| **How often to check** | Weekly. |
| **Green** | >10 sessions/week (5+ days of double brushing) |
| **Yellow** | 5-10 sessions/week |
| **Red** | <5 sessions/week |
| **Green action** | Users are brushing almost every session. The habit is forming. This is the dream metric. |
| **Yellow action** | Users are brushing most days but skipping some. Normal for the first 2 weeks. If this persists at Week 4+, consider: morning vs evening detection prompt, streak notifications, reduced session length option. |
| **Red action** | Users install but don't make it a routine. Check: (1) Is the app only being used at one time of day? (2) Are parents forgetting? (3) Is the unlock curve not motivating enough? Consider push notifications as a gentle reminder (parent-controlled). |

### Core Metric: Play Store Rating and Review Count

| Attribute | Detail |
|-----------|--------|
| **What it measures** | Average star rating and total number of reviews. Social proof and store ranking factor. |
| **Why it matters** | Below 4.0 stars, install conversion drops dramatically. Below 10 reviews, parents do not trust the listing. Reviews are the compound interest of app growth. |
| **Where to find it** | Google Play Console > Ratings & Reviews |
| **How often to check** | 3x/week (Mon/Wed/Fri, 2 min each). |
| **Green** | Rating: 4.5+ stars. Reviews: on track for 10+ by Month 1, 50+ by Month 3, 200+ by Month 6. |
| **Yellow** | Rating: 4.0-4.5. Review velocity declining (fewer reviews per week than previous week). |
| **Red** | Rating: <4.0. OR 3+ negative reviews in a week on the same issue. |
| **Green action** | Respond to every review (positive and negative). Use positive quotes in marketing materials. |
| **Yellow action** | Read every negative review carefully. Categorize issues: bugs, UX confusion, content complaints, pricing. Fix the top issue. If review velocity is slowing, check in-app review prompt timing -- move it later (after 7th brush instead of 5th) to capture happier users. |
| **Red action** | Rating <4.0 is an emergency. (1) Respond to every negative review with empathy and a fix timeline. (2) Ship a patch for the most common complaint within 48 hours. (3) Temporarily pause GTM -- sending traffic to a <4.0 listing wastes effort. (4) After fix ships, reply to negative reviews: "We've fixed this in the latest update." Resume GTM when rating returns to 4.3+. |

### Core Metric: Organic vs Referred Installs

| Attribute | Detail |
|-----------|--------|
| **What it measures** | Breakdown of install sources: Play Store organic search, UTM-tagged referrals (dentist cards, social links), direct (unknown). |
| **Why it matters** | Tells Jim which channels are actually driving growth vs which feel productive but produce nothing. |
| **Where to find it** | Google Play Console > Acquisition > Traffic sources. Firebase Dynamic Links for UTM tracking. |
| **How often to check** | Weekly. |
| **Green** | Organic search growing month-over-month (ASO working). At least 1 non-organic source producing 5+ installs/week. |
| **Yellow** | Organic flat. No single referral source producing 5+ installs/week. |
| **Red** | Organic declining. All referral sources producing <2 installs/week. |
| **Green action** | Double down on the top referral source. Optimize ASO for the converting keywords. |
| **Yellow action** | ASO review: are the right keywords in the listing? Check competitor listings for keywords Jim is missing. For referral: verify UTM links are working (common failure point). |
| **Red action** | Organic declining usually means: (1) rating dropped, (2) a competitor outranked you, (3) seasonal dip. Check each. If no referral source is working, the problem may be the store listing -- run an A/B test on the short description and first screenshot. |

### Core Metric: Social Media Engagement (Per Platform)

| Attribute | Detail |
|-----------|--------|
| **What it measures** | Views, likes, comments, shares, and profile visits per post and per platform. |
| **Why it matters** | Leading indicator of whether content is resonating. High engagement with low installs means the CTA or funnel is broken. Low engagement means the content is not reaching parents. |
| **Where to find it** | TikTok: Creator Tools > Analytics. Instagram: Professional Dashboard > Insights. |
| **How often to check** | Weekly (Sunday, during content batch review). |
| **Green (TikTok)** | Average 500+ views/video after Month 1. 1+ video >5K views in any given month. |
| **Yellow (TikTok)** | Average 200-500 views/video. No breakout videos. |
| **Red (TikTok)** | Average <200 views/video after 20+ posts. |
| **Green action** | Analyze top performers: what format, hook, and topic? Make more of those. |
| **Yellow action** | Experiment with hooks. Test: (1) start with the kid's face/reaction, (2) start with a bold text overlay, (3) start with a relatable parent frustration. Give each format 3-4 videos. |
| **Red action** | After 20+ posts with <200 average views, the content strategy is not working. Options: (1) try a completely different content style (educational vs entertainment vs reaction), (2) reduce to 1 video/week and reallocate time, (3) if still below 200 after 30 total posts, kill TikTok. Dentist outreach is likely a better use of time. |

### Core Metric: Email List Growth

| Attribute | Detail |
|-----------|--------|
| **What it measures** | New email subscribers per week from landing page, in-app prompts, or lead magnets. |
| **Why it matters** | Email is the only channel Jim fully controls. Every subscriber is a future launch announcement, feature update, or premium conversion opportunity. |
| **Where to find it** | Buttondown dashboard. |
| **How often to check** | Weekly. |
| **Green** | 10+ new subscribers/week. |
| **Yellow** | 3-10 new subscribers/week. |
| **Red** | <3 new subscribers/week. |
| **Green action** | Test email content: tips, progress updates, feature announcements. Measure open rates. |
| **Yellow action** | Check the signup placement: is it visible? Is the value proposition clear? Test different lead magnets (printable brushing chart, coloring pages). |
| **Red action** | Email capture is not a priority at <500 installs. Defer optimization. Focus on installs and retention first. Only worry about email growth after Month 3. |

### Core Metric: Dentist Partnership Conversion Rate

| Attribute | Detail |
|-----------|--------|
| **What it measures** | % of outreach attempts that result in an active partner (cards placed or recommending the app). |
| **Why it matters** | Tells Jim whether the pitch, materials, and value proposition work for dental professionals. |
| **Where to find it** | Google Sheets CRM (manual tracking). |
| **How often to check** | Biweekly. |
| **Green** | >20% conversion (1 in 5 outreach attempts results in a partner). |
| **Yellow** | 10-20% conversion. |
| **Red** | <10% conversion (fewer than 1 in 10). |
| **Green action** | The pitch works. Scale outreach volume. Move from 5/month to 10/month. |
| **Yellow action** | Analyze the funnel: where are they dropping? No response (pitch problem)? Responded but said no (objection handling)? Said yes but never placed cards (follow-up problem)? Fix the weakest link. |
| **Red action** | The pitch or materials need fundamental rework. (1) Talk to the 1-2 partners who DID say yes -- why did they agree? (2) Talk to 1-2 who said no -- what would change their mind? (3) Revise materials based on feedback. Do not increase volume on a broken pitch. |

### Core Metric: Cost Per Install (When Paid Starts)

| Attribute | Detail |
|-----------|--------|
| **What it measures** | Ad spend / installs from that ad channel. |
| **Why it matters** | The unit economics of growth. If CPI > LTV, Jim is losing money on every install. |
| **Where to find it** | Google Ads dashboard. Facebook Ads Manager. |
| **How often to check** | Daily for first 2 weeks of a new campaign. Weekly after stabilization. |
| **Green** | CPI < LTV/3 (e.g., if LTV is $6, CPI < $2). |
| **Yellow** | CPI between LTV/3 and LTV/2 (e.g., CPI $2-3 on $6 LTV). |
| **Red** | CPI > LTV/2. |
| **Green action** | Scale budget by 20% per week. Test new creatives. This channel is working. |
| **Yellow action** | Do not scale. Test: (1) different ad creatives, (2) different audiences, (3) different bidding strategy. Give each test 1 week. If CPI improves to green, scale. |
| **Red action** | Pause the campaign. Diagnose: (1) Is the creative wrong? (2) Is the audience wrong? (3) Is the store listing not converting paid traffic? If 3 creative tests all produce red CPI, kill this channel. Try a different paid platform. |

### Core Metric: LTV (When Premium Starts)

| Attribute | Detail |
|-----------|--------|
| **What it measures** | Average revenue generated per user over their lifetime with the app. |
| **Why it matters** | Determines how much Jim can afford to spend acquiring users and whether the business is viable. |
| **Where to find it** | Play Store financial reports + Firebase Analytics (cohort revenue). Initially estimated from D30 retention x premium conversion rate x ARPU. |
| **How often to check** | Monthly (need 30+ days of data per cohort for meaningful calculation). |
| **Green** | LTV > $5 (supports paid acquisition at reasonable CPI). |
| **Yellow** | LTV $2-5 (only very efficient paid channels are viable). |
| **Red** | LTV < $2 (paid acquisition is not viable; organic-only until pricing/retention improves). |
| **Green action** | Invest in paid acquisition. Test price increases. Consider annual subscription option. |
| **Yellow action** | Focus on improving retention (increases LTV) and reducing churn. Do not start paid acquisition above $1 CPI. |
| **Red action** | The business model needs work. Options: (1) increase price (test 2x current price), (2) add a higher-value tier, (3) improve D30 retention, (4) consider a different monetization model. Do not spend on paid acquisition. |

### Core Metric: LTV:CAC Ratio

| Attribute | Detail |
|-----------|--------|
| **What it measures** | Lifetime value / cost to acquire a customer. The fundamental unit economics of the business. |
| **Why it matters** | Below 3:1, the business is not sustainable at scale. Below 1:1, Jim is losing money on every user. |
| **Where to find it** | Calculated: LTV (from above) / CPI (from above). |
| **How often to check** | Monthly. |
| **Green** | >3:1 |
| **Yellow** | 2:1 to 3:1 |
| **Red** | <2:1 |
| **Green action** | Scale paid acquisition aggressively. This is the growth engine working. |
| **Yellow action** | Improve one side of the equation: either increase LTV (better retention, higher price) or decrease CAC (better creatives, better store listing conversion). |
| **Red action** | Pause paid acquisition. Focus entirely on improving the product (retention, conversion) until the ratio improves. Organic-only growth until LTV:CAC > 2:1. |

---

## 3. The Decision Playbook

### Decision: "Should I Start Paid Ads?"

**Prerequisites (ALL must be met):**
1. D7 retention >35% for 2+ consecutive weekly cohorts
2. Premium tier is live with at least $1 average revenue per paying user per month
3. Play Store rating is 4.3+ with 50+ reviews
4. Play Store CVR (store visitors to installs) is >25%
5. At least 200 organic installs (proves the listing converts)
6. Jim has $500/month available for ad spend without stress

**Starting budget:** $500/month on Google App Campaigns. Do NOT split across platforms.

**First test:** Run Google App Campaigns for 14 days at $15/day targeting US, English, parents of kids 5-10. Let Google's ML optimize. Do not micro-manage targeting.

**Success criteria after 14 days:**
- CPI < $2.50 AND
- D7 retention of paid users > 25% (lower than organic is normal, but not by more than 10 points) AND
- At least 50 installs from the campaign (statistical minimum)

**If successful:** Increase budget by 20% per week until CPI starts rising. Cap at the point where CPI = LTV/3.

**If CPI is $2.50-4.00:** Test 3 different creative sets (different screenshots, different ad copy). Give each 7 days. If none break $2.50 CPI, the store listing is not converting paid traffic. Pause ads. A/B test the listing. Retry in 30 days.

**Kill condition:** CPI > $4.00 after 3 creative tests OR paid user D7 < 15%. Paid acquisition is not viable at current product/listing quality. Redirect budget to content boosting ($50-100/month on top-performing organic posts) and revisit in 60 days.

---

### Decision: "Should I Launch on iOS?"

**Prerequisites (ALL must be met):**
1. Android growing (installs increasing month-over-month for 3+ months)
2. D7 retention >30% consistently
3. Jim has $5,000-10,000 available for the port (contract Flutter developer or his own time)
4. Jim has 100+ hours available over 6-8 weeks for the port (or can hire)
5. At least 5 users have requested iOS in reviews or emails
6. Monthly revenue from Android covers the monthly cost of maintaining two platforms (~$100/month Apple Developer account + testing overhead)

**Estimated effort:** 4-8 weeks for an experienced Flutter developer. The codebase is Flutter, so the core code is shared. The work is: Apple Developer account setup, iOS-specific permissions (camera, notifications), App Store screenshots, App Store review process (stricter than Play Store for kids apps), Apple's COPPA compliance requirements, and testing on multiple iOS devices.

**Expected ROI:** iOS users typically have 2-3x higher LTV than Android. If Android LTV is $5, expect iOS LTV of $10-15. The US market is ~55% iOS, so Jim is leaving more than half the addressable market on the table. At 5,000 Android installs, an iOS launch could add 3,000-8,000 installs in the first 6 months.

**Decision framework:** If monthly Android revenue > $500, the iOS port pays for itself within 6-12 months. If Android revenue < $200, defer. The operational overhead of two platforms is real.

**Cheapest test before committing:** Post on the landing page: "Coming soon to iOS -- enter your email to be notified." Track signups for 30 days. If 50+ people sign up, there is demand.

---

### Decision: "Should I Hire My First Person?"

**Prerequisites (at least 3 of 4 must be met):**
1. Monthly revenue > $2,000 (can sustain a part-time hire)
2. Jim is spending >15 hrs/week on GTM and it is producing results (not speculative effort)
3. Jim's product development is blocked because GTM takes too much time
4. One specific channel is proven but bottlenecked by Jim's bandwidth (e.g., dentist outreach works but Jim can only do 5/month)

**First hire should be:** A part-time virtual assistant ($15-25/hour, 10-15 hrs/week) handling:
- Social media scheduling and comment monitoring
- Dentist outreach email sending (Jim approves, VA sends + follows up)
- Play Store review responses (from templates)
- Metrics tracking and weekly report preparation

**Budget:** $600-1,500/month for 10-15 hrs/week.

**Where to find:** Belay, Time Etc, or Upwork. Look for someone with experience managing social media for a small brand. Kids/family category experience is a bonus.

**NOT the first hire:**
- A developer (Jim is the developer, and the app is Flutter-specific)
- A marketing strategist (Jim needs execution help, not more strategy)
- A designer (use Fiverr per-project)
- A full-time employee (too expensive and too much management overhead at this stage)

**Kill condition:** If the VA is not saving Jim at least 8 hours/week of productive time after 30 days of onboarding, the role is not ready. Terminate and try again at higher revenue.

---

### Decision: "My Retention Is Below Target"

**Step 1: Diagnose (1-2 days)**
- Check D1, D7, D30 separately. Which is the problem?
  - Low D1 (< 30%): First session is broken. Run through onboarding + first brush as a new user. Time every screen. Check crash reports in Firebase Crashlytics.
  - Low D7 (< 20%): Engagement drops after initial excitement. Check: how many brush sessions does the average user complete before churning? If it is 3-5, the game loop is too repetitive by session 4.
  - Low D30 (< 12%): Users lose interest after 2-3 weeks. Check: have they unlocked everything? Is the mid-game content wall hit around session 15-20?
- Check session completion rate. If kids are quitting mid-brush, the 2-minute session may be too long for the age group.
- Check by acquisition source. Do dentist-referred users retain better than social-acquired users? If so, the social audience may not be the right fit.

**Step 2: Fix (1-2 weeks)**
- D1 issue: Simplify onboarding. Reduce first-brush session to 60 seconds. Make the reward for completing the first brush dramatic and immediate.
- D7 issue: Audit the Day 2-7 experience. Add variety: different monsters, surprise events, buddy system. Check if the unlock curve is too slow (nothing new for 3+ sessions) or too fast (everything unlocked by Day 5).
- D30 issue: Add a mid-game content injection. New world, new hero type, new mechanic. Consider push notifications for streak preservation (parent-opted-in only).
- Session completion: Offer a "quick brush" mode (60 seconds, 2 quadrants). Some brushing is better than no brushing.

**Step 3: Measure (2 weeks)**
- After shipping the fix, wait 2 full weekly cohorts (14 days minimum) before evaluating.
- Compare the new cohort's retention to the pre-fix cohort. Improvement of 5+ percentage points = the fix worked.
- If improvement is <3 percentage points, the fix addressed the wrong problem. Return to Step 1 with the new data.

**If still below target after 2 fix cycles (6 weeks):**
- Talk to 5 real users (parents). Ask: "Why did your kid stop using the app?" The answer is usually simpler than the data suggests.
- Consider: the target age range may be wrong. A 7-year-old and a 4-year-old need very different experiences. Narrow the target or add age-specific modes.
- If D7 < 15% after 3 fix cycles: the product concept may need fundamental rethinking, not iteration. Consider a pivot to a different engagement model (e.g., multiplayer brushing, parent-child co-op mode).

---

### Decision: "Growth Has Stalled"

**Definition:** Installs have been flat or declining for 3+ weeks despite consistent GTM effort.

**Possible causes (check in this order):**
1. **Play Store listing degraded.** Rating dropped below 4.0? New negative reviews at the top? A competitor started bidding on your keywords? Screenshot or description changed inadvertently?
2. **Your content hit a ceiling.** Social algorithms reward novelty. If Jim has been posting the same format for 8 weeks, the algorithm has shown it to everyone it thinks will engage. Time for a new content format.
3. **Seasonal dip.** Summer (June-Aug) sees lower app installs across the kids category. December holidays see a spike. Check Play Store category trends.
4. **A single channel dried up.** A Reddit post ages off. A dentist partner took down your cards. A local press article is no longer driving traffic. Check channel-by-channel attribution.
5. **Market saturation in current channels.** If Jim has emailed every dentist within 15 miles and posted 30 TikToks, the local/organic channels may be tapped out. Time for a new channel.

**Diagnostic steps:**
1. Pull install data by source for the last 6 weeks. Identify which channel declined.
2. Check Play Store CVR. If CVR declined, the listing or rating is the issue (not distribution).
3. Check social engagement. If views are up but installs are flat, the funnel is broken (content is not driving action).
4. Check retention. If retention dropped, word-of-mouth has weakened (unhappy users don't recommend).

**Potential fixes by channel:**
- ASO stalled: A/B test short description + first screenshot. Add new keywords based on competitor analysis.
- Social stalled: Try a completely new content format. If doing gameplay clips, try parent testimonials. If doing parent content, try kid reactions.
- Dentist stalled: Expand geography. Try email-only outreach to a 30-mile radius. Refresh materials.
- PR stalled: Wait for a seasonal hook (next holiday/awareness month). Apply for an award to create a news hook.
- Paid stalled: Refresh creatives (performance degrades every 2-3 weeks). Test new audiences.

---

### Decision: "A Channel Isn't Working"

**Definition of "not working" (per channel):**

| Channel | Not Working Threshold | Time to Give It |
|---------|----------------------|-----------------|
| ASO | CVR <15% after 2 A/B tests | 8 weeks |
| Reddit | <20 upvotes on 2 posts to different subreddits | 4 weeks |
| TikTok | <200 avg views after 20 videos | 10 weeks |
| Instagram | <100 avg views when cross-posting from TikTok | 8 weeks |
| Local dentists | <2 partners after 15 outreach attempts | 8 weeks |
| Local PR | 0 published pieces after 6 pitches | 6 weeks (rework angle, try 6 more) |
| National PR | 0 published pieces after 12 pitches | 12 weeks (then kill) |
| Product Hunt | <50 upvotes | One shot (don't retry) |
| Podcasts | 0 bookings after 10 pitches | 10 weeks |
| PTA/schools | <10 installs per PTA program | 2 programs (then kill) |
| Google Ads | CPI > $4.00 after 3 creative tests | 6 weeks |
| Facebook/IG Ads | CPI > $5.00 after 3 creative tests | 6 weeks |
| Grandparent/FB | <50 followers after 6 weeks + $200 boost spend | 10 weeks |

**Channel rotation order (what to try next):**
1. If social fails: double down on dentists + PR
2. If dentists fail: double down on social + SEO/ASO
3. If PR fails: try Product Hunt + IndieHackers + Show HN
4. If all organic fails: fix the product (retention), then try paid
5. If paid fails: the unit economics need fundamental improvement (LTV or conversion rate)

---

## 4. The Monthly Review Template

### Monthly Review Agenda (60 minutes, first Sunday of each month)

**Pre-work (10 min, the night before):**
Pull these numbers and put them in the metrics spreadsheet:
- Total installs this month (Play Console > Statistics)
- Total installs by source (Play Console > Acquisition)
- D1/D7/D30 retention for this month's cohort (Firebase Analytics > Retention)
- Session completion rate (Firebase Analytics > Events)
- Average sessions per user per week (Firebase Analytics > Engagement)
- Play Store rating + new review count (Play Console > Ratings)
- Social stats: TikTok views/followers, Instagram views/followers (platform analytics)
- Email subscribers added (Buttondown)
- Dentist partners: new, active, inactive (Google Sheets CRM)
- Cash spent on GTM this month (receipts/bank statement)
- If paid ads active: CPI, spend, installs per channel (ad dashboards)

**Agenda:**

**0:00-0:10 -- Scorecard Review**
- Fill in this month's row in the metrics spreadsheet
- For each metric, mark Green/Yellow/Red based on the thresholds in Section 2
- Count: how many Greens, Yellows, Reds?
- If 3+ Reds: this is a crisis review (skip to section below)

**0:10-0:25 -- Channel Performance Ranking**
- For each active channel, calculate: installs attributable / hours Jim spent
- Rank channels by installs-per-hour
- Top channel: plan to invest more time next month
- Bottom channel: is it below the "not working" threshold? If yes, kill it
- Middle channels: maintain current effort level

**0:25-0:40 -- Decision Points**
- Check each Phase Gate in the Channel Activation Tree: are any new channels ready to activate?
- Check each Kill Switch: should any channels be deactivated?
- Review the Decision Playbook: does any pending decision now have enough data?
- Specifically ask: "Is my time allocation still right, or should I shift hours between channels?"

**0:40-0:50 -- Next Month Planning**
- Write down the 3 most important GTM actions for next month (not 10, not 5 -- three)
- For each: what is the expected outcome, and how will I measure it?
- If a seasonal hook is coming (holiday, awareness month, back-to-school), plan for it now
- Set the monthly cash budget: $X on tools, $Y on ads (if active), $Z on outsourcing

**0:50-0:60 -- Reflection**
- What surprised me this month? (Unexpected wins or losses)
- What did I spend time on that produced nothing? (Be honest)
- Am I burning out? (If yes, next month is a recovery month: half GTM, double product)
- One sentence: "The most important thing I learned about my users this month is ___"

**Format for recording decisions:**
```
## Month X Review -- [Date]

### Scorecard
| Metric | This Month | Last Month | Trend | Status |
|--------|-----------|------------|-------|--------|
| Installs | X | Y | +/-% | G/Y/R |
| D7 Retention | X% | Y% | +/-pp | G/Y/R |
| ... | ... | ... | ... | ... |

### Channel Ranking (installs per hour of Jim's time)
1. [Channel]: X installs / Y hours = Z installs/hr
2. ...

### Decisions Made
- ACTIVATED: [channel] because [trigger met]
- KILLED: [channel] because [kill threshold hit]
- CONTINUED: [channel] despite [concern] because [reason]

### Next Month: Top 3 Priorities
1. [Action] -- Expected outcome: [X]. Measure: [Y].
2. ...
3. ...

### Budget: $X total
- Tools: $X
- Ads: $X
- Outsourcing: $X

### Lesson: [One sentence]
```

---

## 5. Phase Transitions

### Phase 0 to Phase 1: Pre-Launch to Validation
**"The app is live. Now prove someone wants it."**

**Required to enter Phase 1 (ALL must be met):**
- [ ] App live on Play Store production track (publicly downloadable)
- [ ] Play Store listing finalized (8 screenshots, full description, preview video)
- [ ] In-app review prompt built and deployed
- [ ] Share card feature built and deployed
- [ ] Week 0 infrastructure complete (accounts, templates, CRM, alerts)
- [ ] First batch of dentist prescription cards printed

**Expected timeline:** 1-2 weeks after internal testing is stable.

**What Phase 1 looks like:** Jim is doing 3 things: monitoring the Play Store listing, executing the Reddit launch, and approaching the first 5 dentists. Total GTM time: 6-8 hours/week.

---

### Phase 1 to Phase 2: Validation to Monetize
**"People want it and keep using it. Now charge for it."**

**Required to enter Phase 2 (ALL must be met):**
- [ ] 200+ total installs (proves Jim can acquire users)
- [ ] D7 retention >25% for 4+ consecutive weekly cohorts (proves kids keep using it)
- [ ] 20+ Play Store reviews with 4.3+ star average (proves social proof)
- [ ] At least 1 channel producing 5+ installs/week reliably (proves repeatable distribution)
- [ ] Session completion rate >80% (proves kids finish the brush)
- [ ] Jim has identified the top 2 channels by installs-per-hour (knows what works)

**Expected timeline:** Month 2-4 (realistic), Month 2 (if Reddit post goes viral).

**What Phase 2 looks like:** Jim launches premium tier. Begins optimizing conversion from free to paid. Starts preparing prerequisites for paid acquisition. Adds 1-2 new channels from the activation tree. Total GTM time: 6-8 hours/week, with more time on optimization and less on experimentation.

**Phase 2 actions:**
- Launch premium tier (freemium model)
- Track: free-to-paid conversion rate, ARPU, churn
- Begin LTV calculation (need 30 days of premium data minimum)
- Product Hunt launch (if 20+ reviews and 4.3+ stars)
- Start national PR pitches (if local press hit exists)
- Prepare paid acquisition prerequisites (store listing CVR >25%)

---

### Phase 2 to Phase 3: Monetize to Growth Engine
**"The unit economics work. Now pour fuel on the fire."**

**Required to enter Phase 3 (ALL must be met):**
- [ ] Premium tier live for 60+ days
- [ ] LTV calculable and >$3 (enough to support some paid acquisition)
- [ ] D7 retention >30% (product is sticky)
- [ ] D30 retention >18% (habit is forming)
- [ ] Play Store CVR >25% (listing converts)
- [ ] 500+ total installs
- [ ] 50+ reviews with 4.3+ stars
- [ ] At least 1 organic channel producing 15+ installs/week
- [ ] Monthly revenue > $200 (proves willingness to pay)

**Expected timeline:** Month 5-8 (realistic), Month 4 (if monetization converts well).

**What Phase 3 looks like:** Jim starts paid acquisition. Scales the top 2-3 organic channels. Begins exploring iOS. May hire first part-time help. Total GTM time: 5-7 hours/week (more systematized, less manual). Total GTM budget: $500-2,000/month.

**Phase 3 actions:**
- Start Google App Campaigns at $500/month
- Scale dentist outreach to 50+ (email-only, broader geography)
- Begin iOS planning if revenue supports it
- Grandparent channel activation if premium is live
- Back-to-school push preparation (if timing is July-August)
- First VA hire consideration if revenue > $2K/month

---

## 6. Realistic Growth Projections

### Assumptions Stated

**All scenarios assume:**
- App launches to production in April 2026
- Jim executes 6-8 hours/week of GTM consistently
- No paid ads until Phase 3 prerequisites are met
- Premium tier launches in Month 3-4
- No iOS until Month 8+ at earliest
- Kids dental app category benchmarks (US Play Store)

**Conservative scenario assumes:**
- Reddit post gets moderate traction (100-200 upvotes, 20-40 installs)
- No viral moments on any platform
- TikTok averages 200-500 views per video (below algorithmic breakout)
- 3-5 dentist partners by Month 3
- No significant press coverage in Year 1
- Premium conversion rate: 3%
- D7 retention: 25%

**Baseline scenario assumes:**
- Reddit post does well (500+ upvotes, 100-200 installs)
- 1 TikTok gets moderate traction (5K-20K views) in the first 6 months
- 10-15 dentist partners by Month 6
- 1-2 local press hits
- Product Hunt launch generates 100-300 installs
- Premium conversion rate: 5%
- D7 retention: 30%

**Optimistic scenario assumes:**
- Reddit post goes viral on r/Daddit (1000+ upvotes, 500+ installs)
- 2-3 TikTok videos break 50K+ views
- 30+ dentist partners by Month 6
- 1 national parenting media hit
- Award badge earned (Parents' Choice or CSM)
- Premium conversion rate: 7%
- D7 retention: 35%

### Month-by-Month Projections

| Month | Conservative | Baseline | Optimistic |
|-------|-------------|----------|------------|
| | Installs / MAU / Revenue | Installs / MAU / Revenue | Installs / MAU / Revenue |
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

**Cumulative installs at Month 12:**
- Conservative: ~3,600
- Baseline: ~14,600
- Optimistic: ~64,150

**Revenue assumptions:**
- Premium launches Month 3-4 at $3.99/month or $29.99/year
- Revenue = MAU x premium conversion rate x $3.99 (monthly average)
- Conservative: 3% conversion. Baseline: 5%. Optimistic: 7%.
- Revenue numbers are gross (before Play Store 15% cut on first $1M)

**Key inflection points:**
- Month 1: Reddit launch. The size of this spike sets the trajectory for Month 2-3.
- Month 3-4: Premium launch. First revenue. LTV calculation becomes possible.
- Month 6-7: If paid ads activate, growth accelerates. October Halloween content push.
- Month 10-11: February is National Children's Dental Health Month. Biggest PR window.

**What moves the needle between scenarios:**
- The difference between Conservative and Baseline is usually ONE thing going well: a Reddit post that catches, a TikTok that breaks out, a press hit that drives 200 installs. Jim cannot plan for this, but he can increase the surface area of luck by consistently shipping content and pitches.
- The difference between Baseline and Optimistic is TWO OR MORE things going well simultaneously, plus paid ads working at good economics. This is not something Jim can force.

---

## 7. The "If Everything Goes Wrong" Playbook

### Scenario 1: Zero Installs After 1 Month

**Early warning signs (Week 2):**
- Play Store impressions are <100/week (nobody is finding the listing)
- Reddit post got <10 upvotes (story didn't resonate)
- Zero installs from dentist cards (cards are being ignored)

**This is not a growth problem. This is a discovery problem.**

**Response plan (in order):**
1. Check the basics: is the app actually findable on Play Store? Search for "kids brushing app" and "toothbrush game." If Brush Quest does not appear in the first 50 results, the ASO is broken. Rewrite the listing with higher-volume keywords.
2. Check the listing conversion: if impressions exist but installs are zero, the listing is not compelling. Rewrite the short description. Change the first screenshot. Ask 3 parent friends to look at the listing and tell Jim why they would or would not install.
3. Force 20 installs manually: ask every parent Jim knows personally. Family, friends, coworkers, Oliver's school parents. This is not scalable but it provides (a) initial data on retention and (b) the first reviews.
4. If all 20 manual users churn within a week: this is a product problem, not a marketing problem. Observe Oliver using the app. Time how long he engages. Note where he looks bored. Fix the product before doing anything else.

**Pivot options:**
- Reposition the app for a different age group (if 7-year-olds are not engaged, try 4-5 year olds or 9-10 year olds)
- Simplify radically: cut session to 60 seconds, cut complexity, make it a "first timer app" instead of a deep game
- Change the distribution model: give up on Play Store discoverability and go 100% dentist-referred

---

### Scenario 2: Retention Is Terrible (D7 < 15%)

**Early warning signs:**
- Kids complete the first brush but don't come back the next day
- Oliver himself stops wanting to use the app (the canary in the coal mine)
- Reviews mention "my kid liked it for a day then forgot about it"

**Response plan:**
1. STOP all GTM spending and effort. Do not acquire new users into a broken experience.
2. Interview 5 parents whose kids stopped using the app. Ask: "What happened? When did your kid stop asking to use it?" The answer is almost always one of: (a) the novelty wore off, (b) it was too hard/easy, (c) the parent forgot to remind them, (d) a sibling fight over the phone.
3. Check session-level data: where in the user journey do they drop? After session 1? Session 3? Session 7? This tells Jim what content is boring.
4. Ship one targeted fix per week for 3 weeks. Measure D7 after each fix. Fixes to try:
   - Add push notifications (parent-opted-in) as a gentle reminder
   - Add a "daily surprise" element to the first 7 days (different monster, bonus reward)
   - Reduce session length option (60 seconds for quick brushes)
   - Add a sibling mode if siblings are competing for the phone
5. If D7 is still <15% after 3 fix cycles: the core game loop is not engaging enough for the target age. Consider adding a fundamentally different mechanic (multiplayer, parent co-op, story mode).

**Pivot options:**
- Narrow the age range (maybe 5-6 year olds love it but 7-8 year olds find it babyish)
- Switch from "game" to "reward chart" model (simpler, less gamified, more like a chore chart)
- Open-source the codebase and reposition as an open-source kids health project (reputation play instead of revenue play)

---

### Scenario 3: A Competitor Launches With More Funding

**Early warning signs:**
- A new brushing app appears in Play Store with professional screenshots and a marketing budget
- A major brand (Colgate, Oral-B) refreshes their app with similar features
- A VC-backed startup announces a kids dental health app

**Response plan:**
1. Do NOT panic. Do NOT try to out-feature them. Jim cannot outspend a funded competitor.
2. Lean into what they cannot copy:
   - "Built by a dad, for his kid" (authenticity they will never have)
   - "No tracking, no data collection" (corporate apps always collect data)
   - "Works with any toothbrush" (brand apps lock you into their hardware)
   - "Indie developer who responds to every review" (corporate CS is impersonal)
3. Speed advantage: ship the feature they announced before they ship it. Jim can push an update in a day. A funded startup needs 2-week sprint cycles and QA teams.
4. Community advantage: rally the early users. "We're the indie alternative." This resonates with a meaningful segment of parents.
5. If competitor has clearly better retention and is free: consider differentiating on a different axis entirely (e.g., dentist-endorsed, privacy-first, multi-child support, habit tracking for parents).

**Pivot options:**
- Pivot from consumer to B2B2C (sell to dental practices as a patient engagement tool)
- Pivot to a broader kids health app (brushing + handwashing + sunscreen)
- Pivot to a white-label solution (license the platform to dental brands)

---

### Scenario 4: Play Store Flags the App

**Early warning signs:**
- Email from Play Store review team requesting changes
- App temporarily suspended or removed from search results
- "Policy violation" warning in Play Console

**Most likely causes for a kids app:**
- COPPA/children's privacy policy issues
- "Designed for Families" compliance gaps (ad SDK detected, even if not used)
- Camera permission flagged as inappropriate for children's app
- Description claims that violate Play Store policies ("clinically proven," "recommended by dentists" without documentation)

**Response plan:**
1. Respond within 24 hours. Slow responses escalate to removal.
2. Read the specific violation cited. Do NOT guess or broadly change things.
3. If it is a privacy policy issue: update the privacy policy. Add explicit language about no data collection from children. Resubmit.
4. If it is a camera permission issue: provide detailed justification (motion detection for brushing, no images stored, no images transmitted). If they reject the justification, make the camera feature optional and remove the permission requirement.
5. If it is a content claim issue: remove or soften the claim. "Recommended by dentists" becomes "Loved by families" unless Jim has documented dentist endorsements.
6. Join the "Designed for Families" program properly. Read every requirement. Meet every requirement. This protects against most future flags.

**Worst case (app removed):**
- Appeal immediately. Be specific and polite.
- While appealing, make the APK available on the website for direct download.
- If appeal fails: create a new listing that addresses every violation. Resubmit.
- Consider also listing on Amazon Appstore as a backup distribution channel.

---

### Scenario 5: Jim Burns Out on GTM

**Early warning signs:**
- Jim skips 2+ GTM sessions in a row
- Jim catches himself spending "GTM time" on product features instead
- Jim dreads Monday (outreach day)
- Jim stops checking metrics
- Jim feels resentful that he is "doing marketing instead of building"

**Response plan:**
1. This is normal and expected. Every technical founder hits this wall. It is not a character flaw.
2. Immediately activate recovery mode: 2 weeks of zero GTM. Product work only. The world will not end.
3. During recovery, do the MINIMUM: respond to Play Store reviews (5 min, 3x/week). Everything else pauses.
4. After 2 weeks, ask: "Which ONE GTM activity do I actually enjoy?" Maybe it is the dentist conversations. Maybe it is filming with Oliver. Maybe it is writing Reddit posts. Do ONLY that activity for the next month.
5. For everything else: either automate it (Claude batch content + Buffer), outsource it (Fiverr, VA), or kill it.
6. If Jim cannot find ANY GTM activity he enjoys: hire a part-time marketing person ($1,500-2,500/month) or a fractional CMO ($2,000-4,000/month for 5-10 hrs/week). This is expensive but cheaper than the app dying.

**Prevention:**
- Recovery week every 4th week (already in the plan)
- Zero-GTM Fridays (already in the plan)
- Never exceed 8 hrs/week of GTM in Months 1-3
- Celebrate wins explicitly. Jim should write down every milestone: first non-friend install, first organic review, first dentist partner, first press mention. These small wins fuel motivation.

**Pivot option:**
- Abandon active GTM entirely and go "build in public" instead. Post weekly development updates on Twitter/X. Let the product grow through ASO and in-app review prompts alone. This is slower but requires almost zero GTM time and plays to Jim's strength (building). Many successful indie apps grew this way.

---

### Scenario 6: What If Nothing Works After 6 Months?

**Definition:** 6 months in, total installs < 500, D7 < 20%, monthly revenue < $50.

**This is the hardest scenario because it requires honest self-assessment.**

**Before giving up, verify these are NOT the cause:**
1. Play Store listing is actively bad (ask 5 strangers to rate it on a 1-10 scale)
2. The app has a critical bug that Jim missed (install it on 3 different phones)
3. Jim never actually executed the plan (8 hours/week for 6 months is 200 hours of real GTM work -- did Jim actually do this?)
4. The target audience is wrong (maybe older kids love it, maybe younger kids love it, but 7-year-olds don't)

**If all of the above check out and it still is not working:**
- The market may not be big enough to sustain a standalone brushing app at the price point Jim needs. This is a real possibility for a niche category.
- Options in order of preference:
  1. Expand scope: brushing + handwashing + sunscreen + vitamins = "kids health habits" app. Larger market.
  2. Change monetization: free app with dentist referral fees (B2B2C model).
  3. License the platform: sell white-labeled versions to dental practices or brands.
  4. Open-source and move on: release the code, write a blog post about the journey, move on to the next project. This is not failure. This is learning.

**The honest math:** If Jim is earning $0-50/month after 6 months of effort, and his time is worth $100/hour, he has invested $20,000+ of time value into an asset producing $50/month. The question is whether the growth curve is accelerating (keep going) or flat (pivot or stop). Month-over-month growth rate matters more than absolute numbers at this stage. Going from 50 to 100 installs/month (100% growth) is a better signal than being at 500 but flat.

---

*This is the operating manual. It does not replace the V2 GTM plan -- it tells Jim how to execute it. Every number in this document is a starting point. Adjust thresholds based on real data. The system works when Jim checks the tree, follows the rules, and makes decisions based on data instead of feelings. Update this document at the Month 3 review based on what the data actually shows.*
