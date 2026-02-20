import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:plex_kids/src/connection/connection_selector.dart';

class FakeSelector extends PlexConnectionSelector {
  final Map<String, (Duration delay, bool succeed)> plan;

  FakeSelector(this.plan);

  @override
  Future<ConnectionProbeResult> probe({
    required String baseUrl,
    required String token,
    required bool local,
    required Duration timeout,
  }) async {
    final step = plan[baseUrl];
    if (step == null) throw StateError('No plan for $baseUrl');

    final delay = step.$1;
    final succeed = step.$2;

    await Future<void>.delayed(delay);

    if (!succeed) throw TimeoutException('fail $baseUrl');

    return ConnectionProbeResult(baseUrl: baseUrl, local: local, latency: delay);
  }
}

void main() {
  test('chooseBest returns fastest successful connection', () async {
    final selector = FakeSelector({
      'http://local:32400': (const Duration(milliseconds: 150), true),
      'https://remote:32400': (const Duration(milliseconds: 50), true),
    });

    final res = await selector.chooseBest(
      candidates: [
        ('http://local:32400', true),
        ('https://remote:32400', false),
      ],
      token: 't',
    );

    expect(res.baseUrl, 'https://remote:32400');
    expect(res.local, isFalse);
  });

  test('chooseBest errors if all probes fail', () async {
    final selector = FakeSelector({
      'http://local:32400': (const Duration(milliseconds: 10), false),
      'https://remote:32400': (const Duration(milliseconds: 20), false),
    });

    await expectLater(
      () => selector.chooseBest(
        candidates: [
          ('http://local:32400', true),
          ('https://remote:32400', false),
        ],
        token: 't',
      ),
      throwsA(isA<TimeoutException>()),
    );
  });
}
