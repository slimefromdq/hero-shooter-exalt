# EXALT · Meridian Gardens

A playable offline **6v6 King of the Hill** hero shooter in a modern fantasy city, with **Nimbus, Slayer, Marshal, Doctor, Huddle, Relay, Dynamo, Wisp, Samson and Stitch** and a separate hero training arena. Built with original modular geometry and synthesized sound. **Godot 4.7.2 stable** is the verified engine (`4.7.2.stable.official.ed1daf0bf`).

**Play Samson:** run `Launch.ps1 -Samson`, adding `-Training` or `-Museum`. This cockroach-lawyer Support rescues allies with two Q charges, channels a stun and silence on E, denies new movement casts inside a ground injunction with 1, and summons a 750-HP Roach Court with an 11 m Witness Protection radius on 2. See [kit, rules and validation](docs/SAMSON.md).

**Tactical bots:** all ten heroes now share observed-enemy memory, utility decisions, combat positioning, team intentions and hero-specific ability tactics across City and Museum. Nimbus can throw and shoot her own airborne bomb through ordinary rifle fire. Select **Beginner / Normal / Hard / Expert** in settings, try **Tactical Sparring** in advanced training, and use **F3** plus **[ / ]** for bot diagnostics. See [enemy AI behavior and validation](docs/ENEMY_AI.md).

**Play Stitch:** run `Launch.ps1 -Stitch`, adding `-Training` or `-Museum` as desired. Needles build marks, close shears consume them, Red Thread limits escape mobility, Play Dead conceals for up to 20 seconds, and Curtain Call telegraphs a marked-target execute. See [Stitch controls, rules and validation](docs/STITCH.md).

**Play the new trio:** run `Launch.ps1 -Relay`, `-Dynamo` or `-Wisp`; add `-Training` for practice. Relay manages an indestructible, battery-powered healing drone, a 6 m shock blast and an 80 HP/s team overclock. Dynamo spins up her minigun, chains lightning, builds physical segmented walls, pulls enemies from 28 m and casts a damaging storm from 35 m. Wisp combines pistol marks, dash-loaded shotgun shells, phase, aerial lift and a four-second Death Ballet. All menus include the trio; training adds three exercises and bot profiles. New matches use seeded **2 tank / 2 support / 2 DPS** teams. See [kits, controls and validation](docs/RELAY_DYNAMO_WISP.md).

**Play Huddle:** run `Launch.ps1 -Huddle`, adding `-Training` for practice. This 600-HP bug colony fires seeds, channels self-healing on RMB, flies in two quick Q bursts, screens an ally with E, pushes threats away with 1, and becomes an advancing enemy-displacing wave with 2. Both menus offer Huddle; training adds **Huddle rescue**. See [Huddle's kit and rules](docs/HUDDLE.md).

**Play the new tank/support:** run `Launch.ps1 -Marshal` or `Launch.ps1 -Doctor`; add `-Training` for practice. Marshal carries an 8 x 4.5 m / 1,200-durability shield, launches enemies with Forward March, rallies nearby allies with temporary overhealth, calls down a terrain-validated orbital strike lane, and leaps into a slam covering a 16 m cone. Doctor heals with **right hold**, shoots with **left hold**, leaves lingering treatment, escapes to allies on a 4 s cooldown, cleanses with brief heavy resistance, and empowers one teammate with her ultimate. Both pause menus offer all ten heroes; training adds Doctor rounds and Marshal drill. See [kits, controls and rules](docs/MARSHAL_DOCTOR.md).

Marshal now has a [rigged Blender character](docs/MARSHAL_CHARACTER.md) with a tall shako, ivory moustache, navy/red/gold uniform, matching cannon, shield bracer and cigar. The editable source, deterministic Blender generator and GLB are included; players and bots use the model automatically.

**Play Slayer:** run `Launch.ps1 -Slayer` for the city, or `Launch.ps1 -Training -Slayer`. Both pause menus offer hero selection; training includes **Start Slayer hunt**. Slayer has 275 HP. Q throws trailing silver knives at 110 m/s, E performs a 12 m Boot Rush at 32 m/s with a 0.45 s boot attachment, aimable automatic kick and fading recovery slow, 1 tosses a snare that arms after 0.75 s even in flight, and 2 launches Heads Will Roll after a 0.55 s windup. The shotgun deals 90 close-range body damage with tight spread and useful midrange reach. Health/shields use a broad lower-screen bar, ammunition also appears beside the crosshair, hits show larger outlined damage numbers, and 4 performs her two-handed lift and slam. See [Slayer controls, tuning and engine validation](docs/SLAYER.md).

The city includes a celestial conservatory, garden and market flanks, an underground shopping arcade with six through-shops and cover, accessible balconies and wizard's study, elevated promenades, monumental railway arches and moving scenic trains. Six small packs heal **75 HP**; two large packs heal **400 HP**, capped at maximum health. See [Meridian Gardens field guide and validation](docs/MERIDIAN_GARDENS.md) and the [geometry revision](docs/GEOMETRY_AUDIT.md).

## Play

**Meridian Museum:** choose **Museum / Capture + Payload** in the main menu, then Attack, Defend, or Explore. Or run `Launch.ps1 -Museum`, adding `-Defend` or `-Explore` and an optional hero switch. Capture the Astrolabe Court in three permanent thirds, then escort an artifact through three checkpoints to the Conservation Vault. Includes a compact horseshoe layout, connected gallery/roof/garden routes, a rideable payload, phase-aware 6v6 bots, overtime, forgiving movement shortcuts, and an M/B tactical atlas. Team-operated sliding spawn doors provide friendly immunity and allow firing outward while protected. Gold objective markers show distance and direction to the active capture point or cart. Select **Cool Dawn / Rosy Afternoon / Starry Night** before launch or through **Pause → Museum Lighting**; the selection is saved. The launcher also accepts `-Museum -Lighting Night`. See the [museum field guide and floor plans](docs/MERIDIAN_MUSEUM.md).

Team spawn rooms rapidly restore **200 HP per second** to their own living players. Cyan shoulder/chest bands, ground rings and **[+] ALLY / LANTERN** labels identify your team; red bands and **[!] ENEMY / CROWN** labels identify opponents. The city HUD shows the five latest eliminations with weapon and assist credit, plus your kills, assists and current life streak. Damage within **8 seconds** earns an assist; the most recent enemy hit earns an environmental elimination. Final blows within **4 seconds** build double, triple, quadruple and higher multi-kills. Original synth cues rise with your streak, with separate multi-kill arpeggios and streak fanfares from three kills onward. Death resets streaks; restarting clears all combat feedback.

Import **project.godot** in Godot 4.7.2 and press **F5** to open the main menu. On Windows, run:

```powershell
powershell -ExecutionPolicy Bypass -File .\Launch.ps1
```

`Launch.ps1 -Editor` opens the editor; `Launch.ps1 -Training` starts the original arena directly. The launcher finds the installed 4.7.2 console executable in Downloads or `GODOT_BIN`. Click the game to capture the mouse. **Tab / Esc** opens the pause menu, including exploration, match restart and return to training. **M** opens the tactical atlas; **F3** adds route/resource debugging.

The game starts in **borderless fullscreen** at your monitor's native resolution. **F11** or **Alt+Enter** toggles fullscreen/windowed in both city and training, including while paused; both pause menus also have a display button. Your choice is saved for the next launch, and returning to windowed restores its previous size and position. Use `Launch.ps1 -Windowed` or `-Fullscreen` to override the saved preference for one launch. The game fills widescreen/ultrawide displays while the HUD keeps its proportions and centred aim point.

## Controls

The table shows Nimbus's kit; [Marshal and Doctor](docs/MARSHAL_DOCTOR.md) and [Huddle](docs/HUDDLE.md) use their own mouse and Q/E/1/2 abilities. Shared traversal and close-combat keys apply to every hero.

| Input | Action |
| --- | --- |
| WASD / mouse | Move / look |
| Left click / right hold | Semi-auto umbrella rifle / shoulder aim |
| R | Reload |
| Space | Press to jump / wall kick; hold while moving into a ledge to mantle automatically |
| Scroll wheel up | Two WASD-directed dash charges; air W/S follows aim pitch; no WASD uses aim |
| Shift hold | Crouch / half-speed crouch walk; momentum or a downhill slope takes priority as a slide |
| Q | Ability 1 — Hover: higher umbrella vault, then glide; press again to end |
| E | Ability 2 — frontal Deflect |
| 1 | Ability 3 — bouncing Pocket Bomb |
| 2, then left click | Final Notice stance: three shots over 8 s after preparation; 2 cancels |
| 5 | Forward lunging umbrella strike |
| 4 | 3.2 m throw or timed counterthrow |
| 6 hold | Shield / frontal melee guard |
| Tab or Esc | Pause menu / training console / return to play |
| M | City district atlas with routes, levels and shared health locations |
| B | Switch the open city atlas between surface and underground plans |
| F11 / Alt+Enter | Toggle borderless fullscreen / windowed; also available in pause menus |
| F3 / F5 / F6 | Telemetry / match or exercise restart / training-only refill |

Bindings use named InputMap actions in `scripts/training/input_bindings.gd`; existing editor-configured bindings take precedence, and HUD prompts read the actual map. Every hero has **two shared dash charges**, recharging one at a time every **4.3 s**. Dash speed is **20 m/s**. Direction commits after the 0.16 s buildup: WASD selects travel relative to the camera, with forward/backward following camera pitch in the air and strafing remaining horizontal. Ground dashes stay horizontal. Without WASD, dash follows aim.

Only a dash that **starts airborne** can convert downward floor contact into a dash slide, using a fresh Shift press within **0.12 s** before impact. Ground-dash residual speed cannot trigger a slide by releasing and repressing Shift. Ordinary running/downhill momentum slides remain available; standing crouch remains crouch. Slides have slightly stronger friction (**4.0**). WASD gently steers existing slide momentum without adding speed. Release Shift or jump to exit. A fresh Shift press in the last **0.15 s** of a mantle or within **0.2 s** afterward produces a forward **mantle slide** at at least **8 m/s**, carrying faster forward momentum. Buffered exit jumps take priority.

Shared melee keeps its **6 m** lunge. Aim in 3D until the lunge starts after **0.06 s**, then the direction commits. Grounded lunges move horizontally; airborne lunges follow full aim and suspend ordinary falling for **0.25 s** before gravity resumes. Stationary training strikes remain stationary. Air steering is reduced by **25%**, with gravity and jump height unchanged. Guard limits movement and does **not** reduce bullets at the default setting.

Movement now has distinct takeoff/contact bursts, short dash trails, ground slide streaks, mantle hand glints and aimed melee arcs. Wall jumps, dashes, ordinary slides and dash slides briefly confirm beside the crosshair; jumps, mantles and melee use world effects only. Attempted dash slides explain early/late crouch, released crouch, grounded starts, insufficient momentum, obstructions and expired dashes. No warning appears for ordinary dashes without a slide attempt. **Movement camera effects** in settings or the training camera controls toggles the short FOV accents; aiming/scoped views suppress them. Gameplay timing, damage and movement tuning are unchanged.

## Guard practice

Press **Tab → Start guard drill**, walk inside the coral ring, face the stationary bot and hold **6**. The bot starts strikes within **2.4 m**, repeating at a **1.6 s** interval after its normal reaction/startup. A successful block produces a metallic clang, shield flash, expanding rings and sparks. The attacker snaps backward, spreads its arms, buckles its knees and shows rotating daze markers during the existing 0.55 s stagger. It uses the shared melee and stagger rules but stays planted. Change **Strike trigger range** and **Strike interval** under **Stationary guard drill** in the training console. The same bot is available as the **Guard trainer** spawn profile. Starting the dedicated drill clears AI freeze.

## Climbing and wall jumps

**Hold Space and move into a wall or tower** to mantle automatically when a ledge comes within about **1.15 m** and **2.35 m above your feet**, provided the top has room to stand. Keep holding through a jump, umbrella ascent or successive ledges; you do not need another press at each lip. The climb takes about **0.32 s**, with continuous collision checks and a two-arm pull-up pose. Your incoming horizontal momentum carries through the finish straight into running. **Press Space during the last 0.12 s** to jump immediately off the top with that momentum. Holding Space while standing still or moving away does not start an automatic climb; holding alone does not jump on completion.

While airborne within **0.72 m** of a wall, press **Space** to kick upward and away with a facing-directed horizontal launch. Moving forward beside a left wall carries you forward and right; a right wall carries you forward and left. Facing directly into a wall kicks you straight upward and backward, with no sideways impulse. At other angles, camera facing directs horizontal launch while retaining at least 3 m/s away from the wall. The horizontal launch uses at least 9 m/s and preserves faster incoming speed within the shared cap. Wall kicks still need a new press, and landing or reaching a differently facing wall enables another kick. Try the marked ledge and kick wall beside the east-side traversal route. Q launches at **12 m/s for 0.4 s** and reaches roughly **8 m** above its starting point in open space before descending into the glide; ceilings stop the ascent safely.

## Included

- Meridian Gardens: one player and eleven bots across nine heroes, navigation across five elevations, fixed-hill capture/contest/scoring, team-only safe rooms, eight-second respawns, ultimate retention, shared health pickups, match HUD, exploration mode and tactical atlas. First to 100% wins after the 20-second unlock and five-second uncontested capture.
- Nimbus's complete prototype kit: 45/90 body/head rifle, upward Hover, timed projectile reflection and hitscan blocking, 140-peak / 5 m bomb with falloff, cover checks and owner-only airborne shoot detonation, and 150-damage Final Notice with a pre-hit 20% execution check.
- Shared acceleration, braking, air steering, jump buffering/coyote time, collision-checked mantling, wall jumps, two-charge directional dash, momentum/dash/mantle slides, and collision-aware shoulder camera.
- A 6 m committed melee lunge for engages/finishers, finite frontal guard with attacker stagger, interruptible 3.2 m throws, counterthrows, and an articulated pull/hip-lift/turn/slam/get-up animation. Slam damage occurs at impact; both participants retain 90% outside-damage reduction during the pair.
- Reloads progress independently of action state with full movement speed; shoulder aiming retains its 60% cap. Nimbus/Huddle reload in 0.8 s, Marshal in 1 s, Doctor in 0.7 s; Slayer loads shells with 0.15 s startup and 0.22 s per shell. Firing waits until completion.
- Six bot profiles; seven exercises including the stationary guard drill; spawn/despawn; 250/500 HP experiments; 19/20/21% target presets; shield/invulnerability controls; AI settings; resource refills; movement presets; live combat tuning; route timer; event export.
- Cover, firing lane, slope, elevated traversal platforms, and a ranged projectile-emitter opponent. The crossfire exercise uses a third-faction probe to test damage on **both** throw participants while preserving friendly-fire rules.
- Slayer's complete prototype kit: pellet shotgun and shell reload, bleeding knives with flight trails, swept Boot Rush with knockback, a single aimed snare toss with timed arming, private pursuit marks, and a piercing axe with temporary max-health wounds. Includes distinct geometric art, keyed throwing poses, effects, synth audio, AI, selection and HUD support. All heroes use an adjustable 3 m shoulder camera with an 82-degree normal / 60-degree aiming field of view and crosshair ammunition display.
- All gameplay components and per-actor resources are shared by player and bots. Marshal and Doctor add main-tank and main-support roles; multiplayer and the remaining reserved roster remain deferred.

## Verify

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\verify.ps1
# Add -Capture to render arena and console PNGs.
```

Or use Godot directly:

```text
godot --headless --path . --editor --import --quit
godot --headless --path . --script res://tests/rules_test.gd
godot --headless --path . --script res://tests/match_feedback_test.gd
godot --headless --path . --script res://tests/close_combat_test.gd
godot --headless --path . --script res://tests/guard_drill_test.gd
godot --headless --path . --script res://tests/block_feedback_test.gd
godot --headless --path . --script res://tests/traversal_test.gd
godot --headless --path . --script res://tests/traversal_flow_test.gd
godot --headless --path . --script res://tests/mantle_exit_test.gd
godot --headless --path . --script res://tests/integration_test.gd
```

Results are written to `artifacts/`. The full verification run passes **1,112 checks**, plus **2,516 structural surface probes** and **4,420 winding checks**. Marshal/Doctor follow-up verification passes **126 focused headless checks** and **128 native checks**. Native input verification adds **47 checks** and fullscreen verification adds **20**. The final ten-minute four-hero simulation passes **17 stability checks**. City checks cover healing, objective heights, protection, respawns, resets, traversal, navigation recovery and camera clearance. See [Slayer validation](docs/SLAYER.md), `docs/PLAYTESTS.md` and the city field guide for evidence and reproduction commands. Competitive balance and game feel still need human playtesting. Tune the hero resources or map definition through the Inspector.

## Layout

`scenes/actors` composes the common actor. `scripts/actors` owns intent, actor state, movement and camera. `scripts/abilities` owns hero kits and close-combat lifecycles. `scripts/combat` is the offline authority boundary for damage, cover and projectiles. `scripts/presentation` owns geometry, animation and sound. `scripts/training` owns exercises, bots/debug control and HUD. All dimensions are meters, times seconds, health/damage HP.

The city uses a reusable batched architecture kit, a baked pedestrian navigation mesh, original material shaders and static indirect lamp illumination. Nimbus retains the existing prototype character art and procedural animation. Human keyboard/mouse playtesting remains useful for responsiveness, route difficulty and combat balance. See `docs/DECISIONS.md` and `docs/TASKS.md` before extending it.

To render the revised combat choreography for review, run `godot --path . --script res://tests/capture_close_combat.gd --fixed-fps 60 --resolution 1100x720`. It writes actual engine frames under `artifacts/combat-frames/`.
