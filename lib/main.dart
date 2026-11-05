import 'package:flutter/material.dart';
import 'game_screen.dart';

void main() {
  runApp(const ChessApp());
}

class ChessApp extends StatelessWidget {
  const ChessApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFFFAF6EE), // warm ivory
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFC1694F)),
      ),
      home: const GameScreen(),
    );
  }
}