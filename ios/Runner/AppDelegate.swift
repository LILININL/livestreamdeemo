import AVFoundation
import AVKit
import Flutter
import UIKit

// Minimal in-file PiP controller to avoid Xcode target membership issues
class PiPController: NSObject, AVPictureInPictureControllerDelegate {
  static let shared = PiPController()

  private var player: AVPlayer?
  private var playerLayer: AVPlayerLayer?
  private var pipController: AVPictureInPictureController?
  private var autoEnable = false
  private var hostView: UIView?

  override private init() { super.init() }

  func configureAudioSession() {
    do {
      let session = AVAudioSession.sharedInstance()
      try session.setCategory(
        .playback, mode: .moviePlayback, options: [.allowAirPlay, .mixWithOthers])
      try session.setActive(true)
    } catch {
      NSLog("PiPController: Failed to set audio session: \(error)")
    }
  }

  func setStreamUrl(_ urlString: String) {
    guard let url = URL(string: urlString) else {
      NSLog("PiPController: Invalid URL: \(urlString)")
      return
    }

    let item = AVPlayerItem(url: url)
    let newPlayer = AVPlayer(playerItem: item)
    newPlayer.automaticallyWaitsToMinimizeStalling = true
    self.player = newPlayer

    let layer = AVPlayerLayer(player: newPlayer)
    layer.videoGravity = .resizeAspect
    self.playerLayer = layer

    // Ensure player layer is in the view hierarchy
    DispatchQueue.main.async { [weak self] in
      guard let self = self else { return }
      if self.hostView == nil {
        let v = UIView(frame: CGRect(x: 0, y: 0, width: 1, height: 1))
        v.isHidden = true
        self.hostView = v
        if #available(iOS 13.0, *) {
          if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
            let win = scene.windows.first,
            let rootView = win.rootViewController?.view
          {
            rootView.addSubview(v)
          }
        } else {
          if let rootView = UIApplication.shared.delegate?.window??.rootViewController?.view {
            rootView.addSubview(v)
          }
        }
      }
      self.playerLayer?.frame = self.hostView?.bounds ?? .zero
      if let host = self.hostView, let pl = self.playerLayer, pl.superlayer == nil {
        host.layer.addSublayer(pl)
      }
    }

    if #available(iOS 13.0, *) {
      if AVPictureInPictureController.isPictureInPictureSupported() {
        self.pipController = AVPictureInPictureController(playerLayer: layer)
        self.pipController?.delegate = self
        if #available(iOS 14.2, *) {
          self.pipController?.canStartPictureInPictureAutomaticallyFromInline = true
        }
      } else {
        NSLog("PiPController: PiP not supported on this device.")
      }
    } else {
      NSLog("PiPController: iOS version < 13.0, PiP unsupported")
    }
  }

  func enableAuto(_ enabled: Bool) { self.autoEnable = enabled }

  func startPiP() {
    guard let pip = pipController else {
      NSLog("PiPController: startPiP called but pipController is nil")
      return
    }
    if player?.rate == 0 { player?.play() }
    if pip.isPictureInPicturePossible && !pip.isPictureInPictureActive {
      pip.startPictureInPicture()
    }
  }

  func stopPiP() {
    guard let pip = pipController else { return }
    if pip.isPictureInPictureActive { pip.stopPictureInPicture() }
  }

  // App lifecycle hooks
  func onWillResignActive() { if autoEnable { startPiP() } }
  func onDidBecomeActive() { stopPiP() }

  // AVPictureInPictureControllerDelegate (optional logs)
  func pictureInPictureControllerWillStartPictureInPicture(
    _ controller: AVPictureInPictureController
  ) { NSLog("PiPController: PiP will start") }
  func pictureInPictureControllerDidStartPictureInPicture(
    _ controller: AVPictureInPictureController
  ) { NSLog("PiPController: PiP did start") }
  func pictureInPictureController(
    _ controller: AVPictureInPictureController, failedToStartPictureInPictureWithError error: Error
  ) { NSLog("PiPController: failed: \(error)") }
  func pictureInPictureControllerWillStopPictureInPicture(
    _ controller: AVPictureInPictureController
  ) { NSLog("PiPController: will stop") }
  func pictureInPictureControllerDidStopPictureInPicture(_ controller: AVPictureInPictureController)
  { NSLog("PiPController: did stop") }
}
@main
@objc class AppDelegate: FlutterAppDelegate {
  private var pipChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Register Flutter plugins
    GeneratedPluginRegistrant.register(with: self)


    // Let FlutterAppDelegate complete engine/window setup first
    let res = super.application(application, didFinishLaunchingWithOptions: launchOptions)

    // Configure audio session for playback/PiP
    PiPController.shared.configureAudioSession()

    // Create MethodChannel using Flutter registry (robust, view-controller independent)
    if let registrar = self.registrar(forPlugin: "pip_ios") {
      let channel = FlutterMethodChannel(name: "pip_ios", binaryMessenger: registrar.messenger())
      self.pipChannel = channel
      NSLog("AppDelegate: pip_ios channel registered")
      channel.setMethodCallHandler { call, result in
        switch call.method {
        case "setStreamUrl":
          if let args = call.arguments as? [String: Any], let url = args["url"] as? String {
            NSLog("AppDelegate: setStreamUrl -> \(url)")
            PiPController.shared.setStreamUrl(url)
            result(nil)
          } else {
            result(FlutterError(code: "bad_args", message: "Missing url", details: nil))
          }
        case "enableAutoPip":
          if let args = call.arguments as? [String: Any], let enabled = args["enabled"] as? Bool {
            NSLog("AppDelegate: enableAutoPip -> \(enabled)")
            PiPController.shared.enableAuto(enabled)
            result(nil)
          } else {
            result(FlutterError(code: "bad_args", message: "Missing enabled", details: nil))
          }
        case "startPiP":
          NSLog("AppDelegate: startPiP called")
          PiPController.shared.startPiP()
          result(nil)
        case "stopPiP":
          NSLog("AppDelegate: stopPiP called")
          PiPController.shared.stopPiP()
          result(nil)
        default:
          result(FlutterMethodNotImplemented)
        }
      }
    } else {
      NSLog("AppDelegate: Failed to obtain registrar for pip_ios")
    }

    return res
  }

  override func applicationWillResignActive(_ application: UIApplication) {
    super.applicationWillResignActive(application)
    PiPController.shared.onWillResignActive()
  }

  override func applicationDidBecomeActive(_ application: UIApplication) {
    super.applicationDidBecomeActive(application)
    PiPController.shared.onDidBecomeActive()
  }
}
