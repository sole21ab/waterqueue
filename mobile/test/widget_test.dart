import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/main.dart';

void main() {
  testWidgets('Home screen shows app name and empty state', (WidgetTester tester) async {
    await tester.pumpWidget(const WaterQueueApp());

    expect(find.text('WaterQueue'), findsAtLeastNWidgets(1));
    expect(find.text('No water points yet'), findsOneWidget);
  });
}
