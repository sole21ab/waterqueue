import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/screens/auth_screen.dart';
import 'package:mobile/services/api_client.dart';

const String _email = 'resident@example.com';
const String _password = 'StrongPass123456';

String _successBody({String role = 'resident'}) {
  return jsonEncode(<String, Object?>{
    'user': <String, Object?>{
      'id': 'aaaaaaaa-bbbb-cccc-dddd-000000000001',
      'email': _email,
      'role': role,
      'createdAt': '2024-01-01T00:00:00.000Z',
    },
    'token': 'signed-jwt-token',
  });
}

Widget _app({
  required ApiClient apiClient,
  void Function(AuthResult result)? onAuthenticated,
}) {
  return MaterialApp(
    home: AuthScreen(
      apiClient: apiClient,
      onAuthenticated: onAuthenticated ?? (_) {},
    ),
  );
}

Future<void> _enterCredentials(
  WidgetTester tester, {
  String email = _email,
  String password = _password,
}) async {
  await tester.enterText(find.byKey(const Key('auth-email')), email);
  await tester.enterText(find.byKey(const Key('auth-password')), password);
  await tester.pump();
}

void main() {
  testWidgets('login form shows email, password and a login button', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _app(
        apiClient: ApiClient(
          client: MockClient((_) async => http.Response(_successBody(), 200)),
        ),
      ),
    );

    expect(find.byKey(const Key('auth-email')), findsOneWidget);
    expect(find.byKey(const Key('auth-password')), findsOneWidget);
    expect(find.text('Log in'), findsOneWidget);
    expect(find.text('Need an account? Register'), findsOneWidget);
  });

  testWidgets('switching to registration and back updates the form', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _app(
        apiClient: ApiClient(
          client: MockClient((_) async => http.Response(_successBody(), 200)),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('auth-toggle')));
    await tester.pump();

    expect(find.text('Create account'), findsOneWidget);
    expect(find.text('Register'), findsOneWidget);
    expect(find.text('Already have an account? Log in'), findsOneWidget);

    await tester.tap(find.byKey(const Key('auth-toggle')));
    await tester.pump();

    expect(find.text('Log in'), findsOneWidget);
    expect(find.text('Need an account? Register'), findsOneWidget);
  });

  testWidgets('empty form shows validation errors and sends no request', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _app(
        apiClient: ApiClient(
          client: MockClient((_) async {
            fail('The API must not be called when the form is invalid.');
          }),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('auth-submit')));
    await tester.pump();

    expect(find.text('Email is required.'), findsOneWidget);
    expect(find.text('Password is required.'), findsOneWidget);
  });

  testWidgets('invalid email is rejected before the request is sent', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _app(
        apiClient: ApiClient(
          client: MockClient((_) async {
            fail('The API must not be called when the email is invalid.');
          }),
        ),
      ),
    );

    await _enterCredentials(tester, email: 'not-an-email');
    await tester.tap(find.byKey(const Key('auth-submit')));
    await tester.pump();

    expect(find.text('Enter a valid email address.'), findsOneWidget);
  });

  testWidgets('registration requires a password of at least 12 characters', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _app(
        apiClient: ApiClient(
          client: MockClient((_) async {
            fail('The API must not be called when the password is too short.');
          }),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('auth-toggle')));
    await tester.pump();

    await _enterCredentials(tester, password: 'short1234');
    await tester.tap(find.byKey(const Key('auth-submit')));
    await tester.pump();

    expect(find.text('Password must be at least 12 characters.'), findsOneWidget);
  });

  testWidgets('duplicate registration shows the server error message', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _app(
        apiClient: ApiClient(
          client: MockClient(
            (_) async => http.Response(
              jsonEncode(<String, String>{
                'error': 'An account with this email already exists.',
              }),
              409,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('auth-toggle')));
    await tester.pump();

    await _enterCredentials(tester);
    await tester.tap(find.byKey(const Key('auth-submit')));
    await tester.pumpAndSettle();

    expect(
      find.text('An account with this email already exists.'),
      findsOneWidget,
    );
  });

  testWidgets('invalid login shows the server error message', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _app(
        apiClient: ApiClient(
          client: MockClient(
            (_) async => http.Response(
              jsonEncode(<String, String>{'error': 'Invalid email or password.'}),
              401,
            ),
          ),
        ),
      ),
    );

    await _enterCredentials(tester);
    await tester.tap(find.byKey(const Key('auth-submit')));
    await tester.pumpAndSettle();

    expect(find.text('Invalid email or password.'), findsOneWidget);
  });

  testWidgets('a network failure is reported to the user', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _app(
        apiClient: ApiClient(
          client: MockClient(
            (_) async => throw http.ClientException('Connection refused'),
          ),
        ),
      ),
    );

    await _enterCredentials(tester);
    await tester.tap(find.byKey(const Key('auth-submit')));
    await tester.pumpAndSettle();

    expect(
      find.text('Could not reach the server. Make sure the backend is running.'),
      findsOneWidget,
    );
  });

  testWidgets('a server failure is reported to the user', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _app(
        apiClient: ApiClient(
          client: MockClient(
            (_) async => http.Response(
              jsonEncode(<String, String>{'error': 'Unable to log in.'}),
              500,
            ),
          ),
        ),
      ),
    );

    await _enterCredentials(tester);
    await tester.tap(find.byKey(const Key('auth-submit')));
    await tester.pumpAndSettle();

    expect(find.text('Unable to log in.'), findsOneWidget);
  });

  testWidgets('the submit button shows a spinner and blocks repeat submits', (
    WidgetTester tester,
  ) async {
    final Completer<http.Response> completer = Completer<http.Response>();
    int requestCount = 0;

    await tester.pumpWidget(
      _app(
        apiClient: ApiClient(
          client: MockClient((_) async {
            requestCount++;
            return completer.future;
          }),
        ),
      ),
    );

    await _enterCredentials(tester);
    await tester.tap(find.byKey(const Key('auth-submit')));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byKey(const Key('auth-submit'))).onPressed,
      isNull,
    );

    await tester.tap(find.byKey(const Key('auth-submit')));
    await tester.pump();

    expect(requestCount, 1);

    completer.complete(http.Response(_successBody(), 200));
    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('a successful login reports the authenticated user', (
    WidgetTester tester,
  ) async {
    AuthResult? received;

    await tester.pumpWidget(
      _app(
        apiClient: ApiClient(
          client: MockClient((_) async => http.Response(_successBody(), 200)),
        ),
        onAuthenticated: (AuthResult result) => received = result,
      ),
    );

    await _enterCredentials(tester);
    await tester.tap(find.byKey(const Key('auth-submit')));
    await tester.pumpAndSettle();

    expect(received, isNotNull);
    expect(received!.user.email, _email);
    expect(received!.user.role, 'resident');
    expect(received!.token, 'signed-jwt-token');
  });
}
