// Colour Clash — Result screen.
// Winner celebration: animated confetti + "X DOMINATES!" + % per player.
import 'dart:math';
import 'package:flutter/material.dart';
import '../data/game_data.dart';
import '../game/coins.dart';
import '../game/sound.dart';
import '../main.dart';

class ResultArgs {
  ResultArgs(
      {required this.players,
      required this.percentages,
      required this.winnerIndex,
      this.winnerLabel,
      this.config});
  final List<PlayerConfig> players;
  final List<double> percentages;
  final int winnerIndex;
  final String? winnerLabel;
  final MatchConfig? config;
}

class ResultScreen extends StatefulWidget {
  const ResultScreen({super.key, required this.args});
  final ResultArgs args;
  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  int _coinsEarned = 0;
  bool _coinsDone = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..repeat();
    // Coins: win = 50, any finished match = 10. P1 is "you" for Vs Bot;
    // in multiplayer the winner is the human who won, so award on win.
    final won = widget.args.winnerIndex == 0 ||
        (widget.args.config?.mode == GameMode.team2v2 &&
            (widget.args.winnerIndex == 0 || widget.args.winnerIndex == 2));
    CoinsService.awardMatch(won: won).then((earned) {
      if (mounted) setState(() {
        _coinsEarned = earned;
        _coinsDone = true;
      });
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final winner = widget.args.players[widget.args.winnerIndex];
    final order = List<int>.generate(widget.args.players.length, (i) => i)
      ..sort((a, b) => widget.args.percentages[b].compareTo(widget.args.percentages[a]));
    return Scaffold(
      body: Stack(
        children: [
          AnimatedBuilder(
            animation: _ctrl,
            builder: (_, __) => CustomPaint(
              painter: _ConfettiPainter(_ctrl.value, Color(winner.colour.value)),
              size: Size.infinite,
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 30),
                  const Text('🏆', textAlign: TextAlign.center, style: TextStyle(fontSize: 64)),
                  const SizedBox(height: 8),
                  Text(
                    widget.args.winnerLabel ?? '${winner.name.toUpperCase()} DOMINATES!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      color: Color(winner.colour.value),
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${widget.args.percentages[widget.args.winnerIndex].round()}% of the arena',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 19, color: Colors.white70),
                  ),
                  if (_coinsDone)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text('🪙 +$_coinsEarned coins earned!  (Total: ${CoinsService.coins})',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFFFFCA28))),
                    ),
                  const SizedBox(height: 24),
                  ...order.map((i) {
                    final p = widget.args.players[i];
                    final pct = widget.args.percentages[i];
                    final isWinner = i == widget.args.winnerIndex;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: isWinner ? Color(p.colour.value) : Colors.white24,
                            width: isWinner ? 2.5 : 1),
                      ),
                      child: Row(
                        children: [
                          Container(
                              width: 26, height: 26,
                              decoration: BoxDecoration(color: Color(p.colour.value), shape: BoxShape.circle)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(p.name,
                                style: TextStyle(
                                    fontSize: 19,
                                    fontWeight: isWinner ? FontWeight.w900 : FontWeight.w700)),
                          ),
                          Text('${pct.round()}%',
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                        ],
                      ),
                    );
                  }),
                  const Spacer(),
                  BigButton(
                    label: 'PLAY AGAIN  ▶',
                    color: const Color(0xFFFF7BAC),
                    onPressed: () {
                      SoundFx.click();
                      final cfg = widget.args.config;
                      if (cfg != null) {
                        Navigator.pushNamed(
                          context,
                          '/game',
                          arguments: MatchConfig(
                            players: widget.args.players.map((p) => p.copy()).toList(),
                            mode: cfg.mode,
                            arenaShape: cfg.arenaShape,
                            botDifficulty: cfg.botDifficulty,
                            trail: cfg.trail,
                            pack: cfg.pack,
                          ),
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () {
                        SoundFx.click();
                        Navigator.pushNamed(context, '/setup');
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: const BorderSide(color: Colors.white54, width: 1.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Text('CHANGE COLOURS & SHAPES',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Colors.white)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () {
                        SoundFx.click();
                        Navigator.pushNamedAndRemoveUntil(context, '/', (_) => false);
                      },
                      child: const Text('HOME',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Colors.white70)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.progress, this.color);
  final double progress;
  final Color color;
  final Random _rng = Random(42);

  @override
  void paint(Canvas canvas, Size size) {
    final colours = [color, Colors.white, const Color(0xFFFFCA28), const Color(0xFF29B6F6)];
    for (var i = 0; i < 70; i++) {
      final x = _rng.nextDouble() * size.width;
      final startY = _rng.nextDouble() * size.height * 0.4;
      final y = (startY + progress * size.height * 0.9) % size.height;
      final paint = Paint()..color = colours[i % colours.length].withOpacity(0.85);
      canvas.drawRect(
          Rect.fromCenter(center: Offset(x, y), width: 8, height: 12), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter old) => old.progress != progress;
}
