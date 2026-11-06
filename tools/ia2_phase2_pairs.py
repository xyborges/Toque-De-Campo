"""QA only: five alternating A/B pairs for one independent bot optimization."""
import argparse
import csv
import json
import pathlib
import statistics
import subprocess
import sys
import time

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "work" / "ia2-ganhos-baratos-fase2-20261106"

def gather(args, tag):
    cmd=[sys.executable,str(ROOT/"tools"/"ia2_cost_runner.py"),
        "--godot",str(args.godot),"--operation",args.operation,"--variant","on",
        "--feature",args.feature,"--feature-on",str(args.feature_on),
        "--seconds",str(args.seconds),"--warmup",str(args.warmup),"--tag",tag]
    started=time.time()
    p=subprocess.run(cmd,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,
                     encoding="utf-8",errors="replace",timeout=300)
    print(p.stdout[-1200:],flush=True)
    if p.returncode:
        raise RuntimeError("runner failed "+tag+" exit="+str(p.returncode))
    files=[f for f in OUT.glob("*"+tag+".json") if f.stat().st_mtime >= started-5
           and f.name.startswith("ia2p2-")]
    if len(files)!=1:
        raise RuntimeError("expected one JSON for "+tag+" found="+str(files))
    f=files[0]
    doc=json.loads(f.read_text(encoding="utf-8"))
    raw=doc["ia2_phase2"]
    expected = (str(args.feature_on)=="1")
    flag=(raw["los_enabled"] if args.feature=="los" else raw["traffic_query_enabled"])
    if flag != expected or doc["actual_bots"]!=28 or doc["focus"]["unfocused_frames"]!=0:
        raise RuntimeError("invalid flag, bots, focus: "+f.name)
    ticks={int(k):int(v) for k,v in doc["physics_ticks_per_frame"].items()}
    window=doc["measurement_window_unix_ms"]
    readings=[]
    gpufile=f.with_suffix(".gpu.csv")
    with gpufile.open(encoding="utf-8-sig",newline="") as source:
        for row in csv.DictReader(source):
            if window["start"]<=int(row["unix_ms"])<=window["end"]:
                readings.append(row)
    thermal=[r for r in readings if "Active" in (r.get("sw_thermal","")+","
              +r.get("hw_thermal","")).replace("Not Active","")]
    temps=[]
    for row in readings:
        try:temps.append(float(row["temp_c"]))
        except (ValueError,KeyError):pass
    return {
        "file":f.name,"operation":args.operation,"feature":args.feature,
        "feature_on":bool(expected),
        "fps":doc["frames"]["average_fps"],
        "p95":doc["frames"]["p95_ms"],"p99":doc["frames"]["p99_ms"],
        "physics_mean_ms":doc["physics_ms"]["mean_ms"],
        "gpu_mean_ms":doc["gpu_ms"]["mean_ms"],
        "over33_per_min":doc["over33_per_min"],
        "multi_ticks_ge2":sum(v for k,v in ticks.items() if k>=2),
        "multi_ticks_ge4":sum(v for k,v in ticks.items() if k>=4),
        "los_reused":raw["los_reused"],"los_fallback":raw["los_fallback"],
        "traffic_queries_reused":raw["traffic_queries_reused"],
        "gpu_thermal_samples":len(readings),"gpu_temp_min":min(temps) if temps else None,
        "gpu_temp_max":max(temps) if temps else None,
        "thermal_flags_available":bool(readings) and all(
            r.get("sw_thermal")!="UNAVAILABLE" for r in readings),
        "thermal_active":len(thermal)
    }

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot",type=pathlib.Path,required=True)
    parser.add_argument("--operation",choices=["afghan","favela"],required=True)
    parser.add_argument("--feature",choices=["los","traffic"],required=True)
    parser.add_argument("--pairs",type=int,default=5)
    parser.add_argument("--seconds",type=float,default=10)
    parser.add_argument("--warmup",type=float,default=5)
    args=parser.parse_args()
    if args.pairs<1 or args.pairs>10:raise SystemExit("pairs 1..10")
    OUT.mkdir(exist_ok=True,parents=True)
    results=[]
    path=OUT/f"pairs-{args.feature}-{args.operation}.json"
    for pair in range(1,args.pairs+1):
        order=[0,1] if pair%2==1 else [1,0]
        for ix,enabled in enumerate(order):
            args.feature_on=enabled
            tag=f"pair{pair:02d}-{'B' if enabled else 'A'}"
            print("START",args.feature,args.operation,tag,flush=True)
            row=gather(args,tag)
            row["pair"]=pair
            row["position"]=ix
            results.append(row)
            path.write_text(json.dumps({"status":"partial","records":results},
                        indent=2,ensure_ascii=False),encoding="utf-8")
            print("FINISHED",tag,"FPS",round(row["fps"],2),"P99",
                  round(row["p99"],2),"ticks>=4",row["multi_ticks_ge4"],flush=True)
    pair_rows=[]
    for n in range(1,args.pairs+1):
        base=next(r for r in results if r["pair"]==n and not r["feature_on"])
        trial=next(r for r in results if r["pair"]==n and r["feature_on"])
        pair_rows.append({"pair":n,
            "fps_change_percent":100*(trial["fps"]-base["fps"])/base["fps"],
            "p99_change_ms":trial["p99"]-base["p99"],
            "ticks_ge4_change":trial["multi_ticks_ge4"]-base["multi_ticks_ge4"],
            "over33_change":trial["over33_per_min"]-base["over33_per_min"]})
    base=[r["fps"] for r in results if not r["feature_on"]]
    noise=(max(base)-min(base))/statistics.mean(base)*100 if len(base)>1 else None
    fps_gains=[x["fps_change_percent"] for x in pair_rows]
    median_gain=statistics.median(fps_gains)
    p99_changes=[x["p99_change_ms"] for x in pair_rows]
    tick_changes=[x["ticks_ge4_change"] for x in pair_rows]
    evaluation={"baseline_range_noise_percent":noise,
        "median_gain_fps_percent":median_gain,
        "median_p99_change_ms":statistics.median(p99_changes),
        "median_ge4_tick_change":statistics.median(tick_changes),
        "minimum_pairs_for_acceptance":5,
        "performance_gate_candidate":(
            args.pairs>=5 and noise is not None and median_gain>noise and
            statistics.median(p99_changes)<0 and statistics.median(tick_changes)<0),
        "gameplay_multiplayer_gate":"NOT VERIFIED; cannot accept for production",
        "decision":"diagnostic only; no main integration"}
    path.write_text(json.dumps({"status":"complete","base_commit":"b4192f1",
        "feature":args.feature,"operation":args.operation,
        "measurement_seconds_per_run":args.seconds,"warmup":args.warmup,
        "order":"AB BA AB BA AB ...","records":results,"pair_deltas":pair_rows,
        "evaluation":evaluation},ensure_ascii=False,indent=2),encoding="utf-8")
    print("SUMMARY",json.dumps(evaluation,ensure_ascii=False),"FILE",path,flush=True)

if __name__=="__main__":
    main()
