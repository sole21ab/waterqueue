import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/models/water_point.dart';
import 'package:mobile/screens/report_screen.dart';
import 'package:mobile/services/api_client.dart';
import 'package:mobile/theme/app_theme.dart';

const String _waterPointId = 'aaaaaaaa-bbbb-cccc-dddd-000000000001';
const String _token = 'signed-jwt-token';

const WaterPoint _waterPoint = WaterPoint(
  id: _waterPointId,
  name: 'Bole Medhanealem Well',
  address: 'Bole Subcity, near Medhanealem Church, Addis Ababa',
  latitude: 8.9867,
  longitude: 38.7993,
  operatingHours: '06:00-22:00',
  isActive: true,
);

String _reportBody({
  bool waterAvailable = true,
  int queueSize = 3,
}) {
  return jsonEncode(<String, Object?>{
    'report': <String, Object?>{
      'id': 'bbbbbbbb-cccc-dddd-eeee-000000000009',
      'waterPointId': _waterPointId,
      'userId': 'aaaaaaaa-bbbb-cccc-dddd-000000000002',
      'waterAvailable': waterAvailable,
      'queueSize': queueSize,
      'estimatedWaitMinutes': queueSize * 2,
      'createdAt': '2024-05-01T10:00:00.000Z',
    },
  });
}

Widget _app(ApiClient apiClient) {
  return MaterialApp(
    theme: AppTheme.light(),
    home: ReportScreen(
      waterPoint: _waterPoint,
      apiClient: apiClient,
      token: _token,
    ),
  );
}

ApiClient _client(
  Future<http.Response> Function(http.Request request) handler, {
  List<http.Request>? recorded,
}) {
  return ApiClient(
    client: MockClient((http.Request request) {
      recorded?.add(request);
      return handler(request);
    }),
  );
}

Future<void> _submit(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('report-submit')));
  await tester.pump();
}

void main() {
  testWidgets('shows the water point and the report form', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _app(_client((_) async => http.Response(_reportBody(), 201))),
    );

    expect(find.text('Report status'), findsOneWidget);
    expect(find.byKey(const Key('report-water-point-name')), findsOneWidget);
    expect(find.text('Bole Medhanealem Well'), findsOneWidget);
    expect(find.text('Water available'), findsOneWidget);
    expect(find.text('No water'), findsOneWidget);
    expect(find.byKey(const Key('report-queue-size')), findsOneWidget);
    expect(find.byKey(const Key('report-queue-slider')), findsOneWidget);
    expect(find.byKey(const Key('report-submit')), findsOneWidget);
    expect(find.byKey(const Key('report-success')), findsNothing);
  });

  testWidgets('a queue size above 50 is rejected before the request', (
    WidgetTester tester,
  ) async {
    final List<http.Request> requests = <http.Request>[];

    await tester.pumpWidget(
      _app(
        _client(
          (_) async => http.Response(_reportBody(), 201),
          recorded: requests,
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const Key('report-queue-size')),
      '51',
    );
    await _submit(tester);

    expect(find.text('Queue size must be 50 or less.'), findsOneWidget);
    expect(requests, isEmpty);
    expect(find.byKey(const Key('report-success')), findsNothing);
  });

  testWidgets('a negative queue size is rejected before the request', (
    WidgetTester tester,
  ) async {
    final List<http.Request> requests = <http.Request>[];

    await tester.pumpWidget(
      _app(
        _client(
          (_) async => http.Response(_reportBody(), 201),
          recorded: requests,
        ),
      ),
    );

    await tester.enterText(find.byKey(const Key('report-queue-size')), '-3');
    await _submit(tester);

    expect(find.text('Queue size cannot be less than 0.'), findsOneWidget);
    expect(requests, isEmpty);
  });

  testWidgets('a queue size that is not a whole number is rejected', (
    WidgetTester tester,
  ) async {
    final List<http.Request> requests = <http.Request>[];

    await tester.pumpWidget(
      _app(
        _client(
          (_) async => http.Response(_reportBody(), 201),
          recorded: requests,
        ),
      ),
    );

    await tester.enterText(find.byKey(const Key('report-queue-size')), '3.5');
    await _submit(tester);

    expect(find.text('Queue size must be a whole number.'), findsOneWidget);
    expect(requests, isEmpty);
  });

  testWidgets('an empty queue size is rejected before the request', (
    WidgetTester tester,
  ) async {
    final List<http.Request> requests = <http.Request>[];

    await tester.pumpWidget(
      _app(
        _client(
          (_) async => http.Response(_reportBody(), 201),
          recorded: requests,
        ),
      ),
    );

    await tester.enterText(find.byKey(const Key('report-queue-size')), '');
    await _submit(tester);

    expect(find.text('Enter the queue size.'), findsOneWidget);
    expect(requests, isEmpty);
  });

  testWidgets('submits the report to the water point with the token', (
    WidgetTester tester,
  ) async {
    final List<http.Request> requests = <http.Request>[];

    await tester.pumpWidget(
      _app(
        _client(
          (_) async => http.Response(_reportBody(queueSize: 7), 201),
          recorded: requests,
        ),
      ),
    );

    await tester.enterText(find.byKey(const Key('report-queue-size')), '7');
    await tester.tap(find.byKey(const Key('report-submit')));
    await tester.pumpAndSettle();

    expect(requests, hasLength(1));
    expect(requests.single.method, 'POST');
    expect(
      requests.single.url.toString(),
      'http://localhost:3000/water-points/$_waterPointId/reports',
    );
    expect(requests.single.headers['Authorization'], 'Bearer $_token');
    expect(
      jsonDecode(requests.single.body),
      <String, Object?>{'waterAvailable': true, 'queueSize': 7},
    );

    expect(find.byKey(const Key('report-success')), findsOneWidget);
    expect(find.text('Report submitted'), findsOneWidget);
  });

  testWidgets('submits a report when the water is not available', (
    WidgetTester tester,
  ) async {
    final List<http.Request> requests = <http.Request>[];

    await tester.pumpWidget(
      _app(
        _client(
          (_) async => http.Response(_reportBody(waterAvailable: false), 201),
          recorded: requests,
        ),
      ),
    );

    await tester.tap(find.text('No water'));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('report-queue-size')), '2');
    await tester.tap(find.byKey(const Key('report-submit')));
    await tester.pumpAndSettle();

    expect(requests, hasLength(1));
    expect(
      jsonDecode(requests.single.body),
      <String, Object?>{'waterAvailable': false, 'queueSize': 2},
    );
    expect(find.byKey(const Key('report-success')), findsOneWidget);
  });

  testWidgets('the slider fills the queue size', (WidgetTester tester) async {
    await tester.pumpWidget(
      _app(_client((_) async => http.Response(_reportBody(), 201))),
    );

    await tester.drag(
      find.byKey(const Key('report-queue-slider')),
      const Offset(200, 0),
    );
    await tester.pumpAndSettle();

    final String text = tester
        .widget<TextFormField>(find.byKey(const Key('report-queue-size')))
        .controller!
        .text;
    final int? queueSize = int.tryParse(text);

    expect(queueSize, isNotNull);
    expect(queueSize, greaterThan(0));
    expect(queueSize, lessThanOrEqualTo(50));
  });

  testWidgets('the submit button shows a spinner and blocks repeat submits', (
    WidgetTester tester,
  ) async {
    final Completer<http.Response> completer = Completer<http.Response>();
    int requestCount = 0;

    await tester.pumpWidget(
      _app(
        _client((_) async {
          requestCount++;
          return completer.future;
        }),
      ),
    );

    await tester.enterText(find.byKey(const Key('report-queue-size')), '4');
    await tester.tap(find.byKey(const Key('report-submit')));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byKey(const Key('report-submit'))).onPressed,
      isNull,
    );

    await tester.tap(find.byKey(const Key('report-submit')));
    await tester.pump();

    expect(requestCount, 1);

    completer.complete(http.Response(_reportBody(queueSize: 4), 201));
    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byKey(const Key('report-success')), findsOneWidget);
    expect(requestCount, 1);
  });

  testWidgets('shows the server error message when the report fails', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _app(
        _client(
          (_) async => http.Response(
            jsonEncode(<String, String>{'error': 'Unable to submit report.'}),
            500,
          ),
        ),
      ),
    );

    await tester.enterText(find.byKey(const Key('report-queue-size')), '4');
    await tester.tap(find.byKey(const Key('report-submit')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('report-error')), findsOneWidget);
    expect(find.text('Unable to submit report.'), findsOneWidget);
    expect(find.byKey(const Key('report-success')), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(
      tester.widget<FilledButton>(find.byKey(const Key('report-submit'))).onPressed,
      isNotNull,
    );
  });

  testWidgets('shows an error when the backend cannot be reached', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _app(
        _client((_) async => throw http.ClientException('Connection refused')),
      ),
    );

    await tester.enterText(find.byKey(const Key('report-queue-size')), '4');
    await tester.tap(find.byKey(const Key('report-submit')));
    await tester.pumpAndSettle();

    expect(
      find.text('Could not reach the server. Make sure the backend is running.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('report-success')), findsNothing);
  });

  testWidgets('the done button returns to the water points', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _app(_client((_) async => http.Response(_reportBody(), 201))),
    );

    await tester.enterText(find.byKey(const Key('report-queue-size')), '4');
    await tester.tap(find.byKey(const Key('report-submit')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('report-done')), findsOneWidget);

    await tester.tap(find.byKey(const Key('report-done')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('report-success')), findsNothing);
  });
}
