import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Lets the daily reminder show even while the app is open.
    UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    // Tells the app the name of the space it shares with its widgets
    // (lib/device/native_device.dart, LanguageWidgets/AppGroup.swift).
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "LanguageLibraryDevice") {
      let channel = FlutterMethodChannel(name: "langlib/device", binaryMessenger: registrar.messenger())
      channel.setMethodCallHandler { call, result in
        switch call.method {
        case "appGroup": result(AppGroup.id)
        default: result(FlutterMethodNotImplemented)
        }
      }
    }
  }
}
