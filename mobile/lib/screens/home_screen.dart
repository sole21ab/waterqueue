import 'package:flutter/material.dart';

import '../models/auth_user.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.user,
    required this.onSignOut,
  });

  final AuthUser user;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('WaterQueue'),
        centerTitle: true,
        actions: <Widget>[
          IconButton(
            key: const Key('sign-out'),
            onPressed: onSignOut,
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Icon(Icons.water_drop, size: 64, color: Colors.teal),
                const SizedBox(height: 12),
                Text(
                  'Signed in',
                  style: theme.textTheme.headlineSmall,
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Text(
                          'Email',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          user.email,
                          key: const Key('home-email'),
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Role',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Role: ${user.role}',
                          key: const Key('home-role'),
                          style: theme.textTheme.titleMedium,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'No water points yet',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Add water points to see availability and queue times.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 24),
                OutlinedButton(
                  key: const Key('home-sign-out'),
                  onPressed: onSignOut,
                  child: const Text('Sign out'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
