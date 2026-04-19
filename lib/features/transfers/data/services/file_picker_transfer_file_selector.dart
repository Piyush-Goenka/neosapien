import 'package:file_picker/file_picker.dart';
import 'package:neo_sapien/core/errors/app_exception.dart';
import 'package:neo_sapien/features/transfers/data/services/mime_type_guesser.dart';
import 'package:neo_sapien/features/transfers/domain/entities/transfer_file.dart';
import 'package:neo_sapien/features/transfers/domain/entities/transfer_file_status.dart';
import 'package:neo_sapien/features/transfers/domain/services/transfer_file_selector.dart';

class FilePickerTransferFileSelector implements TransferFileSelector {
  const FilePickerTransferFileSelector();

  @override
  Future<List<TransferFile>> pickFiles() async {
    try {
      final result = await FilePicker.pickFiles(
        allowMultiple: true,
        type: FileType.any,
        withData: false,
      );

      if (result == null || result.files.isEmpty) {
        return const <TransferFile>[];
      }

      return result.files.map(_toTransferFile).toList(growable: false);
    } on Exception catch (error) {
      throw TransferFileSelectionException(
        'Unable to open the system file picker. '
        'Check file permissions and try again.',
        cause: error,
      );
    }
  }

  TransferFile _toTransferFile(PlatformFile file) {
    final cleanedName = file.name.trim();
    final name = cleanedName.isEmpty ? 'unnamed-file' : cleanedName;
    final localPath = file.path?.trim();
    final sourceIdentifier = file.identifier?.trim();
    final entropy = <String>[
      file.name,
      file.path ?? '',
      file.identifier ?? '',
      file.size.toString(),
      DateTime.now().microsecondsSinceEpoch.toString(),
    ].join(':');

    return TransferFile(
      id: entropy.hashCode.abs().toRadixString(36),
      name: name,
      byteCount: file.size,
      mimeType: MimeTypeGuesser.fromFileName(name),
      status: TransferFileStatus.pending,
      localPath: localPath == null || localPath.isEmpty ? null : localPath,
      sourceIdentifier: sourceIdentifier == null || sourceIdentifier.isEmpty
          ? null
          : sourceIdentifier,
    );
  }
}
