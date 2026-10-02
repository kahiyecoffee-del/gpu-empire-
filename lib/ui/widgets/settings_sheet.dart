import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../game/monetization.dart';
import '../../services/settings_service.dart';
import '../languages.dart';
import '../theme.dart';
import 'icon_text.dart';
import 'max_avatar.dart';

Future<void> showSettingsSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => const _SettingsSheet(),
    );

class _SettingsSheet extends ConsumerWidget {
  const _SettingsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final settings = ref.watch(settingsProvider);
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: IconText(
              Icons.settings,
              l10n.settings,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.music_note, color: AppColors.accent),
            title: Text(l10n.settingsMusic),
            subtitle: Text(
              l10n.settingsMusicHint,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            value: settings.musicOn,
            onChanged: (on) =>
                ref.read(settingsProvider.notifier).setMusic(on: on),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.volume_up, color: AppColors.accent),
            title: Text(l10n.settingsSfx),
            subtitle: Text(
              l10n.settingsSfxHint,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            value: settings.sfxOn,
            onChanged: (on) =>
                ref.read(settingsProvider.notifier).setSfx(on: on),
          ),
          if (ref.watch(privacyOptionsRequiredProvider).value ?? false)
            ListTile(
              leading: const Icon(Icons.privacy_tip, color: AppColors.accent),
              title: Text(l10n.privacyOptions),
              subtitle: Text(
                l10n.privacyOptionsHint,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              onTap: () => ref.read(adServiceProvider).showPrivacyOptions(),
            ),
          ListTile(
            key: const ValueKey('settings_language'),
            leading: const Icon(Icons.language, color: AppColors.accent),
            title: Text(l10n.settingsLanguage),
            subtitle: Text(
              settings.language == null
                  ? l10n.languageAutomatic
                  : languageName(settings.language!),
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => showLanguagePicker(context),
          ),
          ListTile(
            leading: const Icon(Icons.restore, color: AppColors.accent),
            title: Text(l10n.restorePurchases),
            onTap: () => ref.read(storeProvider).restore(),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

/// Max's first-launch greeting.
Future<void> showIntroDialog(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      backgroundColor: AppColors.surface,
      icon: const MaxAvatar(size: 96, excited: true),
      title: Text(l10n.introTitle),
      content: Text(l10n.introBody, textAlign: TextAlign.center),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: AppColors.background,
          ),
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.introButton),
        ),
      ],
    ),
  );
}

Future<void> showLanguagePicker(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => const _LanguagePicker(),
    );

class _LanguagePicker extends ConsumerWidget {
  const _LanguagePicker();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final current = ref.watch(settingsProvider.select((s) => s.language));
    final settings = ref.read(settingsProvider.notifier);
    Widget tile(String? tag, String name) => ListTile(
      key: ValueKey('language_${tag ?? 'auto'}'),
      title: Text(name),
      trailing: current == tag
          ? const Icon(Icons.check_circle, color: AppColors.accent)
          : null,
      onTap: () {
        settings.setLanguage(tag);
        Navigator.pop(context);
      },
    );
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.75,
        child: Column(
          children: [
            ListTile(
              title: IconText(
                Icons.language,
                l10n.settingsLanguage,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Expanded(
              child: ListView(
                children: [
                  tile(null, l10n.languageAutomatic),
                  for (final (tag, name) in languages) tile(tag, name),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
