import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/platform/native_transfer_bridge.g.dart',
    dartPackageName: 'neo_sapien',
    kotlinOut:
        'android/app/src/main/kotlin/com/neosapien/assignment/neo_sapien/NativeTransferBridge.g.kt',
    kotlinOptions: KotlinOptions(
      package: 'com.neosapien.assignment.neo_sapien',
    ),
    swiftOut: 'ios/Runner/NativeTransferBridge.g.swift',
    swiftOptions: SwiftOptions(),
  ),
)
class NativeTransferJob {
  NativeTransferJob({
    required this.transferId,
    required this.endpoint,
    required this.localPath,
    required this.method,
    this.headers = const <String, String>{},
    this.expectedBytes,
    this.contentType,
  });

  String transferId;
  String endpoint;
  String localPath;
  String method;
  Map<String, String> headers;
  int? expectedBytes;
  String? contentType;
}

class NativeTransferProgressEvent {
  NativeTransferProgressEvent({
    required this.transferId,
    required this.bytesTransferred,
    required this.totalBytes,
    required this.isUpload,
  });

  String transferId;
  int bytesTransferred;
  int totalBytes;
  bool isUpload;
}

class NativeTransferSnapshot {
  NativeTransferSnapshot({
    required this.transferId,
    required this.state,
    required this.bytesTransferred,
    required this.totalBytes,
    this.failureMessage,
  });

  String transferId;
  String state;
  int bytesTransferred;
  int totalBytes;
  String? failureMessage;
}

class NativeCommandResult {
  NativeCommandResult({required this.accepted, this.message});

  bool accepted;
  String? message;
}

/// Request to save a received file into the platform's native media store:
/// `PHPhotoLibrary` / Files-app share sheet on iOS,
/// `MediaStore.Downloads` / `MediaStore.Images` / `MediaStore.Video` on Android.
class SaveFileRequest {
  SaveFileRequest({
    required this.localPath,
    required this.mimeType,
    required this.displayName,
  });

  String localPath;
  String mimeType;
  String displayName;
}

/// Outcome of a native save operation.
///
/// `savedUri` is filled by Android (the MediaStore content:// URI) so the
/// caller can later surface an "Open" action; iOS does not return a usable
/// URI (Photos saves are identifier-based), so this stays null.
class SaveFileResult {
  SaveFileResult({required this.success, this.savedUri, this.message});

  bool success;
  String? savedUri;
  String? message;
}

@HostApi()
abstract class NativeTransferHostApi {
  NativeCommandResult startTransfer(NativeTransferJob job);

  NativeCommandResult pauseTransfer(String transferId);

  NativeCommandResult resumeTransfer(String transferId);

  NativeCommandResult cancelTransfer(String transferId);

  List<NativeTransferSnapshot?> queryActiveTransfers();
}

/// Thin host API specifically for native media save — Bonus E.
/// Kept separate from `NativeTransferHostApi` so the two bonus tracks
/// (background transfer + native save) can ship independently.
@HostApi()
abstract class NativeMediaSaverHostApi {
  @async
  SaveFileResult saveFileToGallery(SaveFileRequest request);
}

@FlutterApi()
abstract class NativeTransferFlutterApi {
  void onProgress(NativeTransferProgressEvent event);

  void onStateChanged(NativeTransferSnapshot snapshot);
}
