import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/config/source.dart';

/// Where to knock to find out whether a route is alive.
@immutable
class ProbeTarget {
  final String host;
  final int port;

  const ProbeTarget(this.host, this.port);

  @override
  bool operator ==(Object other) =>
      other is ProbeTarget && other.host == host && other.port == port;

  @override
  int get hashCode => Object.hash(host, port);

  @override
  String toString() => '$host:$port';
}

/// Opens a connection and closes it again. Injected so tests never touch the
/// network. Must complete normally on success and throw on failure.
typedef SocketConnector = Future<void> Function(
  String host,
  int port,
  Duration timeout,
);

const _defaultPorts = <String, int>{
  'http': 80,
  'https': 443,
};

/// One route's answer to a probe: it opened, and this is how long it took.
typedef RouteLatency = ({String endpointId, Duration latency});

/// What probing one source found: every route that answered, **fastest first**.
///
/// The ordering is the whole point — "which routes are up" was never the
/// interesting question when more than one is. A source reachable both over the
/// LAN and through a DDNS name is reachable *twice*, and the only thing that
/// separates them is how long the connect took.
///
/// Routes that did not answer are simply absent. There is no "unknown" state:
/// a route that timed out inside the budget and a route that was never probed
/// are equally unusable right now, and pretending to tell them apart would put
/// a distinction on screen that nobody can act on.
@immutable
class ProbeResults {
  const ProbeResults(this.ranked);

  static const empty = ProbeResults(<RouteLatency>[]);

  /// Routes that answered, ascending by latency. Ties keep the source's own
  /// endpoint order, so a user who put the LAN first still gets the LAN when
  /// both addresses answer in the same millisecond.
  final List<RouteLatency> ranked;

  bool get isEmpty => ranked.isEmpty;
  bool get isNotEmpty => ranked.isNotEmpty;

  /// Ids fastest first — pass straight to [Source.resolveEndpoint].
  List<String> get rankedIds => [for (final r in ranked) r.endpointId];

  /// For callers that only care whether a route is up at all.
  Set<String> get reachableIds => {for (final r in ranked) r.endpointId};

  bool contains(String endpointId) =>
      ranked.any((r) => r.endpointId == endpointId);

  /// How long [endpointId] took, or null when it did not answer. This is what
  /// the picker shows next to each route.
  Duration? latencyOf(String endpointId) {
    for (final r in ranked) {
      if (r.endpointId == endpointId) return r.latency;
    }
    return null;
  }

  /// The route auto-selection would take, or null when nothing answered.
  String? get fastestId => ranked.isEmpty ? null : ranked.first.endpointId;

  @override
  bool operator ==(Object other) =>
      other is ProbeResults && listEquals(ranked, other.ranked);

  @override
  int get hashCode => Object.hashAll(ranked);

  @override
  String toString() => 'ProbeResults($ranked)';
}

/// Measures which endpoint addresses answer right now and how fast, so
/// [Source.resolveEndpoint] can pick the best live route.
///
/// **Reachability here means "a TCP connection can be opened", nothing more.**
/// It deliberately does not issue an HTTP request, follow redirects, or check
/// credentials: the question being answered is "can I get to this server by
/// this route", not "is this server healthy" or "am I authorised". Keeping it
/// at the transport layer means one implementation covers RomM, Web, SMB and
/// FTP, and a 401 from a perfectly reachable server never gets mistaken for a
/// dead route.
class EndpointProbeService {
  EndpointProbeService({
    SocketConnector? connect,
    Duration perEndpointTimeout = const Duration(seconds: 1),
    Duration overallBudget = const Duration(seconds: 3),
    DateTime Function()? now,
    Duration cacheTtl = const Duration(minutes: 2),
  })  : _connect = connect ?? _realConnect,
        _perEndpointTimeout = perEndpointTimeout,
        _overallBudget = overallBudget,
        _now = now ?? DateTime.now,
        _cacheTtl = cacheTtl;

  final SocketConnector _connect;

  /// How long a single address gets to answer. The LAN answers in tens of
  /// milliseconds; a second is generous for it and short enough that a dead
  /// LAN route does not hold up startup.
  final Duration _perEndpointTimeout;

  /// Hard ceiling for probing one source, however many routes it has.
  /// Endpoints are probed concurrently, so this only bites when a source has
  /// many routes and they are all slow.
  final Duration _overallBudget;

  final DateTime Function() _now;
  final Duration _cacheTtl;

  final Map<String, ({DateTime at, ProbeResults results})> _cache = {};

  static Future<void> _realConnect(
    String host,
    int port,
    Duration timeout,
  ) async {
    final socket = await Socket.connect(host, port, timeout: timeout);
    socket.destroy();
  }

  /// The address to knock on for [endpoint], or null when it carries no
  /// usable address (a local source, or a half-filled entry).
  ///
  /// Pure — no I/O, so the port-defaulting rules are directly testable.
  static ProbeTarget? targetFor(SourceEndpoint endpoint, SourceType type) {
    switch (type) {
      case SourceType.romm:
      case SourceType.web:
        final raw = endpoint.url;
        if (raw == null || raw.trim().isEmpty) return null;
        final uri = Uri.tryParse(raw.trim());
        if (uri == null || uri.host.isEmpty) return null;
        final port = uri.hasPort
            ? uri.port
            : _defaultPorts[uri.scheme.toLowerCase()];
        if (port == null) return null;
        return ProbeTarget(uri.host, port);
      case SourceType.smb:
        if (endpoint.host == null || endpoint.host!.isEmpty) return null;
        return ProbeTarget(endpoint.host!, endpoint.port ?? 445);
      case SourceType.ftp:
        if (endpoint.host == null || endpoint.host!.isEmpty) return null;
        return ProbeTarget(endpoint.host!, endpoint.port ?? 21);
      case SourceType.local:
        // Nothing to reach — the filesystem is always "up".
        return null;
    }
  }

  /// Id reported for a source that carries its address on the source itself
  /// rather than in an endpoint list.
  static const String syntheticEndpointId = 'self';

  /// The routes to probe. [Source.fromJson] backfills an endpoint from the
  /// legacy connection fields, but a Source built directly in code has an
  /// empty list while still having a perfectly good address — treating that
  /// as "nothing to probe" would silently report it unreachable.
  static List<SourceEndpoint> _probeableEndpoints(Source source) {
    if (source.endpoints.isNotEmpty) return source.endpoints;
    if (source.url == null && source.host == null) return const [];
    return [
      SourceEndpoint(
        id: syntheticEndpointId,
        label: source.name,
        url: source.url,
        host: source.host,
        port: source.port,
        share: source.share,
      ),
    ];
  }

  /// Probes every route of [source] at once and ranks the ones that answered.
  ///
  /// The latency reported is the time to open a TCP connection. It is not the
  /// throughput the route will give a download, and it is not meant to be:
  /// what separates a LAN address from a proxied DDNS name is round trips, and
  /// the connect is the cheapest honest sample of those we can take without
  /// sending a request that would need credentials.
  ///
  /// An endpoint with no usable address is simply absent from the results
  /// rather than reported at latency zero, so it can never win auto-selection.
  Future<ProbeResults> probeFor(Source source) async {
    final endpoints = _probeableEndpoints(source);
    if (endpoints.isEmpty) return ProbeResults.empty;

    final cached = _cache[source.id];
    if (cached != null && _now().difference(cached.at) < _cacheTtl) {
      return cached.results;
    }

    final answered = <String, Duration>{};
    final probes = endpoints.map((ep) async {
      final target = targetFor(ep, source.type);
      if (target == null) return;
      final watch = Stopwatch()..start();
      try {
        await _connect(target.host, target.port, _perEndpointTimeout);
        answered[ep.id] = watch.elapsed;
      } catch (_) {
        // Unreachable is the normal outcome for the route you are not on.
      }
    });

    try {
      await Future.wait(probes).timeout(_overallBudget);
    } on TimeoutException {
      // Keep whatever answered inside the budget rather than failing the lot.
      debugPrint('EndpointProbe: budget exhausted for source ${source.id}');
    }

    // Snapshot now: probes abandoned by the budget keep running and would
    // otherwise land in the map — and, before this was a snapshot, inside the
    // already-cached result — long after we told the caller what we found.
    final listOrder = <String, int>{
      for (var i = 0; i < endpoints.length; i++) endpoints[i].id: i,
    };
    final ranked = <RouteLatency>[
      for (final e in answered.entries)
        (endpointId: e.key, latency: e.value),
    ]..sort((a, b) {
        final byLatency = a.latency.compareTo(b.latency);
        if (byLatency != 0) return byLatency;
        return (listOrder[a.endpointId] ?? 0)
            .compareTo(listOrder[b.endpointId] ?? 0);
      });

    final results = ProbeResults(List<RouteLatency>.unmodifiable(ranked));
    _cache[source.id] = (at: _now(), results: results);
    return results;
  }

  /// Ids of [source]'s routes that answered, unordered.
  ///
  /// Kept for callers whose only question is "is this source up at all" —
  /// [resolveForSync] asks exactly that before reaching for the fallback.
  /// Anything that ranks, displays or auto-selects wants [probeFor].
  Future<Set<String>> reachableFor(Source source) async =>
      (await probeFor(source)).reachableIds;

  /// Probes, then applies [Source.resolveEndpoint]. Returns the route that
  /// should serve this source, or null when it has none.
  ///
  /// In `auto` this is "the fastest route that answered": the user did not
  /// override anything, so the machine is free to take the quickest way in and
  /// to change its mind the next time the network looks different.
  Future<SourceEndpoint?> resolve(Source source) async {
    // A pinned route is the user's explicit override; probing would only waste
    // a second, because the answer cannot change what we return.
    if (source.endpointSelection == EndpointSelection.pinned &&
        source.pinnedEndpointId != null &&
        source.endpointById(source.pinnedEndpointId!) != null) {
      return source.resolveEndpoint();
    }
    final results = await probeFor(source);
    return source.resolveEndpoint(reachable: results.rankedIds);
  }

  /// Drops cached results. Call when the network changes (Wi-Fi on/off, a
  /// different SSID) — "the LAN is unreachable" stops being true the moment
  /// the user walks back in the door.
  void invalidate([String? sourceId]) {
    if (sourceId == null) {
      _cache.clear();
    } else {
      _cache.remove(sourceId);
    }
  }
}
