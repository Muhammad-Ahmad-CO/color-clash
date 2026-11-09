// Color Cover — a 2, 3 or 4 player territory battle on one phone.
// Portrait only. No login, no internet needed. Free.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'data/game_data.dart';
import 'screens/preloader_screen.dart';
import 'screens/home_screen.dart';
import 'screens/setup_screen.dart';
import 'screens/how_to_play_screen.dart';
import 'screens/game_screen.dart';
import 'screens/modes_screen.dart';
import 'screens/shop_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const ColorCoverApp());
}

class ColorCoverApp extends StatelessWidget {
  const ColorCoverApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Color Cover',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF1B1A1F),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFFD6EA3),
          secondary: Color(0xFF7C4DFF),
        ),
        useMaterial3: true,
        textTheme: const TextTheme(
          headlineLarge: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1),
          titleLarge: TextStyle(fontWeight: FontWeight.w800),
          bodyLarge: TextStyle(fontSize: 17),
          bodyMedium: TextStyle(fontSize: 16),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
            textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.zero),
          ),
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (_) => const PreloaderScreen(),
        '/home': (_) => const HomeScreen(),
        '/how': (_) => const HowToPlayScreen(),
        '/modes': (_) => const ModesScreen(),
        '/shop': (_) => const ShopScreen(),
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/setup') {
          final pack = settings.arguments as ModePack?;
          return MaterialPageRoute(builder: (_) => SetupScreen(initialPack: pack));
        }
        if (settings.name == '/game') {
          final config = settings.arguments as MatchConfig;
          return MaterialPageRoute(builder: (_) => GameScreen(config: config));
        }
        return null;
      },
    );
  }
}

/// Big primary button used on every screen — large text, flat, sharp corners.
class BigButton extends StatelessWidget {
  const BigButton({super.key, required this.label, required this.onPressed, this.color});
  final String label;
  final VoidCallback? onPressed;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: color == null
            ? null
            : ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white),
        child: Text(label),
      ),
    );
  }
}
