import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_state.dart';
import '../providers.dart';
import 'home_rails_screen.dart';

class AuthSpikeScreen extends ConsumerWidget {
  const AuthSpikeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);

    if (auth.userToken != null && auth.serverBaseUrl != null) {
      return const HomeRailsScreen();
    }

    return _AuthView(state: auth);
  }
}

class _AuthView extends ConsumerWidget {
  final AuthState state;

  const _AuthView({required this.state});

  Future<String?> _promptForPin(BuildContext context, {required String title}) async {
    final controller = TextEditingController();
    final result = await showDialog<String?>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: TextField(
            controller: controller,
            obscureText: true,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(hintText: 'PIN'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, null), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('OK')),
          ],
        );
      },
    );
    return result;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctl = ref.read(authControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Sign in')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Plex Kids (Spike)\n\n'
              'This will open Plex login in your browser.\n'
              'If it does not auto-complete, go to plex.tv/link and enter the code shown below.',
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
                      await ctl.signIn();
                    },
              child: state.isLoading ? const Text('Working...') : const Text('Sign in to Plex'),
            ),
            if (state.isLoading && state.linkCode != null) ...[
              const SizedBox(height: 12),
              Text('Link code', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 6),
              SelectableText(
                state.linkCode!,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(letterSpacing: 2),
              ),
              const SizedBox(height: 6),
              const SelectableText('https://plex.tv/link'),
            ],
            const SizedBox(height: 16),
            if (state.accountToken != null && state.homeUsers.isNotEmpty) ...[
              Text('Choose profile', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.separated(
                  itemCount: state.homeUsers.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final u = state.homeUsers[i];
                    final subtitle = <String>[];
                    if (u.isManaged) subtitle.add('managed');
                    if (u.isProtected) subtitle.add('PIN');

                    return ListTile(
                      title: Text(u.title),
                      subtitle: subtitle.isEmpty ? null : Text(subtitle.join(' • ')),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: state.isLoading
                          ? null
                          : () async {
                              String? pin;
                              if (u.isProtected) {
                                pin = await _promptForPin(context, title: 'Enter PIN for ${u.title}');
                                if (pin == null) return;
                              }

                              await ctl.selectHomeUser(userId: u.id, pin: pin);
                            },
                    );
                  },
                ),
              ),
            ] else ...[
              const Spacer(),
            ],
            const SizedBox(height: 12),
            Text('Server: ${state.serverName ?? '-'}'),
            Text('Base URL: ${state.serverBaseUrl ?? '-'}'),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () async {
                await ctl.signOut();
              },
              child: const Text('Clear session'),
            ),
          ],
        ),
      ),
    );
  }
}
