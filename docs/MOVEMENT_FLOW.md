# Movement flow · October 20, 2026

Shared movement now carries earned horizontal velocity between ordinary movement states instead of continually steering it back to the running-speed vector.

## Controls and tuning

- Wheel up starts a dash. Buildup retains horizontal velocity. Burst entry uses the greater of dash speed and incoming horizontal speed, bounded by the existing shared 26 m/s cap; existing burst decay follows.
- Hold Shift through a ground dash to slide on its grounded completion. The handoff copies actual surface-tangent velocity without a new impulse. Residual ground-dash speed also supports ordinary momentum-slide entry afterward.
- Downward air-dash slides still require a fresh Shift press within 0.12 s before impact. Early held Shift and late presses cannot bypass the gate.
- Neutral air movement has no horizontal drag. Air steering turns existing overspeed without increasing its magnitude; opposing input brakes. The combined velocity cap and collisions remain authoritative.
- Aligned ground input reduces excess speed at `ground_overspeed_decay = 6` m/s² until the hero's allowed running speed. Ground release/reversal keeps normal 24 m/s² braking; reversal stops before accelerating backward.
- Aim, guard, crouch, status and ability recovery movement restrictions deliberately brake. External enemy shoves remain separate from voluntary momentum, including during roots.
- `dash_up_angle = 30` degrees caps the final requested upward air-dash launch direction, including backward movement and straight-up camera aim. Level/upward air dashes integrate ordinary gravity; downward dash trajectories remain fixed. Vertical speed after the burst is the integrated exit speed.
- Shared wall-jump lift is 8 m/s; stronger incoming upward motion is retained within the combined speed cap. The existing camera-directed horizontal wall kick, clearance and rearm rules remain.
- Ordinary jump, melee's committed lunge/stop, hero-specific vertical abilities, slide friction/steering, mantle timing and mantle-slide boosts retain their established rules. Stitch hook release now uses its separate `hook_release_up = 9.5` m/s setting.

Ground excess-speed decay and upward dash angle are exposed in the training console. Hero resources inherit the shared defaults and keep their individual running speed and air-steering overrides.

## Route consequence

The old unassisted jump → head-on wall kick → mantle on the **4.5 m training tower** no longer reaches the ledge. This is an expected consequence of reducing wall-jump lift. Tower geometry is unchanged. Jump → wall kick → upward air dash → mantle reaches the same roof and supports early, buffered and post-mantle slide input; this route spends one shared dash charge.

## Verification

- Full `powershell -ExecutionPolicy Bypass -File ./tools/verify.ps1` passed with exit code **0**, including hero/combat regressions, training, all 22 city stair flights, route/geometry audits and bot navigation recovery. Final Godot editor import and source whitespace checks passed. The optional full `-Capture` suite was not run; the new native movement smoke was run separately.
- `momentum_flow_test.gd`: **77 checks passed**, including real movement/collision at 30, 60 and 144 Hz, air coasting/steering/braking, ground decay/reversal, jump/landing and mantle handoffs, held-Shift ground slides, root plus external shove, reset, pitch limiting, wall-jump height, and thin-wall momentum removal.
- Measured upward-dash apex relative to the pre-buildup position: **1.376 / 1.671 / 1.844 m** at 30 / 60 / 144 Hz. Buildup and burst boundaries are quantized to physics ticks; these are physical movement measurements, not inferred camera height.
- Wall-jump apex above its launch: **1.322 / 1.388 / 1.427 m** at those same rates. Stronger incoming upward speed is independently checked.
- `momentum_input_test.gd`: **6 native checks passed** using physical W/Shift input and wheel pulses, confirming slide handoff, one-charge spending, absence of obsolete warnings, upward angle limiting, gravity and falling exit momentum. Captures in `artifacts/momentum-native/` were visually reviewed.
- Real training-tower route and slide checks: **16 passed**, explicitly covering the lost unassisted route and dash-assisted alternative.

The normal verification script includes the new momentum suite; `-Capture` additionally runs its native-input smoke. Human playtesting is still required to judge turning commitment, route difficulty, combat balance and movement feel.
