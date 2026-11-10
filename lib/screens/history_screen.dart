// Color Cover — Match History screen (Dot Clash chrome).
// Last 20 finished matches, newest first, stored on the phone.
// Reached from Home (not a bottom-nav tab). No emoji anywhere.
import 'package:flutter/material.dart';
import '../game/stats.dart';
import '../widgets/dot_chrome.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  @override
  void initState() {
    super.initState();
    StatsService.load().then((_) {
      if (mounted) setState(() {});
    });
  }

  String _dateText(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    final records = StatsService.history;
    return Scaffold(
      backgroundColor: DcColors.page,
      appBar: AppBar(title: const Text('MATCH HISTORY')),
      body: records.isEmpty
          ? const Center(
              child: Text(
                'No matches yet.\nPlay your first battle!',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: DcColors.muted),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: records.length,
              itemBuilder: (context, i) {
                final r = records[i];
                final winnerTiles = r.tiles.isEmpty
                    ? 0
                    : r.tiles.reduce((a, b) => a > b ? a : b);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: DcCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                r.won ? 'YOU WON' : '${r.winner.toUpperCase()} WON',
                                style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    color: r.won
                                        ? DcColors.orangeDark
                                        : DcColors.text),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: r.won
                                    ? DcColors.orange
                                    : Colors.white,
                                borderRadius: const BorderRadius.all(
                                    Radius.circular(999)),
                                border: Border.all(color: DcColors.border),
                              ),
                              child: Text(
                                '+${r.coinsEarned} COINS',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                    color: r.won
                                        ? Colors.white
                                        : DcColors.text),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${r.mode}  ·  ${_dateText(r.date)}  ·  ${r.durationSeconds}s',
                          style: const TextStyle(
                              fontSize: 14, color: DcColors.muted),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Winner: ${r.winner}  ·  $winnerTiles tiles  ·  ${r.players.join(' vs ')}',
                          style: const TextStyle(
                              fontSize: 14, color: DcColors.text),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
