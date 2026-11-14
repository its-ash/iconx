import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:iconx/icons/icon_source.dart';
import 'package:iconx/icons/pixel_icon_view.dart';

const _sample = '''
# comment
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
    '[$name]\nbg = #000000\nfg = #FFFFFF\napp = a.b/.C\n$extra${(rows ?? List.filled(16, '.' * 16)).join('\n')}\n';

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

  test('itsash file is titled Ash Store', () {
    expect(parseIcons(_icon('a'), file: 'itsash.txt').single.group, 'Ash Store');
  });

  test('errors name the file and line', () {
    expect(
      () => parseIcons(_icon('a', rows: List.filled(15, '.' * 16)), file: 'x.txt'),
      throwsA(
        isA<IconSourceException>().having((e) => e.toString(), 'text', contains('x.txt:1: [a] has 15 grid rows')),
      ),
    );
    expect(() => parseIcons('[Bad]\n', file: 'x.txt'), throwsA(isA<IconSourceException>()));
    expect(() => parseIcons(_icon('a', extra: 'size = 3\n'), file: 'x.txt'), throwsA(isA<IconSourceException>()));
    expect(() => parseIcons(_icon('a', extra: 'app = nonsense\n'), file: 'x.txt'), throwsA(isA<IconSourceException>()));
    expect(
      () => parseIcons('[a]\nbg = red\nfg = #FFFFFF\napp = a/.B\n${'${'.' * 16}\n' * 16}', file: 'x.txt'),
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

    test('names are unique and no component is claimed twice', () {
      final names = icons.map((i) => i.name).toList();
      expect(names.toSet(), hasLength(names.length));
      final components = [for (final i in icons) ...i.components];
      final dupes = components.where((c) => components.where((d) => d == c).length > 1).toSet();
      expect(dupes, isEmpty, reason: 'components mapped twice: $dupes');
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
