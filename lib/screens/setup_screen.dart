// Color Cover — Setup screen.
// Pick 2, 3 or 4 players. Each player picks a name, one of 54 colours
// (each colour can be used only once) and one of 24 ball shapes.
import 'package:flutter/material.dart';
import '../data/game_data.dart';
import '../game/coins.dart';
import '../game/sound.dart';
import '../main.dart';
import '../widgets/ball_painter.dart';

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

  @override
  Widget build(BuildContext context) {
    final current = _active[_editing];
    return Scaffold(
      appBar: AppBar(
        title: const Text('SETUP YOUR BATTLE', style: TextStyle(fontWeight: FontWeight.w900)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Mode chosen from the Modes section.
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF7C4DFF).withOpacity(0.25),
                  border: Border.all(color: const Color(0xFF7C4DFF), width: 1.5),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      color: const Color(0xFFFD6EA3),
                      alignment: Alignment.center,
                      child: Text(
                        '${kModePacks.indexOf(_pack) + 1}',
                        style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF210044)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('MODE: ${modePackName(_pack)}',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                          Text(modePackDesc(_pack),
                              style: const TextStyle(fontSize: 14, color: Colors.white70)),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        SoundFx.click();
                        Navigator.pushNamed(context, '/modes');
                      },
                      child: const Text('CHANGE',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              if (_pack == ModePack.vsBot) ...[
                const Text('Bot difficulty',
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                Row(
                  children: BotDifficulty.values.map((d) {
                    final selected = _botDifficulty == d;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ElevatedButton(
                          onPressed: () => setState(() => _botDifficulty = d),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: selected ? const Color(0xFFFF7BAC) : Colors.white12,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: Text(botDifficultyName(d),
                              style: const TextStyle(fontWeight: FontWeight.w800)),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 6),
                const Text('You are Player 1. The COMPUTER is Player 2 — drag anywhere on the arena to steer.',
                    style: TextStyle(color: Colors.white70, fontSize: 14)),
                const SizedBox(height: 18),
              ],
              const Text('Arena shape',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: kArenaShapes.map((s) {
                  final selected = _arenaShape == s;
                  return ChoiceChip(
                    label: Text(arenaShapeName(s),
                        style: const TextStyle(fontWeight: FontWeight.w800)),
                    selected: selected,
                    selectedColor: const Color(0xFFFF7BAC),
                    backgroundColor: Colors.white12,
                    labelStyle: const TextStyle(color: Colors.white),
                    shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.zero),
                    onSelected: (_) => setState(() => _arenaShape = s),
                  );
                }).toList(),
              ),
              const SizedBox(height: 6),
              const Text('Tiles outside the shape are dead and cannot be painted.',
                  style: TextStyle(color: Colors.white70, fontSize: 14)),
              const SizedBox(height: 18),
              const Text('How many players?',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              Row(
                children: [2, 3, 4].map((n) {
                  final selected = _playerCount == n;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ElevatedButton(
                        onPressed: () => _setCount(n),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: selected ? const Color(0xFFFF7BAC) : Colors.white12,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                        ),
                        child: Text('$n'),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
              if (_countLocked)
                Text(
                  _pack == ModePack.vsBot
                      ? 'VS COMPUTER: 1 human + 1 computer (fixed).'
                      : 'This mode needs 4 players (fixed).',
                  style: const TextStyle(color: Colors.amber, fontSize: 15, fontWeight: FontWeight.w700),
                ),
              Text(
                _playerCount == 2
                    ? '2 players: drag in the left half vs the right half.'
                    : _playerCount == 3
                        ? '3 players: drag in three vertical thirds.'
                        : '4 players: drag in four corners (2 x 2).',
                style: const TextStyle(color: Colors.white70, fontSize: 15),
              ),
              const SizedBox(height: 18),
              const Text('Choose a player to set up:',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              Row(
                children: List.generate(_playerCount, (i) {
                  final p = _active[i];
                  final selected = _editing == i;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: InkWell(
                        onTap: () => setState(() => _editing = i),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
                          decoration: BoxDecoration(
                            color: selected ? Color(p.colour.value).withOpacity(0.35) : Colors.white10,
                            border: Border.all(
                                color: selected ? Color(p.colour.value) : Colors.white24, width: 2),
                          ),
                          child: Column(
                            children: [
                              ShapePreview(shape: p.shape, color: Color(p.colour.value), size: 40),
                              const SizedBox(height: 6),
                              Text(p.name,
                                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                                  overflow: TextOverflow.ellipsis),
                              Text(p.colour.name,
                                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                                  overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 18),
              TextField(
                key: ValueKey('name-$_editing'),
                controller: TextEditingController(text: current.name)
                  ..selection = TextSelection.fromPosition(
                      TextPosition(offset: current.name.length)),
                decoration: InputDecoration(
                  labelText: 'Player ${_editing + 1} name',
                  border: const OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.white10,
                ),
                onChanged: (v) => setState(() => current.name = v.trim().isEmpty ? 'Player ${_editing + 1}' : v.trim()),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  const Text('Color — 54 to choose',
                      style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    color: Color(current.colour.value),
                    child: Text(current.colour.name,
                        style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.white)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 6, crossAxisSpacing: 8, mainAxisSpacing: 8),
                itemCount: kColours.length,
                itemBuilder: (context, i) {
                  final c = kColours[i];
                  final selected = current.colour.value == c.value;
                  final takenBy = _active.indexWhere((p) => p.colour.value == c.value);
                  final taken = takenBy >= 0 && takenBy != _editing;
                  return InkWell(
                    onTap: () => _pickColour(c),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Color(c.value),
                        border: Border.all(
                            color: selected ? Colors.white : Colors.white24,
                            width: selected ? 3 : 1),
                      ),
                      child: taken
                          ? const Center(
                              child: Text('✕', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)))
                          : (selected
                              ? const Center(
                                  child: Text('✓', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20)))
                              : null),
                    ),
                  );
                },
              ),
              const SizedBox(height: 18),
              const Text('Ball shape — 24 to choose',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4, crossAxisSpacing: 8, mainAxisSpacing: 8),
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
                        color: selected ? Color(current.colour.value).withOpacity(0.35) : Colors.white10,
                        border: Border.all(
                            color: selected ? Color(current.colour.value) : Colors.white24,
                            width: selected ? 3 : 1),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ShapePreview(shape: s, color: Color(current.colour.value), size: 36),
                          const SizedBox(height: 2),
                          Text(shapeName(s),
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                              overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 22),
              BigButton(
                label: 'START BATTLE',
                color: const Color(0xFFFF7BAC),
                onPressed: () {
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
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
