import 'package:flutter_test/flutter_test.dart';
import 'package:plex_kids/src/plex/plex_resources.dart';

void main() {
  test('parseResourcesXml returns only server devices with connections', () {
    const xml = '''
<MediaContainer size="2">
  <Device name="NotAServer" provides="client" clientIdentifier="abc">
    <Connection uri="http://1.2.3.4:32400" local="1" />
  </Device>
  <Device name="MyPlex" provides="server" clientIdentifier="machine-1">
    <Connection uri="http://192.168.1.10:32400" local="1" />
    <Connection uri="https://example.com:32400" local="0" />
  </Device>
</MediaContainer>
''';

    final servers = PlexResourcesApi.parseResourcesXml(xml);
    expect(servers, hasLength(1));

    final s = servers.single;
    expect(s.name, 'MyPlex');
    expect(s.machineIdentifier, 'machine-1');
    expect(s.connections, hasLength(2));
    expect(s.connections.first.uri, 'http://192.168.1.10:32400');
    expect(s.connections.first.local, isTrue);
  });
}
