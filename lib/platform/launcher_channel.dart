import 'package:flutter/services.dart';

/// An app with a launcher icon on this phone.
class InstalledApp {
  const InstalledApp({required this.label, required this.component});

  factory InstalledApp.fromMap(Map<Object?, Object?> m) =>
      InstalledApp(label: m['label'] as String? ?? '', component: m['component'] as String? ?? '');

  final String label;

  /// `package/full.Class`.
  final String component;

  String get package => component.split('/').first;
}

/// A launcher iconX can be applied to.
class LauncherInfo {
  const LauncherInfo({required this.id, required this.name, required this.installed, required this.isDefault});

  factory LauncherInfo.fromMap(Map<Object?, Object?> m) => LauncherInfo(
    id: m['id'] as String? ?? '',
    name: m['name'] as String? ?? '',
    installed: m['installed'] as bool? ?? false,
    isDefault: m['isDefault'] as bool? ?? false,
  );

  final String id;
  final String name;
  final bool installed;
  final bool isDefault;
}

enum ApplyResult { applied, opened, failed }

/// The native side, so screens can be tested with a fake.
abstract interface class LauncherPlatform {
  Future<List<InstalledApp>> apps();
  Future<List<LauncherInfo>> launchers();
  Future<ApplyResult> apply(String launcherId);
  Future<void> share(String text);
}

/// Talks to `MainActivity.kt` over `com.itsash.iconx/launcher`.
class MethodChannelLauncherPlatform implements LauncherPlatform {
  const MethodChannelLauncherPlatform([this._channel = const MethodChannel('com.itsash.iconx/launcher')]);

  final MethodChannel _channel;

  @override
  Future<List<InstalledApp>> apps() async {
    final rows = await _channel.invokeListMethod<Map<Object?, Object?>>('apps');
    return [for (final r in rows ?? const <Map<Object?, Object?>>[]) InstalledApp.fromMap(r)];
  }

  @override
  Future<List<LauncherInfo>> launchers() async {
    final rows = await _channel.invokeListMethod<Map<Object?, Object?>>('launchers');
    return [for (final r in rows ?? const <Map<Object?, Object?>>[]) LauncherInfo.fromMap(r)];
  }

  @override
  Future<ApplyResult> apply(String launcherId) async {
    final r = await _channel.invokeMethod<String>('apply', {'id': launcherId});
    return ApplyResult.values.asNameMap()[r] ?? ApplyResult.failed;
  }

  @override
  Future<void> share(String text) => _channel.invokeMethod('share', {'text': text});
}
