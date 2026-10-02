import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'game/session.dart';
import 'l10n/app_localizations.dart';
import 'services/settings_service.dart';
import 'ui/game_loop.dart';
import 'ui/game_screen.dart';
import 'ui/languages.dart';
import 'ui/music_director.dart';
import 'ui/sfx_director.dart';
import 'ui/widgets/celebration_layer.dart';
import 'ui/theme.dart';

class GpuEmpireApp extends ConsumerWidget {
  const GpuEmpireApp({super.key, this.navigatorKey});

  /// Lets services show full-screen test ads and store dialogs.
  final GlobalKey<NavigatorState>? navigatorKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final language = ref.watch(settingsProvider.select((s) => s.language));
    return MaterialApp(
      navigatorKey: navigatorKey,
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      // The player's choice, else the device language (English fallback).
      locale: language == null ? null : localeFromTag(language),
      localeListResolutionCallback: resolveLocale,
      // Above the navigator, so taps on dialogs also unlock audio.
      builder: (context, child) => MusicDirector(
        child: SfxDirector(child: CelebrationLayer(child: child!)),
      ),
      home: const GameSession(child: GameLoop(child: GameScreen())),
    );
  }
}
