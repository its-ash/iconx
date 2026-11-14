import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:iconx/icons/icon_format.dart' show crossCheck, parseIconDefs;
import 'package:iconx/icons/icon_source.dart';
import 'package:iconx/icons/pixel_icon_view.dart';

const _sample = '''
# comment
group = Google
[demo]
label = Demo
bg = #112233
fg = #FFFFFF
app = com.demo/.Main
app = com.demo.beta/com.demo.Main
################
#..............#
#..............#
#..............#
#..............#
#..............#
#..............#
#..............#
#..............#
#..............#
#..............#
#..............#
#..............#
#..............#
#..............#
################
''';

String _icon(String name, {List<String>? rows, String extra = ''}) =>
    'group = Test\n[$name]\nbg = #000000\nfg = #FFFFFF\napp = a.b/.C\n$extra${(rows ?? List.filled(16, '.' * 16)).join('\n')}\n';

void main() {
  test('parses an icon, expands relative activities, keeps rows starting with #', () {
    final icons = parseIcons(_sample, file: 'assets/icons/google.txt');
    expect(icons, hasLength(1));
    final i = icons.single;
    expect(i.name, 'demo');
    expect(i.label, 'Demo');
    expect(i.group, 'Google');
    expect(i.bg.toARGB32(), 0xFF112233);
    expect(i.components, ['com.demo/com.demo.Main', 'com.demo.beta/com.demo.Main']);
    expect(i.packages, {'com.demo', 'com.demo.beta'});
    expect(i.on(0, 0), isTrue);
    expect(i.on(5, 5), isFalse);
  });

  test('group comes from the group line, and is required', () {
    expect(parseIcons(_icon('a'), file: 'x.txt').single.group, 'Test');
    expect(
      () => parseIcons(_icon('a').replaceFirst('group = Test\n', ''), file: 'x.txt'),
      throwsA(isA<IconSourceException>().having((e) => e.message, 'message', contains('group'))),
    );
  });

  test('cross-check finds duplicate names and shared components', () {
    final a = parseIconDefs(_icon('a'), file: 'a.txt');
    final b = parseIconDefs(_icon('a'), file: 'b.txt');
    expect(crossCheck([...a, ...b]), hasLength(1)); // same name; same component in a same-named icon is one problem
    final c = parseIconDefs(_icon('c'), file: 'c.txt');
    expect(crossCheck([...a, ...c]).single, contains('a.b/a.b.C'));
  });

  test('errors name the file and line', () {
    expect(
      () => parseIcons(_icon('a', rows: List.filled(15, '.' * 16)), file: 'x.txt'),
      throwsA(
        isA<IconSourceException>().having((e) => e.toString(), 'text', contains('x.txt:2: [a] has 15 grid rows')),
      ),
    );
    expect(() => parseIcons('[Bad]\n', file: 'x.txt'), throwsA(isA<IconSourceException>()));
    expect(() => parseIcons(_icon('a', extra: 'size = 3\n'), file: 'x.txt'), throwsA(isA<IconSourceException>()));
    expect(() => parseIcons(_icon('a', extra: 'app = nonsense\n'), file: 'x.txt'), throwsA(isA<IconSourceException>()));
    expect(
      () => parseIcons('group = T\n[a]\nbg = red\nfg = #FFFFFF\napp = a/.B\n${'${'.' * 16}\n' * 16}', file: 'x.txt'),
      throwsA(isA<IconSourceException>()),
    );
  });

  test('component expansion', () {
    expect(expandComponent('p.q/.Main'), 'p.q/p.q.Main');
    expect(expandComponent('p.q/x.y.Main'), 'p.q/x.y.Main');
    expect(expandComponent('p.q/'), isNull);
    expect(expandComponent('/Main'), isNull);
  });

  test('tile corners: three cells cut per corner', () {
    var cut = 0;
    for (var y = 0; y < tileCells; y++) {
      for (var x = 0; x < tileCells; x++) {
        if (isCornerCell(x, y)) cut++;
      }
    }
    expect(cut, 12);
    expect(isCornerCell(0, 0) && isCornerCell(1, 0) && isCornerCell(0, 1), isTrue);
    expect(isCornerCell(1, 1), isFalse);
    expect(isCornerCell(19, 18), isTrue);
  });

  group('the real icon files', () {
    final files = Directory('assets/icons').listSync().whereType<File>().where((f) => f.path.endsWith('.txt')).toList();
    final icons = [for (final f in files) ...parseIcons(f.readAsStringSync(), file: f.path)];

    test('all parse and there are plenty', () {
      expect(files, isNotEmpty);
      expect(icons.length, greaterThan(60));
    });

    test('the landing page lists every icon file', () {
      final html = File('index.html').readAsStringSync();
      for (final f in files) {
        final name = f.uri.pathSegments.last;
        expect(html, contains('"$name"'), reason: 'add $name to FILES in index.html');
      }
    });

    test('names are unique and no component is claimed twice', () {
      expect(crossCheck([for (final i in icons) i.def]), isEmpty);
    });

    test('every motif uses both colors and leaves the tile visible', () {
      for (final i in icons) {
        final on = i.rows.join().split('').where((c) => c == '#').length;
        expect(on, inInclusiveRange(10, 200), reason: '${i.name} has $on foreground cells');
        expect(i.bg, isNot(i.fg), reason: '${i.name} uses one color');
      }
    });
  });
}
