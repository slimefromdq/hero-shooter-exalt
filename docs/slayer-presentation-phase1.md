# Slayer combat presentation: Phase 1

This pass changes presentation only. SlayerKit still resolves the same fixed equal-area pellet disk, individual attack rays/cast IDs, damage/headshot/falloff, collision and object hits, ammunition, pump cooldown, and PlayerController recoil call. CombatResolver's damage authority, per-pellet signals, training statistics, and elimination order remain unchanged. No tuning resources, character model, or other hero kits were changed.

## Effects and aggregation

`SlayerKit.fire()` builds a bounded contact report while resolving the existing casts. `SlayerShotPresentation` consumes that completed report once per discharge. A muzzle effect replaces the original full-distance box tracers and sphere pulses. Impacts group by target (or by collider and a 1.5 m surface neighborhood), prioritize confirmed enemy damage, and cap at four per discharge. Red rings confirm applied enemy damage; gold indicates a confirmed head contact; warm sparks indicate surfaces or unconfirmed/immune contacts. Feedback does not invent damage or change collision outcomes. Damage numbers and authoritative per-pellet signals retain their existing behavior.

Reusable scenes:

- `scenes/effects/slayer_shotgun_muzzle.tscn`: emissive tapered flash, 12 GPU sparks, six low-opacity smoke particles.
- `scenes/effects/slayer_shotgun_impact.tscn`: emissive contact ring and eight GPU sparks.
- `SlayerBurstEffect`: finite 0.42 s lease, brief shrinking flash, one-shot particle emission, shadows disabled, small visibility bounds, no lights or decals.

The ordinary single-target shot uses two bursts and at most 26 particles; the four-impact maximum is five bursts and 50 particles. Each owner retains at most 16 active bursts. The startup pool reserves 16 muzzle and 48 impact scenes (64 total, at most 672 particle slots); saturation drops cosmetic bursts rather than growing allocations. Inactive nodes are hidden and their script processing/emission is disabled. Muzzle placement follows the existing rendered barrel, with a cosmetic environment-only occlusion ray. That extra query has no gameplay result.

Godot's GPUParticles3D constructor itself advances the engine RNG even when fixed particle seeds are assigned. The pool therefore constructs nodes once during autoload startup, before gameplay; shots, restarts and hero switching reuse them. Particle seeds are fixed and all procedural audio noise uses private seeded RandomNumberGenerator instances. The tests verify that firing and switching back to Slayer leave the gameplay random sequence unchanged.

Set `actor.presentation.slayer_shot.enabled = false` to use the retained legacy pulse/alternate-pellet-tracer and muzzle-mesh fallback. The fallback intentionally retains its old per-pellet visual count. New shotgun recoil animation and layered audio remain available in that mode.

## Animation, camera, and lifecycle

The weapon gets a fast mechanical kick, damped return, and a short pump dip, using only presentation transforms. The existing recoil tuning, controller recoil accumulation/cap/decay, pitch/yaw, and physics are unchanged. Tiny camera projection offsets and local roll add a brief impulse without changing the aim ray's origin or forward direction. There is no camera FOV pulse, gameplay shake RNG, or physical target stagger.

Death, reset, and hero selection call `HeroPresentation.clear_feedback()`, recycling owned bursts, stopping Slayer voices, and restoring camera offsets. Lifetime expiry also recycles bursts. Global training/city restart uses `CombatEffect.clear_transients()` so pooled effects return to the pool rather than being deleted. Use this helper when adding new global transient cleanup paths. Scene exit returns leases through the same presentation cleanup.

## Original audio and replacement slots

No external sounds were supplied. The new cached original synthesis layers a broadband crack, descending bass body and filtered air tail. A separate mechanism voice contains pump clicks at 0.16 and 0.29 s. Exactly one target/surface feedback cue is chosen per discharge with contacts; a miss has no impact cue. Mechanism, blast, shell insertion and ability cues can overlap. Each ProceduralSound instance caps Slayer voices at eight, retiring only the oldest on saturation. All voices route through the existing Combat bus and distance gain.

Edit `resources/slayer_audio.tres` in the inspector. Empty slots use the procedural originals:

| Slot | Replacement content | Default level |
| --- | --- | --- |
| blast | Single shotgun discharge, immediate onset, no pump | -7 dB |
| mechanism | Pump/receiver movement; include its desired initial silence | -14 dB |
| target_impact | One confirmed-target feedback cue, independent of pellet count | -12 dB |
| surface_impact | One surface/unconfirmed-contact cue | -12 dB |

Use original or appropriately licensed finite, non-looping AudioStreams; keep tails below three seconds (the safety lifetime limit). These slots replace rather than add to their respective synthesized layer. Avoid baking a pump or hit cue into the blast replacement. No external asset dependencies are required.

## Validation and manual follow-up

Run `powershell -ExecutionPolicy Bypass -File tools/verify.ps1`. The suite includes `tests/slayer_presentation_test.gd` (27 focused checks). It compares fallback/new contact positions, normals, damage, head state, ammo, cooldown, cast counts, velocity and position; checks exact 90-damage close body shots, immune/miss feedback, RNG isolation, overlap, local/world budgets, exhaustion, expiry, and death/reset/hero-switch cleanup. Existing Slayer tests continue covering falloff, headshots, teammates, thin-wall obstruction, deployables, reload, abilities and city integration.

Run `tests/capture_slayer_presentation.gd` through Godot with `--windowed --resolution 1440x900 --audio-driver Dummy --fixed-fps 60`. `tools/verify.ps1 -Capture` also includes it. Five PNGs and four isolated original WAV layers are saved under `artifacts/slayer-phase1-*`. Rendered focused tests use the same 27 checks under Vulkan, rather than relying only on the headless renderer.

Remaining human checks: listen on headphones and speakers for blast/pump balance, hit-cue distinction, simultaneous nearby Slayers, shell/ability overlap, and Combat volume controls; assess recoil recovery and camera comfort while moving, aiming, and firing near cover; assess enemy/head/guard readability against bright and dark backgrounds. Captures use Dummy audio and do not establish audible mix quality. Automated parity establishes unchanged gameplay calculations, not perceived balance or game feel. The RTX 3080 render run is not a low-end hardware performance benchmark.
