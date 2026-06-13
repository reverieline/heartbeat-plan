import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const ProviderScope(child: RhrApp()));
}

class RhrApp extends StatelessWidget {
  const RhrApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RHR Trainer',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.red,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
