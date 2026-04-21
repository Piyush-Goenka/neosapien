import Foundation
import UIKit
import UniformTypeIdentifiers

// iOS implementation of the Pigeon NativeFilePickerHostApi contract.
//
// Uses UIDocumentPickerViewController directly (via platform channels) instead
// of the file_picker pub.dev package — Bonus D scope.
//
// Presents the system document picker with `asCopy: true` so iOS copies the
// selected file(s) into our app sandbox's tmp directory before returning.
// That avoids the security-scoped resource dance: the URL iOS hands back
// already points to a readable file inside our sandbox.
final class NativeFilePickerImpl: NSObject, NativeFilePickerHostApi,
  UIDocumentPickerDelegate
{

  private var pendingCompletion: ((Result<PickFilesResult, Error>) -> Void)?

  func pickFiles(
    allowMultiple: Bool,
    completion: @escaping (Result<PickFilesResult, Error>) -> Void
  ) {
    // If a previous pick is still open (shouldn't happen — UI blocks it), fail it out.
    if let previous = pendingCompletion {
      pendingCompletion = nil
      previous(
        .success(
          PickFilesResult(
            files: [],
            cancelled: true,
            message: "A new file picker was requested before the previous one finished."
          )
        )
      )
    }
    pendingCompletion = completion

    DispatchQueue.main.async { [weak self] in
      guard let self = self else { return }
      guard let presenter = self.topViewController() else {
        let pending = self.pendingCompletion
        self.pendingCompletion = nil
        pending?(
          .success(
            PickFilesResult(
              files: [],
              cancelled: false,
              message: "No active view controller to present the picker."
            )
          )
        )
        return
      }

      let picker: UIDocumentPickerViewController
      if #available(iOS 14.0, *) {
        // `.data` + `.content` + `.item` covers any file type the OS exposes
        // through the Files app (documents, media, archives, binaries).
        picker = UIDocumentPickerViewController(
          forOpeningContentTypes: [UTType.data, UTType.content, UTType.item],
          asCopy: true
        )
      } else {
        // Pre-iOS-14 fallback using UTI strings + the older .import mode,
        // which also copies into the app sandbox.
        picker = UIDocumentPickerViewController(
          documentTypes: ["public.data", "public.content", "public.item"],
          in: .import
        )
      }
      picker.allowsMultipleSelection = allowMultiple
      picker.delegate = self
      picker.modalPresentationStyle = .formSheet
      presenter.present(picker, animated: true, completion: nil)
    }
  }

  // MARK: - UIDocumentPickerDelegate

  func documentPicker(
    _ controller: UIDocumentPickerViewController,
    didPickDocumentsAt urls: [URL]
  ) {
    guard let completion = pendingCompletion else { return }
    pendingCompletion = nil

    let files = urls.compactMap { url -> PickedFile? in
      // With asCopy: true / .import mode, the URL already points to a file
      // iOS copied into our tmp directory. Still attempt a stable copy into
      // `Library/Caches/neosapien_picked/` so the Dart layer can read it
      // even if the OS reclaims tmp later.
      let stableUrl = moveToStableCache(from: url) ?? url
      let name = url.lastPathComponent
      let id = UUID().uuidString

      let byteCount: Int64
      if let attributes = try? FileManager.default.attributesOfItem(atPath: stableUrl.path),
        let size = attributes[.size] as? NSNumber
      {
        byteCount = size.int64Value
      } else {
        byteCount = 0
      }

      return PickedFile(
        id: id,
        name: name,
        localPath: stableUrl.path,
        mimeType: guessMimeType(for: stableUrl),
        byteCount: byteCount,
        sourceIdentifier: url.absoluteString
      )
    }

    completion(
      .success(PickFilesResult(files: files, cancelled: false, message: nil))
    )
  }

  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    guard let completion = pendingCompletion else { return }
    pendingCompletion = nil
    completion(
      .success(PickFilesResult(files: [], cancelled: true, message: nil))
    )
  }

  // MARK: - Helpers

  private func moveToStableCache(from source: URL) -> URL? {
    do {
      let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
        .first
      guard let base = caches?.appendingPathComponent("neosapien_picked", isDirectory: true)
      else { return nil }
      if !FileManager.default.fileExists(atPath: base.path) {
        try FileManager.default.createDirectory(
          at: base,
          withIntermediateDirectories: true
        )
      }
      let target = base.appendingPathComponent(
        "\(UUID().uuidString)_\(source.lastPathComponent)"
      )
      try FileManager.default.copyItem(at: source, to: target)
      return target
    } catch {
      return nil
    }
  }

  private func guessMimeType(for url: URL) -> String {
    if #available(iOS 14.0, *) {
      let ext = url.pathExtension
      if !ext.isEmpty,
        let type = UTType(filenameExtension: ext),
        let mime = type.preferredMIMEType
      {
        return mime
      }
    }
    return "application/octet-stream"
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
