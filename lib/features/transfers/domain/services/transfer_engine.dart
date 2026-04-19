abstract interface class TransferEngine {
  Future<void> enqueue(String batchId);

  Future<void> pause(String batchId);

  Future<void> resume(String batchId);

  Future<void> cancel(String batchId);
}
