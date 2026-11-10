// Color Cover — match history, lifetime stats, achievements, daily reward.
// All local (shared_preferences), no login, no network. Every call is
// guarded: if storage fails, the game keeps working with memory only.
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'coins.dart';

/// One finished match, as shown on the History screen.
class MatchRecord {
  MatchRecord({
    required this.date,
    required this.mode,
    required this.players,
    required this.winner,
    required this.durationSeconds,
    required this.tiles,
    required this.powerUps,
    required this.coinsEarned,
    required this.won,
  });

  final DateTime date;
  final String mode;
  final List<String> players;
  final String winner;
  final int durationSeconds;
  final List<int> tiles; // tiles painted per player
  final List<int> powerUps; // power-ups collected per player
  final int coinsEarned;
  final bool won; // true when Player 1 (or their team) won

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'mode': mode,
        'players': players,
        'winner': winner,
        'duration': durationSeconds,
        'tiles': tiles,
        'powerUps': powerUps,
        'coins': coinsEarned,
        'won': won,
      };

  static MatchRecord? fromJson(Map<String, dynamic> j) {
    try {
      return MatchRecord(
        date: DateTime.parse(j['date'] as String),
        mode: j['mode'] as String? ?? '',
        players:
            (j['players'] as List<dynamic>? ?? []).map((e) => e.toString()).toList(),
        winner: j['winner'] as String? ?? '',
        durationSeconds: j['duration'] as int? ?? 0,
        tiles: (j['tiles'] as List<dynamic>? ?? [])
            .map((e) => (e as num).toInt())
            .toList(),
        powerUps: (j['powerUps'] as List<dynamic>? ?? [])
            .map((e) => (e as num).toInt())
            .toList(),
        coinsEarned: j['coins'] as int? ?? 0,
        won: j['won'] as bool? ?? false,
      );
    } catch (_) {
      return null;
    }
  }
}

/// One achievement badge. Rewards are paid once, in coins.
class AchievementDef {
  const AchievementDef(this.id, this.name, this.desc, this.reward);
  final String id;
  final String name;
  final String desc;
  final int reward;
}

const List<AchievementDef> kAchievements = [
  AchievementDef('first_win', 'First Win', 'Win your first match.', 25),
  AchievementDef('streak5', 'On Fire', 'Win 5 matches in a row.', 100),
  AchievementDef('tiles1000', 'Painter', 'Paint 1000 tiles in total.', 50),
  AchievementDef('powerups10', 'Power Collector', 'Collect 10 power-ups in total.', 50),
  AchievementDef('beat_crazy', 'Bot Slayer', 'Beat the computer on Crazy.', 75),
  AchievementDef('win_4p', 'Crowd Champion', 'Win a 4-player match.', 75),
  AchievementDef('win_sudden', 'Last Second', 'Win a Sudden Death match.', 50),
];

AchievementDef achievementById(String id) =>
    kAchievements.firstWhere((a) => a.id == id, orElse: () => kAchievements[0]);

class StatsService {
  static List<MatchRecord> history = <MatchRecord>[];
  static int lifetimeTiles = 0;
  static int lifetimePowerUps = 0;
  static int wins = 0;
  static int winStreak = 0;
  static int bestStreak = 0;
  static final Set<String> unlocked = <String>{};
  static bool _loaded = false;

  static Future<void> load() async {
    if (_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      lifetimeTiles = prefs.getInt('cc_lifetime_tiles') ?? 0;
      lifetimePowerUps = prefs.getInt('cc_lifetime_powerups') ?? 0;
      wins = prefs.getInt('cc_wins') ?? 0;
      winStreak = prefs.getInt('cc_win_streak') ?? 0;
      bestStreak = prefs.getInt('cc_best_streak') ?? 0;
      unlocked.addAll(prefs.getStringList('cc_achievements') ?? <String>[]);
      final raw = prefs.getString('cc_history');
      if (raw != null && raw.isNotEmpty) {
        final list = jsonDecode(raw) as List<dynamic>;
        history = list
            .map((e) => MatchRecord.fromJson(e as Map<String, dynamic>))
            .whereType<MatchRecord>()
            .toList();
      }
    } catch (_) {
      // Storage failed — keep memory-only values.
    }
    _loaded = true;
  }

  static Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('cc_lifetime_tiles', lifetimeTiles);
      await prefs.setInt('cc_lifetime_powerups', lifetimePowerUps);
      await prefs.setInt('cc_wins', wins);
      await prefs.setInt('cc_win_streak', winStreak);
      await prefs.setInt('cc_best_streak', bestStreak);
      await prefs.setStringList('cc_achievements', unlocked.toList());
      await prefs.setString(
          'cc_history',
          jsonEncode(history.map((r) => r.toJson()).toList()));
    } catch (_) {}
  }

  /// Record a finished match, update lifetime totals + streaks, evaluate
  /// achievements, pay newly unlocked rewards. Returns the ids of the
  /// achievements unlocked by this match (empty when none).
  static Future<List<String>> recordMatch({
    required String mode,
    required List<String> players,
    required String winner,
    required int durationSeconds,
    required List<int> tiles,
    required List<int> powerUps,
    required int coinsEarned,
    required bool won,
    required bool vsCrazyWin,
    required int playerCount,
    required bool suddenDeath,
  }) async {
    await load();
    var tilesTotal = 0;
    for (final t in tiles) {
      tilesTotal += t;
    }
    var powerUpsTotal = 0;
    for (final p in powerUps) {
      powerUpsTotal += p;
    }
    lifetimeTiles += tilesTotal;
    lifetimePowerUps += powerUpsTotal;
    if (won) {
      wins++;
      winStreak++;
      if (winStreak > bestStreak) bestStreak = winStreak;
    } else {
      winStreak = 0;
    }
    history.insert(
      0,
      MatchRecord(
        date: DateTime.now(),
        mode: mode,
        players: players,
        winner: winner,
        durationSeconds: durationSeconds,
        tiles: tiles,
        powerUps: powerUps,
        coinsEarned: coinsEarned,
        won: won,
      ),
    );
    if (history.length > 20) history.removeRange(20, history.length);

    final newly = <String>[];
    bool unlock(String id, bool condition) {
      if (condition && !unlocked.contains(id)) {
        unlocked.add(id);
        newly.add(id);
        return true;
      }
      return false;
    }

    unlock('first_win', wins >= 1);
    unlock('streak5', winStreak >= 5);
    unlock('tiles1000', lifetimeTiles >= 1000);
    unlock('powerups10', lifetimePowerUps >= 10);
    unlock('beat_crazy', vsCrazyWin);
    unlock('win_4p', won && playerCount >= 4);
    unlock('win_sudden', won && suddenDeath);
    await _save();
    for (final id in newly) {
      await CoinsService.addCoins(achievementById(id).reward);
    }
    return newly;
  }

  /// Daily reward: +50 coins once per calendar day. Returns the amount
  /// claimed (50) or 0 when already claimed today.
  static Future<int> claimDailyReward() async {
    await load();
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = DateTime.now();
      final key =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      if (prefs.getString('cc_daily_last') == key) return 0;
      await prefs.setString('cc_daily_last', key);
      await CoinsService.addCoins(50);
      return 50;
    } catch (_) {
      return 0;
    }
  }

  /// 0..1 progress for an achievement's progress bar.
  static double achievementProgress(String id) {
    switch (id) {
      case 'first_win':
        return wins >= 1 ? 1 : 0;
      case 'streak5':
        return (winStreak / 5).clamp(0.0, 1.0);
      case 'tiles1000':
        return (lifetimeTiles / 1000).clamp(0.0, 1.0);
      case 'powerups10':
        return (lifetimePowerUps / 10).clamp(0.0, 1.0);
      default:
        return unlocked.contains(id) ? 1 : 0;
    }
  }

  /// Short progress text, e.g. "3 / 5" or "740 / 1000".
  static String achievementProgressText(String id) {
    switch (id) {
      case 'streak5':
        return '$winStreak / 5';
      case 'tiles1000':
        return '$lifetimeTiles / 1000';
      case 'powerups10':
        return '$lifetimePowerUps / 10';
      default:
        return unlocked.contains(id) ? 'DONE' : 'LOCKED';
    }
  }
}
