import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../plex/plex_media_models.dart';
import '../plex/plex_url.dart';
import '../providers.dart';

class PlayerWithRailScreen extends ConsumerStatefulWidget {
  final PlexMediaItem initialItem;

  const PlayerWithRailScreen({super.key, required this.initialItem});

  @override
  ConsumerState<PlayerWithRailScreen> createState() => _PlayerWithRailScreenState();
}

class _PlayerWithRailScreenState extends ConsumerState<PlayerWithRailScreen> {
  VideoPlayerController? _controller;
  Object? _error;

  late PlexMediaItem _current;

  bool _chromeVisible = false;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    _current = widget.initialItem;
    _loadAndPlay(_current);
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  void _toggleChrome() {
    setState(() {
      _chromeVisible = !_chromeVisible;
    });

    _hideTimer?.cancel();
    if (_chromeVisible) {
      _hideTimer = Timer(const Duration(seconds: 4), () {
        if (!mounted) return;
        setState(() {
          _chromeVisible = false;
        });
      });
    }
  }

  Future<void> _togglePlayPause() async {
    final ctl = _controller;
    if (ctl == null) return;

    if (ctl.value.isPlaying) {
      await ctl.pause();
    } else {
      await ctl.play();
    }

    if (!mounted) return;
    setState(() {});
  }

  Future<void> _loadAndPlay(PlexMediaItem item) async {
    setState(() {
      _error = null;
    });

    final client = ref.read(plexClientProvider);
    final auth = ref.read(authControllerProvider);

    if (client == null || auth.userToken == null || auth.serverBaseUrl == null) {
      setState(() {
        _error = StateError('Not connected to Plex');
      });
      return;
    }

    try {
      final partKey = await client.getFirstPartKey(ratingKey: item.ratingKey);
      final url = PlexUrl.absolute(baseUrl: auth.serverBaseUrl!, path: partKey);

      final old = _controller;
      final ctl = VideoPlayerController.networkUrl(
        Uri.parse(url),
        httpHeaders: {
          'X-Plex-Token': auth.userToken!,
        },
      );

      await ctl.initialize();
      await ctl.play();

      if (!mounted) {
        await ctl.dispose();
        return;
      }

      setState(() {
        _current = item;
        _controller = ctl;
      });

      await old?.dispose();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ctl = _controller;

    final selectedLibrary = ref.watch(selectedLibraryProvider);
    final onDeckAsync = ref.watch(onDeckProvider);

    final mediaType = (selectedLibrary?.type == 'show') ? 'episode' : 'movie';

    final filteredOnDeck = onDeckAsync.whenData((items) {
      final byType = items.where((it) => it.type == mediaType).toList(growable: false);
      if (selectedLibrary == null) return byType;

      final matchingLibrary = byType.where((it) => it.librarySectionId == selectedLibrary.id).toList(growable: false);
      return matchingLibrary.isNotEmpty ? matchingLibrary : byType;
    });

    final player = (ctl == null)
        ? const Center(child: CircularProgressIndicator())
        : Stack(
            alignment: Alignment.center,
            children: [
              AspectRatio(
                aspectRatio: ctl.value.aspectRatio,
                child: VideoPlayer(ctl),
              ),
              if (_chromeVisible)
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () async {
                    // When chrome is visible, a tap on the player toggles play/pause.
                    // (Tap outside the player still toggles chrome.)
                    await _togglePlayPause();
                  },
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.10),
                    child: AnimatedScale(
                      duration: const Duration(milliseconds: 120),
                      scale: 1.0,
                      child: Icon(
                        ctl.value.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                        color: Colors.white.withValues(alpha: 0.92),
                        size: 96,
                      ),
                    ),
                  ),
                ),
            ],
          );

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: _chromeVisible
          ? AppBar(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              title: Text(
                _current.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            )
          : null,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _toggleChrome,
        child: SafeArea(
          child: _error != null
              ? Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('Playback error: $_error', style: const TextStyle(color: Colors.white)),
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    const railBlockHeight = 140.0; // rail + spacing
                    final fullHeight = constraints.maxHeight;
                    final playerHeight = _chromeVisible ? (fullHeight - railBlockHeight).clamp(180.0, fullHeight) : fullHeight;

                    return Stack(
                      children: [
                        Column(
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 220),
                              curve: Curves.easeOut,
                              height: playerHeight,
                              width: double.infinity,
                              child: Center(child: player),
                            ),
                            if (_chromeVisible) ...[
                              const SizedBox(height: 10),
                              _ContinueWatchingRail(
                                asyncItems: filteredOnDeck,
                                onPick: (it) => _loadAndPlay(it),
                              ),
                            ],
                          ],
                        ),
                        if (_chromeVisible)
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: IgnorePointer(
                              child: Container(
                                height: railBlockHeight + 40,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.black.withValues(alpha: 0.0),
                                      Colors.black.withValues(alpha: 0.55),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
        ),
      ),
    );
  }
}

class _ContinueWatchingRail extends StatelessWidget {
  final AsyncValue<List<PlexMediaItem>> asyncItems;
  final void Function(PlexMediaItem) onPick;

  const _ContinueWatchingRail({required this.asyncItems, required this.onPick});

  @override
  Widget build(BuildContext context) {
    return asyncItems.when(
      loading: () => const SizedBox(
        height: 110,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, st) => Padding(
        padding: const EdgeInsets.all(12),
        child: Text('Error: $e', style: const TextStyle(color: Colors.white)),
      ),
      data: (items) {
        if (items.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(12),
            child: Text('Nothing else to watch.', style: TextStyle(color: Colors.white70)),
          );
        }

        return SizedBox(
          height: 120,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (context, index) => const SizedBox(width: 10),
            itemBuilder: (context, i) {
              final it = items[i];
              return _SmallTile(item: it, onTap: () => onPick(it));
            },
          ),
        );
      },
    );
  }
}

class _SmallTile extends ConsumerWidget {
  final PlexMediaItem item;
  final VoidCallback onTap;

  const _SmallTile({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);

    String? thumbUrl;
    if (item.thumb != null && auth.serverBaseUrl != null && auth.userToken != null) {
      thumbUrl = '${auth.serverBaseUrl}${item.thumb}?X-Plex-Token=${auth.userToken}';
    }

    return SizedBox(
      width: 140,
      child: Material(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: thumbUrl == null
                        ? Container(
                            color: Colors.black,
                            child: const Center(
                              child: Icon(Icons.play_circle_outline, color: Colors.white70),
                            ),
                          )
                        : Image.network(
                            thumbUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Container(
                              color: Colors.black,
                              child: const Center(
                                child: Icon(Icons.broken_image_outlined, color: Colors.white70),
                              ),
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 12, height: 1.1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
