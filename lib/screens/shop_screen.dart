// Color Cover — Coins + Shop (Tiny Clash chrome, v3.5).
// Dark-navy page, navy cards, white text, gold coin balance, blue
// gradient BUY/EQUIP buttons. Win a match = 50 coins,
// finish a match = 10 coins. Coins are stored on the phone. Shop sells
// ball trails: Glow, Fire, Rainbow, Golden. Bottom nav (Shop active).
import 'package:flutter/material.dart';
import '../data/game_data.dart';
import '../game/coins.dart';
import '../game/sound.dart';
import '../widgets/dot_chrome.dart';

class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});
  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    CoinsService.load().then((_) {
      if (mounted) setState(() => _loading = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DcColors.page,
      appBar: AppBar(
        title: const Text('SHOP',
            style: TextStyle(fontWeight: FontWeight.w900)),
      ),
      bottomNavigationBar: const DotBottomNav(current: DcTab.shop),
      body: SafeArea(
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: DcColors.orange))
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                children: [
                  DcCard(
                    padding: const EdgeInsets.all(18),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: const BoxDecoration(
                            color: DcColors.gold,
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: const Text('C',
                              style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                  color: DcColors.ink)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${CoinsService.coins} coins',
                                  style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w900,
                                      color: DcColors.text)),
                              const Text(
                                  'Win a match = 50 coins. Finish a match = 10 coins.',
                                  style: TextStyle(
                                      color: DcColors.muted, fontSize: 14)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  const DcSectionTitle('BALL TRAILS'),
                  const SizedBox(height: 4),
                  const Text('Buy once, use forever',
                      style:
                          TextStyle(fontSize: 15, color: DcColors.muted)),
                  const SizedBox(height: 12),
                  ...kShopItems.map((item) {
                    final owned = CoinsService.owned.contains(item.id);
                    final equipped =
                        CoinsService.equippedTrail == item.trail;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: DcCard(
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item.name,
                                      style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w900,
                                          color: DcColors.text)),
                                  Text(item.desc,
                                      style: const TextStyle(
                                          color: DcColors.muted,
                                          fontSize: 14)),
                                  const SizedBox(height: 6),
                                  Text(
                                      owned
                                          ? (equipped
                                              ? 'EQUIPPED ✓'
                                              : 'OWNED')
                                          : '${item.cost} COINS',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          color: owned
                                              ? DcColors.green
                                              : DcColors.gold)),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            SizedBox(
                              width: 112,
                              height: 46,
                              child: TextButton(
                                onPressed: () async {
                                  if (owned) {
                                    await CoinsService.equip(item.trail);
                                    setState(() {});
                                    SoundFx.click();
                                  } else {
                                    final ok =
                                        await CoinsService.buy(item);
                                    if (!mounted) return;
                                    if (ok) {
                                      await CoinsService.equip(item.trail);
                                      setState(() {});
                                      SoundFx.pickup();
                                    } else {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                            content: Text(
                                                'Not enough coins yet. Win matches to earn coins!')),
                                      );
                                    }
                                  }
                                },
                                style: TextButton.styleFrom(
                                    backgroundColor: equipped
                                        ? DcColors.gold
                                        : DcColors.blue,
                                    foregroundColor: equipped
                                        ? DcColors.ink
                                        : Colors.white,
                                    shape: const StadiumBorder(),
                                    textStyle: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800)),
                                child: Text(equipped
                                    ? 'EQUIPPED'
                                    : (owned ? 'EQUIP' : 'BUY')),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 4),
                  DcSecondaryButton(
                    label: 'USE NORMAL TRAIL',
                    onPressed: () async {
                      await CoinsService.equip(TrailType.none);
                      setState(() {});
                      SoundFx.click();
                    },
                  ),
                  const SizedBox(height: 14),
                  const Text(
                      'Tip: the Rainbow Ball changes colour while you play.',
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(color: DcColors.muted, fontSize: 14)),
                ],
              ),
      ),
    );
  }
}
