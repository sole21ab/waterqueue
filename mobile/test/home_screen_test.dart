import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/models/auth_user.dart';
import 'package:mobile/screens/home_screen.dart';
import 'package:mobile/services/api_client.dart';
import 'package:mobile/theme/app_theme.dart';

const AuthUser _user = AuthUser(
  id: 'aaaaaaaa-bbbb-cccc-dddd-000000000001',
  email: 'resident@example.com',
  role: 'resident',
);

const AuthUser _adminUser = AuthUser(
  id: 'aaaaaaaa-bbbb-cccc-dddd-000000000002',
  email: 'admin@example.com',
  role: 'admin',
);

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
    <String, Object?>{
      'id': 'aaaaaaaa-bbbb-cccc-dddd-000000000002',
      'name': 'Piazza Community Tap',
      'address': 'Arada Subcity, Piazza District, Addis Ababa',
      'latitude': 9.0333,
      'longitude': 38.7500,
      'operatingHours': '24/7',
      'isActive': true,
      'createdAt': '2024-01-01T00:00:00.000Z',
      'currentStatus': <String, Object?>{
        'waterAvailable': 'unknown',
        'queueSize': 'unknown',
        'estimatedWaitMinutes': 'unknown',
        'confidence': 0,
        'lastReportedAt': null,
      },
    },
  ],
}) {
  return jsonEncode(<String, Object?>{'waterPoints': waterPoints});
}

Widget _app(ApiClient apiClient) {
  return MaterialApp(
    theme: AppTheme.light(),
    home: HomeScreen(
      user: _user,
      token: 'signed-jwt-token',
      apiClient: apiClient,
      onSignOut: () {},
    ),
  );
}

Widget _adminApp(ApiClient apiClient) {
  return MaterialApp(
    theme: AppTheme.light(),
    home: HomeScreen(
      user: _adminUser,
      token: 'signed-jwt-token',
      apiClient: apiClient,
      onSignOut: () {},
    ),
  );
}

ApiClient _client(Future<http.Response> Function(http.Request request) handler) {
  return ApiClient(client: MockClient(handler));
}

void main() {
  testWidgets('shows a loading indicator while the water points load', (
    WidgetTester tester,
  ) async {
    final Completer<http.Response> completer = Completer<http.Response>();

    await tester.pumpWidget(_app(_client((_) async => completer.future)));

    expect(find.byKey(const Key('water-points-loading')), findsOneWidget);

    completer.complete(http.Response(_waterPointsBody(), 200));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('water-points-loading')), findsNothing);
  });

  testWidgets('lists the water points returned by the API', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _app(_client((_) async => http.Response(_waterPointsBody(), 200))),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('water-points-list')), findsOneWidget);
    expect(find.text('Bole Medhanealem Well'), findsOneWidget);
    expect(
      find.text('Bole Subcity, near Medhanealem Church, Addis Ababa'),
      findsOneWidget,
    );
    expect(find.text('Open 06:00-22:00'), findsOneWidget);
    expect(find.text('Water available'), findsOneWidget);
    expect(find.textContaining('Queue: 5 people'), findsOneWidget);
    expect(find.textContaining('About 10 min wait'), findsOneWidget);
    expect(find.text('Confidence 80%'), findsOneWidget);
  });

  testWidgets('shows the unknown status when the backend has no reports', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _app(_client((_) async => http.Response(_waterPointsBody(), 200))),
    );
    await tester.pumpAndSettle();

    expect(find.text('Piazza Community Tap'), findsOneWidget);
    expect(find.text('No reports yet'), findsOneWidget);
    expect(find.textContaining('Queue size unknown'), findsOneWidget);
    expect(find.text('Confidence unknown'), findsOneWidget);
  });

  testWidgets('keeps the signed-in email and role visible', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _app(_client((_) async => http.Response(_waterPointsBody(), 200))),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('home-email')), findsOneWidget);
    expect(find.text('resident@example.com'), findsOneWidget);
    expect(find.byKey(const Key('home-role')), findsOneWidget);
    expect(find.text('Role: resident'), findsOneWidget);
  });

  testWidgets('shows an empty state when there are no water points', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _app(
        _client(
          (_) async => http.Response(
            jsonEncode(<String, Object?>{'waterPoints': <Object?>[]}),
            200,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('water-points-empty')), findsOneWidget);
    expect(find.text('No water points available'), findsOneWidget);
    expect(find.byKey(const Key('water-points-list')), findsNothing);
  });

  testWidgets('shows the error message and reloads on retry', (
    WidgetTester tester,
  ) async {
    int requestCount = 0;

    await tester.pumpWidget(
      _app(
        _client((_) async {
          requestCount++;
          if (requestCount == 1) {
            return http.Response(
              jsonEncode(<String, String>{
                'error': 'Unable to fetch water points.',
              }),
              500,
            );
          }
          return http.Response(_waterPointsBody(), 200);
        }),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('water-points-error')), findsOneWidget);
    expect(find.text('Unable to fetch water points.'), findsOneWidget);
    expect(find.byKey(const Key('water-points-retry')), findsOneWidget);

    await tester.tap(find.byKey(const Key('water-points-retry')));
    await tester.pumpAndSettle();

    expect(requestCount, 2);
    expect(find.byKey(const Key('water-points-error')), findsNothing);
    expect(find.text('Bole Medhanealem Well'), findsOneWidget);
  });

  testWidgets('shows an error when the backend cannot be reached', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _app(
        _client((_) async => throw http.ClientException('Connection refused')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('water-points-error')), findsOneWidget);
    expect(
      find.text('Could not reach the server. Make sure the backend is running.'),
      findsOneWidget,
    );
  });

  testWidgets('opens the report form from a water point', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _app(_client((_) async => http.Response(_waterPointsBody(), 200))),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('water-point-report')), findsNWidgets(2));

    await tester.tap(find.byKey(const Key('water-point-report')).first);
    await tester.pumpAndSettle();

    expect(find.text('Report status'), findsOneWidget);
    expect(find.byKey(const Key('report-queue-size')), findsOneWidget);
    expect(find.byKey(const Key('report-submit')), findsOneWidget);
  });

  testWidgets('the refresh action requests the water points again', (
    WidgetTester tester,
  ) async {
    int requestCount = 0;

    await tester.pumpWidget(
      _app(
        _client((_) async {
          requestCount++;
          return http.Response(_waterPointsBody(), 200);
        }),
      ),
    );
    await tester.pumpAndSettle();

    expect(requestCount, 1);

    await tester.tap(find.byKey(const Key('home-refresh')));
    await tester.pumpAndSettle();

    expect(requestCount, 2);
    expect(find.text('Bole Medhanealem Well'), findsOneWidget);
  });

  testWidgets('routes administrators to the water points management screen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _adminApp(_client((_) async => http.Response(_waterPointsBody(), 200))),
    );
    await tester.pumpAndSettle();

    expect(find.text('Manage water points'), findsOneWidget);
    expect(find.byKey(const Key('admin-add-water-point')), findsOneWidget);
    expect(find.byKey(const Key('water-points-list')), findsNothing);
    expect(find.byKey(const Key('water-point-report')), findsNothing);
    expect(find.text('Role: admin'), findsNothing);
  });

  testWidgets('keeps residents on the resident water points list', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _app(_client((_) async => http.Response(_waterPointsBody(), 200))),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('water-points-list')), findsOneWidget);
    expect(find.byKey(const Key('admin-add-water-point')), findsNothing);
    expect(find.text('Manage water points'), findsNothing);
    expect(find.text('Role: resident'), findsOneWidget);
  });
}
