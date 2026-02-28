import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
              'Device link flow: generate a 4-character code, enter it on plex.tv/link, then continue.',
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
                      await ctl.generateLinkCode();
                    },
              child: state.isLoading ? const Text('Working...') : const Text('Generate link code'),
            ),
            if (state.awaitingLink && state.linkCode != null) ...[
              const SizedBox(height: 12),
              Text('Link code', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 6),
              SelectableText(
                state.linkCode!,
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(letterSpacing: 6),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  OutlinedButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: state.linkCode!));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Code copied')));
                      }
                    },
                    icon: const Icon(Icons.copy),
                    label: const Text('Copy code'),
                  ),
                  FilledButton.icon(
                    onPressed: () async {
                      await ctl.openLinkPage();
                    },
                    icon: const Icon(Icons.open_in_browser),
                    label: const Text('Open plex.tv/link'),
                  ),
                  FilledButton.icon(
                    onPressed: state.isLoading
                        ? null
                        : () async {
                            await ctl.startPollingForAccountToken();
                          },
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text("I've linked it"),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '1) Copy the code\n'
                '2) Open plex.tv/link in your browser and enter it\n'
                '3) Tap "I\'ve linked it" to continue',
                style: Theme.of(context).textTheme.bodySmall,
              ),
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
