import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'profile_switcher_sheet.dart';

import '../plex/plex_media_models.dart';
import '../plex/plex_models.dart';
import '../providers.dart';
import 'channel_badge.dart';
import 'player_with_rail_screen.dart';
import 'show_screen.dart';

class HomeRailsScreen extends ConsumerWidget {
  const HomeRailsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final libsAsync = ref.watch(plexLibrariesProvider);
    final onDeckAsync = ref.watch(onDeckProvider);
    final selected = ref.watch(selectedLibraryProvider);
    final auth = ref.watch(authControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Plex Kids'),
        leading: Padding(
          padding: const EdgeInsets.only(left: 8),
          child: IconButton(
            tooltip: 'Switch profile',
            onPressed: (auth.accountToken == null || auth.accountToken!.isEmpty)
                ? null
                : () {
                    showModalBottomSheet(
                      context: context,
                      showDragHandle: true,
                      isScrollControlled: true,
                      builder: (_) => const ProfileSwitcherSheet(),
                    );
                  },
            icon: CircleAvatar(
              child: Text(
                (auth.activeUserTitle ?? 'U').characters.first.toUpperCase(),
              ),
            ),
          ),
        ),
      ),
      body: libsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => SingleChildScrollView(child: Text('Error: $e\n\n$st')),
        data: (libs) {
          if (libs.isEmpty) {
            return const Center(child: Text('No TV/Movie libraries found.'));
          }

          final lib = selected ?? libs.first;
          if (selected == null) {
            // Set default once.
            WidgetsBinding.instance.addPostFrameCallback((_) {
              ref.read(selectedLibraryProvider.notifier).state = lib;
            });
          }

          final recentlyAsync = ref.watch(recentlyAddedProvider(lib.id));
          final randomAsync = ref.watch(randomPicksProvider(lib.id));

          final mediaType = lib.type == 'show' ? 'episode' : 'movie';

          final filteredOnDeckAsync = onDeckAsync.whenData((items) {
            final byType = items.where((it) => it.type == mediaType).toList(growable: false);

            // Prefer items that belong to the currently selected library if we can.
            final matchingLibrary = byType.where((it) => it.librarySectionId == lib.id).toList(growable: false);
            if (matchingLibrary.isNotEmpty) return matchingLibrary;

            return byType;
          });
          final filteredRecentlyAsync = recentlyAsync.whenData(
            (items) => items.where((it) => it.type == mediaType).toList(growable: false),
          );
          final filteredRandomAsync = randomAsync.whenData(
            (items) => items.where((it) => it.type == mediaType).toList(growable: false),
          );

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(onDeckProvider);
              ref.invalidate(recentlyAddedProvider(lib.id));
              ref.invalidate(randomPicksProvider(lib.id));
              ref.invalidate(plexLibrariesProvider);
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _LibraryPicker(libraries: libs, selected: lib),
                const SizedBox(height: 16),

                _RailSection(
                  title: 'Continue Watching',
                  asyncItems: filteredOnDeckAsync,
                ),
                const SizedBox(height: 16),

                _RailSection(
                  title: 'Recently Added • ${lib.title}',
                  asyncItems: filteredRecentlyAsync,
                ),
                const SizedBox(height: 16),

                _RailSection(
                  title: 'Random Picks • ${lib.title}',
                  asyncItems: filteredRandomAsync,
                ),
                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _LibraryPicker extends ConsumerWidget {
  final List<PlexLibrary> libraries;
  final PlexLibrary selected;

  const _LibraryPicker({required this.libraries, required this.selected});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<String>(
            initialValue: selected.id,
            decoration: const InputDecoration(
              labelText: 'Library',
              border: OutlineInputBorder(),
            ),
            items: [
              for (final l in libraries)
                DropdownMenuItem(
                  value: l.id,
                  child: Text('${l.title} (${l.type})'),
                ),
            ],
            onChanged: (id) {
              final lib = libraries.firstWhere((l) => l.id == id);
              ref.read(selectedLibraryProvider.notifier).state = lib;
            },
          ),
        ),
      ],
    );
  }
}

class _RailSection extends StatelessWidget {
  final String title;
  final AsyncValue<List<PlexMediaItem>> asyncItems;

  const _RailSection({required this.title, required this.asyncItems});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        asyncItems.when(
          loading: () => const SizedBox(
            height: 120,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, st) => Text('Error: $e'),
          data: (items) {
            if (items.isEmpty) {
              return const Text('Nothing here yet.');
            }

            return SizedBox(
              height: 190,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: items.length,
                separatorBuilder: (context, index) => const SizedBox(width: 12),
                itemBuilder: (context, i) {
                  final it = items[i];
                  return _MediaCard(
                    item: it,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => PlayerWithRailScreen(initialItem: it),
                        ),
                      );
                    },
                    onTapChannel: (it.grandparentRatingKey != null && it.grandparentTitle != null)
                        ? () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => ShowScreen(
                                  showRatingKey: it.grandparentRatingKey!,
                                  showTitle: it.grandparentTitle!,
                                ),
                              ),
                            );
                          }
                        : null,
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }
}

class _MediaCard extends ConsumerWidget {
  final PlexMediaItem item;
  final VoidCallback onTap;
  final VoidCallback? onTapChannel;

  const _MediaCard({required this.item, required this.onTap, this.onTapChannel});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);

    String? thumbUrl;
    if (item.thumb != null && auth.serverBaseUrl != null && auth.userToken != null) {
      // Build thumbnail URL with token.
      thumbUrl = '${auth.serverBaseUrl}${item.thumb}?X-Plex-Token=${auth.userToken}';
    }

    return SizedBox(
      width: 140,
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AspectRatio(
                  aspectRatio: 1, // YouTube Kids-ish square
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: thumbUrl == null
                              ? Container(
                                  color: Theme.of(context).colorScheme.surface,
                                  child: Center(
                                    child: Text(
                                      item.type.toUpperCase(),
                                      style: Theme.of(context).textTheme.labelSmall,
                                    ),
                                  ),
                                )
                              : Image.network(
                                  thumbUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => Container(
                                    color: Theme.of(context).colorScheme.surface,
                                    child: const Center(child: Icon(Icons.broken_image_outlined)),
                                  ),
                                ),
                        ),
                      ),
                      if (onTapChannel != null && item.grandparentThumb != null && auth.serverBaseUrl != null && auth.userToken != null)
                        Positioned(
                          left: 6,
                          bottom: 6,
                          child: ChannelBadge(
                            imageUrl: '${auth.serverBaseUrl}${item.grandparentThumb}?X-Plex-Token=${auth.userToken}',
                            onTap: onTapChannel!,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
