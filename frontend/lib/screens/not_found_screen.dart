import 'package:flutter/material.dart';
import '../core/theme.dart';
import 'ocr_camera_screen.dart';

class NotFoundScreen extends StatelessWidget {
  final String barcode;
  const NotFoundScreen({super.key, required this.barcode});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Product Not Found')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: const BoxDecoration(color: AppColors.amberLight, shape: BoxShape.circle),
              child: const Icon(Icons.search_off_rounded, color: AppColors.amber, size: 40),
            ),
            const SizedBox(height: 20),
            const Text('No product found',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.ink)),
            const SizedBox(height: 8),
            Text(
              "We couldn't find barcode $barcode in the product database. "
              "You can instead scan the ingredients label directly.",
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.muted, height: 1.5),
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              icon: const Icon(Icons.document_scanner_outlined),
              label: const Text('Scan Ingredients Label'),
              onPressed: () {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const OcrCameraScreen()),
                );
              },
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Try scanning again'),
            ),
          ],
        ),
      ),
    );
  }
}
