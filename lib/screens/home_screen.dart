// Color Cover — Home screen.
// Flat dark background (matches the Pixel Tiles logo corners), logo image,
// heavy grotesque title, flat sharp buttons. No gradients, no emoji.
import 'package:flutter/material.dart';
import '../data/game_data.dart';
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
      backgroundColor: const Color(0xFF1B1A1F),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              Center(
                child: ClipRRect(
                  borderRadius: const BorderRadius.all(Radius.circular(24)),
                  child: Image.asset('assets/logo.png',
                      width: 132, height: 132, fit: BoxFit.cover),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'COLOR',
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
                'COVER',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 52,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 4,
                  color: Color(0xFFFD6EA3),
                  height: 1.0,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Paint the arena. Steal the tiles.\nWin the battle in 90 seconds.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, color: Colors.white70, height: 1.4),
              ),
              const SizedBox(height: 12),
              const Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                children: [
                  _Chip('2-4 PLAYERS'),
                  _Chip('54 COLOURS'),
                  _Chip('24 BALL SHAPES'),
                  _Chip('OFFLINE'),
                ],
              ),
              const Spacer(),
              // VS COMPUTER is first and biggest — impossible to miss.
              _FlatButton(
                label: 'VS COMPUTER',
                background: const Color(0xFFFD6EA3),
                foreground: const Color(0xFF210044),
                onPressed: () {
                  SoundFx.click();
                  Navigator.pushNamed(context, '/setup',
                      arguments: ModePack.vsBot);
                },
              ),
              const SizedBox(height: 12),
              _FlatButton(
                label: 'PLAY',
                background: Colors.white,
                foreground: const Color(0xFF1B1A1F),
                onPressed: () {
                  SoundFx.click();
                  Navigator.pushNamed(context, '/setup');
                },
              ),
              const SizedBox(height: 12),
              _FlatButton(
                label: 'MODES  (9)',
                background: const Color(0xFF7C4DFF),
                foreground: Colors.white,
                onPressed: () {
                  SoundFx.click();
                  Navigator.pushNamed(context, '/modes');
                },
              ),
              const SizedBox(height: 12),
              _FlatButton(
                label: 'SHOP — COINS & TRAILS',
                background: const Color(0xFFF5DA69),
                foreground: const Color(0xFF1A0A00),
                onPressed: () {
                  SoundFx.click();
                  Navigator.pushNamed(context, '/shop');
                },
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () {
                    SoundFx.click();
                    Navigator.pushNamed(context, '/how');
                  },
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: const BorderSide(color: Colors.white54, width: 1.5),
                    shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.zero),
                  ),
                  child: const Text('HOW TO PLAY',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: Colors.white)),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Sound: ',
                      style: TextStyle(color: Colors.white70, fontSize: 16)),
                  Switch(
                    value: !SoundFx.muted,
                    activeColor: const Color(0xFFFD6EA3),
                    onChanged: (v) {
                      setState(() => SoundFx.muted = !v);
                      if (!SoundFx.muted) SoundFx.click();
                    },
                  ),
                  Text(SoundFx.muted ? 'OFF' : 'ON',
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w700)),
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
    );
  }
}

/// Flat sharp-cornered button (the spec's visual language: no radius,
/// no gradient, heavy caps type).
class _FlatButton extends StatelessWidget {
  const _FlatButton(
      {required this.label,
      required this.background,
      required this.foreground,
      required this.onPressed});
  final String label;
  final Color background;
  final Color foreground;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          backgroundColor: background,
          foregroundColor: foreground,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape:
              const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          textStyle:
              const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
        ),
        child: Text(label),
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
        border: Border.all(color: Colors.white24),
      ),
      child: Text(label,
          style: const TextStyle(
              fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white)),
    );
  }
}
