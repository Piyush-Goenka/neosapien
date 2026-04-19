import 'package:neo_sapien/features/recipients/domain/entities/recipient.dart';
import 'package:neo_sapien/features/recipients/domain/value_objects/recipient_code.dart';

abstract interface class RecipientLookupRepository {
  Future<Recipient?> resolveByCode(RecipientCode code);
}
