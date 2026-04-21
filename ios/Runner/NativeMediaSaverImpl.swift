import Foundation
import Photos
import UIKit

/// iOS implementation of the Pigeon `NativeMediaSaverHostApi` contract.
///
/// Behavior:
/// - `image/*` and `video/*` → `PHPhotoLibrary.performChanges` saves into the
///   Photos library (requires `NSPhotoLibraryAddUsageDescription` in Info.plist,
///   already declared).
/// - Any other MIME → presents the system share sheet (`UIActivityViewController`)
///   with the local file so the user can tap "Save to Files", "Copy", etc.
///   This is the iOS idiomatic equivalent of Android's `MediaStore.Downloads`
///   for non-media files.
final class NativeMediaSaverImpl: NSObject, NativeMediaSaverHostApi {

  func saveFileToGallery(
    request: SaveFileRequest,
    completion: @escaping (Result<SaveFileResult, Error>) -> Void
  ) {
    let fileUrl = URL(fileURLWithPath: request.localPath)
    guard FileManager.default.fileExists(atPath: fileUrl.path) else {
      completion(
        .success(
          SaveFileResult(
            success: false,
            savedUri: nil,
            message: "File not found at \(request.localPath)."
          )
        )
      )
      return
    }

    let mime = request.mimeType.lowercased()
    if mime.hasPrefix("image/") {
      savePhoto(fileUrl: fileUrl, completion: completion)
    } else if mime.hasPrefix("video/") {
      saveVideo(fileUrl: fileUrl, completion: completion)
    } else {
      presentShareSheet(fileUrl: fileUrl, completion: completion)
    }
  }

  // MARK: - PHPhotoLibrary (images)

  private func savePhoto(
    fileUrl: URL,
    completion: @escaping (Result<SaveFileResult, Error>) -> Void
  ) {
    ensurePhotosAddPermission { [weak self] granted in
      guard let self = self else { return }
      guard granted else {
        completion(
          .success(
            SaveFileResult(
              success: false,
              savedUri: nil,
              message:
                "Photos add-only permission was denied. Enable it in Settings to save into Photos."
            )
          )
        )
        return
      }
      PHPhotoLibrary.shared().performChanges(
        {
          let request = PHAssetCreationRequest.forAsset()
          request.addResource(with: .photo, fileURL: fileUrl, options: nil)
        },
        completionHandler: { success, error in
          DispatchQueue.main.async {
            self.finish(success: success, error: error, completion: completion)
          }
        }
      )
    }
  }

  // MARK: - PHPhotoLibrary (video)

  private func saveVideo(
    fileUrl: URL,
    completion: @escaping (Result<SaveFileResult, Error>) -> Void
  ) {
    ensurePhotosAddPermission { [weak self] granted in
      guard let self = self else { return }
      guard granted else {
        completion(
          .success(
            SaveFileResult(
              success: false,
              savedUri: nil,
              message:
                "Photos add-only permission was denied. Enable it in Settings to save into Photos."
            )
          )
        )
        return
      }
      PHPhotoLibrary.shared().performChanges(
        {
          let request = PHAssetCreationRequest.forAsset()
          request.addResource(with: .video, fileURL: fileUrl, options: nil)
        },
        completionHandler: { success, error in
          DispatchQueue.main.async {
            self.finish(success: success, error: error, completion: completion)
          }
        }
      )
    }
  }

  private func ensurePhotosAddPermission(_ granted: @escaping (Bool) -> Void) {
    let current: PHAuthorizationStatus
    if #available(iOS 14, *) {
      current = PHPhotoLibrary.authorizationStatus(for: .addOnly)
    } else {
      current = PHPhotoLibrary.authorizationStatus()
    }

    switch current {
    case .authorized, .limited:
      granted(true)
    case .notDetermined:
      if #available(iOS 14, *) {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
          granted(status == .authorized || status == .limited)
        }
      } else {
        PHPhotoLibrary.requestAuthorization { status in
          granted(status == .authorized || status == .limited)
        }
      }
    default:
      granted(false)
    }
  }

  private func finish(
    success: Bool,
    error: Error?,
    completion: @escaping (Result<SaveFileResult, Error>) -> Void
  ) {
    if success {
      completion(.success(SaveFileResult(success: true, savedUri: nil, message: nil)))
    } else {
      let reason = error?.localizedDescription ?? "Photos library rejected the save."
      completion(
        .success(SaveFileResult(success: false, savedUri: nil, message: reason))
      )
    }
  }

  // MARK: - Share sheet fallback (non-media files)

  private func presentShareSheet(
    fileUrl: URL,
    completion: @escaping (Result<SaveFileResult, Error>) -> Void
  ) {
    DispatchQueue.main.async { [weak self] in
      guard let presenter = self?.topViewController() else {
        completion(
          .success(
            SaveFileResult(
              success: false,
              savedUri: nil,
              message: "No active view controller to present the share sheet."
            )
          )
        )
        return
      }

      let activity = UIActivityViewController(
        activityItems: [fileUrl],
        applicationActivities: nil
      )
      activity.completionWithItemsHandler = { _, completed, _, error in
        if let error = error {
          completion(
            .success(
              SaveFileResult(
                success: false,
                savedUri: nil,
                message: error.localizedDescription
              )
            )
          )
        } else {
          completion(
            .success(SaveFileResult(success: completed, savedUri: nil, message: nil))
          )
        }
      }

      // iPad popover anchoring — avoids crash on iPad when share sheet is presented.
      if let pop = activity.popoverPresentationController {
        pop.sourceView = presenter.view
        pop.sourceRect = CGRect(
          x: presenter.view.bounds.midX,
          y: presenter.view.bounds.midY,
          width: 0,
          height: 0
        )
        pop.permittedArrowDirections = []
      }

      presenter.present(activity, animated: true, completion: nil)
    }
  }

  private func topViewController() -> UIViewController? {
    guard
      let window = UIApplication.shared.connectedScenes
        .compactMap({ ($0 as? UIWindowScene)?.keyWindow })
        .first
    else { return nil }
    var top = window.rootViewController
    while let presented = top?.presentedViewController {
      top = presented
    }
    return top
  }
}
