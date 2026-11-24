import 'package:flutter/foundation.dart';
import '../models/product.dart';
import '../models/analysis_result.dart';
import '../services/product_service.dart';
import '../services/analysis_service.dart';

enum ScanStage {
  idle,
  lookingUpProduct,
  notFound,
  analyzing,
  result,
  error,
  awaitingNutritionPhoto, // NEW - ingredients captured, prompting for nutrition photo
}

/// Drives the barcode-scan -> product-detail -> analyzing -> result flow,
/// and the OCR-camera -> review -> analyzing -> result flow.
class ScanProvider extends ChangeNotifier {
  final _productService = ProductService();
  final _analysisService = AnalysisService();

  ScanStage stage = ScanStage.idle;
  String category = 'food'; // 'food' | 'drinks'
  Product? product;
  AnalysisResult? result;
  String? ocrIngredientsText;
  String? errorMessage;
  String? lastBarcode;

  // NEW - holds the ingredients photo while the user is prompted to also
  // capture the nutrition table. Cleared once the two-photo analysis
  // completes (success or failure) or the flow is reset.
  Uint8List? pendingIngredientsImage;

  // NEW - when the OCR flow is started from a known product (e.g. a
  // barcode-resolved product with missing ingredients/nutrition), this
  // carries the product's real name through to the OCR result/history
  // instead of the generic "Scanned Label" fallback.
  String? productNameOverride;

  void setCategory(String value) {
    category = value;
    notifyListeners();
  }

  void reset() {
    stage = ScanStage.idle;
    product = null;
    result = null;
    ocrIngredientsText = null;
    errorMessage = null;
    pendingIngredientsImage = null;
    productNameOverride = null;
    notifyListeners();
  }

  Future<void> lookupBarcode(String barcode) async {
    lastBarcode = barcode;
    stage = ScanStage.lookingUpProduct;
    notifyListeners();
    try {
      product = await _productService.lookupBarcode(barcode);
      stage = ScanStage.idle; // caller navigates to product-detail screen
      notifyListeners();
    } on ProductNotFoundException {
      stage = ScanStage.notFound;
      notifyListeners();
    } catch (e) {
      errorMessage = e.toString();
      stage = ScanStage.error;
      notifyListeners();
    }
  }

  Future<void> analyzeCurrentProduct() async {
    if (product == null) return;
    stage = ScanStage.analyzing;
    notifyListeners();
    try {
      result = await _analysisService.analyzeProduct(product!, category: category);
      stage = ScanStage.result;
    } catch (e) {
      errorMessage = e.toString();
      stage = ScanStage.error;
    }
    notifyListeners();
  }

  Future<void> analyzeOcrImage(Uint8List imageBytes) async {
    stage = ScanStage.analyzing;
    notifyListeners();
    try {
      final outcome = await _analysisService.analyzeImage(
        imageBytes,
        category: category,
        productName: productNameOverride ?? 'Scanned Label',
      );
      result = outcome.result;
      ocrIngredientsText = outcome.ingredientsText;
      stage = ScanStage.result;
    } catch (e) {
      errorMessage = e.toString();
      stage = ScanStage.error;
    }
    notifyListeners();
  }

  /// NEW - Step 1 of the two-photo flow: store the reviewed ingredients
  /// photo and move to the "now scan nutrition" prompt, without calling
  /// the backend yet.
  void submitIngredientsPhoto(Uint8List imageBytes) {
    pendingIngredientsImage = imageBytes;
    stage = ScanStage.awaitingNutritionPhoto;
    notifyListeners();
  }

  /// NEW - Step 2 of the two-photo flow: send both photos together.
  /// [nutritionImageBytes] is optional - if the user skips it, analysis
  /// proceeds with ingredients only.
  Future<void> analyzeTwoImages({Uint8List? nutritionImageBytes}) async {
    if (pendingIngredientsImage == null) return;
    stage = ScanStage.analyzing;
    notifyListeners();
    try {
          final outcome = await _analysisService.analyzeTwoImages(
        pendingIngredientsImage!,
        nutritionImageBytes: nutritionImageBytes,
        category: category,
        productName: productNameOverride ?? 'Scanned Label',
      );
      result = outcome.result;
      ocrIngredientsText = outcome.ingredientsText;
      stage = ScanStage.result;
    } catch (e) {
      errorMessage = e.toString();
      stage = ScanStage.error;
    }
    pendingIngredientsImage = null;
    notifyListeners();
  }
}