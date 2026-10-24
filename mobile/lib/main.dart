// Gavin - App entry point and theme.
// Starts the Flutter interface for ApolLens.
import 'package:flutter/material.dart';
import 'package:apollens/screens/home_screen.dart';

void main() => runApp(const ApolLensApp());

class ApolLensApp extends StatelessWidget {
  const ApolLensApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ApolLens',
      // Keep the shared colors here as more screens are added.
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFB3452E)),
        scaffoldBackgroundColor: const Color(0xFFF4F3EF),
      ),
      home: const HomeScreen(),
    );
  }
}
