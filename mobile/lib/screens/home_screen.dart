// Gavin - Equipment selection for ApolLens inspections.
import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ApolLens')),
      // Scroll the equipment list on smaller screens.
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: const [
          Text('Equipment', style: TextStyle(fontSize: 28)),
          SizedBox(height: 20),
          Card(
            child: ListTile(
              leading: Icon(Icons.air),
              title: Text('HEPA air purifier'),
              subtitle: Text('Guided inspection'),
            ),
          ),
        ],
      ),
    );
  }
}
