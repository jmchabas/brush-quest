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
| H5 | `WrappedMediaPlayer.swift` | `stop` answers Dart exactly once right after `pause()` instead of when its rewind seek reports `finished`. A cancelled rewind no longer loses the reply (`await stop()` hung in loop mode), release mode no longer replies twice, and `release()`'s `stop { reset() }` can no longer reset a newer item late. The rewind itself still runs. |
| H3 | `WrappedMediaPlayer.swift` | Loop mode: a natural end is a wrap, not a completion. No `onComplete` is sent to Dart (upstream sent one per wrap, so Dart saw `completed` on a playing loop and restarted the music / reset its volume every ~2 min), and the loop resumes after the rewind whatever its `finished` flag says (upstream went silent if the rewind was cancelled), unless the player was paused/stopped meanwhile or the item replaced. Adds the private `seekThen(time:onDone:)` that always reports `finished`; public `seek(time:completer:)` keeps upstream's call-only-if-finished contract. |
| H6 | `WrappedMediaPlayer.swift` | A seek on an item that is not `.readyToPlay` yet (e.g. stop/interrupt while a voice loads) is parked in `pendingSeek` instead of calling `AVPlayerItem.seek(to:completionHandler:)`, which raises on some iOS versions. The status observer runs it once ready; a newer seek or `reset()` resolves it with `finished = false`. |
| C5 | all three Swift files | AVFoundation callbacks (status KVO, did-play-to-end notification, seek completion) and every `FlutterEventSink` call run on the main thread (`runOnMainThread` in `Utils.swift`: inline when already on main, so upstream ordering is kept). A callback that had to hop to main is dropped if its item was replaced meanwhile. |

## Upgrading

Copy the new upstream version from the pub cache over this directory, re-apply
each patch above (search `BRUSH QUEST PATCH`), keep this file, run
`cd ios && pod install`, `flutter build ios --release --no-codesign`,
`scripts/check_ios_kids_binary.sh`, and the simulator audio test
(`integration_test/ios_audio_real_test.dart`). Do not move to 6.4.0-6.5.x
without confirming the continuation leak is fixed upstream.
