import 'package:flutter_test/flutter_test.dart';
import 'package:plex_kids/src/plex/plex_playback_parser.dart';

void main() {
  test('parseFirstPart returns part key', () {
    final data = {
      'MediaContainer': {
        'Metadata': [
          {
            'Media': [
              {
                'Part': [
                  {'key': '/library/parts/12345/file.mp4'}
                ]
              }
            ]
          }
        ]
      }
    };

    final info = PlexPlaybackParser.parseFirstPart(data);
    expect(info, isNotNull);
    expect(info!.partKey, '/library/parts/12345/file.mp4');
  });
}
