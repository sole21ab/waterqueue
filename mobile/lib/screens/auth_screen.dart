import 'dart:convert';

import 'package:flutter/material.dart';

import '../services/api_client.dart';

enum AuthMode { login, register }

class AuthScreen extends StatefulWidget {
  const AuthScreen({
    super.key,
    required this.apiClient,
    required this.onAuthenticated,
  });

  final ApiClient apiClient;
  final void Function(AuthResult result) onAuthenticated;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  static final RegExp _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  static const int _maxEmailLength = 254;
  static const int _maxPasswordBytes = 72;
  static const int _minRegisterPasswordLength = 12;

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  AuthMode _mode = AuthMode.login;
  bool _isSubmitting = false;
  String? _errorMessage;

  bool get _isLogin => _mode == AuthMode.login;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _switchMode() {
    setState(() {
      _mode = _isLogin ? AuthMode.register : AuthMode.login;
      _errorMessage = null;
    });
    _formKey.currentState?.reset();
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

    final String email = _emailController.text.trim();
    final String password = _passwordController.text;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final AuthResult result = _isLogin
          ? await widget.apiClient.login(email: email, password: password)
          : await widget.apiClient.register(email: email, password: password);

      if (!mounted) {
        return;
      }
      setState(() => _isSubmitting = false);
      widget.onAuthenticated(result);
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

  String? _validateEmail(String? value) {
    final String email = (value ?? '').trim();
    if (email.isEmpty) {
      return 'Email is required.';
    }
    if (email.length > _maxEmailLength) {
      return 'Email must be 254 characters or fewer.';
    }
    if (!_emailPattern.hasMatch(email)) {
      return 'Enter a valid email address.';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    final String password = value ?? '';
    if (password.isEmpty) {
      return 'Password is required.';
    }
    if (!_isLogin && password.length < _minRegisterPasswordLength) {
      return 'Password must be at least $_minRegisterPasswordLength characters.';
    }
    if (utf8.encode(password).length > _maxPasswordBytes) {
      return 'Password must not exceed $_maxPasswordBytes bytes.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('WaterQueue'),
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.water_drop, size: 56, color: Colors.teal),
                  const SizedBox(height: 12),
                  Text(
                    _isLogin ? 'Welcome back' : 'Create account',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _isLogin
                        ? 'Sign in to check water-point availability.'
                        : 'Register a resident account to get started.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    key: const Key('auth-email'),
                    controller: _emailController,
                    enabled: !_isSubmitting,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autofillHints: const <String>[AutofillHints.email],
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                    ),
                    validator: _validateEmail,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    key: const Key('auth-password'),
                    controller: _passwordController,
                    enabled: !_isSubmitting,
                    obscureText: true,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _submit(),
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      border: OutlineInputBorder(),
                    ),
                    validator: _validatePassword,
                  ),
                  if (_errorMessage != null) ...<Widget>[
                    const SizedBox(height: 16),
                    Text(
                      _errorMessage!,
                      key: const Key('auth-error'),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    key: const Key('auth-submit'),
                    onPressed: _isSubmitting ? null : _submit,
                    child: _isSubmitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(_isLogin ? 'Log in' : 'Register'),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    key: const Key('auth-toggle'),
                    onPressed: _isSubmitting ? null : _switchMode,
                    child: Text(
                      _isLogin
                          ? 'Need an account? Register'
                          : 'Already have an account? Log in',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
