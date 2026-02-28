import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';

class ProfileAndLibraryScreen extends ConsumerStatefulWidget {
  const ProfileAndLibraryScreen({super.key});

  @override
  ConsumerState<ProfileAndLibraryScreen> createState() => _ProfileAndLibraryScreenState();
}

class _ProfileAndLibraryScreenState extends ConsumerState<ProfileAndLibraryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = ref.read(authControllerProvider);
      if (auth.homeUsers.isEmpty) {
        ref.read(authControllerProvider.notifier).loadHomeUsers();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final users = auth.homeUsers;

    final libsAsync = ref.watch(plexLibrariesProvider);
    final selectedLib = ref.watch(selectedLibraryProvider);

    final hasUnprotected = users.any((u) => !u.isProtected);

    return Scaffold(
      appBar: AppBar(title: const Text('Profiles & Libraries')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Current profile', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              child: Text((auth.activeUserTitle ?? 'U').characters.first.toUpperCase()),
            ),
            title: Text(auth.activeUserTitle ?? 'Unknown'),
            subtitle: Text(auth.serverName ?? ''),
          ),
          const SizedBox(height: 16),

          Text('Switch profile', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (users.isEmpty)
            const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()))
          else ...[
            if (hasUnprotected) ...[
              Text(
                'Some profiles are not PIN protected. Consider adding a PIN in Plex Home settings.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 8),
            ],
            ...users.map((u) {
              final selected = auth.activeUserId == u.id;
              return ListTile(
                leading: CircleAvatar(child: Text(u.title.characters.first.toUpperCase())),
                title: Text(u.title),
                subtitle: (u.isManaged || u.isProtected)
                    ? Text([
                        if (u.isManaged) 'managed',
                        if (u.isProtected) 'PIN',
                      ].join(' • '))
                    : null,
                trailing: selected ? const Icon(Icons.check) : const Icon(Icons.chevron_right),
                onTap: auth.isLoading
                    ? null
                    : () async {
                        await ref.read(authControllerProvider.notifier).selectHomeUser(userId: u.id);
                        ref.invalidate(onDeckProvider);
                        ref.invalidate(plexLibrariesProvider);
                        ref.invalidate(selectedLibraryProvider);
                        if (context.mounted) Navigator.pop(context);
                      },
              );
            }),
          ],

          const Divider(height: 32),

          Text('Library', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          libsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(12),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, st) => Text('Error: $e'),
            data: (libs) {
              if (libs.isEmpty) return const Text('No TV/Movie libraries found.');

              final lib = selectedLib ?? libs.first;
              if (selectedLib == null) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  ref.read(selectedLibraryProvider.notifier).state = lib;
                });
              }

              return DropdownButtonFormField<String>(
                initialValue: lib.id,
                decoration: const InputDecoration(
                  labelText: 'Active library',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final l in libs)
                    DropdownMenuItem(
                      value: l.id,
                      child: Text('${l.title} (${l.type})'),
                    ),
                ],
                onChanged: (id) {
                  final next = libs.firstWhere((l) => l.id == id);
                  ref.read(selectedLibraryProvider.notifier).state = next;
                  ref.invalidate(onDeckProvider);
                  ref.invalidate(recentlyAddedProvider(next.id));
                  ref.invalidate(randomPicksProvider(next.id));
                },
              );
            },
          ),

          const Divider(height: 32),

          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Log out & re-link Plex'),
            subtitle: const Text('Clears tokens and returns to link screen'),
            onTap: () async {
              final ok = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Log out?'),
                      content: const Text('This will clear the Plex session and require re-linking.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Log out')),
                      ],
                    ),
                  ) ??
                  false;

              if (!ok) return;

              await ref.read(authControllerProvider.notifier).signOut();
              ref.invalidate(onDeckProvider);
              ref.invalidate(plexLibrariesProvider);
              ref.invalidate(selectedLibraryProvider);

              if (context.mounted) {
                Navigator.pop(context);
              }
            },
          ),
        ],
      ),
    );
  }
}
