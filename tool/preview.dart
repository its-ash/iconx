// Validates icon files and draws them as an SVG contact sheet.
//
//   dart run tool/preview.dart [file.txt ...] [-o out.svg]
//
// With no files it previews every assets/icons/*.txt. Given files are parsed with the same rules as
// the app and the Gradle build, then cross-checked against all of assets/icons (duplicate names,
// components claimed twice). Exit code 1 on any problem. Convert the SVG to PNG to look at it:
//   rsvg-convert dist/preview.svg -o dist/preview.png
import 'dart:io';

import 'package:iconx/icons/icon_format.dart';

const _cell = 5; // px per pixel-art cell in the sheet
const _tile = 20 * _cell;
const _colW = _tile + 24;
const _rowH = _tile + 34;
const _perRow = 10;

void main(List<String> args) {
  var out = 'dist/preview.svg';
  final files = <String>[];
  for (var i = 0; i < args.length; i++) {
    if (args[i] == '-o' && i + 1 < args.length) {
      out = args[++i];
    } else {
      files.add(args[i]);
    }
  }
  final all = Directory(
    'assets/icons',
  ).listSync().whereType<File>().map((f) => f.path).where((p) => p.endsWith('.txt'));
  final shown = files.isEmpty ? (all.toList()..sort()) : files;
  final checked = {...all.map(_norm), ...files.map(_norm)}.toList()..sort();

  final defs = <String, List<IconDef>>{};
  var failed = false;
  for (final f in checked) {
    try {
      defs[f] = parseIconDefs(File(f).readAsStringSync(), file: f);
    } on IconSourceException catch (e) {
      stderr.writeln(e);
      failed = true;
    }
  }
  final problems = crossCheck([for (final list in defs.values) ...list]);
  for (final p in problems) {
    stderr.writeln('iconX: $p');
  }
  failed |= problems.isNotEmpty;

  final icons = [for (final f in shown) ...?defs[_norm(f)]];
  File(out)
    ..parent.createSync(recursive: true)
    ..writeAsStringSync(_svg(icons));
  stdout.writeln(
    '${icons.length} icons in ${shown.length} file(s) -> $out'
    '${failed ? '' : ' (all ${defs.values.fold(0, (n, l) => n + l.length)} icons valid)'}',
  );
  if (failed) exitCode = 1;
}

String _norm(String p) => p.startsWith('./') ? p.substring(2) : p;

bool _corner(int x, int y) {
  final dx = x < 19 - x ? x : 19 - x;
  final dy = y < 19 - y ? y : 19 - y;
  return dx + dy < 2;
}

String _hex(int argb) => '#${(argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

String _esc(String s) => s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');

String _svg(List<IconDef> icons) {
  final rows = (icons.length / _perRow).ceil().clamp(1, 1 << 20);
  final w = _perRow * _colW + 12;
  final h = rows * _rowH + 12;
  final b = StringBuffer()
    ..writeln('<svg xmlns="http://www.w3.org/2000/svg" width="$w" height="$h" shape-rendering="crispEdges">')
    ..writeln('<rect width="$w" height="$h" fill="#E5E7EB"/>');
  for (var i = 0; i < icons.length; i++) {
    final icon = icons[i];
    final ox = 12 + (i % _perRow) * _colW + 6;
    final oy = 12 + (i ~/ _perRow) * _rowH;
    final bg = StringBuffer();
    final fg = StringBuffer();
    for (var y = 0; y < 20; y++) {
      for (var x = 0; x < 20; x++) {
        if (_corner(x, y)) continue;
        final gx = x - 2;
        final gy = y - 2;
        final on = gx >= 0 && gy >= 0 && gx < 16 && gy < 16 && icon.on(gx, gy);
        (on ? fg : bg).write('M${ox + x * _cell} ${oy + y * _cell}h${_cell}v${_cell}h-${_cell}z');
      }
    }
    b
      ..writeln('<path fill="${_hex(icon.bg)}" d="$bg"/>')
      ..writeln('<path fill="${_hex(icon.fg)}" d="$fg"/>')
      ..writeln(
        '<text x="${ox + _tile / 2}" y="${oy + _tile + 16}" font-family="Arial" font-size="12" '
        'text-anchor="middle" fill="#111827">${_esc(icon.label.length > 16 ? '${icon.label.substring(0, 15)}…' : icon.label)}</text>',
      )
      ..writeln(
        '<text x="${ox + _tile / 2}" y="${oy + _tile + 28}" font-family="Arial" font-size="9" '
        'text-anchor="middle" fill="#6B7280">${_esc(icon.name)}</text>',
      );
  }
  b.writeln('</svg>');
  return b.toString();
}
