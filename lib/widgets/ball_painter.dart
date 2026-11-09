// Colour Clash — draws all 24 ball shapes + the arena.
// Arena painter also draws the tile grid with a paint "pop" animation:
// a tile that was just painted draws slightly larger for a moment.
import 'dart:math';
import 'package:flutter/material.dart';
import '../data/game_data.dart';
import '../game/engine.dart';

/// Draw one ball shape centred at [center] with radius [r].
void drawBallShape(
    Canvas canvas, BallShape shape, Offset center, double r, Color color) {
  final paint = Paint()
    ..color = color
    ..style = PaintingStyle.fill;
  final outline = Paint()
    ..color = Colors.white.withOpacity(0.85)
    ..style = PaintingStyle.stroke
    ..strokeWidth = max(1.5, r * 0.12);

  Path polygon(int sides, double rotation) {
    final path = Path();
    for (var i = 0; i < sides; i++) {
      final a = rotation + i * 2 * pi / sides;
      final p = Offset(center.dx + cos(a) * r, center.dy + sin(a) * r);
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    return path;
  }

  Path starPath(int points, double outer, double inner) {
    final path = Path();
    for (var i = 0; i < points * 2; i++) {
      final rad = i.isEven ? outer : inner;
      final a = -pi / 2 + i * pi / points;
      final p = Offset(center.dx + cos(a) * rad, center.dy + sin(a) * rad);
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    return path;
  }

  switch (shape) {
    case BallShape.circle:
      canvas.drawCircle(center, r, paint);
      canvas.drawCircle(center, r, outline);
      break;
    case BallShape.square:
      canvas.drawRect(Rect.fromCenter(center: center, width: r * 1.7, height: r * 1.7), paint);
      canvas.drawRect(Rect.fromCenter(center: center, width: r * 1.7, height: r * 1.7), outline);
      break;
    case BallShape.triangle:
      final p = polygon(3, -pi / 2);
      canvas.drawPath(p, paint);
      canvas.drawPath(p, outline);
      break;
    case BallShape.diamond:
      final p = polygon(4, 0);
      canvas.drawPath(p, paint);
      canvas.drawPath(p, outline);
      break;
    case BallShape.star:
      final p = starPath(5, r, r * 0.45);
      canvas.drawPath(p, paint);
      canvas.drawPath(p, outline);
      break;
    case BallShape.heart:
      final p = Path();
      p.moveTo(center.dx, center.dy + r * 0.9);
      p.cubicTo(center.dx - r * 1.3, center.dy - r * 0.1, center.dx - r * 0.7,
          center.dy - r * 1.0, center.dx, center.dy - r * 0.3);
      p.cubicTo(center.dx + r * 0.7, center.dy - r * 1.0, center.dx + r * 1.3,
          center.dy - r * 0.1, center.dx, center.dy + r * 0.9);
      p.close();
      canvas.drawPath(p, paint);
      canvas.drawPath(p, outline);
      break;
    case BallShape.pentagon:
      final p = polygon(5, -pi / 2);
      canvas.drawPath(p, paint);
      canvas.drawPath(p, outline);
      break;
    case BallShape.hexagon:
      final p = polygon(6, 0);
      canvas.drawPath(p, paint);
      canvas.drawPath(p, outline);
      break;
    case BallShape.octagon:
      final p = polygon(8, pi / 8);
      canvas.drawPath(p, paint);
      canvas.drawPath(p, outline);
      break;
    case BallShape.oval:
      canvas.drawOval(Rect.fromCenter(center: center, width: r * 2.1, height: r * 1.4), paint);
      canvas.drawOval(Rect.fromCenter(center: center, width: r * 2.1, height: r * 1.4), outline);
      break;
    case BallShape.crescent:
      canvas.drawCircle(center, r, paint);
      final cut = Paint()..color = const Color(0xFF1A1033);
      canvas.drawCircle(center + Offset(r * 0.45, -r * 0.2), r * 0.85, cut);
      break;
    case BallShape.lightning:
      final p = Path();
      p.moveTo(center.dx + r * 0.2, center.dy - r);
      p.lineTo(center.dx - r * 0.6, center.dy + r * 0.1);
      p.lineTo(center.dx - r * 0.05, center.dy + r * 0.1);
      p.lineTo(center.dx - r * 0.2, center.dy + r);
      p.lineTo(center.dx + r * 0.6, center.dy - r * 0.1);
      p.lineTo(center.dx + r * 0.05, center.dy - r * 0.1);
      p.close();
      canvas.drawPath(p, paint);
      canvas.drawPath(p, outline);
      break;
    case BallShape.teardrop:
      final p = Path();
      p.moveTo(center.dx, center.dy - r);
      p.quadraticBezierTo(center.dx + r, center.dy + r * 0.2, center.dx, center.dy + r);
      p.quadraticBezierTo(center.dx - r, center.dy + r * 0.2, center.dx, center.dy - r);
      p.close();
      canvas.drawPath(p, paint);
      canvas.drawPath(p, outline);
      break;
    case BallShape.cross:
      final w = r * 0.55;
      final p = Path();
      p.addRect(Rect.fromCenter(center: center, width: w, height: r * 2));
      p.addRect(Rect.fromCenter(center: center, width: r * 2, height: w));
      canvas.drawPath(p, paint);
      canvas.drawPath(p, outline);
      break;
    case BallShape.flower:
      for (var i = 0; i < 6; i++) {
        final a = i * pi / 3;
        canvas.drawCircle(
            Offset(center.dx + cos(a) * r * 0.55, center.dy + sin(a) * r * 0.55),
            r * 0.5,
            paint);
      }
      canvas.drawCircle(center, r * 0.45, Paint()..color = Colors.white);
      break;
    case BallShape.moon:
      canvas.drawCircle(center, r, paint);
      final cut = Paint()..color = const Color(0xFF1A1033);
      canvas.drawCircle(center + Offset(r * 0.5, 0), r * 0.9, cut);
      break;
    case BallShape.sun:
      canvas.drawCircle(center, r * 0.65, paint);
      final ray = Paint()
        ..color = color
        ..strokeWidth = max(2, r * 0.18)
        ..strokeCap = StrokeCap.round;
      for (var i = 0; i < 8; i++) {
        final a = i * pi / 4;
        canvas.drawLine(
            Offset(center.dx + cos(a) * r * 0.8, center.dy + sin(a) * r * 0.8),
            Offset(center.dx + cos(a) * r * 1.15, center.dy + sin(a) * r * 1.15),
            ray);
      }
      break;
    case BallShape.arrow:
      final p = Path();
      p.moveTo(center.dx - r, center.dy);
      p.lineTo(center.dx + r * 0.3, center.dy - r * 0.7);
      p.lineTo(center.dx + r * 0.3, center.dy - r * 0.25);
      p.lineTo(center.dx + r, center.dy - r * 0.25);
      p.lineTo(center.dx + r, center.dy + r * 0.25);
      p.lineTo(center.dx + r * 0.3, center.dy + r * 0.25);
      p.lineTo(center.dx + r * 0.3, center.dy + r * 0.7);
      p.close();
      canvas.drawPath(p, paint);
      canvas.drawPath(p, outline);
      break;
    case BallShape.ring:
      canvas.drawCircle(
          center,
          r,
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = max(2.5, r * 0.3));
      break;
    case BallShape.blob:
      final p = Path();
      p.moveTo(center.dx, center.dy - r);
      p.quadraticBezierTo(center.dx + r, center.dy - r * 0.8, center.dx + r * 0.85, center.dy);
      p.quadraticBezierTo(center.dx + r * 0.9, center.dy + r * 0.8, center.dx, center.dy + r * 0.9);
      p.quadraticBezierTo(center.dx - r * 0.9, center.dy + r * 0.7, center.dx - r * 0.85, center.dy);
      p.quadraticBezierTo(center.dx - r, center.dy - r * 0.8, center.dx, center.dy - r);
      p.close();
      canvas.drawPath(p, paint);
      canvas.drawPath(p, outline);
      break;
    case BallShape.cube:
      final s = r * 0.8;
      canvas.drawRect(Rect.fromCenter(center: center, width: s * 1.6, height: s * 1.6), paint);
      canvas.drawRect(Rect.fromCenter(center: center, width: s * 1.6, height: s * 1.6), outline);
      canvas.drawLine(Offset(center.dx - s * 0.8, center.dy - s * 0.8),
          Offset(center.dx + s * 0.8, center.dy + s * 0.8), outline);
      break;
    case BallShape.pyramid:
      final p = Path();
      p.moveTo(center.dx, center.dy - r);
      p.lineTo(center.dx + r, center.dy + r * 0.8);
      p.lineTo(center.dx - r, center.dy + r * 0.8);
      p.close();
      canvas.drawPath(p, paint);
      canvas.drawPath(p, outline);
      break;
    case BallShape.snowflake:
      final line = Paint()
        ..color = color
        ..strokeWidth = max(2, r * 0.18)
        ..strokeCap = StrokeCap.round;
      for (var i = 0; i < 3; i++) {
        final a = i * pi / 3;
        canvas.drawLine(
            Offset(center.dx - cos(a) * r, center.dy - sin(a) * r),
            Offset(center.dx + cos(a) * r, center.dy + sin(a) * r),
            line);
      }
      canvas.drawCircle(center, r * 0.2, paint);
      break;
    case BallShape.smiley:
      canvas.drawCircle(center, r, paint);
      final dark = Paint()..color = Colors.black87;
      canvas.drawCircle(center + Offset(-r * 0.35, -r * 0.25), r * 0.13, dark);
      canvas.drawCircle(center + Offset(r * 0.35, -r * 0.25), r * 0.13, dark);
      final smile = Paint()
        ..color = Colors.black87
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(1.5, r * 0.12)
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(Rect.fromCircle(center: center, radius: r * 0.6), 0.15 * pi, 0.7 * pi, false, smile);
      break;
  }
}

/// Small preview widget used in Setup's shape grid.
class ShapePreview extends StatelessWidget {
  const ShapePreview({super.key, required this.shape, required this.color, this.size = 44});
  final BallShape shape;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _ShapePreviewPainter(shape, color),
    );
  }
}

class _ShapePreviewPainter extends CustomPainter {
  _ShapePreviewPainter(this.shape, this.color);
  final BallShape shape;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    drawBallShape(canvas, shape, Offset(size.width / 2, size.height / 2),
        size.width * 0.38, color);
  }

  @override
  bool shouldRepaint(covariant _ShapePreviewPainter old) =>
      old.shape != shape || old.color != color;
}

/// Paints the whole arena: tiles, power-ups, trails and balls.
class ArenaPainter extends CustomPainter {
  ArenaPainter(this.engine, this.players, this.now, {this.trail = TrailType.none});
  final GameEngine engine;
  final List<PlayerConfig> players;
  final double now; // engine.time, drives the pop animation
  final TrailType trail;

  @override
  void paint(Canvas canvas, Size size) {
    final tileW = size.width / engine.cols;
    final tileH = size.height / engine.rows;

    // Tiles with a short "pop" after they are painted.
    for (var r = 0; r < engine.rows; r++) {
      for (var c = 0; c < engine.cols; c++) {
        final idx = engine.tileIndex(c, r);
        final owner = engine.grid[idx];
        if (owner == -2 || !engine.playable[idx]) {
          canvas.drawRect(
              Rect.fromLTWH(c * tileW, r * tileH, tileW, tileH),
              Paint()..color = const Color(0xFF0D0819));
          continue;
        }
        if (owner < 0) continue;
        final age = now - engine.paintTime[idx];
        final pop = age < 0.25 ? 1 + (0.25 - age) * 0.8 : 1.0;
        final w = tileW * pop;
        final h = tileH * pop;
        final rect = Rect.fromLTWH(
          c * tileW + (tileW - w) / 2,
          r * tileH + (tileH - h) / 2,
          w,
          h,
        );
        canvas.drawRect(rect,
            Paint()..color = Color(players[owner].colour.value));
      }
    }

    // Faint grid lines.
    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.06)
      ..strokeWidth = 1;
    for (var c = 1; c < engine.cols; c++) {
      canvas.drawLine(Offset(c * tileW, 0), Offset(c * tileW, size.height), gridPaint);
    }
    for (var r = 1; r < engine.rows; r++) {
      canvas.drawLine(Offset(0, r * tileH), Offset(size.width, r * tileH), gridPaint);
    }

    // Golden Tile in the centre (Golden Rush mode).
    if (engine.goldenVisible && engine.goldenCol >= 0) {
      final rect = Rect.fromLTWH(engine.goldenCol * tileW + 1, engine.goldenRow * tileH + 1,
          tileW - 2, tileH - 2);
      canvas.drawRect(rect, Paint()..color = const Color(0xFFFFCA28));
      final tp = TextPainter(
        text: const TextSpan(
            text: '★',
            style: TextStyle(color: Colors.black, fontSize: 20, fontWeight: FontWeight.w900)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas,
          Offset(engine.goldenCol * tileW + (tileW - tp.width) / 2,
              engine.goldenRow * tileH + (tileH - tp.height) / 2));
    }

    // Power-up tiles: dark square, coloured border, big letter.
    for (final p in engine.powerUps) {
      final rect = Rect.fromLTWH(
          p.col * tileW + 1, p.row * tileH + 1, tileW - 2, tileH - 2);
      canvas.drawRect(rect, Paint()..color = const Color(0xFF1A1033));
      canvas.drawRect(
          rect,
          Paint()
            ..color = Color(p.def.value)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2);
      final tp = TextPainter(
        text: TextSpan(
          text: p.def.letter,
          style: TextStyle(
            color: Color(p.def.value),
            fontSize: tileH * 0.7,
            fontWeight: FontWeight.w900,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
          canvas,
          Offset(p.col * tileW + (tileW - tp.width) / 2,
              p.row * tileH + (tileH - tp.height) / 2));
    }

    // Ball trails, then balls.
    for (final b in engine.balls) {
      final cfg = players[b.player];
      Color color = Color(cfg.colour.value);
      if (trail == TrailType.rainbow) {
        color = HSVColor.fromAHSV(1, (now * 120 + b.player * 90) % 360, 0.85, 1).toColor();
      } else if (trail == TrailType.golden) {
        color = const Color(0xFFFFCA28);
      }
      final isNitro = b.nitroUntil > engine.time;
      for (var i = 0; i < b.trail.length; i++) {
        final t = b.trail[i];
        final alpha = (i / b.trail.length) * (isNitro ? 0.7 : 0.35);
        final trailColor = trail == TrailType.fire
            ? const Color(0xFFFF6D00)
            : color;
        final trailSize = trail == TrailType.glow
            ? tileW * 0.7 * (0.4 + 0.6 * i / b.trail.length)
            : tileW * 0.45 * (0.4 + 0.6 * i / b.trail.length);
        canvas.drawCircle(
          Offset(t.x * tileW, t.y * tileH),
          trailSize,
          Paint()..color = trailColor.withOpacity(alpha),
        );
      }
      final isColossus = b.colossusUntil > engine.time;
      final radius = tileW * (isColossus ? 1.15 : 0.55);
      // Soft glow behind the ball.
      canvas.drawCircle(
        Offset(b.x * tileW, b.y * tileH),
        radius * 1.6,
        Paint()..color = color.withOpacity(0.25),
      );
      drawBallShape(
        canvas,
        cfg.shape,
        Offset(b.x * tileW, b.y * tileH),
        radius,
        color,
      );
      // Ghost balls look see-through.
      if (b.ghostUntil > engine.time) {
        canvas.drawCircle(
          Offset(b.x * tileW, b.y * tileH),
          radius,
          Paint()..color = Colors.white.withOpacity(0.25),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant ArenaPainter old) => true;
}
