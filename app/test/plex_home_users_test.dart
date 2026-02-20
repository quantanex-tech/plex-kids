import 'package:flutter_test/flutter_test.dart';
import 'package:plex_kids/src/plex/plex_home_users.dart';

void main() {
  test('parseUsersXml parses managed and protected flags', () {
    const xml = '''
<MediaContainer size="2">
  <User id="1" title="Paul" managed="0" protected="0" />
  <User id="2" title="Kid" managed="1" protected="1" />
</MediaContainer>
''';

    final users = PlexHomeUsersApi.parseUsersXml(xml);
    expect(users, hasLength(2));

    expect(users[0].id, '1');
    expect(users[0].title, 'Paul');
    expect(users[0].isManaged, isFalse);
    expect(users[0].isProtected, isFalse);

    expect(users[1].id, '2');
    expect(users[1].title, 'Kid');
    expect(users[1].isManaged, isTrue);
    expect(users[1].isProtected, isTrue);
  });
}
