import 'package:neo_sapien/core/errors/app_exception.dart';
import 'package:neo_sapien/features/transfers/data/services/mime_type_guesser.dart';
import 'package:neo_sapien/features/transfers/domain/entities/transfer_file.dart';
import 'package:neo_sapien/features/transfers/domain/entities/transfer_file_status.dart';
import 'package:neo_sapien/features/transfers/domain/services/transfer_file_selector.dart';
import 'package:neo_sapien/platform/native_transfer_bridge.g.dart' as pigeon;

/// [TransferFileSelector] backed by the Pigeon `NativeFilePickerHostApi`.
///
/// Replaces the `file_picker` pub.dev package with direct platform-channel
/// calls to:
///   - Android: `ACTION_OPEN_DOCUMENT`
///   - iOS:     `UIDocumentPickerViewController`
///
/// Both native impls copy the picked bytes into an app-sandbox cache before
/// returning, so the `localPath` we surface here is always readable without
/// the Dart side touching security-scoped resources or content URI lifetime.
class NativeFilePickerTransferFileSelector implements TransferFileSelector {
  NativeFilePickerTransferFileSelector([pigeon.NativeFilePickerHostApi? api])
    : _api = api ?? pigeon.NativeFilePickerHostApi();

  final pigeon.NativeFilePickerHostApi _api;

  @override
  Future<List<TransferFile>> pickFiles() async {
    try {
      final result = await _api.pickFiles(true);
      if (result.cancelled) {
        return const <TransferFile>[];
      }

      final picked = result.files.whereType<pigeon.PickedFile>();
      return picked.map(_toTransferFile).toList(growable: false);
    } on Exception catch (error) {
      throw TransferFileSelectionException(
        'Unable to open the system file picker. '
        'Check file permissions and try again.',
        cause: error,
      );
    }
  }

  TransferFile _toTransferFile(pigeon.PickedFile file) {
    final cleanedName = file.name.trim();
    final name = cleanedName.isEmpty ? 'unnamed-file' : cleanedName;
    final mime = file.mimeType.isNotEmpty
        ? file.mimeType
        : MimeTypeGuesser.fromFileName(name);

    return TransferFile(
      id: file.id,
      name: name,
      byteCount: file.byteCount,
      mimeType: mime,
      status: TransferFileStatus.pending,
      localPath: file.localPath.isEmpty ? null : file.localPath,
      sourceIdentifier:
          (file.sourceIdentifier == null || file.sourceIdentifier!.isEmpty)
          ? null
          : file.sourceIdentifier,
    );
  }
}
