import '../core/api_client.dart';
import '../models/history_item.dart';

class HistoryService {
  final _api = ApiClient.instance;

  Future<List<HistoryItem>> list({int page = 1, int perPage = 20}) async {
    final data = await _api.get('/history', query: {'page': page, 'per_page': perPage});
    return (data['items'] as List).map((e) => HistoryItem.fromJson(e)).toList();
  }

  Future<void> delete(String id) => _api.delete('/history/$id');

  Future<void> clearAll() => _api.delete('/history');
}
