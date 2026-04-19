import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neo_sapien/core/config/app_environment.dart';

final appEnvironmentProvider = Provider<AppEnvironment>((ref) {
  return AppEnvironment.current;
});
