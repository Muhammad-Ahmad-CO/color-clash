// Colour Clash — one player's on-screen joystick.
// Each joystick is its own GestureDetector, so 2, 3 or 4 fingers can
// steer 2, 3 or 4 balls at the same time (multi-touch).
import 'dart:math';
import 'package:flutter/material.dart';

class Joystick extends StatefulWidget {
  const Joystick({
    super.key,
    required this.label,
    required this.color,
    required this.onDirection,
  });
  final String label;
  final Color color;
  final void Function(Offset? direction) onDirection;

  @override
  State<Joystick> createState() => _JoystickState();
}

class _JoystickState extends State<Joystick> {
  Offset _knob = Offset.zero; // -1..1 in both axes

  void _update(Offset local, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    var d = (local - center) / (size.width / 2);
    if (d.distance > 1) d = d / d.distance;
    setState(() => _knob = d);
    widget.onDirection(d);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 116,
      height: 116,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: (d) {
          final box = context.findRenderObject() as RenderBox?;
          if (box != null) _update(box.globalToLocal(d.globalPosition), box.size);
        },
        onPanUpdate: (d) {
          final box = context.findRenderObject() as RenderBox?;
          if (box != null) _update(box.globalToLocal(d.globalPosition), box.size);
        },
        onPanEnd: (_) {
          setState(() => _knob = Offset.zero);
          widget.onDirection(null);
        },
        onPanCancel: () {
          setState(() => _knob = Offset.zero);
          widget.onDirection(null);
        },
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 116,
              height: 116,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withOpacity(0.45),
                border: Border.all(color: widget.color.withOpacity(0.8), width: 2.5),
              ),
            ),
            Transform.translate(
              offset: _knob * 32,
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.color,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: const [
                    BoxShadow(color: Colors.black45, blurRadius: 6, offset: Offset(0, 2)),
                  ],
                ),
                alignment: Alignment.center,
                child: Text(
                  widget.label,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
