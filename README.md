# Color Cover

A 2, 3 or 4 player territory battle on one phone. Paint the arena, steal the tiles, win in 90 seconds.

## How to play

1. **Pick a mode** — On Home, tap **MODES** (10 cards) or tap **PLAY** for the default mode.
2. **Setup** — Choose 2, 3 or 4 players. Each player picks a name, a colour (60 colours, no two players the same) and a ball shape (30 shapes). Pick an arena shape too: Rectangle, Heart, Star, Maze or Circle.
3. **Steer your ball** — Your ball moves on its own. Touch anywhere in your zone and drag to steer it. 2 players: left half vs right half. 3 players: three vertical thirds. 4 players: four corners. All players steer at the same time with different fingers.
4. **Paint the arena** — Where your ball goes, tiles change to your colour. Take tiles from other players.
5. **Grab power-ups** — A power-up tile appears every 6 seconds (max 3 on the field). Drive over it to use it. A banner with its name shows above the arena for a few seconds.
6. **Win in 90 seconds** — Most tiles wins. The end card shows "X DOMINATES!" right on the arena.

## Modes (10 cards on the Modes screen)

1. **Ultimate Clash** — Paint to fill your Ultimate Meter, then tap TSUNAMI to turn a full row your colour.
2. **Bomb Battle** — Bomb Balls explode a 5x5 area to your colour.
3. **Golden Rush** — A Golden Tile (★) sits in the centre. First ball to touch it gets double paint for 10 seconds.
4. **Sudden Death** — In the last 10 seconds the arena shrinks, ring by ring.
5. **Chaos Mode** — Every 20 seconds a Chaos Event hits: Earthquake (tiles shuffle), Ice (balls go fast and slippery) or Fire (tiles burn away).
6. **Team 2v2** — 4 players, 2 teams: P1+P3 (Team A) vs P2+P4 (Team B). Team tiles count together.
7. **Battle Royale** — 4 players. The lowest player is out every 30 seconds. Last one wins.
8. **VS COMPUTER** — You vs the computer. Pick Easy, Medium or Crazy. Drag anywhere on the arena to steer.
9. **Sab Kuch / All Chaos** — Modes 1–5 together in one match.
10. **Time Attack** — 60-second blitz. Most tiles at the buzzer wins.

## Coins + Shop (separate section, not in Modes)

- Win a match = 50 coins. Finish a match = 10 coins. Coins are saved on your phone.
- Shop sells ball trails: Glow Trail (50), Fire Trail (75), Rainbow Ball (100), Golden Ball (150). Buy once, equip any time.

## Arena shapes (Setup)

Rectangle (full grid), Heart, Star, Maze, Circle. Tiles outside the shape are dead and cannot be painted.

## Stats, achievements + daily reward (Home)

- Every finished match is saved on your phone: date, mode, players, winner, duration, tiles painted and power-ups collected. Open **HISTORY** on Home for the last 20 matches with W/L and coins earned. The end card also shows the match stats (tiles painted, power-ups, biggest lead).
- **ACHIEVEMENTS** on Home: 7 badges with coin rewards — First Win (+25), On Fire 5-win streak (+100), Painter 1000 tiles (+50), Power Collector 10 power-ups (+50), Bot Slayer beat Crazy (+75), Crowd Champion win a 4-player match (+75), Last Second win Sudden Death (+50). Each pays once.
- **Daily reward:** +50 coins once per day when you open the app. A gold pill on Home shows it.

## Power-ups (13 total)

Speed +33%, Nitro, Wrecking Ball, Colossus, Fortify +10s, Infiltrator +10s, Ghost, Black Hole, Tidal Wave, Wormhole, Bomb Ball, FREEZE (enemy balls frozen 3s), MAGNET (power-up tiles pulled to your ball).

## Build the APK (free, like TerraSpeak)

1. Create a GitHub repo (for example `color-clash`) and push all files in this folder.
2. **Workflow file:** the GitHub App cannot create `.github/workflows/` files, so create it in the browser: in the repo go to **Actions → New workflow → set up a workflow yourself**, paste the contents of `build-apk.yml.txt`, and commit it.
3. Push any change (or press **Run workflow**). GitHub Actions builds the APK in about 4–5 minutes.
4. Go to **Actions → the latest run → Artifacts → `color-clash-apk`**, download it, unzip it, and install `app-release.apk` on your phone.
5. To share it, create a **Release** (tag `v1.0.0`), attach the APK, and send the Release link.

Package: `com.colorclash.app`, version 1.0.0+1, portrait only, minSdk 21 (works on Android 8.1 / Oppo F9). No login, no internet needed.
