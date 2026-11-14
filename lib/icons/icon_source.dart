import 'package:flutter/services.dart';

/// One pixel icon from `assets/icons/*.txt` (format in `assets/icons/google.txt`).
///
/// The Android build (`android/app/build.gradle.kts`) reads the same files to make the PNGs and
/// `appfilter.xml`, so the gallery always shows exactly what launchers get.
class PixelIcon {
  const PixelIcon({
    required this.name,
    required this.label,
    required this.bg,
    required this.fg,
    required this.components,
    required this.rows,
    required this.group,
  });

  static const grid = 16;

  final String name;
  final String label;
  final Color bg;
  final Color fg;

  /// Full `package/Activity` names (a leading `.` in the source is expanded).
  final List<String> components;

  /// [grid] rows of [grid] characters, `#` = foreground.
  final List<String> rows;

  /// Source file name, title-cased (for example `Google`).
  final String group;

  bool on(int x, int y) => rows[y].codeUnitAt(x) == 0x23; // '#'

  Set<String> get packages => {for (final c in components) c.split('/').first};
}

class IconSourceException implements Exception {
  IconSourceException(this.file, this.line, this.message);

  final String file;
  final int line;
  final String message;

  @override
  String toString() => 'iconX: $file:$line: $message';
}

/// Parses one source file. Mirrors `IconPackTask.parse` in `build.gradle.kts`.
List<PixelIcon> parseIcons(String text, {required String file}) {
  final group = _groupOf(file);
  final out = <PixelIcon>[];
  final row = RegExp(r'^[.#]{16}$');
  final nameRe = RegExp(r'^[a-z][a-z0-9_]*$');
  final colorRe = RegExp(r'^#[0-9A-Fa-f]{6}$');

  String? name;
  var start = 0;
  final props = <String, String>{};
  final components = <String>[];
  final rows = <String>[];

  Never fail(int line, String msg) => throw IconSourceException(file, line, msg);

  void flush() {
    final n = name;
    if (n == null) return;
    Color color(String key) {
      final v = props[key] ?? fail(start, '[$n] has no $key');
      if (!colorRe.hasMatch(v)) fail(start, '[$n] $key must be #RRGGBB, got $v');
      return Color(0xFF000000 | int.parse(v.substring(1), radix: 16));
    }

    if (rows.length != PixelIcon.grid) fail(start, '[$n] has ${rows.length} grid rows, needs ${PixelIcon.grid}');
    if (components.isEmpty) fail(start, '[$n] has no app = lines');
    out.add(
      PixelIcon(
        name: n,
        label: props['label'] ?? n,
        bg: color('bg'),
        fg: color('fg'),
        components: List.unmodifiable(components),
        rows: List.unmodifiable(rows),
        group: group,
      ),
    );
    props.clear();
    components.clear();
    rows.clear();
  }

  final lines = text.split('\n');
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i].trim();
    final no = i + 1;
    if (line.isEmpty) continue;
    if (row.hasMatch(line)) {
      if (name == null) fail(no, 'grid row outside an icon');
      rows.add(line);
    } else if (line.startsWith('#')) {
      continue; // comment; grid rows are matched first
    } else if (line.startsWith('[') && line.endsWith(']')) {
      flush();
      final n = line.substring(1, line.length - 1);
      if (!nameRe.hasMatch(n)) fail(no, "icon name '$n' must match ${nameRe.pattern}");
      name = n;
      start = no;
    } else if (line.contains('=')) {
      if (name == null) fail(no, 'property outside an icon');
      final key = line.substring(0, line.indexOf('=')).trim();
      final value = line.substring(line.indexOf('=') + 1).trim();
      switch (key) {
        case 'app':
          components.add(expandComponent(value) ?? fail(no, "app must be package/Activity, got '$value'"));
        case 'label' || 'bg' || 'fg':
          props[key] = value;
        default:
          fail(no, "unknown key '$key'");
      }
    } else {
      fail(no, "cannot read '$line' (a grid row is 16 of . and #)");
    }
  }
  flush();
  return out;
}

/// `pkg/.Act` -> `pkg/pkg.Act`; null when malformed.
String? expandComponent(String value) {
  final slash = value.indexOf('/');
  if (slash <= 0 || slash == value.length - 1) return null;
  final pkg = value.substring(0, slash);
  final cls = value.substring(slash + 1);
  return '$pkg/${cls.startsWith('.') ? '$pkg$cls' : cls}';
}

/// Group title from the file name: `google.txt` -> `Google`. Keep in sync with `IconPackTask.parse`
/// in `build.gradle.kts`.
String _groupOf(String file) {
  final base = file.split('/').last.replaceAll('.txt', '');
  if (base == 'itsash') return 'Ash Store';
  return base.isEmpty ? base : base[0].toUpperCase() + base.substring(1);
}

/// Display order of the source files; others follow alphabetically.
const groupOrder = ['google.txt', 'system.txt', 'popular.txt', 'itsash.txt'];

/// Every icon in the app's assets, grouped in [groupOrder].
Future<List<PixelIcon>> loadIcons([AssetBundle? bundle]) async {
  final b = bundle ?? rootBundle;
  final manifest = await AssetManifest.loadFromAssetBundle(b);
  final files = manifest.listAssets().where((a) => a.startsWith('assets/icons/') && a.endsWith('.txt')).toList()
    ..sort((x, y) {
      int rank(String f) {
        final i = groupOrder.indexOf(f.split('/').last);
        return i < 0 ? groupOrder.length : i;
      }

      final r = rank(x).compareTo(rank(y));
      return r != 0 ? r : x.compareTo(y);
    });
  return [for (final f in files) ...parseIcons(await b.loadString(f), file: f)];
}
