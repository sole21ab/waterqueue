import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/auth_user.dart';
import '../models/report.dart';
import '../models/water_point.dart';

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

  /// Fetches the active water points from `GET /water-points`.
  ///
  /// The backend route is public (it has no authentication pre-handler), so no
  /// bearer token is attached to the request.
  Future<List<WaterPoint>> fetchWaterPoints() async {
    final Map<String, dynamic> body = await _get('/water-points');

    final Object? rawWaterPoints = body['waterPoints'];
    if (rawWaterPoints is! List) {
      throw const ApiException(
        'The server returned an unexpected response. Please try again.',
      );
    }

    final List<WaterPoint> waterPoints = <WaterPoint>[];
    for (final Object? entry in rawWaterPoints) {
      if (entry is! Map<String, dynamic>) {
        throw const ApiException(
          'The server returned an unexpected response. Please try again.',
        );
      }
      waterPoints.add(WaterPoint.fromJson(entry));
    }

    return waterPoints;
  }

  /// Submits a resident report to `POST /water-points/:id/reports`.
  ///
  /// The route requires the signed-in resident's JWT as a bearer token, so
  /// [token] is attached as an `Authorization` header.
  Future<Report> submitReport({
    required String waterPointId,
    required String token,
    required bool waterAvailable,
    required int queueSize,
  }) async {
    if (queueSize < 0 || queueSize > 50) {
      throw const ApiException('Queue size must be between 0 and 50.');
    }

    final Map<String, dynamic> body = await _postJson(
      '/water-points/${Uri.encodeComponent(waterPointId)}/reports',
      body: <String, Object?>{
        'waterAvailable': waterAvailable,
        'queueSize': queueSize,
      },
      headers: <String, String>{'Authorization': 'Bearer $token'},
      errorMessage: _reportErrorMessage,
    );

    final Object? rawReport = body['report'];
    if (rawReport is! Map<String, dynamic>) {
      throw const ApiException(
        'The server returned an unexpected response. Please try again.',
      );
    }

    return Report.fromJson(rawReport);
  }

  Future<Map<String, dynamic>> _get(String path) async {
    final Uri uri = Uri.parse('$baseUrl$path');

    late final http.Response response;
    try {
      response = await _client.get(uri).timeout(const Duration(seconds: 20));
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
      return body;
    }

    throw ApiException(
      _resourceErrorMessage(response, body),
      statusCode: response.statusCode,
    );
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

  /// Sends a JSON body to [path] and returns the decoded response body.
  ///
  /// [errorMessage] builds the message of the [ApiException] thrown for a
  /// non successful response.
  Future<Map<String, dynamic>> _postJson(
    String path, {
    required Map<String, Object?> body,
    required String Function(http.Response response, Map<String, dynamic> body)
    errorMessage,
    Map<String, String> headers = const <String, String>{},
  }) async {
    final Uri uri = Uri.parse('$baseUrl$path');

    late final http.Response response;
    try {
      response = await _client
          .post(
            uri,
            headers: <String, String>{
              'Content-Type': 'application/json',
              ...headers,
            },
            body: jsonEncode(body),
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

    final Map<String, dynamic> decoded = _decodeBody(response);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded;
    }

    throw ApiException(
      errorMessage(response, decoded),
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

  String _resourceErrorMessage(http.Response response, Map<String, dynamic> body) {
    final Object? serverError = body['error'];
    if (serverError is String && serverError.trim().isNotEmpty) {
      return serverError;
    }

    switch (response.statusCode) {
      case 400:
        return 'The server rejected the request.';
      case 404:
        return 'The requested resource was not found.';
      case 500:
        return 'The server could not load water points. Please try again.';
      default:
        return 'Could not load water points (status ${response.statusCode}).';
    }
  }

  String _reportErrorMessage(http.Response response, Map<String, dynamic> body) {
    final Object? serverError = body['error'];
    if (serverError is String && serverError.trim().isNotEmpty) {
      return serverError;
    }

    switch (response.statusCode) {
      case 400:
        return 'The server rejected the report.';
      case 401:
        return 'Your session has expired. Please sign in again.';
      case 404:
        return 'This water point is no longer available.';
      case 500:
        return 'The server could not submit the report. Please try again.';
      default:
        return 'Could not submit the report (status ${response.statusCode}).';
    }
  }
}
