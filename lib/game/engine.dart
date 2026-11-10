// Color Cover — game engine (pure logic, no widgets).
// Grid: 18 columns x 24 rows (reference arena is 3:4). Balls move in tile
// coordinates at ~2.7 tiles/s (the measured video pace) and bounce off
// walls — the enemy border IS a wall: a ball's centre never enters
// enemy territory. Pressing the border converts the tile the ball
// touches, one block at a time, like the reference videos. Match
// length: 90 seconds. Modes (see Modes screen): Ultimate Meter/Tsunami,
// Bomb Ball, Golden Tile, Sudden Death shrinking, Chaos Events, Team
// 2v2, Battle Royale, VS COMPUTER. Flags come from MatchConfig.pack —
// All Chaos enables 1-5.
import 'dart:math';
import '../data/game_data.dart';
import 'juice.dart';
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
  BallState(
      {required this.player,
      required this.x,
      required this.y,
      required this.angle,
      this.angleOffset = 0})
      : lastValidX = x,
        lastValidY = y,
        prevX = x,
        prevY = y,
        teleX = x,
        teleY = y;
  final int player;
  double x;
  double y;
  double angle;
  /// TRINITY spread: a fixed ±40° offset from the player's steering
  /// direction. Steering sets one angle per player, so without this the
  /// three balls would travel as one cluster; with it they fan out.
  /// 0 for originals; -0.7 / +0.7 for TRINITY extras.
  final double angleOffset;
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
  /// WALL (reference video): last position whose centre tile was not a
  /// wall. Persistent — only written while the centre tile is non-wall,
  /// so a shrink, FIRE or Earthquake flip under the ball cannot poison
  /// it, and a frozen ball shoved by collision separation keeps a valid
  /// snapshot. Initialised to the spawn position.
  double lastValidX;
  double lastValidY;
  /// Wormhole: true from the teleport until the ball's centre tile is
  /// own again (paint converts the landing, or the ball walks out).
  /// While true the end-of-step wall clamp exempts this ball.
  bool teleported = false;
  /// Pre-teleport spot + engine time of the teleport: the 5 s
  /// last-resort yank if a landing never converts.
  double teleX;
  double teleY;
  double teleportedAt = -1000;
  /// Render interpolation: position at the previous fixed step. The
  /// painter lerps prev -> current by the frame fraction, so the ball
  /// glides smoothly even when the display rate != the 60 Hz sim rate.
  /// Reset on teleports/spawns, or the ball would smear across the arena.
  double prevX;
  double prevY;
  /// Squash & stretch: engine time until the pop ends + the squash axis
  /// (radians, the wall normal on a bounce, the travel direction on a
  /// pickup). The painter eases it back with a BACK overshoot.
  double squashUntil = 0;
  double squashAxis = 0;
  /// Wall-bounce sound throttle: one counted bounce per 0.5 s per ball,
  /// so pressing the border is one sustained bounce, not 60/s.
  double lastWallBounceAt = -1000;
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

  /// Bounce events this match (wall bounces + ball-ball impulses).
  /// The screen diffs this to play the bounce blip (throttled) — the
  /// engine itself stays silent. Only real impulses count: the
  /// already-separating / both-frozen / ghost paths add nothing.
  int bounceCount = 0;

  /// Golden Tiles collected this match (for the pickup sound: the
  /// Golden Tile does not increment powerUpsCollected).
  int goldenPickups = 0;

  /// Juice particles (visual only, capped at [maxParticles]). Spawned at
  /// conversions, pickups, bombs and tsunamis; updated in step() and
  /// drawn by the painter. They never touch the simulation.
  final List<Particle> particles = <Particle>[];
  static const int maxParticles = 120;

  /// Big-event counter (Bomb explosions + Colour Tsunamis). The screen
  /// diffs this for the large feedback tier (shake + hit-stop + flash).
  int bigEventCount = 0;

  /// Spawn a burst of [count] particles at tile coords ([cx], [cy]).
  /// Directions are random, speeds vary 0.4x–1.2x of [speed], life
  /// 0.35–0.6 s. Silently stops at the particle budget — juice must
  /// never grow unbounded.
  void spawnBurst(double cx, double cy, int color, int count, double speed) {
    for (var i = 0; i < count; i++) {
      if (particles.length >= maxParticles) return;
      final a = _rng.nextDouble() * 2 * pi;
      final v = speed * (0.4 + _rng.nextDouble() * 0.8);
      final life = 0.35 + _rng.nextDouble() * 0.25;
      particles.add(Particle(cx, cy, cos(a) * v, sin(a) * v, life, life,
          color, 0.06 + _rng.nextDouble() * 0.06));
    }
  }

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
    // 3 players: P1's ball starts in the middle third (9, 12). The old
    // (13.5, 12) sat in P2's third, and under the border-push rule P1
    // would paint nothing until it travelled back to the border.
    if (players.length == 3) starts[1] = Point(cols * 0.5, rows * 0.5);
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
    // Base speed is the measured video pace: the reference balls run
    // ~2.7 tiles/s (median 2.73 over the Latte vs Roast video). The old
    // 7.0 was nearly 3x too fast. All buffs stay multipliers on it.
    var s = 2.7;
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
    // SPEED CAP (physics-tuning): 12 tiles/s is 0.2 tiles per 60 Hz
    // step — far under one tile, so the per-axis wall check can never be
    // tunnelled through a 1-tile wall (the axis-separated move is the
    // CCD equivalent here: a step never skips a tile).
    return s.clamp(0, 12.0);
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
  /// Returns true iff the tile actually changed owner (false for a
  /// turret tile or a tile the player already owns). The Ultimate Meter
  /// grows only on real conversions — see _paintAround.
  bool _setTile(int idx, int player) {
    if (_isTurretTileIdx(idx)) return false;
    if (grid[idx] == player) return false;
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
    return true;
  }

  /// BORDER-PUSH (reference video): does tile (c, r) touch territory
  /// owned by [player]'s team? A neighbour counts iff it is playable
  /// and owned by the same team (fortified own tiles still count —
  /// fortify protects, it does not un-own). A tile with NO playable
  /// neighbour at all (e.g. a Maze singleton whose 4 neighbours are
  /// walls) counts as touching: adjacency could never be satisfied
  /// there, so direct contact converts it.
  bool _touchesOwnTerritory(int c, int r, int player) {
    var hasPlayableNeighbour = false;
    const dirs = [
      Point<int>(1, 0),
      Point<int>(-1, 0),
      Point<int>(0, 1),
      Point<int>(0, -1),
    ];
    for (final d in dirs) {
      final nc = c + d.x;
      final nr = r + d.y;
      if (!isPlayableTile(nc, nr)) continue;
      hasPlayableNeighbour = true;
      final owner = grid[tileIndex(nc, nr)];
      if (owner >= 0 && teamOf(owner) == teamOf(player)) return true;
    }
    return !hasPlayableNeighbour;
  }

  /// MERCY: a player (or their team in Team 2v2) that owns zero
  /// PLAYABLE tiles may repaint its centre tile to restart a territory.
  /// Only playable tiles count: in Sudden Death a player owning only
  /// shrunk-ring tiles would otherwise never trigger mercy while the
  /// ball is confined inside. Never resurrects a Battle Royale
  /// elimination (eliminated players have no balls, but the guard is
  /// explicit): it applies only to players still alive in the match.
  /// Once the seed tile is painted the team owns 1 tile and mercy
  /// switches off — it cannot be exploited into paint-anywhere.
  bool _mercyApplies(int player) {
    if (isBattleRoyale && eliminated.contains(player)) return false;
    final team = teamOf(player);
    for (var i = 0; i < grid.length; i++) {
      final owner = grid[i];
      if (owner < 0 || teamOf(owner) != team) continue;
      if (!isPlayableTile(i % cols, i ~/ cols)) continue;
      return false; // the team still owns a playable tile.
    }
    return true;
  }

  /// WALL (reference video): is tile (c, r) a wall for [player]'s ball?
  /// A wall is any tile the ball's centre may never occupy: a dead /
  /// non-playable tile, an unowned tile, or a tile owned by another
  /// team. Own-team tiles (fortified or not) are never walls.
  bool _isWallTile(int c, int r, int player) {
    if (!isPlayableTile(c, r)) return true;
    final owner = grid[tileIndex(c, r)];
    return owner < 0 || teamOf(owner) != teamOf(player);
  }

  /// Try to move ball [b] by [d] along one axis ([isX] true = x-axis).
  /// The centre may only enter a tile it already occupies or a
  /// non-wall tile: stepping into a wall tile is blocked, the angle
  /// reflects on that axis (like the arena edge bounce below), and the
  /// ball stays put on that axis. A zero step is a no-op, never a
  /// bounce. Mercy disables the wall for this ball. Returns true iff
  /// the ball moved. Steering runs before movement each frame, so the
  /// reflection is the ball's final angle for the frame — holding the
  /// joystick into the wall keeps it pressing, and the y-step still
  /// slides it along the border.
  bool _tryMoveAxis(BallState b, double d, bool isX, bool mercy) {
    if (d == 0) return true;
    final nx = isX ? b.x + d : b.x;
    final ny = isX ? b.y : b.y + d;
    final nc = nx.floor();
    final nr = ny.floor();
    if (!mercy &&
        (nc != b.x.floor() || nr != b.y.floor()) &&
        _isWallTile(nc, nr, b.player)) {
      if (isX) {
        b.angle = pi - b.angle;
      } else {
        b.angle = -b.angle;
      }
      // Squash & stretch: the ball squashes along the wall normal and
      // springs back with a BACK-ease overshoot (painter-side, 0.18 s).
      b.squashUntil = time + 0.18;
      b.squashAxis = isX ? 0 : pi / 2;
      // One counted bounce per 0.5 s per ball: a head-on press is one
      // sustained bounce, not 60/s (the screen already throttles the
      // sound to 80 ms, this keeps the counter itself sane).
      if (time - b.lastWallBounceAt > 0.5) {
        b.lastWallBounceAt = time;
        bounceCount++;
      }
      return false;
    }
    b.x = nx;
    b.y = ny;
    return true;
  }

  void _paintAround(BallState b) {
    final radius = _paintRadius(b);
    // The tile the centre stands on (floor, not round — the wall
    // keeps the centre on own tiles, so round() would be a tile the
    // ball may never occupy).
    final fc = b.x.floor();
    final fr = b.y.floor();
    // Candidates are tested against the grid as it stands when this
    // call starts (two-pass): a tile converted by this same call must
    // not unlock its neighbour in the same frame — the border advances
    // one block at a time, never in a chain.
    final mercy = _mercyApplies(b.player);
    // SEED: a ball may (re)paint its own floor tile when it has no
    // territory at all (mercy) or when it just wormhole-teleported
    // onto a border tile — the landing converts on the first paint
    // after the teleport (or after unfreezing), which is what clears
    // the teleported flag. Without this, a teleported ball sits in
    // the middle of its landing tile, its disc reaching no neighbour,
    // and can neither convert it nor move.
    final seed = mercy || b.teleported;
    // INFILTRATOR is the one ball-painting bypass: the ball stays
    // on its own side of the wall, but its paint reaches across the
    // border in a radius-2 disc for 10 s (earned by pickup).
    final infiltrator = b.infiltratorUntil > time;
    final candidates = <int>[];
    if (radius == 1) {
      // BASE (wall rule): exactly ONE tile per frame — the tile the
      // ball is pressing most directly (the edge-neighbour of the
      // floor tile most aligned with the ball's velocity), and only
      // if the disc actually overlaps it. That is the video's
      // one-block-at-a-time push. Overlap alone would paint up to 4
      // tiles at a corner (a 2-wide swath, and a bot converting ~5
      // tiles/s); round() alone could paint a diagonal tile the disc
      // never reached, or miss the tile it does touch; floor() alone
      // could never paint at all, because the wall keeps the centre
      // on own tiles.
      final vx = cos(b.angle);
      final vy = sin(b.angle);
      var bestDot = 0.0;
      var bestC = fc;
      var bestR = fr;
      const dirs = [
        Point<int>(1, 0),
        Point<int>(-1, 0),
        Point<int>(0, 1),
        Point<int>(0, -1),
      ];
      for (final d in dirs) {
        final dot = d.x * vx + d.y * vy;
        if (dot <= bestDot) continue;
        final c = fc + d.x;
        final r = fr + d.y;
        if (!_ballOverlapsTile(b, c, r)) continue;
        bestDot = dot;
        bestC = c;
        bestR = r;
      }
      if (bestDot > 0) {
        _maybePaint(bestC, bestR, b, seed, infiltrator, candidates);
      }
      // Seed: the floor tile itself (the ball's centre tile).
      if (seed) _maybePaint(fc, fr, b, seed, infiltrator, candidates);
    } else {
      // Buff radii (Wrecking Ball / Colossus / double paint): the
      // radius-2 disc around the floor tile, as before.
      for (var dr = -radius; dr <= radius; dr++) {
        for (var dc = -radius; dc <= radius; dc++) {
          if (dc * dc + dr * dr > radius * radius + 1) continue;
          _maybePaint(fc + dc, fr + dr, b, seed, infiltrator, candidates);
        }
      }
    }
    for (final idx in candidates) {
      if (!_setTile(idx, b.player)) continue;
      // Conversion puff: 2 tiny specks in the player's colour. Capped
      // by the particle budget — pressing the border converts ~3 tiles/s
      // per ball, so only a handful are ever alive at once.
      if (particles.length < 60) {
        spawnBurst(idx % cols + 0.5, idx ~/ cols + 0.5,
            players[b.player].colour.value, 2, 1.2);
      }
      if (ultimateEnabled) {
        ultimateMeters[b.player] =
            (ultimateMeters[b.player] + (b.doublePaintUntil > time ? 6 : 3)).clamp(0, 100);
      }
    }
  }

  /// One paint candidate: playable, not already own, not fortified,
  /// and (unless Infiltrator, or the seed) touching own territory.
  /// The seed exempts only the floor tile: a mercy seed is one tile,
  /// and a wormhole landing is one tile — both regrow outward one
  /// block at a time from there.
  void _maybePaint(int c, int r, BallState b, bool seed,
      bool infiltrator, List<int> candidates) {
    if (!isPlayableTile(c, r)) return;
    final idx = tileIndex(c, r);
    final owner = grid[idx];
    if (owner == b.player) return;
    if (owner >= 0 && fortifyUntil[owner] > time) return;
    if (!infiltrator &&
        !(seed && c == b.x.floor() && r == b.y.floor()) &&
        !_touchesOwnTerritory(c, r, b.player)) return;
    candidates.add(idx);
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
    // Big-event juice (see _explodeBomb): burst + counter for the
    // screen's large tier.
    bigEventCount++;
    spawnBurst(ball.x, ball.y, players[player].colour.value, 20, 3.5);
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
    // Big-event juice: the screen diffs bigEventCount for the large
    // tier (shake + hit-stop + flash); the burst is the visual.
    bigEventCount++;
    spawnBurst(cc + 0.5, rr + 0.5, 0xFFFF6D00, 24, 3.0);
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

  /// Wormhole landing test: a border tile (own territory, or an enemy
  /// tile touching own territory) that is playable, not a turret tile
  /// and not fortified — the ball must be able to convert it, or the
  /// wall rule would strand it there.
  bool _wormholeLanding(int c, int r, BallState b) {
    if (!isPlayableTile(c, r)) return false;
    if (_isTurretTile(c, r)) return false;
    final owner = grid[tileIndex(c, r)];
    if (owner >= 0 && fortifyUntil[owner] > time) return false;
    return (owner >= 0 && teamOf(owner) == teamOf(b.player)) ||
        _touchesOwnTerritory(c, r, b.player);
  }

  void _applyPowerUp(BallState b, PowerUpDef def) {
    powerUpsCollected[b.player]++;
    _showBanner(b.player, def.name, def.effect);
    // Pickup pop: squash along the travel direction + a burst in the
    // power-up's own colour. The screen adds shake + hit-stop.
    b.squashUntil = time + 0.18;
    b.squashAxis = b.angle;
    spawnBurst(b.x, b.y, def.value, 10, 2.5);
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
        // Top-up spawns only the MISSING offsets: assigning by loop
        // index would give a second -0.7 extra when the -0.7 one is
        // the survivor, and the pair would travel together.
        final liveExtras = balls
            .where((e) => e.player == b.player && e.removeAt > time)
            .toList();
        for (final e in liveExtras) {
          e.removeAt = time + 10;
        }
        final liveOffsets = liveExtras.map((e) => e.angleOffset).toSet();
        for (final spread in [-0.7, 0.7]) {
          if (liveOffsets.contains(spread)) continue;
          final extra = BallState(
              player: b.player,
              x: b.x,
              y: b.y,
              angle: b.angle + spread,
              angleOffset: spread);
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
          // WALL: extras spawn on the collector — if the collector
          // was just wormhole-teleported onto a border tile, the
          // extras inherit the teleport state and the pre-teleport
          // spot, so the wall clamp never yanks them to (0, 0).
          extra.teleported = b.teleported;
          extra.teleX = b.teleX;
          extra.teleY = b.teleY;
          extra.teleportedAt = b.teleportedAt;
          extra.lastValidX = b.lastValidX;
          extra.lastValidY = b.lastValidY;
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
        // The landing is on a border tile (own territory or adjacent
        // to it) so the ball can keep painting right away — a deep
        // random landing would strand it under the border-push rule.
        // Fortified and turret tiles are excluded: the ball could
        // never convert them, so landing there would strand it under
        // the wall rule. No border tile found (owns nothing): fall
        // back to any playable tile (mercy covers the owns-nothing
        // case) — never an unchecked random tile, which could be a
        // maze wall or a shrunk ring.
        b.teleX = b.x;
        b.teleY = b.y;
        b.teleportedAt = time;
        var landed = false;
        for (var tries = 0; tries < 24 && !landed; tries++) {
          final c = _rng.nextInt(cols);
          final r = _rng.nextInt(rows);
          if (!_wormholeLanding(c, r, b)) continue;
          b.x = c.toDouble() + 0.5;
          b.y = r.toDouble() + 0.5;
          landed = true;
        }
        if (!landed) {
          // Deterministic scan: a border tile exists whenever the
          // team owns tiles — 24 random tries can miss a 1-tile
          // border.
          for (var r = 0; r < rows && !landed; r++) {
            for (var c = 0; c < cols && !landed; c++) {
              if (!_wormholeLanding(c, r, b)) continue;
              b.x = c.toDouble() + 0.5;
              b.y = r.toDouble() + 0.5;
              landed = true;
            }
          }
        }
        if (!landed) {
          for (var tries = 0; tries < 24 && !landed; tries++) {
            final c = _rng.nextInt(cols);
            final r = _rng.nextInt(rows);
            if (!isPlayableTile(c, r) || _isTurretTile(c, r)) continue;
            final owner = grid[tileIndex(c, r)];
            if (owner >= 0 && fortifyUntil[owner] > time) continue;
            b.x = c.toDouble() + 0.5;
            b.y = r.toDouble() + 0.5;
            landed = true;
          }
        }
        b.teleported = true;
        b.trail.clear();
        // Render interpolation: reset the previous position, or the
        // painter would smear the ball from the old spot to the new one.
        b.prevX = b.x;
        b.prevY = b.y;
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

  /// Does tile (c, r) have at least one playable 4-neighbour? A
  /// power-up on a tile with none (a Maze singleton whose neighbours
  /// are all walls) could never be reached under the wall rule — the
  /// ball's centre can only arrive through a playable neighbour.
  bool _hasPlayableNeighbour(int c, int r) {
    const dirs = [
      Point<int>(1, 0),
      Point<int>(-1, 0),
      Point<int>(0, 1),
      Point<int>(0, -1),
    ];
    for (final d in dirs) {
      if (isPlayableTile(c + d.x, r + d.y)) return true;
    }
    return false;
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
          _hasPlayableNeighbour(c, r) &&
          !powerUps.any((p) => p.col == c && p.row == r)) break;
      c = _rng.nextInt(cols);
      r = _rng.nextInt(rows);
    }
    if (!isPlayableTile(c, r) ||
        _isTurretTile(c, r) ||
        !_hasPlayableNeighbour(c, r)) return;
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

  /// Shortest signed angle from [from] to [to], in (-pi, pi]. The bot
  /// and ice steering lerp toward a target angle every frame; without
  /// wrapping, a target just across the +/-pi branch cut (e.g. from
  /// +3.1 to -3.1 — the SAME direction, due west) makes the lerp spin
  /// the long way around through east, and the bot flies away from the
  /// border forever instead of turning toward it.
  double _angleDelta(double from, double to) {
    var d = (to - from) % (2 * pi);
    if (d > pi) d -= 2 * pi;
    return d;
  }

  /// Bot decision state (VS COMPUTER, player 1): utility-based target
  /// choice, re-decided on a per-difficulty timer — never every frame
  /// (game-ai: recompute sparingly). Steering follows the stored target
  /// each frame; TRINITY extras add their own angleOffset on top.
  double _botTargetX = 0;
  double _botTargetY = 0;
  double _botAimError = 0; // radians, re-rolled each decision
  double _botNextDecisionAt = -1;

  /// How often the bot re-decides (seconds): Easy is slow and sloppy,
  /// Crazy is near-instant. The decision interval IS the reaction delay.
  double _botDecisionInterval() {
    if (config.botDifficulty == BotDifficulty.easy) return 0.5;
    if (config.botDifficulty == BotDifficulty.crazy) return 0.12;
    return 0.25;
  }

  /// Aim error re-rolled per decision (radians): Easy wanders ±0.5,
  /// Medium ±0.2, Crazy ±0.05. The error moves the TARGET, never the
  /// angle — a per-ball kick to b.angle would erase the TRINITY spread.
  double _botAimErrorRange() {
    if (config.botDifficulty == BotDifficulty.easy) return 0.5;
    if (config.botDifficulty == BotDifficulty.crazy) return 0.05;
    return 0.2;
  }

  /// Steering turn rate per frame fraction: Easy turns slowly, Medium
  /// turns firmly, Crazy snaps (1.0 = instant). Uses _angleDelta, so a
  /// westward turn never spins the long way around through east (the
  /// v3.7 angle-wrap stall fix — do not regress it).
  double _botTurnRate() {
    if (config.botDifficulty == BotDifficulty.easy) return 0.05;
    if (config.botDifficulty == BotDifficulty.crazy) return 1.0;
    return 0.2;
  }

  /// Power-up value for the utility score: game-changing powers are
  /// worth travelling for, small buffs are not.
  double _powerUpValue(String id) {
    switch (id) {
      case 'bomb':
        return 14;
      case 'trinity':
        return 12;
      case 'tidal':
        return 11;
      case 'turret':
        return 11;
      case 'colossus':
        return 10;
      case 'infiltrator':
        return 10;
      case 'blackhole':
        return 9;
      case 'wrecking':
        return 9;
      case 'freeze':
        return 8;
      case 'nitro':
        return 7;
      case 'wormhole':
        return 7;
      case 'speed':
        return 6;
      case 'magnet':
        return 6;
      case 'ghost':
        return 5;
      case 'fortify':
        return 5;
      default:
        return 5;
    }
  }

  /// UTILITY DECISION (game-ai): score every option, take the best.
  /// (a) Border tiles to push: 10 - distance, + a defence bonus when an
  /// enemy ball is pressing that tile (6 - 1.5 * enemy distance).
  /// (b) Power-ups by value minus 0.8 * distance, so a far power-up
  /// loses to a near border tile. (c) No border tile at all (owns
  /// nothing): fall back to the nearest enemy tile (mercy case).
  void _botDecide(BallState b) {
    var found = false;
    var bestScore = -1e9;
    var tx = b.x;
    var ty = b.y;
    // Threats: live balls whose team is not the bot's.
    final threats = <BallState>[];
    for (final o in balls) {
      if (teamOf(o.player) != teamOf(b.player)) threats.add(o);
    }
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        if (!isPlayableTile(c, r)) continue;
        final owner = grid[tileIndex(c, r)];
        if (owner < 0 || teamOf(owner) == teamOf(b.player)) continue;
        if (fortifyUntil[owner] > time) continue;
        if (!_touchesOwnTerritory(c, r, b.player)) continue;
        final dx = c + 0.5 - b.x;
        final dy = r + 0.5 - b.y;
        final d = sqrt(dx * dx + dy * dy);
        var score = 10 - d;
        // Defence: an enemy ball pressing this tile makes it urgent.
        for (final t in threats) {
          final edx = c + 0.5 - t.x;
          final edy = r + 0.5 - t.y;
          final ed = sqrt(edx * edx + edy * edy);
          if (ed < 4) score += 6 - 1.5 * ed;
        }
        if (score > bestScore) {
          bestScore = score;
          tx = c + 0.5;
          ty = r + 0.5;
          found = true;
        }
      }
    }
    for (final p in powerUps) {
      final dx = p.col + 0.5 - b.x;
      final dy = p.row + 0.5 - b.y;
      final score = _powerUpValue(p.def.id) - 0.8 * sqrt(dx * dx + dy * dy);
      if (score > bestScore) {
        bestScore = score;
        tx = p.col + 0.5;
        ty = p.row + 0.5;
        found = true;
      }
    }
    if (!found) {
      // No border tile and no power-up (owns nothing — mercy case):
      // nearest enemy tile so the bot still has a direction; the
      // mercy rule lets it repaint from wherever it lands. Fortified
      // tiles are excluded — pressing a fortified border forever
      // would stall the bot.
      var best = 1e9;
      for (var r = 0; r < rows; r++) {
        for (var c = 0; c < cols; c++) {
          if (!isPlayableTile(c, r) || grid[tileIndex(c, r)] == b.player) {
            continue;
          }
          final owner = grid[tileIndex(c, r)];
          if (owner >= 0 && fortifyUntil[owner] > time) continue;
          final d = (c + 0.5 - b.x) * (c + 0.5 - b.x) +
              (r + 0.5 - b.y) * (r + 0.5 - b.y);
          if (d < best) {
            best = d;
            tx = c + 0.5;
            ty = r + 0.5;
          }
        }
      }
    }
    _botTargetX = tx;
    _botTargetY = ty;
    _botAimError =
        (_rng.nextDouble() * 2 - 1) * _botAimErrorRange();
    _botNextDecisionAt = time + _botDecisionInterval();
  }

  void _botSteer(BallState b) {
    // Decide on the difficulty's timer; steer toward the stored target
    // every frame. _botDecide runs once per decision window (the first
    // bot ball each step sets the timer, so TRINITY extras share it).
    if (time >= _botNextDecisionAt) _botDecide(b);
    // TRINITY extras keep their ±40° spread: steer toward the target
    // plus the ball's own offset, so the three balls fan out instead
    // of travelling as one cluster.
    final target = atan2(_botTargetY - b.y, _botTargetX - b.x) +
        b.angleOffset +
        _botAimError;
    final rate = _botTurnRate();
    if (rate >= 1.0) {
      b.angle = target;
    } else {
      b.angle += _angleDelta(b.angle, target) * rate;
    }
  }

  void step(double dt) {
    // Juice particles: visual only — drift, drag, die. Updated even
    // after the match ends so a final burst settles under the end card.
    for (var i = particles.length - 1; i >= 0; i--) {
      final p = particles[i];
      p.life -= dt;
      if (p.life <= 0) {
        particles.removeAt(i);
        continue;
      }
      p.x += p.vx * dt;
      p.y += p.vy * dt;
      final drag = (1 - 3 * dt).clamp(0.0, 1.0);
      p.vx *= drag;
      p.vy *= drag;
    }
    // Render-interpolation snapshot: previous fixed-step positions.
    for (final b in balls) {
      b.prevX = b.x;
      b.prevY = b.y;
    }
    if (finished) return;
    // A hitch must never let one step jump a whole tile (tunnelling
    // through the border): cap dt at 1/30 s — at max speed the step
    // stays under half a tile.
    if (dt > 1 / 30) dt = 1 / 30;
    time += dt;
    timeLeft = (matchSeconds - time).clamp(0, matchSeconds.toDouble());
    if (timeLeft <= 0) {
      finished = true;
      return;
    }

    // WALL: a wormhole-teleported ball stops being exempt once its
    // centre tile is own again (paint converted the landing, or the
    // ball walked out) — or while mercy applies (no walls at all).
    // Not cleared on a timer: a frozen teleported ball keeps the flag
    // until its centre is own.
    for (final b in balls) {
      if (b.teleported &&
          (_mercyApplies(b.player) ||
              !_isWallTile(b.x.floor(), b.y.floor(), b.player))) {
        b.teleported = false;
      }
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
      // A power-up on a shrunk tile could never be reached under the
      // wall rule and would occupy one of the max-3 slots forever.
      powerUps.removeWhere((p) => !isPlayableTile(p.col, p.row));
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
      // The drift has no playable check: a power-up dragged onto a
      // dead tile could never be reached under the wall rule.
      powerUps.removeWhere((p) => !isPlayableTile(p.col, p.row));
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
          // BORDER-PUSH: the turret only paints tiles at the border —
          // otherwise it would be the last deep-painting path left.
          // No border tile in range means no shot this tick; it
          // retries in 0.8 s (nextShotAt already advanced above).
          if (!_touchesOwnTerritory(c, r, t.player)) continue;
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

      // WALL: remember the last position whose centre tile was not a
      // wall. Persistent — only written while non-wall — so a shrink,
      // FIRE or Earthquake flip under the ball cannot poison it.
      // Recorded before the freeze skip: a frozen ball is still moved
      // by collision separation, so it needs a valid snapshot too.
      if (!_isWallTile(b.x.floor(), b.y.floor(), b.player)) {
        b.lastValidX = b.x;
        b.lastValidY = b.y;
      }

      // FREEZE: a frozen ball does not move, paint or pick up anything.
      if (frozenUntil[b.player] > time) continue;

      // Pre-pull spot, for the wall check below.
      final prePullX = b.x;
      final prePullY = b.y;
      for (final other in balls) {
        if (other == b) continue;
        if (other.blackHoleUntil > time) {
          final dx = other.x - b.x;
          final dy = other.y - b.y;
          final d = sqrt(dx * dx + dy * dy);
          if (d > 0.6) {
            // Black-hole pull scales with the victim's own speed
            // (0.5x — the victim can always escape). The old absolute
            // 2.0 would be 74% of the new 2.7 base speed and would
            // drag balls into the wall.
            final pull = 0.5 * _ballSpeed(b);
            b.x += dx / d * pull * dt;
            b.y += dy / d * pull * dt;
          }
        }
      }
      // WALL: the pull must not drag the ball across the border —
      // restore the pre-pull position before _paintAround runs, so
      // the pull can never paint its way through the wall. Restoring
      // to lastValid instead would yank a wormhole-teleported ball
      // back to its pre-teleport spot before paint can convert the
      // landing — the pre-pull spot is the landing itself, so the
      // restore is a no-op for it.
      final mercy = _mercyApplies(b.player);
      if (!mercy &&
          _isWallTile(b.x.floor(), b.y.floor(), b.player) &&
          (b.x != prePullX || b.y != prePullY)) {
        b.x = prePullX;
        b.y = prePullY;
      }

      final steer = steering[b.player];
      if (steer != null && (steer.x.abs() > 0.2 || steer.y.abs() > 0.2)) {
        // TRINITY extras keep their ±40° spread off the steered
        // direction, so the three balls fan out instead of clustering.
        final target = atan2(steer.y, steer.x) + b.angleOffset;
        if (iceUntil > time) {
          // Slippery ice: turn slowly (wrapped — see _angleDelta, or
          // a westward turn spins the long way around through east).
          b.angle += _angleDelta(b.angle, target) * 0.12;
        } else {
          b.angle = target;
        }
      }

      final speed = _ballSpeed(b);
      // WALL (reference video): axis-separated movement — the centre
      // may only occupy own-team tiles; the border is a wall the ball
      // bounces off while converting the tile it presses (see
      // _tryMoveAxis and _paintAround). Mercy turns the walls off.
      _tryMoveAxis(b, cos(b.angle) * speed * dt, true, mercy);
      _tryMoveAxis(b, sin(b.angle) * speed * dt, false, mercy);

      final rad = _ballRadius(b);
      final minX = (suddenDeathEnabled ? shrinkLevel : 0) + rad;
      final maxX = cols - (suddenDeathEnabled ? shrinkLevel : 0) - rad;
      final minY = (suddenDeathEnabled ? shrinkLevel : 0) + rad;
      final maxY = rows - (suddenDeathEnabled ? shrinkLevel : 0) - rad;
      if (b.x < minX) {
        b.x = minX;
        b.angle = pi - b.angle;
        b.squashUntil = time + 0.18;
        b.squashAxis = 0;
        bounceCount++;
      }
      if (b.x > maxX) {
        b.x = maxX;
        b.angle = pi - b.angle;
        b.squashUntil = time + 0.18;
        b.squashAxis = 0;
        bounceCount++;
      }
      if (b.y < minY) {
        b.y = minY;
        b.angle = -b.angle;
        b.squashUntil = time + 0.18;
        b.squashAxis = pi / 2;
        bounceCount++;
      }
      if (b.y > maxY) {
        b.y = maxY;
        b.angle = -b.angle;
        b.squashUntil = time + 0.18;
        b.squashAxis = pi / 2;
        bounceCount++;
      }

      b.trail.add(Point(b.x, b.y));
      if (b.trail.length > 14) b.trail.removeAt(0);

      _paintAround(b);

      // Golden Tile: first ball to touch it gets double paint for 10s.
      // Overlap, not centre-only — same fix as power-up pickup.
      if (goldenEnabled && goldenVisible) {
        if (_ballOverlapsTile(b, goldenCol, goldenRow)) {
          goldenVisible = false;
          goldenPickups++;
          _goldenRespawnAt = time + 20;
          b.doublePaintUntil = time + 10;
          b.squashUntil = time + 0.18;
          b.squashAxis = b.angle;
          spawnBurst(goldenCol + 0.5, goldenRow + 0.5, 0xFFFFD700, 10, 2.5);
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
          if (vcn < 0) {
            c.angle = reflect(vcx, vcy, vcn);
            bounceCount++;
          }
          continue;
        }
        if (cFrozen) {
          // a bounces off the frozen c.
          final van = vax * nx + vay * ny;
          if (van > 0) {
            a.angle = reflect(vax, vay, van);
            bounceCount++;
          }
          continue;
        }
        // Both free: exchange the normal components.
        final vn = (vax - vcx) * nx + (vay - vcy) * ny;
        if (vn <= 0) continue; // already separating — no impulse.
        bounceCount++;
        final nax = vax - vn * nx;
        final nay = vay - vn * ny;
        final ncx = vcx + vn * nx;
        final ncy = vcy + vn * ny;
        if (sqrt(nax * nax + nay * nay) > 0.5) a.angle = atan2(nay, nax);
        if (sqrt(ncx * ncx + ncy * ncy) > 0.5) c.angle = atan2(ncy, ncx);
      }
    }

    // WALL CLAMP: black-hole pull, collision separation, shrink, FIRE
    // and Earthquake can still leave a ball's centre on a wall tile.
    // Push it back to its last non-wall position and point it back
    // the way it came. Teleported balls are exempt while their
    // landing is unconverted (paint or walking out heals it); only
    // after 5 s does the last-resort yank to the pre-teleport spot
    // fire. Mercy balls have no walls at all.
    for (final b in balls) {
      if (_mercyApplies(b.player)) continue;
      final cc = b.x.floor();
      final cr = b.y.floor();
      if (!_isWallTile(cc, cr, b.player)) continue;
      if (b.teleported) {
        if (time - b.teleportedAt >= 5.0) {
          b.x = b.teleX;
          b.y = b.teleY;
          b.teleported = false;
        }
        continue;
      }
      // The last valid spot itself may have become a wall (shrink /
      // FIRE flipped it under a standing ball): then pop to the
      // nearest non-wall tile centre instead (expanding ring, max 3
      // — the ball's team always owns tiles within reach, or mercy
      // applies and this loop is skipped).
      if (!_isWallTile(
          b.lastValidX.floor(), b.lastValidY.floor(), b.player)) {
        final wx = b.x;
        final wy = b.y;
        b.x = b.lastValidX;
        b.y = b.lastValidY;
        final dx = b.lastValidX - wx;
        final dy = b.lastValidY - wy;
        if (dx * dx + dy * dy > 0.0001) b.angle = atan2(dy, dx);
      } else {
        var placed = false;
        for (var ring = 1; ring <= 3 && !placed; ring++) {
          for (var dr = -ring; dr <= ring && !placed; dr++) {
            for (var dc = -ring; dc <= ring && !placed; dc++) {
              if (dc.abs() != ring && dr.abs() != ring) continue;
              final tc = cc + dc;
              final tr = cr + dr;
              if (_isWallTile(tc, tr, b.player)) continue;
              b.x = tc + 0.5;
              b.y = tr + 0.5;
              placed = true;
            }
          }
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
