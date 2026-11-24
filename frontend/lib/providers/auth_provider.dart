import 'package:flutter/foundation.dart';
import '../core/api_client.dart';
import '../models/user_profile.dart';
import '../services/auth_service.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthProvider extends ChangeNotifier {
  final _authService = AuthService();

  AuthStatus status = AuthStatus.unknown;
  UserProfile? profile;
  String? errorMessage;
  bool isLoading = false;

  Future<void> bootstrap() async {
    final loggedIn = await ApiClient.instance.isLoggedIn;
    if (!loggedIn) {
      status = AuthStatus.unauthenticated;
      notifyListeners();
      return;
    }
    try {
      profile = await _authService.fetchMe();
      status = AuthStatus.authenticated;
    } catch (_) {
      status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  Future<bool> register({
    required String name,
    required String email,
    required String password,
    required int age,
  }) => _run(() async {
        profile = await _authService.register(name: name, email: email, password: password, age: age);
        status = AuthStatus.authenticated;
      });

  Future<bool> login({required String email, required String password}) => _run(() async {
        profile = await _authService.login(email: email, password: password);
        status = AuthStatus.authenticated;
      });

  Future<bool> updateProfile({String? name, int? age}) => _run(() async {
        profile = await _authService.updateProfile(name: name, age: age);
      });

  Future<void> logout() async {
    await _authService.logout();
    profile = null;
    status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  Future<bool> _run(Future<void> Function() action) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      await action();
      isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      isLoading = false;
      errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }
}
