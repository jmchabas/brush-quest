---
name: "source-command-gtm-prep"
description: "Migrated source command `gtm-prep`"
---

# source-command-gtm-prep

Use this skill when the user asks to run the migrated source command `gtm-prep`.

## Command Template

You are running **GTM Prep** — generating go-to-market artifacts for Brush Quest app store submissions.

## SCOPE: This is a WRITING task. You generate drafts for Jim to review. You do NOT modify app code, UI, or any .dart files.

## Steps:

1. **Read context** (parallel):
   - `STATUS.md` — current blockers, app status
   - `STRATEGY.md` — product positioning, target audience
   - `AGENTS.md` — landing page copy rules (apply to store listings too)
   - `lib/services/hero_service.dart` — current hero roster for feature descriptions
   - `lib/services/weapon_service.dart` — current weapon roster
   - `lib/services/world_service.dart` — current world roster
   - `git log --oneline -20` — recent feature work

2. **Generate/update these artifacts** (create files in `marketing/` directory):

   a. **`marketing/play-store-listing.md`** — Google Play Store listing:
      - Title (30 char max)
      - Short description (80 char max)
      - Full description (4000 char max)
      - Feature graphic text suggestions
      - Keywords/tags
      - Content rating justification (COPPA-compliant, no ads, no IAP yet)

   b. **`marketing/amazon-appstore-listing.md`** — Amazon Appstore listing:
      - Same structure as Play Store but adapted for Amazon's format
      - Note any Amazon-specific requirements

   c. **`marketing/screenshot-captions.md`** — Suggested captions for each screenshot:
      - Home screen, brushing screen, victory screen, hero shop, world map
      - Short, parent-focused (what does this screen DO for my kid?)

3. **Apply copy rules from AGENTS.md**:
   - Write from parent's lived experience, not product features
   - Never state commitments the codebase can't guarantee
   - Kill filler — every line earns its place
   - The child is the user, the parent is the buyer

4. **Review checklist** (self-evaluate before presenting):
   - [ ] Every factual claim true given the codebase?
   - [ ] Would I cringe reading this on someone else's listing?
   - [ ] Does it pass the "tired parent at 9pm" test?
   - [ ] No COPPA violations in copy (don't mention camera tracking, don't claim "monitoring")
   - [ ] No pricing claims unless confirmed in STRATEGY.md

5. **Present to Jim** with:
   - The drafts
   - Any open questions (e.g., "Should we mention the camera feature? It could concern parents.")
   - Suggested next step: "Review these, then submit to Amazon Appstore (not blocked on D-U-N-S)"
