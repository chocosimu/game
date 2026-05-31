import 'package:flutter/material.dart';

import 'game_screen.dart';

void main() {
  runApp(const RoguelikeApp());
}

/// アプリの入口。トルネコ3風ローグライク（第一段階：地図生成＋移動）。
class RoguelikeApp extends StatelessWidget {
  const RoguelikeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dungeon',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6750A4),
          brightness: Brightness.dark,
        ),
      ),
      home: const GameScreen(),
    );
  }
}
