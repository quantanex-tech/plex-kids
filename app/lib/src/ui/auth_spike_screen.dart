import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_state.dart';
import '../providers.dart';
import 'plex_spike_screen.dart';

class AuthSpikeScreen extends ConsumerWidget {
  const AuthSpikeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);

    if (auth.userToken != null && auth.serverBaseUrl != null) {
      // We have enough to use PlexClient in the existing spike.
      return const PlexSpikeScreen();
    }

    return _AuthView(state: auth);
  }
}

class _AuthView extends ConsumerWidget {
  final AuthState state;

  const _AuthView({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign in')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Plex Kids (Spike)\n\n'
              'This will open Plex login in your browser, then the app will poll until login completes.\n'
              'After login we switch to the first managed user (kid) for now.',
            ),
            const SizedBox(height: 12),
            if (state.error != null) ...[
              Text(state.error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              const SizedBox(height: 12),
            ],
            FilledButton(
              onPressed: state.isLoading
                  ? null
                  : () async {
                      final ctl = ref.read(authControllerProvider.notifier);
                      await ctl.signInAndSelectKid();
                    },
              child: state.isLoading ? const Text('Working...') : const Text('Sign in to Plex'),
            ),
            const SizedBox(height: 12),
            Text('Server: ${state.serverName ?? '-'}'),
            Text('Base URL: ${state.serverBaseUrl ?? '-'}'),
            const Spacer(),
            TextButton(
              onPressed: () async {
                await ref.read(authControllerProvider.notifier).signOut();
              },
              child: const Text('Clear session'),
            ),
          ],
        ),
      ),
    );
  }
}
