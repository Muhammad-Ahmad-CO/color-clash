// Color Cover — Game screen (Tiny Clash chrome, v3.5).
// Animated gradient background derived from the player colours, a 3:4
// arena floating in it, chunky rounded power-up banners stacked in the
// top margin, navy territory pill at the bottom, and the end card as a
// chunky navy card with a gold crown on the dimmed playfield. No timer,
// no names, no pause/mute HUD, no % numbers, no emoji anywhere on the
// match screen.
// Steering: a VISIBLE floating joystick appears where the player's finger
// touches down (dynamic origin) and follows the finger — the user asked
// for a joystick they can see (03:51 PKT), so the invisible drag of v2
// is replaced by a visible control on top of the same anchor logic.
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import '../data/game_data.dart';
import '../game/coins.dart';
import '../game/engine.dart';
import '../game/juice.dart';
import '../game/match_theme.dart';
import '../game/sound.dart';
import '../game/stats.dart';
import '../widgets/ball_painter.dart';
import '../widgets/dot_chrome.dart';
import '../widgets/floating_joystick.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key, required this.config});
  final MatchConfig config;
  List<PlayerConfig> get players => config.players;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late GameEngine _engine;
  // Fixed-timestep loop (physics-tuning): a vsync Ticker feeds an
  // accumulator; the engine steps at a fixed 1/60 s, at most 4 steps
  // per frame, so the sim is frame-rate independent and a load hitch
  // can never spiral. _interpAlpha is the leftover fraction for the
  // painter's render interpolation. NOTE: the state uses
  // TickerProviderStateMixin (not Single-) because the background
  // AnimationController already owns one ticker — a second createTicker
  // on Single- would assert.
  Ticker? _ticker;
  Duration? _lastTick;
  double _accumulator = 0;
  double _interpAlpha = 1.0;
  static const double _fixedDt = 1 / 60;
  late AnimationController _bgCtrl;
  bool _paused = false;
  bool _showEnd = false;
  int _coinsEarned = 0;
  bool _coinsDone = false;
  bool _statsDone = false; // match recorded once per match.
  List<String> _newAchievements = <String>[];
  final GlobalKey _arenaKey = GlobalKey();
  // Match generation: incremented on every restart. The async
  // awardMatch/recordMatch callbacks ignore stale generations, so a
  // NEXT MATCH can never overwrite the new match's coins/announcements.
  int _matchGen = 0;
  // Best-of series (2 players / VS COMPUTER only): wins per player.
  List<int> _seriesScore = <int>[0, 0];
  bool _seriesDecided = false;
  // Sound + haptic diff baselines: the engine only counts events, this
  // screen turns new counts into sounds. Reset in _newMatch, or the
  // first pickups of a new match would stay silent until the totals
  // pass the previous match's.
  int _lastPowerUpsTotal = 0;
  int _lastBounceCount = 0;
  DateTime _lastBounceSoundAt = DateTime.fromMillisecondsSinceEpoch(0);
  // Game feel (v3.8): trauma-based shake, hit-stop, white flash.
  // Trauma 0..1, decays 1.2/s; shake offset = trauma^2 * max offset,
  // sin-driven (smooth, never a random per-frame jitter). Shake moves
  // the arena WIDGET only — never the ball/body. Hit-stop slows the
  // SIM via _timeScale and restores on a REAL-TIME Future.delayed, so
  // it can never stall the game; only the newest call restores it.
  // Input is never blocked: steering is set in the pointer listeners,
  // independent of the loop.
  double _trauma = 0;
  double _shakeT = 0;
  double _timeScale = 1.0;
  int _hitStopId = 0;
  DateTime _flashUntil = DateTime.fromMillisecondsSinceEpoch(0);
  // Juice event baselines (reset in _newMatch like the sound ones).
  int _lastTilesPaintedTotal = 0;
  int _lastBigEventCount = 0;
  DateTime _lastSmallShakeAt = DateTime.fromMillisecondsSinceEpoch(0);
  // End-card extras from the last recordMatch result.
  int _comboBonus = 0;
  int _bestCombo = 0;
  List<String> _extraLines = <String>[];

  // Active joysticks: pointer id -> joystick (player, touch-down origin,
  // current finger position). One per active finger.
  final Map<int, ActiveJoystick> _pointers = <int, ActiveJoystick>{};
  // One-line steer hint, shown until the first successful steer.
  bool _showSteerHint = true;

  List<Color> get _territoryColors =>
      widget.players.map((p) => Color(p.colour.value)).toList();

  @override
  void initState() {
    super.initState();
    _engine = GameEngine(widget.config);
    WidgetsBinding.instance.addObserver(this);
    _hideSystemBars();
    JuiceSettings.load();
    _bgCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat(reverse: true);
    _startLoop();
  }

  // Fullscreen: hide the Android system buttons (back/home/recent) as
  // soon as the game opens. immersiveSticky brings them back only on an
  // edge swipe, then auto-hides them again.
  void _hideSystemBars() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _hideSystemBars();
  }

  void _startLoop() {
    _ticker?.dispose();
    _ticker = createTicker(_onTick);
    _lastTick = null;
    _accumulator = 0;
    _interpAlpha = 1.0;
    _ticker!.start();
  }

  /// Trauma-based screen shake (game-feel): hits ADD trauma, it decays
  /// every frame; the offset is trauma^2 so small hits barely move and
  /// big hits punch. Skipped entirely when Reduce Shake is on.
  void _addTrauma(double amount) {
    if (JuiceSettings.reduceShake) return;
    _trauma = (_trauma + amount).clamp(0.0, 1.0);
  }

  Offset get _shakeOffset {
    if (_trauma <= 0) return Offset.zero;
    final s = _trauma * _trauma;
    return Offset(12 * s * sin(_shakeT * 1.7), 8 * s * sin(_shakeT * 2.3));
  }

  /// Hit-stop (game-feel): slow the sim to [slow]x for [duration] REAL
  /// seconds, then restore. The restore uses a real-time wait
  /// (Future.delayed is unaffected by _timeScale) and only the newest
  /// call restores, so overlapping hit-stops never cut each other short.
  void _hitStop(double duration, double slow) {
    _hitStopId++;
    final id = _hitStopId;
    _timeScale = slow;
    Future.delayed(Duration(milliseconds: (duration * 1000).round()), () {
      if (!mounted || id != _hitStopId) return;
      _timeScale = 1.0;
    });
  }

  /// Feedback bundles by importance tier (game-feel):
  /// small = tile-conversion tick (shake 0.1, throttled to 0.3 s, no
  /// hit-stop); medium = power-up pickup (shake 0.4 + hit-stop 0.05 s);
  /// large = Bomb / Colour Tsunami / match win (shake 0.8 + hit-stop
  /// 0.12 s + white flash 0.06 s). Never on routine actions.
  void _feedbackSmall() {
    final now = DateTime.now();
    if (now.difference(_lastSmallShakeAt).inMilliseconds < 300) return;
    _lastSmallShakeAt = now;
    _addTrauma(0.1);
  }

  void _feedbackMedium() {
    _addTrauma(0.4);
    _hitStop(0.05, 0.05);
  }

  void _feedbackLarge() {
    _addTrauma(0.8);
    _hitStop(0.12, 0.05);
    _flashUntil = DateTime.now().add(const Duration(milliseconds: 60));
  }

  void _onTick(Duration elapsed) {
    if (!mounted) return;
    // Real frame dt, clamped: a load hitch advances the sim by at most
    // 0.1 s (no explosion after a stall), and the 4-step cap below
    // drops any further backlog instead of spiralling.
    final realDt = _lastTick == null
        ? _fixedDt
        : (elapsed - _lastTick!).inMicroseconds / 1e6;
    _lastTick = elapsed;
    if (_paused) return;
    final clampedDt = realDt.clamp(0.0, 0.1);
    // Trauma decays on REAL time, so shake settles even during hit-stop.
    if (_trauma > 0) {
      _trauma = max(0.0, _trauma - 1.2 * clampedDt);
      _shakeT += clampedDt * 30;
    }
    if (!_engine.finished) {
      _accumulator += clampedDt * _timeScale;
      var steps = 0;
      while (_accumulator >= _fixedDt && steps < 4) {
        _engine.step(_fixedDt);
        _accumulator -= _fixedDt;
        steps++;
      }
      if (steps == 4) _accumulator = 0; // drop backlog, never spiral
      _interpAlpha = (_accumulator / _fixedDt).clamp(0.0, 1.0);
    }
    setState(() {
      _diffEvents();
    });
  }

  /// Sounds + haptics + juice, diff-based: the engine only counts
  /// events and this screen turns new counts into one response each.
  void _diffEvents() {
        // Small tier: tile conversions tick the shake (throttled).
        final tilesTotal =
            _engine.tilesPainted.fold<int>(0, (a, b) => a + b);
        if (tilesTotal > _lastTilesPaintedTotal) {
          _lastTilesPaintedTotal = tilesTotal;
          _feedbackSmall();
        }
        // Sounds + haptics, diff-based: the engine only counts events
        // (powerUpsCollected + goldenPickups, bounceCount) and this
        // screen turns new counts into one sound each. The TSUNAMI
        // button plays its own pickup() and does not count, so there
        // is no double-fire.
        final powerUpsTotal =
            _engine.powerUpsCollected.fold<int>(0, (a, b) => a + b) +
                _engine.goldenPickups;
        if (powerUpsTotal > _lastPowerUpsTotal) {
          _lastPowerUpsTotal = powerUpsTotal;
          SoundFx.pickup();
          _feedbackMedium();
          // HapticFeedback returns a Future: a plain try/catch around
          // the call cannot catch async platform errors (e.g. no
          // vibrator), so errors are swallowed on the Future.
          unawaited(HapticFeedback.heavyImpact().catchError((_) {}));
        }
        if (_engine.bounceCount > _lastBounceCount) {
          _lastBounceCount = _engine.bounceCount;
          final now = DateTime.now();
          if (now.difference(_lastBounceSoundAt).inMilliseconds >= 80) {
            _lastBounceSoundAt = now;
            SoundFx.bounce();
          }
        }
        // Large tier: Bomb explosions and Colour Tsunamis.
        if (_engine.bigEventCount > _lastBigEventCount) {
          _lastBigEventCount = _engine.bigEventCount;
          _feedbackLarge();
        }
        if (_engine.finished && !_showEnd) {
          final gen = _matchGen;
          final winnerIdx = _engine.winnerIndex();
          final won = winnerIdx == 0 ||
              (widget.config.mode == GameMode.team2v2 &&
                  (winnerIdx == 0 || winnerIdx == 2));
          if (won) {
            SoundFx.win();
            _feedbackLarge();
            unawaited(HapticFeedback.vibrate().catchError((_) {}));
          } else {
            SoundFx.lose();
          }
          // Series score is computed synchronously — the end card needs
          // it right away (bonuses arrive a moment later, async).
          setState(() {
            if (widget.config.seriesWinsNeeded > 1 &&
                widget.players.length == 2) {
              _seriesScore[winnerIdx]++;
              _seriesDecided =
                  _seriesScore[winnerIdx] >= widget.config.seriesWinsNeeded;
              if (_seriesDecided) {
                // Fire-and-forget: counts a series won by Player 1.
                StatsService.recordSeriesWin(winnerIdx == 0);
              }
            }
            _showEnd = true;
          });
          final wonDailyChallenge =
              won && widget.config.isDailyChallenge;
          CoinsService.awardMatch(won: won).then((earned) {
            if (!mounted || gen != _matchGen) return;
            setState(() {
              _coinsEarned = earned;
              _coinsDone = true;
            });
            // Record the match (history + lifetime/daily stats +
            // achievements + every match-end bonus) once per match;
            // recordMatch is the single payer for all bonuses.
            if (_statsDone) return;
            _statsDone = true;
            StatsService.recordMatch(
              mode: modePackName(widget.config.pack),
              players: widget.players.map((p) => p.name).toList(),
              winner: widget.players[winnerIdx].name,
              durationSeconds: _engine.time.round(),
              tiles: List<int>.from(_engine.tilesPainted),
              powerUps: List<int>.from(_engine.powerUpsCollected),
              coinsEarned: earned,
              won: won,
              vsCrazyWin: won &&
                  widget.config.mode == GameMode.vsBot &&
                  widget.config.botDifficulty == BotDifficulty.crazy,
              playerCount: widget.players.length,
              suddenDeath: widget.config.pack == ModePack.suddenDeath ||
                  widget.config.pack == ModePack.allChaos,
              botDifficulty: widget.config.mode == GameMode.vsBot
                  ? widget.config.botDifficulty
                  : null,
              bestCombo: _engine.matchBestCombo,
              wonDailyChallenge: wonDailyChallenge,
            ).then((result) {
              if (!mounted || gen != _matchGen) return;
              final lines = <String>[];
              for (final m in result.streakMilestones) {
                lines.add('${m.label}! +${m.coins} COINS');
              }
              if (result.challengeBonus > 0) {
                lines.add(
                    'DAILY CHALLENGE WON! +${result.challengeBonus} COINS');
              }
              if (result.streak7Awarded) {
                lines.add('7-DAY STREAK! +300 COINS');
              }
              for (final d in result.botUnlockedNow) {
                lines.add('${botDifficultyName(d).toUpperCase()} UNLOCKED!');
              }
              setState(() {
                _coinsEarned = result.totalCoins;
                _newAchievements = result.achievements;
                _extraLines = lines;
                _comboBonus = result.comboBonus;
                _bestCombo = _engine.matchBestCombo;
              });
            });
          });
        }
  }

  /// Start a fresh match. NEXT MATCH keeps the series score (same
  /// series, next game); REMATCH resets the series and starts a new one.
  void _newMatch({required bool resetSeries}) {
    _matchGen++;
    setState(() {
      _engine = GameEngine(widget.config);
      _pointers.clear();
      _showEnd = false;
      _coinsEarned = 0;
      _coinsDone = false;
      _statsDone = false;
      _newAchievements = <String>[];
      _extraLines = <String>[];
      _comboBonus = 0;
      _bestCombo = 0;
      _paused = false;
      // Sound/haptic baselines restart with the match (see _startLoop).
      _lastPowerUpsTotal = 0;
      _lastBounceCount = 0;
      _lastBounceSoundAt = DateTime.fromMillisecondsSinceEpoch(0);
      // Juice baselines restart too; a pending hit-stop restore from
      // the old match is voided by bumping the id.
      _lastTilesPaintedTotal = 0;
      _lastBigEventCount = 0;
      _lastSmallShakeAt = DateTime.fromMillisecondsSinceEpoch(0);
      _trauma = 0;
      _timeScale = 1.0;
      _hitStopId++;
      _flashUntil = DateTime.fromMillisecondsSinceEpoch(0);
      if (resetSeries) {
        _seriesScore = <int>[0, 0];
        _seriesDecided = false;
      }
    });
    _startLoop();
  }

  void _restartMatch() => _newMatch(resetSeries: true);
  void _nextMatch() => _newMatch(resetSeries: false);

  void _changeSetup() {
    Navigator.pushNamedAndRemoveUntil(
        context, '/setup', (_) => false,
        arguments: widget.config.pack);
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _bgCtrl.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // ---- visible floating joystick steering -------------------------------
  // Zones: 2 players = left/right halves; 3 players = vertical thirds;
  // 4 players = 2x2 quadrants. VS COMPUTER: the whole arena steers P1.
  // The joystick appears where the finger touches down (dynamic origin)
  // and the knob follows the finger; steering = knob offset direction,
  // clamped to kJoystickRadius. It only exists while a finger is down.

  int _playerForLocal(Offset local, Size arenaSize) {
    final n = widget.players.length;
    if (widget.config.mode == GameMode.vsBot || n == 1) return 0;
    final fx = local.dx / arenaSize.width;
    final fy = local.dy / arenaSize.height;
    if (n == 2) return fx < 0.5 ? 0 : 1;
    if (n == 3) return fx < 1 / 3 ? 0 : (fx < 2 / 3 ? 1 : 2);
    return (fy < 0.5 ? 0 : 2) + (fx < 0.5 ? 0 : 1);
  }

  Offset _arenaLocal(Offset globalPosition) {
    final box = _arenaKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return Offset.zero;
    return box.globalToLocal(globalPosition);
  }

  Size _arenaSize() {
    final box = _arenaKey.currentContext?.findRenderObject() as RenderBox?;
    return box?.size ?? Size.zero;
  }

  void _onPointerDown(PointerDownEvent e) {
    if (_showEnd || _paused) return;
    final local = _arenaLocal(e.position);
    final size = _arenaSize();
    if (size == Size.zero) return;
    _pointers[e.pointer] = ActiveJoystick(
        player: _playerForLocal(local, size), origin: local, current: local);
  }

  void _onPointerMove(PointerMoveEvent e) {
    final p = _pointers[e.pointer];
    if (p == null || _showEnd || _paused) return;
    final local = _arenaLocal(e.position);
    p.current = local;
    final d = local - p.origin;
    if (d.distance < 8) return;
    final dir = d / d.distance;
    _engine.steering[p.player] = Point(dir.dx, dir.dy);
    if (_showSteerHint) _showSteerHint = false;
  }

  void _onPointerUp(PointerUpEvent e) => _clearPointer(e.pointer);
  void _onPointerCancel(PointerCancelEvent e) => _clearPointer(e.pointer);

  void _clearPointer(int pointer) {
    final p = _pointers.remove(pointer);
    if (p == null) return;
    // Only release the steering if no other finger steers this player.
    final still = _pointers.values.any((q) => q.player == p.player);
    if (!still) _engine.steering.remove(p.player);
  }

  // ---- layout --------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_showEnd) setState(() => _paused = !_paused);
      },
      child: AnimatedBuilder(
        animation: _bgCtrl,
        builder: (context, _) {
          final gradient = matchGradient(_territoryColors, _bgCtrl.value);
          return Scaffold(
            body: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: gradient,
                ),
              ),
              child: SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    const bannerZoneH = 84.0;
                    const extrasH = 118.0;
                    const verticalPad = 24.0;
                    final bottomBarH =
                        widget.players.length * 14.0 + 8.0;
                    final availW = constraints.maxWidth;
                    final availH = constraints.maxHeight;
                    final arenaW = min(
                        availW - 32,
                        (availH - bannerZoneH - bottomBarH - extrasH - verticalPad) *
                            3 /
                            4);
                    final arenaH = arenaW * 4 / 3;
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _BannerZone(
                            banners: _engine.banners,
                            players: widget.players,
                            width: arenaW,
                            height: bannerZoneH,
                          ),
                          _buildArena(arenaW, arenaH),
                          const SizedBox(height: 14),
                          _TerritoryBar(
                            percentages: _engine.percentages(),
                            players: widget.players,
                            width: arenaW,
                            comeback: _engine.comebackPlayers,
                          ),
                          SizedBox(
                            height: extrasH,
                            width: arenaW,
                            child: _buildExtras(),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildArena(double arenaW, double arenaH) {
    return Listener(
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: _onPointerUp,
      onPointerCancel: _onPointerCancel,
      // Screen shake (game-feel): the Transform moves the arena WIDGET
      // only — the ball/body simulation never moves. It sits inside the
      // Listener, so hit-testing shifts with the visuals and the
      // joystick stays glued to the finger.
      child: Transform.translate(
        offset: _shakeOffset,
        child: Container(
        key: _arenaKey,
        width: arenaW,
        height: arenaH,
        child: Stack(
          children: [
            CustomPaint(
              painter: ArenaPainter(_engine, widget.players, _engine.time,
                  trail: widget.config.trail, interpAlpha: _interpAlpha),
              size: Size(arenaW, arenaH),
            ),
            // Visible floating joysticks (one per active finger), drawn
            // above the tiles and below the pause/end overlays.
            CustomPaint(
              painter: FloatingJoystickPainter(
                  _pointers.values.toList(), _territoryColors),
              size: Size(arenaW, arenaH),
            ),
            // White flash (large tier): a 0.06 s full-arena flash on
            // Bomb / Tsunami / win. Real-time, fades by the ticker.
            // Above the arena and joysticks, below the pause/end cards.
            if (_flashUntil.isAfter(DateTime.now()))
              const Positioned.fill(
                child: IgnorePointer(
                  child: ColoredBox(color: Colors.white54),
                ),
              ),
            if (_paused && !_showEnd) _PauseOverlay(
              onResume: () => setState(() => _paused = false),
              onQuit: () => Navigator.pushNamedAndRemoveUntil(
                  context, '/home', (_) => false),
            ),
            if (_showEnd) _EndCardOverlay(
              engine: _engine,
              players: widget.players,
              coinsEarned: _coinsEarned,
              coinsDone: _coinsDone,
              newAchievements: _newAchievements,
              extraLines: _extraLines,
              bestCombo: _bestCombo,
              comboBonus: _comboBonus,
              seriesScore: _seriesScore,
              seriesNeeded: widget.config.seriesWinsNeeded,
              seriesDecided: _seriesDecided,
              onNextMatch: _nextMatch,
              onRematch: _restartMatch,
              onChangeSetup: _changeSetup,
              onHome: () => Navigator.pushNamedAndRemoveUntil(
                  context, '/home', (_) => false),
            ),
          ],
        ),
        ),
      ),
    );
  }

  Widget _buildExtras() {
    final children = <Widget>[];
    if (_showSteerHint && !_showEnd) {
      children.add(Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Align(
          alignment: Alignment.center,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: DcColors.bar.withOpacity(0.95),
              borderRadius:
                  const BorderRadius.all(Radius.circular(999)),
              border: Border.all(color: DcColors.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.35),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Text('TOUCH AND DRAG TO STEER',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    letterSpacing: 1,
                    color: Colors.white)),
          ),
        ),
      ));
    }
    if (_engine.chaosEnabled &&
        _engine.chaosName.isNotEmpty &&
        _engine.time < _engine.chaosUntil) {
      children.add(Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text('CHAOS: ${_engine.chaosName}',
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 14,
                color: Colors.white)),
      ));
    }
    if (_engine.suddenDeathEnabled && _engine.timeLeft <= 10) {
      children.add(const Padding(
        padding: EdgeInsets.only(top: 8),
        child: Text('SUDDEN DEATH — ARENA SHRINKING',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 14,
                color: Color(0xFFFF5252))),
      ));
    }
    if (_engine.ultimateEnabled) {
      for (var i = 0; i < widget.players.length; i++) {
        if (_engine.eliminated.contains(i)) continue;
        final meter = _engine.ultimateMeters[i];
        final ready = meter >= 100;
        final color = Color(widget.players[i].colour.value);
        children.add(Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(
            children: [
              SizedBox(
                width: 52,
                child: Text(widget.players[i].name.toUpperCase(),
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: Colors.white),
                    overflow: TextOverflow.ellipsis),
              ),
              Expanded(
                child: Container(
                  height: 10,
                  color: Colors.white.withOpacity(0.18),
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: (meter / 100).clamp(0.0, 1.0),
                    child: Container(color: color),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              SizedBox(
                height: 30,
                child: TextButton(
                  onPressed: ready
                      ? () {
                          if (_engine.tsunami(i)) {
                            SoundFx.pickup();
                            setState(() {});
                          }
                        }
                      : null,
                  style: TextButton.styleFrom(
                    backgroundColor:
                        ready ? color : Colors.white.withOpacity(0.15),
                    foregroundColor: ready
                        ? contrastTextColor(color)
                        : Colors.white70,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10),
                    shape: const StadiumBorder(),
                    textStyle: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w900),
                  ),
                  child: const Text('TSUNAMI'),
                ),
              ),
            ],
          ),
        ));
      }
    }
    // Scrollable so a hint line + chaos + sudden-death + up to 4 ultimate
    // meters can never overflow the fixed-height extras zone.
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

/// Stacked power-up banners: chunky rounded full-arena-width bars in
/// the top margin, newest on top, background = activator's colour,
/// contrasting extra-bold caps name + a one-line "what it does"
/// underneath, soft drop shadow. Two banners max (38 px each) so they
/// always fit the 84 px zone. The name is only 13 px, so no outline
/// stroke — plain heavy type (a stroke would fill the counters).
class _BannerZone extends StatelessWidget {
  const _BannerZone(
      {required this.banners,
      required this.players,
      required this.width,
      required this.height});
  final List<MatchBanner> banners;
  final List<PlayerConfig> players;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final visible = banners.reversed.take(2).toList();
    return SizedBox(
      width: width,
      height: height,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: visible.map((b) {
          final bg = Color(players[b.player].colour.value);
          final fg = contrastTextColor(bg);
          final hasEffect = b.effect.isNotEmpty;
          return Container(
            width: width,
            height: hasEffect ? 38 : 24,
            margin: const EdgeInsets.only(bottom: 2),
            decoration: BoxDecoration(
              color: bg,
              borderRadius:
                  const BorderRadius.all(Radius.circular(10)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.35),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  b.text.toUpperCase(),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: fg,
                    letterSpacing: 1,
                  ),
                ),
                if (hasEffect)
                  Text(
                    b.effect,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: fg.withOpacity(0.9),
                    ),
                  ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// Bottom territory bar: one thin row per player — name label + ball dot +
/// translucent track with a fill proportional to the share + a fixed tick.
/// No percentage numbers (the reference prints none). Tiny Clash chrome:
/// the rows sit in a dark-navy pill with rounded tracks and gold accents.
/// A player on a comeback boost (trailing by 40+ tiles) gets a small
/// gold COMEBACK tag after their track.
class _TerritoryBar extends StatelessWidget {
  const _TerritoryBar(
      {required this.percentages,
      required this.players,
      required this.width,
      this.comeback = const <int>{}});
  final List<double> percentages;
  final List<PlayerConfig> players;
  final double width;
  final Set<int> comeback;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: DcColors.bar,
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        border: Border.all(color: DcColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(players.length, (i) {
          final color = Color(players[i].colour.value);
          final share = (percentages[i] / 100).clamp(0.0, 1.0);
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                SizedBox(
                  width: 64,
                  child: Text(players[i].name.toUpperCase(),
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: DcColors.text),
                      overflow: TextOverflow.ellipsis),
                ),
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                      color: cueBallColor(color), shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, c) {
                      return Container(
                        height: 10,
                        decoration: const BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.all(
                              Radius.circular(999)),
                        ),
                        child: Stack(
                          children: [
                            FractionallySizedBox(
                              widthFactor: share,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: color,
                                  borderRadius: const BorderRadius.all(
                                      Radius.circular(999)),
                                ),
                              ),
                            ),
                            Positioned(
                              left: c.maxWidth * 0.86,
                              top: 0,
                              bottom: 0,
                              width: 2,
                              child: Container(
                                  color: Colors.white.withOpacity(0.6)),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                if (comeback.contains(i)) ...[
                  const SizedBox(width: 6),
                  const Text('COMEBACK',
                      style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          color: DcColors.gold)),
                ],
              ],
            ),
          );
        }),
      ),
    );
  }
}

/// Pause overlay (opened by the system back button): dimmed playfield
/// + a chunky navy card with a gradient RESUME button.
class _PauseOverlay extends StatelessWidget {
  const _PauseOverlay({required this.onResume, required this.onQuit});
  final VoidCallback onResume;
  final VoidCallback onQuit;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withOpacity(0.6),
      alignment: Alignment.center,
      child: DcCard(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const TcOutlined(
              'PAUSED',
              fontSize: 32,
              letterSpacing: 2,
              textAlign: TextAlign.center,
              height: 1.0,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: 200,
              child: DcPillButton(
                label: 'RESUME',
                height: 52,
                fontSize: 16,
                onPressed: onResume,
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: 200,
              child: DcSecondaryButton(
                label: 'QUIT TO HOME',
                height: 52,
                fontSize: 16,
                onPressed: onQuit,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// End card: the whole playfield dims to near-black, then a chunky
/// navy card (winner-colour border, gold crown, winner name in heavy
/// outlined caps, match duration). Below it: match stats (tiles
/// painted, power-ups, biggest lead, best combo), newly unlocked
/// achievements, bonus announcements (streak milestones, daily challenge,
/// 7-day streak, bot unlocks), coins, and actions — NEXT MATCH while a
/// best-of series is undecided, REMATCH (new series) once it is decided,
/// CHANGE SETUP (same mode, new picks), HOME. No confetti, no emoji.
/// A series win shows "<NAME> WINS THE SERIES!" instead of DOMINATES.
class _EndCardOverlay extends StatelessWidget {
  const _EndCardOverlay({
    required this.engine,
    required this.players,
    required this.coinsEarned,
    required this.coinsDone,
    required this.newAchievements,
    this.extraLines = const <String>[],
    this.bestCombo = 0,
    this.comboBonus = 0,
    this.seriesScore = const <int>[0, 0],
    this.seriesNeeded = 1,
    this.seriesDecided = false,
    this.onNextMatch,
    required this.onRematch,
    required this.onChangeSetup,
    required this.onHome,
  });
  final GameEngine engine;
  final List<PlayerConfig> players;
  final int coinsEarned;
  final bool coinsDone;
  final List<String> newAchievements;
  final List<String> extraLines;
  final int bestCombo;
  final int comboBonus;
  final List<int> seriesScore;
  final int seriesNeeded;
  final bool seriesDecided;
  final VoidCallback? onNextMatch;
  final VoidCallback onRematch;
  final VoidCallback onChangeSetup;
  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) {
    final winnerIndex = engine.winnerIndex();
    final winner = players[winnerIndex];
    final bg = Color(winner.colour.value);
    final inSeries = seriesNeeded > 1 && players.length == 2;
    final seriesWinner =
        seriesDecided ? (seriesScore[0] >= seriesNeeded ? 0 : 1) : -1;
    final title = seriesDecided
        ? '${players[seriesWinner].name.toUpperCase()} WINS THE SERIES!'
        : engine.winnerLabel();
    return Container(
      color: Colors.black.withOpacity(0.85),
      alignment: Alignment.center,
      child: LayoutBuilder(
        builder: (context, c) {
          final cardW = c.maxWidth * 0.72;
          return SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: cardW,
                  padding:
                      const EdgeInsets.fromLTRB(20, 22, 20, 20),
                  decoration: BoxDecoration(
                    color: DcColors.panel,
                    borderRadius: const BorderRadius.all(
                        Radius.circular(20)),
                    border: Border.all(color: bg, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.5),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CustomPaint(
                        size: const Size(34, 24),
                        painter: _CrownPainter(DcColors.gold),
                      ),
                      const SizedBox(height: 10),
                      TcOutlined(
                        title,
                        fontSize: 22,
                        letterSpacing: 1,
                        textAlign: TextAlign.center,
                        height: 1.1,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        engine.matchDurationLabel(),
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: DcColors.muted),
                      ),
                    ],
                  ),
                ),
                if (inSeries)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      'SERIES  ${players[0].name.toUpperCase()} ${seriesScore[0]} — ${seriesScore[1]} ${players[1].name.toUpperCase()}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: Colors.white),
                    ),
                  ),
                // Match stats (one-line rows).
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Column(
                    children: [
                      _StatLine(
                        'TILES PAINTED',
                        players
                            .asMap()
                            .entries
                            .map((e) =>
                                '${e.value.name.toUpperCase()} ${engine.tilesPainted[e.key]}')
                            .join('  ·  '),
                      ),
                      _StatLine(
                        'POWER-UPS',
                        players
                            .asMap()
                            .entries
                            .map((e) =>
                                '${e.value.name.toUpperCase()} ${engine.powerUpsCollected[e.key]}')
                            .join('  ·  '),
                      ),
                      _StatLine('BIGGEST LEAD',
                          '${engine.biggestLead} tiles'),
                      if (bestCombo >= 5)
                        _StatLine('BEST COMBO',
                            'x$bestCombo  (+$comboBonus COINS)'),
                    ],
                  ),
                ),
                if (newAchievements.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Column(
                      children: newAchievements.map((id) {
                        final a = achievementById(id);
                        return Text(
                          'ACHIEVEMENT UNLOCKED: ${a.name.toUpperCase()}  (+${a.reward} COINS)',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              color: DcColors.gold),
                        );
                      }).toList(),
                    ),
                  ),
                if (extraLines.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Column(
                      children: extraLines.map((line) {
                        return Text(
                          line,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              color: DcColors.gold),
                        );
                      }).toList(),
                    ),
                  ),
                if (coinsDone)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text('+$coinsEarned COINS  (TOTAL: ${CoinsService.coins})',
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: DcColors.gold)),
                  ),
                const SizedBox(height: 18),
                SizedBox(
                  width: cardW,
                  child: DcPillButton(
                    label: inSeries && !seriesDecided
                        ? 'NEXT MATCH'
                        : 'REMATCH',
                    height: 52,
                    fontSize: 16,
                    onPressed:
                        inSeries && !seriesDecided ? onNextMatch : onRematch,
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: cardW,
                  child: DcSecondaryButton(
                    label: 'CHANGE SETUP',
                    height: 52,
                    fontSize: 16,
                    onPressed: onChangeSetup,
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: cardW,
                  child: DcSecondaryButton(
                    label: 'HOME',
                    height: 52,
                    fontSize: 16,
                    onPressed: onHome,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// One match-stat line: small grey label + white value.
class _StatLine extends StatelessWidget {
  const _StatLine(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
                text: '$label  ',
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: DcColors.muted)),
            TextSpan(
                text: value,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: Colors.white)),
          ],
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

/// Drawn crown glyph (reference end card uses a drawn crown, not an emoji).
class _CrownPainter extends CustomPainter {
  _CrownPainter(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final p = Path();
    p.moveTo(0, size.height);
    p.lineTo(0, size.height * 0.45);
    p.lineTo(size.width * 0.22, size.height * 0.7);
    p.lineTo(size.width * 0.5, size.height * 0.1);
    p.lineTo(size.width * 0.78, size.height * 0.7);
    p.lineTo(size.width, size.height * 0.45);
    p.lineTo(size.width, size.height);
    p.close();
    canvas.drawPath(p, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _CrownPainter old) => old.color != color;
}
