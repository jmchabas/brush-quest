# L1 — Digital-Native Lens

## 1. Framing from the digital-native playbook

Fifty qualified installs in 14 days via organic Reels is, in SaaS terms, a cold-start distribution sprint to seed the loop — the analogue is Cal.com or Cron (now Notion Calendar) dropping a demo-clip cascade on Twitter and Product Hunt to surface 50 qualified early users. It is NOT a growth engine, it is a wedge: produce enough native-feeling vertical video to find the one hook that compounds, instrument it, then decide whether to scale. The product-market fit question for the channel is whether a 9-second "monster gets punched" loop can survive the parent-gatekeeper filter on IG, where parents (not kids) scroll. That is the single risk to surface in every PRD.

## 2. Route coverage

**Paid UA.** A SaaS founder would default to $100–300 in boosted Reels as signal-finders, not scale — IG's in-app boost is a cheap A/B machine for finding the thumbnail/hook that wins. Transfers well: 50 installs at ~$2–4 CPI is realistic at this budget, and Play Store has referrer attribution. Does not transfer cleanly: Meta ad targeting for "parents of 4–8 year-olds" is a blunt instrument post-iOS-14, and ads require AnemosGP LLC's Meta Business Manager to be in order — name it as a prerequisite in the PRD.

**UGC / creators.** Default move is a micro-creator seeding program (10–30 parenting accounts, 5K–50K followers, $50–150 product/cash per post, Fourthwall/Passes-style simple contract). Transfers strongly: parents trust parents on IG more than brand accounts. Partial blocker: COPPA + "no child face" means creator kids can be in frame only if the creator owns the rights and Jim does not re-share — structure agreements as "you post on your feed, we repost only with written parent consent and face obscured." Do not skip this in the PRD.

**Earned media.** A SaaS founder would skip press at 50 installs — ROI too noisy. Same here.

**Partnerships.** Pediatric dentists, Montessori IG accounts, kids-OT therapists. Transfers moderately — one warm partner DM > ten cold ones. Worth a single PRD for outreach, not a main route.

**PLG / referral.** In SaaS this is the whole game. Here: weakest route at 14-day horizon. Kids cannot refer, parent-to-parent referral needs a running streak and a reason to share (milestone screenshot). Worth instrumenting the share plumbing now (UTM on a "Ranger Rank earned" share card), not worth driving the 50 installs.

**Community.** Reddit r/parenting, r/Mommit, r/daddit, FB parenting groups, Geneva/Discord parent servers. Transfers well if Jim shows up as a dad, not a founder — founder-led transparency ("I built this because my 7-yo refused to brush") is IG + Reddit gold. Mod rules block most groups, so PRD needs a curated "allowed to post" list with each group's self-promo policy.

**ASO.** Table stakes. 50 installs come from ads + Reels + QR, but ASO determines conversion on the store listing. PRD for a 2-hour ASO pass (title, first screenshot, "short description" keyword density) is mandatory.

**Email / newsletter.** Buttondown list exists. A single "we're live on Play internal testing, here's the invite link" email is a layup — 20–40% of Jim's existing list will open. Cheapest 10 installs in the plan. PRD it.

## 3. Three underused plays

1. **Changelog-as-marketing.** Ship a public "this week in Brush Quest" Reel every Friday — 15 seconds of "shipped 3 new cavity monsters, Oliver (7) tested them." Linear, Cal.com, and Resend built audiences on this. No kids-app I know does it.
2. **Public retention dashboard.** A shareable "kids who brushed today: N" counter on brushquest.app, updated nightly from Firestore. Gives reporters/creators a live number to point at and gives you a daily Reel hook ("we hit 100 brushes today"). Stripe/Vercel-style open metrics.
3. **Founder-POV Reels from the dev desk.** Not "here's my app" but "my 7-yo just told me the Shadow Ranger needs a cape — shipping it tonight." This is the Pieter Levels / build-in-public playbook. Parents feel the parent, not the pitch. Almost no kids app does this because most are VC-funded and faceless.

## 4. Ranked takeaway

**High confidence:**
1. UGC micro-creator seeding (5–10 parents, small cash + product) — highest signal-to-cost for this audience.
2. Email to existing Buttondown list — cheapest installs on the plan.
3. ASO pass on Play Store listing — compounding multiplier on every other route.

**Medium confidence:**
4. Organic Reels from a founder-POV account (Jim's face OR a purchased creator partnership, given "face-of-brand not Jim" constraint — resolve this in the trunk loop).
5. $100–200 boosted Reel to find the winning hook, then lean in.
6. Targeted Reddit posts in 3 curated subs under dad-founder frame.

**Low confidence:**
7. Pediatric dentist / Montessori partnerships — slow, worth one warm DM each, not a main route.
8. Referral plumbing — instrument now, harvest in Month 2.
9. Earned media — skip.

**Non-obvious bet:** Ship a public "brushes today" counter at brushquest.app/live and turn it into the #1 evergreen Reel format — a counter ticking up with monster-defeat clips over it. No kids app does this. It gives you an infinite content well and a real-numbers credibility signal.

## 5. Quick failure modes

- **SaaS playbooks assume self-serve.** Kids apps have parent gatekeepers — a viral Reel among 8-year-olds does nothing. Every PRD must target the parent feed, not the "kids app" feed.
- **Build-in-public assumes the founder is the face.** Jim has explicitly said face-of-brand is NOT him. Resolve via hired creator or animated "Brush Quest team" persona before this lens's #3 play ships.
- **14 days is too short to judge UGC.** Creator content compounds over 30–90 days. If the PRD judges the route on Day 14 install count alone, it will kill a working channel too early. Bake in a 30-day readthrough metric alongside the 14-day target.
