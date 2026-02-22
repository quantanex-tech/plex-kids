import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'src/ui/auth_spike_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load app/.env if present. We keep this purely for local dev so you can
  // validate Plex connectivity without committing secrets.
  //
  // On some setups an empty .env may exist; flutter_dotenv throws
  // EmptyEnvFileError in that case. We intentionally ignore dotenv failures
  // because the real path is Plex web auth.
  try {
    await dotenv.load(fileName: '.env', isOptional: true);
  } catch (_) {
    // ignore
  }

  runApp(const PlexKidsRoot());
}

class PlexKidsRoot extends StatelessWidget {
  const PlexKidsRoot({super.key});

  @override
  Widget build(BuildContext context) {
    return const ProviderScope(child: PlexKidsApp());
  }
}

class PlexKidsApp extends StatelessWidget {
  const PlexKidsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Plex Kids',
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo)),
      home: const AuthSpikeScreen(),
    );
  }
}
