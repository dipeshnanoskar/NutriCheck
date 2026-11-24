import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../providers/scan_provider.dart';
import 'analyzing_screen.dart';
import 'ocr_camera_screen.dart';

class ProductDetailScreen extends StatelessWidget {
  const ProductDetailScreen({super.key});

  /// Splits a raw ingredients string into individual ingredient lines.
  /// Splits on top-level commas/semicolons only - text inside
  /// parentheses or brackets (e.g. "Vegetable oil (palm, sunflower)")
  /// is kept together as part of that ingredient's description.
  static List<String> _splitIngredients(String rawText) {
    // European ingredient lists often use a comma as a DECIMAL POINT
    // (e.g. "Cacao maigre 7,4%"). Protect digit-comma-digit patterns
    // before splitting so "7,4" isn't mistaken for a list separator.
    final text = rawText.replaceAllMapped(
      RegExp(r'(\d),(\d)'),
      (m) => '${m.group(1)}\u0001${m.group(2)}',
    );

    final List<String> result = [];
    int depth = 0;
    final buffer = StringBuffer();

    for (final rune in text.runes) {
      final char = String.fromCharCode(rune);
      if (char == '(' || char == '[') {
        depth++;
        buffer.write(char);
      } else if (char == ')' || char == ']') {
        depth--;
        buffer.write(char);
      } else if ((char == ',' || char == ';') && depth <= 0) {
        final piece = buffer.toString().trim();
        if (piece.isNotEmpty) result.add(piece);
        buffer.clear();
      } else {
        buffer.write(char);
      }
    }
    final last = buffer.toString().trim();
    if (last.isNotEmpty) result.add(last);

    // Restore protected decimal commas and capitalize each line.
    return result.map((e) {
      final restored = e.replaceAll('\u0001', ',');
      if (restored.isEmpty) return restored;
      return restored[0].toUpperCase() + restored.substring(1);
    }).toList();
  }

  /// True when every nutrition value is effectively zero/blank - a strong
  /// signal that Open Food Facts had no real nutrition data for this
  /// product, rather than the product genuinely having all-zero values.
  static bool _isNutritionEmpty(dynamic nutrition) {
    for (final entry in nutrition.entries) {
      final digits = RegExp(r'[\d.]+').firstMatch(entry.value.toString());
      final value = digits != null ? double.tryParse(digits.group(0)!) ?? 0 : 0;
      if (value > 0) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final scan = context.watch<ScanProvider>();
    final product = scan.product!;
    final ingredientLines = _splitIngredients(product.ingredients);
    final missingData = ingredientLines.isEmpty || _isNutritionEmpty(product.nutrition);

    return Scaffold(
      appBar: AppBar(title: const Text('Product Details')),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton.icon(
            icon: const Icon(Icons.insights_rounded),
            label: const Text('Analyze Suitability'),
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AnalyzingScreen()),
              );
            },
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: product.image.isNotEmpty
                  ? Image.network(product.image, width: 160, height: 160, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _imageFallback())
                  : _imageFallback(),
            ),
          ),
          const SizedBox(height: 20),
                Text(product.name,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.ink)),
          if (product.brand.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(product.brand,
                  textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted)),
            ),
          const SizedBox(height: 20),
          if (missingData)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppColors.amberLight,
                borderRadius: BorderRadius.circular(kCardRadius),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.info_outline_rounded, color: AppColors.amber, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "We couldn't find complete ingredient or nutrition details for this product.",
                          style: TextStyle(color: AppColors.ink, fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'For an accurate result, scan the ingredients label and nutrition table directly.',
                    style: TextStyle(color: AppColors.muted, fontSize: 12, height: 1.4),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.document_scanner_outlined, size: 18),
                      label: const Text('Scan Label Instead'),
                      onPressed: () {
                        scan.productNameOverride = product.name;
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const OcrCameraScreen()),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.greenPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          _sectionCard(
            title: 'Ingredients',
            child: ingredientLines.isEmpty
                ? const Text(
                    'No ingredient information available.',
                    style: TextStyle(color: AppColors.muted, height: 1.5),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (int i = 0; i < ingredientLines.length; i++)
                        Padding(
                          padding: EdgeInsets.only(bottom: i == ingredientLines.length - 1 ? 0 : 10),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.only(top: 6),
                                child: Icon(Icons.circle, size: 6, color: AppColors.greenPrimary),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  ingredientLines[i],
                                  style: const TextStyle(
                                    color: AppColors.ink,
                                    height: 1.4,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
          ),
          const SizedBox(height: 16),
          _sectionCard(
            title: 'Nutrition (per 100g/100ml)',
            child: Column(
              children: product.nutrition.entries
                  .map((e) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(e.key, style: const TextStyle(color: AppColors.muted)),
                            Text(e.value, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.ink)),
                          ],
                        ),
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(height: 90),
        ],
      ),
    );
  }

  Widget _imageFallback() => Container(
        width: 160,
        height: 160,
        color: AppColors.greenLight,
        child: const Icon(Icons.fastfood_rounded, color: AppColors.greenPrimary, size: 48),
      );

  Widget _sectionCard({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(kCardRadius),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}