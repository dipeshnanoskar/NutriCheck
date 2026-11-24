import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../models/analysis_result.dart';
import '../models/history_item.dart';
import '../providers/scan_provider.dart';
import 'home_screen.dart';


/// Splits raw OCR ingredients text into individual items for bullet
/// display. Splits on commas, but keeps bracketed/parenthetical groups
/// together - e.g. "RAISING AGENTS [INS 503(ii), INS 500(ii)]" stays one
/// item instead of being split into three.
List<String> _splitIngredientItems(String text) {
  final items = <String>[];
  final buffer = StringBuffer();
  var depth = 0;

  for (final char in text.split('')) {
    if (char == '(' || char == '[') {
      depth++;
      buffer.write(char);
    } else if (char == ')' || char == ']') {
      depth = depth > 0 ? depth - 1 : 0;
      buffer.write(char);
    } else if (char == ',' && depth == 0) {
      final item = buffer.toString().trim();
      if (item.isNotEmpty) items.add(item);
      buffer.clear();
    } else {
      buffer.write(char);
    }
  }
  final last = buffer.toString().trim();
  if (last.isNotEmpty) items.add(last);

  return items;
}

class ResultScreen extends StatelessWidget {
  const ResultScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scan = context.watch<ScanProvider>();
    final result = scan.result!;
    final productName = scan.product?.name ?? 'Scanned Label';
    final image = scan.product?.image ?? '';

    return _ResultView(
      result: result,
      productName: productName,
      image: image,
      ingredientsText: scan.ocrIngredientsText ?? scan.product?.ingredients,
      onDone: () {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (route) => false,
        );
      },
    );
  }
}

/// Read-only result view rendered from a saved history item. Older history
/// entries saved before the health-condition feature existed simply have
/// no health_conditions data, so this resolves to an empty list - no crash.
class ResultScreenFromHistory extends StatelessWidget {
  final HistoryItem item;
  const ResultScreenFromHistory({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final result = AnalysisResult(
      overall: item.overall,
      ageGroups: item.ageGroups,
      flags: item.flags,
      nutritionConcerns: const [],
      healthConditions: item.healthConditions,
    );
    return _ResultView(
      result: result,
      productName: item.productName,
      image: item.image,
      ingredientsText: null,
      onDone: () => Navigator.of(context).pop(),
    );
  }
}

class _ResultView extends StatelessWidget {
  final AnalysisResult result;
  final String productName;
  final String image;
  final String? ingredientsText;
  final VoidCallback onDone;

  const _ResultView({
    required this.result,
    required this.productName,
    required this.image,
    required this.ingredientsText,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    final style = StatusStyle.forStatus(result.overall);

    return Scaffold(
      appBar: AppBar(title: const Text('Analysis Result')),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton(onPressed: onDone, child: const Text('Done')),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: style.bg,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                Icon(
                  result.overall == 'Avoid'
                      ? Icons.dangerous_rounded
                      : result.overall == 'Use Caution'
                          ? Icons.warning_amber_rounded
                          : Icons.check_circle_rounded,
                  color: style.fg,
                  size: 40,
                ),
                const SizedBox(height: 10),
                Text(result.overall,
                    style: TextStyle(color: style.fg, fontWeight: FontWeight.w700, fontSize: 20)),
                const SizedBox(height: 4),
                Text(productName,
                    textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted)),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text('By age group', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: AppColors.ink)),
          const SizedBox(height: 12),
          ...result.ageGroups.map(_ageGroupCard),

          // --- NEW: Health Conditions section - only rendered if non-empty ---
          if (result.healthConditions.isNotEmpty) ...[
            const SizedBox(height: 24),
            const Text('Health Conditions', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: AppColors.ink)),
            const SizedBox(height: 4),
            const Text(
              'General product information - not a personal diagnosis.',
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            ),
            const SizedBox(height: 12),
            ...result.healthConditions.map(_healthConditionCard),
          ],

          if (result.flags.isNotEmpty) ...[
            const SizedBox(height: 24),
            const Text('Ingredient flags', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: AppColors.ink)),
            const SizedBox(height: 12),
            ...result.flags.map((f) => _flagTile(f.ingredient, f.concern)),
          ],
          if (result.nutritionConcerns.isNotEmpty) ...[
            const SizedBox(height: 24),
            const Text('Nutrition concerns', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: AppColors.ink)),
            const SizedBox(height: 12),
            ...result.nutritionConcerns.map((n) => _flagTile('${n.label}: ${n.value}', n.concern)),
          ],
          if (ingredientsText != null && ingredientsText!.isNotEmpty) ...[
            const SizedBox(height: 24),
            const Text('Ingredients read', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: AppColors.ink)),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(kCardRadius),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _splitIngredientItems(ingredientsText!).map((item) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('•  ', style: TextStyle(color: AppColors.ink, height: 1.5)),
                        Expanded(
                          child: Text(item, style: const TextStyle(color: AppColors.ink, height: 1.5)),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
          const SizedBox(height: 90),
        ],
      ),
    );
  }

  Widget _ageGroupCard(dynamic ageGroup) {
    final style = StatusStyle.forStatus(ageGroup.status);
    IconData icon;
    switch (ageGroup.group) {
      case 'Child':
        icon = Icons.child_care_rounded;
        break;
      case 'Teenager':
        icon = Icons.face_retouching_natural_rounded;
        break;
      default:
        icon = Icons.person_rounded;
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(kCardRadius),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: style.bg, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: style.fg, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(ageGroup.group, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink)),
                    Text(ageGroup.status,
                        style: TextStyle(color: style.fg, fontWeight: FontWeight.w600, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(ageGroup.reason, style: const TextStyle(color: AppColors.muted, fontSize: 13, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// NEW - card for a single health-condition warning. Same visual
  /// language as the age-group cards, using a heart icon to distinguish
  /// "condition" warnings from "age" warnings at a glance.
  Widget _healthConditionCard(HealthConditionWarning w) {
    final style = StatusStyle.forStatus(w.severity);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(kCardRadius),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: style.bg, borderRadius: BorderRadius.circular(10)),
            child: Icon(Icons.monitor_heart_rounded, color: style.fg, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(w.conditionName,
                          style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink)),
                    ),
                    Text(w.severity,
                        style: TextStyle(color: style.fg, fontWeight: FontWeight.w600, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 4),
                if (w.reason.isNotEmpty)
                  Text(w.reason, style: const TextStyle(color: AppColors.muted, fontSize: 13, height: 1.4)),
                if (w.recommendation.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(w.recommendation,
                      style: const TextStyle(color: AppColors.ink, fontSize: 13, height: 1.4, fontStyle: FontStyle.italic)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _flagTile(String title, String subtitle) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.amberLight,
        borderRadius: BorderRadius.circular(kCardRadius),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, color: AppColors.amber, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink, fontSize: 13)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(color: AppColors.muted, fontSize: 12, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}