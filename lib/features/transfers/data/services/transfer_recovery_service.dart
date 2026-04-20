import 'package:neo_sapien/features/transfers/data/data_sources/firestore_transfer_remote_data_source.dart';
import 'package:neo_sapien/features/transfers/data/services/transfer_remote_context_resolver.dart';

/// Runs once on app boot to detect in-flight transfers that did not finish
/// before the process died (kill, crash, OOM, OS reclamation) and marks them
/// as failed + recoverable so the user can explicitly retry.
///
/// This is a soft reconciliation: true resume-from-offset lands with the
/// native background engines (Bonus B/C). Here we at least surface honest
/// state so the UI does not lie about an in-flight transfer.
class TransferRecoveryService {
  const TransferRecoveryService({
    required FirestoreTransferRemoteDataSource remoteDataSource,
    required TransferRemoteContextResolver contextResolver,
  }) : _remoteDataSource = remoteDataSource,
       _contextResolver = contextResolver;

  final FirestoreTransferRemoteDataSource _remoteDataSource;
  final TransferRemoteContextResolver _contextResolver;

  Future<int> reconcileOnBoot() async {
    final context = await _contextResolver.tryResolve();
    if (context == null) {
      return 0;
    }

    return _remoteDataSource.reconcileStaleBatchesForUser(
      currentUserUid: context.uid,
    );
  }
}
