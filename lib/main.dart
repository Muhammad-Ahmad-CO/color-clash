// Colour Clash — a 2, 3 or 4 player territory battle on one phone.
// Portrait only. No login, no internet needed. Free.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'data/game_data.dart';
import 'screens/home_screen.dart';
import 'screens/setup_screen.dart';
import 'screens/how_to_play_screen.dart';
import 'screens/game_screen.dart';
import 'screens/result_screen.dart';
import 'screens/modes_screen.dart';
import 'screens/shop_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const ColourClashApp());
}

class ColourClashApp extends StatelessWidget {
  const ColourClashApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Colour Clash',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF1A1033),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFFF7BAC),
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (_) => const HomeScreen(),
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
        if (settings.name == '/result') {
          final args = settings.arguments as ResultArgs;
          return MaterialPageRoute(builder: (_) => ResultScreen(args: args));
        }
        return null;
      },
    );
  }
}

/// Big primary button used on every screen — large text, no overlap.
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
