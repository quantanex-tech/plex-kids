import '../plex/plex_pin_auth.dart';

class PendingPin {
  final PlexPin pin;
  final String clientIdentifier;

  const PendingPin({required this.pin, required this.clientIdentifier});
}
