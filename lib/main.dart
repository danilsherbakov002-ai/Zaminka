import 'package:flutter/material.dart';
import 'screens/sound_effects_screen.dart';

void main() {
  runApp(const DirexApp());
}

class DirexApp extends StatelessWidget {
  const DirexApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Direx',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: const SoundEffectsScreen(
        trackId: 'demo_track_01',
        streamUrl: 'https://cdn.example.com/tracks/demo_track_01.mp3',
      ),
    );
  }
}
