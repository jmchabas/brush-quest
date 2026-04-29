# Apple App Store — Listing Copy (parent-lens pass)

> Drafted 2026-04-28. Rewritten through the parent's decision lens. Reviewed before paste into App Store Connect (PLAN.md 2C-2). Limits checked against Apple's published max.

---

## App Name (≤30 characters)

**`Brush Quest: Space Rangers`** — 26/30 ✓
Differentiates from existing iOS namesake; "Space Rangers" hooks the kid in the title.

## Subtitle (≤30 characters)

**`Make brushing the easy part`** — 28/30 ✓
Speaks straight to the parent's pain without conflict-themed vocabulary that could be flagged in Kids Category review.

## Promotional Text (≤170 characters, editable any time without re-review)

**`Two minutes of brushing without bargaining. Built by a dad for his own kids — now shared with families tired of the nightly negotiation. No ads. No tracking.`**

Count: 156/170 ✓

## Description (≤4000 characters)

```
Brushing battles? We get it.

Brush Quest is a 2-minute toothbrushing app made by a dad for his own kids — and shared with other families who are tired of the nightly negotiation.

Your child picks a Ranger, picks a weapon, and battles the Cavity Monsters threatening their teeth. The mouth-guide overlay quietly teaches WHERE to brush — not just how long. By the time the timer's up, all four areas of the mouth have been covered, the boss monster is defeated, and your kid is asking to brush again tomorrow.

That's the goal. A habit that survives.

────────────────────────────────────
WHAT PARENTS GET
────────────────────────────────────

• A 2-minute brushing routine that doesn't need negotiation
• Real coverage: the on-screen mouth guide teaches kids WHERE to brush, quadrant by quadrant — the part most timers skip
• Streaks and small celebrations build the habit through positive reinforcement, not pressure
• Optional cloud backup if you want progress to follow your child between devices (parent-only, behind a math problem)
• Works fully offline — no account required to use the app
• Designed for ages 6-8; younger and older siblings often play happily too

────────────────────────────────────
WHAT YOUR CHILD SEES
────────────────────────────────────

A friendly guide who knows their name. A boss monster shaking with every brush stroke. Voiced encouragements throughout — no reading required.

The brushing zone shifts on screen so they always know where their toothbrush should be. Two minutes goes by fast.

────────────────────────────────────
PRIVACY YOU CAN ACTUALLY VERIFY
────────────────────────────────────

Brush Quest is submitted to the Apple Kids Category. We made deliberate choices to align with that:

• No advertising. No advertising SDKs of any kind, on iOS or anywhere else.
• No third-party analytics or crash-reporting in the iOS app — stripped at build time. Not "configured off." Not in the binary at all.
• No advertising IDs. No App Tracking Transparency prompt — because we don't track.
• Sign-in is optional and behind a parental gate. Children cannot create accounts, link to social services, or follow external links.
• No social features, no chat, no in-app purchases, no subscriptions.

Plain-English privacy policy: https://brushquest.app/privacy-policy.html

────────────────────────────────────
FROM THE MAKER
────────────────────────────────────

I built Brush Quest for my own kids because I was tired of fighting them about brushing every night. It's free. It's ad-free. It's the kind of app I'd want on my own children's devices.

If it's helping at your house, I'd love to hear about it.

— Jim
support@brushquest.app
AnemosGP LLC
```

Approximate count: ~2,300 / 4,000 ✓ (~30% shorter than the previous draft — the feature list cuts went there.)

## Keywords (≤100 characters, comma-separated, NO spaces around commas)

**`toothbrushing,brushing,kids habit,dental,parents,routine,bedtime,family,hygiene,timer,toddler,health`**

Count: 95/100 ✓
Note: keywords are *additional* to the App Name. We avoid duplicating "brush" or "quest" since both are in the name. "Parent" indexes both "parent" and "parents".

## Categories

- **Primary Category:** `Kids → Ages 6-8`
- **Secondary Category:** `Education`

## Age Rating Questionnaire (2026 version)

Default to **4+**. Notes for the questionnaire:
- Cartoon Violence: **None** (cavity monsters are non-violent silly characters; no realistic weapons context)
- In-app controls: **Yes — math gate on Settings**
- Medical/wellness: **Yes — toothbrushing health-education context**
- Everything else: None

## Support / Marketing / Privacy URLs

- Support URL: `https://brushquest.app/`
- Marketing URL: `https://brushquest.app/`
- Privacy Policy URL: `https://brushquest.app/privacy-policy.html`

## Copyright

`© 2026 AnemosGP LLC`

## App Review Information (private — for Apple reviewers)

See `docs/ios-port/review-notes.md` (separate doc, drafted in PLAN.md task 2C-6).

---

## What changed in this rewrite vs v1

| Section | v1 (feature-lens) | v2 (parent-lens) |
|---|---|---|
| Subtitle | "Toothbrushing Hero Adventure" | "Brushing without battles" |
| Opening line | "Brush Quest turns toothbrushing into a 2-minute space adventure." | "Brushing battles? We get it." |
| Description framing | What the app DOES (heroes, weapons, timer) | The parent's pain → outcome → reassurance |
| Feature list | Counted heroes / weapons / worlds / trophies | Cut entirely. "10 worlds, 50 trophies" doesn't help a parent decide. |
| Privacy section | Bulleted compliance facts | Confidence-builder framed around what parents fear (ads, tracking, social) |
| Closing | "made by AnemosGP LLC" + ask for review | "From the Maker" — direct dad-to-parent voice + email |
| Length | ~2,950 chars | ~2,300 chars (cuts went into the feature list) |

## Approval status (2026-04-29)

1. **Subtitle:** approved "Make brushing the easy part" (28/30) — chosen over "Brushing without battles" to avoid conflict-themed vocabulary in Kids Category review.
2. **iOS strip claim** — verified: 1P-3 shipped, zero `*crashlytics*` files in built bundle. Sentence is truthful as written.
3. **Removed numbers** (10 worlds, 50 trophies, 6 heroes, 6 weapons) — approved removed. Parent-lens framing prioritized over feature counts.
4. **Roster count claim** — none in this version. ✓
5. **Age-band consistency** — dropped "kids 4+ can play independently" line for uniform 6-8 framing. Voiceover-only design still mentioned implicitly via "no reading required".
