import 'package:dio/dio.dart';
import 'package:xml/xml.dart';

class PlexResourceServer {
  final String name;
  final String machineIdentifier;
  final List<PlexConnection> connections;

  const PlexResourceServer({
    required this.name,
    required this.machineIdentifier,
    required this.connections,
  });
}

class PlexConnection {
  final String uri;
  final bool local;

  const PlexConnection({required this.uri, required this.local});
}

class PlexResourcesApi {
  final Dio _dio;

  PlexResourcesApi()
      : _dio = Dio(
          BaseOptions(
            baseUrl: 'https://plex.tv',
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 20),
            responseType: ResponseType.plain,
          ),
        );

  static List<PlexResourceServer> parseResourcesXml(String xmlString) {
    final xml = XmlDocument.parse(xmlString);
    final devices = xml.findAllElements('Device');

    final servers = <PlexResourceServer>[];
    for (final d in devices) {
      final provides = d.getAttribute('provides') ?? '';
      if (!provides.contains('server')) continue;

      final name = d.getAttribute('name') ?? 'Plex Server';
      final machineId = d.getAttribute('clientIdentifier') ?? '';
      if (machineId.isEmpty) continue;

      final connections = <PlexConnection>[];
      for (final c in d.findAllElements('Connection')) {
        final uri = c.getAttribute('uri') ?? '';
        if (uri.isEmpty) continue;
        final local = (c.getAttribute('local') ?? '0') == '1';
        connections.add(PlexConnection(uri: uri, local: local));
      }

      servers.add(PlexResourceServer(
        name: name,
        machineIdentifier: machineId,
        connections: connections,
      ));
    }

    return servers;
  }

  Future<List<PlexResourceServer>> listServers({required String token}) async {
    // Returns XML.
    final res = await _dio.get(
      '/api/resources',
      queryParameters: {
        'includeHttps': 1,
        'includeRelay': 1,
        'includeIPv6': 1,
        'X-Plex-Token': token,
      },
    );

    return parseResourcesXml(res.data as String);
  }
}
