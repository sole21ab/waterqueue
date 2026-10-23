import 'package:flutter/material.dart';

import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';
import 'services/api_client.dart';
import 'state/session.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const WaterQueueApp());
}

class WaterQueueApp extends StatefulWidget {
  const WaterQueueApp({super.key, this.apiClient});

  final ApiClient? apiClient;

  @override
  State<WaterQueueApp> createState() => _WaterQueueAppState();
}

class _WaterQueueAppState extends State<WaterQueueApp> {
  final Session _session = Session();
  late final ApiClient _apiClient = widget.apiClient ?? ApiClient();

  @override
  void dispose() {
    _session.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WaterQueue',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: ListenableBuilder(
        listenable: _session,
        builder: (BuildContext context, Widget? child) {
          final user = _session.user;
          final token = _session.token;
          if (user != null && token != null) {
            return HomeScreen(
              user: user,
              token: token,
              apiClient: _apiClient,
              onSignOut: _session.signOut,
            );
          }
          return AuthScreen(
            apiClient: _apiClient,
            onAuthenticated: _session.signIn,
          );
        },
      ),
    );
  }
}
