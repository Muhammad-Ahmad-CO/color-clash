// Colour Clash — Game screen.
// 60fps loop (Timer every 16ms). Arena + joysticks + timer + banner
// + territory bar. At 0 seconds, go to the Result screen.
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../data/game_data.dart';
import '../game/engine.dart';
import '../game/sound.dart';
import '../widgets/ball_painter.dart';
import '../widgets/joystick.dart';
import 'result_screen.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key, required this.config});
  final MatchConfig config;
  List<PlayerConfig> get players => config.players;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late GameEngine _engine;
  Timer? _timer;
  bool _paused = false;
  String _lastBanner = '';
  int _countdown = 3;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _engine = GameEngine(widget.config);
    // 3-2-1 countdown, then the balls start moving.
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_countdown > 1) {
        setState(() => _countdown--);
      } else {
        t.cancel();
        setState(() => _countdown = 0);
        _startLoop();
      }
    });
  }

  void _startLoop() {
    _timer = Timer.periodic(const Duration(milliseconds: 16), (_) {
      if (_paused || !mounted) return;
      setState(() {
        _engine.step(0.016);
        if (_engine.bannerText.isNotEmpty && _engine.bannerText != _lastBanner) {
          _lastBanner = _engine.bannerText;
          SoundFx.pickup();
        }
        if (_engine.finished) {
          _timer?.cancel();
          SoundFx.win();
          final args = ResultArgs(
            players: widget.players,
            percentages: _engine.percentages(),
            winnerIndex: _engine.winnerIndex(),
            winnerLabel: _engine.winnerLabel(),
            config: widget.config,
          );
          Navigator.pushReplacementNamed(context, '/result', arguments: args);
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  String _timeText() {
    final s = _engine.timeLeft.ceil();
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final pcts = _engine.percentages();
    final bannerVisible =
        _engine.bannerText.isNotEmpty && _engine.time < _engine.bannerUntil;
    return Scaffold(
      backgroundColor: const Color(0xFF1A1033),
      body: SafeArea(
        child: Column(
          children: [
            // Top bar: timer, pause, sound.
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white12,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _timeText(),
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.players.map((p) => p.name).join('  vs  '),
                      style: const TextStyle(fontSize: 13, color: Colors.white70, fontWeight: FontWeight.w700),
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  IconButton(
                    icon: Icon(SoundFx.muted ? Icons.volume_off : Icons.volume_up, size: 26),
                    onPressed: () => setState(() {
                      SoundFx.muted = !SoundFx.muted;
                      if (!SoundFx.muted) SoundFx.click();
                    }),
                  ),
                  IconButton(
                    icon: Icon(_paused ? Icons.play_arrow : Icons.pause, size: 28),
                    onPressed: () => setState(() => _paused = !_paused),
                  ),
                ],
              ),
            ),
            // Power-up banner (animated in/out).
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: bannerVisible
                  ? Container(
                      key: ValueKey(_engine.bannerText + _engine.bannerUntil.toString()),
                      width: double.infinity,
                      margin: const EdgeInsets.symmetric(horizontal: 12),
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      decoration: BoxDecoration(
                        color: Color(widget.players[_engine.bannerPlayer].colour.value),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _engine.bannerText,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1),
                      ),
                    )
                  : const SizedBox(key: ValueKey('no-banner'), height: 8),
            ),
            const SizedBox(height: 6),
            // Arena with joysticks overlaid in the corners.
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final arenaW = constraints.maxWidth;
                    final arenaH = arenaW * _engine.rows / _engine.cols;
                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: arenaW,
                          height: arenaH,
                          decoration: BoxDecoration(
                            color: const Color(0xFF241A45),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white24, width: 2),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: CustomPaint(
                              painter: ArenaPainter(_engine, widget.players, _engine.time, trail: widget.config.trail),
                              size: Size(arenaW, arenaH),
                            ),
                          ),
                        ),
                        if (_countdown > 0)
                          Container(
                            width: arenaW,
                            height: arenaH,
                            decoration: BoxDecoration(
                                color: Colors.black54, borderRadius: BorderRadius.circular(12)),
                            alignment: Alignment.center,
                            child: Text(
                              '$_countdown',
                              style: const TextStyle(
                                  fontSize: 90, fontWeight: FontWeight.w900, color: Colors.white),
                            ),
                          ),
                        if (_paused && _countdown == 0)
                          Container(
                            width: arenaW,
                            height: arenaH,
                            decoration: BoxDecoration(
                                color: Colors.black54, borderRadius: BorderRadius.circular(12)),
                            alignment: Alignment.center,
                            child: const Text('PAUSED',
                                style: TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: Colors.white)),
                          ),
                        // Joysticks: P1 bottom-left, P2 bottom-right,
                        // P3 top-centre (3P) or top-left (4P), P4 top-right.
                        Positioned(
                          left: 6,
                          bottom: 6,
                          child: Joystick(
                            label: 'P1',
                            color: Color(widget.players[0].colour.value),
                            onDirection: (d) {
                              _engine.steering[0] =
                                  d == null ? const Point(0, 0) : Point(d.dx, d.dy);
                              if (d == null) _engine.steering.remove(0);
                            },
                          ),
                        ),
                        if (widget.config.mode != GameMode.vsBot)
                        Positioned(
                          right: 6,
                          bottom: 6,
                          child: Joystick(
                            label: 'P2',
                            color: Color(widget.players[1].colour.value),
                            onDirection: (d) {
                              if (d == null) {
                                _engine.steering.remove(1);
                              } else {
                                _engine.steering[1] = Point(d.dx, d.dy);
                              }
                            },
                          ),
                        ),
                        if (widget.config.mode == GameMode.vsBot)
                          const Positioned(
                            right: 10,
                            bottom: 10,
                            child: Chip(
                              label: Text('🤖 BOT', style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white)),
                              backgroundColor: Colors.black54,
                            ),
                          ),
                        if (widget.players.length >= 3)
                          Positioned(
                            left: widget.players.length == 3 ? null : 6,
                            right: widget.players.length == 3 ? null : null,
                            top: 6,
                            child: Joystick(
                              label: 'P3',
                              color: Color(widget.players[2].colour.value),
                              onDirection: (d) {
                                if (d == null) {
                                  _engine.steering.remove(2);
                                } else {
                                  _engine.steering[2] = Point(d.dx, d.dy);
                                }
                              },
                            ),
                          ),
                        if (widget.players.length == 4)
                          Positioned(
                            right: 6,
                            top: 6,
                            child: Joystick(
                              label: 'P4',
                              color: Color(widget.players[3].colour.value),
                              onDirection: (d) {
                                if (d == null) {
                                  _engine.steering.remove(3);
                                } else {
                                  _engine.steering[3] = Point(d.dx, d.dy);
                                }
                              },
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),
            if (_engine.ultimateEnabled || _engine.chaosEnabled || _engine.suddenDeathEnabled)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: Column(
                  children: [
                    if (_engine.chaosEnabled && _engine.chaosName.isNotEmpty && _engine.time < _engine.chaosUntil)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        decoration: BoxDecoration(
                            color: Colors.deepOrange.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(8)),
                        child: Text('🌪️ CHAOS: ${_engine.chaosName}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
                      ),
                    if (_engine.suddenDeathEnabled && _engine.timeLeft <= 10)
                      const Text('⏳ SUDDEN DEATH — ARENA SHRINKING!',
                          style: TextStyle(fontWeight: FontWeight.w900, color: Colors.redAccent, fontSize: 14)),
                    if (_engine.ultimateEnabled)
                      ...List.generate(widget.players.length, (i) {
                        final meter = _engine.ultimateMeters[i];
                        final ready = meter >= 100;
                        final eliminated = _engine.eliminated.contains(i);
                        if (eliminated) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 52,
                                child: Text(widget.players[i].name,
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                                    overflow: TextOverflow.ellipsis),
                              ),
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: LinearProgressIndicator(
                                    value: meter / 100,
                                    minHeight: 10,
                                    backgroundColor: Colors.white12,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Color(widget.players[i].colour.value)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              SizedBox(
                                height: 30,
                                child: ElevatedButton(
                                  onPressed: ready
                                      ? () {
                                          if (_engine.tsunami(i)) {
                                            SoundFx.pickup();
                                            setState(() {});
                                          }
                                        }
                                      : null,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Color(widget.players[i].colour.value),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 10),
                                    textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
                                  ),
                                  child: Text(ready ? '⚡ TSUNAMI' : '${meter.round()}%'),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                  ],
                ),
              ),
            const SizedBox(height: 10),
            // Territory bar: one segment per player, sized by %.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Row(
                      children: List.generate(widget.players.length, (i) {
                        final flex = max(1, pcts[i].round());
                        return Expanded(
                          flex: flex,
                          child: Container(
                            height: 26,
                            color: Color(widget.players[i].colour.value),
                            alignment: Alignment.center,
                            child: pcts[i] >= 12
                                ? Text('${pcts[i].round()}%',
                                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Colors.white))
                                : const SizedBox.shrink(),
                          ),
                        );
                      }),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(widget.players.length, (i) {
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                              width: 12, height: 12,
                              decoration: BoxDecoration(
                                  color: Color(widget.players[i].colour.value),
                                  shape: BoxShape.circle)),
                          const SizedBox(width: 4),
                          Text(widget.players[i].name,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                        ],
                      );
                    }),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}
