# L1 — Digital-Native Lens (Trunk)

## 1. Framing from the digital-native playbook

If Brush Quest were a SaaS product, the question would be: "How do I get to 1,000 WAUs on a $1–2K CAC budget in 90 days, when my buyer (parent) is not my user (kid), my activation is a daily ritual, and I can't ship the self-serve viral loops I'd normally reach for?" The closest analogues are Duolingo's early kid-free era (streak-as-product), Calm/Headspace at the $10K-MRR stage (parent-payer, ritual-user, paid-to-seed-organic), and indie iOS apps like Structured or Opal that launched on Product Hunt + TikTok UGC without paid UA. At 1,000 WAK / 90 days / $1.5K, CAC ceiling is ~$1.50/WAK — so any route whose blended CAC is >$3 install is dead before it starts; the entire portfolio has to lean organic or near-zero-marginal-cost, with paid only as a forcing function for specific tests.

## 2. Route coverage

**Paid UA (Meta/TikTok/Google).** SaaS default at this budget is a $500 "can we even buy this?" smoke test on Meta targeting parents 28–42 with kid-age signals, optimized for landing-page email capture (not install — installs are too expensive at this budget). Transfers partially: Meta parent-targeting works, but optimizing for install burns budget on non-activators, and COPPA means the ad creative can't show a real kid. **Does not transfer:** TikTok self-serve ads for a kids app — auction is brutal and creative needs a face, which we've ruled out.

**UGC / creators.** SaaS founder default is micro-influencer seeding via Passes/Beehiiv sponsorships at $50–200/post. Transfers well if reframed as "parent-creator on Instagram/TikTok who already posts parenting content" — not kid-creators. **What transfers:** the hero-character-as-proxy lets a parent creator film their kid's hand/toothbrush without showing face; 10 seeded parents at $100 each = $1K, exactly the budget. **Does not transfer:** "creator sends code → gets affiliate revenue" because there's no subscription spike to share.

**Earned media / PR.** SaaS default: HARO, a founder story on Indie Hackers, a launch on Tech for Kids newsletters. Transfers cleanly — parenting press (Lifehacker Parenting, Romper, Fatherly, Today's Parent) actively covers "apps that make [hated chore] work." Angle: "solo founder + AI shipped a kids app that gets 7-year-olds to brush twice a day" is a legitimately fresh pitch. Low cost, high leverage. **Does not transfer:** Product Hunt — parent audience is thin there and it burns a one-time card for ~200 curious devs, not 1,000 WAK.

**Partnerships.** SaaS default: integrate with a complementary tool. For Brush Quest, the analogue is dentist offices, pediatric practices, and one dental-brand co-marketing deal (Quip, Burst, Hum). Transfers strongly: a single pediatric-dentistry practice with 500 families hitting a QR code after a cleaning visit is a viable 90-day path to 200+ WAK with near-zero marginal cost. **Does not transfer:** paid co-marketing at this budget — the brands expect $10K+ minimums.

**PLG / referral.** SaaS default: in-product referral loop ("invite a friend, get a month free"). **Does not transfer** — COPPA + no-prompts-to-children rule forbids an in-app referral surface aimed at the kid. Parent-side referral ("share with another parent") is possible but parents don't share apps the way SaaS users share tools; conversion will be <1%.

**Community.** SaaS default: Discord server, weekly office hours. **Does not transfer** — parents of 4–8yos don't want another Discord. What does work is existing communities: r/Parenting, r/daddit, Facebook Groups for parents of 5–8yo boys, Beehiiv parenting newsletters. The play is show up and be useful, not build.

**ASO.** SaaS default: not usually a priority. For Brush Quest it's the single highest-leverage organic channel once Play is public — "toothbrush timer for kids" has meaningful search volume and low competition. Transfers 100%. Should be a Tier-1 bet, ASO-optimized screenshots + a keyword-dense subtitle.

**Email / newsletter.** SaaS default: Beehiiv + paid sponsorships in Morning Brew–style newsletters. Transfers well — Bored Teachers, The Sunday Sermon (parenting), and smaller dad-newsletters run $100–300 placements. Buttondown list at brushquest.app/rangers is the capture bridge; email nurture sequence is the conversion layer when iOS ships.

**Content / SEO.** SaaS default: long-tail blog posts that rank. Transfers slowly — "how to get my 5-year-old to brush teeth" has real volume but 90 days is too short for SEO to mature. Worth writing 5 evergreen posts anyway for the compounding 2027 tail.

## 3. Three underused plays

1. **Public changelog + "Built-in-90-Days" build log.** A SaaS founder would ship a Beehiiv or Substack documenting every cycle, Oliver's reactions, metrics. Kids-app space has zero of this — it becomes the press hook and the parent-trust signal simultaneously.
2. **Open metrics page at brushquest.app/stats.** "237 kids brushed today, 1,482 monsters defeated this week." Duolingo-style transparency; zero kids-app competitor does this; every parenting journalist quotes it.
3. **Parent-facing README.** A Notion-style "here's exactly how the app works, what we track, what we don't, every voice line we use." COPPA-strict as a trust asset, not a compliance cost. Link from App Store description.

## 4. Ranked takeaway

**High confidence:** ASO + public-Play launch (Tier 1) · Pediatric-dentist partnership pilot · Parenting earned-media pitch (Romper, Fatherly, Lifehacker Parenting) · Newsletter sponsorships in dad/parenting Beehiivs.
**Medium confidence:** Micro-creator seeding (parent creators, hero-proxy creative) · $500 Meta smoke test to brushquest.app/rangers · Reddit (r/daddit, r/Parenting) useful-first presence.
**Low confidence / skip at this stage:** TikTok paid · Product Hunt · in-product referral · new Discord community · content-SEO as near-term WAK driver.

**Non-obvious bet:** ship the public metrics page + build-log newsletter in week 1. A conservative founder won't — it feels exposing. It's the single fastest way to manufacture press angle + parent trust on a $0 budget.

## 5. Quick failure modes

- SaaS playbooks assume self-serve activation; Brush Quest has a parent-install → kid-engage handoff that can silently kill WAK even with good install numbers. Measure WAK, not installs.
- "Community-led growth" is a SaaS cliché that collapses for parents of young kids — they don't join communities for products, they join for survival tactics. Don't build a Discord.
- Digital-native lens over-indexes on content flywheels; 90 days is too short for SEO/content to produce meaningful WAK. Treat content as 2027-tail insurance, not a Q2 lever.
