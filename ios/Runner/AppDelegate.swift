import UIKit
import Flutter
import AVFoundation

@main
@objc class AppDelegate: FlutterAppDelegate {
  private let channelName = "wave_audio"
  private var audioChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    // Ensure audio session category is set to playAndRecord early (best-effort).
    // Do NOT activate here permanently — we activate on-demand from Dart.
    do {
      try AVAudioSession.sharedInstance().setCategory(.playAndRecord, options: [.allowBluetooth, .allowBluetoothA2DP, .defaultToSpeaker, .allowAirPlay])
    } catch {
      print("AppDelegate: failed to set initial audio category: \(error)")
    }

    guard let controller = window?.rootViewController as? FlutterViewController else {
      return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    audioChannel = FlutterMethodChannel(name: channelName, binaryMessenger: controller.binaryMessenger)

    audioChannel?.setMethodCallHandler { [weak self] (call, result) in
      guard let self = self else { return }
      switch call.method {
      case "getAudioRoutes":
        result(self.getAudioRoutes())
      case "setAudioRoute":
        if let args = call.arguments as? [String:Any], let id = args["id"] as? String {
          self.setAudioRoute(id: id)
          result(nil)
        } else {
          result(FlutterError(code: "bad_args", message: "Missing id", details: nil))
        }
      case "activateAudioSession":
        do {
          try self.configureAudioSession()
          result(true)
        } catch {
          result(FlutterError(code: "audio", message: "\(error)", details: nil))
        }
      case "deactivateAudioSession":
        do {
          // Try to deactivate (best-effort). Use option notifyOthersOnDeactivation to behave nicely with other audio apps.
          try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
          result(true)
        } catch {
          result(FlutterError(code: "audio", message: "deactivate failed: \(error)", details: nil))
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    // notify Dart side when audio route changes (e.g. BT connect/disconnect)
    NotificationCenter.default.addObserver(self, selector: #selector(handleRouteChange(_:)), name: AVAudioSession.routeChangeNotification, object: nil)
    NotificationCenter.default.addObserver(self, selector: #selector(handleInterruption(_:)), name: AVAudioSession.interruptionNotification, object: nil)

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  @objc func handleRouteChange(_ notification: Notification) {
    guard let channel = audioChannel else { return }
    let routes = getAudioRoutes()
    channel.invokeMethod("onAudioRoutesChanged", arguments: routes)
  }

  @objc func handleInterruption(_ notification: Notification) {
    guard let channel = audioChannel else { return }
    guard let info = notification.userInfo as? [String: Any] else { return }
    // forward interruption info to Dart (type + option if available)
    channel.invokeMethod("onAudioInterruption", arguments: info)
  }

  func getAudioRoutes() -> [[String: String]] {
    let session = AVAudioSession.sharedInstance()
    var res: [[String: String]] = []

    // Virtual options for UI (UI can translate labels)
    res.append(["id":"speaker","label":"Speaker"])
    res.append(["id":"receiver","label":"Receiver"])

    for output in session.currentRoute.outputs {
      let id = output.uid ?? output.portType.rawValue
      let label = output.portName
      res.append(["id": id, "label": label])
    }
    return res
  }

  func configureAudioSession() throws {
    let session = AVAudioSession.sharedInstance()
    try session.setCategory(.playAndRecord, options: [.allowBluetooth, .allowBluetoothA2DP, .defaultToSpeaker])
    try session.setMode(.voiceChat)
    try session.setActive(true)
  }

  func setAudioRoute(id: String) {
    let session = AVAudioSession.sharedInstance()
    do {
      try configureAudioSession()
      if id == "speaker" {
        try session.overrideOutputAudioPort(.speaker)
      } else if id == "receiver" {
        try session.overrideOutputAudioPort(.none)
      } else {
        // Let system choose for external (bluetooth / usb)
        try session.overrideOutputAudioPort(.none)
      }
    } catch {
      print("setAudioRoute error: \(error)")
    }
  }

  deinit {
    NotificationCenter.default.removeObserver(self, name: AVAudioSession.routeChangeNotification, object: nil)
    NotificationCenter.default.removeObserver(self, name: AVAudioSession.interruptionNotification, object: nil)
  }
}
