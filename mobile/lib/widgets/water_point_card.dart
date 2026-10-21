import 'package:flutter/material.dart';

import '../models/water_point.dart';
import '../theme/app_theme.dart';

/// Formats a timestamp as a short relative age such as `5 min ago`.
String formatRelativeTime(DateTime? time) {
  if (time == null) {
    return 'Never reported';
  }

  final Duration age = DateTime.now().difference(time);
  if (age.isNegative || age.inMinutes < 1) {
    return 'Just now';
  }
  if (age.inMinutes < 60) {
    return '${age.inMinutes} min ago';
  }
  if (age.inHours < 24) {
    return '${age.inHours} h ago';
  }
  return '${age.inDays} d ago';
}

/// Renders a single water point with the location, availability and queue
/// information the backend returns for it.
class WaterPointCard extends StatelessWidget {
  const WaterPointCard({super.key, required this.waterPoint});

  final WaterPoint waterPoint;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Text(
                    waterPoint.name,
                    key: const Key('water-point-name'),
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: AppColors.primaryDeep,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                _AvailabilityChip(status: waterPoint.status),
              ],
            ),
            const SizedBox(height: 12),
            _DetailRow(
              icon: Icons.place_outlined,
              text: waterPoint.address.isEmpty
                  ? 'No address provided'
                  : waterPoint.address,
            ),
            const SizedBox(height: 6),
            _DetailRow(
              icon: Icons.schedule,
              text: waterPoint.operatingHours.isEmpty
                  ? 'Operating hours not provided'
                  : 'Open ${waterPoint.operatingHours}',
            ),
            const SizedBox(height: 6),
            _DetailRow(
              icon: Icons.people_outline,
              text: _queueSummary(waterPoint.status),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfacePale,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      _confidenceSummary(waterPoint.status),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.primaryDeep,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    formatRelativeTime(waterPoint.status.lastReportedAt),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _queueSummary(WaterPointStatus status) {
    final int? queueSize = status.queueSize;
    final int? waitMinutes = status.estimatedWaitMinutes;

    if (queueSize == null && waitMinutes == null) {
      return 'Queue size unknown';
    }

    final String queue = queueSize == null
        ? 'Queue size unknown'
        : 'Queue: $queueSize ${queueSize == 1 ? 'person' : 'people'}';
    final String wait = waitMinutes == null
        ? 'Wait time unknown'
        : 'About $waitMinutes min wait';

    return '$queue · $wait';
  }

  static String _confidenceSummary(WaterPointStatus status) {
    if (status.confidence <= 0) {
      return 'Confidence unknown';
    }
    return 'Confidence ${status.confidence}%';
  }
}

class _AvailabilityChip extends StatelessWidget {
  const _AvailabilityChip({required this.status});

  final WaterPointStatus status;

  @override
  Widget build(BuildContext context) {
    final (Color background, Color foreground, IconData icon) = switch (
      status.waterAvailable
    ) {
      WaterAvailability.available => (
        AppColors.surfacePale,
        AppColors.primaryDeep,
        Icons.water_drop,
      ),
      WaterAvailability.unavailable => (
        AppColors.dangerSurface,
        AppColors.danger,
        Icons.cancel,
      ),
      WaterAvailability.uncertain => (
        AppColors.warningSurface,
        AppColors.warning,
        Icons.help_outline,
      ),
      WaterAvailability.unknown => (
        AppColors.neutralSurface,
        AppColors.neutral,
        Icons.remove_circle_outline,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 16, color: foreground),
          const SizedBox(width: 6),
          Text(
            status.waterAvailable.label,
            key: const Key('water-point-status'),
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(icon, size: 18, color: AppColors.primaryDeep),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textMuted,
            ),
          ),
        ),
      ],
    );
  }
}
