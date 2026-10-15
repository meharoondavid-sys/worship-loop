import 'package:flutter/material.dart';

void main() {
  runApp(const WorshipLoopApp());
}

class WorshipLoopApp extends StatelessWidget {
  const WorshipLoopApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Worship Loop',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF82B5FF),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF0B1018),
        useMaterial3: true,
      ),
      home: const RestartHomePage(),
    );
  }
}

class RestartHomePage extends StatelessWidget {
  const RestartHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.graphic_eq, size: 56, color: Color(0xFF82B5FF)),
              SizedBox(height: 16),
              Text(
                'Worship Loop',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'Clean restart. We will build the mixer from the ground up.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
