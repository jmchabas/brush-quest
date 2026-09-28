import AVFoundation
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  // Native -> Dart AVAudioSession events (see AudioService
  // .listenForIosAudioSessionEvents). Dart only listens; it never invokes
  // methods on this channel. Created once the implicit engine exists, so an
  // event that arrives before that is simply dropped.
  private static let audioSessionChannelName = "brushquest/audio_session"
  private var audioSessionChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    setupAudioSessionObservers()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    audioSessionChannel = FlutterMethodChannel(
      name: AppDelegate.audioSessionChannelName,
      binaryMessenger: engineBridge.applicationRegistrar.messenger())
  }

  // Phone calls, Siri, alarms, FaceTime, etc. interrupt the AVAudioSession
  // and the system pauses every AVPlayer. The audioplayers plugin observes
  // none of this, so without these observers the voice in flight never
  // completes (the Dart voice pump stalls) and music stays silent while Dart
  // still believes it is playing. Headphones/AirPods disconnecting pause the
  // players the same way; a media-services reset invalidates the session.
  private func setupAudioSessionObservers() {
    let center = NotificationCenter.default
    let session = AVAudioSession.sharedInstance()
    center.addObserver(
      self,
      selector: #selector(handleAudioInterruption(_:)),
      name: AVAudioSession.interruptionNotification,
      object: session
    )
    center.addObserver(
      self,
      selector: #selector(handleRouteChange(_:)),
      name: AVAudioSession.routeChangeNotification,
      object: session
    )
    center.addObserver(
      self,
      selector: #selector(handleMediaServicesReset(_:)),
      name: AVAudioSession.mediaServicesWereResetNotification,
      object: session
    )
  }

  @objc private func handleAudioInterruption(_ notification: Notification) {
    guard let info = notification.userInfo,
          let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
          let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
      return
    }
    switch type {
    case .began:
      sendAudioSessionEvent("interruptionBegan")
    case .ended:
      var shouldResume = false
      if let optionsValue = info[AVAudioSessionInterruptionOptionKey] as? UInt {
        let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
        shouldResume = options.contains(.shouldResume)
      }
      // iOS leaves the session deactivated after the interruption; without
      // this all later audio (voice, SFX, music) silently fails.
      if shouldResume {
        try? AVAudioSession.sharedInstance().setActive(true)
      }
      sendAudioSessionEvent("interruptionEnded", ["shouldResume": shouldResume])
    @unknown default:
      break
    }
  }

  @objc private func handleRouteChange(_ notification: Notification) {
    guard let info = notification.userInfo,
          let reasonValue = info[AVAudioSessionRouteChangeReasonKey] as? UInt,
          let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue),
          reason == .oldDeviceUnavailable else {
      return
    }
    // Headphones unplugged / AirPods gone: the system has paused the players.
    sendAudioSessionEvent("routeLost")
  }

  @objc private func handleMediaServicesReset(_ notification: Notification) {
    // The media server restarted: the session lost its configuration.
    // Re-apply what audioplayers sets at startup (.playback, no options).
    let session = AVAudioSession.sharedInstance()
    try? session.setCategory(.playback, options: [])
    try? session.setActive(true)
    sendAudioSessionEvent("mediaServicesReset")
  }

  // AVAudioSession notifications can arrive on a background thread; Flutter
  // channels are main-thread only.
  private func sendAudioSessionEvent(_ method: String, _ arguments: [String: Any]? = nil) {
    DispatchQueue.main.async {
      self.audioSessionChannel?.invokeMethod(method, arguments: arguments)
    }
  }
}
