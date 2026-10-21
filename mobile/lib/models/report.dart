/// A resident report about a water point.
///
/// Mirrors the report object returned by the backend route
/// `POST /water-points/:id/reports`.
class Report {
  const Report({
    required this.id,
    required this.waterPointId,
    required this.userId,
    required this.waterAvailable,
    required this.queueSize,
    this.estimatedWaitMinutes,
    this.createdAt,
  });

  factory Report.fromJson(Map<String, dynamic> json) {
    return Report(
      id: _readString(json['id']),
      waterPointId: _readString(json['waterPointId']),
      userId: _readString(json['userId']),
      waterAvailable: json['waterAvailable'] is bool
          ? json['waterAvailable'] as bool
          : false,
      queueSize: _readInt(json['queueSize']) ?? 0,
      estimatedWaitMinutes: _readInt(json['estimatedWaitMinutes']),
      createdAt: DateTime.tryParse(_readString(json['createdAt'])),
    );
  }

  /// Identifier of the created report.
  final String id;

  /// Identifier of the water point the report belongs to.
  final String waterPointId;

  /// Identifier of the resident who submitted the report.
  final String userId;

  /// Whether water was available when the report was submitted.
  final bool waterAvailable;

  /// Number of people in the queue, between 0 and 50.
  final int queueSize;

  /// Estimated wait in minutes, when the backend returns one.
  final int? estimatedWaitMinutes;

  /// Time at which the report was created.
  final DateTime? createdAt;

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
