import 'analysis_result.dart';

class HistoryItem {
  final String id;
  final String source; // barcode / ocr
  final String productName;
  final String brand;
  final String image;
  final String barcode;
  final String overall;
  final List<AgeGroupResult> ageGroups;
  final List<IngredientFlag> flags;
  final List<HealthConditionWarning> healthConditions;
  final DateTime createdAt;

  HistoryItem({
    required this.id,
    required this.source,
    required this.productName,
    required this.brand,
    required this.image,
    required this.barcode,
    required this.overall,
    required this.ageGroups,
    required this.flags,
    required this.createdAt,
    this.healthConditions = const [],
  });

  factory HistoryItem.fromJson(Map<String, dynamic> json) => HistoryItem(
        id: json['id'] ?? '',
        source: json['source'] ?? 'barcode',
        productName: json['product_name'] ?? 'Unknown',
        brand: json['brand'] ?? '',
        image: json['image'] ?? '',
        barcode: json['barcode'] ?? '',
        overall: json['overall'] ?? 'Generally Suitable',
        ageGroups: (json['age_groups'] as List? ?? [])
            .map((e) => AgeGroupResult.fromJson(e))
            .toList(),
        flags: (json['flags'] as List? ?? [])
            .map((e) => IngredientFlag.fromJson(e))
            .toList(),
        // Safe even for older history entries saved before this feature
        // existed - missing/null key resolves to an empty list.
        healthConditions: (json['health_conditions'] as List? ?? [])
            .map((e) => HealthConditionWarning.fromJson(e))
            .toList(),
        createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      );
}