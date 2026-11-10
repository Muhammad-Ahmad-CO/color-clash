// Color Cover — real sound effects (audioplayers + generated WAVs).
// The old version used Flutter's built-in SystemSound only, which is
// effectively silent on Android — that is why the user heard nothing.
// These are short generated beeps (assets/sounds/, made with Python,
// no copyrighted audio). The mute toggle flips [muted] and persists
// it on the phone (shared_preferences, key cc_sound_muted) so it
// survives app restarts.
import 'dart:async';
import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SoundFx {
  static bool muted = false;
  static bool _loaded = false;
  static final Random _rng = Random();

  /// One pre-created player per sound. Players are created lazily
  /// (load() only runs from Home, but the preloader already plays
  /// click() before Home exists).
  static final Map<String, AudioPlayer> _players = <String, AudioPlayer>{};
  static const Map<String, String> _files = {
    'click': 'sounds/click.wav',
    'pickup': 'sounds/pickup.wav',
    'bounce': 'sounds/bounce.wav',
    'win': 'sounds/win.wav',
    'lose': 'sounds/lose.wav',
    'tick': 'sounds/tick.wav',
  };

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

  static AudioPlayer _player(String name) =>
      _players.putIfAbsent(name, () => AudioPlayer());

  static Future<void> _play(String name) async {
    if (muted) return;
    try {
      final p = _player(name);
      // SFX variation (audio-design): a small random pitch (±~1
      // semitone, 0.94–1.06x) and volume jitter on every play, so
      // repeated bounces/pickups never sound mechanical. Set per play
      // — the players are shared, so a stale value would leak into
      // the next sound. Bounce stays a quiet background blip (0.30–
      // 0.40); pickup sits just under full volume (0.90–1.0).
      await p.setPlaybackRate(0.94 + _rng.nextDouble() * 0.12);
      if (name == 'bounce') {
        await p.setVolume(0.30 + _rng.nextDouble() * 0.10);
      } else if (name == 'pickup') {
        await p.setVolume(0.90 + _rng.nextDouble() * 0.10);
      }
      // stop() first: a bare play() on a still-playing sound does not
      // reliably restart it from 0.
      await p.stop();
      await p.play(AssetSource(_files[name]!));
    } catch (_) {
      // Audio must never throw into the 16 ms game loop.
    }
  }

  static void click() {
    unawaited(_play('click'));
  }

  static void pickup() {
    unawaited(_play('pickup'));
  }

  static void bounce() {
    unawaited(_play('bounce'));
  }

  static void win() {
    unawaited(_play('win'));
  }

  static void lose() {
    unawaited(_play('lose'));
  }

  /// Countdown tick. No countdown UI exists yet — ready for one.
  static void tick() {
    unawaited(_play('tick'));
  }
}
