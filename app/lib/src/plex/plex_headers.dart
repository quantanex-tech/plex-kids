import 'dart:io';

/// Plex expects a handful of X-Plex-* headers from clients.
/// We keep this minimal for now; we can refine as needed.
class PlexHeaders {
  static const String product = 'Plex Kids';
  static const String version = '0.0.1';
  static const String device = 'Android';
  static const String platform = 'Android';

  static Map<String, String> base({required String clientIdentifier}) => {
        'X-Plex-Product': product,
        'X-Plex-Version': version,
        'X-Plex-Device': device,
        'X-Plex-Platform': platform,
        'X-Plex-Client-Identifier': clientIdentifier,
        'X-Plex-Device-Name': Platform.localHostname,
        'Accept': 'application/json',
      };
}
