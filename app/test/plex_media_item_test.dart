import 'package:flutter_test/flutter_test.dart';
import 'package:plex_kids/src/plex/plex_media_models.dart';

void main() {
  test('PlexMediaItem parses grandparent fields for episodes', () {
    final json = {
      'ratingKey': '100',
      'title': 'Episode 1',
      'type': 'episode',
      'thumb': '/thumb/ep',
      'grandparentRatingKey': '200',
      'grandparentTitle': 'My Show',
      'grandparentThumb': '/thumb/show',
      'parentIndex': 1,
      'index': 2,
    };

    final item = PlexMediaItem.fromPlexJson(json);
    expect(item.grandparentRatingKey, '200');
    expect(item.grandparentTitle, 'My Show');
    expect(item.grandparentThumb, '/thumb/show');
    expect(item.parentIndex, 1);
    expect(item.index, 2);
  });
}
