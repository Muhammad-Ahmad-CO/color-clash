// Color Cover — Setup screen (Tiny Clash chrome, v3.5).
// Dark-navy menu: big tappable cards, blue-gradient selections, gold
// accents. Built like the game itself: flat bright colours, heavy
// grotesque caps type, BIG tappable cards everywhere.
//  - Each player's tab is a big card filled with THEIR colour (live preview).
//  - Colour picker = big tiles with the colour NAME printed on them (62,
//    including 2 rare colours locked until earned).
//  - Shape picker = big tiles with the shape drawn LARGE (30).
//  - Arena picker = 6 big tiles showing the real arena shape + RANDOM.
//  - VS COMPUTER gets a big YOU vs COMPUTER header + 3 big difficulty buttons
//    (bot ladder: Easy open, Medium/Crazy unlock by beating the previous).
//  - Series picker for 2 players: Single / Best of 3 / Best of 5.
//  - START BATTLE is HUGE, full-width, pinned at the bottom — always visible.
import 'dart:math';
import 'package:flutter/material.dart';
import '../data/game_data.dart';
import '../game/coins.dart';
import '../game/match_theme.dart';
import '../game/sound.dart';
import '../game/stats.dart';
import '../widgets/ball_painter.dart';
import '../widgets/dot_chrome.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key, this.initialPack, this.initialDailyChallenge = false});
  final ModePack? initialPack;
  final bool initialDailyChallenge;
  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  late ModePack _pack;
  late int _playerCount;
  late List<PlayerConfig> _players;
  int _editing = 0; // which player's card is open
  ArenaShape _arenaShape = ArenaShape.rectangle;
  bool _randomArena = false;
  BotDifficulty _botDifficulty = BotDifficulty.easy;
  /// Wins needed to take the series: 1 = single, 2 = Best of 3, 3 = Best
  /// of 5. Only for 2 players / VS COMPUTER.
  int _seriesWinsNeeded = 1;

  /// Modes force the player count: Team 2v2 and Battle Royale need 4,
  /// VS COMPUTER is 1 human + 1 computer (2 slots, P2 is the computer).
  bool get _countLocked =>
      _pack == ModePack.team2v2 || _pack == ModePack.battleRoyale || _pack == ModePack.vsBot;

  @override
  void initState() {
    super.initState();
    _pack = widget.initialPack ?? ModePack.ultimate;
    _playerCount = _pack == ModePack.team2v2 || _pack == ModePack.battleRoyale ? 4 : 2;
    _players = [
      PlayerConfig(name: 'Player 1', colour: kColours[0], shape: BallShape.circle),
      PlayerConfig(name: 'Player 2', colour: kColours[1], shape: BallShape.square),
      PlayerConfig(name: 'Player 3', colour: kColours[2], shape: BallShape.triangle),
      PlayerConfig(name: 'Player 4', colour: kColours[3], shape: BallShape.star),
    ];
    if (_pack == ModePack.vsBot) _players[1].name = 'COMPUTER';
    CoinsService.load();
    // Bot ladder + rare colours need StatsService; load it, then clamp
    // the difficulty (a locked default would be unselectable).
    StatsService.load().then((_) {
      if (!mounted) return;
      setState(() {
        if (!StatsService.isBotUnlocked(_botDifficulty)) {
          _botDifficulty = BotDifficulty.easy;
        }
      });
    });
  }

  List<PlayerConfig> get _active => _players.sublist(0, _playerCount);

  void _setCount(int n) {
    if (_countLocked) return;
    setState(() {
      _playerCount = n;
      if (_editing >= n) _editing = 0;
      // Series only exist for 2 players — switching away resets it.
      if (n != 2) _seriesWinsNeeded = 1;
    });
    SoundFx.click();
  }

  void _pickColour(GameColor c) {
    // Rare colours are locked until earned — tapping one explains how.
    final rareKey = kRareColourUnlock[c.name];
    if (rareKey != null && !StatsService.isColourUnlocked(rareKey)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                '${c.name} is locked. Unlock: ${rareColourUnlockText(c.name)}.')),
      );
      return;
    }
    final takenBy = _active.indexWhere((p) => p.colour.value == c.value);
    if (takenBy >= 0 && takenBy != _editing) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${c.name} is already taken by ${_active[takenBy].name}. Pick another colour.')),
      );
      return;
    }
    setState(() => _active[_editing].colour = c);
    SoundFx.click();
  }

  void _startBattle() {
    SoundFx.click();
    // RANDOM arena: pick one of the 5 real shapes now, so the engine
    // always sees a concrete shape.
    final shape = _randomArena
        ? kArenaShapes[Random().nextInt(kArenaShapes.length)]
        : _arenaShape;
    Navigator.pushNamed(
      context,
      '/game',
      arguments: MatchConfig(
        players: _active.map((p) => p.copy()).toList(),
        mode: gameModeForPack(_pack),
        arenaShape: shape,
        botDifficulty: _botDifficulty,
        trail: CoinsService.equippedTrail,
        pack: _pack,
        seriesWinsNeeded: _seriesWinsNeeded,
        isDailyChallenge: widget.initialDailyChallenge,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final current = _active[_editing];
    final currentColor = Color(current.colour.value);
    return Scaffold(
      backgroundColor: DcColors.page,
      appBar: AppBar(
        title: const Text('SETUP YOUR BATTLE',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 22)),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildModeCard(),
                    if (_pack == ModePack.vsBot) ...[
                      const SizedBox(height: 16),
                      _buildVsComputerCard(),
                    ],
                    const SizedBox(height: 18),
                    _sectionTitle('ARENA SHAPE'),
                    const SizedBox(height: 10),
                    _buildArenaPicker(currentColor),
                    const SizedBox(height: 8),
                    const Text(
                        'Tiles outside the shape are dead and cannot be painted.',
                        style: TextStyle(color: DcColors.muted, fontSize: 14)),
                    const SizedBox(height: 18),
                    _sectionTitle('HOW MANY PLAYERS?'),
                    const SizedBox(height: 10),
                    _buildCountPicker(),
                    const SizedBox(height: 8),
                    if (_countLocked)
                      Text(
                        _pack == ModePack.vsBot
                            ? 'VS COMPUTER: 1 human + 1 computer (fixed).'
                            : 'This mode needs 4 players (fixed).',
                        style: const TextStyle(
                            color: DcColors.orangeDark,
                            fontSize: 15,
                            fontWeight: FontWeight.w700),
                      ),
                    Text(
                      _playerCount == 2
                          ? '2 players: left half vs right half — each player drags in their own half.'
                          : _playerCount == 3
                              ? '3 players: drag in three vertical thirds.'
                              : '4 players: drag in four corners (2 x 2).',
                      style: const TextStyle(color: DcColors.muted, fontSize: 15),
                    ),
                    if (_playerCount == 2) ...[
                      const SizedBox(height: 18),
                      _sectionTitle('MATCH SERIES'),
                      const SizedBox(height: 10),
                      _buildSeriesPicker(),
                      const SizedBox(height: 8),
                      const Text(
                          'Best of 3: first to 2 wins takes the series. Best of 5: first to 3.',
                          style: TextStyle(color: DcColors.muted, fontSize: 15)),
                    ],
                    const SizedBox(height: 18),
                    _sectionTitle('CHOOSE YOUR PLAYER'),
                    const SizedBox(height: 10),
                    _buildPlayerTabs(),
                    const SizedBox(height: 18),
                    TextField(
                      key: ValueKey('name-$_editing'),
                      controller: TextEditingController(text: current.name)
                        ..selection = TextSelection.fromPosition(
                            TextPosition(offset: current.name.length)),
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: DcColors.text),
                      decoration: InputDecoration(
                        labelText: 'Player ${_editing + 1} name',
                        labelStyle: const TextStyle(color: DcColors.muted),
                        border: const OutlineInputBorder(
                            borderRadius:
                                BorderRadius.all(Radius.circular(12)),
                            borderSide:
                                BorderSide(color: DcColors.border)),
                        enabledBorder: const OutlineInputBorder(
                            borderRadius:
                                BorderRadius.all(Radius.circular(12)),
                            borderSide:
                                BorderSide(color: DcColors.border)),
                        focusedBorder: const OutlineInputBorder(
                            borderRadius:
                                BorderRadius.all(Radius.circular(12)),
                            borderSide: BorderSide(
                                color: DcColors.orange, width: 2)),
                        filled: true,
                        fillColor: DcColors.bar,
                      ),
                      onChanged: (v) => setState(() => current.name =
                          v.trim().isEmpty ? 'Player ${_editing + 1}' : v.trim()),
                    ),
                    const SizedBox(height: 18),
                    _sectionTitle('COLOUR — 62 TO CHOOSE'),
                    const SizedBox(height: 10),
                    _buildColourGrid(current),
                    const SizedBox(height: 18),
                    _sectionTitle('BALL SHAPE — 30 TO CHOOSE'),
                    const SizedBox(height: 10),
                    _buildShapeGrid(current, currentColor),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
            // START BATTLE — huge, full-width, pinned at the bottom and
            // always visible, never buried below the scroll.
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
              decoration: const BoxDecoration(
                color: DcColors.bar,
                border:
                    Border(top: BorderSide(color: DcColors.border)),
              ),
              child: DcPillButton(
                label: 'START BATTLE',
                height: 72,
                fontSize: 26,
                onPressed: _startBattle,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Text(text,
        style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            letterSpacing: 1,
            color: DcColors.text));
  }

  /// Big mode card: number tile + name + description + CHANGE.
  Widget _buildModeCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: DcColors.card,
        borderRadius: const BorderRadius.all(Radius.circular(14)),
        border: Border.all(color: DcColors.border, width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              color: Color(0xFFFD6EA3),
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
            alignment: Alignment.center,
            child: Text(
              '${kModePacks.indexOf(_pack) + 1}',
              style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF210044)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('MODE: ${modePackName(_pack)}',
                    style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: DcColors.text)),
                Text(modePackDesc(_pack),
                    style:
                        const TextStyle(fontSize: 15, color: DcColors.muted)),
              ],
            ),
          ),
          TextButton(
            onPressed: () {
              SoundFx.click();
              Navigator.pushNamed(context, '/modes');
            },
            child: const Text('CHANGE',
                style: TextStyle(
                    color: DcColors.orange,
                    fontWeight: FontWeight.w900,
                    fontSize: 16)),
          ),
        ],
      ),
    );
  }

  /// VS COMPUTER header: big off-white card with an orange border +
  /// 3 big difficulty pills (selected = blue gradient, per Tiny Clash).
  /// Bot ladder: Easy is always open; Medium unlocks by beating Easy,
  /// Crazy by beating Medium. Locked pills are dimmed with a lock and
  /// explain how to unlock them.
  Widget _buildVsComputerCard() {
    return Container(
      // Extra top padding so the header never sits tight against the
      // card's top edge (the phone screenshot showed the subtitle
      // half-sliced at the top of the screen while scrolling).
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      decoration: BoxDecoration(
        color: DcColors.card,
        borderRadius: const BorderRadius.all(Radius.circular(14)),
        border: Border.all(color: DcColors.orange, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('YOU  vs  COMPUTER',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: DcColors.text)),
          const SizedBox(height: 6),
          const Text('You are Player 1. The COMPUTER is Player 2.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: DcColors.muted)),
          const SizedBox(height: 12),
          Row(
            children: BotDifficulty.values.map((d) {
              final selected = _botDifficulty == d;
              final locked = !StatsService.isBotUnlocked(d);
              final label = botDifficultyName(d).toUpperCase();
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: DcPillButton(
                    label: label,
                    height: 64,
                    fontSize: 20,
                    icon: locked ? Icons.lock : null,
                    color: locked
                        ? DcColors.bar
                        : (selected ? null : DcColors.panel),
                    foreground:
                        locked ? DcColors.muted : Colors.white,
                    borderColor: locked
                        ? null
                        : (selected ? null : DcColors.border),
                    onPressed: () {
                      if (locked) {
                        final need = d == BotDifficulty.medium
                            ? 'Easy'
                            : 'Medium';
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text(
                                  '${botDifficultyName(d)} is locked. Beat $need first!')),
                        );
                        return;
                      }
                      setState(() => _botDifficulty = d);
                    },
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 10),
          Text(_ladderHint(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: DcColors.orangeDark)),
        ],
      ),
    );
  }

  String _ladderHint() {
    if (!StatsService.isBotUnlocked(BotDifficulty.medium)) {
      return 'Beat EASY to unlock MEDIUM.';
    }
    if (!StatsService.isBotUnlocked(BotDifficulty.crazy)) {
      return 'Beat MEDIUM to unlock CRAZY.';
    }
    return 'All difficulties unlocked — go for CHAMPION!';
  }

  /// Series picker: Single / Best of 3 / Best of 5 (2 players only).
  Widget _buildSeriesPicker() {
    const options = <(int, String)>[
      (1, 'SINGLE'),
      (2, 'BEST OF 3'),
      (3, 'BEST OF 5'),
    ];
    return Row(
      children: options.map((o) {
        final selected = _seriesWinsNeeded == o.$1;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: DcPillButton(
              label: o.$2,
              height: 56,
              fontSize: 16,
              color: selected ? null : DcColors.panel,
              borderColor: selected ? null : DcColors.border,
              onPressed: () {
                setState(() => _seriesWinsNeeded = o.$1);
                SoundFx.click();
              },
            ),
          ),
        );
      }).toList(),
    );
  }

  /// 6 big arena tiles: the 5 real shapes + RANDOM (a drawn dice — a
  /// random shape is picked when the battle starts).
  Widget _buildArenaPicker(Color accent) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      // Fixed cell height: 88 px preview + 6 px gap + ~16 px label +
      // slack. The old childAspectRatio 1.1 gave ~94 px cells on a
      // 360 px phone while the content needs ~109 px, so the first
      // row's labels were cut off mid-text by the next row.
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          mainAxisExtent: 118),
      itemCount: kArenaShapes.length + 1,
      itemBuilder: (context, i) {
        final isRandom = i == kArenaShapes.length;
        final shape = isRandom ? null : kArenaShapes[i];
        final selected = isRandom ? _randomArena : (!_randomArena && _arenaShape == shape);
        final name = isRandom ? 'Random' : arenaShapeName(shape!);
        return InkWell(
          onTap: () {
            setState(() {
              if (isRandom) {
                _randomArena = true;
              } else {
                _randomArena = false;
                _arenaShape = shape!;
              }
            });
            SoundFx.click();
          },
          child: Column(
            children: [
              Container(
                height: 88,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: DcColors.panel,
                  borderRadius:
                      const BorderRadius.all(Radius.circular(12)),
                  border: Border.all(
                      color: selected ? DcColors.blue : DcColors.border,
                      width: selected ? 2.5 : 1),
                ),
                child: isRandom
                    ? CustomPaint(
                        size: const Size(44, 44),
                        painter: _DicePainter(accent),
                      )
                    : ArenaShapePreview(shape: shape!, size: 44),
              ),
              const SizedBox(height: 6),
              Text(name,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: selected ? DcColors.text : DcColors.muted)),
            ],
          ),
        );
      },
    );
  }

  /// 2 / 3 / 4 as big buttons.
  Widget _buildCountPicker() {
    return Row(
      children: [2, 3, 4].map((n) {
        final selected = _playerCount == n;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: DcPillButton(
              label: '$n',
              height: 64,
              fontSize: 24,
              color: selected ? null : DcColors.panel,
              borderColor: selected ? null : DcColors.border,
              onPressed: () => _setCount(n),
            ),
          ),
        );
      }).toList(),
    );
  }

  /// Big player tabs: each card is FILLED with that player's colour
  /// (live preview) — shape, name and colour name in contrasting text.
  Widget _buildPlayerTabs() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(_playerCount, (i) {
        final p = _active[i];
        final selected = _editing == i;
        final bg = Color(p.colour.value);
        final fg = contrastTextColor(bg);
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              onTap: () => setState(() => _editing = i),
              child: Container(
                height: 124,
                padding:
                    const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: const BorderRadius.all(
                      Radius.circular(12)),
                  border: Border.all(
                      color: selected
                          ? contrastTextColor(bg)
                          : DcColors.border,
                      width: selected ? 3 : 1),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ShapePreview(shape: p.shape, color: fg, size: 44),
                    const SizedBox(height: 6),
                    Text(p.name.toUpperCase(),
                        style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                            color: fg),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    Text(p.colour.name,
                        style: TextStyle(
                            color: fg.withOpacity(0.85), fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    if (selected)
                      Text('EDITING',
                          style: TextStyle(
                              color: fg,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1)),
                  ],
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  /// Colour picker: big tiles with the colour NAME printed on them.
  /// Rare colours show a lock until earned (tap explains how to unlock).
  Widget _buildColourGrid(PlayerConfig current) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 2.6),
      itemCount: kColours.length,
      itemBuilder: (context, i) {
        final c = kColours[i];
        final selected = current.colour.value == c.value;
        final takenBy = _active.indexWhere((p) => p.colour.value == c.value);
        final taken = takenBy >= 0 && takenBy != _editing;
        final rareKey = kRareColourUnlock[c.name];
        final locked =
            rareKey != null && !StatsService.isColourUnlocked(rareKey);
        final bg = locked
            ? Color(c.value).withOpacity(0.25)
            : (taken ? Color(c.value).withOpacity(0.35) : Color(c.value));
        final fg = contrastTextColor(Color(c.value));
        return InkWell(
          onTap: () => _pickColour(c),
          borderRadius: const BorderRadius.all(Radius.circular(10)),
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: bg,
              borderRadius:
                  const BorderRadius.all(Radius.circular(10)),
              border: Border.all(
                  color: selected ? fg : Colors.black26,
                  width: selected ? 3 : 1),
            ),
            child: locked
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.lock, size: 13, color: fg),
                      const SizedBox(width: 3),
                      Flexible(
                        child: Text(c.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: fg)),
                      ),
                    ],
                  )
                : Text(
                    taken
                        ? '✕ ${c.name}'
                        : (selected ? '✓ ${c.name}' : c.name),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: fg),
                  ),
          ),
        );
      },
    );
  }

  /// Shape picker: big tiles with the shape drawn LARGE.
  Widget _buildShapeGrid(PlayerConfig current, Color currentColor) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 0.82),
      itemCount: kShapes.length,
      itemBuilder: (context, i) {
        final s = kShapes[i];
        final selected = current.shape == s;
        return InkWell(
          onTap: () {
            setState(() => current.shape = s);
            SoundFx.click();
          },
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: selected
                  ? currentColor.withOpacity(0.35)
                  : DcColors.panel,
              borderRadius:
                  const BorderRadius.all(Radius.circular(12)),
              border: Border.all(
                  color: selected ? DcColors.blue : DcColors.border,
                  width: selected ? 3 : 1),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ShapePreview(shape: s, color: currentColor, size: 46),
                const SizedBox(height: 4),
                Text(shapeName(s),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: DcColors.text),
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Drawn dice icon (for the RANDOM arena tile): a rounded square with
/// five white dots — drawn paths, never an emoji or a photo.
class _DicePainter extends CustomPainter {
  _DicePainter(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(w * 0.12, h * 0.12, w * 0.76, h * 0.76),
            Radius.circular(w * 0.12)),
        Paint()..color = color);
    final dot = Paint()..color = Colors.white;
    const spots = <(double, double)>[
      (0.3, 0.3),
      (0.7, 0.3),
      (0.5, 0.5),
      (0.3, 0.7),
      (0.7, 0.7),
    ];
    for (final (fx, fy) in spots) {
      canvas.drawCircle(Offset(w * fx, h * fy), w * 0.06, dot);
    }
  }

  @override
  bool shouldRepaint(covariant _DicePainter old) => old.color != color;
}
