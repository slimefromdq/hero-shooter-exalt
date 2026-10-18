# Playable Slayer model

`slayer_character.tscn` is the game component instantiated by `SlayerCharacterDriver` for every Slayer player/bot. It is derived from the editable model and raw GLB in the parent directory. Training and the city use the same `HeroPresentation` path. Existing hero selection and Slayer gameplay remain authoritative.

## Build and regenerate

After regenerating `slayer.glb`, run from the repository root:

```powershell
$taskEngine = & ./tools/find_godot.ps1
$env:APPDATA = Join-Path $PWD '.tools/runtime'
& $taskEngine --headless --path . --script res://tools/build_slayer_character.gd
& $taskEngine --headless --path . --script res://tests/slayer_character_test.gd --fixed-fps 60
```

The builder creates a sixteen-bone `Skeleton3D`, normalized weights with at most four influences per vertex, a shared skin, nineteen skinned body groups, and two authored weapon meshes. Original mesh positions, PBR materials, vertex colours, facial morphs, height and facing survive the conversion. The native `.blend` remains the editable modular authoring source; this deterministic Godot step supplies its game skin. `rig-report.json` records the source GLB hash; the live test rejects a stale generated rig.

The scene references shared binary mesh resources instead of embedding duplicate vertex buffers in the text scene. Multiple actors share those meshes and materials but own separate skeletons and morph values. Weight assertions allow the engine's four-influence 16-bit storage precision. Expanded render bounds cover kicks and throws without changing collision bounds.

## Animation and attachments

`SlayerCharacterDriver` consumes the existing presentation limb controls after shared movement, crouch, slide, traversal, melee, boot and throw animations have applied. It maps them to the weighted skeleton. A two-segment arm solver maintains the ready/reload gun grip and both hand contacts on the axe shaft during its windup. The knife and trap follow the actual hand while retaining the existing anticipation/release visibility. The authored shotgun and axe use the existing weapon animation anchors; recoil and stow behaviour remain in `SlayerVisuals`.

Shotgun muzzle VFX use an explicit marker aligned to the authored barrel crown. The separate combat muzzle, pellet directions, hit registration, damage, ammunition, recoil tuning and cooldowns are unchanged. Compact faction markings and the existing team ring preserve team readability without covering the new outfit.

Head aim, deterministic blinking and focused/hurt expressions use the authored morphs. The animation clock never consumes gameplay RNG. Death/restart clear presentation feedback; switching heroes frees the skeleton, facial state and weapon meshes mounted outside the avatar subtree.

## Fallback

The current procedural Slayer remains available. From a Slayer actor's presentation:

```gdscript
presentation.slayer_model.set_enabled(false) # Original procedural model.
presentation.slayer_model.set_enabled(true)  # Authored model.
```

The switch restores held-tool transforms as well as mesh visibility. If the generated scene is absent, `attach()` leaves the procedural model active. Controls, gameplay components and collision are shared by both paths. No other hero model is replaced.

## Verification

`tests/slayer_character_test.gd` instantiates the real training scene. It checks source freshness, bindings, normalized weights, exact capsule dimensions, actual articulated hand/foot movement, preserved hip spacing, mesh sharing with independent expressions, RNG independence, fallback, held tools, an actual ultimate windup, death/reset and switch cleanup. Its rendered mode captures ready, arena face, shotgun, reload, running, jump, crouch, boot, knife, trap and axe states. `tests/slayer_integration_test.gd` also asserts the authored rig is present on the player and opposing Slayer in a real 6v6 city.

Both checks run through `tools/verify.ps1`; `-Capture` includes the live character rendered check. The current full `tools/verify.ps1` run passed with exit code 0. Final focused checks passed **45 headless** and **56 rendered** assertions, plus the refreshed Slayer presentation (27), ability (71), revision (47) and real training/city integration (30) checks. Asset hashes are in `integration-validation.json`. Local logs and frames are under `artifacts/slayer-integration/`.

Remaining manual checks: human control feel, combined facial expression timing, extreme aim-angle hand/weapon contact, close camera intersections, cloth deformation during rapid transitions, varied city-light readability and lower-end hardware performance. The model retains the 91,330-triangle / 77-material-primitive review geometry; it has not received a new texture atlas, hand-authored animation library or final production LOD pass. These are polish/performance follow-ups, not alternate gameplay implementations.

Representative actual in-game frames: [city shoulder camera](../../../../artifacts/slayer-integration/city-gameplay.png), [city character](../../../../artifacts/slayer-integration/city-character.png), [training portrait](../../../../artifacts/slayer-integration/face-in-arena.png), [axe windup](../../../../artifacts/slayer-integration/axe.png).
