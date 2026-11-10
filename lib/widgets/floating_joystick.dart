// Color Cover — visible floating joystick overlay for the match screen.
//
// The user (03:51 PKT) reported that in VS COMPUTER "my joystick is not
// appearing" — the v2 drag steering worked but was invisible, so it felt
// like there was no control at all. User feedback overrides the reference
// spec's "zero visible controls" here: the joystick must be SEEN.
//
// Behaviour: the joystick appears exactly where the player's finger
// touches down on the arena (dynamic origin) and follows the finger.
// Base ring + knob in that player's colour, semi-transparent so the
// tiles show through. The knob travels at most [kJoystickRadius] from
// the base centre; steering direction = knob offset (the same anchor
// logic the drag code already uses). On release the joystick is gone
// immediately — it NEVER sits on the arena covering tiles while idle.
// One joystick per active pointer, each bound to its player.
import 'package:flutter/material.dart';

/// Joystick travel radius in logical pixels.
const double kJoystickRadius = 48.0;

/// One active joystick: [origin] is where the finger touched down,
/// [current] is the finger's latest position (both arena-local).
/// Steering direction is (current - origin), normalised.
class ActiveJoystick {
  ActiveJoystick({
    required this.player,
    required this.origin,
    required this.current,
  });
  final int player;
  final Offset origin;
  Offset current;
}

/// Paints every active joystick on top of the arena.
class FloatingJoystickPainter extends CustomPainter {
  FloatingJoystickPainter(this.sticks, this.playerColors);
  final List<ActiveJoystick> sticks;
  final List<Color> playerColors;

  @override
  void paint(Canvas canvas, Size size) {
    for (final stick in sticks) {
      final color = playerColors[stick.player % playerColors.length];
      final offset = stick.current - stick.origin;
      final dist = offset.distance;
      final knobOffset = dist <= kJoystickRadius
          ? offset
          : offset / dist * kJoystickRadius;
      final knobCenter = stick.origin + knobOffset;

      // Base: translucent disc + solid ring in the player's colour.
      canvas.drawCircle(
        stick.origin,
        kJoystickRadius,
        Paint()..color = Colors.white.withOpacity(0.10),
      );
      canvas.drawCircle(
        stick.origin,
        kJoystickRadius,
        Paint()
          ..color = color.withOpacity(0.75)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
      // Direction line from base centre to the knob.
      if (dist > 4) {
        canvas.drawLine(
          stick.origin,
          knobCenter,
          Paint()
            ..color = color.withOpacity(0.55)
            ..strokeWidth = 4
            ..strokeCap = StrokeCap.round,
        );
      }
      // Knob: solid player colour with a white rim.
      canvas.drawCircle(
        knobCenter,
        20,
        Paint()..color = color.withOpacity(0.92),
      );
      canvas.drawCircle(
        knobCenter,
        20,
        Paint()
          ..color = Colors.white.withOpacity(0.9)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(covariant FloatingJoystickPainter old) => true;
}
