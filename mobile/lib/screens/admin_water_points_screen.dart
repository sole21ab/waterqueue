import 'package:flutter/material.dart';

import '../models/water_point.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';
import 'admin_water_point_form_screen.dart';

/// Admin screen listing the water points and offering the management actions
/// the backend exposes to administrators.
///
/// The screen is only reachable for accounts with the `admin` role. Every
/// request is sent with the administrator's JWT, and the backend remains the
/// authority that rejects unauthorized administrative requests.
class AdminWaterPointsScreen extends StatefulWidget {
  const AdminWaterPointsScreen({
    super.key,
    required this.token,
    required this.apiClient,
    required this.onSignOut,
  });

  /// JWT of the signed-in administrator.
  final String token;

  final ApiClient apiClient;

  /// Clears the session and returns the user to the sign-in screen.
  final VoidCallback onSignOut;

  @override
  State<AdminWaterPointsScreen> createState() => _AdminWaterPointsScreenState();
}

class _AdminWaterPointsScreenState extends State<AdminWaterPointsScreen> {
  List<WaterPoint> _waterPoints = const <WaterPoint>[];
  bool _isLoading = true;
  bool _includeInactive = false;
  String? _errorMessage;
  String? _pendingId;

  @override
  void initState() {
    super.initState();
    _isLoading = true;
    _fetchWaterPoints();
  }

  /// Reloads the water points behind a full-screen loading indicator.
  Future<void> _reload() async {
    if (!mounted) {
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    await _fetchWaterPoints();
  }

  /// Reloads the water points and keeps the list visible, so a failed refresh
  /// does not wipe the screen.
  Future<void> _refresh() async {
    final String? error = await _fetchWaterPoints();
    if (error != null && mounted && _waterPoints.isNotEmpty) {
      _showMessage(error);
    }
  }

  Future<String?> _fetchWaterPoints() async {
    try {
      final List<WaterPoint> waterPoints = await widget.apiClient
          .fetchAdminWaterPoints(includeInactive: _includeInactive);
      if (!mounted) {
        return null;
      }
      setState(() {
        _waterPoints = waterPoints;
        _errorMessage = null;
        _isLoading = false;
      });
      return null;
    } on ApiException catch (error) {
      if (!mounted) {
        return error.message;
      }
      setState(() {
        _errorMessage = error.message;
        _isLoading = false;
      });
      return error.message;
    } catch (_) {
      const String message = 'Something went wrong while loading water points.';
      if (!mounted) {
        return message;
      }
      setState(() {
        _errorMessage = message;
        _isLoading = false;
      });
      return message;
    }
  }

  /// Shows or hides the deactivated water points in the list.
  Future<void> _setIncludeInactive(bool includeInactive) async {
    if (includeInactive == _includeInactive) {
      return;
    }
    setState(() => _includeInactive = includeInactive);
    await _reload();
  }

  /// Opens the form that creates a new water point.
  Future<void> _openCreateForm() async {
    final String? message = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (BuildContext context) => AdminWaterPointFormScreen(
          token: widget.token,
          apiClient: widget.apiClient,
        ),
      ),
    );

    if (!mounted || message == null) {
      return;
    }
    await _reload();
    _showMessage(message);
  }

  /// Opens the form that edits an existing water point.
  Future<void> _openEditForm(WaterPoint waterPoint) async {
    final String? message = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (BuildContext context) => AdminWaterPointFormScreen(
          token: widget.token,
          apiClient: widget.apiClient,
          waterPoint: waterPoint,
        ),
      ),
    );

    if (!mounted || message == null) {
      return;
    }
    await _reload();
    _showMessage(message);
  }

  /// Deactivates a water point after the administrator confirms it.
  Future<void> _deactivate(WaterPoint waterPoint) async {
    final bool confirmed = await _confirmDeactivate(waterPoint);
    if (!confirmed || !mounted) {
      return;
    }

    setState(() => _pendingId = waterPoint.id);

    try {
      await widget.apiClient.deactivateWaterPoint(
        token: widget.token,
        waterPointId: waterPoint.id,
      );

      if (!mounted) {
        return;
      }
      setState(() => _pendingId = null);
      await _reload();
      _showMessage('${waterPoint.name} was deactivated.');
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _pendingId = null);
      _showMessage(error.message);
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _pendingId = null);
      _showMessage('Something went wrong. Please try again.');
    }
  }

  Future<bool> _confirmDeactivate(WaterPoint waterPoint) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Deactivate water point?'),
        content: Text(
          '${waterPoint.name} will no longer be visible to residents.',
        ),
        actions: <Widget>[
          TextButton(
            key: const Key('admin-deactivate-cancel'),
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('admin-deactivate-confirm'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );

    return confirmed ?? false;
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage water points'),
        actions: <Widget>[
          IconButton(
            key: const Key('admin-refresh'),
            onPressed: _isLoading ? null : _reload,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh water points',
          ),
          IconButton(
            key: const Key('admin-sign-out'),
            onPressed: widget.onSignOut,
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        key: const Key('admin-add-water-point'),
        onPressed: _openCreateForm,
        tooltip: 'Add water point',
        child: const Icon(Icons.add),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: _FilterBar(
                    includeInactive: _includeInactive,
                    onChanged: _setIncludeInactive,
                  ),
                ),
                Expanded(child: _buildContent()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(key: Key('admin-water-points-loading')),
      );
    }

    if (_errorMessage != null && _waterPoints.isEmpty) {
      return _scrollableState(
        _ErrorState(message: _errorMessage!, onRetry: _reload),
      );
    }

    if (_waterPoints.isEmpty) {
      return _scrollableState(const _EmptyState());
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      color: AppColors.primary,
      child: ListView.separated(
        key: const Key('admin-water-points-list'),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _waterPoints.length,
        separatorBuilder: (BuildContext context, int index) =>
            const SizedBox(height: 12),
        itemBuilder: (BuildContext context, int index) {
          final WaterPoint waterPoint = _waterPoints[index];
          return _AdminWaterPointTile(
            waterPoint: waterPoint,
            isBusy: _pendingId == waterPoint.id,
            onEdit: () => _openEditForm(waterPoint),
            onDeactivate: () => _deactivate(waterPoint),
          );
        },
      ),
    );
  }

  Widget _scrollableState(Widget child) {
    return RefreshIndicator(
      onRefresh: _refresh,
      color: AppColors.primary,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Center(child: child),
            ),
          );
        },
      ),
    );
  }
}

/// Bar that lets the administrator include the deactivated water points.
class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.includeInactive, required this.onChanged});

  final bool includeInactive;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: FilterChip(
        key: const Key('admin-include-inactive'),
        selected: includeInactive,
        onSelected: onChanged,
        avatar: Icon(
          includeInactive ? Icons.visibility : Icons.visibility_off_outlined,
          size: 18,
          color: AppColors.primaryDeep,
        ),
        label: const Text('Show deactivated'),
      ),
    );
  }
}

/// Card that lists a single water point with the admin actions.
class _AdminWaterPointTile extends StatelessWidget {
  const _AdminWaterPointTile({
    required this.waterPoint,
    required this.onEdit,
    required this.onDeactivate,
    this.isBusy = false,
  });

  final WaterPoint waterPoint;
  final VoidCallback onEdit;
  final VoidCallback onDeactivate;
  final bool isBusy;

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
                    key: const Key('admin-water-point-name'),
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: AppColors.primaryDeep,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                _ActiveChip(isActive: waterPoint.isActive),
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
              icon: Icons.my_location_outlined,
              text: '${waterPoint.latitude}, ${waterPoint.longitude}',
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton.icon(
                    key: const Key('admin-water-point-edit'),
                    onPressed: isBusy ? null : onEdit,
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Edit'),
                  ),
                ),
                if (waterPoint.isActive) ...<Widget>[
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const Key('admin-water-point-deactivate'),
                      onPressed: isBusy ? null : onDeactivate,
                      icon: const Icon(Icons.power_settings_new),
                      label: const Text('Deactivate'),
                    ),
                  ),
                ],
              ],
            ),
            if (isBusy) ...<Widget>[
              const SizedBox(height: 12),
              const Center(
                child: CircularProgressIndicator(
                  key: Key('admin-water-point-busy'),
                  strokeWidth: 2,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Chip that shows whether residents can still see the water point.
class _ActiveChip extends StatelessWidget {
  const _ActiveChip({required this.isActive});

  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final Color background = isActive
        ? AppColors.surfacePale
        : AppColors.neutralSurface;
    final Color foreground = isActive
        ? AppColors.primaryDeep
        : AppColors.neutral;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            isActive ? Icons.check_circle_outline : Icons.do_not_disturb_on,
            size: 16,
            color: foreground,
          ),
          const SizedBox(width: 6),
          Text(
            isActive ? 'Active' : 'Deactivated',
            key: const Key('admin-water-point-active-chip'),
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

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(
            Icons.water_drop,
            size: 56,
            color: AppColors.primaryDeep,
          ),
          const SizedBox(height: 12),
          Text(
            'No water points available',
            key: const Key('admin-water-points-empty'),
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              color: AppColors.textStrong,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add the first water point with the button below.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(
            Icons.cloud_off,
            size: 56,
            color: AppColors.danger,
          ),
          const SizedBox(height: 12),
          Text(
            'Could not load water points',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              color: AppColors.textStrong,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            key: const Key('admin-water-points-error'),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            key: const Key('admin-water-points-retry'),
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
