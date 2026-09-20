import 'package:flutter/material.dart';

/// Reusable presentation screen for unauthorized access attempts.
///
/// Displayed when a user navigates to an unassigned module or an area
/// requiring privileges they do not possess. Does NOT expose technical
/// permission identifiers or internal policy details.
class AccessRestrictedScreen extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback? onBack;

  const AccessRestrictedScreen({
    super.key,
    this.title = 'Access Restricted',
    this.message = 'You do not have permission to access this area.',
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      key: const Key('access_restricted_screen'),
      appBar: AppBar(title: const Text('Access Denied'), elevation: 0),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Card(
              elevation: 0,
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: colorScheme.outlineVariant),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24.0,
                  vertical: 32.0,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: colorScheme.errorContainer.withValues(
                          alpha: 0.6,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.gpp_bad_outlined,
                        size: 48,
                        color: colorScheme.error,
                        key: const Key('access_restricted_icon'),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      title,
                      key: const Key('access_restricted_title'),
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      message,
                      key: const Key('access_restricted_message'),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 28),
                    ElevatedButton.icon(
                      key: const Key('access_restricted_back_button'),
                      onPressed: onBack ?? () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Back to Dashboard'),
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
