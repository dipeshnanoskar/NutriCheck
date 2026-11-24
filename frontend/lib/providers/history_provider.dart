import 'package:flutter/foundation.dart';
import '../models/history_item.dart';
import '../services/history_service.dart';

class HistoryProvider extends ChangeNotifier {
  final _service = HistoryService();

  List<HistoryItem> items = [];
  bool isLoading = false;
  String? errorMessage;

  Future<void> load() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      items = await _service.list();
    } catch (e) {
      errorMessage = e.toString();
    }
    isLoading = false;
    notifyListeners();
  }

  Future<void> delete(String id) async {
    await _service.delete(id);
    items.removeWhere((i) => i.id == id);
    notifyListeners();
  }

  Future<void> clearAll() async {
    await _service.clearAll();
    items = [];
    notifyListeners();
  }
}
