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
  PowerUpOnField(this.col, this.row, this.def);
  int col; // mutable: MAGNET pulls power-up tiles across the arena.
  int row;
  final PowerUpDef def;
}

/// One stacked power-up banner (reference: newest on top, ~2-4 s visible).
class MatchBanner {
  MatchBanner(this.player, this.text, this.until);
  final int player;
  final String text;
  final double until;
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
  final List<Point<double>> trail = <Point<double>>[];
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

  double time = 0;
  late double timeLeft;
  double _spawnTimer = 6;
  bool finished = false;

  /// Match stats (for the end card + History + Achievements).
  late List<int> tilesPainted; // tiles each player painted this match.
  late List<int> powerUpsCollected; // power-ups each player collected.
  int biggestLead = 0; // biggest tile-count gap between 1st and 2nd.

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

  /// Paint one tile for [player] and count it for match stats.
  /// Chaos/Fire/Earthquake reassign tiles directly (environment, not
  /// player-painted) and do not go through here.
  void _setTile(int idx, int player) {
    if (grid[idx] == player) return;
    grid[idx] = player;
    paintTime[idx] = time;
    tilesPainted[player]++;
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
    _showBanner(player, 'COLOR TSUNAMI!');
    return true;
  }

  void _showBanner(int player, String text) {
    banners.add(MatchBanner(player, text, time + 3));
    if (banners.length > 4) banners.removeAt(0);
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
    _showBanner(b.player, def.name);
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
    var c = _rng.nextInt(cols);
    var r = _rng.nextInt(rows);
    for (var tries = 0; tries < 12; tries++) {
      if (isPlayableTile(c, r) && !powerUps.any((p) => p.col == c && p.row == r)) break;
      c = _rng.nextInt(cols);
      r = _rng.nextInt(rows);
    }
    if (!isPlayableTile(c, r)) return;
    powerUps.add(PowerUpOnField(c, r, def));
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

    // Sudden Death: last 10 seconds, arena shrinks one ring at a time.
    if (suddenDeathEnabled && timeLeft <= 10) {
      shrinkLevel = ((10 - timeLeft) / 3).ceil().clamp(0, 3);
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
      if (goldenEnabled && goldenVisible) {
        final cc = b.x.round();
        final rr = b.y.round();
        if (cc == goldenCol && rr == goldenRow) {
          goldenVisible = false;
          _goldenRespawnAt = time + 20;
          b.doublePaintUntil = time + 10;
          _showBanner(b.player, 'GOLDEN TILE! DOUBLE PAINT!');
        }
      }

      final cc = b.x.round().clamp(0, cols - 1);
      final rr = b.y.round().clamp(0, rows - 1);
      final hit = powerUps.indexWhere((p) => p.col == cc && p.row == rr);
      if (hit >= 0) {
        final def = powerUps[hit].def;
        powerUps.removeAt(hit);
        _applyPowerUp(b, def);
      }
    }

    for (var i = 0; i < balls.length; i++) {
      for (var j = i + 1; j < balls.length; j++) {
        final a = balls[i];
        final c = balls[j];
        if (a.ghostUntil > time || c.ghostUntil > time) continue;
        final dx = c.x - a.x;
        final dy = c.y - a.y;
        final d = sqrt(dx * dx + dy * dy);
        final minD = _ballRadius(a) + _ballRadius(c);
        if (d > 0.01 && d < minD) {
          final push = (minD - d) / 2;
          final nx = dx / d;
          final ny = dy / d;
          a.x -= nx * push;
          a.y -= ny * push;
          c.x += nx * push;
          c.y += ny * push;
          a.angle = atan2(-ny, -nx);
          c.angle = atan2(ny, nx);
        }
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
