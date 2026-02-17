import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/config/app_config.dart';
import '../models/config/system_config.dart';

final appConfigProvider = StateProvider<AppConfig>((ref) {
  return AppConfig.empty;
});

final isConfigLoadedProvider = Provider<bool>((ref) {
  return ref.watch(appConfigProvider).systems.isNotEmpty;
});

final configuredSystemsProvider = Provider<List<SystemConfig>>((ref) {
  return ref.watch(appConfigProvider).systems;
});

final systemConfigProvider = Provider.family<SystemConfig?, String>((ref, id) {
  return ref.watch(appConfigProvider).systemById(id);
});
