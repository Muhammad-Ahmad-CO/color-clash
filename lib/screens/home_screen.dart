// Colour Clash — Home screen.
import 'package:flutter/material.dart';
import '../game/sound.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF2A1A5E), Color(0xFF1A1033), Color(0xFF120A24)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 28),
                // Logo mark: four coloured balls.
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    _LogoBall(Color(0xFFFF7BAC)),
                    SizedBox(width: 10),
                    _LogoBall(Color(0xFF3F2A7A)),
                    SizedBox(width: 10),
                    _LogoBall(Color(0xFFF5E6C8)),
                    SizedBox(width: 10),
                    _LogoBall(Color(0xFF6B3A1F)),
                  ],
                ),
                const SizedBox(height: 20),
                const Text(
                  'COLOUR',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 52,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 4,
                    color: Colors.white,
                    height: 1.0,
                  ),
                ),
                const Text(
                  'CLASH',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 52,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 4,
                    color: Color(0xFFFF7BAC),
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Paint the arena. Steal the tiles.\nWin the battle in 90 seconds.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, color: Colors.white70, height: 1.4),
                ),
                const SizedBox(height: 12),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  children: const [
                    _Chip('2-4 PLAYERS'),
                    _Chip('54 COLOURS'),
                    _Chip('24 BALL SHAPES'),
                    _Chip('OFFLINE'),
                  ],
                ),
                const Spacer(),
                // MODES section sits before Play on Home.
                BigButtonHome(
                  label: '🎮  MODES  (9)',
                  color: const Color(0xFF7C4DFF),
                  onPressed: () {
                    SoundFx.click();
                    Navigator.pushNamed(context, '/modes');
                  },
                ),
                const SizedBox(height: 14),
                BigButtonHome(
                  label: '▶  PLAY',
                  onPressed: () {
                    SoundFx.click();
                    Navigator.pushNamed(context, '/setup');
                  },
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      SoundFx.click();
                      Navigator.pushNamed(context, '/how');
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: const BorderSide(color: Colors.white54, width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text('HOW TO PLAY',
                        style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: Colors.white)),
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      SoundFx.click();
                      Navigator.pushNamed(context, '/shop');
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: const BorderSide(color: Color(0xFFFFCA28), width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text('🪙  SHOP — COINS & TRAILS',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFFFFCA28))),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Sound: ', style: TextStyle(color: Colors.white70, fontSize: 16)),
                    Switch(
                      value: !SoundFx.muted,
                      activeColor: const Color(0xFFFF7BAC),
                      onChanged: (v) {
                        setState(() => SoundFx.muted = !v);
                        if (!SoundFx.muted) SoundFx.click();
                      },
                    ),
                    Text(SoundFx.muted ? 'OFF' : 'ON',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'No login. No internet. Free forever.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white38, fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class BigButtonHome extends StatelessWidget {
  const BigButtonHome({super.key, required this.label, required this.onPressed, this.color});
  final String label;
  final VoidCallback onPressed;
  final Color? color;
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color ?? const Color(0xFFFF7BAC),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 18),
          textStyle: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: Text(label),
      ),
    );
  }
}

class _LogoBall extends StatelessWidget {
  const _LogoBall(this.color);
  final Color color;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 6, offset: Offset(0, 3))],
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
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white24),
      ),
      child: Text(label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white)),
    );
  }
}
