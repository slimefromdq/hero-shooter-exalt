# Slayer · playable hero

Slayer is playable in Meridian Gardens and the training arena. Both heroes use `HeroActor`, `HeroMotor`, `CloseCombat`, `CombatResolver`, `PlayerController`, and the same ultimate economy. The supplied portraits informed her original geometric layered hair, cropped jacket, silver equipment and reinforced boots. No external models are required.

## Play

Run `Launch.ps1 -Slayer` for the city or `Launch.ps1 -Training -Slayer` for the sandbox. Both pause menus offer **Play Slayer**. City selection restarts the match with zero ultimate charge; training selection resets the exercise. Selection survives scene transitions. Nimbus remains the default on ordinary launch.

**Tab → Start Slayer hunt** selects Slayer and provides stationary, moving and attacking Slayer targets. F6 restores resources and cleanses statuses; F5 resets; F3 shows state, velocity, actual shot damage, pellet count and recharge timers. The advanced tuning panel exposes Slayer's numeric fields. Reset after changing capacities or base health.

| Input | Action |
| --- | --- |
| Left click / right hold | Street Sweeper / shoulder aim |
| R | Load individual shells; offensive actions interrupt |
| Q | Silver Knife |
| E | Boot Rush |
| 1 | Place Hunter's Snare on valid nearby ground |
| Right mouse + 1 | Throw a snare toward the crosshair |
| 2 | Heads Will Roll; automatic release after windup |
| 3 / Shift / Space | Shared dash / slide / jump, mantle and wall kick |
| 5 / 6 / 4 | Shared melee / guard / throw and counterthrow |

Internal `hover`, `deflect` and `bomb` action names remain Q/E/1 slots. Slayer's Q cannot activate Nimbus's Hover. Sprint remains undecided in the design; both heroes retain the same 6 m/s baseline and shared traversal.

## Rules and tuning

Defaults are in `resources/slayer.tres` and exported `SlayerTuning` fields. Each actor gets its own resource copy.

| Mechanic | Initial implementation |
| --- | --- |
| Shotgun | 6 shells, 10 × 7 body damage, global 2× head multiplier, 1.1 s pump lock, 2.2° fixed disk spread |
| Falloff | Full through 8 m; linear reduction to 15% at 14 m; 35 m trace limit |
| Reload | First shell after 0.3 + 0.55 s; subsequent shells every 0.55 s |
| Knives | 2 charges, sequential 7 s recharge, 30 direct damage, 35 m/s, 25 m range |
| Bleed | 8 DPS for 4 s in eight 4-damage ticks; refresh retains partial tick progress |
| Boot Rush | 0.12 s startup, up to 8 m at 25 m/s, 55 damage, 8 m/s decaying displacement, 9 s cooldown |
| Boot recovery | 0.18 s on contact; 0.35 s on miss/wall; 30% horizontal exit velocity before braking |
| Snare | 2 charges / active traps, sequential 12 s recharge, 0.5 s arm time, 1.4 m radius, 15 s lifetime, 25 HP |
| Ground trigger | 25 damage, 1.5 s root and mobility lock; aim and shooting remain available |
| Direct thrown hit | 12 damage, 50% slow and mobility lock for 1.5 s; early consumption |
| Instinct | Private 4 s marks within 32 m; wounded warning at 30% effective HP; ordinary visibility/depth tests |
| Axe | 0.65 s windup, 0.2 s release, 0.55 s recovery; 20 m/s, 30 m range, 0.55 m collision radius |
| Axe contact | 110 direct damage, then an 8 s wound reducing effective max HP by 50% of base maximum |

Pellets trace from the muzzle with a shoulder obstruction check, individual resolver cast IDs, and one collision each. HUD feedback sums actual damage for the shot; events retain individual pellet/headshot/shield attribution. Existing team, spawn-room, invulnerability and paired-throw rules apply.

Reload cancels preserve inserted shells. Knives can follow gunfire after 0.25 s. Knife/trap casts have 0.22/0.25 s recovery. Cancels never reset the pump lock. Boot and axe commitments reject other attacks through recovery; a successful boot opens normal shotgun, knife, melee and movement follow-ups after its shorter recovery. Boot never replenishes dash or wall-jump permissions.

Boot moves the existing CharacterBody through normal collision response. Ground entry uses flat camera aim; air entry retains committed 3D direction. Walls stop it, slopes use capsule sliding, and ledges lead to falls. Frontal guard uses the shared cost and attacker stagger. Knockback uses swept, decaying displacement rather than repeated velocity additions.

Placement validates ground normals and overlap before spending a snare charge. Missed throws bounce off unsuitable surfaces, settle on walkable ground and arm. Friends cannot trigger/damage traps. Enemy hitscan, projectiles, axes and bombs can destroy them. New deployments above the active limit retire the oldest trap. Death, reset, selection and scene teardown remove owned attacks. Root/slow cancel active mobility while retaining cooldowns and preserving unrelated reloads and axe windups.

The piercing axe hits each actor once and stops at walls. It follows projectile defense rules: ordinary guard defaults to zero bullet reduction; Nimbus's frontal Deflect stops axe and wound. Invulnerability and protected rooms reject both. Remaining shields prevent the wound. Paired throw participants take existing 10% direct damage and cannot receive a full wound. Windup interruption spends the ultimate without refund.

Wounds are per-life runtime statuses. Direct damage resolves first; HP then clamps to the new ceiling without a second damage event. Wounds refresh without recursive stacking. Expiry/cleanse restore the ceiling without granting health. Respawn clears wounds and restores full HP. Health packs respect effective maximum. Purple health-bar segments, opponent timers and floor rings expose the effect.

Bleed ticks through the shared resolver with its originating attacker, including after attacker death. Cleansing, invulnerability, team rules and respawn apply. Marks clear on either participant's death/reset, including immediate respawns. Only the viewing Slayer sees her pursuit indicator; it cannot reveal enemies through walls or on the tactical map.

## Implementation and validation

Completed plan: inspect and preserve the architecture; implement kit/status rules; connect selection, AI, presentation and training; verify engine physics and rendered output.

- `tests/slayer_test.gd`: **108 checks** covering weapons, cancels, deterministic bleed, boot/trap collision and interruption, wounds, defenses, healing, marks and cleanup. Includes thin walls, doorways, slopes, ledges, falling momentum, moving/airborne enemies and a 500 HP target.
- `tests/slayer_integration_test.gd`: **28 checks** using real scenes, paused selection, live bot attacks, finite resources, respawn economy, aggregate hit feedback and transition cleanup.
- All **530 previous checks** and **1,358 structural collision probes** pass. Native fullscreen adds **20 checks** with Slayer selected; its test now locates the actual display button instead of a positional index.
- The final **600-second mixed-roster simulation passes 15 checks**, with five Slayers, 4/6 captures, 279 contested seconds and 147 deaths. Both teams use subway, arcade and high decks. No falls, persistent stalls or recovery teleports were recorded.
- `tests/capture_slayer.gd` produces ten Forward+ renders covering silhouette, shotgun, boot, snare, axe windup/flight, wound, victim HUD and console. These were inspected. Original finite WAV cues and an `audio_cue` signal provide sound and replacement hooks. Final capture exits without script errors or leaked audio instances.

Total: **666 headless correctness checks**, **20 native display checks**, **15 simulation checks**, plus **1,358 collision probes**. Verified in installed Godot **4.7.2 stable**.

Run `tools/verify.ps1`, adding `-Capture` for rendered checks. Reproduce the mixed-hero simulation with:

```text
godot --headless --path . --fixed-fps 60 --script res://tests/city_simulation_test.gd -- --hero=slayer --seconds=600 --seed=76
```

Logs, JSON, WAV and PNG evidence are in ignored `artifacts/`. Focused reports: `slayer-results.json`, `slayer-integration-results.json`. Simulation report: `slayer-city-simulation-results.json`. The combined record is `slayer-validation-summary.json`.

## Human acceptance

The complete loop is connected and engine-tested. Art/action poses use articulated primitives and sound uses synthesized effects. Human playtesting remains necessary for recoil comfort, kick commitment, trap visibility, sound quality and competitive balance. Networking remains outside this offline project's scope. No permanent speed bonus, lifesteal or damage-amplification passive was added.
