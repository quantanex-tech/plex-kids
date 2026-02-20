import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'src/ui/plex_spike_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load app/.env if present. We keep this purely for local dev so you can
  // validate Plex connectivity without committing secrets.
  await dotenv.load(fileName: '.env', isOptional: true);

  runApp(const ProviderScope(child: PlexKidsApp()));
}

class PlexKidsApp extends StatelessWidget {
  const PlexKidsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Plex Kids',
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo)),
      home: const PlexSpikeScreen(),
    );
  }
}
