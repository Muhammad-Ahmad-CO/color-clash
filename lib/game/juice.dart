// Color Cover — game-feel helpers (v3.8): particles, squash easing,
// trauma-shake constants, and the persisted "Reduce screen shake"
// accessibility setting. Pure Dart + shared_preferences; no widgets.
// The engine owns the particles (visual only, never simulation); the
// match screen owns trauma / hit-stop / flash and reads this file for
// the setting and the ease.
import 'package:shared_preferences/shared_preferences.dart';

/// BACK-ease-out (overshoot then settle): f(0)=0, f(1)=1, peaks ~1.1.
/// The "pop" ease for squash & stretch — linear motion reads robotic.
double easeOutBack(double t) {
  const c1 = 1.70158;
  const c3 = c1 + 1;
  final u = t - 1;
  return 1 + c3 * u * u * u + c1 * u * u;
}

/// One juice particle: a short-lived coloured speck in tile coords.
/// Visual only — never touches the simulation.
class Particle {
  Particle(this.x, this.y, this.vx, this.vy, this.life, this.maxLife,
      this.color, this.size);
  double x;
  double y;
  double vx;
  double vy;
  double life; // seconds left
  final double maxLife;
  final int color; // ARGB
  final double size; // tiles
}

/// "Reduce screen shake" accessibility setting (default off = full
/// juice). Persisted on the phone (shared_preferences, key
/// cc_reduce_shake) so it survives app restarts.
class JuiceSettings {
  static bool reduceShake = false;
  static bool _loaded = false;

  static Future<void> load() async {
    if (_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      reduceShake = prefs.getBool('cc_reduce_shake') ?? false;
    } catch (_) {}
    _loaded = true;
  }

  static Future<void> setReduceShake(bool value) async {
    reduceShake = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('cc_reduce_shake', value);
    } catch (_) {}
  }
}
