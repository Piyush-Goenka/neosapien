import 'package:neo_sapien/features/transfers/domain/entities/transfer_file.dart';

abstract interface class TransferFileSelector {
  Future<List<TransferFile>> pickFiles();
}
