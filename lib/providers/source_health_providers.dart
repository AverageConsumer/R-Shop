import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/config/source.dart';
import '../models/system_model.dart';
import '../services/romm_api_service.dart';
import '../services/romm_platform_matcher.dart';

enum SourceHealth { unknown, checking, valid, invalid }

@immutable
class SourceHealthState {
  final Map<String, SourceHealth> statuses;
  final Map<String, String> errors;
  final DateTime? lastCheckAt;

  const SourceHealthState({
    this.statuses = const {},
    this.errors = const {},
    this.lastCheckAt,
  });

  SourceHealth statusFor(String sourceId) =>
      statuses[sourceId] ?? SourceHealth.unknown;

  String? errorFor(String sourceId) => errors[sourceId];

  bool get isStale {
    if (lastCheckAt == null) return true;
    return DateTime.now().difference(lastCheckAt!) >
        const Duration(minutes: 5);
  }

  SourceHealthState copyWith({
    Map<String, SourceHealth>? statuses,
    Map<String, String>? errors,
    DateTime? lastCheckAt,
  }) {
    return SourceHealthState(
      statuses: statuses ?? this.statuses,
      errors: errors ?? this.errors,
      lastCheckAt: lastCheckAt ?? this.lastCheckAt,
    );
  }
}

/// Result of a health check for a single source, including discovered
/// platforms so callers can update knownPlatforms and auto-create systems.
class SourceHealthResult {
  final SourceHealth health;
  final String? error;
  final Map<String, int>? discoveredPlatforms;

  const SourceHealthResult.valid(this.discoveredPlatforms)
      : health = SourceHealth.valid,
        error = null;
  const SourceHealthResult.invalid(this.error)
      : health = SourceHealth.invalid,
        discoveredPlatforms = null;
}

class SourceHealthNotifier extends StateNotifier<SourceHealthState> {
  SourceHealthNotifier() : super(const SourceHealthState());

  /// Check all enabled RomM sources in parallel. Uses `fetchPlatforms`
  /// instead of `testConnection` so it both validates the token AND
  /// discovers new platforms in a single HTTP call.
  ///
  /// Returns a map of sourceId → discovered platforms for sources that
  /// responded successfully, so callers can update knownPlatforms and
  /// auto-create missing SystemConfigs.
  Future<Map<String, Map<String, int>>> checkAll(List<Source> sources) async {
    final rommSources = sources
        .where((s) => s.type == SourceType.romm && s.enabled && s.url != null)
        .toList();

    if (rommSources.isEmpty) return const {};

    final checking = Map<String, SourceHealth>.from(state.statuses);
    for (final s in rommSources) {
      checking[s.id] = SourceHealth.checking;
    }
    state = state.copyWith(statuses: checking);

    final api = RommApiService();
    final allSystemIds = SystemModel.supportedSystems.map((s) => s.id);

    final results = await Future.wait(
      rommSources.map((s) async {
        try {
          final platforms =
              await api.fetchPlatforms(s.url!, auth: s.auth);
          final known = RommPlatformMatcher.buildKnownPlatforms(
              allSystemIds, platforms);
          return MapEntry(s.id, SourceHealthResult.valid(known));
        } catch (e) {
          debugPrint('SourceHealthCheck: ${s.name} failed: $e');
          return MapEntry(s.id, SourceHealthResult.invalid(e.toString()));
        }
      }),
    );

    final newStatuses = Map<String, SourceHealth>.from(state.statuses);
    final newErrors = Map<String, String>.from(state.errors);
    final discoveredPlatforms = <String, Map<String, int>>{};

    for (final entry in results) {
      final result = entry.value;
      newStatuses[entry.key] = result.health;
      if (result.health == SourceHealth.valid) {
        newErrors.remove(entry.key);
        if (result.discoveredPlatforms != null) {
          discoveredPlatforms[entry.key] = result.discoveredPlatforms!;
        }
      } else {
        newErrors[entry.key] = result.error ?? 'Connection failed';
      }
    }

    state = SourceHealthState(
      statuses: newStatuses,
      errors: newErrors,
      lastCheckAt: DateTime.now(),
    );

    return discoveredPlatforms;
  }

  void markInvalid(String sourceId, String reason) {
    state = state.copyWith(
      statuses: {...state.statuses, sourceId: SourceHealth.invalid},
      errors: {...state.errors, sourceId: reason},
    );
  }

  void markValid(String sourceId) {
    final errors = Map<String, String>.from(state.errors)..remove(sourceId);
    state = state.copyWith(
      statuses: {...state.statuses, sourceId: SourceHealth.valid},
      errors: errors,
    );
  }
}

final sourceHealthProvider =
    StateNotifierProvider<SourceHealthNotifier, SourceHealthState>((ref) {
  return SourceHealthNotifier();
});
