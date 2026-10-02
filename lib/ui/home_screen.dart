import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import 'theme.dart';
import 'widgets/server_rack.dart';

/// Build identifier injected by CI (`--dart-define=BUILD_ID=<sha>`), so a
/// tester can confirm they are looking at the latest deploy.
const _buildId = String.fromEnvironment('BUILD_ID', defaultValue: 'dev');

/// Placeholder home screen for Phase 0. Replaced by the game screen in Phase 1.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const Spacer(),
              const SizedBox(width: 120, height: 200, child: ServerRack()),
              const SizedBox(height: 32),
              Text(
                l10n.appTitle,
                style: textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                l10n.homeTagline,
                style: textTheme.bodyLarge?.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              Text(
                l10n.buildInfo(_buildId),
                style: textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
