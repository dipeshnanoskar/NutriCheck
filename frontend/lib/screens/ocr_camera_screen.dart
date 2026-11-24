import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import '../core/theme.dart';
import 'ocr_review_screen.dart';

/// Captures a photo of an ingredients label using the device camera
/// (or picks one from the gallery) for OCR-based analysis.
class OcrCameraScreen extends StatefulWidget {
  const OcrCameraScreen({super.key});

  @override
  State<OcrCameraScreen> createState() => _OcrCameraScreenState();
}

class _OcrCameraScreenState extends State<OcrCameraScreen> {
  final _picker = ImagePicker();
  bool _busy = false;

  Future<void> _capture(ImageSource source) async {
    setState(() => _busy = true);
    try {
      final file = await _picker.pickImage(source: source, imageQuality: 90);
      if (file == null) {
        setState(() => _busy = false);
        return;
      }

      // Let the user crop out background clutter before OCR - improves
      // accuracy and lets them exclude anything that isn't the label.
      final cropped = await ImageCropper().cropImage(
        sourcePath: file.path,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Ingredients Label',
            toolbarColor: AppColors.greenPrimary,
            toolbarWidgetColor: Colors.white,
            lockAspectRatio: false,
          ),
          IOSUiSettings(
            title: 'Crop Ingredients Label',
          ),
        ],
      );
      if (cropped == null) {
        // User cancelled the crop - stay on this screen.
        setState(() => _busy = false);
        return;
      }

      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => OcrReviewScreen(imageFile: File(cropped.path))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: const Text('Scan Ingredients Label'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white38, width: 2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.document_scanner_outlined, color: Colors.white54, size: 56),
              ),
              const SizedBox(height: 24),
              const Text(
                'Fit the ingredients text within the frame,\nkeep it well lit and in focus.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.5),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                icon: const Icon(Icons.camera_alt_rounded),
                label: const Text('Take Photo'),
                onPressed: _busy ? null : () => _capture(ImageSource.camera),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.greenPrimary,
                  minimumSize: const Size(double.infinity, 52),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.photo_library_outlined, color: Colors.white),
                label: const Text('Choose from Gallery', style: TextStyle(color: Colors.white)),
                onPressed: _busy ? null : () => _capture(ImageSource.gallery),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white38),
                  minimumSize: const Size(double.infinity, 52),
                ),
              ),
              if (_busy) const Padding(
                padding: EdgeInsets.only(top: 20),
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
