// Colour Clash — sound effects with no audio files.
// Uses Flutter's built-in SystemSound only, so there is no paid asset
// and no copyrighted audio. The mute toggle flips [muted].
import 'package:flutter/services.dart';

class SoundFx {
  static bool muted = false;

  static void click() {
    if (muted) return;
    SystemSound.play(SystemSoundType.click);
  }

  static void pickup() {
    if (muted) return;
    SystemSound.play(SystemSoundType.alert);
  }

  static void win() {
    if (muted) return;
    SystemSound.play(SystemSoundType.alert);
  }
}
