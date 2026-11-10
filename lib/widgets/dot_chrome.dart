// Color Cover — Dot Clash-style shared chrome.
// Palette + shared widgets for the APP CHROME only (home, modes, setup,
// shop, how-to, match chrome). The match ARENA is NOT styled here — it
// still follows REFERENCE_UI_SPEC.md (animated gradient, flat territories,
// cue-colour balls). Source of the language: DOT_CLASH_UI_SPEC.md —
// light grey pages, off-white cards, white bars, near-black text, one
// orange pill CTA per screen, hairline borders, clean system-sans type.
import 'package:flutter/material.dart';

class DcColors {
  static const page = Color(0xFFE5E5E5);
  static const card = Color(0xFFF7F7F7);
  static const bar = Colors.white;
  static const text = Color(0xFF111827);
  static const muted = Color(0xFF6B7280);
  static const border = Color(0xFFD1D5DB);
  static const orange = Color(0xFFF59E0B);
  static const orangeDark = Color(0xFF92400E); // readable amber text on light
  static const danger = Color(0xFFDC2626);
  static const gold = Color(0xFFFFCA28);
}

/// Primary action: fully rounded orange pill, white bold text.
/// One per screen (Dot Clash rule).
class DcPillButton extends StatelessWidget {
  const DcPillButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.height = 56,
    this.fontSize = 18,
    this.color,
    this.foreground,
  });
  final String label;
  final VoidCallback? onPressed;
  final double height;
  final double fontSize;
  final Color? color;
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: height,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          backgroundColor: color ?? DcColors.orange,
          foregroundColor: foreground ?? Colors.white,
          shape: const StadiumBorder(),
          textStyle: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w800),
        ),
        child: Text(label),
      ),
    );
  }
}

/// Secondary action: white pill with a grey hairline border.
class DcSecondaryButton extends StatelessWidget {
  const DcSecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.height = 56,
    this.fontSize = 18,
  });
  final String label;
  final VoidCallback? onPressed;
  final double height;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: height,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: DcColors.text,
          side: const BorderSide(color: DcColors.border, width: 1.5),
          shape: const StadiumBorder(),
          textStyle: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w800),
        ),
        child: Text(label),
      ),
    );
  }
}

/// Off-white card: 14px corners, hairline grey border (Dot Clash cards).
class DcCard extends StatelessWidget {
  const DcCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color,
    this.borderColor,
    this.borderWidth = 1,
    this.radius = 14,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Color? borderColor;
  final double borderWidth;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? DcColors.card,
        borderRadius: BorderRadius.all(Radius.circular(radius)),
        border: Border.all(
            color: borderColor ?? DcColors.border, width: borderWidth),
      ),
      child: child,
    );
  }
}

/// Section heading: near-black, extra-bold, wide letter spacing.
class DcSectionTitle extends StatelessWidget {
  const DcSectionTitle(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            letterSpacing: 1,
            color: DcColors.text));
  }
}

/// Bottom navigation (Dot Clash style): white bar, icons + tiny labels,
/// active tab black/filled, inactive grey. Top-level tabs only — tapping
/// the current tab does nothing; tapping another replaces the stack so
/// the back button exits from a top-level tab, like Dot Clash.
enum DcTab { home, play, shop }

class DotBottomNav extends StatelessWidget {
  const DotBottomNav({super.key, required this.current});
  final DcTab current;

  void _go(BuildContext context, DcTab tab) {
    if (tab == current) return;
    final route = switch (tab) {
      DcTab.home => '/home',
      DcTab.play => '/modes',
      DcTab.shop => '/shop',
    };
    Navigator.pushNamedAndRemoveUntil(context, route, (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: DcColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            _NavItem(
              icon: Icons.home,
              label: 'Home',
              active: current == DcTab.home,
              onTap: () => _go(context, DcTab.home),
            ),
            _NavItem(
              icon: Icons.sports_esports,
              label: 'Play',
              active: current == DcTab.play,
              onTap: () => _go(context, DcTab.play),
            ),
            _NavItem(
              icon: Icons.shopping_bag,
              label: 'Shop',
              active: current == DcTab.shop,
              onTap: () => _go(context, DcTab.shop),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem(
      {required this.icon,
      required this.label,
      required this.active,
      required this.onTap});
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? DcColors.text : DcColors.muted;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: 26, color: color, fill: active ? 1.0 : 0.0),
              const SizedBox(height: 2),
              Text(label,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight:
                          active ? FontWeight.w800 : FontWeight.w600,
                      color: color)),
            ],
          ),
        ),
      ),
    );
  }
}
