# miniSWG — Work Session Handoff
_Updated 2026-03-12 (session 2). Paste this into a fresh Claude Code session at work._

---

## Who You Are Talking To
- Call the user "buddy" or "budge"
- Explain things at slightly above beginner level — he's learning GDScript by doing
- Correct wrong terminology gently
- Don't dump advanced concepts all at once — introduce them when the moment is right
- He's a visual learner who learns by trial and error
- Output full files rather than snippets when making edits

---

## The Project

**miniSWG** — 2D top-down sci-fi RPG (PSO/SWG inspired), built in Godot 4, GDScript.
Project root: `C:\Users\ryang\OneDrive\Documents\miniSWG`
Everything is procedural — no scene tree nodes added in the editor, all built in code.

> This project was migrated from `C:\Users\ryang\OneDrive\Documents\beyond-the-veil` and is now the active working copy. The old repo can be referenced for history but miniSWG is the source of truth.

---

## Boss Arena — What It Is

A standalone arena scene (`boss_arena.tscn` + `Scripts/BossArenaScene.gd`).
The player picks a class and nickname on a character select screen, then fights bosses.

### Player Classes (BossArenaPlayer.gd)
| Class | HP | MP | Attack Interval | Range | Notes |
|---|---|---|---|---|---|
| melee | 300 | 60 | 2.0s | 130 | direct dmg, melee hit effect |
| ranged | 180 | 100 | 2.5s | 700 | fires Bullet projectile |
| mage | 150 | 200 | 4.0s | 700 | fires Fireball arc projectile |
| brawler | 350 | 60 | 2.0s | 130 | direct dmg, melee2 sprite assets (144×144 frames, scale 44/144) |

- All classes: `SPEED = 55.0`, no movement lock after attacking (`_move_lock_timer = 0.0` for all)
- **Kiting** supported for ranged/mage: moving after firing cancels attack animation, run takes over
- Targeting: Tab cycles targets, ESC closes open window or clears target
- Credits earned from kills, spent at shop terminal (press F near terminal)
- I = Inventory, C = Attributes (stat points), G = one-shot kill (debug)

### Attributes
- STR: +25 HP, +5 melee dmg, +5% dmg reduction per point
- AGI: +5% attack speed, +2% crit chance per point
- INT: +5% spell dmg, +2% spell crit per point
- SPI: +25 MP, +5 spell dmg per point
- 3 points per level-up, spend via Attributes window

---

## Boss Arena — Key Scripts

| File | Purpose |
|---|---|
| `Scripts/BossArenaScene.gd` | Main scene: camera, HUD, world, spawning, ambient FX, music |
| `Scripts/BossArenaPlayer.gd` | Player: movement, animation, auto-attack, stats, windows |
| `Scripts/ZergBoss.gd` | Boss 1 (spawn F2) — alien horde type |
| `Scripts/CyberLord.gd` | Boss 2 (spawn F3) — cyberpunk type |
| `Scripts/ZergMob.gd` | Mob version of ZergBoss (spawn F4) — half scale, 10 credits |
| `Scripts/CyberMob.gd` | Mob version of CyberLord (spawn F5) — half scale, 10 credits |
| `Scripts/Zergling.gd` | Small swarming enemy |
| `Scripts/ZerglingSpawner.gd` | Spawns Zergling waves |
| `Scripts/TrainingDummy.gd` | F1 spawns training dummy (no credits, no XP) |
| `Scripts/Bullet.gd` | Ranged projectile — travels in straight line to target |
| `Scripts/Fireball.gd` | Mage projectile — quadratic bezier arc, tracks target live |
| `Scripts/MeleeHit.gd` | Visual hit effect for melee attacks |
| `Scripts/HpPotion.gd` | HP potion item/pickup logic |
| `Scripts/DamageNumber.gd` | Floating damage/XP/credit numbers |
| `Scripts/BossFloatingText.gd` | Floating text (legacy/alternative to DamageNumber) |
| `Scripts/Tumbleweed.gd` | Ambient tumbleweed that rolls across the arena |
| `Scripts/WindEffect.gd` | Ambient wind streak lines that sweep across viewport |
| `Scripts/BossShopWindow.gd` | Shop UI |
| `Scripts/BossInventoryWindow.gd` | Inventory UI |
| `Scripts/BossAttributeWindow.gd` | Attribute spend UI |
| `Scripts/BossChatWindow.gd` | In-game chat |
| `Scripts/BossWeaponSwing.gd` | Knife swing visual for equipped melee weapons |
| `Scripts/BossShopTerminal.gd` | Shop terminal object in the world |
| `Scripts/BossCinematic.gd` | Cinematic intro sequence |
| `Scripts/BossCrumble.gd` | Boss death crumble/disintegrate effect |
| `Scripts/BossItemIcon.gd` | Item icon rendering for inventory/shop |
| `Scripts/BossLevelUpEffect.gd` | Level-up visual effect |
| `Scripts/BossActionBar.gd` | 5-slot action bar (keys 1–5), drag-from-skill-window, cooldown overlays |
| `Scripts/BossBuffBar.gd` | Buff/debuff icon row below HUD bars — sprint, sensu bean, etc. |
| `Scripts/BossSkillWindow.gd` | Skill book window (P to open) — drag skills onto action bar |
| `Scripts/HelpWindow.gd` | In-game help/keybindings reference window |
| `Scripts/SettingsWindow.gd` | In-game settings window |
| `Scripts/TooltipManager.gd` | Hover tooltips for skill/action bar slots |
| `Scripts/MinimapDraw.gd` | Minimap rendering |
| `Scripts/SpaceportScene.gd` | Level 2: Coronet Spaceport — 8192×8192 open world with spaceport complex |
| `Scripts/SpaceportTeleporter.gd` | Procedural teleporter pad + portal oval for scene transitions |
| `Scripts/Relay.gd` | Multiplayer relay connection (wss://newgamewhodis.onrender.com) |

---

## Assets

| Path | Contents |
|---|---|
| `Assets/Backgrounds/sand_floor.png` | Desert arena floor texture |
| `Assets/Backgrounds/grassland.png` | Alternate background |
| `Assets/Backgrounds/lunar.png` | Alternate background |
| `Assets/Backgrounds/moonislandsnow.png` | Alternate background |
| `Assets/Fonts/IMFellEnglish-Regular.ttf` | Serif display font |
| `Assets/Fonts/Bebas_Neue/` | Bebas Neue (titles/HUD) |
| `Assets/Fonts/Roboto/` | Roboto family (UI body text) |
| `Assets/Fonts/Bungee/` | Bungee (display/accent) |
| `Assets/Fonts/Archivo_Black/` | Archivo Black |

---

## Boss Constants (same for both bosses)
```
ATTACK_RANGE     = 55
REPOSITION_RANGE = 150
SPEED            = 55
MAX_HP           = 500
ATTACK_INTERVAL  = 2.2
Damage           = 25–45
Collision        = layer 2, mask 2 (no player collision)
Groups           = "targetable" + "boss"
Credits on death = 100
```

### get_target_position() — IMPORTANT
Projectiles (Bullet, Fireball) aim at `get_target_position()`, not `global_position`.
Returns visual body center in world space so hits land on the sprite, not feet.

- ZergBoss: `global_position + Vector2(0, -80)`
- CyberLord: `global_position + Vector2(0, -132)`
- ZergMob: `global_position + Vector2(0, -40)`
- CyberMob: `global_position + Vector2(0, -66)`

### Boss death
Blink-and-fade over 2 seconds (`modulate.a`), `_dying` flag gates AI/movement/damage/HP bar.
Calls `arena.on_boss_died()` → 100 credits, 100 XP, gold damage number at death pos.

### Mob death
Same blink-and-fade. Calls `arena.on_mob_died(global_position)` → 10 credits, 10 XP.

---

## Targeting Indicator (Arrow + Pulsing Arcs)
Drawn in `_draw()` on each enemy via `is_targeted()` check on the arena scene.
Arrow bounces up/down with `sin(_pulse_t * 4.5) * 5.0`.

Arrow Y positions (above sprite head):
- ZergBoss: `ARROW_Y = -135.0`
- CyberLord: `ARROW_Y = -278.0`
- ZergMob:  `ARROW_Y = -108.0`
- CyberMob: `ARROW_Y = -140.0`

---

## Animation Frame Sizes (BossArenaScene.gd sprite setup)
Animations loaded procedurally in `_build_*_frames()` functions.
Each call takes `(path, frame_w, frame_h, frame_count)`.

### Melee
- idle: 192×24px, 8 frames
- run: 192×24, 8 frames
- attack_n/s/e/w: check file for current values

### Ranged
- idle: 192×24px, 8 frames
- run: 192×24px, 8 frames
- attack_n/s/e/w: check file for current values

### Brawler
- All animations use 144×144px frames, sprite scale = `44.0 / 144.0`

---

## Fireball — Live Tracking
Fireball recalculates `_end_pos` and `_ctrl_pos` every frame so it tracks the boss as it moves.
```gdscript
var aim = _target.get_target_position() if _target.has_method("get_target_position") else _target.global_position
_end_pos  = aim
var mid   = (_start_pos + _end_pos) * 0.5
var perp  = (_end_pos - _start_pos).normalized().rotated(-PI * 0.5)
_ctrl_pos = mid + perp * (_start_pos.distance_to(_end_pos) * 0.30)
```

---

## Buff Bar (BossBuffBar.gd)
Sits below player HUD bars. API called from BossArenaPlayer:
- `add_buff({id, icon, label, duration, color})` — creates icon slot with countdown
- `update_buff(id, remaining)` — ticks timer label; blinks red at ≤5s
- `remove_buff(id)` — removes slot, reflows row

Active buffs:
| Buff | Icon key | Duration | Effect |
|---|---|---|---|
| Sprint | `"sprint"` | 15s | +30% move speed |
| Sensu Bean | `"sensu"` | 10s | Regen full HP+MP over duration |
| Triple Strike | `"triple"` | — | Next 3 attacks hit 3× |

Icon art is drawn procedurally via GDScript (`_draw_sprint`, `_draw_sensu`, `_draw_triple` in `_icon_draw_script()`).

---

## Ambient Effects
- **Tumbleweed**: one at a time, rolls in from a random edge, fades after ~6s. Group: `"tumbleweed"`.
- **Wind**: sweeping line streaks from left edge across viewport, triggered every 4.5–8s.

---

## Nickname Save/Load
Nickname saved to `user://player_prefs.cfg` via `ConfigFile`. Pre-fills on next load.

---

## Music
`res://Sounds/Music/music_battle.mp3` plays on scene load via `AudioStreamPlayer` at `-6.0 db`.

---

## Keyboard Shortcuts (BossArenaScene.gd — debug spawning)
| Key | Action |
|---|---|
| F1 | Spawn training dummy |
| F2 | Spawn ZergBoss |
| F3 | Spawn CyberLord |
| F4 | Spawn ZergMob |
| F5 | Spawn CyberMob |

---

## Critical GDScript 4 Gotchas
- No chained assignment: `a = b = 0` must be two lines
- `animation_finished` signal → always use `CONNECT_ONE_SHOT`
- `draw_colored_polygon()` takes plain `Color`, not `PackedColorArray`
- `get_tree().create_timer()` stacks — guard against double-calls
- Never use inner classes in UI-heavy files — Godot parser chokes; use separate files
- `exp` is a reserved word in GDScript — stats use `exp_points` instead
- `.duplicate()` is NOT needed on Vector2 — it's a value type

---

## Current State
The project is fully working. All scripts are migrated from beyond-the-veil and running without errors.

---

## Pending / Next Ideas
- More enemy types / mob waves
- Boss phases (enrage at low HP)
- Player death respawn or game over screen
- Sound effects for abilities (attacks, hits)
- More shop items
- Music looping
- Multiplayer (long term — relay server: wss://newgamewhodis.onrender.com)
