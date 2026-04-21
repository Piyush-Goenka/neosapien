import 'dart:io';

import 'package:neo_sapien/platform/native_transfer_bridge.g.dart' as pigeon;

/// Domain-level outcome of a native save operation. Keeps the Pigeon
/// generated class out of application/presentation layers.
class NativeSaveOutcome {
  const NativeSaveOutcome({
    required this.success,
    this.savedUri,
    this.message,
  });

  final bool success;
  final String? savedUri;
  final String? message;
}

/// Strategy-pattern entry point for saving a received file into the
/// platform's native media store.
///
/// The concrete platform implementations live in:
///   - iOS:     `ios/Runner/NativeMediaSaverImpl.swift`
///             (`PHPhotoLibrary` for image/video, `UIActivityViewController`
///             share sheet for everything else).
///   - Android: `android/app/src/main/kotlin/.../NativeMediaSaverImpl.kt`
///             (`MediaStore.Downloads` ContentResolver insert).
///
/// This abstraction exists so the rest of the app never imports the
/// Pigeon-generated class directly.
abstract class NativeMediaSaver {
  Future<NativeSaveOutcome> saveFile({
    required String localPath,
    required String mimeType,
    required String displayName,
  });
}

/// Default implementation backed by Pigeon host API.
class PigeonNativeMediaSaver implements NativeMediaSaver {
  PigeonNativeMediaSaver([pigeon.NativeMediaSaverHostApi? api])
    : _api = api ?? pigeon.NativeMediaSaverHostApi();

  final pigeon.NativeMediaSaverHostApi _api;

  @override
  Future<NativeSaveOutcome> saveFile({
    required String localPath,
    required String mimeType,
    required String displayName,
  }) async {
    if (!File(localPath).existsSync()) {
      return NativeSaveOutcome(
        success: false,
        message: 'File no longer exists at $localPath.',
      );
    }

    try {
      final result = await _api.saveFileToGallery(
        pigeon.SaveFileRequest(
          localPath: localPath,
          mimeType: mimeType,
          displayName: displayName,
        ),
      );
      return NativeSaveOutcome(
        success: result.success,
        savedUri: result.savedUri,
        message: result.message,
      );
    } on Object catch (error) {
      return NativeSaveOutcome(
        success: false,
        message: 'Native save failed: $error',
      );
    }
  }
}
