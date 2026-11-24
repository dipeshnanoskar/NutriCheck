import 'dart:typed_data';
import '../core/api_client.dart';
import '../models/analysis_result.dart';
import '../models/product.dart';

class OcrAnalysisOutcome {
  final AnalysisResult result;
  final String ingredientsText;
  OcrAnalysisOutcome({required this.result, required this.ingredientsText});
}

class AnalysisService {
  final _api = ApiClient.instance;

  Future<AnalysisResult> analyzeProduct(Product product, {String category = 'food'}) async {
    final data = await _api.post('/analyze/product', body: {
      'name': product.name,
      'brand': product.brand,
      'image': product.image,
      'barcode': product.barcode,
      'ingredients': product.ingredients,
      'nutrition': product.nutrition.toJson(),
      'category': category,
    });
    return AnalysisResult.fromJson(data['result']);
  }
  Future<OcrAnalysisOutcome> analyzeImage(
    Uint8List imageBytes, {
    String filename = 'label.jpg',
    String category = 'food',
    String productName = 'Scanned Label',
  }) async {
    final data = await _api.postMultipart(
      '/analyze/ocr',
      fileBytes: imageBytes,
      filename: filename,
      fields: {'category': category, 'name': productName},
    );
    return OcrAnalysisOutcome(
      result: AnalysisResult.fromJson(data['result']),
      ingredientsText: data['ingredients_text'] ?? '',
    );
  }

  /// Two-photo OCR flow: ingredients label + nutrition table.
  /// [nutritionImageBytes] is optional - if null, analysis proceeds with
  /// ingredients only (matches the backend's optional nutrition_image).
  Future<TwoPhotoOcrOutcome> analyzeTwoImages(
    Uint8List ingredientsImageBytes, {
    Uint8List? nutritionImageBytes,
    String category = 'food',
    String productName = 'Scanned Label',
  }) async {
    final files = {
      'ingredients_image': (bytes: ingredientsImageBytes, filename: 'ingredients.jpg'),
      if (nutritionImageBytes != null)
        'nutrition_image': (bytes: nutritionImageBytes, filename: 'nutrition.jpg'),
    };
    final data = await _api.postMultipartFiles(
      '/analyze/ocr-full',
      files: files,
      fields: {'category': category, 'name': productName},
    );
    return TwoPhotoOcrOutcome(
      result: AnalysisResult.fromJson(data['result']),
      ingredientsText: data['ingredients_text'] ?? '',
    );
  }
}

class TwoPhotoOcrOutcome {
  final AnalysisResult result;
  final String ingredientsText;
  TwoPhotoOcrOutcome({required this.result, required this.ingredientsText});
}