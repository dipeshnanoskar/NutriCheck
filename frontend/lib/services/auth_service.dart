import '../core/api_client.dart';
import '../models/user_profile.dart';

class AuthService {
  final _api = ApiClient.instance;

  Future<UserProfile> register({
    required String name,
    required String email,
    required String password,
    required int age,
  }) async {
    final data = await _api.post(
      '/auth/register',
      body: {'name': name, 'email': email, 'password': password, 'age': age},
      auth: false,
    );
    await _api.saveTokens(access: data['access_token'], refresh: data['refresh_token']);
    return UserProfile.fromJson(data['user']);
  }

  Future<UserProfile> login({required String email, required String password}) async {
    final data = await _api.post(
      '/auth/login',
      body: {'email': email, 'password': password},
      auth: false,
    );
    await _api.saveTokens(access: data['access_token'], refresh: data['refresh_token']);
    return UserProfile.fromJson(data['user']);
  }

  Future<UserProfile> fetchMe() async {
    final data = await _api.get('/auth/me');
    return UserProfile.fromJson(data['user']);
  }

  Future<UserProfile> updateProfile({String? name, int? age}) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (age != null) body['age'] = age;
    final data = await _api.put('/auth/me', body: body);
    return UserProfile.fromJson(data['user']);
  }

  Future<void> logout() async {
    await _api.clearTokens();
  }

  Future<bool> get isLoggedIn => _api.isLoggedIn;
}
