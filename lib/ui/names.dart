import '../core/economy_config.dart';
import '../core/monetization.dart';
import '../core/number_format.dart';
import '../l10n/app_localizations.dart';

/// Maps config ids to translated names. New ids must be added here and to
/// the .arb files.
String lineName(AppLocalizations l10n, String id) => switch (id) {
  'legacy_gpu' => l10n.lineLegacyGpu,
  'gaming_cluster' => l10n.lineGamingCluster,
  'datacenter_gpu' => l10n.lineDatacenterGpu,
  'tpu_pod' => l10n.lineTpuPod,
  'supercomputer' => l10n.lineSupercomputer,
  'quantum' => l10n.lineQuantum,
  'wh_rack_row' => l10n.lineWhRackRow,
  'wh_inference_farm' => l10n.lineWhInferenceFarm,
  'wh_training_cluster' => l10n.lineWhTrainingCluster,
  'wh_tpu_superpod' => l10n.lineWhTpuSuperpod,
  'wh_exascale' => l10n.lineWhExascale,
  'wh_quantum_array' => l10n.lineWhQuantumArray,
  'cp_chip_fab' => l10n.lineCpChipFab,
  'cp_model_foundry' => l10n.lineCpModelFoundry,
  'cp_hyperscale_hall' => l10n.lineCpHyperscaleHall,
  'cp_optical_compute' => l10n.lineCpOpticalCompute,
  'cp_neuromorphic' => l10n.lineCpNeuromorphic,
  'cp_quantum_lab' => l10n.lineCpQuantumLab,
  _ => id,
};

/// Manager names come from their role, shared across locations.
String managerName(AppLocalizations l10n, String role) => switch (role) {
  'intern' => l10n.managerIntern,
  'sysadmin' => l10n.managerSysadmin,
  'network_engineer' => l10n.managerNetworkEngineer,
  'ml_engineer' => l10n.managerMlEngineer,
  'chief_engineer' => l10n.managerChiefEngineer,
  'quantum_physicist' => l10n.managerQuantumPhysicist,
  _ => role,
};

String managerBonus(AppLocalizations l10n, ManagerConfig m) =>
    switch (m.bonus) {
      ManagerBonusType.none => '',
      ManagerBonusType.lineIncome => l10n.bonusLineIncome(
        formatMultiplier(m.bonusValue),
      ),
      ManagerBonusType.allIncome => l10n.bonusAllIncome(
        formatMultiplier(m.bonusValue),
      ),
      ManagerBonusType.infraDiscount => l10n.bonusInfraDiscount(
        '${(m.bonusValue * 100).round()}',
      ),
    };

String locationName(AppLocalizations l10n, String id) => switch (id) {
  'garage' => l10n.locationGarage,
  'warehouse' => l10n.locationWarehouse,
  'campus' => l10n.locationCampus,
  _ => id,
};

String skillName(AppLocalizations l10n, String id) => switch (id) {
  'seed_round' => l10n.skillSeedRound,
  'series_a' => l10n.skillSeriesA,
  'unicorn' => l10n.skillUnicorn,
  'bulk_power' => l10n.skillBulkPower,
  'liquid_cooling' => l10n.skillLiquidCooling,
  'fusion_contract' => l10n.skillFusionContract,
  'head_start' => l10n.skillHeadStart,
  'night_shift' => l10n.skillNightShift,
  'auto_hire' => l10n.skillAutoHire,
  'dreamer' => l10n.skillDreamer,
  _ => id,
};

String skillEffect(AppLocalizations l10n, SkillConfig s) => switch (s.effect) {
  SkillEffect.incomeMultiplier => l10n.effectIncome(formatMultiplier(s.value)),
  SkillEffect.infraDiscount => l10n.effectInfraDiscount(
    '${(s.value * 100).round()}',
  ),
  SkillEffect.infraCapacity => l10n.effectInfraCapacity(
    formatMultiplier(s.value),
  ),
  SkillEffect.startCash => l10n.effectStartCash('\$${formatDouble(s.value)}'),
  SkillEffect.offlineHours => l10n.effectOfflineHours(
    formatMultiplier(s.value),
  ),
  SkillEffect.startManagers => l10n.effectStartManagers('${s.value.toInt()}'),
};

String branchName(AppLocalizations l10n, String branch) => switch (branch) {
  'income' => l10n.branchIncome,
  'infra' => l10n.branchInfra,
  'automation' => l10n.branchAutomation,
  _ => branch,
};

String eventTitle(AppLocalizations l10n, String id) => switch (id) {
  'viral_product' => l10n.eventViral,
  'investor_visit' => l10n.eventInvestor,
  'chip_deal' => l10n.eventChipDeal,
  'hackathon' => l10n.eventHackathon,
  _ => id,
};

/// Formats a multiplier without a trailing `.0`: 2.0 -> `2`, 1.5 -> `1.5`.
String formatMultiplier(double value) =>
    value == value.roundToDouble() ? value.toInt().toString() : '$value';

String productName(AppLocalizations l10n, ProductConfig p) {
  if (p.removesAds) return l10n.productRemoveAds;
  if (p.incomeMultiplier > 1) return l10n.productStarter;
  return l10n.productTokens('${p.tokens}');
}

String productBody(AppLocalizations l10n, ProductConfig p) {
  if (p.removesAds) return l10n.productRemoveAdsBody;
  if (p.incomeMultiplier > 1) return l10n.productStarterBody;
  return l10n.productTokensBody;
}

/// Short label for a wheel segment.
String prizeLabel(AppLocalizations l10n, WheelPrize p) => switch (p.kind) {
  WheelPrizeKind.cash => l10n.prizeCashShort('${(p.value / 60).round()}'),
  WheelPrizeKind.boost => l10n.prizeBoost(
    formatMultiplier(p.value),
    '${p.seconds.round()}',
  ),
  WheelPrizeKind.overclock => l10n.prizeOverclock('${(p.value / 60).round()}'),
  WheelPrizeKind.tokens => l10n.prizeTokens('${p.value.round()}'),
};
