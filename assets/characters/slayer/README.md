# Slayer facial reconstruction review asset

Original Slayer hunter, generated with Blender 5.2.2 LTS. This reconstruction replaces the old solid head with real socket apertures, inset ellipsoid eye surfaces and welded skin/lid transitions. The editable source and raw GLB remain the authoring assets. The generated [runtime rig](runtime/README.md) now supplies the playable Slayer model in training and city matches. Gameplay camera, collision, abilities and balance are unchanged. No existing Riot character, external geometry or textures are reproduced.

## Open the result

- [Editable Blender source](slayer.blend), with modular body/equipment, studio lighting and nine facial shape keys.
- [Self-contained Godot GLB](slayer.glb), 1.861 m visual height after neck shortening, ground at zero, Blender +Y / Godot -Z facing.
- [Face settings](face-config.json), [generator](../../../tools/blender/slayer_face.py) and [model report](model-report.json).
- [Previous source and export](rollback/pre-reconstruction/), including the prior generator, settings and three matching before renders.

Native `.blend` files use Godot's Keep File importer; Godot consumes the explicit GLB. Cameras, studio lights and floor are excluded from export. The source had no skeletal rig or animation library; the six pre-existing facial shape keys were regenerated for the new topology and retained by name. Three additional expression keys are provided. The runtime generator derives a sixteen-bone weighted game rig from this source without altering the native authoring geometry. The existing combat animation controls drive that rig through a dedicated presentation component.

## Reconstruction

The eye openings are horizontal almond contours with a narrower vertical aperture and a subtle outer tilt. The neutral upper lid overlaps 9% of the iris diameter. Head skin is actually removed inside the sockets, rather than hidden beneath white patches. Ellipsoid surfaces sit behind the lids; iris, fibers, pupil and two restrained catchlights follow that curved surface. Skin and outer lids share vertices and normals. A shallow upper roll/crease and supported lower lid use the same skin material, without a contrasting eyelid ring or lower liner.

The forehead/brow transition, cheekbone, cheek hollow, muzzle, small bridge/tip and chin are part of one continuous facial surface. The lower face is shorter, with a slightly wider chin and a restrained, asymmetric mouth. Lips blend back into the muzzle with less projection and softer colour than the previous decorative lip treatment. Low tapered brows establish a quieter, more confident neutral expression.

Ten front hair clumps are shifted slightly to clear the exposed eye/brow while preserving the shaggy asymmetry. Their original coordinates remain in `SlayerFramingRest`; applying the edit repeatedly is idempotent. The other 243 protected components, including original ears/earrings, body, outfit, weapons and remaining hair, are checked against the rollback `.blend` using evaluated world-space geometry/topology/material hashes.

Skin warmth, socket shading and upper-eye shading use exported vertex colours and ordinary PBR materials. There is no compositor dependency or custom Godot shader. Export-only box UVs support imported morph tangents; they are not a finished texture atlas. Tinted skin is ordered after the sclera primitive to retain vertex-colour albedo under the observed Godot 4.7.2 importer behaviour. Generator randomness uses a private fixed seed, independent of hair/gameplay randomness.

## Actual rendered views

All final Blender views use 48 Cycles samples and denoising. Portraits use the same cameras and studio lights as the rollback before views. Weapons are hidden only in facial inspection renders to expose the profile jaw, then restored for saved source/export and body views.

| Required view | Render |
|---|---|
| Neutral front close-up | [PNG](previews/face-neutral.png) |
| Neutral three-quarter | [PNG](previews/face-three-quarter.png) |
| Side profile | [PNG](previews/face-profile.png) |
| Relaxed / half-lidded | [PNG](previews/face-relaxed.png) |
| Focused / angry | [PNG](previews/face-focused.png) |
| Subtle smirk | [PNG](previews/face-smirk.png) |
| Full-body portrait | [PNG](previews/front.png) |
| Actual gameplay-distance framing | [PNG](previews/gameplay-distance.png) |

Additional views include [blink](previews/face-blink.png), [mouth open](previews/face-open-mouth.png), smile, determined, equipment, back and side. `previews/godot-face-*.png` and `godot-import.png` are actual Godot renders. The gameplay-distance inspection uses the existing 3 m arm, 82-degree vertical FOV, 0.65 m shoulder, 1.75 m pivot and -0.12 rad pitch at 1440 x 900, without editing the live camera.

Visual iteration records: pass 1 reduced the startled opening and rebuilt sockets/planes, but inspection exposed a visible socket seam. Pass 2 welded the outer lid/head boundary and reduced iris offsets; profile inspection then prompted deeper eye placement, a shorter lower face and a slightly higher mouth. Final inspection corrected the front/back head seam and two folded socket triangles in half-lidded poses. A continuous deformation field fixes the folds, with explicit regression checks for both affected expressions. Closed eyes and imported materials were also inspected. Intermediate images are retained locally under `artifacts/slayer-face-reconstruction/pass-1` and `pass-2`; the permanent rollback folder holds the original before views. See `face-validation-summary.json` for the final inspection record and artifact hashes.

## Regenerate

From the repository root in PowerShell:

```powershell
$blender = 'C:/Program Files (x86)/Steam/steamapps/common/Blender/blender.exe'
& $blender --background --factory-startup --python-exit-code 1 --python tools/blender/build_slayer.py -- --face-only --face-config assets/characters/slayer/face-config.json --samples 48
```

`--face-only` opens the saved source, reconstructs Face and the original ear/accessory group, applies the idempotent front-hair edit, checks the protected components and exports neutral morph weights. It does not rebuild the body or outfit. Use `--views face-neutral face-three-quarter face-profile` for a shorter render iteration, or `--skip-renders` for geometry/export only. A full build without `--face-only` recreates the entire procedural asset. Express manual changes in the generator or save them in a separate source copy before regenerating.

## Facial controls

Values are validated before the source is overwritten. Measurements are in source metres before the existing root transform. The former unused `eye_height`, `eye_tilt` and `eyebrow_angle` names have been replaced by the explicit opening/outer-tilt/brow controls below; use the rollback generator with the rollback preset.

| Parameter | Default | Meaning |
|---|---:|---|
| `eye_scale` | 1.25 | Overall eye width and ellipsoid radius. |
| `eye_width` | 0.8 | Horizontal half-width multiplier, independent of opening height. |
| `eye_opening_height` | 0.8 | Vertical opening multiplier; neutral starts about 30% below the prior oval height. |
| `eye_outer_tilt` | 0.075 | Rise of the outer corner as a slope. |
| `upper_lid_overlap` | 0.09 | Neutral lid overlap as a fraction of iris diameter at opening height 0.80. |
| `brow_height` | 0.024 | Brow elevation above the eye centre, metres. |
| `brow_angle` | 0.035 | Brow slope, with a low curved arch and restrained asymmetry. |
| `brow_thickness` | 0.0052 | Maximum brow tissue/graphic thickness, metres. |
| `chin_width` | 1.08 | Chin width multiplier, independent of cheek width. |
| `nose_projection` | 0.92 | Bridge/tip projection multiplier. |
| `mouth_width` | 0.027 | Mouth half-width, metres. |
| `mouth_smirk` | 0.0012 | Neutral corner asymmetry, metres. |
| `head_width` | 1.055 | Visible head width, fading toward the unchanged crown. |
| `chin_lift` | 0.024 | Shortens the lower face in metres, fading out below the cheeks. |
| `eye_spacing` | 0.047 | Each eye centre distance from the face midline, metres. |
| `iris_scale` | 1.1 | Iris radius multiplier on the actual ellipsoid surface. |
| `cheek_fullness` | 1.12 | Cheekbone volume with a softer transition into the lower cheek. |
| `jaw_taper` | 0.95 | Lower-jaw taper multiplier. |
| `nose_size` | 0.9 | Integrated nose and nostril scale. |
| `mouth_curvature` | 1.15 | Gentle neutral mouth curvature. |
| `eyelid_thickness` | 0.0008 | Inner lid tissue thickness in metres. |
| `lip_fullness` | 1.1 | Upper/lower lip tissue height and projection. |

Neutral is Basis, with all weights zero. Relative morphs `Blink`, `BrowRaise`, `BrowLower`, `Smile`, `Frown`, `MouthOpen`, `Relaxed`, `Focused` and `Smirk` survive GLB and Godot import. Drive weights from 0 to 1 on `Slayer_Face`. Blink closes the lid/socket and retracts eye layers; relaxed/focused narrow the upper opening; smirk raises one mouth corner. Mouth open supplies a dark aperture and lower-lip/chin motion, not finished dental geometry. Arbitrary combined extremes and animation timing still need an animation pass.

## Validation and limits

```powershell
& $blender --background --factory-startup --python-exit-code 1 --python tools/blender/test_slayer_face.py
& $blender --background --factory-startup --python-exit-code 1 --python tools/blender/validate_slayer_blend.py
& $blender --background --factory-startup --python-exit-code 1 --python tools/blender/validate_slayer_glb.py
$taskEngine = & ./tools/find_godot.ps1
$env:APPDATA = Join-Path $PWD '.tools/runtime'
& $taskEngine --headless --path . --editor --import --quit
& $taskEngine --headless --path . --script res://tests/slayer_model_asset_test.gd
& $taskEngine --path . --script res://tests/slayer_model_asset_test.gd --windowed --resolution 1000x1200 --audio-driver Dummy
```

Current revision: **40 generator checks, 11 saved-source checks, 20,511 structural GLB checks, 164 headless engine checks and 180 rendered engine checks, all passing.** Export: **91,330 triangles**, 21 meshes, 77 material primitives and nine facial morphs.

Reports record generator geometry/parameter checks, saved source/rollback comparisons, GLB buffers/normals/PBR/morph checks, and actual Godot import/render checks. Render checks verify pixel changes for driven expressions. The review budget remains under 95,000 triangles, with 21 export meshes and 77 material primitives. This is a detailed review model, not a final gameplay draw-call budget.

The face-only reconstruction record is in `face-validation-summary.json`. The later playable-model integration has its own runtime checks and verification record under `runtime/`; both the source asset check and live character check are included in `tools/verify.ps1`.

Remaining human review: approve the artistic direction, tune expression timing and combined morph extremes during animation, and judge readability and animation polish under varied arena lighting and camera motion. At the actual gameplay distance the face occupies few pixels; portrait detail is primarily visible in close-ups. Rollback copies are available for comparison or restoration.

## Shorter neck revision

The head, hair and earrings sit approximately 3.93 cm lower than the first playable-model commit. The visible neck compresses into the existing collar from stored rest coordinates, preserving the face, body scale, outfit, weapons and all nine facial morphs. The visual crown is now approximately 1.861 m above ground; the gameplay capsule remains exactly 1.9 m. The game rig derives its head anchor and neck weights from the source report.

Regenerate just this proportional change with `--neck-only --neck-shortening .075`; `.035` is the previous baseline, so `.075` adds 4 cm in authored coordinates. Reapplying the same value is idempotent. Use a face-only rebuild to retain the saved neck setting. Run `tools/build_slayer_character.gd` afterward to refresh the live asset.

Current neck inspection views are `neck-bust`, `front`, `face-neutral`, `face-three-quarter` and `face-profile`, plus refreshed Godot source/live views and city captures. Other Blender pose previews retain the preceding neck placement until the full preview set is regenerated. `neck-validation.json` records this localized revision; the earlier face/full-suite records remain historical baselines.
