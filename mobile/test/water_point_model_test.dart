import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/models/water_point.dart';

Map<String, dynamic> _waterPointJson({
  String waterAvailable = 'available',
  Object? queueSize = 5,
  Object? estimatedWaitMinutes = 10,
  int confidence = 80,
  Object? lastReportedAt = '2024-05-01T10:00:00.000Z',
  bool includeStatus = true,
}) {
  return <String, dynamic>{
    'id': 'aaaaaaaa-bbbb-cccc-dddd-000000000001',
    'name': 'Bole Medhanealem Well',
    'address': 'Bole Subcity, near Medhanealem Church, Addis Ababa',
    'latitude': 8.9867,
    'longitude': 38.7993,
    'operatingHours': '06:00-22:00',
    'isActive': true,
    'createdAt': '2024-01-01T00:00:00.000Z',
    if (includeStatus)
      'currentStatus': <String, dynamic>{
        'waterAvailable': waterAvailable,
        'queueSize': queueSize,
        'estimatedWaitMinutes': estimatedWaitMinutes,
        'confidence': confidence,
        'lastReportedAt': lastReportedAt,
      },
  };
}

void main() {
  group('WaterPoint.fromJson', () {
    test('maps every field of the backend response', () {
      final WaterPoint waterPoint = WaterPoint.fromJson(_waterPointJson());

      expect(waterPoint.id, 'aaaaaaaa-bbbb-cccc-dddd-000000000001');
      expect(waterPoint.name, 'Bole Medhanealem Well');
      expect(
        waterPoint.address,
        'Bole Subcity, near Medhanealem Church, Addis Ababa',
      );
      expect(waterPoint.latitude, 8.9867);
      expect(waterPoint.longitude, 38.7993);
      expect(waterPoint.operatingHours, '06:00-22:00');
      expect(waterPoint.isActive, isTrue);
      expect(waterPoint.createdAt, DateTime.parse('2024-01-01T00:00:00.000Z'));
    });

    test('maps the current status of the backend response', () {
      final WaterPoint waterPoint = WaterPoint.fromJson(_waterPointJson());

      expect(waterPoint.status.waterAvailable, WaterAvailability.available);
      expect(waterPoint.status.queueSize, 5);
      expect(waterPoint.status.estimatedWaitMinutes, 10);
      expect(waterPoint.status.confidence, 80);
      expect(
        waterPoint.status.lastReportedAt,
        DateTime.parse('2024-05-01T10:00:00.000Z'),
      );
    });

    test('treats the "unknown" queue size and wait time as missing values', () {
      final WaterPoint waterPoint = WaterPoint.fromJson(
        _waterPointJson(
          waterAvailable: 'unknown',
          queueSize: 'unknown',
          estimatedWaitMinutes: 'unknown',
          confidence: 0,
          lastReportedAt: null,
        ),
      );

      expect(waterPoint.status.waterAvailable, WaterAvailability.unknown);
      expect(waterPoint.status.queueSize, isNull);
      expect(waterPoint.status.estimatedWaitMinutes, isNull);
      expect(waterPoint.status.confidence, 0);
      expect(waterPoint.status.lastReportedAt, isNull);
    });

    test('falls back to the unknown status when no status is returned', () {
      final WaterPoint waterPoint = WaterPoint.fromJson(
        _waterPointJson(includeStatus: false),
      );

      expect(waterPoint.status.waterAvailable, WaterAvailability.unknown);
      expect(waterPoint.status.queueSize, isNull);
      expect(waterPoint.status.confidence, 0);
    });

    test('falls back to unknown for an unrecognised availability value', () {
      final WaterPoint waterPoint = WaterPoint.fromJson(
        _waterPointJson(waterAvailable: 'flooded'),
      );

      expect(waterPoint.status.waterAvailable, WaterAvailability.unknown);
    });
  });

  group('WaterAvailability', () {
    test('exposes a label for every backend value', () {
      expect(WaterAvailability.available.label, 'Water available');
      expect(WaterAvailability.unavailable.label, 'Water unavailable');
      expect(WaterAvailability.uncertain.label, 'Status uncertain');
      expect(WaterAvailability.unknown.label, 'No reports yet');
    });
  });
}
