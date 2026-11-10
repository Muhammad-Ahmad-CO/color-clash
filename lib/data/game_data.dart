// Color Cover — static game data.
// Counts are fixed by design: 62 colours (60 + 2 rare unlockables),
// 30 ball shapes, 10 base power-ups + Bomb Ball + FREEZE + MAGNET + TRINITY
// + TURRET = 15 total power-ups.
// Do not change the counts without updating Setup + README.

/// One pickable colour: a human name + an ARGB hex value.
class GameColor {
  const GameColor(this.name, this.value);
  final String name;
  final int value; // 0xFFRRGGBB
}

const int kColourCount = 62;

/// EXACTLY 62 colours. Names are unique, hex values are unique.
/// The last two are RARE: locked until earned (see kRareColourUnlock).
const List<GameColor> kColours = [
  GameColor('Indigo', 0xFF3F2A7A),
  GameColor('Pink', 0xFFFF7BAC),
  GameColor('Latte', 0xFFF5E6C8),
  GameColor('Roast', 0xFF6B3A1F),
  GameColor('Ruby Red', 0xFFE6193C),
  GameColor('Crimson', 0xFFB3001B),
  GameColor('Cherry', 0xFFD81B60),
  GameColor('Hot Pink', 0xFFFF1493),
  GameColor('Magenta', 0xFFFF00FF),
  GameColor('Purple', 0xFF8E24AA),
  GameColor('Violet', 0xFF7C4DFF),
  GameColor('Lavender', 0xFFB39DDB),
  GameColor('Deep Blue', 0xFF0D47A1),
  GameColor('Royal Blue', 0xFF1565C0),
  GameColor('Sky Blue', 0xFF29B6F6),
  GameColor('Cyan', 0xFF00BCD4),
  GameColor('Teal', 0xFF00897B),
  GameColor('Mint', 0xFF80CBC4),
  GameColor('Emerald', 0xFF00C853),
  GameColor('Green', 0xFF43A047),
  GameColor('Lime', 0xFF9CCC65),
  GameColor('Olive', 0xFF827717),
  GameColor('Mustard', 0xFFFFCA28),
  GameColor('Gold', 0xFFFFB300),
  GameColor('Amber', 0xFFFF8F00),
  GameColor('Orange', 0xFFFF6D00),
  GameColor('Tangerine', 0xFFFF7043),
  GameColor('Peach', 0xFFFFAB91),
  GameColor('Coral', 0xFFFF6F61),
  GameColor('Salmon', 0xFFFA8072),
  GameColor('Brown', 0xFF795548),
  GameColor('Chocolate', 0xFF5D4037),
  GameColor('Coffee', 0xFF4E342E),
  GameColor('Cream', 0xFFFFF3E0),
  GameColor('Beige', 0xFFD7CCC8),
  GameColor('Grey', 0xFF78909C),
  GameColor('Slate', 0xFF546E7A),
  GameColor('Charcoal', 0xFF37474F),
  GameColor('Black', 0xFF212121),
  GameColor('White', 0xFFFAFAFA),
  GameColor('Silver', 0xFFB0BEC5),
  GameColor('Navy', 0xFF1A237E),
  GameColor('Turquoise', 0xFF26A69A),
  GameColor('Aqua', 0xFF4DD0E1),
  GameColor('Lilac', 0xFFCE93D8),
  GameColor('Plum', 0xFF6A1B9A),
  GameColor('Rose', 0xFFF06292),
  GameColor('Lemon', 0xFFFFEE58),
  GameColor('Lime Neon', 0xFFC6FF00),
  GameColor('Forest', 0xFF2E7D32),
  GameColor('Jade', 0xFF26A65B),
  GameColor('Denim', 0xFF3D5AFE),
  GameColor('Ice Blue', 0xFFB3E5FC),
  GameColor('Sunset', 0xFFFF5722),
  GameColor('Maroon', 0xFF800000),
  GameColor('Burgundy', 0xFF800020),
  GameColor('Copper', 0xFFB87333),
  GameColor('Khaki', 0xFFC3B091),
  GameColor('Orchid', 0xFFDA70D6),
  GameColor('Electric Blue', 0xFF7DF9FF),
  GameColor('Champion Gold', 0xFFFFD700),
  GameColor('Streak Flame', 0xFFFF3D00),
];

/// Rare colours: locked until earned. The keys are the shared unlock ids
/// used by StatsService and the Setup colour picker — keep them in sync.
const String kRareChampionGold = 'champion_gold';
const String kRareStreakFlame = 'streak_flame';
const Map<String, String> kRareColourUnlock = {
  'Champion Gold': kRareChampionGold,
  'Streak Flame': kRareStreakFlame,
};

/// How to unlock a rare colour, shown in the Setup picker.
String rareColourUnlockText(String name) {
  switch (name) {
    case 'Champion Gold':
      return 'Beat the COMPUTER on Crazy';
    case 'Streak Flame':
      return 'Play 7 days in a row';
    default:
      return '';
  }
}

/// The 30 ball shapes, drawn with CustomPainter (no image assets).
enum BallShape {
  circle,
  square,
  triangle,
  diamond,
  star,
  heart,
  pentagon,
  hexagon,
  octagon,
  oval,
  crescent,
  lightning,
  teardrop,
  cross,
  flower,
  moon,
  sun,
  arrow,
  ring,
  blob,
  cube,
  pyramid,
  snowflake,
  smiley,
  clover,
  rocket,
  crown,
  anchor,
  bell,
  gem,
}

const int kShapeCount = 30;

const List<BallShape> kShapes = [
  BallShape.circle,
  BallShape.square,
  BallShape.triangle,
  BallShape.diamond,
  BallShape.star,
  BallShape.heart,
  BallShape.pentagon,
  BallShape.hexagon,
  BallShape.octagon,
  BallShape.oval,
  BallShape.crescent,
  BallShape.lightning,
  BallShape.teardrop,
  BallShape.cross,
  BallShape.flower,
  BallShape.moon,
  BallShape.sun,
  BallShape.arrow,
  BallShape.ring,
  BallShape.blob,
  BallShape.cube,
  BallShape.pyramid,
  BallShape.snowflake,
  BallShape.smiley,
  BallShape.clover,
  BallShape.rocket,
  BallShape.crown,
  BallShape.anchor,
  BallShape.bell,
  BallShape.gem,
];

String shapeName(BallShape s) {
  switch (s) {
    case BallShape.circle:
      return 'Circle';
    case BallShape.square:
      return 'Square';
    case BallShape.triangle:
      return 'Triangle';
    case BallShape.diamond:
      return 'Diamond';
    case BallShape.star:
      return 'Star';
    case BallShape.heart:
      return 'Heart';
    case BallShape.pentagon:
      return 'Pentagon';
    case BallShape.hexagon:
      return 'Hexagon';
    case BallShape.octagon:
      return 'Octagon';
    case BallShape.oval:
      return 'Oval';
    case BallShape.crescent:
      return 'Crescent';
    case BallShape.lightning:
      return 'Lightning';
    case BallShape.teardrop:
      return 'Teardrop';
    case BallShape.cross:
      return 'Cross';
    case BallShape.flower:
      return 'Flower';
    case BallShape.moon:
      return 'Moon';
    case BallShape.sun:
      return 'Sun';
    case BallShape.arrow:
      return 'Arrow';
    case BallShape.ring:
      return 'Ring';
    case BallShape.blob:
      return 'Blob';
    case BallShape.cube:
      return 'Cube';
    case BallShape.pyramid:
      return 'Pyramid';
    case BallShape.snowflake:
      return 'Snowflake';
    case BallShape.smiley:
      return 'Smiley';
    case BallShape.clover:
      return 'Clover';
    case BallShape.rocket:
      return 'Rocket';
    case BallShape.crown:
      return 'Crown';
    case BallShape.anchor:
      return 'Anchor';
    case BallShape.bell:
      return 'Bell';
    case BallShape.gem:
      return 'Gem';
  }
}

/// One player's setup choice.
class PlayerConfig {
  PlayerConfig({
    required this.name,
    required this.colour,
    required this.shape,
  });
  String name;
  GameColor colour;
  BallShape shape;

  PlayerConfig copy() =>
      PlayerConfig(name: name, colour: colour, shape: shape);
}

/// A power-up definition. `letter` is a legacy label (tiles now use drawn
/// icons, never letters). `effect` is the one-line banner text shown under
/// the power-up name when it is collected.
class PowerUpDef {
  const PowerUpDef(this.id, this.name, this.desc, this.letter, this.value, this.effect);
  final String id;
  final String name;
  final String desc;
  final String letter;
  final int value;
  final String effect;
}

const int kPowerUpCount = 15;

/// 10 base power-ups + Bomb Ball + FREEZE + MAGNET + TRINITY + TURRET = 15 total.
/// NOTE: every `value` must be unique — the field tile uses it as its
/// background colour, so two power-ups sharing a value look identical.
const List<PowerUpDef> kPowerUps = [
  PowerUpDef('speed', 'SPEED +33%', 'Your ball is 33% faster for 10 seconds.', 'S', 0xFF29B6F6, '+33% speed for 10s'),
  PowerUpDef('nitro', 'NITRO', 'Very fast with a bright trail for 8 seconds.', 'N', 0xFFFF6D00, 'Super fast with a gold trail — 8s'),
  PowerUpDef('wrecking', 'WRECKING BALL', 'Paints a bigger area (radius 2) for 10 seconds.', 'W', 0xFFE6193C, 'Paints a bigger area — 10s'),
  PowerUpDef('colossus', 'COLOSSUS', 'Your ball grows huge and paints radius 2 for 10 seconds.', 'C', 0xFF8E24AA, 'Giant ball, paints radius 2 — 10s'),
  PowerUpDef('fortify', 'FORTIFY +10 SECONDS', 'Your tiles cannot be taken for 10 seconds.', 'F', 0xFF43A047, 'Your tiles can\'t be taken — 10s'),
  PowerUpDef('infiltrator', 'INFILTRATOR +10 SECONDS', 'Paints ANY enemy tiles, radius 2 — even deep behind enemy lines, for 10 seconds.', 'I', 0xFFFF8F00, 'Paints anywhere, radius 2 — 10s'),
  PowerUpDef('ghost', 'GHOST', 'Pass straight through enemy balls for 8 seconds.', 'G', 0xFFB0BEC5, 'Pass through enemy balls — 8s'),
  PowerUpDef('blackhole', 'BLACK HOLE', 'Pulls enemy balls towards you for 5 seconds.', 'B', 0xFF212121, 'Pulls enemy balls to you — 5s'),
  PowerUpDef('tidal', 'TIDAL WAVE', 'Instantly paints your full row and column.', 'T', 0xFF00BCD4, 'Paints your whole row + column'),
  PowerUpDef('wormhole', 'WORMHOLE', 'Teleports your ball to a random tile.', 'H', 0xFF7C4DFF, 'Teleports to a random tile'),
  PowerUpDef('bomb', 'BOMB BALL', 'Explodes a 5x5 area to your colour!', 'B', 0xFFBF360C, 'Explodes a 5x5 area to your colour'),
  PowerUpDef('freeze', 'FREEZE', 'Freeze all enemy balls for 3 seconds.', 'Z', 0xFF00E5FF, 'Enemy balls stop for 3s'),
  PowerUpDef('magnet', 'MAGNET', 'Pull nearby power-up tiles to your ball for 8 seconds.', 'M', 0xFFFFD54F, 'Power-ups drift to you — 8s'),
  PowerUpDef('trinity', 'TRINITY', 'Three balls at once for 10 seconds.', '3', 0xFFEC407A, 'Three balls at once — 10s'),
  PowerUpDef('turret', 'TURRET', 'A turret auto-paints enemy tiles at the border for 10 seconds.', 'R', 0xFF5C6BC0, 'Auto-paints border tiles — 10s'),
];

PowerUpDef powerUpById(String id) =>
    kPowerUps.firstWhere((p) => p.id == id, orElse: () => kPowerUps[0]);

/// Game modes (Setup selector).
enum GameMode { freeForAll, team2v2, battleRoyale, vsBot }

String gameModeName(GameMode m) {
  switch (m) {
    case GameMode.freeForAll:
      return 'Free For All';
    case GameMode.team2v2:
      return 'Team 2v2';
    case GameMode.battleRoyale:
      return 'Battle Royale';
    case GameMode.vsBot:
      return 'VS COMPUTER';
  }
}

String gameModeDesc(GameMode m) {
  switch (m) {
    case GameMode.freeForAll:
      return 'Everyone fights alone. Most tiles wins.';
    case GameMode.team2v2:
      return '4 players, 2 teams. P1+P3 vs P2+P4. Team tiles count together.';
    case GameMode.battleRoyale:
      return '4 players. Lowest player is out every 30 seconds. Last one wins.';
    case GameMode.vsBot:
      return 'You vs the computer. Pick Easy, Medium or Crazy.';
  }
}

enum BotDifficulty { easy, medium, crazy }

String botDifficultyName(BotDifficulty d) {
  switch (d) {
    case BotDifficulty.easy:
      return 'Easy';
    case BotDifficulty.medium:
      return 'Medium';
    case BotDifficulty.crazy:
      return 'Crazy';
  }
}

/// Custom arena shapes (Setup selector). Tiles outside the shape are dead.
enum ArenaShape { rectangle, heart, star, maze, circle }

const List<ArenaShape> kArenaShapes = [
  ArenaShape.rectangle,
  ArenaShape.heart,
  ArenaShape.star,
  ArenaShape.maze,
  ArenaShape.circle,
];

String arenaShapeName(ArenaShape s) {
  switch (s) {
    case ArenaShape.rectangle:
      return 'Rectangle';
    case ArenaShape.heart:
      return 'Heart';
    case ArenaShape.star:
      return 'Star';
    case ArenaShape.maze:
      return 'Maze';
    case ArenaShape.circle:
      return 'Circle';
  }
}

/// Ball trail cosmetics bought in the Shop.
enum TrailType { none, glow, rainbow, fire, golden }

String trailName(TrailType t) {
  switch (t) {
    case TrailType.none:
      return 'Normal Trail';
    case TrailType.glow:
      return 'Glow Trail';
    case TrailType.rainbow:
      return 'Rainbow Ball';
    case TrailType.fire:
      return 'Fire Trail';
    case TrailType.golden:
      return 'Golden Ball';
  }
}

/// One shop item. Coins are earned by playing (win = 50, play = 10).
class ShopItem {
  const ShopItem(this.id, this.name, this.desc, this.cost, this.trail);
  final String id;
  final String name;
  final String desc;
  final int cost;
  final TrailType trail;
}

const List<ShopItem> kShopItems = [
  ShopItem('glow', 'Glow Trail', 'Your ball leaves a bright glowing trail.', 50, TrailType.glow),
  ShopItem('fire', 'Fire Trail', 'Your ball leaves a hot orange fire trail.', 75, TrailType.fire),
  ShopItem('rainbow', 'Rainbow Ball', 'Your ball changes colour like a rainbow.', 100, TrailType.rainbow),
  ShopItem('golden', 'Golden Ball', 'Your ball turns shining gold.', 150, TrailType.golden),
];

/// Everything needed to start a match.
class MatchConfig {
  MatchConfig({
    required this.players,
    required this.mode,
    required this.arenaShape,
    required this.botDifficulty,
    required this.trail,
    this.pack = ModePack.ultimate,
    this.seriesWinsNeeded = 1,
    this.isDailyChallenge = false,
  });
  final List<PlayerConfig> players;
  final GameMode mode;
  final ArenaShape arenaShape;
  final BotDifficulty botDifficulty;
  final TrailType trail;
  final ModePack pack;
  /// Wins needed to take a series: 1 = single match, 2 = Best of 3,
  /// 3 = Best of 5. Only used for 2 players / VS COMPUTER.
  final int seriesWinsNeeded;
  /// True when this match was launched from the Daily Challenge card —
  /// winning it pays the +100 challenge bonus (once per day).
  final bool isDailyChallenge;
}

/// Arguments for the /setup route: which mode to open, and whether this
/// setup was launched from the Daily Challenge card (the flag is carried
/// through into MatchConfig so the win counts for the challenge).
class SetupArgs {
  const SetupArgs({this.pack, this.dailyChallenge = false});
  final ModePack? pack;
  final bool dailyChallenge;
}

/// Modes section: 10 selectable mode cards (9 + Time Attack).
/// Tapping a card opens Setup with that mode's rule active.
enum ModePack {
  ultimate,
  bomb,
  golden,
  suddenDeath,
  chaos,
  team2v2,
  battleRoyale,
  vsBot,
  allChaos,
  timeAttack,
}

const List<ModePack> kModePacks = [
  ModePack.vsBot,
  ModePack.ultimate,
  ModePack.bomb,
  ModePack.golden,
  ModePack.suddenDeath,
  ModePack.chaos,
  ModePack.team2v2,
  ModePack.battleRoyale,
  ModePack.allChaos,
  ModePack.timeAttack,
];

String modePackName(ModePack p) {
  switch (p) {
    case ModePack.ultimate:
      return 'Ultimate Clash';
    case ModePack.bomb:
      return 'Bomb Battle';
    case ModePack.golden:
      return 'Golden Rush';
    case ModePack.suddenDeath:
      return 'Sudden Death';
    case ModePack.chaos:
      return 'Chaos Mode';
    case ModePack.team2v2:
      return 'Team 2v2';
    case ModePack.battleRoyale:
      return 'Battle Royale';
    case ModePack.vsBot:
      return 'VS COMPUTER';
    case ModePack.allChaos:
      return 'Sab Kuch / All Chaos';
    case ModePack.timeAttack:
      return 'Time Attack';
  }
}

String modePackDesc(ModePack p) {
  switch (p) {
    case ModePack.ultimate:
      return 'Fill your Ultimate Meter, then fire a Color Tsunami.';
    case ModePack.bomb:
      return 'Bomb Balls explode a 5x5 area to your colour.';
    case ModePack.golden:
      return 'Touch the Golden Tile in the centre for double paint.';
    case ModePack.suddenDeath:
      return 'Last 10 seconds: the arena shrinks. Survive!';
    case ModePack.chaos:
      return 'Every 20s: Earthquake, Ice or Fire hits the arena.';
    case ModePack.team2v2:
      return '4 players, 2 teams. P1+P3 vs P2+P4.';
    case ModePack.battleRoyale:
      return '4 players. Lowest player is out every 30 seconds.';
    case ModePack.vsBot:
      return 'You vs the computer: Easy, Medium or Crazy.';
    case ModePack.allChaos:
      return 'Modes 1-5 together: Ultimate, Bomb, Golden, Sudden Death, Chaos.';
    case ModePack.timeAttack:
      return '60-second blitz. Most tiles at the buzzer wins.';
  }
}

/// Which GameMode a ModePack maps to (team / battle royale / bot / free).
GameMode gameModeForPack(ModePack p) {
  switch (p) {
    case ModePack.team2v2:
      return GameMode.team2v2;
    case ModePack.battleRoyale:
      return GameMode.battleRoyale;
    case ModePack.vsBot:
      return GameMode.vsBot;
    default:
      return GameMode.freeForAll;
  }
}
