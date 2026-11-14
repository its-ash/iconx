import 'package:flutter/material.dart';

import 'icon_source.dart';

/// Paints a [PixelIcon] exactly like the launcher PNG: a 20x20-cell tile with pixel-rounded
/// corners and the 16x16 motif in the middle (see `IconPackTask.render` in `build.gradle.kts`).
class PixelIconView extends StatelessWidget {
  const PixelIconView(this.icon, {super.key, this.size = 56});

  final PixelIcon icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${icon.label} icon',
      image: true,
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(painter: _TilePainter(icon)),
      ),
    );
  }
}

/// Tile size in cells and the motif inset.
const tileCells = 20;
const _inset = 2;

/// True for the 3 cells cut from each corner of the tile.
bool isCornerCell(int x, int y) {
  final dx = x < tileCells - 1 - x ? x : tileCells - 1 - x;
  final dy = y < tileCells - 1 - y ? y : tileCells - 1 - y;
  return dx + dy < 2;
}

class _TilePainter extends CustomPainter {
  _TilePainter(this.icon);

  final PixelIcon icon;

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / tileCells;
    final bg = Paint()
      ..color = icon.bg
      ..isAntiAlias = false;
    final fg = Paint()
      ..color = icon.fg
      ..isAntiAlias = false;
    // Slight overlap hides hairline seams between cells at fractional sizes. Background first,
    // motif on top, so the overlap never covers motif cells.
    Rect cellRect(int x, int y, {required bool overlap}) {
      final o = overlap ? 0.5 : 0.0;
      return Rect.fromLTWH(x * cell, y * cell, cell + o, cell + o);
    }

    for (var y = 0; y < tileCells; y++) {
      for (var x = 0; x < tileCells; x++) {
        if (isCornerCell(x, y)) continue;
        // No overlap into a cut corner cell.
        final overlap = !isCornerCell(x + 1, y) && !isCornerCell(x, y + 1) && x < tileCells - 1 && y < tileCells - 1;
        canvas.drawRect(cellRect(x, y, overlap: overlap), bg);
      }
    }
    for (var gy = 0; gy < PixelIcon.grid; gy++) {
      for (var gx = 0; gx < PixelIcon.grid; gx++) {
        if (icon.on(gx, gy)) canvas.drawRect(cellRect(gx + _inset, gy + _inset, overlap: true), fg);
      }
    }
  }

  @override
  bool shouldRepaint(_TilePainter old) => old.icon != icon;
}
