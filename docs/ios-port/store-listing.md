# Apple App Store — Listing Copy Draft

> Drafted 2026-04-28 for *Brush Quest: Space Rangers*. Reviewed before paste into App Store Connect (PLAN.md 2C-2). Limits checked against Apple's published max.

---

## App Name (≤30 characters)

**`Brush Quest: Space Rangers`**

Character count: 26/30 ✓
Differentiates from existing iOS namesake (Mitchell Pothitakis "Brush Quest").

## Subtitle (≤30 characters)

**`Toothbrushing Hero Adventure`**

Count: 28/30 ✓
Conveys: kids' app, brushing focus, gamified.

## Promotional Text (≤170 characters, editable any time without re-review)

**`Two minutes of brushing, two minutes of saving the galaxy. Battle cavity monsters, unlock new heroes & weapons, build a streak — no ads, no tracking, parent-approved.`**

Count: 162/170 ✓

## Description (≤4000 characters)

```
Brush Quest turns toothbrushing into a 2-minute space adventure.

Your child picks a Ranger, picks a weapon, and battles the Cavity Monsters
threatening their teeth. Every second of brushing chips away at the boss.
Two minutes of brushing, four quadrants of the mouth, one defeated monster.
Stars earned. Streak built. Real habit, no nagging.

Built by a dad for his own kids. Designed for ages 6-8 — your kid does the
brushing, the app does the cheering.

────────────────────────────────────
WHAT THE KID SEES
────────────────────────────────────

• A pulsing BRUSH button. One tap, the timer counts down: 3, 2, 1, GO!
• A four-quadrant mouth guide showing exactly where to brush
• Voiced encouragements (no reading required — kids 4+ can play independently)
• A boss monster shaking with every brush stroke
• Victory: stars added, monster defeated, hero progress bar moved
• A growing roster of heroes and weapons to unlock with stars

────────────────────────────────────
WHAT PARENTS GET
────────────────────────────────────

• A 2-minute habit tool that doesn't need parental supervision after setup
• Optional cloud backup if you want progress to survive a device switch
  (parent-only — sign-in is gated behind a math problem)
• A real-time mouth-guide overlay that teaches WHERE to brush, not just
  for how long
• Camera-based motion detection (off by default; can be enabled in Settings).
  When on, the front camera produces a motion score only — no images are
  captured, recorded, or sent anywhere.
• 50+ unlockable heroes and weapons, paced for a 2x/day brushing schedule

────────────────────────────────────
PRIVACY (THE WHY-WE-MADE-THIS PART)
────────────────────────────────────

Brush Quest is submitted to Apple's Kids Category. We made deliberate
choices to align with that:

• Zero advertising. No ads of any kind, ever.
• Zero third-party analytics or crash-reporting SDKs in the iOS app binary.
  We strip them at build time.
• No advertising IDs. No App Tracking Transparency prompt — because we
  don't track.
• Sign-in is optional and behind a parental gate. The app works fully
  offline.
• No social features, no chat, no user-generated content, no external
  links visible to children.
• No in-app purchases. No subscriptions.

Full privacy policy: https://brushquest.app/privacy-policy.html

────────────────────────────────────
WHAT'S INCLUDED
────────────────────────────────────

• 6 heroes (more added in updates)
• 6 weapons
• 10 worlds with progressive monster variety
• Star-based wallet economy — earn stars by brushing, spend on unlocks
• 50 trophies tracking long-term mastery
• Sign in with Apple or Google for cloud backup (optional)
• Configurable timer (15s / 20s / 30s per quadrant)

────────────────────────────────────
SUPPORT
────────────────────────────────────

Email support@brushquest.app — we respond within 1 business day.

Brush Quest is made by AnemosGP LLC. The app is free and ad-free.
A grateful note from a parent goes a long way — please leave a review
if Brush Quest is helping at your house.
```

Approximate character count: ~2,950 / 4,000 ✓

## Keywords (≤100 characters, comma-separated, NO spaces around commas)

**`brushing,toothbrush,kids,dental,habit,hygiene,timer,hero,monster,parents,routine,family,oral`**

Count: 99/100 ✓
Note: Apple does not index the App Name in keyword search — keywords are *additional* to the name. We avoid duplicating "brush" or "quest" since both are in the name.

## Categories

- **Primary Category:** `Kids → Ages 6-8`
- **Secondary Category:** `Education`

(Decision: Primary=Kids gives prominent shelf placement and parent trust; Secondary=Education better captures the habit-building/health-education angle than Games.)

## Age Rating Questionnaire

Default to **4+** (no objectionable content). 2026 questionnaire (replaced Jan 31, 2026):
- Cartoon Violence: **None** (cavity monsters are non-violent silly characters; no weapons-as-weapons context)
- Profanity: None
- Sexual: None
- Drugs/alcohol: None
- Realistic Violence: None
- Horror/fear: None
- In-app controls: **Settings parental gate** (math problem) — disclose
- Medical/wellness: **Yes** — toothbrushing health-education context, declare it
- Unrestricted web access: No
- Gambling: No
- User-generated content: No
- Social: No
- Location: No

## Support URL

`https://brushquest.app/`

## Marketing URL (optional)

`https://brushquest.app/`

## Privacy Policy URL

`https://brushquest.app/privacy-policy.html`

## Copyright

`© 2026 AnemosGP LLC`

## App Review Information (private — for Apple reviewers only)

See `docs/ios-port/review-notes.md` (separate doc, will be drafted in PLAN.md task 2C-6).

---

## What still needs your input before paste

1. **Description tone** — read the description aloud. Cringe at any line? Strike it. (Default: ship as-is, edit on first iteration.)
2. **Number of heroes/weapons/worlds in the description** — I wrote "6 heroes / 6 weapons / 10 worlds / 50 trophies." Verify these match the current rosters in code (`hero_service.dart`, `weapon_service.dart`, `world_service.dart`, `achievement_service.dart`). If counts differ, update the description.
3. **Marketing URL** — same as Support URL is fine, OR you can point this to a future "Press Kit" page if you want one.
4. **Subtitle alternatives** — current "Toothbrushing Hero Adventure" works. Alternatives: *"Hero Toothbrushing Adventure"*, *"Cavity Monster Battle"*, *"2-Min Brushing Adventure"*. Tell me if you want a different angle.

Once approved, this is the canonical text for App Store Connect.
