import 'dart:async';

import 'package:dio/dio.dart';

class ConnectionProbeResult {
  final String baseUrl;
  final bool local;
  final Duration latency;

  const ConnectionProbeResult({
    required this.baseUrl,
    required this.local,
    required this.latency,
  });
}

class PlexConnectionSelector {
  /// Probe /identity (cheap) to check connectivity.
  Future<ConnectionProbeResult> probe({
    required String baseUrl,
    required String token,
    required bool local,
    required Duration timeout,
  }) async {
    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: timeout,
        receiveTimeout: timeout,
        headers: {
          'X-Plex-Token': token,
          'Accept': 'application/json',
        },
      ),
    );

    final sw = Stopwatch()..start();
    await dio.get('/identity');
    sw.stop();

    return ConnectionProbeResult(baseUrl: baseUrl, local: local, latency: sw.elapsed);
  }

  /// Choose the best connection.
  ///
  /// Strategy:
  /// - fire probes for local connections with a short timeout
  /// - in parallel, fire probes for remote connections with a longer timeout
  /// - return the first successful result (usually fastest)
  Future<ConnectionProbeResult> chooseBest({
    required List<(String baseUrl, bool local)> candidates,
    required String token,
    Duration localTimeout = const Duration(seconds: 3),
    Duration remoteTimeout = const Duration(seconds: 8),
  }) async {
    final locals = candidates.where((c) => c.$2).toList(growable: false);
    final remotes = candidates.where((c) => !c.$2).toList(growable: false);

    Future<ConnectionProbeResult> race(List<Future<ConnectionProbeResult>> futures) {
      final c = Completer<ConnectionProbeResult>();
      var pending = futures.length;
      Object? lastErr;

      for (final f in futures) {
        f.then((value) {
          if (!c.isCompleted) c.complete(value);
        }).catchError((e) {
          lastErr = e;
          pending -= 1;
          if (pending <= 0 && !c.isCompleted) {
            c.completeError(lastErr ?? StateError('No connection candidates succeeded'));
          }
        });
      }

      return c.future;
    }

    final probes = <Future<ConnectionProbeResult>>[];

    for (final c in locals) {
      probes.add(probe(baseUrl: c.$1, token: token, local: true, timeout: localTimeout));
    }
    for (final c in remotes) {
      probes.add(probe(baseUrl: c.$1, token: token, local: false, timeout: remoteTimeout));
    }

    if (probes.isEmpty) throw StateError('No connection candidates provided');

    return race(probes);
  }
}
