import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neo_sapien/features/transfers/data/services/native_media_saver.dart';
import 'package:neo_sapien/features/transfers/domain/entities/transfer_file.dart';

final nativeMediaSaverProvider = Provider<NativeMediaSaver>((ref) {
  return PigeonNativeMediaSaver();
});

final nativeSaveControllerProvider =
    NotifierProvider<NativeSaveController, NativeSaveState>(
      NativeSaveController.new,
    );

@immutable
class NativeSaveState {
  const NativeSaveState({
    this.pendingFileIds = const <String>{},
    this.lastOutcome,
  });

  final Set<String> pendingFileIds;
  final NativeSaveOutcomeSnapshot? lastOutcome;

  bool isPending(String fileId) => pendingFileIds.contains(fileId);

  NativeSaveState copyWith({
    Set<String>? pendingFileIds,
    Object? lastOutcome = _sentinel,
  }) {
    return NativeSaveState(
      pendingFileIds: pendingFileIds ?? this.pendingFileIds,
      lastOutcome: lastOutcome == _sentinel
          ? this.lastOutcome
          : lastOutcome as NativeSaveOutcomeSnapshot?,
    );
  }
}

@immutable
class NativeSaveOutcomeSnapshot {
  const NativeSaveOutcomeSnapshot({
    required this.fileId,
    required this.fileName,
    required this.success,
    this.message,
    this.savedUri,
  });

  final String fileId;
  final String fileName;
  final bool success;
  final String? message;
  final String? savedUri;
}

const Object _sentinel = Object();

class NativeSaveController extends Notifier<NativeSaveState> {
  @override
  NativeSaveState build() {
    return const NativeSaveState();
  }

  Future<void> save(TransferFile file) async {
    final localPath = file.localPath;
    if (localPath == null || localPath.isEmpty) {
      state = state.copyWith(
        lastOutcome: NativeSaveOutcomeSnapshot(
          fileId: file.id,
          fileName: file.name,
          success: false,
          message: 'No local copy to save. Download the file first.',
        ),
      );
      return;
    }

    state = state.copyWith(
      pendingFileIds: <String>{...state.pendingFileIds, file.id},
      lastOutcome: null,
    );

    final outcome = await ref
        .read(nativeMediaSaverProvider)
        .saveFile(
          localPath: localPath,
          mimeType: file.mimeType,
          displayName: file.name,
        );

    final nextPending = <String>{...state.pendingFileIds}..remove(file.id);
    state = state.copyWith(
      pendingFileIds: nextPending,
      lastOutcome: NativeSaveOutcomeSnapshot(
        fileId: file.id,
        fileName: file.name,
        success: outcome.success,
        message: outcome.message,
        savedUri: outcome.savedUri,
      ),
    );
  }
}
