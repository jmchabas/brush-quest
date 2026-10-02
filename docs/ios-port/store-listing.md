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

**`A brushing routine without the bargaining. Built by a dad for his own kids — now shared with families tired of the nightly negotiation. No ads. No tracking.`**

Count: 156/170 ✓

## Description (≤4000 characters)

```
Brushing battles? We get it.

Brush Quest is a guided toothbrushing game made by a dad for his own kids - and shared with other families tired of the nightly negotiations ;-)

The goal: a brushing habit that sticks, without you playing the bad guy every night. All built for kids (no ads, no tracking).

------------------------------------
WHAT PARENTS GET
------------------------------------
• A brushing routine that doesn't need negotiating. The app sets the pace; you don't. You choose the length in parent Settings (up to 2 minutes).
• Every part of the mouth. A picture shows your child which of the 6 areas to brush next, and a voice tells them when to switch.
• An optional motion camera. Turn it on in parent Settings and the front camera picks up movement while your child brushes, so the hero's attacks keep pace with their brushing. It stays off until you switch it on, and nothing is recorded, saved or sent.
• Habit built in. Every session ends with a treasure chest, and brushing is how they capture cavity monsters for their growing collection.
• Cloud backup if you want progress to follow them (parent-only, behind a math problem).
• Works fully offline. No account required to use the app.
• Designed for ages 6-8. Younger and older siblings can join in too.

------------------------------------
WHAT YOUR CHILD SEES
------------------------------------
• A fun, entertaining experience: heroes they pick, gears they choose, and new worlds to discover
• A friendly voice that guides them step by step - no reading needed.
• Treasures and cavity monsters to collect.

Brushing time flies by!

------------------------------------
PRIVACY, IN PLAIN WORDS
------------------------------------
Brush Quest is submitted to the Apple Kids Category. We made deliberate choices to align with that:
• No advertising. No advertising SDKs of any kind.
• No analytics or crash-reporting code in the iPhone app at all.
• No App Tracking Transparency prompt - because we don't track.
• Sign-in is optional and behind a parental gate. Children cannot create accounts, link to social services, or follow external links.
• No social features, no chat, no in-app purchases, no subscriptions.

Plain-English privacy policy: https://brushquest.app/privacy-policy.html

------------------------------------
FROM THE MAKER
------------------------------------
I built Brush Quest for my own kids because I was tired of fighting them about brushing every night. It's free. It's ad-free. It's the kind of app I'd want on my own children's devices.

If it's helping at your house, I'd love to hear about it.

Jim
support@brushquest.app
AnemosGP LLC
```

Count: 2,645 / 4,000 ✓ (v29 accuracy pass 2026-10-01; v3 final — Jim's tightening 2026-05-09: punchier What-Parents-Get bullets, kids' section converted to bullets, "All built for kids (no ads, no tracking)" up top, ASCII dividers + hyphens for App Store validator compliance).

## Keywords (≤100 characters, comma-separated, NO spaces around commas)

**`toothbrushing,brushing,kids habit,dental,parents,routine,bedtime,family,hygiene,timer,teeth,health`**

Count: 98/100 ✓
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

## Approval status (2026-10-01, v29)

Jim approved all v29 listing corrections (accuracy pass: "2 minutes" → "up to 2 minutes, you choose"; camera is optional and never proof; no unproven promises; one narrator voice; 6 zones, not quadrants; iPhone privacy wording; keyword "teeth" replaces "toddler"). He sees the final text before it is pasted into App Store Connect. Age rating: Cartoon Violence = None (Jim's decision 2026-10-01).

## Approval status (2026-04-29)

1. **Subtitle:** approved "Make brushing the easy part" (28/30) — chosen over "Brushing without battles" to avoid conflict-themed vocabulary in Kids Category review.
2. **iOS strip claim** — WRONG as originally verified: builds 21-26 statically linked GoogleAppMeasurement, APMIdentity and Crashlytics into `Runner` (no separate `*crashlytics*` files, so the file check missed it). Fixed in v29 by vendoring the plugins without iOS code; the line now reads "No analytics or crash-reporting code in the iPhone app at all." Only submit a build that passes `scripts/check_ios_kids_binary.sh`.
3. **Removed numbers** (10 worlds, 50 trophies, 6 heroes, 6 weapons) — approved removed. Parent-lens framing prioritized over feature counts.
4. **Roster count claim** — none in this version. ✓
5. **Age-band consistency** — dropped "kids 4+ can play independently" line for uniform 6-8 framing. Voiceover-only design still mentioned implicitly via "no reading required".
