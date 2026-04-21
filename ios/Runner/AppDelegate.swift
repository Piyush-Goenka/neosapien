import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var mediaSaver: NativeMediaSaverImpl?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    // Register the Bonus E native-save Pigeon host API.
    if let controller = window?.rootViewController as? FlutterViewController {
      let saver = NativeMediaSaverImpl()
      mediaSaver = saver
      NativeMediaSaverHostApiSetup.setUp(
        binaryMessenger: controller.binaryMessenger,
        api: saver
      )
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
