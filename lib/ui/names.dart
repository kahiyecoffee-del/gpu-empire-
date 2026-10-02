import '../l10n/app_localizations.dart';

/// Maps config ids to translated names. New ids must be added here and to
/// both .arb files.
String lineName(AppLocalizations l10n, String id) => switch (id) {
  'legacy_gpu' => l10n.lineLegacyGpu,
  'gaming_cluster' => l10n.lineGamingCluster,
  'datacenter_gpu' => l10n.lineDatacenterGpu,
  'tpu_pod' => l10n.lineTpuPod,
  'supercomputer' => l10n.lineSupercomputer,
  'quantum' => l10n.lineQuantum,
  _ => id,
};

String managerName(AppLocalizations l10n, String id) => switch (id) {
  'intern' => l10n.managerIntern,
  'sysadmin' => l10n.managerSysadmin,
  _ => id,
};

/// Formats a multiplier without a trailing `.0`: 2.0 -> `2`, 1.5 -> `1.5`.
String formatMultiplier(double value) =>
    value == value.roundToDouble() ? value.toInt().toString() : '$value';
