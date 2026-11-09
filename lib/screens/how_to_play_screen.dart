// Colour Clash — How to Play (simple English).
import 'package:flutter/material.dart';
import '../data/game_data.dart';

class HowToPlayScreen extends StatelessWidget {
  const HowToPlayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('HOW TO PLAY', style: TextStyle(fontWeight: FontWeight.w900)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              _Step('1', 'Pick your players',
                  'Choose 2, 3 or 4 players. Each player picks a name, a colour (54 colours) and a ball shape (24 shapes). No two players can pick the same colour.'),
              _Step('2', 'Steer your ball',
                  'Your ball moves on its own. Drag your joystick to steer it. P1 uses the bottom-left joystick, P2 bottom-right, P3 top, P4 top-right. All players can steer at the same time — use different fingers.'),
              _Step('3', 'Paint the arena',
                  'Wherever your ball goes, the tiles change to your colour. Take tiles from other players by driving over them. The player with the most tiles at the end wins.'),
              _Step('4', 'Grab power-ups',
                  'A power-up tile appears every 6 seconds (maximum 3 on the field). Drive over it to use it. The name shows at the top of the screen for 3 seconds.'),
              _Step('5', 'Win in 90 seconds',
                  'The match lasts 90 seconds. When the timer hits 0, the player with the biggest area wins and sees "DOMINATES!" on the result screen.'),
              SizedBox(height: 16),
              Text('MODES — PICK ONE ON HOME',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
              SizedBox(height: 8),
              Text('Ultimate Clash: fill the meter, tap TSUNAMI. Bomb Battle: Bomb Balls explode 5x5. '
                  'Golden Rush: touch the star tile for double paint. Sudden Death: arena shrinks in the last 10 seconds. '
                  'Chaos Mode: Earthquake, Ice or Fire every 20 seconds. Team 2v2: P1+P3 vs P2+P4. '
                  'Battle Royale: lowest player is out every 30 seconds. Vs Bot: play alone vs Easy, Medium or Crazy. '
                  'Sab Kuch / All Chaos: modes 1-5 together.',
                  style: TextStyle(fontSize: 16, height: 1.5, color: Colors.white70)),
              const SizedBox(height: 16),
              Text('POWER-UPS', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
              SizedBox(height: 10),
              _PowerUpList(),
              SizedBox(height: 16),
              Text('TIPS',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
              SizedBox(height: 8),
              Text('• Fortify protects your tiles — grab it when you are winning.\n'
                  '• Wrecking Ball and Colossus paint a bigger area.\n'
                  '• Black Hole pulls enemy balls to you — then paint over them.\n'
                  '• Wormhole can save you or drop you in enemy land. Good luck!',
                  style: TextStyle(fontSize: 16, height: 1.5, color: Colors.white70)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step(this.num, this.title, this.body);
  final String num;
  final String title;
  final String body;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38, height: 38,
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: Color(0xFFFF7BAC), shape: BoxShape.circle),
            child: Text(num, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: Colors.white)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(body, style: const TextStyle(fontSize: 16, height: 1.45, color: Colors.white70)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PowerUpList extends StatelessWidget {
  const _PowerUpList();
  @override
  Widget build(BuildContext context) {
    return Column(
      children: kPowerUps.map((p) {
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(12)),
          child: Row(
            children: [
              Container(
                width: 34, height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                    color: Color(p.value), borderRadius: BorderRadius.circular(8)),
                child: Text(p.letter,
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.white)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                    Text(p.desc, style: const TextStyle(color: Colors.white70, fontSize: 14)),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
