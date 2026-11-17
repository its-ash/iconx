import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'icon_source.dart';

/// Paints a [PixelIcon] exactly like the launcher PNG: a 20x20-cell tile with pixel-rounded
/// corners and the 16x16 motif in the middle (see `IconPackTask.render` in `build.gradle.kts`).
///
/// Each icon is drawn once into a 20x20 px image (one pixel per cell), cached, and then scaled up
/// with nearest-neighbour sampling: one draw call per icon instead of ~650 rects, so long galleries
/// scroll smoothly.
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

/// One 20x20 image per icon, made on first paint. 411 icons take about 650 KB.
final _tiles = Expando<ui.Image>('pixel tile');

ui.Image _tile(PixelIcon icon) {
  final cached = _tiles[icon];
  if (cached != null) return cached;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final bg = Paint()..color = icon.bg;
  final fg = Paint()..color = icon.fg;
  for (var y = 0; y < tileCells; y++) {
    for (var x = 0; x < tileCells; x++) {
      if (isCornerCell(x, y)) continue;
      final gx = x - _inset;
      final gy = y - _inset;
      final on = gx >= 0 && gy >= 0 && gx < PixelIcon.grid && gy < PixelIcon.grid && icon.on(gx, gy);
      canvas.drawRect(Rect.fromLTWH(x.toDouble(), y.toDouble(), 1, 1), on ? fg : bg);
    }
  }
  final picture = recorder.endRecording();
  final image = picture.toImageSync(tileCells, tileCells);
  picture.dispose();
  return _tiles[icon] = image;
}

/// Makes the cached images of [icons] in idle time, a few per frame, so the first scroll through
/// a long gallery does not have to.
void precachePixelIcons(List<PixelIcon> icons, {int perTask = 16}) {
  var next = 0;
  void step() {
    final end = (next + perTask).clamp(0, icons.length);
    for (; next < end; next++) {
      _tile(icons[next]);
    }
    if (next < icons.length) SchedulerBinding.instance.scheduleTask(step, Priority.idle);
  }

  SchedulerBinding.instance.scheduleTask(step, Priority.idle);
}

class _TilePainter extends CustomPainter {
  _TilePainter(this.icon);

  final PixelIcon icon;

  static final _src = Rect.fromLTWH(0, 0, tileCells.toDouble(), tileCells.toDouble());

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawImageRect(_tile(icon), _src, Offset.zero & size, Paint()..filterQuality = FilterQuality.none);
  }

  @override
  bool shouldRepaint(_TilePainter old) => old.icon != icon;
}
