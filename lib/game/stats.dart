// Color Cover — match history, lifetime stats, achievements, daily reward,
// streaks + ranks, bot ladder, daily missions, daily spin, daily challenge,
// personal bests, series wins. All local (shared_preferences), no login,
// no network. Every call is guarded: if storage fails, the game keeps
// working with memory only.
//
// Daily state is date-keyed: _ensureToday() re-keys/resets it whenever
// the calendar date changes, so nothing goes stale if the app stays open
// past midnight. RecordResult is the single payer for ALL match-end
// bonuses (achievements, streak milestones, combo, challenge, 7-day
// streak) — game_screen only pays the base win/play coins (50/10).
import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'coins.dart';
import '../data/game_data.dart';

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
  final int coinsEarned; // base win/play coins + all match-end bonuses
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

/// One streak-milestone reward paid by recordMatch.
class StreakMilestone {
  const StreakMilestone(this.label, this.coins);
  final String label; // e.g. 'STREAK x5'
  final int coins;
}

/// Everything recordMatch pays/announces for one finished match.
class RecordResult {
  RecordResult({
    required this.achievements,
    required this.streakMilestones,
    required this.comboBonus,
    required this.challengeBonus,
    required this.streak7Awarded,
    required this.botUnlockedNow,
    required this.totalCoins,
  });
  final List<String> achievements; // newly unlocked achievement ids
  final List<StreakMilestone> streakMilestones;
  final int comboBonus;
  final int challengeBonus;
  final bool streak7Awarded;
  final List<BotDifficulty> botUnlockedNow;
  final int totalCoins; // base coins + every bonus above
}

/// One daily mission. Progress is read from today's daily totals.
class DailyMissionDef {
  const DailyMissionDef(this.id, this.name, this.desc, this.reward);
  final String id;
  final String name;
  final String desc;
  final int reward;
}

/// A Daily Spin prize: coins, or a still-locked rare colour.
class SpinPrize {
  const SpinPrize.coins(this.coins)
      : colourKey = null,
        colourName = null;
  const SpinPrize.colour(this.colourKey, this.colourName) : coins = 0;
  final int coins;
  final String? colourKey;
  final String? colourName;
  bool get isColour => colourKey != null;
}

class StatsService {
  static List<MatchRecord> history = <MatchRecord>[];
  static int lifetimeTiles = 0;
  static int lifetimePowerUps = 0;
  static int wins = 0;
  static int winStreak = 0;
  static int bestStreak = 0;
  static final Set<String> unlocked = <String>{};
  static bool _loaded = false;

  // --- Replayability wave (v3.2) -----------------------------------------
  /// Bot ladder: difficulties unlocked by beating the previous one.
  /// Easy is always open; 'medium'/'crazy' are added when earned.
  static final Set<String> botUnlocked = <String>{};
  /// Rare colours unlocked (keys: kRareChampionGold / kRareStreakFlame).
  static final Set<String> colourUnlocked = <String>{};
  /// Streak milestones already paid ('s3', 's5', 's10').
  static final Set<String> streakMilestonesAwarded = <String>{};
  /// Dates (yyyy-MM-dd) with at least one finished match.
  static final Set<String> playDays = <String>{};
  /// Date of the last 7-day streak award (once per completed run).
  static String streak7AwardDay = '';
  static int seriesWins = 0; // best-of series won by Player 1
  static int bestTilesMatch = 0; // most tiles by one player in one match
  static int bestCombo = 0; // best combo of any match
  // Today's daily totals (reset by _ensureToday on date change).
  static int dailyTiles = 0;
  static int dailyPowerUps = 0;
  static int dailyWins = 0;
  static bool dailyMediumWin = false;
  static bool dailySuddenWin = false;
  static bool dailyChallengeWon = false;
  static bool spinDoneToday = false;
  static final Set<String> missionsClaimed = <String>{};
  static String _dailyDateKey = '';

  /// 'yyyy-MM-dd' for today (or [d]).
  static String dateKey([DateTime? d]) {
    final t = d ?? DateTime.now();
    return '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';
  }

  /// Day of year, 1..366. Dart has no DateTime.dayOfYear getter.
  static int dayOfYear([DateTime? d]) {
    final t = d ?? DateTime.now();
    return DateTime(t.year, t.month, t.day)
            .difference(DateTime(t.year, 1, 1))
            .inDays +
        1;
  }

  /// Today's special mode: deterministic by day of year.
  static ModePack get dailyChallengePack =>
      kModePacks[dayOfYear() % kModePacks.length];

  /// Rank from the current win streak.
  static String get rankName {
    if (winStreak >= 10) return 'Legend';
    if (winStreak >= 5) return 'Gold';
    if (winStreak >= 3) return 'Silver';
    return 'Bronze';
  }

  /// 'CHAMPION' title: earned by beating the computer on Crazy.
  static bool get isChampion => unlocked.contains('beat_crazy');

  /// Trailing CONSECUTIVE days played, ending today (or yesterday when
  /// today has no match yet). A loss still counts — this is a play
  /// streak, not a win streak.
  static int get playStreak {
    var streak = 0;
    var day = DateTime.now();
    if (!playDays.contains(dateKey(day))) {
      day = day.subtract(const Duration(days: 1));
    }
    while (playDays.contains(dateKey(day))) {
      streak++;
      day = day.subtract(const Duration(days: 1));
    }
    return streak;
  }

  static bool isBotUnlocked(BotDifficulty d) {
    if (d == BotDifficulty.easy) return true;
    if (d == BotDifficulty.medium) return botUnlocked.contains('medium');
    return botUnlocked.contains('crazy');
  }

  static bool isColourUnlocked(String key) => colourUnlocked.contains(key);

  static Future<void> load() async {
    if (_loaded) {
      // Already loaded — but the calendar date may have changed since,
      // so still re-key the daily state.
      await _ensureToday();
      return;
    }
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
      botUnlocked.addAll(prefs.getStringList('cc_bot_unlocked') ?? <String>[]);
      colourUnlocked
          .addAll(prefs.getStringList('cc_colours_unlocked') ?? <String>[]);
      streakMilestonesAwarded.addAll(
          prefs.getStringList('cc_streak_milestones') ?? <String>[]);
      playDays.addAll(prefs.getStringList('cc_play_days') ?? <String>[]);
      streak7AwardDay = prefs.getString('cc_streak7_day') ?? '';
      seriesWins = prefs.getInt('cc_series_wins') ?? 0;
      bestTilesMatch = prefs.getInt('cc_best_tiles') ?? 0;
      bestCombo = prefs.getInt('cc_best_combo') ?? 0;
      // Migration: a veteran who already earned 'Bot Slayer' keeps the
      // whole ladder — otherwise they would be locked out of Medium/Crazy
      // until re-beating Easy/Medium.
      if (unlocked.contains('beat_crazy')) {
        botUnlocked.add('medium');
        botUnlocked.add('crazy');
      }
    } catch (_) {
      // Storage failed — keep memory-only values.
    }
    _loaded = true;
    await _ensureToday();
  }

  /// Re-key daily state when the calendar date changed (e.g. the app
  /// stayed open past midnight). Daily counters/flags are stored under
  /// date-suffixed keys, so yesterday's values never leak into today.
  static Future<void> _ensureToday() async {
    final today = dateKey();
    if (_dailyDateKey == today) return;
    _dailyDateKey = today;
    dailyTiles = 0;
    dailyPowerUps = 0;
    dailyWins = 0;
    dailyMediumWin = false;
    dailySuddenWin = false;
    dailyChallengeWon = false;
    spinDoneToday = false;
    missionsClaimed.clear();
    try {
      final prefs = await SharedPreferences.getInstance();
      dailyTiles = prefs.getInt('cc_daily_tiles_$today') ?? 0;
      dailyPowerUps = prefs.getInt('cc_daily_powerups_$today') ?? 0;
      dailyWins = prefs.getInt('cc_daily_wins_$today') ?? 0;
      dailyMediumWin = prefs.getBool('cc_daily_medium_$today') ?? false;
      dailySuddenWin = prefs.getBool('cc_daily_sudden_$today') ?? false;
      dailyChallengeWon = prefs.getBool('cc_daily_challenge_$today') ?? false;
      spinDoneToday = prefs.getBool('cc_daily_spin_$today') ?? false;
      missionsClaimed.addAll(
          prefs.getStringList('cc_daily_missions_$today') ?? <String>[]);
    } catch (_) {}
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
      await prefs.setStringList('cc_bot_unlocked', botUnlocked.toList());
      await prefs.setStringList(
          'cc_colours_unlocked', colourUnlocked.toList());
      await prefs.setStringList(
          'cc_streak_milestones', streakMilestonesAwarded.toList());
      await prefs.setStringList('cc_play_days', playDays.toList());
      await prefs.setString('cc_streak7_day', streak7AwardDay);
      await prefs.setInt('cc_series_wins', seriesWins);
      await prefs.setInt('cc_best_tiles', bestTilesMatch);
      await prefs.setInt('cc_best_combo', bestCombo);
      final today = dateKey();
      await prefs.setInt('cc_daily_tiles_$today', dailyTiles);
      await prefs.setInt('cc_daily_powerups_$today', dailyPowerUps);
      await prefs.setInt('cc_daily_wins_$today', dailyWins);
      await prefs.setBool('cc_daily_medium_$today', dailyMediumWin);
      await prefs.setBool('cc_daily_sudden_$today', dailySuddenWin);
      await prefs.setBool('cc_daily_challenge_$today', dailyChallengeWon);
      await prefs.setBool('cc_daily_spin_$today', spinDoneToday);
      await prefs.setStringList(
          'cc_daily_missions_$today', missionsClaimed.toList());
    } catch (_) {}
  }

  // --- Daily missions -----------------------------------------------------
  /// Exactly 3 missions a day. The third rotates by day of year.
  static List<DailyMissionDef> missionsToday() {
    final rot = dayOfYear() % 3;
    final third = rot == 0
        ? const DailyMissionDef('m_medium', 'Beat Medium Bot',
            'Win a VS COMPUTER match on Medium.', 50)
        : rot == 1
            ? const DailyMissionDef('m_sudden', 'Sudden Death Winner',
                'Win a Sudden Death match.', 50)
            : const DailyMissionDef('m_tiles1000', 'Paint 1000 Tiles',
                'Paint 1000 tiles today.', 50);
    return <DailyMissionDef>[
      const DailyMissionDef(
          'm_tiles500', 'Paint 500 Tiles', 'Paint 500 tiles today.', 30),
      const DailyMissionDef('m_powerups5', 'Collect 5 Power-Ups',
          'Collect 5 power-ups today.', 30),
      third,
    ];
  }

  /// 0..1 progress for a mission (all missions use today's daily totals).
  static double missionProgress(String id) {
    switch (id) {
      case 'm_tiles500':
        return (dailyTiles / 500).clamp(0.0, 1.0);
      case 'm_powerups5':
        return (dailyPowerUps / 5).clamp(0.0, 1.0);
      case 'm_medium':
        return dailyMediumWin ? 1 : 0;
      case 'm_sudden':
        return dailySuddenWin ? 1 : 0;
      case 'm_tiles1000':
        return (dailyTiles / 1000).clamp(0.0, 1.0);
      default:
        return 0;
    }
  }

  static String missionProgressText(String id) {
    switch (id) {
      case 'm_tiles500':
        return '$dailyTiles / 500';
      case 'm_powerups5':
        return '$dailyPowerUps / 5';
      case 'm_medium':
        return dailyMediumWin ? 'DONE' : 'NOT YET';
      case 'm_sudden':
        return dailySuddenWin ? 'DONE' : 'NOT YET';
      case 'm_tiles1000':
        return '$dailyTiles / 1000';
      default:
        return '';
    }
  }

  static bool isMissionComplete(String id) => missionProgress(id) >= 1.0;
  static bool isMissionClaimed(String id) => missionsClaimed.contains(id);

  /// Claim a completed mission's coins (once per day). Returns the coins
  /// paid (0 when not complete or already claimed).
  static Future<int> claimMission(String id) async {
    await load();
    await _ensureToday();
    DailyMissionDef? def;
    for (final m in missionsToday()) {
      if (m.id == id) def = m;
    }
    if (def == null) return 0;
    if (!isMissionComplete(id) || isMissionClaimed(id)) return 0;
    missionsClaimed.add(id);
    await _save();
    await CoinsService.addCoins(def.reward);
    return def.reward;
  }

  // --- Daily spin ---------------------------------------------------------
  /// One free spin per day. 25% chance of a still-locked rare colour
  /// (when any remain), otherwise +20 / +50 / +100 coins. Returns null
  /// when already spun today.
  static Future<SpinPrize?> claimSpin() async {
    await load();
    await _ensureToday();
    if (spinDoneToday) return null;
    spinDoneToday = true;
    final locked = <String>[];
    if (!colourUnlocked.contains(kRareChampionGold)) {
      locked.add(kRareChampionGold);
    }
    if (!colourUnlocked.contains(kRareStreakFlame)) {
      locked.add(kRareStreakFlame);
    }
    final rng = Random();
    SpinPrize prize;
    if (locked.isNotEmpty && rng.nextDouble() < 0.25) {
      final key = locked[rng.nextInt(locked.length)];
      colourUnlocked.add(key);
      prize = SpinPrize.colour(
          key, key == kRareChampionGold ? 'Champion Gold' : 'Streak Flame');
    } else {
      final coins = <int>[20, 50, 100][rng.nextInt(3)];
      await CoinsService.addCoins(coins);
      prize = SpinPrize.coins(coins);
    }
    await _save();
    return prize;
  }

  /// Record a decided best-of series won by Player 1.
  static Future<void> recordSeriesWin(bool won) async {
    await load();
    if (!won) return;
    seriesWins++;
    await _save();
  }

  /// Record a finished match, update lifetime + daily totals, streaks,
  /// ladder, missions and bests, evaluate achievements, and pay EVERY
  /// match-end bonus (this is the single payer — game_screen only pays
  /// the base win/play coins). Returns what was earned/announced.
  static Future<RecordResult> recordMatch({
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
    BotDifficulty? botDifficulty,
    int bestCombo = 0,
    bool wonDailyChallenge = false,
  }) async {
    await load();
    await _ensureToday();
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
    dailyTiles += tilesTotal;
    dailyPowerUps += powerUpsTotal;
    if (won) {
      wins++;
      dailyWins++;
      winStreak++;
      if (winStreak > bestStreak) bestStreak = winStreak;
    } else {
      winStreak = 0;
    }
    if (won && botDifficulty == BotDifficulty.medium) dailyMediumWin = true;
    if (won && suddenDeath) dailySuddenWin = true;
    playDays.add(dateKey());
    var matchBestTiles = 0;
    for (final t in tiles) {
      if (t > matchBestTiles) matchBestTiles = t;
    }
    if (matchBestTiles > bestTilesMatch) bestTilesMatch = matchBestTiles;
    if (bestCombo > StatsService.bestCombo) {
      StatsService.bestCombo = bestCombo;
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
        coinsEarned: coinsEarned, // replaced with the total below
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
    var achievementCoins = 0;
    for (final id in newly) {
      achievementCoins += achievementById(id).reward;
    }
    if (achievementCoins > 0) {
      await CoinsService.addCoins(achievementCoins);
    }

    // Bot ladder: beating a difficulty unlocks the next one.
    final botUnlockedNow = <BotDifficulty>[];
    if (won && botDifficulty == BotDifficulty.easy &&
        !botUnlocked.contains('medium')) {
      botUnlocked.add('medium');
      botUnlockedNow.add(BotDifficulty.medium);
    }
    if (won && botDifficulty == BotDifficulty.medium &&
        !botUnlocked.contains('crazy')) {
      botUnlocked.add('crazy');
      botUnlockedNow.add(BotDifficulty.crazy);
    }
    // Rare colour: beating Crazy unlocks Champion Gold.
    if (vsCrazyWin && !colourUnlocked.contains(kRareChampionGold)) {
      colourUnlocked.add(kRareChampionGold);
    }

    // Win-streak milestones: paid ONCE each when first reached.
    // (The 'On Fire' achievement also pays +100 at streak 5 — that is a
    // separate badge reward, so streak 5 pays +200 in total.)
    const milestoneTable = <(int, int)>[(3, 50), (5, 100), (10, 200)];
    final milestones = <StreakMilestone>[];
    var milestoneCoins = 0;
    if (won) {
      for (final (threshold, reward) in milestoneTable) {
        if (winStreak >= threshold &&
            !streakMilestonesAwarded.contains('s$threshold')) {
          streakMilestonesAwarded.add('s$threshold');
          milestones.add(StreakMilestone('STREAK x$threshold', reward));
          milestoneCoins += reward;
        }
      }
      if (milestoneCoins > 0) {
        await CoinsService.addCoins(milestoneCoins);
      }
    }

    // Combo bonus: best combo x2, capped at 100 (an uncapped combo
    // would pay hundreds of coins per match).
    final comboBonus = (bestCombo * 2).clamp(0, 100);
    if (comboBonus > 0) await CoinsService.addCoins(comboBonus);

    // Daily challenge: +100 once per day.
    var challengeBonus = 0;
    if (wonDailyChallenge && !dailyChallengeWon) {
      dailyChallengeWon = true;
      challengeBonus = 100;
      await CoinsService.addCoins(100);
    }

    // 7-day streak: +300 coins + Streak Flame, once per completed run.
    var streak7Awarded = false;
    if (playStreak >= 7 && streak7AwardDay != dateKey()) {
      streak7AwardDay = dateKey();
      streak7Awarded = true;
      colourUnlocked.add(kRareStreakFlame);
      await CoinsService.addCoins(300);
    }

    final totalCoins = coinsEarned +
        achievementCoins +
        milestoneCoins +
        comboBonus +
        challengeBonus +
        (streak7Awarded ? 300 : 0);
    // History shows the real total earned for the match.
    history[0] = MatchRecord(
      date: history[0].date,
      mode: history[0].mode,
      players: history[0].players,
      winner: history[0].winner,
      durationSeconds: history[0].durationSeconds,
      tiles: history[0].tiles,
      powerUps: history[0].powerUps,
      coinsEarned: totalCoins,
      won: history[0].won,
    );
    await _save();
    return RecordResult(
      achievements: newly,
      streakMilestones: milestones,
      comboBonus: comboBonus,
      challengeBonus: challengeBonus,
      streak7Awarded: streak7Awarded,
      botUnlockedNow: botUnlockedNow,
      totalCoins: totalCoins,
    );
  }

  /// Daily reward: +50 coins once per calendar day. Returns the amount
  /// claimed (50) or 0 when already claimed today.
  static Future<int> claimDailyReward() async {
    await load();
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = dateKey();
      final key = 'cc_daily_last';
      if (prefs.getString(key) == today) return 0;
      await prefs.setString(key, today);
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
