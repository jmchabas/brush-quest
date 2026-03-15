# Brush Quest — Master Strategy
**Goal**: 1 million children using the app, $10M+ ARR
**Last updated**: 2026-03-14
**Current phase**: 0 — Pre-Launch

---

## Active Decisions (CEO → Workstreams)

### D-001: Ship to Play Store before v7 polish (2026-03-14)
**Context**: App at v7 with 30 UX fixes. Todo has 10 polish items (refactoring, tests, APK size).
**Decision**: Submit to Play Store NOW. Polish in parallel during 3-7 day review wait.
**Affects**: APP workstream
**Status**: ACTIVE

### D-002: Content-led subscription — "Space Ranger Pass" (2026-03-14, revised)
**Context**: Deep research done (see `research/`). Parent-feature subscription rejected — camera "verification" is dishonest (motion ≠ brushing proof), dentist reports are gimmicks, reminders are table stakes. Content-led model recommended instead.
**Decision**: Free = 3 worlds + 2 heroes + 2 weapons (excellent standalone). "Space Ranger Pass" = all 10 worlds + all heroes/weapons + monthly content drops + family profiles + parent activity log + cooperative family quests. **$2.99/mo or $24.99/yr.** Use RevenueCat.
**Key constraint**: Never frame camera motion detection as "brushing verification." It's a gameplay feature, not proof.
**Affects**: APP, PRICING workstreams
**Status**: PENDING — awaiting Jim's feedback on revised pricing + model

### D-003: Feature freeze until 100 users (2026-03-14)
**Context**: App has 10 worlds, 70 monsters, 6 heroes, 6 weapons, boss battles, card collecting. More than enough.
**Decision**: Zero new features until 100 real (non-Jim) users. Only allowed: bug fixes blocking brush completion, Play Store requirements, analytics instrumentation.
**Affects**: APP workstream
**Status**: ACTIVE

---

## Where We Are Today

### Assets
- Fully built Android app (v7 in progress): 10 worlds, 70 monsters, 6 heroes, 6 weapons, camera motion detection, boss battles, card collecting, Firebase auth + sync
- Landing page at jmchabas.github.io/brush-quest (in progress)
- Pricing model (in development)
- Strong product with real kid-testing feedback baked in

### Gaps
- Not on Google Play Store yet
- No iOS version
- No analytics beyond Firebase Crashlytics
- Zero users
- No monetization
- No social proof / reviews
- Solo founder — no team

---

## The 5-Phase Plan

### PHASE 0: Launch-Ready (Now → Week 2)
**Objective**: Get the app in front of real users ASAP. Stop building, start shipping.

#### Critical Path
1. **Get on Google Play Store** — this is THE blocker
   - [ ] Finalize Play Store listing (screenshots, description, feature graphic)
   - [ ] Set up Google Play Developer account ($25 one-time)
   - [ ] Submit for review (expect 3-7 day review for new developers)
   - [ ] Content rating questionnaire (ESRB — target "Everyone")
   - [ ] Privacy policy page (required — add to landing page)
   - [ ] Data safety form (camera usage, Firebase data collection)

2. **Landing page polish** (parallel session)
   - [ ] Add privacy policy
   - [ ] Add Play Store badge/link once approved
   - [ ] Email capture for launch waitlist (Mailchimp free tier or similar)

3. **Pricing model** (parallel session)
   - Recommendation: **Freemium** — free with 2 worlds unlocked, premium unlocks all 10 worlds + all heroes/weapons for $4.99/month or $29.99/year
   - Why freemium: parents need to see the kid hooked before paying. Kids' apps have high churn — you need the free tier to get volume.
   - Alternative: one-time purchase $9.99 (simpler but caps revenue)

4. **Analytics** — you can't grow what you can't measure
   - [ ] Firebase Analytics (you already have Firebase — just add the package)
   - [ ] Key events to track:
     - `app_open`, `onboarding_complete`, `first_brush_complete`
     - `brush_session_complete` (with duration, phase reached)
     - `brush_session_abandoned` (with phase where they quit)
     - `shop_visit`, `purchase_attempt`, `purchase_complete`
     - `day_2_return`, `day_7_return`, `day_30_return`
   - [ ] Firebase A/B Testing for paywall placement experiments

5. **App Store Optimization (ASO) basics**
   - Title: "Brush Quest: Kids Toothbrushing Game"
   - Keywords: toothbrushing app for kids, brushing timer kids, dental game children, tooth brushing game, kids oral hygiene
   - Short description: "Turn brushing teeth into a space battle! 2-min guided timer that kids actually love."

#### Phase 0 Success Metrics
- App live on Google Play Store
- Landing page with Play Store link + email capture
- Analytics tracking core events

---

### PHASE 1: Validate (Weeks 2-8)
**Objective**: Get 500 real users. Prove kids come back. Find product-market fit signals.

#### Get First 100 Users (Weeks 2-4)
These users are for LEARNING, not revenue. Keep it free.

1. **Personal network** (Day 1)
   - Every parent you know. Every friend with a 4-8 year old.
   - Ask them for honest feedback AND a Play Store review.
   - Target: 20-30 installs from your network

2. **Reddit** (Week 1-2)
   - r/Parenting (3.8M), r/Daddit (700K), r/Mommit (800K), r/toddlers
   - Don't spam — share genuinely: "I built an app to get my kid to brush his teeth, here's what happened"
   - Before/after story angle: "My 7yo fought brushing every night. I built a game. Now he asks to brush."
   - r/AndroidApps, r/AppHookup for the tech-savvy parents
   - Key: be authentic, share the story, respond to every comment

3. **Parenting Facebook Groups** (Week 2-3)
   - Local parenting groups (your city/region)
   - "Gentle parenting" groups, "positive discipline" groups
   - Same story-driven approach, not "download my app"

4. **Parenting forums & communities**
   - BabyCenter, What to Expect, Mumsnet (UK)
   - "Any tips for kids who hate brushing?" — help first, share app second

5. **Product Hunt** (Week 3-4)
   - Schedule a launch day
   - "Show HN" on Hacker News (tech parents love this)
   - IndieHackers community post

#### Measure What Matters (Weeks 2-8)

| Metric | Target | Alarm | Why It Matters |
|--------|--------|-------|---------------|
| D1 Retention | >60% | <40% | Do kids want to come back tomorrow? |
| D7 Retention | >35% | <20% | Is the habit forming? |
| D30 Retention | >20% | <10% | Long-term habit = LTV |
| Session Completion Rate | >85% | <70% | Do kids finish the 2-min brush? |
| Avg Sessions/Week | >10 | <7 | 2x/day = 14, 1x/day = 7 |
| Onboarding Completion | >90% | <75% | Is tutorial clear enough? |
| Play Store Rating | >4.5 | <4.0 | Social proof for growth |

**If D7 retention < 20%**: STOP all growth work. Fix the product. The game isn't sticky enough.
**If D7 retention > 35%**: You have something. Move to Phase 2.

#### Product Fixes Based on Data (Weeks 4-8)
- Interview parents via email/DM: what do they like? What's missing?
- Watch for drop-off patterns: which phase? which day?
- Quick iteration cycles: fix → ship → measure → repeat

#### Phase 1 Success Metrics
- 500+ installs
- D7 retention > 35%
- Play Store rating > 4.3 with 20+ reviews
- 5+ parent testimonials you can use in marketing
- Clear understanding of WHY users stay or leave

---

### PHASE 2: Monetize & iOS (Months 2-5)
**Objective**: Prove the business model. Launch iOS. Get to $5K MRR.

#### Monetization (Month 2-3)
1. **Implement paywall**
   - Free tier: World 1-2 (Candy Crater + Slime Swamp), first 2 heroes, first 2 weapons
   - Premium: All 10 worlds, all heroes, all weapons, card album completion
   - Placement: after the kid finishes World 2, show "new worlds to explore!" with parent-gated purchase
   - Price testing: $3.99/mo vs $4.99/mo vs $6.99/mo, annual at 40% discount
   - Use RevenueCat for subscription management (handles both platforms)

2. **Parent-gated purchases**
   - Critical for kids' apps: COPPA compliance
   - Simple math problem gate ("What is 14 + 23?") before any purchase
   - Prevents accidental purchases and keeps parents in control

3. **Conversion optimization**
   - "Your child has brushed 14 times! Unlock the next adventure?"
   - Show the kid's excitement: "NOVA wants to explore Crystal Cave! Ask Mom or Dad!"
   - Free trial: 7-day full access, then paywall
   - Target: 5-8% free-to-paid conversion

#### iOS Launch (Month 3-4)
1. **Why iOS matters**: iOS users pay 2-3x more for kids' apps
   - Apple App Store has 65%+ of kids' app revenue
   - Parents on iOS are more likely to pay for quality
   - Flutter makes this relatively easy — same codebase

2. **iOS-specific requirements**
   - Apple Developer account ($99/year)
   - App Store review is stricter for kids' apps (Kids Category)
   - Must comply with Apple's kids' app guidelines (no third-party analytics, no ads, limited data collection)
   - App Tracking Transparency prompt
   - TestFlight beta first

3. **App Store Optimization for iOS**
   - Apple Search Ads (start small: $500/month)
   - Keywords, screenshots optimized for iPhone/iPad

#### Growth Experiments (Month 3-5)
1. **Referral system**: "Invite a friend, both get a free week of premium"
2. **Sibling sharing**: Family profiles (v8 feature) — one subscription covers all kids
3. **Streak challenges**: "Can you brush 30 days in a row? Share your streak!"

#### Phase 2 Success Metrics
- $5K MRR (Monthly Recurring Revenue)
- 5,000+ total installs (both platforms)
- iOS live and rated 4.5+
- Free-to-paid conversion > 5%
- Monthly churn < 8%

---

### PHASE 3: Growth Engine (Months 5-12)
**Objective**: Get to 50K users and $50K MRR. Build the growth machine.

#### Content Marketing
1. **"Teeth Talk" blog** (SEO play)
   - "How to get your kid to brush their teeth" (high search volume)
   - "Best toothbrushing apps for kids 2026" (capture comparison shoppers)
   - "Gamification and children's habits: the science" (credibility)
   - "Dental tips for parents: age-by-age guide" (broad traffic → funnel)
   - Target: 10 articles ranking on page 1 for kids brushing keywords

2. **YouTube / TikTok / Instagram**
   - Short clips of kids ACTUALLY using the app (with parent permission)
   - "Watch this 5-year-old defeat the Cavity Boss!" — viral potential
   - Parent reaction videos: "She asked to brush her teeth?!"
   - Educational content: "Why 2 minutes matters" by a dentist (collab)

3. **Parenting influencer partnerships**
   - Micro-influencers (10K-100K followers): $200-500 per post
   - Focus on "mom bloggers" and parenting YouTubers
   - Give them premium free + affiliate commission (30% of first year)
   - Budget: $2K-5K/month → test 10 influencers, double down on what works

#### Strategic Partnerships
1. **Pediatric dentists** — THE channel
   - Dentists see parents who complain about brushing EVERY DAY
   - Offer: "Recommend Brush Quest to patients. Here's a co-branded flyer."
   - Dentist gets: happy patients, differentiation, possible revenue share
   - Start local: 10 dentists in your area. Give them QR code cards.
   - Scale: dental association conferences, dental supply companies
   - **Dream deal**: partnership with a dental chain (Kool Smiles, Western Dental)

2. **Dental insurance companies**
   - Kids who brush properly = fewer cavities = lower claims
   - Pitch: "Offer Brush Quest Premium free to members. We reduce your claim costs."
   - Revenue model: per-member-per-month fee ($0.50-1.00)
   - This is a B2B2C play with massive scale potential
   - Target: Delta Dental, Cigna, MetLife dental plans

3. **Schools & after-school programs**
   - Health education curriculum tie-in
   - Bulk licensing for school districts
   - "Brush Quest Classroom" — teacher dashboard, class challenges

4. **Toothbrush / toothpaste brands**
   - Colgate, Oral-B, Hello Products, Tom's of Maine
   - Co-branded "Brush Quest Edition" toothbrush with QR code for premium
   - Revenue: licensing fee + premium conversion
   - This is the HOME RUN partnership — they have the distribution

#### Paid Acquisition (Month 6+)
1. **Apple Search Ads**: "toothbrushing app kids" — high intent
2. **Google App Campaigns**: automated, target CPI < $2
3. **Facebook/Instagram Ads**: target parents of 4-8 year olds
4. **Creative**: 15-second video of kid laughing while brushing with the app
5. **Budget**: start at $3K/month, scale to $10K+ when unit economics work
6. **Target LTV:CAC ratio**: > 3:1

#### Phase 3 Success Metrics
- 50K+ total users
- $50K MRR
- LTV:CAC > 3:1
- 3+ partnership deals signed
- iOS and Android rated 4.5+ with 500+ reviews

---

### PHASE 4: Scale (Year 1-3)
**Objective**: 1M users, $10M+ ARR. Category leader.

#### International Expansion
- **Localization priority**: Spanish, French, German, Japanese, Portuguese
- Voice lines: regenerate in each language (ElevenLabs supports multilingual)
- Monster/hero names: keep or localize
- Pricing: adjust per market (lower in LATAM, higher in Japan/Nordics)
- Target: 10 languages covering 80% of smartphone parents globally

#### Platform Expansion
- **iPad**: optimized layout (larger monster battles, split-screen guide)
- **Smartwatch companion**: Apple Watch/Wear OS — "brush streak" complication
- **Smart toothbrush integration**: Bluetooth connection to Oral-B/Sonicare kids brushes (replace camera with real brush data)
- **Web dashboard for parents**: brush history, habit reports, streak graphs

#### Advanced Monetization
1. **Family Plan**: $7.99/month for up to 4 kids (sibling competition built-in)
2. **Dental Practice Plan**: $49/month — practice can gift premium to patients
3. **Enterprise/Insurance Plan**: per-member pricing, outcomes reporting
4. **Seasonal content packs**: Halloween monsters, Christmas worlds ($1.99 each or included in premium)
5. **Physical merch**: Brush Quest toothbrushes, character toys (licensing)

#### Team Building
As revenue grows, hire in this order:
1. **Marketing/Growth person** (at $20K MRR) — you need to code, not do marketing
2. **Customer support** (at $30K MRR) — parents will email
3. **Content creator** (at $50K MRR) — social media, blog, partnerships
4. **Second developer** (at $80K MRR) — iOS optimization, new features
5. **Head of Partnerships** (at $100K MRR) — dental, insurance, brands

#### Phase 4 Success Metrics
- 1M+ active users
- $10M+ ARR
- Present in 10+ countries
- 3+ enterprise/insurance deals
- Team of 5-8 people
- Category leader in kids' dental apps

---

### PHASE 5: Dominance (Year 3+)
**Objective**: Expand beyond brushing. Become THE children's health habit platform.

#### Expand to Adjacent Habits
- **Wash Quest**: Handwashing timer game (same formula, new theme)
- **Sleep Quest**: Bedtime routine gamification
- **Eat Quest**: Healthy eating tracker for kids
- **Move Quest**: Exercise/active play challenges
- Unified "Quest" platform with shared characters, cross-game rewards

#### Defensibility / Moat
- **Data**: millions of brushing sessions → partner with dental researchers
- **Brand**: "Quest" becomes synonymous with kids' habit building
- **Network effects**: sibling competition, class challenges, friend leaderboards
- **Partnerships**: exclusive deals with dental chains and insurance companies
- **Content library**: 100+ worlds, 500+ monsters, seasonal events

---

## Competitive Landscape

Every direct competitor is free or near-free. The market is structurally free (subsidized by big companies as marketing/goodwill). Full analysis in `research/competitor-analysis.md`.

**Our moat**: No one else has this depth of content + camera-based gameplay + progression system in a brushing app. Most competitors are abandoned or minimal. The market is wide open.

**Key pricing insight**: Cannot price as a game (competitors are free). Must price as a content-led parenting tool. See `research/pricing-research.md` and `research/monetization-models.md`.

---

## Key Strategic Principles

1. **Speed > Perfection**: Ship fast, learn fast. V7 polish is nice-to-have — getting on the Play Store is the real priority.

2. **Parents buy, kids decide**: The kid's excitement is your sales force. If the kid says "Mom can I brush my teeth?", the parent will pay anything.

3. **Retention is king**: A churning user is worthless. Every feature should ask: "Does this make a kid come back tomorrow?"

4. **Dentists are the channel**: Parents trust dentists more than ads. One enthusiastic dentist = 50 downloads/month.

5. **iOS is where the money is**: Android-first was right for building fast. But monetization lives on iOS.

6. **Don't scale what isn't working**: If D7 retention is below 35%, all growth spend is wasted. Fix the product first.

7. **Tell stories, not features**: "Your kid will beg to brush" > "10 worlds and 70 monsters"

8. **B2B2C is the endgame**: Direct-to-consumer gets you to $1M ARR. Dental insurance partnerships get you to $10M+.

---

## What To Do RIGHT NOW (This Week)

### Priority 1: Play Store submission
This is the single highest-leverage thing you can do. Nothing else matters until real users have the app.

### Priority 2: Privacy policy
Required for Play Store. Required for any kids' app. Add to landing page. Cover: what data you collect (camera frames processed locally, Firebase auth email, Firestore brush history), what you don't (no ads, no tracking, no third-party sharing).

### Priority 3: Analytics events
Add Firebase Analytics with the core events listed above. You'll be flying blind without data.

### Priority 4: Email capture on landing page
Even before Play Store approval — start collecting emails of interested parents.

---

## Revenue Projections (Conservative)

| Month | Users | Paid (5%) | MRR ($4.99) | ARR |
|-------|-------|-----------|-------------|-----|
| 3 | 500 | 25 | $125 | $1.5K |
| 6 | 5,000 | 250 | $1,250 | $15K |
| 9 | 15,000 | 750 | $3,750 | $45K |
| 12 | 50,000 | 2,500 | $12,500 | $150K |
| 18 | 150,000 | 10,000 | $49,900 | $600K |
| 24 | 500,000 | 35,000 | $174,650 | $2.1M |
| 36 | 1,000,000 | 70,000 | $349,300 | $4.2M |

Add B2B2C (dental insurance): potential $2-5M additional at scale.
Add partnerships (toothbrush brands): potential $1-3M in licensing.

**Total addressable market**: ~150M kids aged 3-10 in smartphone-owning families globally. Even 1M users = 0.7% penetration. The ceiling is high.

---

## Risk Register

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Play Store rejection (kids' privacy) | High | Medium | COPPA compliance, privacy policy, no behavioral ads |
| Low retention | Critical | Medium | Kid testing, fast iteration, engagement systems |
| Competitor with big IP (Disney, Pokemon) | High | Low | They haven't done it well yet. Speed + depth is our advantage |
| Solo founder burnout | High | High | Prioritize ruthlessly. Say no to nice-to-haves. Hire at $20K MRR |
| Camera permission rejection by parents | Medium | Medium | App works fine without camera (timer fallback) |
| Apple Kids Category rejection | Medium | Medium | Study guidelines before iOS submission, no third-party SDKs in kids mode |

---

*This is a living document. We update it as we learn from real users.*
