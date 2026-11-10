// Color Cover — Setup screen (v3 redesign).
// The v2 screen was a plain scrolling column of small chips and buttons
// and the user called its interface very bad (03:51 PKT). This version is
// built like the game itself: flat bright colours, sharp corners, heavy
// grotesque caps type, BIG tappable cards everywhere.
//  - Each player's tab is a big card filled with THEIR colour (live preview).
//  - Colour picker = big tiles with the colour NAME printed on them (60).
//  - Shape picker = big tiles with the shape drawn LARGE (30).
//  - Arena picker = 5 big tiles showing the real arena shape.
//  - VS COMPUTER gets a big YOU vs COMPUTER header + 3 big difficulty buttons.
//  - START BATTLE is HUGE, full-width, pinned at the bottom — always visible.
import 'package:flutter/material.dart';
import '../data/game_data.dart';
import '../game/coins.dart';
import '../game/match_theme.dart';
import '../game/sound.dart';
import '../widgets/ball_painter.dart';
import '../widgets/dot_chrome.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key, this.initialPack});
  final ModePack? initialPack;
  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  late ModePack _pack;
  late int _playerCount;
  late List<PlayerConfig> _players;
  int _editing = 0; // which player's card is open
  ArenaShape _arenaShape = ArenaShape.rectangle;
  BotDifficulty _botDifficulty = BotDifficulty.medium;

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
  }

  List<PlayerConfig> get _active => _players.sublist(0, _playerCount);

  void _setCount(int n) {
    if (_countLocked) return;
    setState(() {
      _playerCount = n;
      if (_editing >= n) _editing = 0;
    });
    SoundFx.click();
  }

  void _pickColour(GameColor c) {
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
    Navigator.pushNamed(
      context,
      '/game',
      arguments: MatchConfig(
        players: _active.map((p) => p.copy()).toList(),
        mode: gameModeForPack(_pack),
        arenaShape: _arenaShape,
        botDifficulty: _botDifficulty,
        trail: CoinsService.equippedTrail,
        pack: _pack,
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
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
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
                        fillColor: Colors.white,
                      ),
                      onChanged: (v) => setState(() => current.name =
                          v.trim().isEmpty ? 'Player ${_editing + 1}' : v.trim()),
                    ),
                    const SizedBox(height: 18),
                    _sectionTitle('COLOUR — 60 TO CHOOSE'),
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
                color: Colors.white,
                border:
                    Border(top: BorderSide(color: DcColors.border)),
              ),
              child: SizedBox(
                width: double.infinity,
                height: 72,
                child: TextButton(
                  onPressed: _startBattle,
                  style: TextButton.styleFrom(
                    backgroundColor: DcColors.orange,
                    foregroundColor: Colors.white,
                    shape: const StadiumBorder(),
                    textStyle: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1),
                  ),
                  child: const Text('START BATTLE'),
                ),
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
  /// 3 big difficulty pills (selected = orange, per Dot Clash).
  Widget _buildVsComputerCard() {
    return Container(
      padding: const EdgeInsets.all(16),
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
          const SizedBox(height: 4),
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
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: SizedBox(
                    height: 64,
                    child: TextButton(
                      onPressed: () =>
                          setState(() => _botDifficulty = d),
                      style: TextButton.styleFrom(
                        backgroundColor: selected
                            ? DcColors.orange
                            : Colors.white,
                        foregroundColor: selected
                            ? Colors.white
                            : DcColors.text,
                        side: selected
                            ? BorderSide.none
                            : const BorderSide(
                                color: DcColors.border, width: 1.5),
                        shape: const StadiumBorder(),
                        textStyle: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w900),
                      ),
                      child: Text(botDifficultyName(d).toUpperCase()),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  /// 5 big arena-shape preview tiles showing the real shape.
  Widget _buildArenaPicker(Color accent) {
    return Row(
      children: kArenaShapes.map((s) {
        final selected = _arenaShape == s;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              onTap: () {
                setState(() => _arenaShape = s);
                SoundFx.click();
              },
              child: Column(
                children: [
                  Container(
                    height: 88,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: const BorderRadius.all(
                          Radius.circular(12)),
                      border: Border.all(
                          color: selected
                              ? DcColors.orange
                              : DcColors.border,
                          width: selected ? 2.5 : 1),
                    ),
                    child: ArenaShapePreview(
                        shape: s, color: accent, size: 44),
                  ),
                  const SizedBox(height: 6),
                  Text(arenaShapeName(s),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: selected
                              ? DcColors.text
                              : DcColors.muted)),
                ],
              ),
            ),
          ),
        );
      }).toList(),
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
            child: SizedBox(
              height: 64,
              child: TextButton(
                onPressed: () => _setCount(n),
                style: TextButton.styleFrom(
                  backgroundColor:
                      selected ? DcColors.orange : Colors.white,
                  foregroundColor:
                      selected ? Colors.white : DcColors.text,
                  side: selected
                      ? BorderSide.none
                      : const BorderSide(
                          color: DcColors.border, width: 1.5),
                  shape: const StadiumBorder(),
                  textStyle: const TextStyle(
                      fontSize: 24, fontWeight: FontWeight.w900),
                ),
                child: Text('$n'),
              ),
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
                        overflow: TextOverflow.ellipsis),
                    Text(p.colour.name,
                        style: TextStyle(
                            color: fg.withOpacity(0.85), fontSize: 12),
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
        final bg =
            taken ? Color(c.value).withOpacity(0.35) : Color(c.value);
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
                  color: selected
                      ? contrastTextColor(Color(c.value))
                      : Colors.black26,
                  width: selected ? 3 : 1),
            ),
            child: Text(
              taken
                  ? '✕ ${c.name}'
                  : (selected ? '✓ ${c.name}' : c.name),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: contrastTextColor(Color(c.value))),
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
                  : Colors.white,
              borderRadius:
                  const BorderRadius.all(Radius.circular(12)),
              border: Border.all(
                  color: selected ? DcColors.orange : DcColors.border,
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
