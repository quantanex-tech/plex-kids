import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';

class ProfileSwitcherSheet extends ConsumerStatefulWidget {
  const ProfileSwitcherSheet({super.key});

  @override
  ConsumerState<ProfileSwitcherSheet> createState() => _ProfileSwitcherSheetState();
}

class _ProfileSwitcherSheetState extends ConsumerState<ProfileSwitcherSheet> {
  @override
  void initState() {
    super.initState();
    // Load users if we don't have them (e.g. after app restart).
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

    final hasUnprotected = users.any((u) => !u.isProtected);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Switch profile', style: Theme.of(context).textTheme.titleLarge),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            if (users.isEmpty) ...[
              const SizedBox(height: 12),
              const Center(child: CircularProgressIndicator()),
              const SizedBox(height: 12),
              Text(
                'Loading profiles…',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
              ),
            ] else ...[
              if (hasUnprotected) ...[
                Text(
                  'Some profiles are not PIN protected. Consider adding a PIN in Plex Home settings.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
                ),
                const SizedBox(height: 8),
              ],
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    ...List.generate(users.length, (i) {
                      final u = users[i];
                      final selected = auth.activeUserId == u.id;

                      return Column(
                        children: [
                          ListTile(
                            leading: CircleAvatar(
                              child: Text(u.title.isNotEmpty ? u.title.characters.first.toUpperCase() : '?'),
                            ),
                            title: Text(u.title),
                            subtitle: (u.isManaged || u.isProtected)
                                ? Text([
                                    if (u.isManaged) 'managed',
                                    if (u.isProtected) 'PIN',
                                  ].join(' • '))
                                : null,
                            trailing: selected ? const Icon(Icons.check) : const Icon(Icons.chevron_right),
                            onTap: () async {
                              await ref.read(authControllerProvider.notifier).selectHomeUser(userId: u.id);
                              // Refresh app data for the new user.
                              ref.invalidate(onDeckProvider);
                              ref.invalidate(plexLibrariesProvider);
                              ref.invalidate(selectedLibraryProvider);
                              if (context.mounted) Navigator.pop(context);
                            },
                          ),
                          const Divider(height: 1),
                        ],
                      );
                    }),
                    const SizedBox(height: 8),
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
                        // Clear cached app data.
                        ref.invalidate(onDeckProvider);
                        ref.invalidate(plexLibrariesProvider);
                        ref.invalidate(selectedLibraryProvider);

                        if (context.mounted) Navigator.pop(context);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
