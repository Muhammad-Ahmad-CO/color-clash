// Color Cover — Modes screen. Nine mode cards in a flat, sharp,
// heavy-type style. VS COMPUTER is first and featured (bigger, pink).
// No emoji anywhere — numbers and colour tiles instead.
import 'package:flutter/material.dart';
import '../data/game_data.dart';
import '../game/sound.dart';

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
  ];

  static const List<Color> _cardText = [
    Color(0xFF210044),
    Colors.white,
    Color(0xFF1A0A00),
    Color(0xFF1A0A00),
    Colors.white,
    Colors.white,
    Colors.white,
    Colors.white,
    Colors.white,
  ];

  @override
  Widget build(BuildContext context) {
    final packs = kModePacks;
    return Scaffold(
      backgroundColor: const Color(0xFF1B1A1F),
      appBar: AppBar(
        title: const Text('CHOOSE A MODE',
            style: TextStyle(fontWeight: FontWeight.w900)),
        backgroundColor: const Color(0xFF1B1A1F),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: packs.length,
        itemBuilder: (context, index) {
          final pack = packs[index];
          final featured = index == 0;
          final bg = _cardColors[index];
          final fg = _cardText[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: InkWell(
              onTap: () {
                SoundFx.click();
                Navigator.pushNamed(context, '/setup', arguments: pack);
              },
              child: Container(
                color: bg,
                padding: EdgeInsets.symmetric(
                    horizontal: 16, vertical: featured ? 22 : 16),
                child: Row(
                  children: [
                    Container(
                      width: featured ? 52 : 42,
                      height: featured ? 52 : 42,
                      color: Colors.black.withOpacity(0.18),
                      alignment: Alignment.center,
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                            fontSize: featured ? 26 : 22,
                            fontWeight: FontWeight.w900,
                            color: fg),
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
                                fontSize: featured ? 24 : 20,
                                fontWeight: FontWeight.w900,
                                color: fg),
                          ),
                          if (featured)
                            Text('YOU vs THE COMPUTER',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: fg.withOpacity(0.8))),
                          Text(modePackDesc(pack),
                              style: TextStyle(
                                  fontSize: 15, color: fg.withOpacity(0.9))),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: fg, size: 28),
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
