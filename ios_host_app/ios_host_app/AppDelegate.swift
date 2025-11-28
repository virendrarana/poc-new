import UIKit
import Flutter
import FlutterPluginRegistrant

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    lazy var flutterEngine = FlutterEngine(name: "universal_engine")

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {

        print("🚀 AppDelegate.didFinishLaunchingWithOptions")
        flutterEngine.run()
        print("✅ Flutter engine started")
        GeneratedPluginRegistrant.register(with: flutterEngine)
        print("✅ Plugins registered")

        // 🔗 Listen for KYC events from Flutter SDK
        let channel = FlutterMethodChannel(
            name: "universal_experience_sdk/events",
            binaryMessenger: flutterEngine.binaryMessenger
        )

        channel.setMethodCallHandler { call, result in
            if call.method == "onKycEvent" {
                guard let args = call.arguments as? [String: Any] else {
                    result(nil)
                    return
                }

                let type = args["type"] as? String ?? "unknown"
                let step = args["step"] as? String
                let message = args["message"] as? String ?? ""

                let tsMillis = (args["timestamp"] as? Double)
                    ?? Date().timeIntervalSince1970 * 1000
                let timestamp = Date(timeIntervalSince1970: tsMillis / 1000.0)

                let metaDict = args["meta"] as? [String: Any]
                let metaString = metaDict?.description

                let entry = KycLogEntry(
                    type: type,
                    step: step,
                    message: message,
                    meta: metaString,
                    timestamp: timestamp
                )

                KycLogStore.shared.add(entry)
                result(nil)
            } else {
                result(FlutterMethodNotImplemented)
            }
        }

        return true
    }
}
