# Bolsonaro 22 · Força Aérea Brasileira

Jogo vertical de **defesa aérea** em pixel art, feito com Godot 4 (exportação Web, só 2D).
Você pilota um caça da FAB com **Bolsonaro 22** escrito na fuselagem. As ondas são esquerdistas, CUT e MST/PT.
O chefe, em três fases, é o Lula.

🎮 **Play Online**: [https://mmlo.github.io/brazilian-fab-bolsonaro-22/](https://mmlo.github.io/brazilian-fab-bolsonaro-22/)

O remake mantém o movimento, o tiro automático, os padrões, a rajada, a interface em dois idiomas e o recorde local
do modelo Manus. A temática é a defesa do espaço aéreo brasileiro.

## How to play

| Action | Keyboard / mouse | Gamepad | Touch (landscape) |
|---|---|---|---|
| Steer | WASD / arrow keys | Left stick / D-pad | Drag anywhere |
| Precision mode (slow, shows hitbox) | Shift or K (hold) | RB / A / RT (hold) | FOCUS button (hold) |
| Intercept burst (screen clear) | X, L or Space | X / B / LB / LT | BURST button |
| Pause | Esc or P | Start | II button |
| Skip systems check | Enter or Tab | Back / Select | Skip button |

Your interceptor fires automatically. Only the glowing core dot is your hitbox. When a hazard brushes past
inside the near-miss ring you get a **near miss**: it adds score, feeds the BURST gauge and extends the CHAIN.
Neutralized threats extend the chain too. Each 40 chain links add +1.0x to the score multiplier, up to 6.0x.
The chain breaks if 2.6 s pass with no neutralization or near miss, and it also breaks when you are hit.
A full gauge unleashes a defensive shock ring that converts every hazard into score shards.

The sector has three waves (Esquerdistas, CUT, MST e PT) followed by three boss phases: **Palanque**, **Comício** and **Última trincheira**.
A full run takes about 3.5 minutes. On the results screen you get a rank from S to D, and your local best is saved.

## Project map

| Path | What it holds |
|---|---|
| `scripts/config/game_config.gd` | **All gameplay numbers**: speeds, hitbox and near-miss radius, weapon, energy, chain, scoring, ranks, effects |
| `scripts/data/stage_1.gd` | **The level as data**: meteor timelines (spawn events, paths, fire specs) and the three threat phases |
| `scripts/data/enemy_types.gd` | Threat archetypes (sprite, HP, hit radius, score, drops) |
| `scripts/combat/bullet_patterns.gd` | Pattern library: `aimed`, `fixed`, `ring`, `spiral`, `petal`, `curtain`, `rain` |
| `scripts/game.gd` | Simulation and state machine (intro → systems check → waves → warning → threat phases → results) |
| `scripts/playfield_view.gd` | Renders the 270×360 low-resolution pixel playfield at 2×: atmosphere, sprites, hazards, particles |
| `scripts/hud.gd` | Side panels, threat bar, banners, score popups |
| `scripts/title_screen.gd`, `scripts/ui/*` | Title screen, pause, settings, results, systems-check card, touch controls, pixel UI kit |
| `autoload/` | `Settings` (volumes, effects, shake), `SaveData` (local best), `GameInput` (all bindings), `AudioDirector` (SFX pool and music), `I18n` |
| `localization/en.json`, `localization/zh-CN.json` | All player-facing text. The language follows the browser, and a manual choice is remembered |
| `assets/art`, `assets/audio` | Pixel sprites and backgrounds, music and synthesized SFX |
| `tools/art/process_art.py`, `tools/sfx/generate_sfx.py` | Reproducible pipelines that rebuild sprites and sound effects |

## Adapting it

To change the feel, edit the constants in `game_config.gd`. The most important ones are also exposed to the Manus Tweak panel in preview builds through
`scripts/tuning_defaults.gd`. To write a new wave, append events to `WAVES` in
`stage_1.gd`. Each event names a threat id, a path (`dive`, `curve`, `stop`, `sweep`), a spawn position and group
size, and an optional fire spec. To add a threat phase, add an entry to `BOSS.phases` with its HP, time limit,
movement and a list of emitters. Each emitter has an origin offset, an interval and a pattern spec. New pattern
types go in one `match` arm in `bullet_patterns.gd`. New text needs the same key in both catalogs, and the
localization test enforces this.

In debug preview builds you can add URL flags: `?autoplay=1` runs a dodging bot, `?start=boss` (or `wave2`/`wave3`)
jumps ahead, and `&phase=2|3` starts the threat commander at a later phase.

## Tests

`npm test` runs the copy/catalog checks plus the headless Godot suites. `test/smoke.gd` covers data integrity,
every pattern, the systems check, near miss, chain, burst, gamepad input, pause, results and local best.
`test/localization.gd` covers key and placeholder parity, glyph coverage and language persistence.
`test/playthrough.gd` flies a full sector with the bot and prints per-section pacing. Set `SKIP_PLAYTHROUGH=1` to
skip the long run.

## Credits

The Starveil remix uses original generated pixel-art sprites for the interceptor, meteors, catastrophic objects,
radar beacon and atmosphere. Bundled fonts are Exo 2, Orbitron, Smiley Sans and Noto Sans SC, all under the SIL
Open Font License. The engine is Godot (MIT). Full notices are available in-game under *Credits & Licenses*.
