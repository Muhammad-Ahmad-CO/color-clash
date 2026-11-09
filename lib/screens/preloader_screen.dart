// Color Cover — Preloader (shown first on every app start).
// Full-screen: the Pixel Tiles logo + "COLOR COVER" + small
// "made by Ahmed" below it, with a subtle pulse, then Home.
import 'dart:async';
import 'package:flutter/material.dart';
import '../game/sound.dart';

class PreloaderScreen extends StatefulWidget {
  const PreloaderScreen({super.key});
  @override
  State<PreloaderScreen> createState() => _PreloaderScreenState();
}

class _PreloaderScreenState extends State<PreloaderScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulse;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _timer = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      SoundFx.click();
      Navigator.pushReplacementNamed(context, '/home');
    });
  }

  @override
  void dispose() {
    _pulse.dispose();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1B1A1F),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _pulse,
              builder: (context, _) {
                final scale = 1.0 + _pulse.value * 0.06;
                return Transform.scale(
                  scale: scale,
                  child: Container(
                    width: 180,
                    height: 180,
                    decoration: const BoxDecoration(
                      borderRadius: BorderRadius.all(Radius.circular(24)),
                    ),
                    child: ClipRRect(
                      borderRadius:
                          const BorderRadius.all(Radius.circular(24)),
                      child: Image.asset('assets/logo.png',
                          width: 180, height: 180, fit: BoxFit.cover),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 28),
            const Text(
              'COLOR COVER',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.w900,
                letterSpacing: 3,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'made by Ahmed',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}
