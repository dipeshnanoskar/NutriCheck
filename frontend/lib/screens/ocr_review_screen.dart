import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../providers/scan_provider.dart';
import 'result_screen.dart';
import 'nutrition_photo_prompt_screen.dart';

/// What this review step is for - determines what happens when the user
/// taps "Analyze" / "Use Photo".
enum OcrReviewPurpose { ingredients, nutrition }

class OcrReviewScreen extends StatefulWidget {
  final File imageFile;
  final OcrReviewPurpose purpose;

  const OcrReviewScreen({
    super.key,
    required this.imageFile,
    this.purpose = OcrReviewPurpose.ingredients,
  });

  @override
  State<OcrReviewScreen> createState() => _OcrReviewScreenState();
}

class _OcrReviewScreenState extends State<OcrReviewScreen> {
  bool _analyzing = false;

  Future<void> _confirm() async {
    final scan = context.read<ScanProvider>();
    final bytes = await widget.imageFile.readAsBytes();

    if (widget.purpose == OcrReviewPurpose.ingredients) {
      // Step 1 of 2: store the ingredients photo, then prompt for the
      // nutrition table photo - no backend call yet.
      scan.submitIngredientsPhoto(bytes);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const NutritionPhotoPromptScreen()),
      );
      return;
    }

    // Step 2 of 2: nutrition photo reviewed - send both photos together.
    setState(() => _analyzing = true);
    await scan.analyzeTwoImages(nutritionImageBytes: bytes);
    if (!mounted) return;
    setState(() => _analyzing = false);

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
    final isIngredients = widget.purpose == OcrReviewPurpose.ingredients;
    return Scaffold(
      appBar: AppBar(title: Text(isIngredients ? 'Review Photo' : 'Review Nutrition Photo')),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _analyzing ? null : () => Navigator.of(context).pop(),
                  child: const Text('Retake'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _analyzing ? null : _confirm,
                  child: _analyzing
                      ? const SizedBox(
                          height: 20, width: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text(isIngredients ? 'Use This Photo' : 'Analyze'),
                ),
              ),
            ],
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(kCardRadius),
                child: Image.file(widget.imageFile, fit: BoxFit.cover, width: double.infinity),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isIngredients
                  ? 'Make sure the ingredients text is clear and readable before continuing.'
                  : 'Make sure the nutrition table is clear and readable before analyzing.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.muted, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}