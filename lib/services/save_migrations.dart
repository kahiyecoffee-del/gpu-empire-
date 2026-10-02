/// Version written by the current build.
const currentSaveVersion = 1;

typedef SaveMigration = Map<String, Object?> Function(Map<String, Object?>);

/// `migrations[n]` upgrades a save from version n to n + 1. When the save
/// format changes, bump [currentSaveVersion] and add a step here; never edit
/// an existing step.
final Map<int, SaveMigration> migrations = {};

/// Brings a decoded save up to [currentSaveVersion].
Map<String, Object?> migrateSave(Map<String, Object?> json) {
  var version = (json['version'] as num?)?.toInt() ?? 1;
  if (version > currentSaveVersion) {
    throw FormatException('Save version $version is newer than this build');
  }
  var data = json;
  while (version < currentSaveVersion) {
    final step = migrations[version];
    if (step == null) {
      throw StateError('No save migration from version $version');
    }
    data = step(data);
    version++;
    data['version'] = version;
  }
  return data;
}
