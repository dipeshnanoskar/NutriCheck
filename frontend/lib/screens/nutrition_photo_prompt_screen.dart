import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../providers/scan_provider.dart';
import 'ocr_review_screen.dart';
import 'result_screen.dart';

/// Shown after the ingredients photo is confirmed. Prompts the user to
/// also scan the nutrition table (optional - "Skip" analyzes with
/// ingredients only, matching the backend's optional nutrition_image).
class NutritionPhotoPromptScreen extends StatefulWidget {
  const NutritionPhotoPromptScreen({super.key});

  @override
  State<NutritionPhotoPromptScreen> createState() => _NutritionPhotoPromptScreenState();
}

class _NutritionPhotoPromptScreenState extends State<NutritionPhotoPromptScreen> {
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

      final cropped = await ImageCropper().cropImage(
        sourcePath: file.path,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Nutrition Table',
            toolbarColor: AppColors.greenPrimary,
            toolbarWidgetColor: Colors.white,
            lockAspectRatio: false,
          ),
          IOSUiSettings(
            title: 'Crop Nutrition Table',
          ),
        ],
      );
      if (cropped == null) {
        setState(() => _busy = false);
        return;
      }

      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => OcrReviewScreen(
            imageFile: File(cropped.path),
            purpose: OcrReviewPurpose.nutrition,
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _skip() async {
    setState(() => _busy = true);
    final scan = context.read<ScanProvider>();
    await scan.analyzeTwoImages(); // no nutrition photo - ingredients only
    if (!mounted) return;
    setState(() => _busy = false);

    if (scan.stage == ScanStage.result) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const ResultScreen()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(scan.errorMessage ?? 'Could not analyze the image')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: const Text('Scan Nutrition Information'),
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
                child: const Icon(Icons.receipt_long_rounded, color: Colors.white54, size: 56),
              ),
              const SizedBox(height: 24),
              const Text(
                'Now scan the nutrition information.\nFit the table within the frame, keep it well lit and in focus.',
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
              const SizedBox(height: 12),
              TextButton(
                onPressed: _busy ? null : _skip,
                child: const Text(
                  'Skip - analyze ingredients only',
                  style: TextStyle(color: Colors.white70),
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