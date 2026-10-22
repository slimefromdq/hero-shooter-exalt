#!/usr/bin/env python3
"""Self-play tuning of BotTuning weights with a (1+lambda) evolution strategy.

Each generation, `--mutants` mutated weight sets play the current champion head to head
in headless City matches (both sides, several seeds). A mutant replaces the champion when
it wins clearly *and* still plays like a person: the fitness subtracts a human-likeness
penalty (standing still in fights, too little movement tech, unrealistic death rates,
dying alone), so the search cannot drift toward campers or kamikazes.

  tools/tune_bots.py --generations 8 --mutants 4 --seconds 150 --seeds 76,971
Writes resources/bots/tuning/default.tres and docs/validation/bot-tuning.json.
State is kept in artifacts/tuning/state.json, so a stopped run resumes.
"""
import argparse, json, os, random, subprocess, sys, concurrent.futures as futures

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GODOT = os.environ.get("GODOT_BIN", os.path.join(ROOT, ".tools/godot/Godot_v4.7.2-stable_linux.x86_64"))
WORK = os.path.join(ROOT, "artifacts/tuning")
RANGES = {"objective_weight": [.3, 2.5, .25], "danger_weight": [0.0, 2.5, .25], "los_weight": [.3, 2.0, .2], "cover_weight": [.3, 2.0, .2],
          "aggression_bias": [-.3, .3, .06], "retreat_bias": [-.3, .3, .06], "regroup_margin": [1.0, 3.0, .5], "push_fraction": [.4, .9, .08],
          "weave": [0.0, 1.0, .12], "strafe_tempo": [.6, 1.6, .15], "dodge_eagerness": [.5, 1.3, .1]}
DEFAULTS = {"objective_weight": 1.0, "danger_weight": 1.0, "los_weight": 1.0, "cover_weight": 1.0, "aggression_bias": 0.0, "retreat_bias": 0.0,
            "regroup_margin": 2.0, "push_fraction": .65, "weave": .55, "strafe_tempo": 1.0, "dodge_eagerness": 1.0}
# Human-likeness bands (per team, per bot-minute) derived from design targets and the baseline.
BANDS = {"combat_idle_ratio_max": .22, "tech_min": 4.0, "deaths_min": .25, "deaths_max": 1.0, "alone_max": .2}


def penalty(team):
    p = max(0.0, team["combat_idle_ratio"] - BANDS["combat_idle_ratio_max"]) * 3
    p += max(0.0, BANDS["tech_min"] - team["tech_per_bot_minute"]) * .1
    d = team["deaths_per_bot_minute"]
    p += (max(0.0, BANDS["deaths_min"] - d) + max(0.0, d - BANDS["deaths_max"])) * 1.5
    p += max(0.0, team["deaths_alone_ratio"] - BANDS["alone_max"]) * 2
    return p


def mutate(parent, rng, keys=3):
    child = dict(parent)
    for key in rng.sample(sorted(RANGES), keys):
        low, high, sigma = RANGES[key]
        child[key] = round(min(high, max(low, child[key] + rng.gauss(0, sigma))), 3)
    return child


def evaluate(args, label, challenger_path, champion_path, seed, challenger_team):
    out = os.path.join(WORK, f"{label}.json")
    tuning = {challenger_team: challenger_path, 1 - challenger_team: champion_path}
    env = dict(os.environ, XDG_DATA_HOME=os.path.join(ROOT, ".tools/runtime"), XDG_CONFIG_HOME=os.path.join(ROOT, ".tools/runtime"))
    cmd = [GODOT, "--headless", "--path", ROOT, "--fixed-fps", "60", "--script", "res://tests/bot_behavior_benchmark.gd", "--",
           "--map=city", f"--seconds={args.seconds}", f"--seed={seed}", f"--difficulty={args.difficulty}",
           f"--tuning0={tuning[0]}", f"--tuning1={tuning[1]}", f"--out={out}"]
    subprocess.run(cmd, cwd=ROOT, env=env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=args.seconds * 6 + 300)
    data = json.load(open(out))
    me, them = data["teams"][challenger_team], data["teams"][1 - challenger_team]
    hill = data.get("hill_scores") or [0, 0]
    wins = data.get("round_wins") or [0, 0]
    objective = (hill[challenger_team] - hill[1 - challenger_team]) / 100.0 + (wins[challenger_team] - wins[1 - challenger_team])
    kills = .3 * (me["kills"] - them["kills"]) / max(1.0, me["kills"] + them["kills"])
    return {"score": objective + kills - penalty(me) + penalty(them), "objective": objective, "kills": kills,
            "penalty": penalty(me), "champion_penalty": penalty(them), "team": me}


def write_tres(values, path):
    lines = ['[gd_resource type="Resource" script_class="BotTuning" load_steps=2 format=3]', "",
             '[ext_resource type="Script" path="res://scripts/bots/bot_tuning.gd" id="1"]', "", "[resource]", 'script = ExtResource("1")']
    lines += [f"{k} = {values[k]}" for k in DEFAULTS]
    open(path, "w").write("\n".join(lines) + "\n")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--generations", type=int, default=8)
    parser.add_argument("--mutants", type=int, default=4)
    parser.add_argument("--seconds", type=int, default=150)
    parser.add_argument("--seeds", default="76,971")
    parser.add_argument("--difficulty", type=int, default=1)
    parser.add_argument("--workers", type=int, default=os.cpu_count() or 4)
    parser.add_argument("--accept", type=float, default=.08, help="minimum mean margin to replace the champion")
    parser.add_argument("--out", default=os.path.join(ROOT, "resources/bots/tuning/default.tres"))
    parser.add_argument("--report", default=os.path.join(ROOT, "docs/validation/bot-tuning.json"))
    args = parser.parse_args()
    os.makedirs(WORK, exist_ok=True)
    seeds = [int(s) for s in args.seeds.split(",")]
    state_path = os.path.join(WORK, "state.json")
    state = json.load(open(state_path)) if os.path.exists(state_path) else {"generation": 0, "champion": DEFAULTS, "history": []}
    rng = random.Random(1234 + state["generation"])
    while state["generation"] < args.generations:
        gen = state["generation"]
        champion_path = os.path.join(WORK, f"champion_{gen}.json")
        json.dump(state["champion"], open(champion_path, "w"))
        mutants = [mutate(state["champion"], rng) for _ in range(args.mutants)]
        jobs = {}
        with futures.ThreadPoolExecutor(max_workers=args.workers) as pool:
            for m, values in enumerate(mutants):
                path = os.path.join(WORK, f"gen{gen}_m{m}.json")
                json.dump(values, open(path, "w"))
                for seed in seeds:
                    for side in (0, 1):
                        label = f"gen{gen}_m{m}_s{seed}_t{side}"
                        jobs[pool.submit(evaluate, args, label, path, champion_path, seed + gen * 101, side)] = m
            results = {m: [] for m in range(len(mutants))}
            for job in futures.as_completed(jobs):
                try:
                    results[jobs[job]].append(job.result())
                except Exception as error:  # a crashed or timed-out match counts as a loss
                    print(f"  evaluation failed: {error}", file=sys.stderr)
                    results[jobs[job]].append({"score": -1.0, "penalty": 1.0})
        summary = []
        for m, runs in results.items():
            mean = sum(r["score"] for r in runs) / max(1, len(runs))
            summary.append({"mutant": m, "values": mutants[m], "mean_score": round(mean, 3), "runs": len(runs),
                            "mean_penalty": round(sum(r.get("penalty", 0) for r in runs) / max(1, len(runs)), 3)})
        best = max(summary, key=lambda s: s["mean_score"])
        accepted = best["mean_score"] > args.accept
        if accepted:
            state["champion"] = best["values"]
        state["history"].append({"generation": gen, "best": best, "accepted": accepted, "candidates": summary})
        state["generation"] = gen + 1
        json.dump(state, open(state_path, "w"), indent=1)
        print(f"gen {gen}: best mutant {best['mutant']} margin {best['mean_score']:+.3f} penalty {best['mean_penalty']:.3f} -> {'ACCEPT' if accepted else 'keep champion'}", flush=True)
    write_tres(state["champion"], args.out)
    report = {"generations": state["generation"], "seconds": args.seconds, "seeds": seeds, "difficulty": args.difficulty,
              "bands": BANDS, "champion": state["champion"], "defaults": DEFAULTS,
              "history": [{"generation": h["generation"], "accepted": h["accepted"], "best_margin": h["best"]["mean_score"],
                           "best_penalty": h["best"]["mean_penalty"], "best_values": h["best"]["values"]} for h in state["history"]]}
    json.dump(report, open(args.report, "w"), indent=1)
    print("champion:", json.dumps(state["champion"]))


if __name__ == "__main__":
    main()
