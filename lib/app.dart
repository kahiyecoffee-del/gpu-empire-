import 'package:flutter/material.dart';

import 'game/session.dart';
import 'l10n/app_localizations.dart';
import 'ui/game_loop.dart';
import 'ui/game_screen.dart';
import 'ui/theme.dart';

class GpuEmpireApp extends StatelessWidget {
  const GpuEmpireApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const GameSession(child: GameLoop(child: GameScreen())),
    );
  }
}
