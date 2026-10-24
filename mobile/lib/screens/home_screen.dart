// Gavin - Opens ApolLens on the camera without selecting an item first.
import 'package:flutter/material.dart';
import 'package:apollens/screens/camera_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ApolLens')),
      // Keep the camera and status readable on smaller screens.
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'Point your camera at the item',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          const Card(
            child: SizedBox(height: 320, child: Center(child: CameraScreen())),
          ),
          const SizedBox(height: 24),
          const Text('Item recognition unavailable'),
          const SizedBox(height: 8),
          const Text('Guidance will appear after the item is identified.'),
        ],
      ),
    );
  }
}
