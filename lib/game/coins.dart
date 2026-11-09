// Colour Clash — coins + shop ownership, stored on the phone.
// Uses shared_preferences (free, no account). All calls are guarded:
// if storage ever fails, the game keeps working with memory only.
import 'package:shared_preferences/shared_preferences.dart';
import '../data/game_data.dart';

class CoinsService {
  static int coins = 0;
  static final Set<String> owned = <String>{};
  static TrailType equippedTrail = TrailType.none;
  static bool _loaded = false;

  static Future<void> load() async {
    if (_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      coins = prefs.getInt('cc_coins') ?? 0;
      owned.addAll(prefs.getStringList('cc_owned') ?? <String>[]);
      final t = prefs.getString('cc_trail') ?? 'none';
      equippedTrail = TrailType.values.firstWhere(
        (e) => e.name == t,
        orElse: () => TrailType.none,
      );
    } catch (_) {
      // Storage failed — keep memory-only values (0 coins, nothing owned).
    }
    _loaded = true;
  }

  static Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('cc_coins', coins);
      await prefs.setStringList('cc_owned', owned.toList());
      await prefs.setString('cc_trail', equippedTrail.name);
    } catch (_) {}
  }

  /// Win = 50 coins, any finished match = 10 coins.
  static Future<int> awardMatch({required bool won}) async {
    await load();
    final earned = won ? 50 : 10;
    coins += earned;
    await _save();
    return earned;
  }

  static Future<bool> buy(ShopItem item) async {
    await load();
    if (owned.contains(item.id)) return true;
    if (coins < item.cost) return false;
    coins -= item.cost;
    owned.add(item.id);
    await _save();
    return true;
  }

  static Future<void> equip(TrailType t) async {
    await load();
    equippedTrail = t;
    await _save();
  }
}
