import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/main.dart';
import 'package:mobile/services/api_client.dart';

String _loginResponse() {
  return jsonEncode(<String, Object?>{
    'user': <String, Object?>{
      'id': 'aaaaaaaa-bbbb-cccc-dddd-000000000001',
      'email': 'resident@example.com',
      'role': 'resident',
      'createdAt': '2024-01-01T00:00:00.000Z',
    },
    'token': 'signed-jwt-token',
  });
}

ApiClient _apiClient() {
  return ApiClient(
    client: MockClient(
      (_) async => http.Response(_loginResponse(), 200),
    ),
  );
}

void main() {
  testWidgets('App starts on the login screen', (WidgetTester tester) async {
    await tester.pumpWidget(WaterQueueApp(apiClient: _apiClient()));

    expect(find.text('WaterQueue'), findsAtLeastNWidgets(1));
    expect(find.text('Log in'), findsOneWidget);
    expect(find.byKey(const Key('auth-email')), findsOneWidget);
    expect(find.byKey(const Key('auth-password')), findsOneWidget);
  });

  testWidgets('Signed in user sees their email and role', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(WaterQueueApp(apiClient: _apiClient()));

    await tester.enterText(
      find.byKey(const Key('auth-email')),
      'resident@example.com',
    );
    await tester.enterText(
      find.byKey(const Key('auth-password')),
      'StrongPass123456',
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('auth-submit')));
    await tester.pumpAndSettle();

    expect(find.text('resident@example.com'), findsOneWidget);
    expect(find.text('Role: resident'), findsOneWidget);
    expect(find.text('No water points yet'), findsOneWidget);
  });

  testWidgets('Signing out returns to the login screen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(WaterQueueApp(apiClient: _apiClient()));

    await tester.enterText(
      find.byKey(const Key('auth-email')),
      'resident@example.com',
    );
    await tester.enterText(
      find.byKey(const Key('auth-password')),
      'StrongPass123456',
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('auth-submit')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('home-sign-out')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('auth-email')), findsOneWidget);
    expect(find.text('Log in'), findsOneWidget);
  });
}
