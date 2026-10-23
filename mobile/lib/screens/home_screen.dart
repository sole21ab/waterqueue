import 'package:flutter/material.dart';

import '../models/auth_user.dart';
import '../models/water_point.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';
import '../widgets/water_point_card.dart';
import 'admin_water_points_screen.dart';
import 'report_screen.dart';

/// Home screen shown after a successful sign-in.
///
/// It keeps the signed-in account details visible and lists the water points
/// returned by the backend `GET /water-points` route.
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.user,
    required this.token,
    required this.apiClient,
    required this.onSignOut,
  });

  final AuthUser user;

  /// JWT of the signed-in resident, used to submit reports.
  final String token;

  final ApiClient apiClient;
  final VoidCallback onSignOut;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<WaterPoint> _waterPoints = const <WaterPoint>[];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _isLoading = true;
    _fetchWaterPoints();
  }

  /// Loads the water points and keeps the previously loaded list visible, so a
  /// failed pull-to-refresh does not wipe the screen.
  Future<void> _refresh() async {
    final String? error = await _fetchWaterPoints();
    if (error != null && mounted && _waterPoints.isNotEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  /// Loads the water points behind a full-screen loading indicator.
  Future<void> _reload() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    await _fetchWaterPoints();
  }

  Future<String?> _fetchWaterPoints() async {
    try {
      final List<WaterPoint> waterPoints =
          await widget.apiClient.fetchWaterPoints();
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

  /// Opens the report form for [waterPoint] and reloads the list when a
  /// report was submitted.
  Future<void> _openReport(WaterPoint waterPoint) async {
    final bool? reported = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (BuildContext context) => ReportScreen(
          waterPoint: waterPoint,
          apiClient: widget.apiClient,
          token: widget.token,
        ),
      ),
    );

    if (reported == true && mounted) {
      await _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.user.isAdmin) {
      return AdminWaterPointsScreen(
        token: widget.token,
        apiClient: widget.apiClient,
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('WaterQueue'),
        centerTitle: true,
        actions: <Widget>[
          IconButton(
            key: const Key('home-refresh'),
            onPressed: _isLoading ? null : _reload,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh water points',
          ),
          IconButton(
            key: const Key('sign-out'),
            onPressed: widget.onSignOut,
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: _AccountCard(
                    user: widget.user,
                    onSignOut: widget.onSignOut,
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
        child: CircularProgressIndicator(key: Key('water-points-loading')),
      );
    }

    if (_errorMessage != null && _waterPoints.isEmpty) {
      return _scrollableState(
        _ErrorState(message: _errorMessage!, onRetry: _reload),
      );
    }

    if (_waterPoints.isEmpty) {
      return _scrollableState(
        const _EmptyState(),
      );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      color: AppColors.primary,
      child: ListView.separated(
        key: const Key('water-points-list'),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _waterPoints.length,
        separatorBuilder: (BuildContext context, int index) =>
            const SizedBox(height: 12),
        itemBuilder: (BuildContext context, int index) {
          final WaterPoint waterPoint = _waterPoints[index];
          return WaterPointCard(
            waterPoint: waterPoint,
            onReport: () => _openReport(waterPoint),
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

class _AccountCard extends StatelessWidget {
  const _AccountCard({required this.user, required this.onSignOut});

  final AuthUser user;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: <Widget>[
            CircleAvatar(
              backgroundColor: AppColors.surfacePale,
              foregroundColor: AppColors.primaryDeep,
              child: const Icon(Icons.person),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    user.email,
                    key: const Key('home-email'),
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: AppColors.textStrong,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Role: ${user.role}',
                    key: const Key('home-role'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            OutlinedButton(
              key: const Key('home-sign-out'),
              onPressed: onSignOut,
              child: const Text('Sign out'),
            ),
          ],
        ),
      ),
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
            key: const Key('water-points-empty'),
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              color: AppColors.textStrong,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'No active water points have been published yet. Pull down to '
            'refresh.',
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
            key: const Key('water-points-error'),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            key: const Key('water-points-retry'),
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
