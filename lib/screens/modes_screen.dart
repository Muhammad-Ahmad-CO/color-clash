// Colour Clash — MODES section.
// 9 cards: the 8 modes + "Sab Kuch / All Chaos" (modes 1-5 together).
// Tapping a card opens Setup with that mode's rule active.
// Coins + Shop and Arena Shapes are separate sections, not in Modes.
import 'package:flutter/material.dart';
import '../data/game_data.dart';
import '../game/sound.dart';

class ModesScreen extends StatelessWidget {
  const ModesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MODES', style: TextStyle(fontWeight: FontWeight.w900)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
          itemCount: kModePacks.length,
          itemBuilder: (context, i) {
            final pack = kModePacks[i];
            final isAll = pack == ModePack.allChaos;
            return Card(
              color: isAll ? const Color(0xFFFF6D00).withOpacity(0.25) : Colors.white10,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                    color: isAll ? const Color(0xFFFF6D00) : Colors.white24, width: isAll ? 2.5 : 1),
              ),
              margin: const EdgeInsets.only(bottom: 12),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  SoundFx.click();
                  Navigator.pushNamed(context, '/setup', arguments: pack);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  child: Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.white12,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(modePackIcon(pack), style: const TextStyle(fontSize: 30)),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${i + 1}. ${modePackName(pack)}',
                                style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
                            const SizedBox(height: 4),
                            Text(modePackDesc(pack),
                                style: const TextStyle(fontSize: 15, color: Colors.white70, height: 1.35)),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: Colors.white70, size: 28),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
