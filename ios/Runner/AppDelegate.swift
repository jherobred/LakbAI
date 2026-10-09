import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    // Reports RAM so the app can pick a model size the phone can actually run.
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "KontrataDevice") {
      let channel = FlutterMethodChannel(name: "kontrata/device", binaryMessenger: registrar.messenger())
      channel.setMethodCallHandler { call, result in
        guard call.method == "getDeviceInfo" else {
          result(FlutterMethodNotImplemented)
          return
        }
        let totalMb = Int(ProcessInfo.processInfo.physicalMemory / (1024 * 1024))
        result([
          "totalMb": totalMb,
          "availMb": totalMb / 2,
          "isLowRam": totalMb < 3500,
          "platform": "ios",
          "sdkInt": 0,
          "model": UIDevice.current.model + " iOS " + UIDevice.current.systemVersion,
        ])
      }
    }
  }
}
