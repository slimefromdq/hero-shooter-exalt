# Marshal's authored character

Marshal now uses a Blender-authored character for players and bots in training and Meridian Gardens. His navy/red/ivory military uniform, brass epaulettes, tall shako and plume, white moustache, cigar, cannon and shield bracer follow the supplied visual reference. Portraits retain their existing art.

## Assets and reproduction

- `tools/blender/build_marshal.py`: deterministic geometry, materials, Blender armature, skin weights, morphs, GLB export and studio renders. No external assets or add-ons.
- `assets/characters/marshal/marshal.blend`: editable source with live armature modifiers and neutral facial morphs. The cannon has a separate studio-placement parent; rerunning the generator exports it in weapon-anchor space.
- `assets/characters/marshal/marshal.glb`: runtime asset, including the actual Blender skeleton and weighted skin. The `.blend.import` sidecar keeps Godot from importing the editable source a second time.
- `assets/characters/marshal/previews/`: front, side, back, three-quarter and face inspection renders.

Run from the repository root with Blender 5.2.2 LTS:

```powershell
$taskBlender = 'C:\Program Files (x86)\Steam\steamapps\common\Blender\blender.exe'
& $taskBlender --background --python-exit-code 1 --python tools/blender/build_marshal.py -- --samples 32
& $taskBlender --background assets/characters/marshal/marshal.blend --python-exit-code 1 --python tools/blender/validate_marshal.py
```

Use `--skip-renders` to rebuild source/export only, or `--views front three-quarter face` to select review views. The model report records the exported GLB SHA-256, geometry budget, bones and bounds. Current geometry is **36,816 triangles**, below the 95,000 limit. Body height is 1.963 m; the decorative shako/plume reaches 2.674 m. Blender +Y converts to Godot -Z; feet are authored at ground level. The source opens in a cannon-holding studio pose; the GLB is exported in neutral bind pose before applying that review pose.

## Rig and runtime behavior

The skin has **19 bones**: root, spine, chest, neck, head, upper arms, forearms, hands, thighs, calves, feet, and two coat tails. Vertex weights are normalized with at most four influences. Separate `Blink`, `Focused`, and `MouthOpen` morphs animate the face. The moustache and cigar remain on the head. Named sockets are `CannonMuzzle`, `RightGrip`, `LeftGrip`, `CigarTip`, and `ShieldSocket`.

`MarshalCharacterDriver` attaches after `CareVisuals` creates the existing controls and fallback geometry. It uses the imported skeleton, reads the existing limb/animation controls, solves ready/reload cannon grips and shield poses, and attaches the existing melee tool to the hand. Epaulettes stay on the chest so aiming does not turn them sideways. Coattails articulate independently during locomotion and crouching.

Meshes and materials are shared; skeleton poses, expressions and the eight-particle cigar emitter belong to each actor. Smoke stops and hides immediately on death, clears on reset/fallback, and is freed along with the reparented cannon on hero changes. Cosmetic animation does not consume global gameplay RNG. Missing required mesh, bone, socket or morph data retains the procedural fallback.

The authored cannon uses the existing rifle animation anchor with a fitted presentation position. Its muzzle flash follows the exported muzzle socket. **Projectile origin, safe-muzzle obstruction checks, damage, shield collision, tuning, input, actor capsule and headshot rules remain unchanged.** The forearm bracer is cosmetic; the existing energy barrier retains its authority. Team and overhealth accents fit the broader shoulders, and overhead labels clear the plume.

## Verification

```powershell
powershell -ExecutionPolicy Bypass -File tools/verify.ps1
$env:APPDATA = Join-Path (Get-Location) '.tools/runtime'
$taskEngine = & tools/find_godot.ps1
& $taskEngine --path . --fixed-fps 60 --script res://tests/marshal_character_test.gd --windowed --resolution 1440x1100 --audio-driver Dummy
& $taskEngine --path . --fixed-fps 60 --script res://tests/capture_marshal_character_game.gd --windowed --resolution 1440x900 --audio-driver Dummy
```

The source validator checks the saved Blender modifiers/weights, neutral morphs, GLB skin and sockets, four-influence attributes, geometry budget and source fingerprint. The game test checks imported skin weights, distinct actor poses, grip reach, leg articulation and stance, unchanged capsule, real firing/shield/reload behavior, all presentation states, deterministic RNG isolation, fallback, death/reset, and switching to Doctor and back.

Delivery validation passed on Godot 4.7.2 and Blender 5.2.2 LTS:

| Validation | Result |
| --- | --- |
| Saved Blender source and GLB | 177 checks, zero failures |
| Focused headless character integration | 43 checks, zero failures |
| Forward+ character integration and capture | 61 checks, zero failures |
| Real training/city captures | Four captures, player and bot model installation confirmed |
| Full `tools/verify.ps1` workflow | Exit 0; includes Marshal cannon, orbital, rework, care/barrier, overhealth, Slayer character and project regressions |
| Project structural surface audit | 2,516 probes and 4,420 winding checks, zero errors |

Forward+ captures cover firing, shielding, reload, ready, walk, jump, crouch, slide, March, Rally, Verdict, melee, guard, throw, mantle, stagger, death and face detail. Game captures exercise the real training and city scenes, the original player camera and player/bot installation. Pose-gallery ability states are staged for repeatable visual inspection; existing Marshal regression tests separately exercise combat authority. Evidence is written to `artifacts/marshal-character/` and `artifacts/marshal-*.log`.

Visual inspection and automated checks establish import, articulation and integration. Human playtesting remains the test for animation feel during extended play.
