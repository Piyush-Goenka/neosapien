import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var mediaSaver: NativeMediaSaverImpl?
  private var filePicker: NativeFilePickerImpl?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    if let controller = window?.rootViewController as? FlutterViewController {
      // Bonus E — native save (PHPhotoLibrary + share sheet).
      let saver = NativeMediaSaverImpl()
      mediaSaver = saver
      NativeMediaSaverHostApiSetup.setUp(
        binaryMessenger: controller.binaryMessenger,
        api: saver
      )

      // Bonus D — native file picker (UIDocumentPickerViewController).
      let picker = NativeFilePickerImpl()
      filePicker = picker
      NativeFilePickerHostApiSetup.setUp(
        binaryMessenger: controller.binaryMessenger,
        api: picker
      )
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
