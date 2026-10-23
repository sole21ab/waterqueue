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

  Future<AuthResult> login({required String email, required String password}) {
    return _post('/auth/login', email: email, password: password);
  }

  /// Fetches the active water points from `GET /water-points`.
  ///
  /// The backend route is public (it has no authentication pre-handler), so no
  /// bearer token is attached to the request.
  Future<List<WaterPoint>> fetchWaterPoints() {
    return _fetchWaterPoints('/water-points');
  }

  /// Fetches the water points the admin list shows from `GET /water-points`.
  ///
  /// The route is public, so no bearer token is attached. When
  /// [includeInactive] is true the deactivated water points are requested as
  /// well, using the `isActive=false` query the backend supports.
  Future<List<WaterPoint>> fetchAdminWaterPoints({
    required bool includeInactive,
  }) async {
    final List<WaterPoint> active = await _fetchWaterPoints('/water-points');
    if (!includeInactive) {
      return active;
    }

    final List<WaterPoint> inactive = await _fetchWaterPoints(
      '/water-points?isActive=false',
    );
    return <WaterPoint>[...active, ...inactive];
  }

  Future<List<WaterPoint>> _fetchWaterPoints(String path) async {
    final Map<String, dynamic> body = await _get(path);

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

  /// Creates a water point with the admin route `POST /water-points`.
  ///
  /// The route is restricted to administrators, so the signed-in [token] is
  /// attached as an `Authorization` header. The backend answers with the
  /// created water point wrapped in a `waterPoint` object.
  Future<WaterPoint> createWaterPoint({
    required String token,
    required String name,
    required String address,
    required double latitude,
    required double longitude,
    required String operatingHours,
    bool isActive = true,
  }) async {
    final Map<String, dynamic> body = await _sendJson(
      '/water-points',
      method: 'POST',
      body: <String, Object?>{
        'name': name,
        'address': address,
        'latitude': latitude,
        'longitude': longitude,
        'operatingHours': operatingHours,
        'isActive': isActive,
      },
      headers: <String, String>{'Authorization': 'Bearer $token'},
      errorMessage: _adminErrorMessage,
    );

    return _readAdminWaterPoint(body);
  }

  /// Updates a water point with the admin route `PUT /water-points/:id`.
  ///
  /// Only the provided fields are sent, which keeps the partial update the
  /// backend route expects.
  Future<WaterPoint> updateWaterPoint({
    required String token,
    required String waterPointId,
    String? name,
    String? address,
    double? latitude,
    double? longitude,
    String? operatingHours,
    bool? isActive,
  }) async {
    final Map<String, Object?> payload = <String, Object?>{
      if (name != null) 'name': name,
      if (address != null) 'address': address,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (operatingHours != null) 'operatingHours': operatingHours,
      if (isActive != null) 'isActive': isActive,
    };

    final Map<String, dynamic> body = await _sendJson(
      '/water-points/${Uri.encodeComponent(waterPointId)}',
      method: 'PUT',
      body: payload,
      headers: <String, String>{'Authorization': 'Bearer $token'},
      errorMessage: _adminErrorMessage,
    );

    return _readAdminWaterPoint(body);
  }

  /// Deactivates a water point with the admin route
  /// `PATCH /water-points/:id/deactivate`.
  Future<WaterPoint> deactivateWaterPoint({
    required String token,
    required String waterPointId,
  }) async {
    final Map<String, dynamic> body = await _sendJson(
      '/water-points/${Uri.encodeComponent(waterPointId)}/deactivate',
      method: 'PATCH',
      body: <String, Object?>{},
      headers: <String, String>{'Authorization': 'Bearer $token'},
      errorMessage: _adminErrorMessage,
    );

    return _readAdminWaterPoint(body);
  }

  /// Reads the water point the admin routes answer with.
  WaterPoint _readAdminWaterPoint(Map<String, dynamic> body) {
    final Object? rawWaterPoint = body['waterPoint'];
    if (rawWaterPoint is! Map<String, dynamic>) {
      throw const ApiException(
        'The server returned an unexpected response. Please try again.',
      );
    }

    return WaterPoint.fromJson(rawWaterPoint);
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
  }) {
    return _sendJson(
      path,
      method: 'POST',
      body: body,
      errorMessage: errorMessage,
      headers: headers,
    );
  }

  /// Sends a JSON body to [path] with the given HTTP [method] and returns the
  /// decoded response body.
  Future<Map<String, dynamic>> _sendJson(
    String path, {
    required String method,
    required Map<String, Object?> body,
    required String Function(http.Response response, Map<String, dynamic> body)
    errorMessage,
    Map<String, String> headers = const <String, String>{},
  }) async {
    final Uri uri = Uri.parse('$baseUrl$path');

    final http.Request request = http.Request(method, uri)
      ..headers.addAll(<String, String>{
        'Content-Type': 'application/json',
        ...headers,
      })
      ..body = jsonEncode(body);

    late final http.Response response;
    try {
      final http.StreamedResponse streamed = await _client
          .send(request)
          .timeout(const Duration(seconds: 20));
      response = await http.Response.fromStream(streamed);
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

  String _resourceErrorMessage(
    http.Response response,
    Map<String, dynamic> body,
  ) {
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

  String _reportErrorMessage(
    http.Response response,
    Map<String, dynamic> body,
  ) {
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

  /// Builds the message of an admin request that failed.
  ///
  /// The admin routes answer a rejected body with the `details` map the
  /// backend builds from its Zod schema, which is appended to the generic
  /// error message so the admin sees which field was wrong.
  String _adminErrorMessage(http.Response response, Map<String, dynamic> body) {
    final Object? serverError = body['error'];
    final String message =
        serverError is String && serverError.trim().isNotEmpty
        ? serverError
        : _adminFallbackMessage(response);

    final Object? rawDetails = body['details'];
    if (rawDetails is! Map<String, dynamic>) {
      return message;
    }

    final List<String> details = <String>[];
    for (final MapEntry<String, dynamic> entry in rawDetails.entries) {
      final Object? value = entry.value;
      if (value is! List) {
        continue;
      }
      for (final Object? detail in value) {
        if (detail is String && detail.trim().isNotEmpty) {
          details.add('${entry.key}: $detail');
        }
      }
    }

    if (details.isEmpty) {
      return message;
    }

    return '$message\n${details.join('\n')}';
  }

  String _adminFallbackMessage(http.Response response) {
    switch (response.statusCode) {
      case 400:
        return 'The server rejected the request.';
      case 401:
        return 'Your session has expired. Please sign in again.';
      case 403:
        return 'You do not have permission to manage water points.';
      case 404:
        return 'The water point was not found.';
      case 500:
        return 'The server could not complete the request. Please try again.';
      default:
        return 'Request failed with status ${response.statusCode}.';
    }
  }
}
