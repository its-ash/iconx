import 'package:flutter/services.dart';

import 'icon_format.dart';

export 'icon_format.dart' show IconSourceException, expandComponent;

/// One pixel icon from `assets/icons/*.txt`, with Flutter colors. The format and parser live in
/// `icon_format.dart` (pure Dart, shared with `tool/preview.dart`).
///
/// The Android build (`android/app/build.gradle.kts`) reads the same files to make the PNGs and
/// `appfilter.xml`, so the gallery always shows exactly what launchers get.
class PixelIcon {
  PixelIcon(this.def) : bg = Color(def.bg), fg = Color(def.fg);

  static const grid = iconGrid;

  final IconDef def;
  final Color bg;
  final Color fg;

  String get name => def.name;
  String get label => def.label;
  String get group => def.group;

  /// Full `package/Activity` names.
  List<String> get components => def.components;
  List<String> get rows => def.rows;

  bool on(int x, int y) => def.on(x, y);

  Set<String> get packages => {for (final c in components) c.split('/').first};
}

/// Parses one source file (see `icon_format.dart`).
List<PixelIcon> parseIcons(String text, {required String file}) => [
  for (final d in parseIconDefs(text, file: file)) PixelIcon(d),
];

/// Every icon in the app's assets. Files load in name order (`10-google.txt`, `20-system.txt`, ...),
/// which is the gallery's group order.
Future<List<PixelIcon>> loadIcons([AssetBundle? bundle]) async {
  final b = bundle ?? rootBundle;
  final manifest = await AssetManifest.loadFromAssetBundle(b);
  final files = manifest.listAssets().where((a) => a.startsWith('assets/icons/') && a.endsWith('.txt')).toList()
    ..sort();
  return [for (final f in files) ...parseIcons(await b.loadString(f), file: f)];
}
