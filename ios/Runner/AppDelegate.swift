import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var securityChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let controller = window?.rootViewController as? FlutterViewController
    if let controller = controller {
      setupSecurityChannel(binaryMessenger: controller.binaryMessenger)
    }

    setupScreenCaptureObservers()

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }

  private func setupSecurityChannel(binaryMessenger: FlutterBinaryMessenger) {
    securityChannel = FlutterMethodChannel(name: "com.notify.app/security", binaryMessenger: binaryMessenger)
    securityChannel?.setMethodCallHandler { (call: FlutterMethodCall, result: @escaping FlutterResult) in
      switch call.method {
      case "isScreenCaptured":
        if #available(iOS 11.0, *) {
          result(UIScreen.main.isCaptured)
        } else {
          result(false)
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func setupScreenCaptureObservers() {
    // 1. Screenshot Detection (NSNotification.userDidTakeScreenshotNotification)
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(didTakeScreenshot),
      name: UIApplication.userDidTakeScreenshotNotification,
      object: nil
    )

    // 2. Screen Recording Detection (UIScreen.capturedDidChangeNotification -> UIScreen.main.isCaptured)
    if #available(iOS 11.0, *) {
      NotificationCenter.default.addObserver(
        self,
        selector: #selector(screenCapturedDidChange),
        name: UIScreen.capturedDidChangeNotification,
        object: nil
      )
    }
  }

  @objc private func didTakeScreenshot() {
    securityChannel?.invokeMethod("onScreenshotDetected", arguments: [
      "type": "screenshot",
      "platform": "ios",
      "timestamp": Date().timeIntervalSince1970
    ])
  }

  @objc private func screenCapturedDidChange() {
    if #available(iOS 11.0, *) {
      if UIScreen.main.isCaptured {
        securityChannel?.invokeMethod("onScreenRecordingDetected", arguments: [
          "type": "screen_recording",
          "platform": "ios",
          "timestamp": Date().timeIntervalSince1970
        ])
      }
    }
  }

  deinit {
    NotificationCenter.default.removeObserver(self)
  }
}

