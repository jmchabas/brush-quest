# Z-1 + W-1 input: Apple App Store conflict — "Brush Quest" by Mitchell Pothitakis

**Captured:** 2026-04-28
**Source:** https://apps.apple.com/us/app/brush-quest/id6748761829
**iTunes Search API:** `curl 'https://itunes.apple.com/search?term=brush+quest&entity=software&country=us&limit=50'` (1 exact-name match returned)

---

## The conflicting app

| Field | Value |
|---|---|
| App name | **Brush Quest** (exact match) |
| Developer | Mitchell Pothitakis (individual, no LLC visible) |
| Bundle ID | `com.mitchellpothitakis.BrushQuest` |
| Category | Health & Fitness, age 4+ |
| Released | 2025-07-18 (~9 months before our launch) |
| Last update | 2025-07-18 (no updates since launch — likely abandoned or hobbyist) |
| Size | 2.1 MB |
| Price | Free, no ads, no IAP |
| Languages | English only |
| Platform | iOS 17.2+, macOS 14.2+ M1 |
| Rating | 5.0 / 5 from **1 rating** |
| URL | https://apps.apple.com/us/app/brush-quest/id6748761829 |
| Privacy | "Developer does not collect any data" |

## Functional overlap (severity assessment input)

This is **direct competitive overlap, not just name collision:**

| Feature | Their app | Our app |
|---|---|---|
| Concept | Gamified kids' toothbrushing | Gamified kids' toothbrushing |
| Age band | 4-10 | 3-12 |
| Companion characters | Dragon, Unicorn, Robot | Heroes (Bolt, Blaze, etc. — 50+ unlocks) |
| Timer mechanic | 2-minute timer, 6 zones | 2-minute timer, 4-6 zones (configurable) |
| Reward system | Stars + morning/evening bonuses | Stars + streak/pair bonuses, wallet+rank |
| Progress tracking | Interactive calendar | Dashboard + week activity card |
| Audio | Success sounds, animations | ElevenLabs voice, ducked music, brushing SFX |
| Educational | Video tutorials | Voice-guided + visual mouth guide |
| Theme | Generic fantasy companions | Space Rangers vs. Cavity Monsters |

**Verdict:** Same niche, same name, similar mechanics. We are functionally and visually more developed (LLC, professional listing, 121 MB content, 16 dev cycles, real tester program), but legally we're in their shadow on first-use grounds.

## Their apparent state (signal of abandonment)

- 1 rating in 9 months → very low traction
- No updates since launch → likely abandoned or part-time hobby
- 2.1 MB total → minimal content, single-developer effort
- No website footprint (no results in WebSearch for "Mitchell Pothitakis Brush Quest" beyond the App Store listing itself)
- "Developer does not collect any data" → no analytics, no marketing infrastructure
- Single individual developer, no apparent LLC

**Strategic implication:** The owner may be open to a buyout or graceful name release. He's not actively monetizing or marketing.
