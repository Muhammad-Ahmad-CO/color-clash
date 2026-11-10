// Color Cover — Home screen (Tiny Clash chrome, v3.5).
// Rich dark-navy game menu: top currency bar (logo chip + rank chip +
// gold coins), big outlined COLOR COVER title, Pixel Tiles logo in a
// chunky card, big gradient VS COMPUTER button, chunky PLAY / MODES
// cards, daily challenge + missions strip, daily spin, MY RECORDS,
// streak/rank, history/achievements/shop, sound switch. No emoji anywhere.
import 'package:flutter/material.dart';
import '../data/game_data.dart';
import '../game/coins.dart';
import '../game/juice.dart';
import '../game/sound.dart';
import '../game/stats.dart';
import '../widgets/dot_chrome.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _dailyClaimed = 0; // coins from today's daily reward, 0 = none.

  @override
  void initState() {
    super.initState();
    CoinsService.load().then((_) {
      if (mounted) setState(() {});
    });
    SoundFx.load().then((_) {
      if (mounted) setState(() {});
    });
    JuiceSettings.load().then((_) {
      if (mounted) setState(() {});
    });
    // Stats (rank, streak, missions, spin, records) load once per
    // visit; Home is rebuilt on every navigation back to it.
    StatsService.load().then((_) {
      if (mounted) setState(() {});
    });
    // Daily reward: +50 coins once per calendar day, claimed on open.
    StatsService.claimDailyReward().then((claimed) {
      if (mounted && claimed > 0) {
        setState(() => _dailyClaimed = claimed);
      }
    });
  }

  Future<void> _claimMission(String id) async {
    final got = await StatsService.claimMission(id);
    if (!mounted) return;
    if (got > 0) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('MISSION DONE! +$got COINS')),
      );
    }
  }

  Future<void> _spin() async {
    final prize = await StatsService.claimSpin();
    if (!mounted || prize == null) return;
    setState(() {});
    final text = prize.isColour
        ? 'You unlocked ${prize.colourName}! Find it in the Setup colour picker.'
        : '+${prize.coins} COINS!';
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('DAILY SPIN',
            style: TextStyle(fontWeight: FontWeight.w900)),
        content: Text(text,
            style: const TextStyle(
                fontSize: 18, fontWeight: FontWeight.w800)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('NICE!',
                style: TextStyle(
                    fontWeight: FontWeight.w900, color: DcColors.blue)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DcColors.page,
      bottomNavigationBar: const DotBottomNav(current: DcTab.home),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildCurrencyBar(),
              const SizedBox(height: 16),
              if (_dailyClaimed > 0)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: DcCard(
                    borderColor: DcColors.gold,
                    borderWidth: 2,
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'DAILY REWARD',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: Colors.white),
                          ),
                        ),
                        Text(
                          '+$_dailyClaimed COINS',
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: DcColors.gold),
                        ),
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: () => setState(() => _dailyClaimed = 0),
                          child: const Icon(Icons.close,
                              size: 20, color: DcColors.muted),
                        ),
                      ],
                    ),
                  ),
                ),
              DcCard(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
                child: Column(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.all(
                            Radius.circular(18)),
                        border:
                            Border.all(color: DcColors.gold, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.45),
                            blurRadius: 14,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: const BorderRadius.all(
                            Radius.circular(16)),
                        child: Image.asset('assets/logo.png',
                            width: 140, height: 140, fit: BoxFit.cover),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const TcOutlined(
                      'COLOR COVER',
                      fontSize: 34,
                      letterSpacing: 2,
                      textAlign: TextAlign.center,
                      height: 1.0,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Paint the arena. Steal the tiles.\nWin the battle in 90 seconds.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 16,
                          color: DcColors.muted,
                          height: 1.4),
                    ),
                    const SizedBox(height: 14),
                    const Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _Chip('2-4 PLAYERS'),
                        _Chip('62 COLOURS'),
                        _Chip('30 BALL SHAPES'),
                        _Chip('OFFLINE'),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // VS COMPUTER is first and biggest — impossible to miss.
              DcPillButton(
                label: 'VS COMPUTER',
                height: 62,
                fontSize: 22,
                onPressed: () {
                  SoundFx.click();
                  Navigator.pushNamed(context, '/setup',
                      arguments: ModePack.vsBot);
                },
              ),
              const SizedBox(height: 12),
              DcSecondaryButton(
                label: 'PLAY',
                onPressed: () {
                  SoundFx.click();
                  Navigator.pushNamed(context, '/setup');
                },
              ),
              const SizedBox(height: 12),
              DcSecondaryButton(
                label: 'MODES  (10)',
                onPressed: () {
                  SoundFx.click();
                  Navigator.pushNamed(context, '/modes');
                },
              ),
              const SizedBox(height: 16),
              _buildRankCard(),
              const SizedBox(height: 12),
              _buildChallengeCard(),
              const SizedBox(height: 12),
              _buildMissionsCard(),
              const SizedBox(height: 12),
              _buildSpinCard(),
              const SizedBox(height: 12),
              _buildRecordsCard(),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: DcSecondaryButton(
                      label: 'HISTORY',
                      onPressed: () {
                        SoundFx.click();
                        Navigator.pushNamed(context, '/history');
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DcSecondaryButton(
                      label: 'ACHIEVEMENTS',
                      onPressed: () {
                        SoundFx.click();
                        Navigator.pushNamed(context, '/achievements');
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DcSecondaryButton(
                label: 'SHOP — COINS & TRAILS',
                onPressed: () {
                  SoundFx.click();
                  Navigator.pushNamed(context, '/shop');
                },
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  SoundFx.click();
                  Navigator.pushNamed(context, '/how');
                },
                child: const Text('HOW TO PLAY',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: DcColors.muted)),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Sound: ',
                      style:
                          TextStyle(color: DcColors.muted, fontSize: 16)),
                  Switch(
                    value: !SoundFx.muted,
                    activeColor: DcColors.gold,
                    onChanged: (v) {
                      SoundFx.setMuted(!v);
                      setState(() {});
                      if (!SoundFx.muted) SoundFx.click();
                    },
                  ),
                  Text(SoundFx.muted ? 'OFF' : 'ON',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700)),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Reduce shake: ',
                      style:
                          TextStyle(color: DcColors.muted, fontSize: 16)),
                  Switch(
                    value: JuiceSettings.reduceShake,
                    activeColor: DcColors.gold,
                    onChanged: (v) {
                      JuiceSettings.setReduceShake(v);
                      setState(() {});
                    },
                  ),
                  Text(JuiceSettings.reduceShake ? 'ON' : 'OFF',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'No login. No internet. Free forever.',
                textAlign: TextAlign.center,
                style: TextStyle(color: DcColors.muted, fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Top currency bar (Tiny Clash style): logo chip + rank chip +
  /// gold coins balance. Tapping the coins chip opens the Shop.
  Widget _buildCurrencyBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        color: DcColors.bar,
        borderRadius: BorderRadius.all(Radius.circular(999)),
        border: Border.fromBorderSide(
            BorderSide(color: DcColors.border)),
        boxShadow: [
          BoxShadow(
            color: Colors.black38,
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.all(Radius.circular(10)),
            child: Image.asset('assets/logo.png',
                width: 36, height: 36, fit: BoxFit.cover),
          ),
          const SizedBox(width: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: const BoxDecoration(
              color: DcColors.panel,
              borderRadius: BorderRadius.all(Radius.circular(999)),
              border: Border.fromBorderSide(
                  BorderSide(color: DcColors.border)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.emoji_events,
                    size: 18, color: DcColors.gold),
                const SizedBox(width: 4),
                Text(StatsService.rankName.toUpperCase(),
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: Colors.white)),
              ],
            ),
          ),
          const Spacer(),
          InkWell(
            onTap: () {
              SoundFx.click();
              Navigator.pushNamed(context, '/shop');
            },
            borderRadius: const BorderRadius.all(Radius.circular(999)),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: const BoxDecoration(
                color: DcColors.panel,
                borderRadius: BorderRadius.all(Radius.circular(999)),
                border: Border.fromBorderSide(
                    BorderSide(color: DcColors.gold, width: 1.5)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    decoration: const BoxDecoration(
                      color: DcColors.gold,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: const Text('C',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: DcColors.ink)),
                  ),
                  const SizedBox(width: 6),
                  Text('${CoinsService.coins}',
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: Colors.white)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Rank + play streak: rank from the win streak, CHAMPION chip for
  /// beating Crazy, and a 7-dot Day X/7 play streak.
  Widget _buildRankCard() {
    final streak = StatsService.playStreak;
    final filled = streak > 7 ? 7 : streak;
    return DcCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'RANK: ${StatsService.rankName.toUpperCase()}',
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: Colors.white),
                ),
              ),
              if (StatsService.isChampion)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: const BoxDecoration(
                    color: DcColors.gold,
                    borderRadius: BorderRadius.all(Radius.circular(999)),
                  ),
                  child: const Text('CHAMPION',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: DcColors.ink)),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${StatsService.winStreak}-win streak  •  Best ${StatsService.bestStreak}',
            style: const TextStyle(fontSize: 15, color: DcColors.muted),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.local_fire_department,
                  size: 22, color: DcColors.gold),
              const SizedBox(width: 6),
              Text('DAY $filled/7',
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: Colors.white)),
              const SizedBox(width: 10),
              ...List.generate(7, (i) {
                return Padding(
                  padding: const EdgeInsets.only(right: 5),
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i < filled
                          ? DcColors.gold
                          : Colors.white.withOpacity(0.2),
                    ),
                  ),
                );
              }),
              if (streak > 7)
                Text(' $streak days!',
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: DcColors.gold)),
            ],
          ),
          const SizedBox(height: 4),
          const Text('Play every day to reach Day 7: +300 coins + a rare colour.',
              style: TextStyle(fontSize: 13, color: DcColors.muted)),
        ],
      ),
    );
  }

  /// Daily challenge: one special mode per day, +100 coins for winning.
  Widget _buildChallengeCard() {
    final pack = StatsService.dailyChallengePack;
    final won = StatsService.dailyChallengeWon;
    return InkWell(
      onTap: () {
        SoundFx.click();
        Navigator.pushNamed(context, '/setup',
            arguments:
                SetupArgs(pack: pack, dailyChallenge: true));
      },
      borderRadius: const BorderRadius.all(Radius.circular(18)),
      child: DcCard(
        borderColor: DcColors.gold,
        borderWidth: 2,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('AAJ KA CHALLENGE',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                          color: DcColors.gold)),
                  const SizedBox(height: 4),
                  Text(modePackName(pack),
                      style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: Colors.white)),
                  Text(modePackDesc(pack),
                      style: const TextStyle(
                          fontSize: 14, color: DcColors.muted)),
                ],
              ),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: won ? DcColors.green : DcColors.blue,
                borderRadius:
                    const BorderRadius.all(Radius.circular(999)),
              ),
              child: Text(won ? 'WON TODAY' : '+100 COINS',
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  /// Daily missions: 3 a day, each with a progress bar and a CLAIM
  /// button that pays once when complete.
  Widget _buildMissionsCard() {
    final missions = StatsService.missionsToday();
    return DcCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('DAILY MISSIONS',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                  color: Colors.white)),
          const SizedBox(height: 10),
          ...missions.map((m) {
            final progress = StatsService.missionProgress(m.id);
            final complete = StatsService.isMissionComplete(m.id);
            final claimed = StatsService.isMissionClaimed(m.id);
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(m.name,
                            style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: Colors.white)),
                      ),
                      Text(StatsService.missionProgressText(m.id),
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: DcColors.muted)),
                      const SizedBox(width: 8),
                      SizedBox(
                        height: 32,
                        child: TextButton(
                          onPressed: (!complete || claimed)
                              ? null
                              : () => _claimMission(m.id),
                          style: TextButton.styleFrom(
                            backgroundColor: claimed
                                ? DcColors.bar
                                : DcColors.blue,
                            foregroundColor: claimed
                                ? DcColors.muted
                                : Colors.white,
                            shape: const StadiumBorder(),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12),
                            textStyle: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w900),
                          ),
                          child: Text(claimed
                              ? 'CLAIMED'
                              : 'CLAIM +${m.reward}'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.12),
                      borderRadius:
                          const BorderRadius.all(Radius.circular(999)),
                    ),
                    child: FractionallySizedBox(
                      widthFactor: progress,
                      alignment: Alignment.centerLeft,
                      child: Container(
                        decoration: BoxDecoration(
                          color: complete ? DcColors.green : DcColors.blue,
                          borderRadius: const BorderRadius.all(
                              Radius.circular(999)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(m.desc,
                      style: const TextStyle(
                          fontSize: 13, color: DcColors.muted)),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  /// Daily spin: one free spin per day — coins or a locked rare colour.
  Widget _buildSpinCard() {
    final done = StatsService.spinDoneToday;
    return DcCard(
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('DAILY SPIN',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                        color: Colors.white)),
                SizedBox(height: 2),
                Text('One free spin a day — coins or a rare colour.',
                    style: TextStyle(fontSize: 14, color: DcColors.muted)),
              ],
            ),
          ),
          SizedBox(
            height: 44,
            child: TextButton(
              onPressed: done ? null : _spin,
              style: TextButton.styleFrom(
                backgroundColor:
                    done ? DcColors.bar : DcColors.blue,
                foregroundColor:
                    done ? DcColors.muted : Colors.white,
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                textStyle: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w900),
              ),
              child: Text(done ? 'SPUN TODAY' : 'SPIN'),
            ),
          ),
        ],
      ),
    );
  }

  /// Personal bests: lifetime records on one card.
  Widget _buildRecordsCard() {
    return DcCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('MY RECORDS',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                  color: Colors.white)),
          const SizedBox(height: 10),
          Row(
            children: [
              _recordBox('MOST TILES', '${StatsService.bestTilesMatch}'),
              const SizedBox(width: 8),
              _recordBox('BEST COMBO', 'x${StatsService.bestCombo}'),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _recordBox('LONGEST STREAK', '${StatsService.bestStreak}'),
              const SizedBox(width: 8),
              _recordBox('TOTAL WINS', '${StatsService.wins}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _recordBox(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: const BoxDecoration(
          color: DcColors.bar,
          borderRadius: BorderRadius.all(Radius.circular(12)),
          border: Border.fromBorderSide(
              BorderSide(color: DcColors.border)),
        ),
        child: Column(
          children: [
            Text(value,
                style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Colors.white)),
            const SizedBox(height: 2),
            Text(label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: DcColors.muted)),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.label);
  final String label;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: DcColors.bar,
        borderRadius: const BorderRadius.all(Radius.circular(999)),
        border: Border.all(color: DcColors.border),
      ),
      child: Text(label,
          style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: Colors.white)),
    );
  }
}
