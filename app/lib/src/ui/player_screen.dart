import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../plex/plex_media_models.dart';
import '../plex/plex_url.dart';
import '../providers.dart';

class PlayerScreen extends ConsumerStatefulWidget {
  final PlexMediaItem item;

  const PlayerScreen({super.key, required this.item});

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  VideoPlayerController? _controller;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final client = ref.read(plexClientProvider);
      final auth = ref.read(authControllerProvider);

      if (client == null || auth.userToken == null || auth.serverBaseUrl == null) {
        throw StateError('Not connected to Plex');
      }

      final partKey = await client.getFirstPartKey(ratingKey: widget.item.ratingKey);
      final url = PlexUrl.absolute(baseUrl: auth.serverBaseUrl!, path: partKey);

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
        _controller = ctl;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ctl = _controller;

    return Scaffold(
      appBar: AppBar(title: Text(widget.item.title)),
      body: Center(
        child: _error != null
            ? Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Playback error: $_error'),
              )
            : ctl == null
                ? const CircularProgressIndicator()
                : Column(
                    children: [
                      AspectRatio(
                        aspectRatio: ctl.value.aspectRatio,
                        child: VideoPlayer(ctl),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        children: [
                          FilledButton.icon(
                            onPressed: () {
                              setState(() {
                                ctl.value.isPlaying ? ctl.pause() : ctl.play();
                              });
                            },
                            icon: Icon(ctl.value.isPlaying ? Icons.pause : Icons.play_arrow),
                            label: Text(ctl.value.isPlaying ? 'Pause' : 'Play'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () async {
                              await ctl.seekTo(Duration.zero);
                              await ctl.play();
                              setState(() {});
                            },
                            icon: const Icon(Icons.replay),
                            label: const Text('Restart'),
                          ),
                        ],
                      ),
                    ],
                  ),
      ),
    );
  }
}
