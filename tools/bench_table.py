#!/usr/bin/env python3
"""Print a compact comparison of BENCH lines from one or more labels: tools/bench_table.py label1 label2 ..."""
import sys, json, glob, os
keys = ["combat_idle_ratio","combat_share","mean_speed","tech_per_bot_minute","jumps_per_bot_minute","deaths","deaths_alone_ratio","outnumbered_ratio","stuck_events","objective_share","damage_per_bot_minute","link_uses"]
short = ["idle","combat","speed","tech/m","jump/m","deaths","alone","outnum","stuck","obj","dmg/m","links"]
print(f"{'label':10} {'map':7} " + " ".join(f"{s:>7}" for s in short))
for label in sys.argv[1:]:
    for f in sorted(glob.glob(f"artifacts/bench/{label}/*.json")):
        d = json.load(open(f))["aggregate"]
        print(f"{label:10} {d['map'][:7]:7} " + " ".join(f"{d.get(k,0):>7}" for k in keys) + f"  seed={d['seed']} s={d['seconds']}")
