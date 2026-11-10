// Color Cover — game engine (pure logic, no widgets).
// Grid: 18 columns x 24 rows (reference arena is 3:4). Balls move in tile
// coordinates, bounce off walls, paint tiles they cross. Match length:
// 90 seconds. Modes (see Modes screen): Ultimate Meter/Tsunami, Bomb Ball,
// Golden Tile, Sudden Death shrinking, Chaos Events, Team 2v2, Battle
// Royale, VS COMPUTER. Flags come from MatchConfig.pack — All Chaos
// enables 1-5.
import 'dart:math';
import '../data/game_data.dart';
import 'match_theme.dart';

class PowerUpOnField {
  PowerUpOnField(this.col, this.row, this.def, {this.mystery = false});
  int col; // mutable: MAGNET pulls power-up tiles across the arena.
  int row;
  final PowerUpDef def;
  /// Mystery tile: a purple gift box — the hidden power is re-rolled at
  /// pickup, so the reveal is always a surprise.
  final bool mystery;
}

/// One stacked power-up banner (reference: newest on top, ~2-4 s visible).
/// [effect] is the one-line "what it does" shown under the name; empty
/// for banners that have no effect line (e.g. CHAOS, eliminations).
class MatchBanner {
  MatchBanner(this.player, this.text, this.until, [this.effect = '']);
  final int player;
  final String text;
  final double until;
  final String effect;
}

class BallState {
  BallState({required this.player, required this.x, required this.y, required this.angle});
  final int player;
  double x;
  double y;
  double angle;
  double speedUntil = 0;
  double nitroUntil = 0;
  double wreckingUntil = 0;
  double colossusUntil = 0;
  double ghostUntil = 0;
  double blackHoleUntil = 0;
  double infiltratorUntil = 0;
  double doublePaintUntil = 0;
  double magnetUntil = 0; // MAGNET: pulls nearby power-up tiles to this ball.
  /// TRINITY extras: engine time when this ball disappears (0 = permanent).
  /// Only the two extra balls ever carry a value; the original never does.
  double removeAt = 0;
  final List<Point<double>> trail = <Point<double>>[];
}

/// A placed TURRET: a stationary auto-painter owned by one player.
/// Lives on one tile for 10 s; every 0.8 s it paints a random enemy tile
/// within radius 5. One per player — re-pickup stays put, timer refreshes.
class Turret {
  Turret(
      {required this.player,
      required this.col,
      required this.row,
      required this.until,
      required this.nextShotAt});
  final int player;
  final int col;
  final int row;
  double until;
  double nextShotAt;
  double aimAngle = 0; // barrel direction (radians, east = 0).
  Point<int>? shotTarget; // last fired-at tile, for the tracer line.
  double shotUntil = 0; // tracer visible while time < shotUntil.
}

class GameEngine {
  GameEngine(this.config)
      : players = config.players,
        cols = 18,
        rows = 24,
        // TIME ATTACK is a 60-second blitz; every other mode is 90 seconds.
        matchSeconds = config.pack == ModePack.timeAttack ? 60 : 90 {
    grid = List<int>.filled(cols * rows, -1);
    paintTime = List<double>.filled(cols * rows, -1000);
    playable = List<bool>.filled(cols * rows, true);
    ultimateMeters = List<double>.filled(players.length, 0);
    tilesPainted = List<int>.filled(players.length, 0);
    powerUpsCollected = List<int>.filled(players.length, 0);
    combo = List<int>.filled(players.length, 0);
    bestCombo = List<int>.filled(players.length, 0);
    lastPaintTime = List<double>.filled(players.length, -1000);
    timeLeft = matchSeconds.toDouble();
    _initPlayable();
    _initTerritory();
    _initBalls();
    if (goldenEnabled) _placeGoldenTile();
  }

  final MatchConfig config;
  final List<PlayerConfig> players;
  final int cols;
  final int rows;
  final int matchSeconds;

  bool get isTimeAttack => pack == ModePack.timeAttack;

  GameMode get mode => config.mode;
  ModePack get pack => config.pack;
  bool get ultimateEnabled => pack == ModePack.ultimate || pack == ModePack.allChaos;
  bool get bombEnabled => pack == ModePack.bomb || pack == ModePack.allChaos;
  bool get goldenEnabled => pack == ModePack.golden || pack == ModePack.allChaos;
  bool get suddenDeathEnabled => pack == ModePack.suddenDeath || pack == ModePack.allChaos;
  bool get chaosEnabled => pack == ModePack.chaos || pack == ModePack.allChaos;
  bool get isTeam => mode == GameMode.team2v2;
  bool get isBattleRoyale => mode == GameMode.battleRoyale;
  bool get isVsBot => mode == GameMode.vsBot;

  late List<int> grid; // owner, -1 empty, -2 dead (outside shape / shrunk)
  late List<double> paintTime;
  late List<bool> playable;
  late List<BallState> balls;
  late List<double> ultimateMeters; // 0..100 per player
  final List<PowerUpOnField> powerUps = <PowerUpOnField>[];
  final Random _rng = Random();

  /// Live turrets (at most one per player). Painter reads this list.
  final List<Turret> turrets = <Turret>[];

  double time = 0;
  late double timeLeft;
  double _spawnTimer = 6;
  bool finished = false;

  /// Match stats (for the end card + History + Achievements).
  late List<int> tilesPainted; // tiles each player painted this match.
  late List<int> powerUpsCollected; // power-ups each player collected.
  int biggestLead = 0; // biggest tile-count gap between 1st and 2nd.

  /// Combo: consecutive tiles painted with gaps under 2 seconds. A
  /// FREEZE breaks it (a frozen ball does not paint). Best combo is the
  /// max over all players — that is what the end-card bonus pays on.
  late List<int> combo;
  late List<int> bestCombo;
  late List<double> lastPaintTime;
  int get matchBestCombo =>
      bestCombo.isEmpty ? 0 : bestCombo.reduce((a, b) => a > b ? a : b);

  /// Players trailing the leader by 40+ tiles get +15% speed (comeback).
  /// Computed once per step, before the ball loop. Per-player, not
  /// per-team: in Team 2v2 a player trailing individually while their
  /// team leads still gets the boost.
  final Set<int> comebackPlayers = <int>{};

  /// Active power-up banners (reference stacks up to 4 at once, newest on
  /// top). Each entry: (player, text, visible-until time).
  final List<MatchBanner> banners = <MatchBanner>[];
  // Backwards-compatible single-banner view: the newest active banner.
  String get bannerText => banners.isEmpty ? '' : banners.last.text;
  double get bannerUntil => banners.isEmpty ? 0 : banners.last.until;
  int get bannerPlayer => banners.isEmpty ? 0 : banners.last.player;

  /// Tiles the engine just marked (e.g. a Wormhole portal block) that the
  /// painter draws dark with a "+" while [wormholeUntil] has not passed.
  final Set<int> wormholeTiles = <int>{};
  double wormholeUntil = 0;
  final Map<int, Point<double>> steering = <int, Point<double>>{};
  final List<double> fortifyUntil = <double>[0, 0, 0, 0];
  // FREEZE: until when each player's ball is frozen (enemy balls only).
  final List<double> frozenUntil = <double>[0, 0, 0, 0];
  // MAGNET pull is applied every 0.15 s, not every frame.
  double _magnetTimer = 0;

  // Golden Tile (centre of the arena).
  int goldenCol = -1;
  int goldenRow = -1;
  bool goldenVisible = false;
  double _goldenRespawnAt = 0;

  // Sudden Death.
  int shrinkLevel = 0;

  // Chaos Events.
  String chaosName = '';
  double chaosUntil = 0;
  double iceUntil = 0;
  double fireUntil = 0;
  double _chaosTimer = 20;
  int _chaosIndex = 0;
  double _fireTimer = 0;
  static const List<String> _chaosCycle = ['EARTHQUAKE', 'ICE', 'FIRE'];

  // Battle Royale.
  final Set<int> eliminated = <int>{};
  double _nextEliminationAt = 30;

  int teamOf(int player) => isTeam ? (player == 0 || player == 2 ? 0 : 1) : player;

  bool isPlayableTile(int c, int r) {
    if (c < 0 || c >= cols || r < 0 || r >= rows) return false;
    if (!playable[tileIndex(c, r)]) return false;
    if (suddenDeathEnabled && shrinkLevel > 0) {
      if (c < shrinkLevel || c >= cols - shrinkLevel) return false;
      if (r < shrinkLevel || r >= rows - shrinkLevel) return false;
    }
    return true;
  }

  void _initPlayable() {
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final nx = (c + 0.5) / cols * 2 - 1; // -1..1
        final ny = (r + 0.5) / rows * 2 - 1;
        var ok = true;
        switch (config.arenaShape) {
          case ArenaShape.rectangle:
            ok = true;
            break;
          case ArenaShape.circle:
            ok = (nx * nx + ny * ny) <= 1.0;
            break;
          case ArenaShape.heart:
            final x = nx * 1.1;
            final y = -ny;
            ok = ((x * x + y * y - 1) * (x * x + y * y - 1) * (x * x + y * y - 1) -
                    x * x * y * y * y) <=
                0;
            break;
          case ArenaShape.star:
            final ang = atan2(ny, nx);
            final dist = sqrt(nx * nx + ny * ny);
            final starR = 0.55 + 0.45 * cos(ang * 5);
            ok = dist <= starR;
            break;
          case ArenaShape.maze:
            // Walls: every 4th row/column is blocked, with gaps.
            final wallRow = r % 4 == 2 && c % 5 != 2;
            final wallCol = c % 5 == 2 && r % 4 != 2;
            ok = !(wallRow || wallCol);
            break;
        }
        playable[tileIndex(c, r)] = ok;
      }
    }
  }

  void _initTerritory() {
    final n = players.length;
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final idx = tileIndex(c, r);
        if (!playable[idx]) {
          grid[idx] = -2;
          continue;
        }
        int owner;
        if (n == 2) {
          owner = c < cols ~/ 2 ? 0 : 1;
        } else if (n == 3) {
          owner = c < cols ~/ 3 ? 0 : (c < 2 * cols ~/ 3 ? 1 : 2);
        } else {
          final top = r < rows ~/ 2;
          final left = c < cols ~/ 2;
          owner = top ? (left ? 0 : 1) : (left ? 2 : 3);
        }
        grid[idx] = owner;
        paintTime[idx] = 0;
      }
    }
  }

  void _initBalls() {
    balls = <BallState>[];
    final starts = <Point<double>>[
      Point(cols * 0.25, rows * 0.5),
      Point(cols * 0.75, rows * 0.5),
      Point(cols * 0.5, rows * 0.25),
      Point(cols * 0.75, rows * 0.75),
    ];
    if (players.length == 3) starts[2] = Point(cols * 0.83, rows * 0.5);
    if (players.length == 4) {
      starts[0] = Point(cols * 0.25, rows * 0.25);
      starts[1] = Point(cols * 0.75, rows * 0.25);
      starts[2] = Point(cols * 0.25, rows * 0.75);
      starts[3] = Point(cols * 0.75, rows * 0.75);
    }
    for (var i = 0; i < players.length; i++) {
      balls.add(BallState(player: i, x: starts[i].x, y: starts[i].y, angle: (i * 1.9) + 0.6));
    }
  }

  int tileIndex(int c, int r) => r * cols + c;

  List<int> tileCounts() {
    final counts = List<int>.filled(players.length, 0);
    for (final owner in grid) {
      if (owner >= 0 && owner < counts.length) counts[owner]++;
    }
    return counts;
  }

  List<double> percentages() {
    final counts = tileCounts();
    var total = 0;
    for (var i = 0; i < playable.length; i++) {
      if (playable[i] && isPlayableTile(i % cols, i ~/ cols)) total++;
    }
    if (total == 0) total = 1;
    return counts.map((c) => c * 100.0 / total).toList();
  }

  /// Team percentages: [team A, team B] for Team 2v2, else per-player.
  List<double> teamPercentages() {
    if (!isTeam) return percentages();
    final p = percentages();
    return [p[0] + p[2], p[1] + p[3]];
  }

  int winnerIndex() {
    if (isTeam) {
      final t = teamPercentages();
      final winningTeam = t[0] >= t[1] ? 0 : 1;
      final counts = tileCounts();
      var best = winningTeam == 0 ? 0 : 1;
      for (var i = 0; i < players.length; i++) {
        if (teamOf(i) == winningTeam && counts[i] > counts[best]) best = i;
      }
      return best;
    }
    if (isBattleRoyale && eliminated.isNotEmpty) {
      for (var i = 0; i < players.length; i++) {
        if (!eliminated.contains(i)) return i;
      }
    }
    final counts = tileCounts();
    var best = 0;
    for (var i = 1; i < counts.length; i++) {
      if (counts[i] > counts[best]) best = i;
    }
    return best;
  }

  String winnerLabel() {
    if (isTeam) {
      final t = teamPercentages();
      return t[0] >= t[1] ? 'TEAM A DOMINATES!' : 'TEAM B DOMINATES!';
    }
    return '${players[winnerIndex()].name.toUpperCase()} DOMINATES!';
  }

  /// "1 minute 28 seconds" — the reference end-card duration line.
  String matchDurationLabel() => formatDuration(time);

  double _ballSpeed(BallState b) {
    var s = 7.0;
    if (b.speedUntil > time) s *= 1.33;
    if (b.nitroUntil > time) s *= 1.8;
    if (b.infiltratorUntil > time) s *= 1.15;
    if (iceUntil > time) s *= 1.4;
    // Comeback boost: trailing by 40+ tiles means +15% speed.
    if (comebackPlayers.contains(b.player)) s *= 1.15;
    if (isVsBot && b.player == 1) {
      if (config.botDifficulty == BotDifficulty.easy) s *= 0.85;
      if (config.botDifficulty == BotDifficulty.crazy) s *= 1.2;
    }
    return s;
  }

  double _ballRadius(BallState b) => b.colossusUntil > time ? 2.2 : 0.375;

  int _paintRadius(BallState b) {
    if (b.wreckingUntil > time || b.colossusUntil > time) return 2;
    if (b.infiltratorUntil > time || b.doublePaintUntil > time) return 2;
    return 1;
  }

  /// Is tile (c, r) occupied by a live turret? A turret's tile cannot be
  /// repainted while the turret lives — otherwise the painter would draw a
  /// turret on territory it no longer owns. Enforced centrally in _setTile
  /// plus the direct grid writers (Earthquake/Fire).
  bool _isTurretTile(int c, int r) => turrets.any((t) => t.col == c && t.row == r);
  bool _isTurretTileIdx(int idx) => _isTurretTile(idx % cols, idx ~/ cols);

  Turret? _turretOf(int player) {
    for (final t in turrets) {
      if (t.player == player) return t;
    }
    return null;
  }

  /// Paint one tile for [player] and count it for match stats.
  /// Chaos/Fire/Earthquake reassign tiles directly (environment, not
  /// player-painted) and do not go through here.
  /// Combo: every conversion extends the player's combo when the gap
  /// since their last conversion is under 2 seconds, else it restarts
  /// at 1. Bomb/Tidal/Tsunami also paint through here, so a big blast
  /// counts as a big combo — that is the reward for the blast.
  void _setTile(int idx, int player) {
    if (_isTurretTileIdx(idx)) return;
    if (grid[idx] == player) return;
    grid[idx] = player;
    paintTime[idx] = time;
    tilesPainted[player]++;
    final prev = combo[player];
    if (time - lastPaintTime[player] < 2.0) {
      combo[player]++;
    } else {
      combo[player] = 1;
    }
    lastPaintTime[player] = time;
    if (combo[player] > bestCombo[player]) bestCombo[player] = combo[player];
    // Milestone banners use a crossing check (prev < m <= new): a bomb
    // or tidal wave can jump past a value in one frame, and an exact
    // equality check would never fire.
    for (final m in [10, 25, 50]) {
      if (prev < m && combo[player] >= m) {
        _showBanner(player, 'COMBO x$m!', 'Keep painting — no gaps!');
      }
    }
  }

  void _paintAround(BallState b) {
    final radius = _paintRadius(b);
    final cc = b.x.round();
    final rr = b.y.round();
    for (var dr = -radius; dr <= radius; dr++) {
      for (var dc = -radius; dc <= radius; dc++) {
        if (dc * dc + dr * dr > radius * radius + 1) continue;
        final c = cc + dc;
        final r = rr + dr;
        if (!isPlayableTile(c, r)) continue;
        final idx = tileIndex(c, r);
        final owner = grid[idx];
        if (owner == b.player) continue;
        if (owner >= 0 && fortifyUntil[owner] > time) continue;
        _setTile(idx, b.player);
        if (ultimateEnabled) {
          ultimateMeters[b.player] =
              (ultimateMeters[b.player] + (b.doublePaintUntil > time ? 6 : 3)).clamp(0, 100);
        }
      }
    }
  }

  /// Color Tsunami: convert the ball's full row to this player's colour.
  /// Only works when the Ultimate Meter is full (100).
  bool tsunami(int player) {
    if (!ultimateEnabled) return false;
    if (ultimateMeters[player] < 100) return false;
    final ball = balls.firstWhere((b) => b.player == player, orElse: () => balls[0]);
    final rr = ball.y.round().clamp(0, rows - 1);
    for (var c = 0; c < cols; c++) {
      if (!isPlayableTile(c, rr)) continue;
      _setTile(tileIndex(c, rr), player);
    }
    ultimateMeters[player] = 0;
    _showBanner(player, 'COLOR TSUNAMI!', 'Whole row turns your colour');
    return true;
  }

  void _showBanner(int player, String text, [String effect = '']) {
    banners.add(MatchBanner(player, text, time + 3, effect));
    if (banners.length > 4) banners.removeAt(0);
  }

  /// Does the ball's disc overlap tile (col, row)? The ball radius is
  /// 0.375 tiles, so a ball rolling over the EDGE of a tile overlaps it
  /// long before its centre rounds onto it — the old centre-only check
  /// missed those pickups even though the tile was visibly touched.
  bool _ballOverlapsTile(BallState b, int col, int row) {
    final r = _ballRadius(b);
    final dx = (b.x - (col + 0.5)).abs() - 0.5;
    final dy = (b.y - (row + 0.5)).abs() - 0.5;
    final ox = dx > 0 ? dx : 0;
    final oy = dy > 0 ? dy : 0;
    return ox * ox + oy * oy < r * r;
  }

  void _placeGoldenTile() {
    goldenCol = cols ~/ 2;
    goldenRow = rows ~/ 2;
    if (!isPlayableTile(goldenCol, goldenRow)) {
      goldenCol = cols ~/ 2;
      goldenRow = rows ~/ 2 - 2;
    }
    goldenVisible = true;
  }

  void _explodeBomb(BallState b) {
    final cc = b.x.round();
    final rr = b.y.round();
    for (var dr = -2; dr <= 2; dr++) {
      for (var dc = -2; dc <= 2; dc++) {
        final c = cc + dc;
        final r = rr + dr;
        if (!isPlayableTile(c, r)) continue;
        final idx = tileIndex(c, r);
        if (grid[idx] >= 0 && fortifyUntil[grid[idx]] > time) continue;
        _setTile(idx, b.player);
      }
    }
  }

  void _applyPowerUp(BallState b, PowerUpDef def) {
    powerUpsCollected[b.player]++;
    _showBanner(b.player, def.name, def.effect);
    switch (def.id) {
      case 'speed':
        b.speedUntil = time + 10;
        break;
      case 'nitro':
        b.nitroUntil = time + 8;
        break;
      case 'wrecking':
        b.wreckingUntil = time + 10;
        break;
      case 'colossus':
        b.colossusUntil = time + 10;
        break;
      case 'fortify':
        fortifyUntil[b.player] = time + 10;
        break;
      case 'infiltrator':
        b.infiltratorUntil = time + 10;
        break;
      case 'ghost':
        b.ghostUntil = time + 8;
        break;
      case 'blackhole':
        b.blackHoleUntil = time + 5;
        break;
      case 'bomb':
        _explodeBomb(b);
        break;
      case 'freeze':
        // FREEZE: every enemy ball stops moving for 3 seconds.
        for (var i = 0; i < players.length; i++) {
          if (i != b.player) frozenUntil[i] = time + 3;
        }
        break;
      case 'magnet':
        // MAGNET: nearby power-up tiles drift to this ball for 8 seconds.
        b.magnetUntil = time + 8;
        break;
      case 'trinity':
        // TRINITY: two extra balls for 10 s. Re-pickup refreshes the
        // timer and tops up to 2 extras (never stacks to 4). Extras
        // inherit the collector's active timed buffs at spawn, so a
        // ghost collector's extras pass through balls too.
        final liveExtras = balls
            .where((e) => e.player == b.player && e.removeAt > time)
            .toList();
        for (final e in liveExtras) {
          e.removeAt = time + 10;
        }
        final missing = 2 - liveExtras.length;
        for (var i = 0; i < missing; i++) {
          final spread = i == 0 ? -0.7 : 0.7; // ±40° from the collector.
          final extra = BallState(
              player: b.player, x: b.x, y: b.y, angle: b.angle + spread);
          extra.removeAt = time + 10;
          extra.speedUntil = b.speedUntil;
          extra.nitroUntil = b.nitroUntil;
          extra.wreckingUntil = b.wreckingUntil;
          extra.colossusUntil = b.colossusUntil;
          extra.ghostUntil = b.ghostUntil;
          extra.blackHoleUntil = b.blackHoleUntil;
          extra.infiltratorUntil = b.infiltratorUntil;
          extra.doublePaintUntil = b.doublePaintUntil;
          extra.magnetUntil = b.magnetUntil;
          balls.add(extra);
        }
        break;
      case 'turret':
        // TURRET: a stationary auto-painter on the pickup tile for 10 s.
        // One per player; re-pickup stays put and refreshes the timer.
        final existing = _turretOf(b.player);
        if (existing != null) {
          existing.until = time + 10;
        } else {
          turrets.add(Turret(
            player: b.player,
            col: b.x.round().clamp(0, cols - 1),
            row: b.y.round().clamp(0, rows - 1),
            until: time + 10,
            nextShotAt: time + 0.8,
          ));
        }
        break;
      case 'tidal':
        final cc = b.x.round().clamp(0, cols - 1);
        final rr = b.y.round().clamp(0, rows - 1);
        for (var c = 0; c < cols; c++) {
          if (!isPlayableTile(c, rr)) continue;
          final idx = tileIndex(c, rr);
          if (grid[idx] != b.player && !(grid[idx] >= 0 && fortifyUntil[grid[idx]] > time)) {
            _setTile(idx, b.player);
          }
        }
        for (var r = 0; r < rows; r++) {
          if (!isPlayableTile(cc, r)) continue;
          final idx = tileIndex(cc, r);
          if (grid[idx] != b.player && !(grid[idx] >= 0 && fortifyUntil[grid[idx]] > time)) {
            _setTile(idx, b.player);
          }
        }
        break;
      case 'wormhole':
        // Teleport to a random tile and mark a 2x4 portal block there
        // (reference draws it as dark tiles with "+" marks).
        b.x = _rng.nextInt(cols).toDouble() + 0.5;
        b.y = _rng.nextInt(rows).toDouble() + 0.5;
        b.trail.clear();
        wormholeTiles.clear();
        final bx = (b.x.round() - 1).clamp(0, cols - 2);
        final by = (b.y.round() - 2).clamp(0, rows - 4);
        for (var r = by; r < by + 4; r++) {
          for (var c = bx; c < bx + 2; c++) {
            wormholeTiles.add(tileIndex(c, r));
          }
        }
        wormholeUntil = time + 3;
        break;
    }
  }

  void _spawnPowerUp() {
    if (powerUps.length >= 3) return;
    PowerUpDef def;
    if (bombEnabled && _rng.nextDouble() < 0.5) {
      def = powerUpById('bomb');
    } else {
      def = kPowerUps[_rng.nextInt(kPowerUps.length)];
    }
    // Mystery tile: 15% of spawns hide their power behind a gift box.
    // The stored def is only a placeholder — the real power is re-rolled
    // at pickup, so the reveal is always a surprise.
    final mystery = _rng.nextDouble() < 0.15;
    var c = _rng.nextInt(cols);
    var r = _rng.nextInt(rows);
    for (var tries = 0; tries < 12; tries++) {
      if (isPlayableTile(c, r) &&
          !_isTurretTile(c, r) &&
          !powerUps.any((p) => p.col == c && p.row == r)) break;
      c = _rng.nextInt(cols);
      r = _rng.nextInt(rows);
    }
    if (!isPlayableTile(c, r) || _isTurretTile(c, r)) return;
    powerUps.add(PowerUpOnField(c, r, def, mystery: mystery));
  }

  void _runChaosEvent() {
    final name = _chaosCycle[_chaosIndex % _chaosCycle.length];
    _chaosIndex++;
    chaosName = name;
    chaosUntil = time + 10;
    _showBanner(0, 'CHAOS: $name!');
    if (name == 'EARTHQUAKE') {
      // Shuffle about 15% of the tiles to a random player.
      for (var i = 0; i < grid.length; i++) {
        if (!playable[i] || grid[i] < 0) continue;
        if (_isTurretTileIdx(i)) continue;
        if (_rng.nextDouble() < 0.15) {
          grid[i] = _rng.nextInt(players.length);
          paintTime[i] = time;
        }
      }
    } else if (name == 'ICE') {
      iceUntil = time + 10;
    } else if (name == 'FIRE') {
      fireUntil = time + 10;
    }
  }

  void _botSteer(BallState b) {
    // Simple AI: aim at the nearest power-up, else the nearest enemy tile.
    double tx = b.x;
    double ty = b.y;
    if (powerUps.isNotEmpty) {
      var best = 1e9;
      for (final p in powerUps) {
        final d = (p.col - b.x) * (p.col - b.x) + (p.row - b.y) * (p.row - b.y);
        if (d < best) {
          best = d;
          tx = p.col.toDouble();
          ty = p.row.toDouble();
        }
      }
    } else {
      // Scan for the nearest tile that is not ours.
      var best = 1e9;
      for (var r = 0; r < rows; r += 2) {
        for (var c = 0; c < cols; c += 2) {
          if (!isPlayableTile(c, r) || grid[tileIndex(c, r)] == b.player) continue;
          final d = (c - b.x) * (c - b.x) + (r - b.y) * (r - b.y);
          if (d < best) {
            best = d;
            tx = c.toDouble();
            ty = r.toDouble();
          }
        }
      }
    }
    final target = atan2(ty - b.y, tx - b.x);
    if (config.botDifficulty == BotDifficulty.easy) {
      // Easy bot turns slowly and sometimes wanders.
      b.angle += (target - b.angle) * 0.05;
      if (_rng.nextDouble() < 0.01) b.angle += _rng.nextDouble() - 0.5;
    } else if (config.botDifficulty == BotDifficulty.crazy) {
      b.angle = target;
    } else {
      b.angle += (target - b.angle) * 0.2;
    }
  }

  void step(double dt) {
    if (finished) return;
    time += dt;
    timeLeft = (matchSeconds - time).clamp(0, matchSeconds.toDouble());
    if (timeLeft <= 0) {
      finished = true;
      return;
    }

    // Drop expired banners (and expired wormhole marks).
    banners.removeWhere((b) => time >= b.until);
    if (time >= wormholeUntil) wormholeTiles.clear();
    // Drop expired turrets and expired TRINITY extra balls (originals
    // have removeAt 0 and are never removed here).
    turrets.removeWhere((t) => time >= t.until);
    balls.removeWhere((b) => b.removeAt > 0 && time >= b.removeAt);

    // Sudden Death: last 10 seconds, arena shrinks one ring at a time.
    if (suddenDeathEnabled && timeLeft <= 10) {
      shrinkLevel = ((10 - timeLeft) / 3).ceil().clamp(0, 3);
      // A turret whose tile shrank into the dead ring is destroyed.
      turrets.removeWhere((t) => !isPlayableTile(t.col, t.row));
    }

    // Chaos Events every 20 seconds.
    if (chaosEnabled) {
      _chaosTimer -= dt;
      if (_chaosTimer <= 0) {
        _runChaosEvent();
        _chaosTimer = 20;
      }
      if (fireUntil > time) {
        _fireTimer -= dt;
        if (_fireTimer <= 0) {
          _fireTimer = 0.5;
          for (var i = 0; i < 3; i++) {
            final idx = _rng.nextInt(grid.length);
            if (_isTurretTileIdx(idx)) continue;
            if (playable[idx] && grid[idx] >= 0 && isPlayableTile(idx % cols, idx ~/ cols)) {
              // FIRE converts tiles to a random player — the reference has
              // no unpainted tiles, so tiles are never set to -1.
              grid[idx] = _rng.nextInt(players.length);
              paintTime[idx] = time;
            }
          }
        }
      }
    }

    // Battle Royale: eliminate the lowest player every 30 seconds.
    if (isBattleRoyale && time >= _nextEliminationAt) {
      _nextEliminationAt += 30;
      final counts = tileCounts();
      var lowest = -1;
      for (var i = 0; i < players.length; i++) {
        if (eliminated.contains(i)) continue;
        if (lowest < 0 || counts[i] < counts[lowest]) lowest = i;
      }
      if (lowest >= 0) {
        eliminated.add(lowest);
        balls.removeWhere((b) => b.player == lowest);
        turrets.removeWhere((t) => t.player == lowest);
        // The eliminated player's tiles go to the current leader — the
        // reference has no unpainted tiles, so tiles are never set to -1.
        final aliveCounts = tileCounts();
        var leader = -1;
        for (var i = 0; i < players.length; i++) {
          if (eliminated.contains(i)) continue;
          if (leader < 0 || aliveCounts[i] > aliveCounts[leader]) leader = i;
        }
        if (leader < 0) leader = 0;
        for (var i = 0; i < grid.length; i++) {
          if (grid[i] == lowest) grid[i] = leader;
        }
        _showBanner(lowest, '${players[lowest].name.toUpperCase()} IS OUT!');
        final alive = players.length - eliminated.length;
        if (alive <= 1) {
          finished = true;
          return;
        }
      }
    }

    // Golden Tile respawn.
    if (goldenEnabled && !goldenVisible && time >= _goldenRespawnAt) {
      _placeGoldenTile();
    }

    _spawnTimer -= dt;
    if (_spawnTimer <= 0) {
      _spawnPowerUp();
      _spawnTimer = 6;
    }

    // MAGNET: every 0.15 s, power-up tiles near a magnet ball drift one
    // tile closer to it (Manhattan step, only within 6 tiles).
    _magnetTimer -= dt;
    if (_magnetTimer <= 0) {
      _magnetTimer = 0.15;
      for (final b in balls) {
        if (b.magnetUntil <= time) continue;
        for (final p in powerUps) {
          final dx = b.x.round() - p.col;
          final dy = b.y.round() - p.row;
          final dist = dx.abs() + dy.abs();
          if (dist > 6 || dist == 0) continue;
          if (dx != 0) p.col += dx.sign;
          if (dy != 0) p.row += dy.sign;
        }
      }
    }

    // TURRET: every 0.8 s each live turret fires at a random enemy tile
    // within Euclidean radius 5 — team-aware (never a teammate's tile),
    // playable, not fortified, not another turret's tile. nextShotAt
    // advances after EVERY attempt, so a turret with no target in range
    // retries 0.8 s later instead of stalling or machine-gunning.
    // Turrets fire even while their owner is frozen — they are automated.
    for (final t in List<Turret>.from(turrets)) {
      if (time < t.nextShotAt) continue;
      t.nextShotAt = time + 0.8;
      final candidates = <Point<int>>[];
      for (var r = t.row - 5; r <= t.row + 5; r++) {
        for (var c = t.col - 5; c <= t.col + 5; c++) {
          final dc = c - t.col;
          final dr = r - t.row;
          if (dc * dc + dr * dr > 25) continue;
          if (!isPlayableTile(c, r)) continue;
          if (_isTurretTile(c, r)) continue;
          final idx = tileIndex(c, r);
          final owner = grid[idx];
          if (owner < 0) continue;
          if (teamOf(owner) == teamOf(t.player)) continue;
          if (fortifyUntil[owner] > time) continue;
          candidates.add(Point<int>(c, r));
        }
      }
      if (candidates.isEmpty) continue;
      final target = candidates[_rng.nextInt(candidates.length)];
      t.aimAngle = atan2(
          (target.y - t.row).toDouble(), (target.x - t.col).toDouble());
      t.shotTarget = target;
      t.shotUntil = time + 0.25;
      _setTile(tileIndex(target.x, target.y), t.player);
    }

    // Combo reset: a 2-second gap without painting ends the combo.
    // Comeback: players trailing the leader by 40+ tiles get +15%
    // speed (see _ballSpeed). Computed once per step, before the ball
    // loop, so every ball in the frame sees the same values.
    for (var i = 0; i < players.length; i++) {
      if (combo[i] > 0 && time - lastPaintTime[i] > 2.0) combo[i] = 0;
    }
    final stepCounts = tileCounts();
    var stepLeader = 0;
    for (var i = 1; i < stepCounts.length; i++) {
      if (stepCounts[i] > stepCounts[stepLeader]) stepLeader = i;
    }
    comebackPlayers.clear();
    for (var i = 0; i < stepCounts.length; i++) {
      if (i != stepLeader && stepCounts[stepLeader] - stepCounts[i] >= 40) {
        comebackPlayers.add(i);
      }
    }

    for (final b in List<BallState>.from(balls)) {
      if (isVsBot && b.player == 1) _botSteer(b);

      // FREEZE: a frozen ball does not move, paint or pick up anything.
      if (frozenUntil[b.player] > time) continue;

      for (final other in balls) {
        if (other == b) continue;
        if (other.blackHoleUntil > time) {
          final dx = other.x - b.x;
          final dy = other.y - b.y;
          final d = sqrt(dx * dx + dy * dy);
          if (d > 0.6) {
            b.x += dx / d * 2.0 * dt;
            b.y += dy / d * 2.0 * dt;
          }
        }
      }

      final steer = steering[b.player];
      if (steer != null && (steer.x.abs() > 0.2 || steer.y.abs() > 0.2)) {
        final target = atan2(steer.y, steer.x);
        if (iceUntil > time) {
          // Slippery ice: turn slowly.
          b.angle += (target - b.angle) * 0.12;
        } else {
          b.angle = target;
        }
      }

      final speed = _ballSpeed(b);
      b.x += cos(b.angle) * speed * dt;
      b.y += sin(b.angle) * speed * dt;

      final rad = _ballRadius(b);
      final minX = (suddenDeathEnabled ? shrinkLevel : 0) + rad;
      final maxX = cols - (suddenDeathEnabled ? shrinkLevel : 0) - rad;
      final minY = (suddenDeathEnabled ? shrinkLevel : 0) + rad;
      final maxY = rows - (suddenDeathEnabled ? shrinkLevel : 0) - rad;
      if (b.x < minX) {
        b.x = minX;
        b.angle = pi - b.angle;
      }
      if (b.x > maxX) {
        b.x = maxX;
        b.angle = pi - b.angle;
      }
      if (b.y < minY) {
        b.y = minY;
        b.angle = -b.angle;
      }
      if (b.y > maxY) {
        b.y = maxY;
        b.angle = -b.angle;
      }

      b.trail.add(Point(b.x, b.y));
      if (b.trail.length > 14) b.trail.removeAt(0);

      _paintAround(b);

      // Golden Tile: first ball to touch it gets double paint for 10s.
      // Overlap, not centre-only — same fix as power-up pickup.
      if (goldenEnabled && goldenVisible) {
        if (_ballOverlapsTile(b, goldenCol, goldenRow)) {
          goldenVisible = false;
          _goldenRespawnAt = time + 20;
          b.doublePaintUntil = time + 10;
          _showBanner(b.player, 'GOLDEN TILE!', 'Double paint for 10 seconds');
        }
      }

      // Power-up pickup: collect every power-up tile the ball's disc
      // overlaps (a ball can graze two adjacent tiles in one frame).
      // A mystery tile re-rolls its power at pickup — uniform over all
      // 13, with no bomb bias, so the reveal is a real surprise.
      for (var i = powerUps.length - 1; i >= 0; i--) {
        final p = powerUps[i];
        if (_ballOverlapsTile(b, p.col, p.row)) {
          powerUps.removeAt(i);
          if (p.mystery) {
            _applyPowerUp(b, kPowerUps[_rng.nextInt(kPowerUps.length)]);
          } else {
            _applyPowerUp(b, p.def);
          }
        }
      }
    }

    // Ball-ball collision: equal-mass ELASTIC deflection, like the
    // reference videos. Positions separate along the collision normal;
    // the velocity components along the normal are exchanged and the
    // tangential components kept. Direction-only elastic: ball speed is
    // re-derived from buffs every frame, so magnitudes are not
    // exchanged — directions are exactly right. A frozen ball is
    // infinite mass: only the live ball reflects, and the frozen ball's
    // angle is left untouched so it keeps its heading when it unfreezes.
    for (var i = 0; i < balls.length; i++) {
      for (var j = i + 1; j < balls.length; j++) {
        final a = balls[i];
        final c = balls[j];
        if (a.ghostUntil > time || c.ghostUntil > time) continue;
        final dx = c.x - a.x;
        final dy = c.y - a.y;
        final d = sqrt(dx * dx + dy * dy);
        final minD = _ballRadius(a) + _ballRadius(c);
        if (d >= minD) continue;
        // Collision normal (from a to c). Balls spawned on top of each
        // other (TRINITY) get the default east normal.
        final nx = d > 0.01 ? dx / d : 1.0;
        final ny = d > 0.01 ? dy / d : 0.0;
        // Positional separation: half the overlap each, along the normal.
        final push = (minD - d) / 2;
        a.x -= nx * push;
        a.y -= ny * push;
        c.x += nx * push;
        c.y += ny * push;
        if (d <= 0.01) continue; // no meaningful velocities to exchange.
        final aFrozen = frozenUntil[a.player] > time;
        final cFrozen = frozenUntil[c.player] > time;
        if (aFrozen && cFrozen) continue; // separation only.
        final sa = _ballSpeed(a);
        final sc = _ballSpeed(c);
        final vax = cos(a.angle) * sa;
        final vay = sin(a.angle) * sa;
        final vcx = cos(c.angle) * sc;
        final vcy = sin(c.angle) * sc;
        // A post-collision velocity near zero (near-exact cancellation)
        // keeps the old angle: atan2(0, 0) would snap the ball east.
        double reflect(double vx, double vy, double vn) {
          final rx = vx - 2 * vn * nx;
          final ry = vy - 2 * vn * ny;
          return sqrt(rx * rx + ry * ry) > 0.5
              ? atan2(ry, rx)
              : atan2(vy, vx);
        }
        if (aFrozen) {
          // c bounces off the frozen a.
          final vcn = vcx * nx + vcy * ny;
          if (vcn < 0) c.angle = reflect(vcx, vcy, vcn);
          continue;
        }
        if (cFrozen) {
          // a bounces off the frozen c.
          final van = vax * nx + vay * ny;
          if (van > 0) a.angle = reflect(vax, vay, van);
          continue;
        }
        // Both free: exchange the normal components.
        final vn = (vax - vcx) * nx + (vay - vcy) * ny;
        if (vn <= 0) continue; // already separating — no impulse.
        final nax = vax - vn * nx;
        final nay = vay - vn * ny;
        final ncx = vcx + vn * nx;
        final ncy = vcy + vn * ny;
        if (sqrt(nax * nax + nay * nay) > 0.5) a.angle = atan2(nay, nax);
        if (sqrt(ncx * ncx + ncy * ncy) > 0.5) c.angle = atan2(ncy, ncx);
      }
    }

    // Biggest lead so far: 1st-place tiles minus 2nd-place tiles.
    final counts = tileCounts();
    if (counts.length > 1) {
      final sorted = List<int>.from(counts)..sort((a, b) => b - a);
      final lead = sorted[0] - sorted[1];
      if (lead > biggestLead) biggestLead = lead;
    }
  }
}
