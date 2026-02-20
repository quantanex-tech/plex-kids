import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';

class PlexSpikeScreen extends ConsumerWidget {
  const PlexSpikeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cfg = ref.watch(appConfigProvider);
    final libraries = ref.watch(plexLibrariesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Plex connectivity spike'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              cfg.isConfigured
                  ? 'Configured: ${cfg.plexBaseUrl}'
                  : 'Not configured. Create app/.env from app/.env.example',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Expanded(
              child: libraries.when(
                data: (items) {
                  if (!cfg.isConfigured) {
                    return const Center(
                      child: Text('No .env config found (PLEX_BASE_URL / PLEX_TOKEN).'),
                    );
                  }
                  if (items.isEmpty) {
                    return const Center(child: Text('No libraries returned.'));
                  }
                  return ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (context, index) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final lib = items[i];
                      return ListTile(
                        title: Text(lib.title),
                        subtitle: Text('type=${lib.type}  id=${lib.id}'),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, st) => SingleChildScrollView(
                  child: Text('Error: $err\n\n$st'),
                ),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => ref.invalidate(plexLibrariesProvider),
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
            ),
          ],
        ),
      ),
    );
  }
}
