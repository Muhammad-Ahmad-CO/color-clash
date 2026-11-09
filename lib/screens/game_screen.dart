// Color Cover — Game screen (reference look, REFERENCE_UI_SPEC.md).
// Animated gradient background derived from the player colours, a 3:4
// arena floating in it, sharp full-width power-up banners stacked in the
// top margin, thin bottom territory bars, invisible drag steering
// (multi-touch zones, no joysticks), and the end card as a flat overlay
// on the dimmed playfield. No timer, no names, no pause/mute HUD, no %
// numbers, no emoji anywhere on the match screen.
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../data/game_data.dart';
import '../game/coins.dart';
import '../game/engine.dart';
import '../game/match_theme.dart';
import '../game/sound.dart';
import '../widgets/ball_painter.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key, required this.config});
  final MatchConfig config;
  List<PlayerConfig> get players => config.players;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with SingleTickerProviderStateMixin {
  late GameEngine _engine;
  Timer? _timer;
  late AnimationController _bgCtrl;
  bool _paused = false;
  bool _showEnd = false;
  int _coinsEarned = 0;
  bool _coinsDone = false;
  final GlobalKey _arenaKey = GlobalKey();

  // Active drag pointers: pointer id -> (player, anchor position).
  final Map<int, _DragPointer> _pointers = <int, _DragPointer>{};

  List<Color> get _territoryColors =>
      widget.players.map((p) => Color(p.colour.value)).toList();

  @override
  void initState() {
    super.initState();
    _engine = GameEngine(widget.config);
    _bgCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat(reverse: true);
    _startLoop();
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
            if (mounted) {
              setState(() {
                _coinsEarned = earned;
                _coinsDone = true;
              });
            }
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
      _paused = false;
    });
    _startLoop();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _bgCtrl.dispose();
    super.dispose();
  }

  // ---- invisible drag steering -------------------------------------------
  // Zones: 2 players = left/right halves; 3 players = vertical thirds;
  // 4 players = 2x2 quadrants. VS COMPUTER: the whole arena steers P1.

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
    _pointers[e.pointer] = _DragPointer(_playerForLocal(local, size), local);
  }

  void _onPointerMove(PointerMoveEvent e) {
    final p = _pointers[e.pointer];
    if (p == null || _showEnd || _paused) return;
    final local = _arenaLocal(e.position);
    final d = local - p.anchor;
    if (d.distance < 8) return;
    final dir = d / d.distance;
    _engine.steering[p.player] = Point(dir.dx, dir.dy);
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
              onPlayAgain: _restartMatch,
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
                    shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.zero),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }
}

class _DragPointer {
  _DragPointer(this.player, this.anchor);
  final int player;
  final Offset anchor;
}

/// Stacked power-up banners: sharp full-arena-width bars in the top
/// margin, newest on top, background = activator's colour, contrasting
/// extra-bold caps text. Empty gradient when nothing is active.
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
    final visible = banners.reversed.take(3).toList();
    return SizedBox(
      width: width,
      height: height,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: visible.map((b) {
          final bg = Color(players[b.player].colour.value);
          return Container(
            width: width,
            height: 24,
            margin: const EdgeInsets.only(bottom: 2),
            color: bg,
            alignment: Alignment.center,
            child: Text(
              b.text.toUpperCase(),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: contrastTextColor(bg),
                letterSpacing: 1,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// Bottom territory bar: one thin row per player — name label + ball dot +
/// translucent track with a fill proportional to the share + a fixed tick.
/// No percentage numbers (the reference prints none).
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
    return SizedBox(
      width: width,
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
                          color: Colors.white),
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
                        color: Colors.white.withOpacity(0.18),
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
                                  color: Colors.white.withOpacity(0.6)),
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
                shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.zero),
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
                shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.zero),
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
/// "<NAME> DOMINATES!" and the match duration. No confetti, no emoji.
class _EndCardOverlay extends StatelessWidget {
  const _EndCardOverlay({
    required this.engine,
    required this.players,
    required this.coinsEarned,
    required this.coinsDone,
    required this.onPlayAgain,
    required this.onHome,
  });
  final GameEngine engine;
  final List<PlayerConfig> players;
  final int coinsEarned;
  final bool coinsDone;
  final VoidCallback onPlayAgain;
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
          return Column(
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
                  onPressed: onPlayAgain,
                  style: TextButton.styleFrom(
                    backgroundColor: bg,
                    foregroundColor: fg,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.zero),
                    textStyle: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w900),
                  ),
                  child: const Text('PLAY AGAIN'),
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
                    shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.zero),
                    textStyle: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w900),
                  ),
                  child: const Text('HOME'),
                ),
              ),
            ],
          );
        },
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
