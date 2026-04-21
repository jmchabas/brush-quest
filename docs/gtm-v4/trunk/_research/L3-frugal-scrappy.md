# Lens L3 — Frugal / Scrappy (trunk)

**Question:** 1,000 WAK by 2026-07-20 on $1–2K total, agentic execution, solo founder.
**Frugal posture:** treat paid acquisition as a trap until we have Play Store social proof (≥100 ratings). Hustle for the first 300–500 WAK; buy only once the funnel is proven.

---

## 1. Free distribution surfaces (where parents of 4–8yo actually are)

| # | Surface | Rough audience | Effort | What "winning" looks like |
|---|---|---|---|---|
| 1 | **r/Parenting** (5.9M) | US/EN, skews 2–10yo kids | 1–2h/wk | One genuine "my kid fought brushing for 2 years, this worked" comment in a relevant thread → 50–200 landing-page visits, 10–30 installs |
| 2 | **r/Mommit** (1.0M), **r/daddit** (800K), **r/toddlers** (420K), **r/Parenting_tips** (90K, hunch) | Parents of 2–8yo | 1–2h/wk | Same as above, more permissive of "founder" disclosures if flaired |
| 3 | **r/preschoolers** (50K, hunch), **r/ScienceBasedParenting** (280K) | Higher-intent, pickier | 0.5h/wk | 1 thoughtful comment/wk, no links in body — profile bio does the work |
| 4 | **Facebook Mom groups** — local ones beat giant ones. "Moms of [City]" groups (5–50K ea), "Gentle Parenting" (500K+), "Big Little Feelings community" groups (hunch, 100K+) | Very high intent | 2h/wk — slow trust | Admin relationship → one pinned post = 50–500 installs |
| 5 | **Buy Nothing / local neighborhood FB groups** | Hyper-local | 0.5h/wk | Gifting beta access, asking kids to test — trust-laundered distribution |
| 6 | **Substacks:** Big Little Feelings, Ms Rachel newsletter, Janet Lansbury, *Parentdata* (Emily Oster, 200K+), *The Double Shift*, *Mom Brain* | 10K–300K each | Reach-out hours | One guest mention or sponsored slot (<$200) → 100–1000 signups |
| 7 | **Pediatric-dentist waiting rooms** — QR-code flyers | ~30 kids/day per practice | 3–5h once, recurring mail | 5 practices × 5 installs/wk = 25 WAK/wk. Dentists *want* this — free cavity reduction marketing for them |
| 8 | **School / PTA newsletters** (elementary K–2) | 200–800 families per school | 2h per school | 1–3% install rate = 5–25 installs per newsletter. Summer dead zone (we launch in summer — real risk) |
| 9 | **Public library story-time & summer reading programs** | 20–100 parents per session | 2h outreach | Librarian mentions / flyer board = trust laundering |
| 10 | **Discord servers:** Big Little Feelings community, Lovevery parents (hunch), Homeschooling Discords (several 5–20K servers) | 5–50K each | 1h/wk | Be useful for weeks before mentioning app |
| 11 | **Product Hunt** (Kids / Family / Education) | 50K DAU, mostly founders | 4h launch day | Top-5 of day = 500–2000 visits, 50–200 installs. Good for social proof, not parents directly |
| 12 | **App review sites:** Common Sense Media (huge), Smart Apps for Kids (hunch, smaller), TheAppFactor, Geek Dad, Fatherly | 100K–5M/mo | 2–4h each pitch | One Common Sense review = long-tail SEO + trust |
| 13 | **YouTube kid-tech reviewers:** Techboomers, *Screen Time Reviews* channels (hunch), micro-dad/mom vloggers (5–50K subs) | Long-tail | 3h outreach each | Free app codes in exchange for honest review |
| 14 | **Pediatrician / family dentist Twitter & Instagram** (micro-influencers, 2–20K) | HCP-credible | 2h/wk | 1 DM-to-post = 20–100 installs and parent trust |
| 15 | **Hacker News "Show HN"** | 5M, skews dev-dads | 1h | 200–500 visits on good day, kid-tech category converts poorly (hunch) |
| 16 | **Parenting Stack Exchange, Quora parenting** | Long-tail SEO | 1h/wk | Evergreen — 10–30 installs/mo compounding |
| 17 | **Nextdoor** — local parent posts | US neighborhood-level | 0.5h/wk | Best for ZIP-code clusters; admin-moderated |

**Not listed because mostly dead or hostile to app promo:** BabyCenter (demographic too young), Cafe Mom (bot-overrun), Circle of Moms (defunct), Reddit r/Parenting's weekly self-promo (low reach). Instagram/TikTok require the APIs we don't have — covered in §3.

---

## 2. Agent-runnable zero-cost plays (top 3)

### Play A — "Reddit Comment Concierge" (r/Parenting + r/Mommit + r/daddit + r/toddlers)
- **Action:** Agent runs daily: search new threads matching `brush|teeth|toothbrush|dentist|morning routine|bedtime fight`. Drafts a human-sounding, non-promotional comment referencing Brush Quest only if genuinely relevant. Saves draft to Drive.
- **MCPs:** claude-in-chrome (Reddit search + compose — works without API), Drive (draft log), knowledge-graph (remember which subs/accounts used, avoid ban triggers).
- **Human-in-loop:** Jim reviews & posts from his own account each morning (5 min). Never auto-post — Reddit will shadowban.
- **Week 1 MVP:** 5 drafted comments/day, Jim ships 2–3. Target 1 upvoted reply → profile click-through. Landing: brushquest.app/rangers email bridge.
- **Expected:** 20–80 landing visits/wk; if one comment hits, 500+.

### Play B — "Pediatric Dentist Flyer Drop" (offline, hybrid-agentic)
- **Action:** Agent scrapes Google Maps for pediatric dentists within 25 miles of Jim's ZIP via claude-in-chrome. Generates personalized email per practice (Gmail MCP) offering free "Brush Quest adventure cards" (printable QR flyers, ai-image-gen + Canva MCP). Calendar MCP books drop-offs.
- **MCPs:** claude-in-chrome, Gmail, Canva, ai-image-gen, Calendar — **all available**.
- **Human-in-loop:** Jim approves the first 5 emails, then signs off a batch-of-25 per week. Jim (or paid courier, ~$50 total) does physical drops.
- **Week 1 MVP:** 25 practices emailed, 5 flyer packs printed + mailed, 2 drop-offs scheduled. Cost: ~$60 (printing + postage).
- **Expected:** 3–5 practices say yes in 90 days → 50–150 WAK compounding. Highest-leverage offline play because the dentist is the trust proxy.

### Play C — "Substack / Newsletter Pitch Machine"
- **Action:** Agent builds a list of 50 parenting-Substack writers (claude-in-chrome on Substack discover). Drafts 50 personalized pitches referencing a recent post. Sends via Gmail MCP (one per day to stay under spam thresholds).
- **MCPs:** claude-in-chrome, Gmail, Drive — available.
- **Human-in-loop:** Jim reviews first 5 drafts; then batched weekly approval.
- **Week 1 MVP:** 15 pitches sent, 2 replies, 1 yes. A paid mention (≤$200) in one mid-size Substack = 500–2000 visits → 50–200 installs. Fits inside $1–2K budget.
- **Expected:** 2–4 mentions across 90 days, compounding via long-tail search.

**NOT buildable without new API access:** Instagram Graph, Reddit API, TikTok Business, Meta Creator Marketplace. Calling these out as TO-BUILD if a downstream PRD needs them.

---

## 3. Money traps to avoid at this stage

- **Google App Install / UAC ads.** With <100 Play ratings, CPI runs $6–$12 for kids-app vertical (hunch, based on 2024–25 benchmarks). $1K buys 100 installs with <40% WAK conversion = 40 WAK. Same $1K in Substack mentions or flyer drops = 300+ WAK. **Defer until ≥100 ratings + ≥20% D7.**
- **Meta / Instagram ads without iOS live + Creator proof.** Meta's kids-app CPMs are inflated, COPPA targeting is restricted, and we have no Instagram organic presence to retarget. $500 here produces <50 installs and no compounding asset.
- **Influencer marketplaces (#paid, Aspire, Creator.co).** Minimum spend $500–$2K per deal, parenting-mom-creator rates are $250–$800/post for 10K-follower accounts, no guarantee of kid-app category performance. Replace with free DMs to 20 micro-creators (<10K) offering free lifetime Brush Quest+.
- **Honorable mention trap: Product Hunt hunter fees.** Paying a "PH hunter" $200–$500 is dead money — self-hunt is fine in 2026.

---

## 4. Ranked takeaway (volume per hour invested)

| Rank | Play | Confidence | Why |
|---|---|---|---|
| 1 | **Pediatric dentist flyer drop (Play B)** | High | Trust proxy + captive audience + compounding. Offline wins because everyone is attacking online. |
| 2 | **Substack pitch machine (Play C)** | Medium-High | One yes = 500+ visits. Agent automates the grind. |
| 3 | **Reddit comment concierge (Play A)** | Medium | Slow trust build, one viral comment = big spike. Ban risk if over-automated. |
| 4 | **Local Facebook mom-group admin relationships** | Medium | Admin trust is a moat, but months to build; start now for month-3 payoff. |
| 5 | **Common Sense Media / app-review pitches** | Medium-Low | SEO long-tail value; unlikely to hit 1K WAK alone |
| 6 | **Product Hunt launch** | Low-Medium for WAK | Optics/social-proof value > actual parent installs |
| 7 | **PTA newsletters** | Low (this window) | Summer kills K–2 newsletters; revisit in Aug/Sep |

**THE one move this week:** Ship Play B — draft 25 personalized dentist emails + print 50 flyer packs + lock 3 drop-off meetings. It's the only play with an offline trust moat and summer doesn't kill it.

---

## 5. Quick failure modes (how frugal-scrappy misleads)

- **Ceiling traps.** Reddit/FB tactics plateau at ~300–500 WAK no matter how hard you grind — the authentic-comment cadence caps itself. Don't mistake early traction for a scalable channel; plan the handoff to paid by WAK 500.
- **Time-cost invisibility.** "Free" channels eat 5–10 hrs/wk of Jim's 5–10 hrs/wk available. Hustling three at once is the default failure — one Jim-hour is worth more than $30 of ads once you account for context-switching. Pick ONE, run it for 3 weeks, evaluate.
- **Authenticity tax.** Agentic drafting of Reddit/Substack/DM copy sounds like an AI if shipped raw. Every message needs Jim's 60-second human pass or it burns the channel. The moment a mod screenshots "this reads like ChatGPT," the subreddit is dead to us.
