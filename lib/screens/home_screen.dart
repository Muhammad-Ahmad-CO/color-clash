// Color Cover — Home screen (Dot Clash chrome, v3b).
// Light grey page, white top bar with the centred wordmark, off-white
// hero card with the Pixel Tiles logo, one orange pill CTA per screen
// (VS COMPUTER first and biggest), white pill secondaries, bottom nav.
// The preloader still shows the dark logo screen first; this is the
// light home that follows it. No emoji anywhere.
import 'package:flutter/material.dart';
import '../data/game_data.dart';
import '../game/coins.dart';
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
    CoinsService.load();
    SoundFx.load().then((_) {
      if (mounted) setState(() {});
    });
    // Daily reward: +50 coins once per calendar day, claimed on open.
    StatsService.claimDailyReward().then((claimed) {
      if (mounted && claimed > 0) {
        setState(() => _dailyClaimed = claimed);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DcColors.page,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        centerTitle: true,
        title: const Text.rich(
          TextSpan(
            children: [
              TextSpan(
                  text: 'COLOR ',
                  style: TextStyle(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                      color: DcColors.text)),
              TextSpan(
                  text: 'COVER',
                  style: TextStyle(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                      color: DcColors.orange)),
            ],
          ),
          style: TextStyle(fontSize: 22),
        ),
      ),
      bottomNavigationBar: const DotBottomNav(current: DcTab.home),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_dailyClaimed > 0)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: DcCard(
                    color: const Color(0xFFFFF3D6),
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
                                color: DcColors.text),
                          ),
                        ),
                        Text(
                          '+$_dailyClaimed COINS',
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: DcColors.orangeDark),
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
                    ClipRRect(
                      borderRadius:
                          const BorderRadius.all(Radius.circular(16)),
                      child: Image.asset('assets/logo.png',
                          width: 140, height: 140, fit: BoxFit.cover),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'COLOR COVER',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                        color: DcColors.text,
                        height: 1.0,
                      ),
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
                        _Chip('60 COLOURS'),
                        _Chip('30 BALL SHAPES'),
                        _Chip('OFFLINE'),
                      ],
                    ),
                  ],
                ),
              ),
              const Spacer(),
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
              const SizedBox(height: 12),
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
                    activeColor: DcColors.orange,
                    onChanged: (v) {
                      SoundFx.setMuted(!v);
                      setState(() {});
                      if (!SoundFx.muted) SoundFx.click();
                    },
                  ),
                  Text(SoundFx.muted ? 'OFF' : 'ON',
                      style: const TextStyle(
                          color: DcColors.text,
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
}

class _Chip extends StatelessWidget {
  const _Chip(this.label);
  final String label;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.all(Radius.circular(999)),
        border: Border.all(color: DcColors.border),
      ),
      child: Text(label,
          style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: DcColors.text)),
    );
  }
}
