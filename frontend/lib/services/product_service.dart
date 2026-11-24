import '../core/api_client.dart';
import '../models/product.dart';

class ProductNotFoundException implements Exception {
  final String barcode;
  ProductNotFoundException(this.barcode);
}

class ProductService {
  final _api = ApiClient.instance;

  Future<Product> lookupBarcode(String barcode) async {
    try {
      final data = await _api.get('/products/barcode/$barcode');
      return Product.fromJson(data['product']);
    } on ApiException catch (e) {
      if (e.statusCode == 404) throw ProductNotFoundException(barcode);
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> search(String query) async {
    final data = await _api.get('/products/search', query: {'q': query});
    return List<Map<String, dynamic>>.from(data['results'] ?? []);
  }
}
