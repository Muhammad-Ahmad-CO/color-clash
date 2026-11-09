// Color Cover — Coins + Shop (separate section, NOT in Modes).
// Win a match = 50 coins, finish a match = 10 coins. Coins are stored
// on the phone. Shop sells ball trails: Glow, Fire, Rainbow, Golden.
import 'package:flutter/material.dart';
import '../data/game_data.dart';
import '../game/coins.dart';
import '../game/sound.dart';

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
      appBar: AppBar(
        title: const Text('SHOP', style: TextStyle(fontWeight: FontWeight.w900)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFCA28).withOpacity(0.2),
                      border: Border.all(color: const Color(0xFFFFCA28), width: 1.5),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: const BoxDecoration(
                            color: Color(0xFFFFCA28),
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: const Text('C',
                              style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF1A0A00))),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${CoinsService.coins} coins',
                                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                              const Text('Win a match = 50 coins. Finish a match = 10 coins.',
                                  style: TextStyle(color: Colors.white70, fontSize: 14)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Ball trails — buy once, use forever',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  ...kShopItems.map((item) {
                    final owned = CoinsService.owned.contains(item.id);
                    final equipped = CoinsService.equippedTrail == item.trail;
                    return Card(
                      color: Colors.white10,
                      shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.zero),
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item.name,
                                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                                  Text(item.desc,
                                      style: const TextStyle(color: Colors.white70, fontSize: 14)),
                                  const SizedBox(height: 6),
                                  Text(owned ? (equipped ? 'EQUIPPED ✓' : 'OWNED') : '${item.cost} COINS',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          color: owned ? Colors.greenAccent : const Color(0xFFFFCA28))),
                                ],
                              ),
                            ),
                            ElevatedButton(
                              onPressed: () async {
                                if (owned) {
                                  await CoinsService.equip(item.trail);
                                  setState(() {});
                                  SoundFx.click();
                                } else {
                                  final ok = await CoinsService.buy(item);
                                  if (!mounted) return;
                                  if (ok) {
                                    await CoinsService.equip(item.trail);
                                    setState(() {});
                                    SoundFx.pickup();
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text('Not enough coins yet. Win matches to earn coins!')),
                                    );
                                  }
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: equipped
                                      ? Colors.green
                                      : const Color(0xFFFF7BAC),
                                  foregroundColor: Colors.white),
                              child: Text(equipped ? 'EQUIPPED' : (owned ? 'EQUIP' : 'BUY')),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () async {
                      await CoinsService.equip(TrailType.none);
                      setState(() {});
                      SoundFx.click();
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: Colors.white54),
                      shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.zero),
                    ),
                    child: const Text('USE NORMAL TRAIL',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                  ),
                  const SizedBox(height: 12),
                  const Text('Tip: the Rainbow Ball changes colour while you play.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white54, fontSize: 14)),
                ],
              ),
      ),
    );
  }
}
