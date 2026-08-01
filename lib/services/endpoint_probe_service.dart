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

/// Decides which endpoint addresses are reachable right now, so
/// [Source.resolveEndpoint] can pick a live route.
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

  final Map<String, ({DateTime at, Set<String> reachable})> _cache = {};

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

  /// Ids of [source]'s endpoints that answered.
  ///
  /// An endpoint with no usable address is reported unreachable rather than
  /// skipped, so it can never win auto-selection.
  Future<Set<String>> reachableFor(Source source) async {
    if (source.endpoints.isEmpty) return const {};

    final cached = _cache[source.id];
    if (cached != null && _now().difference(cached.at) < _cacheTtl) {
      return cached.reachable;
    }

    final reachable = <String>{};
    final probes = source.endpoints.map((ep) async {
      final target = targetFor(ep, source.type);
      if (target == null) return;
      try {
        await _connect(target.host, target.port, _perEndpointTimeout);
        reachable.add(ep.id);
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

    _cache[source.id] = (at: _now(), reachable: reachable);
    return reachable;
  }

  /// Probes, then applies [Source.resolveEndpoint]. Returns the route that
  /// should serve this source, or null when it has none.
  Future<SourceEndpoint?> resolve(Source source) async {
    // A pinned route is the user's explicit choice; probing would only waste
    // a second, because the answer cannot change what we return.
    if (source.endpointSelection == EndpointSelection.pinned &&
        source.pinnedEndpointId != null &&
        source.endpointById(source.pinnedEndpointId!) != null) {
      return source.resolveEndpoint();
    }
    final reachable = await reachableFor(source);
    return source.resolveEndpoint(reachable: reachable);
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
