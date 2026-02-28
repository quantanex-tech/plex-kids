import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';

class ProfileSwitcherSheet extends ConsumerWidget {
  const ProfileSwitcherSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
            if (hasUnprotected) ...[
              Text(
                'Some profiles are not PIN protected. Consider adding a PIN in Plex Home settings.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 8),
            ],
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: users.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final u = users[i];
                  final selected = auth.activeUserId == u.id;

                  return ListTile(
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
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
