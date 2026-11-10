// Color Cover — Modes screen (Dot Clash chrome, v3b).
// Light grey page, off-white cards with a coloured number tile, heavy
// near-black titles, muted descriptions. VS COMPUTER is first and
// featured: a full orange card, bigger, with "YOU vs THE COMPUTER".
// Every card is tappable anywhere. Bottom nav (Play active).
// No emoji anywhere — numbers and colour tiles instead.
import 'package:flutter/material.dart';
import '../data/game_data.dart';
import '../game/match_theme.dart';
import '../game/sound.dart';
import '../widgets/ball_painter.dart';
import '../widgets/dot_chrome.dart';

class ModesScreen extends StatelessWidget {
  const ModesScreen({super.key});

  static const List<Color> _cardColors = [
    Color(0xFFFD6EA3), // VS COMPUTER (featured)
    Color(0xFF7C4DFF),
    Color(0xFFF5DA69),
    Color(0xFFFFD54F),
    Color(0xFFFF5252),
    Color(0xFF26A69A),
    Color(0xFFFF7043),
    Color(0xFF66BB6A),
    Color(0xFFE56E52),
    Color(0xFFAB47BC), // Time Attack — purple.
  ];

  @override
  Widget build(BuildContext context) {
    final packs = kModePacks;
    return Scaffold(
      backgroundColor: DcColors.page,
      appBar: AppBar(
        title: const Text('CHOOSE A MODE',
            style: TextStyle(fontWeight: FontWeight.w900)),
      ),
      bottomNavigationBar: const DotBottomNav(current: DcTab.play),
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: packs.length,
        itemBuilder: (context, index) {
          final pack = packs[index];
          final featured = index == 0;
          final tileColor = _cardColors[index];
          final tileText = contrastTextColor(tileColor);
          final titleColor = DcColors.text;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: InkWell(
              onTap: () {
                SoundFx.click();
                Navigator.pushNamed(context, '/setup', arguments: pack);
              },
              borderRadius:
                  const BorderRadius.all(Radius.circular(16)),
              child: Container(
                padding: EdgeInsets.symmetric(
                    horizontal: 16, vertical: featured ? 24 : 18),
                decoration: BoxDecoration(
                  color: featured ? DcColors.orange : DcColors.card,
                  borderRadius:
                      const BorderRadius.all(Radius.circular(16)),
                  border: Border.all(
                      color: featured
                          ? DcColors.orange
                          : DcColors.border,
                      width: 1),
                ),
                child: Row(
                  children: [
                    Container(
                      width: featured ? 60 : 52,
                      height: featured ? 60 : 52,
                      decoration: BoxDecoration(
                        color: featured ? Colors.white : tileColor,
                        borderRadius: const BorderRadius.all(
                            Radius.circular(12)),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                            fontSize: featured ? 30 : 26,
                            fontWeight: FontWeight.w900,
                            color: featured ? DcColors.text : tileText),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            modePackName(pack),
                            style: TextStyle(
                                fontSize: featured ? 27 : 23,
                                fontWeight: FontWeight.w900,
                                color: titleColor),
                          ),
                          if (featured)
                            Text('YOU vs THE COMPUTER',
                                style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: titleColor.withOpacity(0.75))),
                          Text(modePackDesc(pack),
                              style: TextStyle(
                                  fontSize: 16,
                                  color: featured
                                      ? titleColor.withOpacity(0.8)
                                      : DcColors.muted)),
                        ],
                      ),
                    ),
                    ShapePreview(
                        shape: BallShape.circle,
                        color: featured
                            ? DcColors.text.withOpacity(0.85)
                            : tileColor,
                        size: 40),
                    const Icon(Icons.chevron_right,
                        color: DcColors.muted, size: 32),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
