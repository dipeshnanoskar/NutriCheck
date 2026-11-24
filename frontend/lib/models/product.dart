class NutritionInfo {
  final String energy;
  final String fat;
  final String saturatedFat;
  final String carbs;
  final String sugars;
  final String fiber;
  final String protein;
  final String salt;

  NutritionInfo({
    this.energy = '0',
    this.fat = '0g',
    this.saturatedFat = '0g',
    this.carbs = '0g',
    this.sugars = '0g',
    this.fiber = '0g',
    this.protein = '0g',
    this.salt = '0g',
  });

  factory NutritionInfo.fromJson(Map<String, dynamic> json) => NutritionInfo(
        energy: json['energy']?.toString() ?? '0',
        fat: json['fat']?.toString() ?? '0g',
        saturatedFat: json['saturatedFat']?.toString() ?? '0g',
        carbs: json['carbs']?.toString() ?? '0g',
        sugars: json['sugars']?.toString() ?? '0g',
        fiber: json['fiber']?.toString() ?? '0g',
        protein: json['protein']?.toString() ?? '0g',
        salt: json['salt']?.toString() ?? '0g',
      );

  Map<String, dynamic> toJson() => {
        'energy': energy,
        'fat': fat,
        'saturatedFat': saturatedFat,
        'carbs': carbs,
        'sugars': sugars,
        'fiber': fiber,
        'protein': protein,
        'salt': salt,
      };

  List<MapEntry<String, String>> get entries => [
        MapEntry('Energy', energy),
        MapEntry('Fat', fat),
        MapEntry('Saturated Fat', saturatedFat),
        MapEntry('Carbohydrates', carbs),
        MapEntry('Sugars', sugars),
        MapEntry('Fiber', fiber),
        MapEntry('Protein', protein),
        MapEntry('Salt', salt),
      ];
}

class Product {
  final String barcode;
  final String name;
  final String brand;
  final String category;
  final String image;
  final String ingredients;
  final NutritionInfo nutrition;

  Product({
    required this.barcode,
    required this.name,
    required this.brand,
    required this.category,
    required this.image,
    required this.ingredients,
    required this.nutrition,
  });

  factory Product.fromJson(Map<String, dynamic> json) => Product(
        barcode: json['barcode'] ?? '',
        name: json['name'] ?? 'Unknown Product',
        brand: json['brand'] ?? '',
        category: json['category'] ?? '',
        image: json['image'] ?? '',
        ingredients: json['ingredients'] ?? '',
        nutrition: NutritionInfo.fromJson(json['nutrition'] ?? {}),
      );
}
