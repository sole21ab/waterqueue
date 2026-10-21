import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/models/water_point.dart';
import 'package:mobile/services/api_client.dart';

const String _baseUrl = 'http://localhost:3000';

String _successBody({
  String email = 'resident@example.com',
  String role = 'resident',
}) {
  return jsonEncode(<String, Object?>{
    'user': <String, Object?>{
      'id': 'aaaaaaaa-bbbb-cccc-dddd-000000000001',
      'email': email,
      'role': role,
      'createdAt': '2024-01-01T00:00:00.000Z',
    },
    'token': 'signed-jwt-token',
  });
}

String _waterPointsBody({
  List<Map<String, Object?>> waterPoints = const <Map<String, Object?>>[
    <String, Object?>{
      'id': 'aaaaaaaa-bbbb-cccc-dddd-000000000001',
      'name': 'Bole Medhanealem Well',
      'address': 'Bole Subcity, near Medhanealem Church, Addis Ababa',
      'latitude': 8.9867,
      'longitude': 38.7993,
      'operatingHours': '06:00-22:00',
      'isActive': true,
      'createdAt': '2024-01-01T00:00:00.000Z',
      'currentStatus': <String, Object?>{
        'waterAvailable': 'available',
        'queueSize': 5,
        'estimatedWaitMinutes': 10,
        'confidence': 80,
        'lastReportedAt': '2024-05-01T10:00:00.000Z',
      },
    },
  ],
}) {
  return jsonEncode(<String, Object?>{'waterPoints': waterPoints});
}

ApiClient _apiClient(
  Future<http.Response> Function(http.Request request) handler, {
  List<http.Request>? recorded,
}) {
  return ApiClient(
    baseUrl: _baseUrl,
    client: MockClient((http.Request request) {
      recorded?.add(request);
      return handler(request);
    }),
  );
}

void main() {
  group('ApiClient.register', () {
    test('posts email and password as JSON to /auth/register', () async {
      final List<http.Request> requests = <http.Request>[];
      final ApiClient client = _apiClient(
        (_) async => http.Response(_successBody(), 201),
        recorded: requests,
      );

      final AuthResult result = await client.register(
        email: 'resident@example.com',
        password: 'StrongPass123456',
      );

      expect(requests, hasLength(1));
      expect(requests.single.method, 'POST');
      expect(requests.single.url.toString(), '$_baseUrl/auth/register');
      expect(requests.single.headers['Content-Type'], 'application/json');
      expect(
        jsonDecode(requests.single.body),
        <String, String>{
          'email': 'resident@example.com',
          'password': 'StrongPass123456',
        },
      );

      expect(result.user.email, 'resident@example.com');
      expect(result.user.role, 'resident');
      expect(result.token, 'signed-jwt-token');
    });
  });

  group('ApiClient.login', () {
    test('posts email and password as JSON to /auth/login', () async {
      final List<http.Request> requests = <http.Request>[];
      final ApiClient client = _apiClient(
        (_) async => http.Response(_successBody(), 200),
        recorded: requests,
      );

      final AuthResult result = await client.login(
        email: 'resident@example.com',
        password: 'StrongPass123456',
      );

      expect(requests, hasLength(1));
      expect(requests.single.method, 'POST');
      expect(requests.single.url.toString(), '$_baseUrl/auth/login');
      expect(
        jsonDecode(requests.single.body),
        <String, String>{
          'email': 'resident@example.com',
          'password': 'StrongPass123456',
        },
      );

      expect(result.user.email, 'resident@example.com');
      expect(result.user.role, 'resident');
      expect(result.token, 'signed-jwt-token');
    });
  });

  group('ApiClient.fetchWaterPoints', () {
    test('gets /water-points without an authorization header', () async {
      final List<http.Request> requests = <http.Request>[];
      final ApiClient client = _apiClient(
        (_) async => http.Response(_waterPointsBody(), 200),
        recorded: requests,
      );

      await client.fetchWaterPoints();

      expect(requests, hasLength(1));
      expect(requests.single.method, 'GET');
      expect(requests.single.url.toString(), '$_baseUrl/water-points');
      expect(requests.single.headers.containsKey('Authorization'), isFalse);
    });

    test('maps the water points of the response', () async {
      final ApiClient client = _apiClient(
        (_) async => http.Response(_waterPointsBody(), 200),
      );

      final List<WaterPoint> waterPoints = await client.fetchWaterPoints();

      expect(waterPoints, hasLength(1));
      expect(waterPoints.single.name, 'Bole Medhanealem Well');
      expect(
        waterPoints.single.address,
        'Bole Subcity, near Medhanealem Church, Addis Ababa',
      );
      expect(waterPoints.single.operatingHours, '06:00-22:00');
      expect(waterPoints.single.isActive, isTrue);
      expect(waterPoints.single.status.waterAvailable, WaterAvailability.available);
      expect(waterPoints.single.status.queueSize, 5);
      expect(waterPoints.single.status.estimatedWaitMinutes, 10);
      expect(waterPoints.single.status.confidence, 80);
    });

    test('returns an empty list when there are no water points', () async {
      final ApiClient client = _apiClient(
        (_) async => http.Response(
          jsonEncode(<String, Object?>{'waterPoints': <Object?>[]}),
          200,
        ),
      );

      expect(await client.fetchWaterPoints(), isEmpty);
    });

    test('surfaces the server error message on 500', () async {
      final ApiClient client = _apiClient(
        (_) async => http.Response(
          jsonEncode(<String, String>{'error': 'Unable to fetch water points.'}),
          500,
        ),
      );

      await expectLater(
        client.fetchWaterPoints(),
        throwsA(
          isA<ApiException>()
              .having((ApiException e) => e.statusCode, 'statusCode', 500)
              .having(
                (ApiException e) => e.message,
                'message',
                'Unable to fetch water points.',
              ),
        ),
      );
    });

    test('reports a network failure when the backend is unreachable', () async {
      final ApiClient client = _apiClient(
        (_) async => throw http.ClientException('Connection refused'),
      );

      await expectLater(
        client.fetchWaterPoints(),
        throwsA(
          isA<ApiException>().having(
            (ApiException e) => e.message,
            'message',
            contains('Could not reach the server'),
          ),
        ),
      );
    });

    test('reports an unexpected response body', () async {
      final ApiClient client = _apiClient(
        (_) async => http.Response(jsonEncode(<String, String>{'ok': 'yes'}), 200),
      );

      await expectLater(
        client.fetchWaterPoints(),
        throwsA(
          isA<ApiException>().having(
            (ApiException e) => e.message,
            'message',
            contains('unexpected response'),
          ),
        ),
      );
    });
  });

  group('ApiClient error handling', () {
    test('surfaces the duplicate account message on 409', () async {
      final ApiClient client = _apiClient(
        (_) async => http.Response(
          jsonEncode(<String, String>{
            'error': 'An account with this email already exists.',
          }),
          409,
        ),
      );

      await expectLater(
        client.register(email: 'resident@example.com', password: 'StrongPass123456'),
        throwsA(
          isA<ApiException>()
              .having((ApiException e) => e.statusCode, 'statusCode', 409)
              .having(
                (ApiException e) => e.message,
                'message',
                'An account with this email already exists.',
              ),
        ),
      );
    });

    test('surfaces the invalid credentials message on 401', () async {
      final ApiClient client = _apiClient(
        (_) async => http.Response(
          jsonEncode(<String, String>{'error': 'Invalid email or password.'}),
          401,
        ),
      );

      await expectLater(
        client.login(email: 'resident@example.com', password: 'WrongPass123456'),
        throwsA(
          isA<ApiException>().having(
            (ApiException e) => e.message,
            'message',
            'Invalid email or password.',
          ),
        ),
      );
    });

    test('surfaces the server failure message on 500', () async {
      final ApiClient client = _apiClient(
        (_) async => http.Response(
          jsonEncode(<String, String>{'error': 'Unable to log in.'}),
          500,
        ),
      );

      await expectLater(
        client.login(email: 'resident@example.com', password: 'StrongPass123456'),
        throwsA(
          isA<ApiException>().having(
            (ApiException e) => e.message,
            'message',
            'Unable to log in.',
          ),
        ),
      );
    });

    test('falls back to a readable message when the body has no error', () async {
      final ApiClient client = _apiClient(
        (_) async => http.Response('not json', 500),
      );

      await expectLater(
        client.login(email: 'resident@example.com', password: 'StrongPass123456'),
        throwsA(
          isA<ApiException>().having(
            (ApiException e) => e.message,
            'message',
            contains('server could not complete'),
          ),
        ),
      );
    });

    test('reports a network failure when the backend is unreachable', () async {
      final ApiClient client = _apiClient(
        (_) async => throw http.ClientException('Connection refused'),
      );

      await expectLater(
        client.login(email: 'resident@example.com', password: 'StrongPass123456'),
        throwsA(
          isA<ApiException>().having(
            (ApiException e) => e.message,
            'message',
            contains('Could not reach the server'),
          ),
        ),
      );
    });

    test('reports an unexpected response body', () async {
      final ApiClient client = _apiClient(
        (_) async => http.Response(jsonEncode(<String, String>{'ok': 'yes'}), 200),
      );

      await expectLater(
        client.login(email: 'resident@example.com', password: 'StrongPass123456'),
        throwsA(
          isA<ApiException>().having(
            (ApiException e) => e.message,
            'message',
            contains('unexpected response'),
          ),
        ),
      );
    });
  });
}
