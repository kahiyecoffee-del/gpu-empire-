import 'package:flutter/material.dart';

import 'game/session.dart';
import 'l10n/app_localizations.dart';
import 'ui/game_loop.dart';
import 'ui/game_screen.dart';
import 'ui/music_director.dart';
import 'ui/theme.dart';

class GpuEmpireApp extends StatelessWidget {
  const GpuEmpireApp({super.key, this.navigatorKey});

  /// Lets services show full-screen test ads and store dialogs.
  final GlobalKey<NavigatorState>? navigatorKey;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      // The game ships in English only for now (see GAME_BRIEF decision log).
      locale: const Locale('en'),
      // Above the navigator, so taps on dialogs also unlock audio.
      builder: (context, child) => MusicDirector(child: child!),
      home: const GameSession(child: GameLoop(child: GameScreen())),
    );
  }
}
