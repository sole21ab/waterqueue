import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/auth_user.dart';

const String kDefaultApiBaseUrl = 'http://localhost:3000';

const String kApiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: kDefaultApiBaseUrl,
);

class AuthResult {
  const AuthResult({required this.user, required this.token});

  final AuthUser user;
  final String token;
}

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({http.Client? client, this.baseUrl = kApiBaseUrl})
      : _client = client ?? http.Client();

  final http.Client _client;
  final String baseUrl;

  Future<AuthResult> register({
    required String email,
    required String password,
  }) {
    return _post('/auth/register', email: email, password: password);
  }

  Future<AuthResult> login({
    required String email,
    required String password,
  }) {
    return _post('/auth/login', email: email, password: password);
  }

  Future<AuthResult> _post(
    String path, {
    required String email,
    required String password,
  }) async {
    final Uri uri = Uri.parse('$baseUrl$path');

    late final http.Response response;
    try {
      response = await _client
          .post(
            uri,
            headers: const <String, String>{'Content-Type': 'application/json'},
            body: jsonEncode(<String, String>{
              'email': email,
              'password': password,
            }),
          )
          .timeout(const Duration(seconds: 20));
    } on TimeoutException {
      throw const ApiException(
        'The server took too long to respond. Please try again.',
      );
    } on http.ClientException {
      throw const ApiException(
        'Could not reach the server. Make sure the backend is running.',
      );
    }

    final Map<String, dynamic> body = _decodeBody(response);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final Object? rawUser = body['user'];
      final Object? rawToken = body['token'];

      if (rawUser is! Map<String, dynamic> || rawToken is! String) {
        throw const ApiException(
          'The server returned an unexpected response. Please try again.',
        );
      }

      return AuthResult(user: AuthUser.fromJson(rawUser), token: rawToken);
    }

    throw ApiException(
      _errorMessage(response, body),
      statusCode: response.statusCode,
    );
  }

  Map<String, dynamic> _decodeBody(http.Response response) {
    try {
      final Object? decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } on FormatException {
      return const <String, dynamic>{};
    }
    return const <String, dynamic>{};
  }

  String _errorMessage(http.Response response, Map<String, dynamic> body) {
    final Object? serverError = body['error'];
    if (serverError is String && serverError.trim().isNotEmpty) {
      return serverError;
    }

    switch (response.statusCode) {
      case 400:
        return 'Invalid email or password.';
      case 401:
        return 'Invalid email or password.';
      case 409:
        return 'An account with this email already exists.';
      case 500:
        return 'The server could not complete the request. Please try again.';
      default:
        return 'Request failed with status ${response.statusCode}.';
    }
  }
}
