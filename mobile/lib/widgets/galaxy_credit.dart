// Gavin - Keep the real Hubble image and its full credit available offline.
import 'package:flutter/material.dart';

const galaxyImageAsset = 'assets/whirlpool.jpg';

class GalaxyCredit extends StatelessWidget {
  const GalaxyCredit({super.key});

  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: () => showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Whirlpool Galaxy · M51'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Image.asset(galaxyImageAsset, height: 180, fit: BoxFit.contain),
              const SizedBox(height: 16),
              const Text(
                'NASA, ESA, S. Beckwith (STScI), and The Hubble Heritage Team (STScI/AURA)',
              ),
              const SizedBox(height: 12),
              const Text('Cropped and animated for this app. CC BY 4.0.'),
              const SizedBox(height: 12),
              const SelectableText('https://esahubble.org/images/heic0506a/'),
              const SizedBox(height: 8),
              const SelectableText(
                'https://creativecommons.org/licenses/by/4.0/',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    ),
    child: const Text('Galaxy image credit'),
  );
}
