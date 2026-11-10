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
import 'screens/history_screen.dart';
import 'screens/achievements_screen.dart';
import 'screens/modes_screen.dart';
import 'screens/shop_screen.dart';
import 'widgets/dot_chrome.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  // Fullscreen: hide the Android system buttons (back/home/recent) from
  // the moment the app opens; immersiveSticky brings them back only on
  // an edge swipe, then auto-hides them again. The game screen re-asserts
  // this on open and on resume.
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
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
        scaffoldBackgroundColor: DcColors.page,
        colorScheme: const ColorScheme.dark(
          primary: DcColors.blue,
          secondary: DcColors.gold,
          surface: DcColors.panel,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: DcColors.bar,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Colors.white),
        ),
        dialogTheme: const DialogTheme(
          backgroundColor: DcColors.panel,
          titleTextStyle: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: Colors.white),
          contentTextStyle: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Colors.white),
        ),
        useMaterial3: true,
        textTheme: const TextTheme(
          headlineLarge: TextStyle(
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
              color: Colors.white),
          titleLarge: TextStyle(
              fontWeight: FontWeight.w800, color: Colors.white),
          bodyLarge: TextStyle(fontSize: 17, color: Colors.white),
          bodyMedium: TextStyle(fontSize: 16, color: Colors.white),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: DcColors.blue,
            foregroundColor: Colors.white,
            padding:
                const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
            textStyle:
                const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            shape: const StadiumBorder(),
          ),
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (_) => const PreloaderScreen(),
        '/home': (_) => const HomeScreen(),
        '/how': (_) => const HowToPlayScreen(),
        '/modes': (_) => const ModesScreen(),
        '/history': (_) => const HistoryScreen(),
        '/achievements': (_) => const AchievementsScreen(),
        '/shop': (_) => const ShopScreen(),
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/setup') {
          // Modes/Home pass a bare ModePack; the Daily Challenge card
          // passes SetupArgs so the challenge flag survives into the
          // match. Both shapes are accepted here.
          final args = settings.arguments;
          ModePack? pack;
          var dailyChallenge = false;
          if (args is ModePack) {
            pack = args;
          } else if (args is SetupArgs) {
            pack = args.pack;
            dailyChallenge = args.dailyChallenge;
          }
          return MaterialPageRoute(
              builder: (_) => SetupScreen(
                  initialPack: pack,
                  initialDailyChallenge: dailyChallenge));
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
