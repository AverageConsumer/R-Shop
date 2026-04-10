import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:multicast_dns/multicast_dns.dart';

/// A host found via [NetworkDiscoveryService].
@immutable
class DiscoveredHost {
  const DiscoveredHost({
    required this.name,
    required this.address,
    required this.port,
    required this.kind,
  });

  /// Human-readable label (mDNS service name with `.local` suffix stripped).
  final String name;

  /// Resolved IPv4/IPv6 address as a string (e.g. `"192.168.1.50"`).
  final String address;

  /// TCP port on which the service was advertised.
  final int port;

  /// Coarse classification used by the UI to pick an icon and pre-fill the
  /// matching source-type form.
  final DiscoveredKind kind;

  @override
  bool operator ==(Object other) =>
      other is DiscoveredHost &&
      other.address == address &&
      other.port == port &&
      other.kind == kind;

  @override
  int get hashCode => Object.hash(address, port, kind);
}

enum DiscoveredKind { smb, romm, http }

/// Discovers SMB and HTTP hosts on the local network via mDNS so the
/// onboarding flow can pre-fill the manual source form.
///
/// Best-effort: returns whatever it finds within [timeout]; failures are
/// silently ignored so an unfriendly network never blocks the UI. The
/// stream completes when the timeout elapses or the lookup is closed.
class NetworkDiscoveryService {
  NetworkDiscoveryService({MDnsClient? client}) : _injectedClient = client;

  final MDnsClient? _injectedClient;

  static const _smbServiceName = '_smb._tcp.local';
  static const _httpServiceName = '_http._tcp.local';

  /// Starts an mDNS lookup and emits any matching hosts.
  ///
  /// The stream is closed automatically once [timeout] elapses. Callers can
  /// also cancel their subscription early to abort the lookup.
  Stream<DiscoveredHost> discover({
    Duration timeout = const Duration(seconds: 5),
  }) async* {
    final client = _injectedClient ?? MDnsClient();
    final seen = <DiscoveredHost>{};
    try {
      try {
        await client.start();
      } on SocketException catch (e) {
        debugPrint('NetworkDiscoveryService: mDNS start failed: $e');
        return;
      }

      final deadline = DateTime.now().add(timeout);

      Future<List<DiscoveredHost>> probe(String service, DiscoveredKind kind) async {
        final results = <DiscoveredHost>[];
        try {
          await for (final ptr in client.lookup<PtrResourceRecord>(
            ResourceRecordQuery.serverPointer(service),
            timeout: timeout,
          )) {
            await for (final srv in client.lookup<SrvResourceRecord>(
              ResourceRecordQuery.service(ptr.domainName),
              timeout: const Duration(seconds: 2),
            )) {
              await for (final ip in client.lookup<IPAddressResourceRecord>(
                ResourceRecordQuery.addressIPv4(srv.target),
                timeout: const Duration(seconds: 2),
              )) {
                results.add(DiscoveredHost(
                  name: _stripLocal(ptr.domainName),
                  address: ip.address.address,
                  port: srv.port,
                  kind: kind,
                ));
              }
            }
            if (DateTime.now().isAfter(deadline)) break;
          }
        } catch (e) {
          debugPrint('NetworkDiscoveryService: probe $service failed: $e');
        }
        return results;
      }

      final probes = await Future.wait([
        probe(_smbServiceName, DiscoveredKind.smb),
        probe(_httpServiceName, DiscoveredKind.http),
      ]);

      for (final list in probes) {
        for (final host in list) {
          if (seen.add(host)) yield host;
        }
      }
    } finally {
      try {
        client.stop();
      } catch (e) {
        debugPrint('NetworkDiscoveryService: client.stop() failed: $e');
      }
    }
  }

  static String _stripLocal(String name) {
    var n = name;
    for (final suffix in const ['._smb._tcp.local', '._http._tcp.local', '.local']) {
      if (n.endsWith(suffix)) {
        n = n.substring(0, n.length - suffix.length);
        break;
      }
    }
    return n;
  }
}
