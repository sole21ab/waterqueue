import 'package:flutter/material.dart';

import '../models/report.dart';
import '../models/water_point.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';

/// Form where a resident reports the current availability and queue size of a
/// water point.
///
/// The report is submitted to the backend route
/// `POST /water-points/:id/reports` with the signed-in resident's JWT.
class ReportScreen extends StatefulWidget {
  const ReportScreen({
    super.key,
    required this.waterPoint,
    required this.apiClient,
    required this.token,
  });

  final WaterPoint waterPoint;
  final ApiClient apiClient;
  final String token;

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  /// The backend accepts a queue size between 0 and 50 inclusive.
  static const int minQueueSize = 0;
  static const int maxQueueSize = 50;

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _queueSizeController = TextEditingController(
    text: '0',
  );

  bool _waterAvailable = true;
  double _queueSize = 0;
  bool _isSubmitting = false;
  String? _errorMessage;
  Report? _submittedReport;

  @override
  void initState() {
    super.initState();
    _queueSizeController.addListener(_handleQueueSizeTextChanged);
  }

  @override
  void dispose() {
    _queueSizeController
      ..removeListener(_handleQueueSizeTextChanged)
      ..dispose();
    super.dispose();
  }

  /// Keeps the slider in sync with a queue size typed by the resident.
  void _handleQueueSizeTextChanged() {
    final int? parsed = int.tryParse(_queueSizeController.text.trim());
    if (parsed == null || parsed < minQueueSize || parsed > maxQueueSize) {
      return;
    }
    if (parsed.toDouble() != _queueSize) {
      setState(() => _queueSize = parsed.toDouble());
    }
  }

  void _handleSliderChanged(double value) {
    final int queueSize = value.round();
    setState(() {
      _queueSize = queueSize.toDouble();
      _queueSizeController.text = queueSize.toString();
    });
  }

  String? _validateQueueSize(String? value) {
    final String text = (value ?? '').trim();
    if (text.isEmpty) {
      return 'Enter the queue size.';
    }

    final int? parsed = int.tryParse(text);
    if (parsed == null) {
      return 'Queue size must be a whole number.';
    }
    if (parsed < minQueueSize) {
      return 'Queue size cannot be less than $minQueueSize.';
    }
    if (parsed > maxQueueSize) {
      return 'Queue size must be $maxQueueSize or less.';
    }
    return null;
  }

  Future<void> _submit() async {
    if (_isSubmitting) {
      return;
    }

    FocusScope.of(context).unfocus();

    final FormState? form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }

    final int queueSize = int.parse(_queueSizeController.text.trim());

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final Report report = await widget.apiClient.submitReport(
        waterPointId: widget.waterPoint.id,
        token: widget.token,
        waterAvailable: _waterAvailable,
        queueSize: queueSize,
      );

      if (!mounted) {
        return;
      }
      setState(() {
        _isSubmitting = false;
        _submittedReport = report;
      });
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSubmitting = false;
        _errorMessage = error.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSubmitting = false;
        _errorMessage = 'Something went wrong. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Report status'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).pop(_submittedReport != null),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: _submittedReport != null
                  ? _buildSuccess(theme)
                  : _buildForm(theme),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildForm(ThemeData theme) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _WaterPointSummary(waterPoint: widget.waterPoint),
          const SizedBox(height: 24),
          Text(
            'Is water available right now?',
            style: theme.textTheme.titleSmall?.copyWith(
              color: AppColors.textStrong,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          SegmentedButton<bool>(
            key: const Key('report-water-available'),
            segments: const <ButtonSegment<bool>>[
              ButtonSegment<bool>(
                value: true,
                label: Text('Water available'),
                icon: Icon(Icons.water_drop),
              ),
              ButtonSegment<bool>(
                value: false,
                label: Text('No water'),
                icon: Icon(Icons.block),
              ),
            ],
            selected: <bool>{_waterAvailable},
            onSelectionChanged: _isSubmitting
                ? null
                : (Set<bool> selection) {
                    setState(() => _waterAvailable = selection.first);
                  },
          ),
          const SizedBox(height: 24),
          Text(
            'How many people are queuing?',
            style: theme.textTheme.titleSmall?.copyWith(
              color: AppColors.textStrong,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            key: const Key('report-queue-size'),
            controller: _queueSizeController,
            enabled: !_isSubmitting,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _submit(),
            decoration: const InputDecoration(
              labelText: 'Queue size',
              helperText: 'Between 0 and 50 people',
              border: OutlineInputBorder(),
            ),
            validator: _validateQueueSize,
          ),
          const SizedBox(height: 12),
          Slider(
            key: const Key('report-queue-slider'),
            value: _queueSize,
            min: minQueueSize.toDouble(),
            max: maxQueueSize.toDouble(),
            divisions: maxQueueSize - minQueueSize,
            label: _queueSize.round().toString(),
            onChanged: _isSubmitting ? null : _handleSliderChanged,
          ),
          if (_errorMessage != null) ...<Widget>[
            const SizedBox(height: 16),
            _ErrorBanner(message: _errorMessage!),
          ],
          const SizedBox(height: 24),
          FilledButton(
            key: const Key('report-submit'),
            onPressed: _isSubmitting ? null : _submit,
            child: _isSubmitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Submit report'),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccess(ThemeData theme) {
    return Column(
      key: const Key('report-success'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const Icon(
          Icons.check_circle,
          size: 56,
          color: AppColors.primaryDeep,
        ),
        const SizedBox(height: 12),
        Text(
          'Report submitted',
          key: const Key('report-success-title'),
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium?.copyWith(
            color: AppColors.textStrong,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Thanks! Your report about ${widget.waterPoint.name} helps the '
          'residents of your community.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 24),
        FilledButton(
          key: const Key('report-done'),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Back to water points'),
        ),
      ],
    );
  }
}

/// Header that shows which water point is being reported.
class _WaterPointSummary extends StatelessWidget {
  const _WaterPointSummary({required this.waterPoint});

  final WaterPoint waterPoint;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfacePale,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.place, color: AppColors.primaryDeep),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  waterPoint.name,
                  key: const Key('report-water-point-name'),
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: AppColors.primaryDeep,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (waterPoint.address.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(
                    waterPoint.address,
                    key: const Key('report-water-point-address'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Inline error message shown when the report could not be submitted.
class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('report-error'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.dangerSurface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(Icons.error_outline, size: 20, color: AppColors.danger),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              key: const Key('report-error-message'),
              style: const TextStyle(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );
  }
}
