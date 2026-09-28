# Brush Quest vendored copy of `audioplayers_darwin` 6.3.0

> **Why this lives here.** darwin 6.4.0+ has a Swift continuation leak that
> hangs every voice on iOS, so the app pins 6.3.0. 6.3.0 (and upstream 6.5.x)
> also has timing bugs that hit Brush Quest's back-to-back voice queue and
> looping music. Upstream is frozen for us, so the source is vendored and
> patched here. Android never uses this package (`audioplayers_android` stays
> the hosted 5.2.1; `test/audio/audioplayers_pin_test.dart` pins it).
>
> **Base:** copied verbatim from
> `~/.pub-cache/hosted/pub.dev/audioplayers_darwin-6.3.0/` (commit
> "build(ios): vendor audioplayers_darwin 6.3.0 verbatim"). `version:` stays
> `6.3.0`. See the diff against that commit for every change.
>
> Every patched spot is marked `BRUSH QUEST PATCH (<id>)` in the Swift and
> logs with the `[audioplayers_darwin][BQ]` NSLog prefix when a guard fires.
> Background: `ios-audio-diagnosis.md` / `ios-audio-adversarial-review.md`
> (release/v29 investigation).

## Patches

| id | File | What |
|----|------|------|
| N1 | `WrappedMediaPlayer.swift` | `onSoundComplete` remembers the finished `AVPlayerItem`; its deferred rewind closure skips `release()`/loop `resume()` if the player's current item is no longer that item. The generic `seek` handler only pauses when the seeked item is still current. Fixes the delayed release that paused/removed the next queued voice. |

## Upgrading

Copy the new upstream version from the pub cache over this directory, re-apply
each patch above (search `BRUSH QUEST PATCH`), keep this file, run
`cd ios && pod install`, `flutter build ios --release --no-codesign`,
`scripts/check_ios_kids_binary.sh`, and the simulator audio test
(`integration_test/ios_audio_real_test.dart`). Do not move to 6.4.0-6.5.x
without confirming the continuation leak is fixed upstream.
