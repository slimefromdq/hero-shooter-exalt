# Seeker

Seeker replaces Relay visibly while retaining the stable `relay` ID, tuning resource and kit class. Launch with `Launch.ps1 -Seeker -Training` or `--hero=seeker`; existing Relay launch arguments remain compatible. The new procedural model and portrait show a cloaked spiritual archer and magical bird rather than mechanical equipment.

| Input | Ability | Tuning |
| --- | --- | --- |
| LMB / held LMB | Spirit Bolts | Infinite arrows; 60 body damage, 1.75× headshots, 0.8 s cadence, 115 m/s, 65 m reach. No reload. |
| Hold/release RMB | Talon Volley | 0.2–1 s charge, five arrows, 40–100% of 28 damage each, 1.5 s recovery. One central arrow leads four fluid spiraling arrows by 0.6 m. |
| 1 | Guiding Spirit | Assign visible aimed ally within 65 m; without an aimed ally select self. 0.25 s transfer, 1 s reassignment cooldown. |
| Q | Omen | Visible enemy within 65 m; six-second reveal and +20% of all Seeker damage against that enemy; 12 s cooldown. |
| E | Guiding Wing | Main recipient receives 60 healing and +30% movement speed for 2 s; 8 s cooldown. Requires current sight and completed transfer. |
| Fresh airborne Space | Spirit jump | One use per airtime; 5 s cooldown; 11 m/s upward impulse and directional boost up to 8 m/s. Normal jump, mantle and wall-jump retain priority. |
| 2 | Murmuration | 0.35 s preparation, ten-second duration. Three distinct recipients; 33.75 HP/s each; arrows gain unlimited enemy piercing at full damage. |

The main bird provides 25 HP/s without batteries, ammo or recharge. It continues healing for five continuous seconds after losing sight, resetting that grace when sight returns. Exceeding 65 m returns it immediately. Death, respawn, hero switch, team change, removal and protected-room invalidation end assignments. No assignment automatically follows a new life. Healing works while Seeker attacks and charges.

The four outer volley arrows have real swept collision along their spiral paths. The central arrow's first confirmed enemy hit makes all surviving outer arrows immediately home onto that target's current life. Cover still blocks them. A central miss or obstruction never unlocks homing. Invalidating a homing target makes survivors continue their last heading without reacquiring. Allies do not intercept Seeker's arrows or Omen acquisition.

Omen is source-bound and restricted to one enemy. Its spectral sigil is shown through cover only to Seeker and the main bird's current recipient, with the six-second remaining time. Reassignment transfers that permission. It never enables attacks through cover; death, respawn, hero switch, concealment and other invalidation clear it. Its damage bonus is applied before ordinary mitigation and also affects swoops.

During Murmuration, the manually assigned main bird is upgraded rather than duplicated. Two cooler, translucent birds automatically choose distinct eligible recipients, including Seeker, prioritizing missing-health percentage and then distance/actor order. They retain valid recipients and replace invalid ones. Main reassignment takes priority; conflicting extra birds move to another recipient. Empty slots orbit without healing.

Every confirmed arrow hit during Murmuration triggers a 25-damage swoop from each bird whose recipient is within 12 m of the enemy and has clear sight to it. Individual volley arrows and pierced enemies each trigger swoops, with no cooldown. Swoops never recurse, headshot, interrupt healing or charge the next ultimate. Visual concurrency is bounded without dropping damage. Walls, hostile barriers and structures still stop piercing arrows; each arrow damages each actor at most once. Deflection clears homing, piercing and Seeker callbacks.

Ultimate expiration removes the two automatic channels and extra birds and returns the main channel to 25 HP/s. Arrows already in flight retain their cast-time piercing but cannot trigger swoops after expiration. Owner death/reset/switch removes owned projectiles and companion state immediately. Spirit birds have no health, collision or independent combat authority.

## Implementation and validation

Authority stays in the existing kit and resolver; `SeekerArrow` specializes the shared projectile convention for curved swept flight, homing and piercing. `SeekerVolley` holds one life-bound homing lock. `SeekerPresentation` builds the placeholder model and non-colliding birds. Guiding Wing uses source-bound shared benefits. Existing heroes retain their projectile defaults.

`tests/seeker_test.gd` covers combat, healing boundaries and lifecycle; it is included in `tools/verify.ps1`. Updated targeting, ability selection, bot tactics, crouch, reload and native roster input tests enforce Seeker's new behavior. `tests/capture_seeker.gd` creates reproducible in-engine frames under `artifacts/seeker-*.png`. `tests/capture_roster.gd -- --seeker-only --portraits-only` regenerates only Seeker's portrait in the compatible `relay.png` slot.

Automated validation and captures do not establish competitive balance or control feel. Those require human playtesting, especially the intentionally unrestricted ultimate swoops and concentrated homing volley.

Validated on Godot 4.7.2: full repository verification passed (4,412 passing assertions printed), 104 focused Seeker checks, 86 bot tactics checks, 40 native roster input checks, 262 roster checks, and 109 crouch checks. Seed 76 completed a 600-second city simulation with 17/17 checks, no falls, persistent stalls or recovery teleports. Seven rendered Seeker captures and the new portrait were inspected. See [machine-readable results](validation/seeker-results.json).
