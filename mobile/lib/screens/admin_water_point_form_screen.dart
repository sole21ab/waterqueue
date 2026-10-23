import 'package:flutter/material.dart';

import '../models/water_point.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';

/// Form where an administrator creates or edits a water point.
///
/// The form is submitted to the backend admin routes `POST /water-points` and
/// `PUT /water-points/:id`, using the signed-in administrator's JWT.
class AdminWaterPointFormScreen extends StatefulWidget {
  const AdminWaterPointFormScreen({
    super.key,
    required this.token,
    required this.apiClient,
    this.waterPoint,
  });

  /// JWT of the signed-in administrator.
  final String token;

  final ApiClient apiClient;

  /// The water point to edit, or `null` to create a new one.
  final WaterPoint? waterPoint;

  /// Whether the form edits an existing water point.
  bool get isEditing => waterPoint != null;

  @override
  State<AdminWaterPointFormScreen> createState() =>
      _AdminWaterPointFormScreenState();
}

class _AdminWaterPointFormScreenState
    extends State<AdminWaterPointFormScreen> {
  /// The backend limits the name to 255 characters.
  static const int _maxNameLength = 255;

  /// The backend limits the address to 500 characters.
  static const int _maxAddressLength = 500;

  /// The backend limits the operating hours to 100 characters.
  static const int _maxOperatingHoursLength = 100;

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _latitudeController = TextEditingController();
  final TextEditingController _longitudeController = TextEditingController();
  final TextEditingController _operatingHoursController = TextEditingController();

  bool _isActive = true;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    final WaterPoint? waterPoint = widget.waterPoint;
    if (waterPoint != null) {
      _nameController.text = waterPoint.name;
      _addressController.text = waterPoint.address;
      _latitudeController.text = waterPoint.latitude.toString();
      _longitudeController.text = waterPoint.longitude.toString();
      _operatingHoursController.text = waterPoint.operatingHours;
      _isActive = waterPoint.isActive;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    _operatingHoursController.dispose();
    super.dispose();
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

    final String name = _nameController.text.trim();
    final String address = _addressController.text.trim();
    final double latitude = double.parse(_latitudeController.text.trim());
    final double longitude = double.parse(_longitudeController.text.trim());
    final String operatingHours = _operatingHoursController.text.trim();

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final WaterPoint? waterPoint = widget.waterPoint;
      if (waterPoint != null) {
        await widget.apiClient.updateWaterPoint(
          token: widget.token,
          waterPointId: waterPoint.id,
          name: name,
          address: address,
          latitude: latitude,
          longitude: longitude,
          operatingHours: operatingHours,
          isActive: _isActive,
        );
      } else {
        await widget.apiClient.createWaterPoint(
          token: widget.token,
          name: name,
          address: address,
          latitude: latitude,
          longitude: longitude,
          operatingHours: operatingHours,
          isActive: _isActive,
        );
      }

      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(
        widget.isEditing ? 'Water point updated.' : 'Water point created.',
      );
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

  String? _validateName(String? value) {
    final String name = (value ?? '').trim();
    if (name.isEmpty) {
      return 'Name is required.';
    }
    if (name.length > _maxNameLength) {
      return 'Name must be $_maxNameLength characters or fewer.';
    }
    return null;
  }

  String? _validateAddress(String? value) {
    final String address = (value ?? '').trim();
    if (address.isEmpty) {
      return 'Address is required.';
    }
    if (address.length > _maxAddressLength) {
      return 'Address must be $_maxAddressLength characters or fewer.';
    }
    return null;
  }

  String? _validateLatitude(String? value) {
    return _validateCoordinate(
      value,
      label: 'Latitude',
      min: -90,
      max: 90,
    );
  }

  String? _validateLongitude(String? value) {
    return _validateCoordinate(
      value,
      label: 'Longitude',
      min: -180,
      max: 180,
    );
  }

  /// Validates a coordinate against the range the backend accepts.
  String? _validateCoordinate(
    String? value, {
    required String label,
    required double min,
    required double max,
  }) {
    final String text = (value ?? '').trim();
    if (text.isEmpty) {
      return '$label is required.';
    }

    final double? parsed = double.tryParse(text);
    if (parsed == null) {
      return '$label must be a number.';
    }
    if (parsed < min || parsed > max) {
      return '$label must be between $min and $max.';
    }
    return null;
  }

  String? _validateOperatingHours(String? value) {
    final String hours = (value ?? '').trim();
    if (hours.isEmpty) {
      return 'Operating hours are required.';
    }
    if (hours.length > _maxOperatingHoursLength) {
      return 'Operating hours must be $_maxOperatingHoursLength characters or '
          'fewer.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edit water point' : 'New water point'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    TextFormField(
                      key: const Key('admin-water-point-name'),
                      controller: _nameController,
                      enabled: !_isSubmitting,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Name',
                        border: OutlineInputBorder(),
                      ),
                      validator: _validateName,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      key: const Key('admin-water-point-address'),
                      controller: _addressController,
                      enabled: !_isSubmitting,
                      textInputAction: TextInputAction.next,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Address',
                        border: OutlineInputBorder(),
                      ),
                      validator: _validateAddress,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(
                          child: TextFormField(
                            key: const Key('admin-water-point-latitude'),
                            controller: _latitudeController,
                            enabled: !_isSubmitting,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                              signed: true,
                            ),
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Latitude',
                              helperText: 'Between -90 and 90',
                              border: OutlineInputBorder(),
                            ),
                            validator: _validateLatitude,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            key: const Key('admin-water-point-longitude'),
                            controller: _longitudeController,
                            enabled: !_isSubmitting,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                              signed: true,
                            ),
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Longitude',
                              helperText: 'Between -180 and 180',
                              border: OutlineInputBorder(),
                            ),
                            validator: _validateLongitude,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      key: const Key('admin-water-point-operating-hours'),
                      controller: _operatingHoursController,
                      enabled: !_isSubmitting,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _submit(),
                      decoration: const InputDecoration(
                        labelText: 'Operating hours',
                        helperText: 'For example 06:00-22:00 or 24/7',
                        border: OutlineInputBorder(),
                      ),
                      validator: _validateOperatingHours,
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      key: const Key('admin-water-point-active'),
                      value: _isActive,
                      onChanged: _isSubmitting
                          ? null
                          : (bool value) => setState(() => _isActive = value),
                      title: const Text('Active'),
                      subtitle: Text(
                        'Inactive water points are hidden from residents.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                    if (_errorMessage != null) ...<Widget>[
                      const SizedBox(height: 16),
                      _ErrorBanner(message: _errorMessage!),
                    ],
                    const SizedBox(height: 24),
                    FilledButton(
                      key: const Key('admin-water-point-submit'),
                      onPressed: _isSubmitting ? null : _submit,
                      child: _isSubmitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              widget.isEditing
                                  ? 'Save changes'
                                  : 'Create water point',
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Inline error message shown when the water point could not be saved.
class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('admin-water-point-error'),
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
              key: const Key('admin-water-point-error-message'),
              style: const TextStyle(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );
  }
}
