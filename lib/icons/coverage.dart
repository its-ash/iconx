import '../platform/launcher_channel.dart';
import 'icon_source.dart';

/// Which of the phone's apps iconX themes. Pure, tested in `test/coverage_test.dart`.
///
/// Launchers match `appfilter.xml` by exact component, so an app counts as themed only when its
/// `package/Activity` is listed. [packageOnly] lists apps whose package is known but whose
/// launcher activity changed (an app update renamed it): those need a new `app =` line.
class Coverage {
  Coverage._(this.themed, this.packageOnly, this.missing);

  factory Coverage.of(List<PixelIcon> icons, List<InstalledApp> apps) {
    final byComponent = <String, PixelIcon>{};
    final byPackage = <String, PixelIcon>{};
    for (final icon in icons) {
      for (final c in icon.components) {
        byComponent[c] = icon;
        byPackage[c.split('/').first] = icon;
      }
    }
    final themed = <(InstalledApp, PixelIcon)>[];
    final packageOnly = <(InstalledApp, PixelIcon)>[];
    final missing = <InstalledApp>[];
    for (final app in apps) {
      final exact = byComponent[app.component];
      final pkg = byPackage[app.package];
      if (exact != null) {
        themed.add((app, exact));
      } else if (pkg != null) {
        packageOnly.add((app, pkg));
      } else {
        missing.add(app);
      }
    }
    return Coverage._(themed, packageOnly, missing);
  }

  final List<(InstalledApp, PixelIcon)> themed;
  final List<(InstalledApp, PixelIcon)> packageOnly;
  final List<InstalledApp> missing;

  int get total => themed.length + packageOnly.length + missing.length;

  /// Text for an icon request: one `label: component` line per app.
  static String requestText(List<InstalledApp> apps) =>
      ['iconX icon request', '', for (final a in apps) '${a.label}: ${a.component}'].join('\n');
}
