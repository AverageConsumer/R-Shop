import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/config/source.dart';

/// Where to knock to find out whether a source is alive.
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

/// Measures which sources answer right now and how fast.
class EndpointProbeService {
  EndpointProbeService({
    SocketConnector? connect,
    Duration timeout = const Duration(seconds: 1),
    DateTime Function()? now,
    Duration cacheTtl = const Duration(minutes: 2),
  })  : _connect = connect ?? _realConnect,
        _timeout = timeout,
        _now = now ?? DateTime.now,
        _cacheTtl = cacheTtl;

  final SocketConnector _connect;
  final Duration _timeout;
  final DateTime Function() _now;
  final Duration _cacheTtl;

  final Map<String, ({DateTime at, Duration? latency})> _cache = {};

  static Future<void> _realConnect(
    String host,
    int port,
    Duration timeout,
  ) async {
    final socket = await Socket.connect(host, port, timeout: timeout);
    socket.destroy();
  }

  /// The address to knock on for [source], or null when it carries no usable address (local source).
  static ProbeTarget? targetFor(Source source) {
    switch (source.type) {
      case SourceType.romm:
      case SourceType.web:
        final raw = source.url;
        if (raw == null || raw.trim().isEmpty) return null;
        final uri = Uri.tryParse(raw.trim());
        if (uri == null || uri.host.isEmpty) return null;
        final port = uri.hasPort
            ? uri.port
            : _defaultPorts[uri.scheme.toLowerCase()];
        if (port == null) return null;
        return ProbeTarget(uri.host, port);
      case SourceType.smb:
        if (source.host == null || source.host!.isEmpty) return null;
        return ProbeTarget(source.host!, source.port ?? 445);
      case SourceType.ftp:
        if (source.host == null || source.host!.isEmpty) return null;
        return ProbeTarget(source.host!, source.port ?? 21);
      case SourceType.local:
        return null;
    }
  }

  /// Probes [source] and returns a Set containing [source.id] if reachable, or empty set if unreachable.
  Future<Set<String>> reachableFor(Source source) async {
    if (source.type == SourceType.local) {
      return {source.id};
    }
    final target = targetFor(source);
    if (target == null) return const {};

    final cached = _cache[source.id];
    if (cached != null && _now().difference(cached.at) < _cacheTtl) {
      return cached.latency != null ? {source.id} : const {};
    }

    final watch = Stopwatch()..start();
    try {
      await _connect(target.host, target.port, _timeout);
      final latency = watch.elapsed;
      _cache[source.id] = (at: _now(), latency: latency);
      return {source.id};
    } catch (_) {
      _cache[source.id] = (at: _now(), latency: null);
      return const {};
    }
  }

  /// Drops cached results.
  void invalidate([String? sourceId]) {
    if (sourceId == null) {
      _cache.clear();
    } else {
      _cache.remove(sourceId);
    }
  }
}
