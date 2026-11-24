class AgeGroupResult {
  final String group; // Child / Teenager / Adult
  final String status; // suitable / caution / avoid
  final String reason;

  AgeGroupResult({required this.group, required this.status, required this.reason});

  factory AgeGroupResult.fromJson(Map<String, dynamic> json) => AgeGroupResult(
        group: json['group'] ?? '',
        status: json['status'] ?? 'suitable',
        reason: json['reason'] ?? '',
      );
}

class IngredientFlag {
  final String ingredient;
  final String concern;
  IngredientFlag({required this.ingredient, required this.concern});

  factory IngredientFlag.fromJson(Map<String, dynamic> json) => IngredientFlag(
        ingredient: json['ingredient'] ?? '',
        concern: json['concern'] ?? '',
      );
}

class NutritionConcern {
  final String label;
  final String value;
  final String concern;
  NutritionConcern({required this.label, required this.value, required this.concern});

  factory NutritionConcern.fromJson(Map<String, dynamic> json) => NutritionConcern(
        label: json['label'] ?? '',
        value: json['value'] ?? '',
        concern: json['concern'] ?? '',
      );
}

/// NEW - one product-level warning for a given health condition
/// (e.g. Diabetes -> Avoid -> "High sugar content"). This is a
/// PRODUCT WARNING, never a diagnosis of the person using the app.
class HealthConditionWarning {
  final String conditionName;
  final String severity; // Safe / Caution / Avoid
  final String reason;
  final String recommendation;

  HealthConditionWarning({
    required this.conditionName,
    required this.severity,
    required this.reason,
    required this.recommendation,
  });

  factory HealthConditionWarning.fromJson(Map<String, dynamic> json) => HealthConditionWarning(
        conditionName: json['condition_name'] ?? '',
        severity: json['severity'] ?? 'Caution',
        reason: json['reason'] ?? '',
        recommendation: json['recommendation'] ?? '',
      );
}

class AnalysisResult {
  final String overall; // Generally Suitable / Use Caution / Avoid
  final List<AgeGroupResult> ageGroups;
  final List<IngredientFlag> flags;
  final List<NutritionConcern> nutritionConcerns;
  final List<HealthConditionWarning> healthConditions; // NEW - defaults to [] if absent

  AnalysisResult({
    required this.overall,
    required this.ageGroups,
    required this.flags,
    required this.nutritionConcerns,
    this.healthConditions = const [],
  });

  factory AnalysisResult.fromJson(Map<String, dynamic> json) => AnalysisResult(
        overall: json['overall'] ?? 'Generally Suitable',
        ageGroups: (json['age_groups'] as List? ?? [])
            .map((e) => AgeGroupResult.fromJson(e))
            .toList(),
        flags: (json['flags'] as List? ?? [])
            .map((e) => IngredientFlag.fromJson(e))
            .toList(),
        nutritionConcerns: (json['nutrition_concerns'] as List? ?? [])
            .map((e) => NutritionConcern.fromJson(e))
            .toList(),
        // Safe even if the backend hasn't been updated yet, or the key
        // is missing/null - always resolves to an empty list, never crashes.
        healthConditions: (json['health_conditions'] as List? ?? [])
            .map((e) => HealthConditionWarning.fromJson(e))
            .toList(),
      );
}