/// The `assets/icons/*.txt` format, in pure Dart (no Flutter imports) so `tool/preview.dart` can use it.
///
/// Format (also at the top of `assets/icons/10-google.txt`):
///   group = Title          once, before the first icon: the group shown in the gallery
///   [drawable_name]        a-z, 0-9, _ ; becomes `res/drawable-nodpi/<name>.png`
///   label = Shown name
///   bg = #RRGGBB           tile color
///   fg = #RRGGBB           motif color
///   app = package/Activity one per launcher component; ".Activity" is relative to the package
///   16 rows of 16 characters: '#' = fg, '.' = bg
/// A line matching [.#]{16} is a grid row; other lines starting with '#' are comments.
/// `IconPackTask` in `android/app/build.gradle.kts` implements the same rules; keep them in sync.
library;

const iconGrid = 16;

class IconDef {
  const IconDef({
    required this.name,
    required this.label,
    required this.bg,
    required this.fg,
    required this.components,
    required this.rows,
    required this.group,
    required this.file,
    required this.line,
  });

  final String name;
  final String label;

  /// 0xAARRGGBB.
  final int bg;
  final int fg;

  /// Full `package/Activity` names.
  final List<String> components;
  final List<String> rows;
  final String group;
  final String file;
  final int line;

  bool on(int x, int y) => rows[y].codeUnitAt(x) == 0x23; // '#'
}

class IconSourceException implements Exception {
  IconSourceException(this.file, this.line, this.message);

  final String file;
  final int line;
  final String message;

  @override
  String toString() => 'iconX: $file:$line: $message';
}

final _row = RegExp(r'^[.#]{16}$');
final _name = RegExp(r'^[a-z][a-z0-9_]*$');
final _color = RegExp(r'^#[0-9A-Fa-f]{6}$');

/// Parses one source file. Throws [IconSourceException] with the file and line on bad input.
List<IconDef> parseIconDefs(String text, {required String file}) {
  final out = <IconDef>[];
  String? group;
  String? name;
  var start = 0;
  final props = <String, String>{};
  final components = <String>[];
  final rows = <String>[];

  Never fail(int line, String msg) => throw IconSourceException(file, line, msg);

  void flush() {
    final n = name;
    if (n == null) return;
    int color(String key) {
      final v = props[key] ?? fail(start, '[$n] has no $key');
      if (!_color.hasMatch(v)) fail(start, '[$n] $key must be #RRGGBB, got $v');
      return 0xFF000000 | int.parse(v.substring(1), radix: 16);
    }

    if (rows.length != iconGrid) fail(start, '[$n] has ${rows.length} grid rows, needs $iconGrid');
    if (components.isEmpty) fail(start, '[$n] has no app = lines');
    final bg = color('bg');
    final fg = color('fg');
    if (bg == fg) fail(start, '[$n] bg and fg are the same color');
    out.add(
      IconDef(
        name: n,
        label: props['label'] ?? n,
        bg: bg,
        fg: fg,
        components: List.unmodifiable(components),
        rows: List.unmodifiable(rows),
        group: group ?? fail(start, 'the file needs "group = Title" before the first icon'),
        file: file,
        line: start,
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
    if (_row.hasMatch(line)) {
      if (name == null) fail(no, 'grid row outside an icon');
      if (rows.length == iconGrid) fail(no, '[$name] has more than $iconGrid grid rows');
      rows.add(line);
    } else if (line.startsWith('#')) {
      continue; // comment; grid rows are matched first
    } else if (line.startsWith('[') && line.endsWith(']')) {
      flush();
      final n = line.substring(1, line.length - 1);
      if (!_name.hasMatch(n)) fail(no, "icon name '$n' must match ${_name.pattern}");
      name = n;
      start = no;
    } else if (line.contains('=')) {
      final key = line.substring(0, line.indexOf('=')).trim();
      final value = line.substring(line.indexOf('=') + 1).trim();
      if (name == null) {
        if (key != 'group') fail(no, "only 'group =' may come before the first icon");
        group = value;
        continue;
      }
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
  if (slash <= 0 || slash == value.length - 1 || value.contains(' ')) return null;
  final pkg = value.substring(0, slash);
  final cls = value.substring(slash + 1);
  return '$pkg/${cls.startsWith('.') ? '$pkg$cls' : cls}';
}

/// Problems across files: duplicate icon names and components claimed by two icons.
List<String> crossCheck(List<IconDef> icons) {
  final problems = <String>[];
  final names = <String, IconDef>{};
  final comps = <String, IconDef>{};
  for (final i in icons) {
    final seen = names[i.name];
    if (seen != null) problems.add('duplicate name [${i.name}] in ${i.file}:${i.line} and ${seen.file}:${seen.line}');
    names[i.name] = i;
    for (final c in i.components) {
      final other = comps[c];
      if (other != null && other.name != i.name) problems.add('$c is in [${i.name}] and [${other.name}]');
      comps[c] = i;
    }
  }
  return problems;
}
