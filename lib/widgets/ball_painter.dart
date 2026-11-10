// Color Cover — draws all 30 ball shapes + the arena.
// Reference look (REFERENCE_UI_SPEC.md): flat tiles with no grid lines and
// no unpainted state, flat balls with no outline/gloss, power-up tiles as a
// solid bright square + drawn icon (never a letter), "+" marks on wormhole
// and recently converted tiles, trails only for Nitro / Colossus / shop
// cosmetics — never in normal play.
import 'dart:math';
import 'package:flutter/material.dart';
import '../data/game_data.dart';
import '../game/engine.dart';
import '../game/match_theme.dart';

/// A 5-point (or N-point) star path centred at [center].
Path starPath(Offset center, int points, double outer, double inner) {
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

/// Draw one ball shape centred at [center] with radius [r], flat fill only.
/// No outline, no gloss, no shadow — the reference ball is a flat circle.
/// [cutColor] is the colour under the ball (used by crescent/moon cut-outs).
void drawBallShape(
    Canvas canvas, BallShape shape, Offset center, double r, Color color,
    {Color? cutColor}) {
  final paint = Paint()
    ..color = color
    ..style = PaintingStyle.fill;
  final cut = Paint()
    ..color = cutColor ?? const Color(0xFF1A1033)
    ..style = PaintingStyle.fill;

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

  switch (shape) {
    case BallShape.circle:
      canvas.drawCircle(center, r, paint);
      break;
    case BallShape.square:
      canvas.drawRect(Rect.fromCenter(center: center, width: r * 1.7, height: r * 1.7), paint);
      break;
    case BallShape.triangle:
      canvas.drawPath(polygon(3, -pi / 2), paint);
      break;
    case BallShape.diamond:
      canvas.drawPath(polygon(4, 0), paint);
      break;
    case BallShape.star:
      canvas.drawPath(starPath(center, 5, r, r * 0.45), paint);
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
      break;
    case BallShape.pentagon:
      canvas.drawPath(polygon(5, -pi / 2), paint);
      break;
    case BallShape.hexagon:
      canvas.drawPath(polygon(6, 0), paint);
      break;
    case BallShape.octagon:
      canvas.drawPath(polygon(8, pi / 8), paint);
      break;
    case BallShape.oval:
      canvas.drawOval(Rect.fromCenter(center: center, width: r * 2.1, height: r * 1.4), paint);
      break;
    case BallShape.crescent:
      canvas.drawCircle(center, r, paint);
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
      break;
    case BallShape.teardrop:
      final p = Path();
      p.moveTo(center.dx, center.dy - r);
      p.quadraticBezierTo(center.dx + r, center.dy + r * 0.2, center.dx, center.dy + r);
      p.quadraticBezierTo(center.dx - r, center.dy + r * 0.2, center.dx, center.dy - r);
      p.close();
      canvas.drawPath(p, paint);
      break;
    case BallShape.cross:
      final w = r * 0.55;
      final p = Path();
      p.addRect(Rect.fromCenter(center: center, width: w, height: r * 2));
      p.addRect(Rect.fromCenter(center: center, width: r * 2, height: w));
      canvas.drawPath(p, paint);
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
      break;
    case BallShape.cube:
      final s = r * 0.8;
      canvas.drawRect(Rect.fromCenter(center: center, width: s * 1.6, height: s * 1.6), paint);
      canvas.drawLine(Offset(center.dx - s * 0.8, center.dy - s * 0.8),
          Offset(center.dx + s * 0.8, center.dy + s * 0.8),
          Paint()
            ..color = cut.color
            ..strokeWidth = max(1.5, r * 0.1));
      break;
    case BallShape.pyramid:
      final p = Path();
      p.moveTo(center.dx, center.dy - r);
      p.lineTo(center.dx + r, center.dy + r * 0.8);
      p.lineTo(center.dx - r, center.dy + r * 0.8);
      p.close();
      canvas.drawPath(p, paint);
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
    case BallShape.clover:
      // Four leaves + centre.
      for (var i = 0; i < 4; i++) {
        final a = i * pi / 2;
        canvas.drawCircle(
            Offset(center.dx + cos(a) * r * 0.45, center.dy + sin(a) * r * 0.45),
            r * 0.5,
            paint);
      }
      canvas.drawCircle(center, r * 0.35, paint);
      break;
    case BallShape.rocket:
      // Nose triangle + body + two fins + flame.
      final rocket = Path();
      rocket.moveTo(center.dx, center.dy - r);
      rocket.lineTo(center.dx + r * 0.55, center.dy - r * 0.1);
      rocket.lineTo(center.dx + r * 0.55, center.dy + r * 0.55);
      rocket.lineTo(center.dx + r * 0.95, center.dy + r * 0.9);
      rocket.lineTo(center.dx + r * 0.3, center.dy + r * 0.55);
      rocket.lineTo(center.dx - r * 0.3, center.dy + r * 0.55);
      rocket.lineTo(center.dx - r * 0.95, center.dy + r * 0.9);
      rocket.lineTo(center.dx - r * 0.55, center.dy + r * 0.55);
      rocket.lineTo(center.dx - r * 0.55, center.dy - r * 0.1);
      rocket.close();
      canvas.drawPath(rocket, paint);
      break;
    case BallShape.crown:
      final crown = Path();
      crown.moveTo(center.dx - r * 0.9, center.dy + r * 0.7);
      crown.lineTo(center.dx - r * 0.9, center.dy - r * 0.2);
      crown.lineTo(center.dx - r * 0.45, center.dy + r * 0.1);
      crown.lineTo(center.dx, center.dy - r * 0.7);
      crown.lineTo(center.dx + r * 0.45, center.dy + r * 0.1);
      crown.lineTo(center.dx + r * 0.9, center.dy - r * 0.2);
      crown.lineTo(center.dx + r * 0.9, center.dy + r * 0.7);
      crown.close();
      canvas.drawPath(crown, paint);
      break;
    case BallShape.anchor:
      final line = Paint()
        ..color = color
        ..strokeWidth = max(2, r * 0.16)
        ..strokeCap = StrokeCap.round;
      // Ring on top.
      canvas.drawCircle(
          Offset(center.dx, center.dy - r * 0.62),
          r * 0.24,
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = max(2, r * 0.16));
      // Shank + crossbar + flukes.
      canvas.drawLine(Offset(center.dx, center.dy - r * 0.4),
          Offset(center.dx, center.dy + r * 0.75), line);
      canvas.drawLine(Offset(center.dx - r * 0.5, center.dy - r * 0.15),
          Offset(center.dx + r * 0.5, center.dy - r * 0.15), line);
      canvas.drawLine(Offset(center.dx - r * 0.85, center.dy + r * 0.35),
          Offset(center.dx, center.dy + r * 0.75), line);
      canvas.drawLine(Offset(center.dx + r * 0.85, center.dy + r * 0.35),
          Offset(center.dx, center.dy + r * 0.75), line);
      break;
    case BallShape.bell:
      final bell = Path();
      bell.moveTo(center.dx - r * 0.85, center.dy + r * 0.55);
      bell.quadraticBezierTo(center.dx - r * 0.85, center.dy - r * 0.8,
          center.dx, center.dy - r * 0.8);
      bell.quadraticBezierTo(center.dx + r * 0.85, center.dy - r * 0.8,
          center.dx + r * 0.85, center.dy + r * 0.55);
      bell.close();
      canvas.drawPath(bell, paint);
      canvas.drawRect(
          Rect.fromCenter(
              center: Offset(center.dx, center.dy + r * 0.62),
              width: r * 1.9,
              height: r * 0.28),
          paint);
      canvas.drawCircle(Offset(center.dx, center.dy + r * 0.9), r * 0.16, paint);
      break;
    case BallShape.gem:
      canvas.drawPath(polygon(4, -pi / 2), paint);
      final facet = Paint()
        ..color = cut.color
        ..strokeWidth = max(1.5, r * 0.1)
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(Offset(center.dx - r * 0.7, center.dy),
          Offset(center.dx + r * 0.7, center.dy), facet);
      canvas.drawLine(Offset(center.dx, center.dy - r),
          Offset(center.dx, center.dy + r), facet);
      break;
  }
}

/// Draw a power-up's icon glyph inside [rect] with [glyph] colour.
/// Icons are drawn paths — never letters (reference §5). Strokes are thick
/// (min ~3 px at tile scale) so each icon still reads at 35 px on a phone.
void drawPowerUpIcon(Canvas canvas, String id, Rect rect, Color glyph) {
  final fill = Paint()
    ..color = glyph
    ..style = PaintingStyle.fill;
  final stroke = Paint()
    ..color = glyph
    ..style = PaintingStyle.stroke
    ..strokeWidth = max(3, rect.height * 0.12)
    ..strokeCap = StrokeCap.round;

  Path bolt() {
    final p = Path();
    p.moveTo(rect.left + rect.width * 0.55, rect.top);
    p.lineTo(rect.left + rect.width * 0.15, rect.top + rect.height * 0.55);
    p.lineTo(rect.left + rect.width * 0.45, rect.top + rect.height * 0.55);
    p.lineTo(rect.left + rect.width * 0.4, rect.top + rect.height);
    p.lineTo(rect.left + rect.width * 0.85, rect.top + rect.height * 0.4);
    p.lineTo(rect.left + rect.width * 0.55, rect.top + rect.height * 0.4);
    p.close();
    return p;
  }

  Path flame() {
    final p = Path();
    p.moveTo(rect.center.dx, rect.top + rect.height * 0.05);
    p.cubicTo(rect.left + rect.width * 0.95, rect.top + rect.height * 0.35,
        rect.left + rect.width * 0.85, rect.top + rect.height * 0.75,
        rect.center.dx, rect.top + rect.height * 0.95);
    p.cubicTo(rect.left + rect.width * 0.15, rect.top + rect.height * 0.75,
        rect.left + rect.width * 0.05, rect.top + rect.height * 0.35,
        rect.center.dx, rect.top + rect.height * 0.05);
    p.close();
    return p;
  }

  Path shield() {
    final p = Path();
    p.moveTo(rect.center.dx, rect.top);
    p.lineTo(rect.left + rect.width * 0.9, rect.top + rect.height * 0.2);
    p.lineTo(rect.left + rect.width * 0.9, rect.top + rect.height * 0.55);
    p.quadraticBezierTo(rect.left + rect.width * 0.9, rect.top + rect.height * 0.9,
        rect.center.dx, rect.top + rect.height);
    p.quadraticBezierTo(rect.left + rect.width * 0.1, rect.top + rect.height * 0.9,
        rect.left + rect.width * 0.1, rect.top + rect.height * 0.55);
    p.lineTo(rect.left + rect.width * 0.1, rect.top + rect.height * 0.2);
    p.close();
    return p;
  }

  Path ghost() {
    final p = Path();
    p.moveTo(rect.left + rect.width * 0.1, rect.top + rect.height);
    p.lineTo(rect.left + rect.width * 0.1, rect.top + rect.height * 0.45);
    p.quadraticBezierTo(rect.left + rect.width * 0.1, rect.top,
        rect.center.dx, rect.top);
    p.quadraticBezierTo(rect.left + rect.width * 0.9, rect.top,
        rect.left + rect.width * 0.9, rect.top + rect.height * 0.45);
    p.lineTo(rect.left + rect.width * 0.9, rect.top + rect.height);
    p.lineTo(rect.left + rect.width * 0.75, rect.top + rect.height * 0.85);
    p.lineTo(rect.left + rect.width * 0.6, rect.top + rect.height);
    p.lineTo(rect.left + rect.width * 0.4, rect.top + rect.height * 0.85);
    p.lineTo(rect.left + rect.width * 0.25, rect.top + rect.height);
    p.close();
    return p;
  }

  Path upArrow() {
    final p = Path();
    p.moveTo(rect.center.dx, rect.top);
    p.lineTo(rect.left + rect.width * 0.9, rect.top + rect.height * 0.55);
    p.lineTo(rect.left + rect.width * 0.65, rect.top + rect.height * 0.55);
    p.lineTo(rect.left + rect.width * 0.65, rect.top + rect.height);
    p.lineTo(rect.left + rect.width * 0.35, rect.top + rect.height);
    p.lineTo(rect.left + rect.width * 0.35, rect.top + rect.height * 0.55);
    p.lineTo(rect.left + rect.width * 0.1, rect.top + rect.height * 0.55);
    p.close();
    return p;
  }

  switch (id) {
    case 'speed':
      canvas.drawPath(bolt(), fill);
      break;
    case 'nitro':
      canvas.drawPath(flame(), fill);
      break;
    case 'wrecking':
      canvas.drawPath(starPath(rect.center, 8, rect.width * 0.48, rect.width * 0.2), fill);
      break;
    case 'colossus':
      canvas.drawPath(upArrow(), fill);
      break;
    case 'fortify':
      canvas.drawPath(shield(), fill);
      break;
    case 'infiltrator':
      // Diagonal arrow piercing through.
      canvas.drawLine(
          Offset(rect.left + rect.width * 0.15, rect.top + rect.height * 0.85),
          Offset(rect.left + rect.width * 0.85, rect.top + rect.height * 0.15),
          stroke);
      canvas.drawPath(starPath(rect.center, 4, rect.width * 0.22, rect.width * 0.1), fill);
      break;
    case 'ghost':
      canvas.drawPath(ghost(), fill);
      break;
    case 'blackhole':
      // Solid disc + outer ring: reads as a bright disc with a halo
      // (the tile behind it is near-black, so the glyph is light).
      canvas.drawCircle(rect.center, rect.width * 0.3, fill);
      canvas.drawCircle(
          rect.center,
          rect.width * 0.44,
          Paint()
            ..color = glyph
            ..style = PaintingStyle.stroke
            ..strokeWidth = max(3, rect.height * 0.12));
      break;
    case 'tidal':
      for (var i = 0; i < 3; i++) {
        final y = rect.top + rect.height * (0.28 + i * 0.22);
        final p = Path();
        p.moveTo(rect.left + rect.width * 0.05, y);
        p.quadraticBezierTo(rect.left + rect.width * 0.28, y - rect.height * 0.12,
            rect.left + rect.width * 0.5, y);
        p.quadraticBezierTo(rect.left + rect.width * 0.72, y + rect.height * 0.12,
            rect.left + rect.width * 0.95, y);
        canvas.drawPath(p, stroke);
      }
      break;
    case 'wormhole':
      // Hollow ring + small centre dot — no solid disc, so it can never
      // be mistaken for the black hole's filled disc.
      canvas.drawCircle(
          rect.center,
          rect.width * 0.42,
          Paint()
            ..color = glyph
            ..style = PaintingStyle.stroke
            ..strokeWidth = max(3, rect.height * 0.12));
      canvas.drawCircle(rect.center, rect.width * 0.18, fill);
      break;
    case 'bomb':
      // Round body + fuse + a BIG spark dot (the old spark was 2 px and
      // vanished at tile size).
      canvas.drawCircle(
          Offset(rect.center.dx, rect.top + rect.height * 0.62),
          rect.width * 0.32,
          fill);
      canvas.drawLine(
          Offset(rect.center.dx + rect.width * 0.2, rect.top + rect.height * 0.38),
          Offset(rect.center.dx + rect.width * 0.35, rect.top + rect.height * 0.12),
          stroke);
      canvas.drawCircle(
          Offset(rect.center.dx + rect.width * 0.38, rect.top + rect.height * 0.08),
          max(3, rect.width * 0.1),
          fill);
      break;
    case 'freeze':
      // Snowflake: three crossing bars + centre dot.
      for (var i = 0; i < 3; i++) {
        final a = i * pi / 3;
        canvas.drawLine(
            Offset(rect.center.dx - cos(a) * rect.width * 0.42,
                rect.center.dy - sin(a) * rect.width * 0.42),
            Offset(rect.center.dx + cos(a) * rect.width * 0.42,
                rect.center.dy + sin(a) * rect.width * 0.42),
            stroke);
      }
      canvas.drawCircle(rect.center, max(2, rect.width * 0.09), fill);
      break;
    case 'magnet':
      // Horseshoe magnet: U-shape with two poles.
      canvas.drawArc(
          Rect.fromLTWH(rect.left + rect.width * 0.12, rect.top + rect.height * 0.08,
              rect.width * 0.76, rect.height * 0.76),
          pi,
          pi,
          false,
          Paint()
            ..color = glyph
            ..style = PaintingStyle.stroke
            ..strokeWidth = max(3, rect.height * 0.18)
            ..strokeCap = StrokeCap.round);
      canvas.drawLine(
          Offset(rect.left + rect.width * 0.12, rect.top + rect.height * 0.46),
          Offset(rect.left + rect.width * 0.12, rect.top + rect.height * 0.92),
          stroke);
      canvas.drawLine(
          Offset(rect.left + rect.width * 0.88, rect.top + rect.height * 0.46),
          Offset(rect.left + rect.width * 0.88, rect.top + rect.height * 0.92),
          stroke);
      break;
    case 'mystery':
      // Gift box: lid + two box halves (the gap between them reads as
      // the ribbon) + a two-loop bow on top. Drawn paths only, no text.
      canvas.drawRect(
          Rect.fromLTWH(rect.left + rect.width * 0.14,
              rect.top + rect.height * 0.24, rect.width * 0.72,
              rect.height * 0.16),
          fill);
      canvas.drawRect(
          Rect.fromLTWH(rect.left + rect.width * 0.18,
              rect.top + rect.height * 0.42, rect.width * 0.29,
              rect.height * 0.48),
          fill);
      canvas.drawRect(
          Rect.fromLTWH(rect.left + rect.width * 0.53,
              rect.top + rect.height * 0.42, rect.width * 0.29,
              rect.height * 0.48),
          fill);
      canvas.drawCircle(
          Offset(rect.left + rect.width * 0.36,
              rect.top + rect.height * 0.14),
          rect.width * 0.09,
          fill);
      canvas.drawCircle(
          Offset(rect.left + rect.width * 0.64,
              rect.top + rect.height * 0.14),
          rect.width * 0.09,
          fill);
      break;
    case 'trinity':
      // Three balls in a triangle: one on top, two below.
      canvas.drawCircle(
          Offset(rect.center.dx, rect.top + rect.height * 0.26),
          rect.width * 0.2,
          fill);
      canvas.drawCircle(
          Offset(rect.left + rect.width * 0.26, rect.top + rect.height * 0.72),
          rect.width * 0.2,
          fill);
      canvas.drawCircle(
          Offset(rect.left + rect.width * 0.74, rect.top + rect.height * 0.72),
          rect.width * 0.2,
          fill);
      break;
    case 'turret':
      // Rook / castle: three battlements on top of a solid base.
      canvas.drawRect(
          Rect.fromLTWH(rect.left + rect.width * 0.16,
              rect.top + rect.height * 0.42, rect.width * 0.68,
              rect.height * 0.48),
          fill);
      for (var i = 0; i < 3; i++) {
        canvas.drawRect(
            Rect.fromLTWH(rect.left + rect.width * (0.16 + i * 0.24),
                rect.top + rect.height * 0.14, rect.width * 0.16,
                rect.height * 0.3),
            fill);
      }
      break;
    default:
      canvas.drawPath(starPath(rect.center, 5, rect.width * 0.45, rect.width * 0.2), fill);
  }
}

/// Small widget that draws a power-up icon (used in How to Play).
/// [color] overrides the glyph colour; default is the power-up's own colour.
class PowerUpIconWidget extends StatelessWidget {
  const PowerUpIconWidget({super.key, required this.def, this.size = 34, this.color});
  final PowerUpDef def;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _PowerUpIconPainter(def, color),
    );
  }
}

class _PowerUpIconPainter extends CustomPainter {
  _PowerUpIconPainter(this.def, this.color);
  final PowerUpDef def;
  final Color? color;
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(size.width * 0.12, size.height * 0.12,
        size.width * 0.76, size.height * 0.76);
    drawPowerUpIcon(canvas, def.id, rect, color ?? Color(def.value));
  }

  @override
  bool shouldRepaint(covariant _PowerUpIconPainter old) => old.def != def;
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

/// Is the tile (c, r) inside the arena shape? Same math as
/// GameEngine._initPlayable — kept in sync so the setup preview shows the
/// exact shape the match will use.
bool arenaShapeCellPlayable(ArenaShape shape, int c, int r, int cols, int rows) {
  final nx = (c + 0.5) / cols * 2 - 1; // -1..1
  final ny = (r + 0.5) / rows * 2 - 1;
  switch (shape) {
    case ArenaShape.rectangle:
      return true;
    case ArenaShape.circle:
      return (nx * nx + ny * ny) <= 1.0;
    case ArenaShape.heart:
      final x = nx * 1.1;
      final y = -ny;
      return ((x * x + y * y - 1) * (x * x + y * y - 1) * (x * x + y * y - 1) -
              x * x * y * y * y) <=
          0;
    case ArenaShape.star:
      final ang = atan2(ny, nx);
      final dist = sqrt(nx * nx + ny * ny);
      final starR = 0.55 + 0.45 * cos(ang * 5);
      return dist <= starR;
    case ArenaShape.maze:
      final wallRow = r % 4 == 2 && c % 5 != 2;
      final wallCol = c % 5 == 2 && r % 4 != 2;
      return !(wallRow || wallCol);
  }
}

/// Small widget that draws the real arena shape as a mini 18x24 grid
/// (used in Setup's arena-shape picker). Playable tiles are filled with
/// [color]; dead tiles stay transparent.
class ArenaShapePreview extends StatelessWidget {
  const ArenaShapePreview(
      {super.key, required this.shape, required this.color, this.size = 56});
  final ArenaShape shape;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size * 4 / 3),
      painter: _ArenaShapePreviewPainter(shape, color),
    );
  }
}

class _ArenaShapePreviewPainter extends CustomPainter {
  _ArenaShapePreviewPainter(this.shape, this.color);
  final ArenaShape shape;
  final Color color;
  static const _cols = 18;
  static const _rows = 24;

  @override
  void paint(Canvas canvas, Size size) {
    final tileW = size.width / _cols;
    final tileH = size.height / _rows;
    final paint = Paint()..color = color;
    for (var r = 0; r < _rows; r++) {
      for (var c = 0; c < _cols; c++) {
        if (!arenaShapeCellPlayable(shape, c, r, _cols, _rows)) continue;
        canvas.drawRect(
            Rect.fromLTWH(c * tileW, r * tileH, tileW, tileH), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ArenaShapePreviewPainter old) =>
      old.shape != shape || old.color != color;
}

/// Paints the whole arena: flat tiles, power-ups, balls. No grid lines,
/// no arena background, no border, no radius — the reference look.
class ArenaPainter extends CustomPainter {
  ArenaPainter(this.engine, this.players, this.now, {this.trail = TrailType.none});
  final GameEngine engine;
  final List<PlayerConfig> players;
  final double now; // engine.time, drives the "+" marks
  final TrailType trail;

  Color _tileColor(int owner) => Color(players[owner].colour.value);

  Color _tileColorAt(double x, double y) {
    final c = x.floor().clamp(0, engine.cols - 1);
    final r = y.floor().clamp(0, engine.rows - 1);
    final owner = engine.grid[engine.tileIndex(c, r)];
    if (owner < 0) return const Color(0xFF1A1033);
    return _tileColor(owner);
  }

  /// The active timed buff to show on a ball, by priority: freeze first
  /// (it stops the ball entirely), then the paint/speed buffs. Returns
  /// the power-up id, or null when no buff needs a marker. Nitro (gold
  /// streak), Colossus (giant ball + ghost trail) and Black Hole (disc +
  /// debris) already have their own visuals, so they need no ring.
  String? _activeBuff(BallState b) {
    if (engine.frozenUntil[b.player] > engine.time) return 'freeze';
    if (b.speedUntil > engine.time) return 'speed';
    if (b.wreckingUntil > engine.time) return 'wrecking';
    if (engine.fortifyUntil[b.player] > engine.time) return 'fortify';
    if (b.infiltratorUntil > engine.time) return 'infiltrator';
    if (b.magnetUntil > engine.time) return 'magnet';
    if (b.ghostUntil > engine.time) return 'ghost';
    return null;
  }

  void _drawPlus(Canvas canvas, Offset center, double size, Color color) {
    final p = Paint()
      ..color = color
      ..strokeWidth = max(1.5, size * 0.18)
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
        Offset(center.dx - size / 2, center.dy), Offset(center.dx + size / 2, center.dy), p);
    canvas.drawLine(
        Offset(center.dx, center.dy - size / 2), Offset(center.dx, center.dy + size / 2), p);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final tileW = size.width / engine.cols;
    final tileH = size.height / engine.rows;

    // Tiles: flat per-tile fill only. Dead/outside tiles are left
    // transparent so the animated gradient shows through.
    for (var r = 0; r < engine.rows; r++) {
      for (var c = 0; c < engine.cols; c++) {
        final idx = engine.tileIndex(c, r);
        final owner = engine.grid[idx];
        if (owner < 0 || !engine.playable[idx]) continue;
        canvas.drawRect(
            Rect.fromLTWH(c * tileW, r * tileH, tileW, tileH),
            Paint()..color = _tileColor(owner));
      }
    }

    // Wormhole portal block: dark tiles with a pale "+".
    if (engine.time < engine.wormholeUntil) {
      for (final idx in engine.wormholeTiles) {
        final c = idx % engine.cols;
        final r = idx ~/ engine.cols;
        canvas.drawRect(
            Rect.fromLTWH(c * tileW, r * tileH, tileW, tileH),
            Paint()..color = const Color(0xFF230040));
        _drawPlus(
            canvas,
            Offset((c + 0.5) * tileW, (r + 0.5) * tileH),
            tileW * 0.36,
            Colors.white.withOpacity(0.9));
      }
    }

    // "+" marks on tiles converted in the last ~1.5 s.
    for (var r = 0; r < engine.rows; r++) {
      for (var c = 0; c < engine.cols; c++) {
        final idx = engine.tileIndex(c, r);
        final owner = engine.grid[idx];
        if (owner < 0 || !engine.playable[idx]) continue;
        final age = now - engine.paintTime[idx];
        if (engine.paintTime[idx] > 0.01 && age >= 0 && age < 1.5) {
          _drawPlus(
              canvas,
              Offset((c + 0.5) * tileW, (r + 0.5) * tileH),
              tileW * 0.32,
              contrastTextColor(_tileColor(owner)).withOpacity(0.85));
        }
      }
    }

    // Golden Tile (Golden Rush mode): gold square + drawn star.
    if (engine.goldenVisible && engine.goldenCol >= 0) {
      final rect = Rect.fromLTWH(engine.goldenCol * tileW,
          engine.goldenRow * tileH, tileW, tileH);
      canvas.drawRect(rect, Paint()..color = const Color(0xFFFFCA28));
      canvas.drawPath(
          starPath(rect.center, 5, tileW * 0.32, tileW * 0.14),
          Paint()..color = const Color(0xFF1A0A00));
    }

    // Power-up tiles: solid square in the power-up's OWN colour + drawn
    // icon glyph in high-contrast colour (never a letter). The icon fills
    // 80% of the tile so each power-up reads at a glance on a phone.
    // A mystery tile hides its power behind a purple gift box.
    for (final p in engine.powerUps) {
      final rect = Rect.fromLTWH(p.col * tileW, p.row * tileH, tileW, tileH);
      final iconRect = Rect.fromLTWH(
          p.col * tileW + tileW * 0.1,
          p.row * tileH + tileH * 0.1,
          tileW * 0.8,
          tileH * 0.8);
      if (p.mystery) {
        canvas.drawRect(rect, Paint()..color = const Color(0xFF9C27B0));
        drawPowerUpIcon(canvas, 'mystery', iconRect, Colors.white);
        continue;
      }
      final tileColor = Color(p.def.value);
      canvas.drawRect(rect, Paint()..color = tileColor);
      drawPowerUpIcon(canvas, p.def.id, iconRect, contrastTextColor(tileColor));
    }

    // Turrets: stationary auto-painters on their owner's colour tile
    // (the tile is unpaintable while the turret lives, so the grid colour
    // and the turret owner always agree). Rook glyph + a barrel aimed at
    // the last target + a brief tracer line on each shot.
    for (final t in engine.turrets) {
      final tileColor = Color(players[t.player].colour.value);
      final trect = Rect.fromLTWH(t.col * tileW, t.row * tileH, tileW, tileH);
      canvas.drawRect(trect, Paint()..color = tileColor);
      final glyph = contrastTextColor(tileColor);
      final tcenter = Offset((t.col + 0.5) * tileW, (t.row + 0.5) * tileH);
      canvas.drawLine(
          tcenter,
          Offset(tcenter.dx + cos(t.aimAngle) * tileW * 0.45,
              tcenter.dy + sin(t.aimAngle) * tileH * 0.45),
          Paint()
            ..color = glyph
            ..strokeWidth = max(2, tileW * 0.08)
            ..strokeCap = StrokeCap.round);
      drawPowerUpIcon(
          canvas,
          'turret',
          Rect.fromLTWH(t.col * tileW + tileW * 0.14,
              t.row * tileH + tileH * 0.14, tileW * 0.72, tileH * 0.72),
          glyph);
      if (t.shotTarget != null && now < t.shotUntil) {
        canvas.drawLine(
            tcenter,
            Offset((t.shotTarget!.x + 0.5) * tileW,
                (t.shotTarget!.y + 0.5) * tileH),
            Paint()
              ..color = Colors.white.withOpacity(0.85)
              ..strokeWidth = max(1.5, tileW * 0.06)
              ..strokeCap = StrokeCap.round);
      }
    }

    // Balls.
    for (final b in engine.balls) {
      final cfg = players[b.player];
      final territory = Color(cfg.colour.value);
      Color color = cueBallColor(territory);
      if (trail == TrailType.rainbow) {
        color = HSVColor.fromAHSV(1, (now * 120 + b.player * 90) % 360, 0.85, 1).toColor();
      } else if (trail == TrailType.golden) {
        color = const Color(0xFFFFCA28);
      }
      final center = Offset(b.x * tileW, b.y * tileH);
      final isNitro = b.nitroUntil > engine.time;
      final isColossus = b.colossusUntil > engine.time;
      final isBlackHole = b.blackHoleUntil > engine.time;

      // Trails only for effects / shop cosmetics — never in normal play.
      if (isNitro && b.trail.length > 1) {
        // Gold streak behind the ball (reference Nitro).
        final streak = Paint()
          ..color = const Color(0xFFE7C168)
          ..strokeWidth = tileW * 0.28
          ..strokeCap = StrokeCap.round;
        final path = Path();
        path.moveTo(b.trail.first.x * tileW, b.trail.first.y * tileH);
        for (final t in b.trail.skip(1)) {
          path.lineTo(t.x * tileW, t.y * tileH);
        }
        path.lineTo(center.dx, center.dy);
        canvas.drawPath(path, streak);
      } else if (isColossus) {
        // Fading ghost circles behind the giant ball.
        for (var i = 0; i < b.trail.length; i++) {
          final t = b.trail[i];
          canvas.drawCircle(
            Offset(t.x * tileW, t.y * tileH),
            tileW * 0.6 * (0.3 + 0.7 * i / b.trail.length),
            Paint()..color = color.withOpacity(0.12 + 0.25 * i / b.trail.length),
          );
        }
      } else if (trail == TrailType.glow || trail == TrailType.fire) {
        for (var i = 0; i < b.trail.length; i++) {
          final t = b.trail[i];
          final trailColor = trail == TrailType.fire
              ? const Color(0xFFFF6D00)
              : color;
          canvas.drawCircle(
            Offset(t.x * tileW, t.y * tileH),
            tileW * 0.45 * (0.4 + 0.6 * i / b.trail.length),
            Paint()..color = trailColor.withOpacity(0.35 * i / b.trail.length),
          );
        }
      }

      // Black Hole: near-black disc + orbiting debris.
      if (isBlackHole) {
        canvas.drawCircle(center, tileW * 0.9, Paint()..color = Colors.black);
        for (var i = 0; i < 6; i++) {
          final a = now * 3 + i * pi / 3;
          canvas.drawCircle(
              Offset(center.dx + cos(a) * tileW * 1.4,
                  center.dy + sin(a) * tileW * 1.4),
              max(1.5, tileW * 0.06),
              Paint()..color = Colors.black87);
        }
      }

      final radius = tileW * (isColossus ? 2.2 : 0.375);
      drawBallShape(
        canvas,
        cfg.shape,
        center,
        radius,
        color,
        cutColor: _tileColorAt(b.x, b.y),
      );
      // Ghost balls look see-through.
      if (b.ghostUntil > engine.time) {
        canvas.drawCircle(
          center,
          radius,
          Paint()..color = Colors.white.withOpacity(0.25),
        );
      }
      // Frozen ball: ice-blue overlay so the freeze is obvious — a frozen
      // ball does not move, paint or pick up anything.
      if (engine.frozenUntil[b.player] > engine.time) {
        canvas.drawCircle(
          center,
          radius,
          Paint()..color = const Color(0xFFB3E5FC).withOpacity(0.55),
        );
      }
      // Active timed buff: a ring around the ball + a small icon badge
      // above it, both in the power-up's own colour, so any player can
      // tell at a glance which buff is running.
      final buff = _activeBuff(b);
      if (buff != null) {
        final buffColor = Color(powerUpById(buff).value);
        final ringR = radius + max(3, tileW * 0.12);
        canvas.drawCircle(
          center,
          ringR,
          Paint()
            ..color = buffColor
            ..style = PaintingStyle.stroke
            ..strokeWidth = max(3, tileW * 0.1),
        );
        final badgeR = tileW * 0.34;
        // Clamped inside the arena so the badge never clips off an edge.
        // (.toDouble() because num.clamp returns num, not double.)
        final badgeCenter = Offset(
          center.dx.clamp(badgeR + 2, size.width - badgeR - 2).toDouble(),
          (center.dy - ringR - badgeR - 2)
              .clamp(badgeR + 2, size.height - badgeR - 2)
              .toDouble(),
        );
        canvas.drawCircle(badgeCenter, badgeR, Paint()..color = buffColor);
        drawPowerUpIcon(
            canvas,
            buff,
            Rect.fromCircle(center: badgeCenter, radius: badgeR * 0.7),
            contrastTextColor(buffColor));
      }
    }
  }

  @override
  bool shouldRepaint(covariant ArenaPainter old) => true;
}
