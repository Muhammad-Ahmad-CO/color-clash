// Color Cover — How to Play (Dot Clash chrome, v3b, simple English).
// Light grey page, orange rounded step numbers, near-black titles,
// muted body text, off-white power-up rows. Back only — no bottom nav.
import 'package:flutter/material.dart';
import '../data/game_data.dart';
import '../game/match_theme.dart';
import '../widgets/ball_painter.dart';
import '../widgets/dot_chrome.dart';

class HowToPlayScreen extends StatelessWidget {
  const HowToPlayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DcColors.page,
      appBar: AppBar(
        title: const Text('HOW TO PLAY',
            style: TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              _Step('1', 'Pick your players',
                  'Choose 2, 3 or 4 players. Each player picks a name, a colour (60 colours) and a ball shape (30 shapes). No two players can pick the same colour.'),
              _Step('2', 'Steer your ball',
                  'Your ball moves on its own. Touch anywhere in your zone and drag to steer it — a joystick appears where your finger touches. 2 players: left half vs right half. 3 players: three vertical thirds. 4 players: four corners. All players can steer at the same time — use different fingers.'),
              _Step('3', 'Paint the arena',
                  'Wherever your ball goes, the tiles change to your colour. Take tiles from other players by driving over them. The player with the most tiles at the end wins.'),
              _Step('4', 'Grab power-ups',
                  'A power-up tile appears every 6 seconds (maximum 3 on the field). Drive over it to use it — any part of your ball touching the tile collects it. A banner with its name and what it does shows above the arena for a few seconds. Each power-up has its own colour and icon, and a coloured ring + badge on your ball shows the buff while it runs.'),
              _Step('5', 'Win in 90 seconds',
                  'The match lasts 90 seconds. When time is up, the player with the biggest area wins — the end card shows "<NAME> DOMINATES!" right on the arena.'),
              SizedBox(height: 16),
              DcSectionTitle('MODES — PICK ONE ON HOME'),
              SizedBox(height: 8),
              Text(
                  'Ultimate Clash: fill the meter, tap TSUNAMI. Bomb Battle: Bomb Balls explode 5x5. '
                  'Golden Rush: touch the star tile for double paint. Sudden Death: arena shrinks in the last 10 seconds. '
                  'Chaos Mode: Earthquake, Ice or Fire every 20 seconds. Team 2v2: P1+P3 vs P2+P4. '
                  'Battle Royale: lowest player is out every 30 seconds. VS COMPUTER: play alone vs Easy, Medium or Crazy. '
                  'Sab Kuch / All Chaos: modes 1-5 together.',
                  style: TextStyle(
                      fontSize: 16, height: 1.5, color: DcColors.muted)),
              SizedBox(height: 16),
              DcSectionTitle('POWER-UPS'),
              SizedBox(height: 10),
              _PowerUpList(),
              SizedBox(height: 16),
              DcSectionTitle('TIPS'),
              SizedBox(height: 8),
              Text(
                  '• Fortify protects your tiles — grab it when you are winning.\n'
                  '• Wrecking Ball and Colossus paint a bigger area.\n'
                  '• Black Hole pulls enemy balls to you — then paint over them.\n'
                  '• Wormhole can save you or drop you in enemy land. Good luck!',
                  style: TextStyle(
                      fontSize: 16, height: 1.5, color: DcColors.muted)),
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
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: DcColors.orange,
              borderRadius: BorderRadius.all(Radius.circular(10)),
            ),
            child: Text(num,
                style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                    color: Colors.white)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: DcColors.text)),
                const SizedBox(height: 4),
                Text(body,
                    style: const TextStyle(
                        fontSize: 16, height: 1.45, color: DcColors.muted)),
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
        // Legend matches the field exactly: the box uses the power-up's
        // own tile colour, and the icon is drawn big (30 px in a 44 px
        // box) in high-contrast colour.
        final bg = Color(p.value);
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: DcCard(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius:
                        const BorderRadius.all(Radius.circular(8)),
                  ),
                  child: PowerUpIconWidget(
                      def: p, color: contrastTextColor(bg), size: 30),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              color: DcColors.text)),
                      Text(p.desc,
                          style: const TextStyle(
                              color: DcColors.muted, fontSize: 14)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
