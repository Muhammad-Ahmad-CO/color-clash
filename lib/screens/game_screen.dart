// Color Cover — Game screen (reference look, REFERENCE_UI_SPEC.md).
// Animated gradient background derived from the player colours, a 3:4
// arena floating in it, sharp full-width power-up banners stacked in the
// top margin, thin bottom territory bars, and the end card as a flat overlay
// on the dimmed playfield. No timer, no names, no pause/mute HUD, no %
// numbers, no emoji anywhere on the match screen.
// Steering: a VISIBLE floating joystick appears where the player's finger
// touches down (dynamic origin) and follows the finger — the user asked
// for a joystick they can see (03:51 PKT), so the invisible drag of v2
// is replaced by a visible control on top of the same anchor logic.
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data/game_data.dart';
import '../game/coins.dart';
import '../game/engine.dart';
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
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late GameEngine _engine;
  Timer? _timer;
  late AnimationController _bgCtrl;
  bool _paused = false;
  bool _showEnd = false;
  int _coinsEarned = 0;
  bool _coinsDone = false;
  bool _statsDone = false; // match recorded once per match.
  List<String> _newAchievements = <String>[];
  final GlobalKey _arenaKey = GlobalKey();

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
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 16), (_) {
      if (_paused || !mounted) return;
      setState(() {
        _engine.step(0.016);
        if (_engine.finished && !_showEnd) {
          _timer?.cancel();
          SoundFx.win();
          final won = _engine.winnerIndex() == 0 ||
              (widget.config.mode == GameMode.team2v2 &&
                  (_engine.winnerIndex() == 0 ||
                      _engine.winnerIndex() == 2));
          CoinsService.awardMatch(won: won).then((earned) {
            if (!mounted) return;
            setState(() {
              _coinsEarned = earned;
              _coinsDone = true;
            });
            // Record the match (history + lifetime stats + achievements)
            // once per match; rewards for newly unlocked badges are paid
            // in coins by StatsService.
            if (_statsDone) return;
            _statsDone = true;
            StatsService.recordMatch(
              mode: modePackName(widget.config.pack),
              players: widget.players.map((p) => p.name).toList(),
              winner: widget.players[_engine.winnerIndex()].name,
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
            ).then((unlocked) {
              if (mounted && unlocked.isNotEmpty) {
                setState(() => _newAchievements = unlocked);
              }
            });
          });
          setState(() => _showEnd = true);
        }
      });
    });
  }

  void _restartMatch() {
    setState(() {
      _engine = GameEngine(widget.config);
      _pointers.clear();
      _showEnd = false;
      _coinsEarned = 0;
      _coinsDone = false;
      _statsDone = false;
      _newAchievements = <String>[];
      _paused = false;
    });
    _startLoop();
  }

  void _changeSetup() {
    Navigator.pushNamedAndRemoveUntil(
        context, '/setup', (_) => false,
        arguments: widget.config.pack);
  }

  @override
  void dispose() {
    _timer?.cancel();
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
      child: Container(
        key: _arenaKey,
        width: arenaW,
        height: arenaH,
        child: Stack(
          children: [
            CustomPaint(
              painter: ArenaPainter(_engine, widget.players, _engine.time,
                  trail: widget.config.trail),
              size: Size(arenaW, arenaH),
            ),
            // Visible floating joysticks (one per active finger), drawn
            // above the tiles and below the pause/end overlays.
            CustomPaint(
              painter: FloatingJoystickPainter(
                  _pointers.values.toList(), _territoryColors),
              size: Size(arenaW, arenaH),
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
              onRematch: _restartMatch,
              onChangeSetup: _changeSetup,
              onHome: () => Navigator.pushNamedAndRemoveUntil(
                  context, '/home', (_) => false),
            ),
          ],
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
              color: Colors.white.withOpacity(0.92),
              borderRadius:
                  const BorderRadius.all(Radius.circular(999)),
            ),
            child: const Text('TOUCH AND DRAG TO STEER',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    letterSpacing: 1,
                    color: DcColors.text)),
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

/// Stacked power-up banners: sharp full-arena-width bars in the top
/// margin, newest on top, background = activator's colour, contrasting
/// extra-bold caps name + a one-line "what it does" underneath. Two
/// banners max (38 px each) so they always fit the 84 px zone.
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
            color: bg,
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
/// No percentage numbers (the reference prints none). Dot Clash chrome:
/// the rows sit in a clean off-white card instead of floating on the
/// gradient — same content, same reference numbers (none).
class _TerritoryBar extends StatelessWidget {
  const _TerritoryBar(
      {required this.percentages,
      required this.players,
      required this.width});
  final List<double> percentages;
  final List<PlayerConfig> players;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: DcColors.card,
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        border: Border.all(color: DcColors.border),
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
                        color: Colors.black.withOpacity(0.08),
                        child: Stack(
                          children: [
                            FractionallySizedBox(
                              widthFactor: share,
                              child: Container(color: color),
                            ),
                            Positioned(
                              left: c.maxWidth * 0.86,
                              top: 0,
                              bottom: 0,
                              width: 2,
                              child: Container(
                                  color: Colors.black.withOpacity(0.3)),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

/// Pause overlay (opened by the system back button): flat, no icons.
class _PauseOverlay extends StatelessWidget {
  const _PauseOverlay({required this.onResume, required this.onQuit});
  final VoidCallback onResume;
  final VoidCallback onQuit;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withOpacity(0.6),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('PAUSED',
              style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: Colors.white)),
          const SizedBox(height: 16),
          SizedBox(
            width: 180,
            child: TextButton(
              onPressed: onResume,
              style: TextButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: const StadiumBorder(),
                textStyle: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w900),
              ),
              child: const Text('RESUME'),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: 180,
            child: TextButton(
              onPressed: onQuit,
              style: TextButton.styleFrom(
                backgroundColor: Colors.white24,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: const StadiumBorder(),
                textStyle: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w900),
              ),
              child: const Text('QUIT TO HOME'),
            ),
          ),
        ],
      ),
    );
  }
}

/// End card: the whole playfield dims to near-black, then a flat
/// winner-colour rectangle (sharp corners) with a drawn crown,
/// "<NAME> DOMINATES!" and the match duration. Below it: match stats
/// (tiles painted, power-ups, biggest lead), newly unlocked achievements,
/// coins, and three actions — REMATCH (same setup), CHANGE SETUP (same
/// mode, new picks), HOME. No confetti, no emoji.
class _EndCardOverlay extends StatelessWidget {
  const _EndCardOverlay({
    required this.engine,
    required this.players,
    required this.coinsEarned,
    required this.coinsDone,
    required this.newAchievements,
    required this.onRematch,
    required this.onChangeSetup,
    required this.onHome,
  });
  final GameEngine engine;
  final List<PlayerConfig> players;
  final int coinsEarned;
  final bool coinsDone;
  final List<String> newAchievements;
  final VoidCallback onRematch;
  final VoidCallback onChangeSetup;
  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) {
    final winnerIndex = engine.winnerIndex();
    final winner = players[winnerIndex];
    final bg = Color(winner.colour.value);
    final fg = contrastTextColor(bg);
    return Container(
      color: Colors.black.withOpacity(0.85),
      alignment: Alignment.center,
      child: LayoutBuilder(
        builder: (context, c) {
          final cardW = c.maxWidth * 0.66;
          final cardH = c.maxHeight * 0.24;
          return SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: cardW,
                  height: cardH,
                  color: bg,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CustomPaint(
                        size: const Size(28, 20),
                        painter: _CrownPainter(fg),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        engine.winnerLabel(),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                            color: fg),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        engine.matchDurationLabel(),
                        style: TextStyle(fontSize: 12, color: fg),
                      ),
                    ],
                  ),
                ),
                // Match stats (Dot Clash-style one-line rows).
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
                              color: Color(0xFFFFCA28)),
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
                            color: Color(0xFFFFCA28))),
                  ),
                const SizedBox(height: 18),
                SizedBox(
                  width: cardW,
                  child: TextButton(
                    onPressed: onRematch,
                    style: TextButton.styleFrom(
                      backgroundColor: bg,
                      foregroundColor: fg,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: const StadiumBorder(),
                      textStyle: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w900),
                    ),
                    child: const Text('REMATCH'),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: cardW,
                  child: TextButton(
                    onPressed: onChangeSetup,
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: const StadiumBorder(),
                      textStyle: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w900),
                    ),
                    child: const Text('CHANGE SETUP'),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: cardW,
                  child: TextButton(
                    onPressed: onHome,
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.white24,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: const StadiumBorder(),
                      textStyle: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w900),
                    ),
                    child: const Text('HOME'),
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
                    color: Colors.white60)),
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
