import AVKit

extension String {
  func deletingPrefix(_ prefix: String) -> String {
    guard self.hasPrefix(prefix) else {
      return self
    }
    return String(self.dropFirst(prefix.count))
  }
}

// BRUSH QUEST PATCH (C5): AVFoundation callbacks (KVO, notifications, seek
// completion handlers) are not guaranteed to arrive on the main thread, but
// player state and FlutterEventSink must only be touched there. Runs inline
// when already on main, so main-thread callers keep upstream ordering.
func runOnMainThread(_ block: @escaping () -> Void) {
  if Thread.isMainThread {
    block()
  } else {
    DispatchQueue.main.async(execute: block)
  }
}

func toCMTime(millis: Int) -> CMTime {
  return toCMTime(millis: Float(millis))
}

func toCMTime(millis: Double) -> CMTime {
  return toCMTime(millis: Float(millis))
}

func toCMTime(millis: Float) -> CMTime {
  return CMTimeMakeWithSeconds(Float64(millis) / 1000, preferredTimescale: Int32(NSEC_PER_SEC))
}

func fromCMTime(time: CMTime) -> Int {
  guard CMTIME_IS_NUMERIC(time) else {
    return 0
  }
  let seconds: Float64 = CMTimeGetSeconds(time)
  let milliseconds: Int = Int(seconds * 1000)
  return milliseconds
}

class TimeObserver {
  let player: AVPlayer
  let observer: Any

  init(
    player: AVPlayer,
    observer: Any
  ) {
    self.player = player
    self.observer = observer
  }
}
