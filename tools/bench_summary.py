#!/usr/bin/env python3
"""Aggregate bench JSON files: tools/bench_summary.py artifacts/bench/<label> [out.json]"""
import json, sys, glob, os, statistics
src = sys.argv[1]
rows = [json.load(open(f))["aggregate"] for f in sorted(glob.glob(os.path.join(src, "*.json")))]
keys = ["combat_idle_ratio","combat_share","mean_speed","tech_per_bot_minute","jumps_per_bot_minute","outnumbered_ratio",
        "deaths_alone_ratio","damage_per_bot_minute","stuck_events","objective_share","deaths"]
summary = {}
for m in sorted({r["map"] for r in rows}):
    rs = [r for r in rows if r["map"] == m]
    summary[m] = {k: round(statistics.mean(r[k] for r in rs), 3) for k in keys}
    summary[m]["seeds"] = [r["seed"] for r in rs]
out = {"label": os.path.basename(src.rstrip("/")), "seconds": rows[0]["seconds"] if rows else 0, "maps": summary}
print(json.dumps(out, indent=1))
if len(sys.argv) > 2: json.dump(out, open(sys.argv[2], "w"), indent=1)
