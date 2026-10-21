/// Availability status of a water point, as computed by the backend.
///
/// Mirrors the `WaterAvailabilityStatus` union in
/// `backend/src/services/reporting.ts`.
enum WaterAvailability {
  available('available', 'Water available'),
  unavailable('unavailable', 'Water unavailable'),
  uncertain('uncertain', 'Status uncertain'),
  unknown('unknown', 'No reports yet');

  const WaterAvailability(this.value, this.label);

  /// Raw value sent by the backend.
  final String value;

  /// Human readable label shown in the app.
  final String label;

  /// Parses the backend value, falling back to [WaterAvailability.unknown].
  static WaterAvailability fromValue(Object? value) {
    for (final WaterAvailability status in WaterAvailability.values) {
      if (status.value == value) {
        return status;
      }
    }
    return WaterAvailability.unknown;
  }
}

/// Current status of a water point, mirroring the `CurrentStatus` object
/// returned inside each water point by `GET /water-points`.
class WaterPointStatus {
  const WaterPointStatus({
    required this.waterAvailable,
    this.queueSize,
    this.estimatedWaitMinutes,
    this.confidence = 0,
    this.lastReportedAt,
  });

  factory WaterPointStatus.fromJson(Map<String, dynamic> json) {
    return WaterPointStatus(
      waterAvailable: WaterAvailability.fromValue(json['waterAvailable']),
      queueSize: _readIntOrNull(json['queueSize']),
      estimatedWaitMinutes: _readIntOrNull(json['estimatedWaitMinutes']),
      confidence: _readInt(json['confidence']) ?? 0,
      lastReportedAt: DateTime.tryParse(_readString(json['lastReportedAt'])),
    );
  }

  static const WaterPointStatus unknown = WaterPointStatus(
    waterAvailable: WaterAvailability.unknown,
  );

  final WaterAvailability waterAvailable;

  /// Number of people in the queue, or `null` when the backend reports
  /// `"unknown"`.
  final int? queueSize;

  /// Estimated wait in minutes, or `null` when the backend reports
  /// `"unknown"`.
  final int? estimatedWaitMinutes;

  /// Confidence percentage (0-100) of the computed status.
  final int confidence;

  /// Timestamp of the most recent report used for the status, if any.
  final DateTime? lastReportedAt;

  static int? _readIntOrNull(Object? value) {
    if (value is num) {
      return value.toInt();
    }
    return null;
  }

  static int? _readInt(Object? value) {
    if (value is num) {
      return value.toInt();
    }
    return null;
  }

  static String _readString(Object? value) {
    return value is String ? value : '';
  }
}

/// A community water point as returned by the backend water-point routes.
class WaterPoint {
  const WaterPoint({
    required this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.operatingHours,
    required this.isActive,
    this.createdAt,
    this.status = WaterPointStatus.unknown,
  });

  factory WaterPoint.fromJson(Map<String, dynamic> json) {
    final Object? rawStatus = json['currentStatus'];
    final Map<String, dynamic> statusJson = rawStatus is Map<String, dynamic>
        ? rawStatus
        : const <String, dynamic>{};

    return WaterPoint(
      id: _readString(json['id']),
      name: _readString(json['name']),
      address: _readString(json['address']),
      latitude: _readDouble(json['latitude']),
      longitude: _readDouble(json['longitude']),
      operatingHours: _readString(json['operatingHours']),
      isActive: json['isActive'] is bool ? json['isActive'] as bool : true,
      createdAt: DateTime.tryParse(_readString(json['createdAt'])),
      status: WaterPointStatus.fromJson(statusJson),
    );
  }

  final String id;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final String operatingHours;
  final bool isActive;
  final DateTime? createdAt;

  /// Availability, queue and confidence information for this water point.
  final WaterPointStatus status;

  static double _readDouble(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    return 0;
  }

  static String _readString(Object? value) {
    return value is String ? value : '';
  }
}
