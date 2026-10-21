# Combat feedback and training workshop

Combat confirmation is shared by Training, Meridian Gardens, and Museum. Successful health hits create small red sparks; shield hits create blue sparks. The white reticle X scales with the damage from each attack, grouping shotgun pellets. Headshots glow red, and a final blow displays a red skull for 0.6 seconds. Incoming attack directions remain visible for one second and follow your camera. Periodic damage uses a neutral pulse. Below 25% health, the screen edges gradually turn red; the center remains clear.

## Quick training controls

Open **Tab / Esc** in training. The pause menu offers **No cooldowns**, **Prevent death (1 HP)**, **Infinite ammunition**, **600 HP tank**, **Perfect shield parry**, and **Extended parkour**. **Spawn hero / Ability lab** opens the training console with the workshop controls at the top.

The toggles start disabled and survive exercise resets and hero changes during the session. No cooldowns restores ability charges, dashes, guard availability, and ultimate readiness without skipping startup, recovery, reloads, or weapon cadence. Infinite ammunition is independent. Prevent death lets damage lower health to 1 HP and preserves status effects and incoming damage indicators. Falling recovers the player; in parkour, recovery returns to the latest checkpoint. Existing invulnerability and infinite-resource experiments remain available in advanced tools.

## Dummies and drills

Choose any roster hero, a behavior, and Enemy or Ally, then **Spawn hero**. Hero dummies retain their native health. Use the existing-target dropdown and **Apply behavior / team** to change a spawned target. There are eight manual target slots, independent of built-in practice stations. The permanent range includes a labelled 600 HP stationary tank dummy that respawns after 3.5 seconds.

Behaviors include Stationary, Strafing, Full kit tactical AI, Melee only, Throw only, Shield defense, and Mixed close combat. The close-combat modes only use shared melee, throws, and guard. Perfect shield parry retains the real Slayer knife and the existing 0.12-second release window; its overhead countdown and HUD show timing, successful parries, and hits taken.

## Ability lab

Select a hero and a primary, secondary, Q, E, 1, or 2 entry, then **Cast once** or **Repeat**. These launch real kit input sequences in the west annex. The enemy targets you with offensive actions; support tests create an injured ally. Healing, shields, buffs, movement, preparation, and passives are labelled rather than presented as damaging attacks. Seeker assigns a spirit before Guiding Wing. Dynamo confirms its wall preview. Nimbus fires after ultimate preparation. Rogue loads burst ammunition and performs a follow-up dive. Samson places the court on clear ground beside its ally. Stitch demonstrates concealment followed by an opening lunge and has a hook wall.

**Stop** removes lab actors, owned attacks, summons, traps, status links, and temporary fixtures. Changing tests restarts the setup. Repeats run at nine-second intervals. Full kit sparring uses the shared tactical AI in the original arena. Use Prevent death if you want to keep receiving attacks without dying.

## Extended parkour

The east annex contains a separate six-checkpoint route for jumps, mantles, wall kicks, directional dashes, momentum slides, and a combined finish. Painted guides connect numbered checkpoints. Raised checkpoints require reaching the deck. The safe floor allows retries; **Recover checkpoint** returns to the latest checkpoint without resetting the timer. **Extended parkour** restarts the route. The course uses shared movement and is intended for roughly two minutes of practice at a learning pace. The original tower route remains available.

## Verification

The regular `tools/verify.ps1` workflow includes `combat_feedback_test.gd`, `training_expansion_test.gd`, `ability_lab_test.gd`, and `parkour_course_test.gd`. The ability lab test executes all 60 hero/action entries through their real controllers and kits. The parkour test drives every hero through the full course using shared movement. `tests/capture_combat_feedback.gd` captures widescreen and ultrawide feedback and accepts `--mode=training`, `--mode=city`, or `--mode=museum` after the engine argument separator.
