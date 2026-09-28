import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var iconChannel: FlutterMethodChannel?
  private var iconChangePending = false
  private var appearanceChannel: FlutterMethodChannel?
  private var appearanceObservers: [NSObjectProtocol] = []
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let glassRegistrar = engineBridge.applicationRegistrar
    glassRegistrar.register(
      NativeGlassFactory(messenger: glassRegistrar.messenger(), prefix: "org.tblite.flutter"),
      withId: "org.tblite.flutter/glass"
    )
    let channel = FlutterMethodChannel(
      name: "org.tblite.flutter/app_icons",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    iconChannel = channel
    let appearance = FlutterMethodChannel(
      name: "org.tblite.flutter/appearance",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    appearanceChannel = appearance
    appearance.setMethodCallHandler { [weak self] call, result in
      guard call.method == "settings" else {
        result(FlutterMethodNotImplemented)
        return
      }
      result(self?.appearanceSettings() ?? [:])
    }
    for observer in appearanceObservers {
      NotificationCenter.default.removeObserver(observer)
    }
    appearanceObservers = [
      UIAccessibility.reduceTransparencyStatusDidChangeNotification,
      UIAccessibility.reduceMotionStatusDidChangeNotification
    ].map { notification in
      NotificationCenter.default.addObserver(forName: notification, object: nil, queue: .main) { [weak self] _ in
        guard let self = self else { return }
        self.appearanceChannel?.invokeMethod("changed", arguments: self.appearanceSettings())
      }
    }
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else {
        result(FlutterError(code: "unavailable", message: "Icon service unavailable.", details: nil))
        return
      }
      self.handleIconCall(call, result: result)
    }
  }

  private func appearanceSettings() -> [String: Bool] {
    [
      "reduceTransparency": UIAccessibility.isReduceTransparencyEnabled,
      "reduceMotion": UIAccessibility.isReduceMotionEnabled
    ]
  }

  deinit {
    for observer in appearanceObservers {
      NotificationCenter.default.removeObserver(observer)
    }
  }

  private func handleIconCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let application = UIApplication.shared
    let icons = ["blue": "AppIconBlue", "dark": "AppIconDark"]
    switch call.method {
    case "supported":
      result(application.supportsAlternateIcons)
    case "current":
      result(icons.first { $0.value == application.alternateIconName }?.key ?? "default")
    case "set":
      guard let choice = call.arguments as? String,
            choice == "default" || icons[choice] != nil else {
        result(FlutterError(code: "invalid_icon", message: "Unknown icon choice.", details: nil))
        return
      }
      guard application.supportsAlternateIcons else {
        result(FlutterError(code: "unsupported", message: "Alternate icons are unavailable.", details: nil))
        return
      }
      guard !iconChangePending else {
        result(FlutterError(code: "busy", message: "An icon change is already pending.", details: nil))
        return
      }
      let name = icons[choice]
      if application.alternateIconName == name {
        result(nil)
        return
      }
      iconChangePending = true
      application.setAlternateIconName(name) { [weak self] error in
        DispatchQueue.main.async {
          self?.iconChangePending = false
          if error != nil {
            result(FlutterError(code: "icon_change_failed", message: "The system could not change the app icon.", details: nil))
          } else {
            result(nil)
          }
        }
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
