import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'constants.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final Map<String, dynamic>? errors;
  ApiException(this.message, {this.statusCode, this.errors});

  @override
  String toString() => message;
}

/// Thin wrapper around http package that injects the bearer token,
/// retries once on a 401 using the refresh token, and decodes JSON.
class ApiClient {
  ApiClient._internal();
  static final ApiClient instance = ApiClient._internal();

  final _storage = const FlutterSecureStorage();
  final _client = http.Client();

  Future<String?> get _accessToken => _storage.read(key: StorageKeys.accessToken);
  Future<String?> get _refreshToken => _storage.read(key: StorageKeys.refreshToken);

  Future<void> saveTokens({required String access, required String refresh}) async {
    await _storage.write(key: StorageKeys.accessToken, value: access);
    await _storage.write(key: StorageKeys.refreshToken, value: refresh);
  }

  Future<void> clearTokens() async {
    await _storage.delete(key: StorageKeys.accessToken);
    await _storage.delete(key: StorageKeys.refreshToken);
  }

  Future<bool> get isLoggedIn async => (await _accessToken) != null;

  Uri _uri(String path, [Map<String, dynamic>? query]) {
    final base = Uri.parse(ApiConfig.baseUrl + path);
    if (query == null) return base;
    return base.replace(queryParameters: {
      ...base.queryParameters,
      ...query.map((k, v) => MapEntry(k, v.toString())),
    });
  }

  Future<Map<String, String>> _headers({bool auth = true}) async {
    final headers = {'Content-Type': 'application/json'};
    if (auth) {
      final token = await _accessToken;
      if (token != null) headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Future<bool> _tryRefresh() async {
    final refresh = await _refreshToken;
    if (refresh == null) return false;
    final resp = await _client.post(
      _uri('/auth/refresh'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $refresh',
      },
    );
    if (resp.statusCode == 200) {
      final body = jsonDecode(resp.body);
      await _storage.write(key: StorageKeys.accessToken, value: body['access_token']);
      return true;
    }
    return false;
  }

  dynamic _decode(http.Response resp) {
    if (resp.body.isEmpty) return null;
    try {
      return jsonDecode(resp.body);
    } catch (_) {
      return null;
    }
  }

  Future<dynamic> _handle(http.Response resp) async {
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      return _decode(resp);
    }
    final body = _decode(resp);
    throw ApiException(
      body?['error'] ?? body?['errors']?.toString() ?? 'Request failed (${resp.statusCode})',
      statusCode: resp.statusCode,
      errors: body?['errors'] is Map ? Map<String, dynamic>.from(body['errors']) : null,
    );
  }

  Future<dynamic> get(String path, {Map<String, dynamic>? query, bool auth = true}) async {
    var resp = await _client
        .get(_uri(path, query), headers: await _headers(auth: auth))
        .timeout(ApiConfig.requestTimeout);
    if (resp.statusCode == 401 && auth && await _tryRefresh()) {
      resp = await _client
          .get(_uri(path, query), headers: await _headers(auth: auth))
          .timeout(ApiConfig.requestTimeout);
    }
    return _handle(resp);
  }

  Future<dynamic> post(String path, {Object? body, bool auth = true}) async {
    var resp = await _client
        .post(_uri(path), headers: await _headers(auth: auth), body: jsonEncode(body ?? {}))
        .timeout(ApiConfig.requestTimeout);
    if (resp.statusCode == 401 && auth && await _tryRefresh()) {
      resp = await _client
          .post(_uri(path), headers: await _headers(auth: auth), body: jsonEncode(body ?? {}))
          .timeout(ApiConfig.requestTimeout);
    }
    return _handle(resp);
  }

  Future<dynamic> put(String path, {Object? body, bool auth = true}) async {
    final resp = await _client
        .put(_uri(path), headers: await _headers(auth: auth), body: jsonEncode(body ?? {}))
        .timeout(ApiConfig.requestTimeout);
    return _handle(resp);
  }

  Future<dynamic> delete(String path, {bool auth = true}) async {
    final resp = await _client
        .delete(_uri(path), headers: await _headers(auth: auth))
        .timeout(ApiConfig.requestTimeout);
    return _handle(resp);
  }

  /// Multipart upload for OCR image analysis.
  Future<dynamic> postMultipart(
    String path, {
    required List<int> fileBytes,
    required String filename,
    Map<String, String>? fields,
  }) async {
    final token = await _accessToken;
    final request = http.MultipartRequest('POST', _uri(path));
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    if (fields != null) request.fields.addAll(fields);
    request.files.add(http.MultipartFile.fromBytes('image', fileBytes, filename: filename));

    final streamed = await _client.send(request).timeout(const Duration(seconds: 30));
    final resp = await http.Response.fromStream(streamed);
    return _handle(resp);
  }

  /// Multipart upload for the two-photo OCR flow (ingredients + nutrition
  /// table). [files] maps the multipart field name (matching what the
  /// Flask route expects, e.g. 'ingredients_image', 'nutrition_image')
  /// to that file's raw bytes and filename.
  Future<dynamic> postMultipartFiles(
    String path, {
    required Map<String, ({List<int> bytes, String filename})> files,
    Map<String, String>? fields,
  }) async {
    final token = await _accessToken;
    final request = http.MultipartRequest('POST', _uri(path));
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    if (fields != null) request.fields.addAll(fields);
    for (final entry in files.entries) {
      request.files.add(http.MultipartFile.fromBytes(
        entry.key,
        entry.value.bytes,
        filename: entry.value.filename,
      ));
    }

    final streamed = await _client.send(request).timeout(const Duration(seconds: 30));
    final resp = await http.Response.fromStream(streamed);
    return _handle(resp);
  }
}
