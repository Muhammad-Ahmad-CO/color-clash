// Color Cover — match-screen theme helpers.
// Every rule here comes from REFERENCE_UI_SPEC.md (measured from the
// reference videos): flat colours, contrasting ball "cue" colours, bright
// power-up accents, and a match gradient derived from the two player colours.
import 'dart:math';
import 'package:flutter/material.dart';

/// Relative luminance (0..1) of a colour.
double colorLuminance(Color c) {
  double channel(int v) {
    final x = v / 255.0;
    return x <= 0.03928 ? x / 12.92 : pow((x + 0.055) / 1.055, 2.4).toDouble();
  }

  return 0.2126 * channel(c.red) +
      0.7152 * channel(c.green) +
      0.0722 * channel(c.blue);
}

/// Contrasting text colour for a flat background: white on dark,
/// near-black on light.
Color contrastTextColor(Color bg) =>
    colorLuminance(bg) < 0.5 ? Colors.white : const Color(0xFF1A0A00);

/// Lighten (positive amount) or darken (negative) a colour in HSL space.
Color shiftLightness(Color c, double amount) {
  final hsl = HSLColor.fromColor(c);
  return hsl
      .withLightness((hsl.lightness + amount).clamp(0.0, 1.0))
      .toColor();
}

/// The ball "cue" colour for a player: a light ball on a dark territory,
/// a dark ball on a light territory — never the raw territory colour.
/// (Reference: pale cyan #B6F1F4 on dark indigo, deep violet #390BA6 on
/// bright pink; near-black #251508 on latte, golden tan #EBC366 on roast.)
Color cueBallColor(Color territory) {
  final hsl = HSLColor.fromColor(territory);
  if (colorLuminance(territory) < 0.5) {
    return hsl.withLightness(0.88).withSaturation(0.65).toColor();
  }
  return hsl.withLightness(0.13).withSaturation(0.7).toColor();
}

/// Power-up tile accent: warm (brown/cream) themes get salmon #E56E52,
/// everything else gets yellow #F5DA69.
Color powerUpTileColor(List<Color> territories) {
  var warm = true;
  for (final c in territories) {
    final hue = HSLColor.fromColor(c).hue; // 0..360
    if (hue < 10 || hue > 65) warm = false;
  }
  return warm ? const Color(0xFFE56E52) : const Color(0xFFF5DA69);
}

/// Glyph colour drawn on a power-up tile: dark on yellow, cream on salmon.
Color powerUpGlyphColor(Color tileColor) =>
    colorLuminance(tileColor) > 0.5
        ? const Color(0xFF230040)
        : const Color(0xFFFCEBC8);

/// Animated match background: a vertical gradient derived from the two
/// player colours, drifting slowly as [t] goes 0..1 and back.
/// Returns [top, bottom].
List<Color> matchGradient(List<Color> territories, double t) {
  final c0 = territories[0];
  final c1 = territories.length > 1 ? territories[1] : territories[0];
  final topA = shiftLightness(c0, 0.42);
  final topB = shiftLightness(c1, 0.30);
  final bottomA = shiftLightness(c0, -0.18);
  final bottomB = shiftLightness(c1, -0.22);
  return [
    Color.lerp(topA, topB, t)!,
    Color.lerp(bottomA, bottomB, t)!,
  ];
}

/// Format a match duration like the reference end card:
/// "1 minute 28 seconds" / "2 minutes 5 seconds" / "45 seconds".
String formatDuration(double seconds) {
  final total = seconds.round();
  final m = total ~/ 60;
  final s = total % 60;
  if (m == 0) return '$s seconds';
  final minWord = m == 1 ? 'minute' : 'minutes';
  return '$m $minWord $s seconds';
}
