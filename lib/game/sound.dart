// Color Cover — sound effects with no audio files.
// Uses Flutter's built-in SystemSound only, so there is no paid asset
// and no copyrighted audio. The mute toggle flips [muted] and persists
// it on the phone (shared_preferences) so it survives app restarts.
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SoundFx {
  static bool muted = false;
  static bool _loaded = false;

  static Future<void> load() async {
    if (_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      muted = prefs.getBool('cc_sound_muted') ?? false;
    } catch (_) {}
    _loaded = true;
  }

  static Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('cc_sound_muted', muted);
    } catch (_) {}
  }

  static Future<void> setMuted(bool value) async {
    muted = value;
    await _save();
  }

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
