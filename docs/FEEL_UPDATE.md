# Movement and combat feel

This update uses the existing shared motor, close combat, combat resolver, rig drivers, and hero kits. Damage, weapon cadence, projectile speeds, bindings, and hero compatibility IDs retain their existing values.

## Movement

Hold A/D in the air and steer the mouse in the same direction. Air acceleration adds velocity along the current wish direction only while its projected speed is below 2 m/s, at up to 30 m/s². Perpendicular momentum remains intact. Above running speed, air strafing can add at most 0.75 m/s per second, up to a 12 m/s gain ceiling. Faster earned dash/launch momentum stays steerable without gaining more speed. Low-speed air input remains responsive. The shared 26 m/s safety limit still applies. Neutral air has no horizontal drag; jumps still require a fresh press. Ability movement overrides retain their own rules.

Ordinary ramp, wall-kick, fast landing, and mantle slides use 2.75 m/s² friction. Dash slides retain 4 m/s² and their existing entry gates. Slide release retries standing whenever overhead clearance returns. Capsule, camera lowering, and motor posture follow the same state.

The additive motion pose runs after authored action animation and before skeleton solving. It supplies breathing, lean, torso movement, airborne legs, landing compression, and distinct slide poses. Visual scale stays within 6%; collision capsules are unaffected. Movement bursts and dust wedges use finite unshaded geometry and no gameplay RNG.

## Aiming and feedback

Nimbus and Slayer ADS defaults to 42°; normal view remains 82°. ADS mouse sensitivity follows the tangent FOV ratio, multiplied by the adjustable ADS sensitivity setting. Version-one settings using the previous 60° default migrate to 42°; customized values remain intact. Combat camera intensity can be reduced to zero independently of movement FOV accents.

Finite magazines automatically reload at zero ammunition when the actor can reload. If an action blocks reload, the request retries after recovery. Manual reload, Slayer's shell loading, infinite resources, and Seeker's bow keep their existing behavior.

Weapon recoil poses and finite bass/crack reports supplement existing hero effects. Surface impacts distinguish metal barriers or colliders marked `surface_material = "metal"` (also metal/steel names) from generic surfaces. Projectile trails are bounded. Local outgoing feedback coalesces simultaneous pellets, uses body/head symbols, a shield diamond, and a KO label, with separate body/head/shield/finish sounds. Incoming arcs use the impact origin in camera space; ongoing damage has an undirected ring and a distinct hurt sound.

## Close combat

| Mechanic | Default |
| --- | --- |
| Shield cooldown | 0.45 s |
| Full-meter shield duration | 3 s; blocks also spend meter |
| Minimum hold before release parry | 0.05 s |
| Release parry window | 0.12 s; one frontal impact |
| Melee lunge | 6.5 m; existing timings and damage |
| Melee shove | 3 m/s horizontal impulse; no additional stun |
| Throw startup approach | 0.6 m, swept against collision |
| Throw capture range | 3.2 m, existing facing and sight checks |
| Completed throw victim recovery | 0.35 s, subject to diminishing control |
| Throw immunity | 1.5 s from release for both participants |
| Throw clash recovery | 0.22 s for both participants |

Hold the existing shield key, then release immediately before an ability hits. Starting another action closes the release window. Canceling shield into an action grants no parry. Discrete non-ultimate abilities can be parried, including their attached statuses, marks, captures, and displacement. Ordinary weapon shots, melee, throws, periodic damage, persistent areas, and ultimates are excluded. Parries do not reflect damage or stun the attacker.

`CombatResolver.classify()` identifies impacts explicitly; `admit_impact()` returns a typed admission result. Damage-free abilities use the same admission check. Per-cast, per-target, per-life rejection prevents an attached effect from bypassing a successful parry. Other victims remain eligible. A parried snare ignores that defender's current life while retaining its ordinary behavior for other targets.

Shield beats frontal melee; throws beat shield; a confirmed melee strike during throw startup produces COUNTER HIT and cancels the grab. Melee windup alone provides no immunity. Weapon stars show melee startup, with separate swing, enemy impact, shield block, and wall-clang effects.

Throw previews and connection use the same eligibility query. At connection, an invalid startup target can be replaced only by an eligible target currently within range, facing, and sight checks. Paired travel remains swept, collision-safe, and interruptible. A throw against guard adds a shield-shatter cue. Thrower and victim receive different camera impulses, with mouse orientation preserved.

Training includes **Release parry practice**, which launches Slayer's real knife every 2.4 seconds. Higher-difficulty tactical bots prepare and release shield against visible incoming knives, use confirmed melee counters, and query actual throw eligibility. All actions still use combat intent and the shared resolver.

## Verification

Run `tools/verify.ps1`, which includes `tests/feel_update_test.gd`. Render the action gallery with `tests/capture_feel_update.gd`; its manifest records actual actor and motor states alongside each image. Logs, captures, and simulation evidence live under `artifacts/feel-*`; the delivery record is `docs/validation/feel-update.json`.

Automated checks and rendered captures do not establish human control feel, sound mix quality, motion comfort, or competitive balance. Those require playtesting with the new defaults.
