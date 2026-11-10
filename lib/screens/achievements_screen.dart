// Color Cover — Achievements screen (Dot Clash chrome).
// 7 local badges with coin rewards, paid once each. Progress bars show
// how close a locked badge is. Reached from Home (not a bottom-nav tab).
// No emoji anywhere.
import 'package:flutter/material.dart';
import '../game/stats.dart';
import '../widgets/dot_chrome.dart';

class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});
  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  @override
  void initState() {
    super.initState();
    StatsService.load().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DcColors.page,
      appBar: AppBar(title: const Text('ACHIEVEMENTS')),
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: kAchievements.length,
        itemBuilder: (context, i) {
          final a = kAchievements[i];
          final unlocked = StatsService.unlocked.contains(a.id);
          final progress = StatsService.achievementProgress(a.id);
          final progressText = StatsService.achievementProgressText(a.id);
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: DcCard(
              borderColor:
                  unlocked ? DcColors.gold : DcColors.border,
              borderWidth: unlocked ? 2 : 1,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          a.name.toUpperCase(),
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: DcColors.text),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: unlocked
                              ? DcColors.gold
                              : Colors.white,
                          borderRadius: const BorderRadius.all(
                              Radius.circular(999)),
                          border: Border.all(color: DcColors.border),
                        ),
                        child: Text(
                          unlocked
                              ? 'UNLOCKED  +${a.reward}'
                              : '+${a.reward} COINS',
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              color: DcColors.text),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(a.desc,
                      style: const TextStyle(
                          fontSize: 15, color: DcColors.muted)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 10,
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.08),
                            borderRadius: const BorderRadius.all(
                                Radius.circular(999)),
                          ),
                          alignment: Alignment.centerLeft,
                          child: FractionallySizedBox(
                            widthFactor: progress.clamp(0.0, 1.0),
                            child: Container(
                              decoration: BoxDecoration(
                                color: unlocked
                                    ? DcColors.gold
                                    : DcColors.orange,
                                borderRadius: const BorderRadius.all(
                                    Radius.circular(999)),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(progressText,
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: DcColors.text)),
                    ],
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
