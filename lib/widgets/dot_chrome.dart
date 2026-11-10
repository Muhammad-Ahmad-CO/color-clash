// Color Cover — Tiny Clash-style shared chrome.
// Palette + shared widgets for the APP CHROME only (home, modes, setup,
// shop, how-to, match chrome). The match ARENA is NOT styled here — it
// still follows REFERENCE_UI_SPEC.md (18x24 grid, flat territories,
// cue-colour balls) rendered bright/saturated, with soft ball shadows
// and glossy power-up tiles per TINY_CLASH_UI_SPEC.md.
// Source of the language: TINY_CLASH_UI_SPEC.md — dark navy UI, saturated
// blue vs red, gold value accents, heavy rounded extra-bold type with a
// dark outline, fully rounded pills, soft drop shadows, blue->cyan
// gradients on headers and primary buttons.
// NOTE: DcColors.orange / orangeDark keep their NAMES (dozens of call
// sites) but are re-valued: orange is now the primary blue, orangeDark
// is gold — the two accent colours every screen uses for selections,
// highlights and reward text.
import 'package:flutter/material.dart';

class DcColors {
  static const page = Color(0xFF1E2148); // deep navy menu background
  static const panel = Color(0xFF2B2E6E); // lighter navy card/panel
  static const bar = Color(0xFF232655); // top/bottom bars, darker navy
  static const card = panel;
  static const text = Colors.white;
  static const muted = Color(0xFFB9C0E8); // light lavender-grey
  static const border = Color(0xFF454A8F); // thin lighter-blue edge
  static const orange = Color(0xFF1FB6FF); // primary blue (was orange)
  static const orangeDark = Color(0xFFFFC531); // gold (was dark amber)
  static const danger = Color(0xFFFF2E3E);
  static const gold = Color(0xFFFFC531);
  static const blue = Color(0xFF1FB6FF);
  static const cyan = Color(0xFF2AA5FF);
  static const red = Color(0xFFFF2E3E);
  static const green = Color(0xFF37D67A);
  static const ink = Color(0xFF1A0A00); // dark text on light/gold tiles
  static const gradientBlue = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [Color(0xFF2AA5FF), Color(0xFF1FB6FF)],
  );
}

/// Heavy display text: white fill with a thick dark outline (Tiny Clash
/// style). Implemented as two identical Texts stacked: the bottom one
/// draws only the stroke, the top one the fill. Use only at >= 20 px —
/// at small sizes the stroke fills the letter counters and turns
/// illegible. [strokeWidth] defaults to 10% of the font size.
class TcOutlined extends StatelessWidget {
  const TcOutlined(
    this.text, {
    super.key,
    this.fontSize = 34,
    this.color = Colors.white,
    this.outline = const Color(0xFF0A0A1A),
    this.letterSpacing = 2,
    this.textAlign,
    this.height,
  });
  final String text;
  final double fontSize;
  final Color color;
  final Color outline;
  final double letterSpacing;
  final TextAlign? textAlign;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final base = TextStyle(
      fontSize: fontSize,
      fontWeight: FontWeight.w900,
      letterSpacing: letterSpacing,
      height: height,
    );
    return Stack(
      children: [
        Text(
          text,
          textAlign: textAlign,
          style: base.copyWith(
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = fontSize * 0.10
              ..strokeJoin = StrokeJoin.round
              ..color = outline,
          ),
        ),
        Text(
          text,
          textAlign: textAlign,
          style: base.copyWith(color: color),
        ),
      ],
    );
  }
}

/// Primary action: fully rounded blue->cyan gradient pill, white bold
/// text, soft drop shadow. One per screen. [color] overrides the
/// gradient with a solid fill (used for selected states); [borderColor]
/// adds a thin edge (used for unselected pills).
class DcPillButton extends StatelessWidget {
  const DcPillButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.height = 56,
    this.fontSize = 18,
    this.color,
    this.foreground,
    this.borderColor,
    this.icon,
  });
  final String label;
  final VoidCallback? onPressed;
  final double height;
  final double fontSize;
  final Color? color;
  final Color? foreground;
  final Color? borderColor;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null;
    final decoration = BoxDecoration(
      gradient: color == null && !disabled ? DcColors.gradientBlue : null,
      color: color ?? (disabled ? DcColors.panel : null),
      borderRadius: const BorderRadius.all(Radius.circular(999)),
      border: borderColor == null
          ? null
          : Border.all(color: borderColor!, width: 1.5),
      boxShadow: disabled
          ? null
          : [
              BoxShadow(
                color: Colors.black.withOpacity(0.35),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
    );
    return SizedBox(
      width: double.infinity,
      height: height,
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: decoration,
          child: InkWell(
            onTap: onPressed,
            borderRadius: const BorderRadius.all(Radius.circular(999)),
            child: Center(
              child: icon == null
                  ? Text(
                      label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: fontSize,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                        color: foreground ??
                            (disabled ? DcColors.muted : Colors.white),
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(icon,
                            size: fontSize,
                            color: foreground ??
                                (disabled
                                    ? DcColors.muted
                                    : Colors.white)),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            label,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: fontSize,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1,
                              color: foreground ??
                                  (disabled
                                      ? DcColors.muted
                                      : Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Secondary action: navy panel pill with a lighter-blue edge, white text.
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
    final disabled = onPressed == null;
    return SizedBox(
      width: double.infinity,
      height: height,
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            color: DcColors.panel,
            borderRadius: const BorderRadius.all(Radius.circular(999)),
            border: Border.all(color: DcColors.border, width: 1.5),
            boxShadow: disabled
                ? null
                : [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
          ),
          child: InkWell(
            onTap: onPressed,
            borderRadius: const BorderRadius.all(Radius.circular(999)),
            child: Center(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                  color: disabled ? DcColors.muted : Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Navy panel card: 18px corners, thin lighter-blue edge, soft shadow.
class DcCard extends StatelessWidget {
  const DcCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color,
    this.borderColor,
    this.borderWidth = 1,
    this.radius = 18,
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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Section heading: white, extra-bold, wide letter spacing.
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

/// Bottom navigation: dark navy bar, icons + tiny labels, active tab
/// gold/filled, inactive muted lavender. Top-level tabs only — tapping
/// the current tab does nothing; tapping another replaces the stack so
/// the back button exits from a top-level tab.
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
        color: DcColors.bar,
        border: Border(top: BorderSide(color: DcColors.border)),
        boxShadow: [
          BoxShadow(
            color: Colors.black45,
            blurRadius: 12,
            offset: Offset(0, -4),
          ),
        ],
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
    final color = active ? DcColors.gold : DcColors.muted;
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
