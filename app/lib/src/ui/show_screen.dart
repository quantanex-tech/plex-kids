import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import 'player_screen.dart';

class ShowScreen extends ConsumerWidget {
  final String showRatingKey;
  final String showTitle;

  const ShowScreen({
    super.key,
    required this.showRatingKey,
    required this.showTitle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final epsAsync = ref.watch(showEpisodesProvider(showRatingKey));

    return Scaffold(
      appBar: AppBar(title: Text(showTitle)),
      body: epsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => SingleChildScrollView(child: Text('Error: $e\n\n$st')),
        data: (eps) {
          if (eps.isEmpty) return const Center(child: Text('No episodes found.'));

          return ListView.separated(
            itemCount: eps.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final ep = eps[i];
              return ListTile(
                title: Text(ep.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text('S${ep.parentIndex ?? 0} • E${ep.index ?? 0}'),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => PlayerScreen(item: ep)),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
