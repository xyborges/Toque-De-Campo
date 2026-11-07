"""Compare 28-bot Favela baseline vs diagnostic-only physics-script pause.
No gameplay code changes, no push to main, no release. A/B B/A repeated.
"""
from pathlib import Path
import csv
import json
import os
import statistics
import subprocess
import threading
import time

ROOT=Path(__file__).resolve().parents[1]
ENGINE=Path(r"C:\Users\Joao Borges\Documents\Codex\tools\Godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe")
OUT=ROOT/"work"/"diag-physics-poses-20261107"
OUT.mkdir(parents=True,exist_ok=True)
(OUT/".gdignore").touch(exist_ok=True)
ALL=[]

def sensor(path,stop):
    with path.open("w",encoding="utf8",newline="") as f:
        writer=csv.writer(f)
        writer.writerow(["timestamp","temperature_c","util_gpu_pct","gpu_clock_mhz","thermal"])
        while not stop.wait(.8):
            try:
                r=subprocess.run(["nvidia-smi","--query-gpu=timestamp,temperature.gpu,utilization.gpu,clocks.current.graphics,clocks_event_reasons.sw_thermal_slowdown",
                    "--format=csv,noheader,nounits"],capture_output=True,text=True,timeout=8)
                if r.returncode==0 and r.stdout.strip():
                    values=[v.strip() for v in r.stdout.splitlines()[0].split(",")]
                    if len(values)>=5:writer.writerow(values[:5]);f.flush()
            except (OSError,subprocess.TimeoutExpired):
                continue

def one(pair,kind):
    label=f"favela28-physics-p{pair}-{kind}"
    dest=OUT/(label+".json")
    if dest.exists():raise RuntimeError("Will not overwrite raw "+str(dest))
    args=[str(ENGINE),"--rendering-method","forward_plus","--resolution","1920x1080","--max-fps","0",
        "--path",str(ROOT),"--script","res://tests/ia1_physics_pose_ab.gd","--",
        "--tag="+label,"--seconds=14","--disabled-bot-physics="+str(int(kind=="B"))]
    env=os.environ.copy()
    for key in ("TDC_IA2_REUSE_RESPAWN_WEAPON","TDC_IA2_RAGDOLL_STRICT_CAP","TDC_IA2_DEFER_REMOTE_RAGDOLL"):
        env.pop(key,None)
    stop=threading.Event()
    gpu=OUT/(label+".gpu.csv")
    thread=threading.Thread(target=sensor,args=(gpu,stop),daemon=True)
    thread.start()
    print("START",label,flush=True)
    try:
        with (OUT/(label+".stdout.log")).open("w",encoding="utf8") as log:
            result=subprocess.run(args,cwd=ROOT,env=env,stdout=log,stderr=subprocess.STDOUT,timeout=195)
    finally:
        stop.set()
        thread.join(timeout=12)
    payload=json.loads(dest.read_text(encoding="utf8")) if dest.exists() else {"valid":False,"failures":["no_report"]}
    with gpu.open("r",encoding="utf8",newline="") as f:rows=list(csv.DictReader(f))
    temps=[float(x["temperature_c"]) for x in rows if x["temperature_c"]]
    slow=sum(x["thermal"].strip().lower() in ("active","1") for x in rows)
    entry={"label":label,"pair":pair,"variant":kind,"valid":result.returncode==0 and payload.get("valid") is True,
        "fps":payload.get("fps"),"p99_ms":payload.get("frame",{}).get("p99_ms"),
        "physics_mean_ms":payload.get("physics",{}).get("mean_ms"),
        "multi_ticks":payload.get("multi_ticks"),"total_frames":payload.get("total_frames"),
        "movement":payload.get("movement_solver",{}),"travel_sum_m":payload.get("travel_sum_m"),
        "gpu_temp_max":max(temps) if temps else None,"gpu_samples":len(rows),
        "thermal_slowdown_samples":slow,"failures":payload.get("failures",[]),"exit":result.returncode}
    ALL.append(entry)
    (OUT/"summary.json").write_text(json.dumps({"records":ALL},indent=2),encoding="utf8")
    print("DONE",label,"valid",entry["valid"],"fps",entry["fps"],"p99",entry["p99_ms"],
        "physics",entry["physics_mean_ms"],"moves",entry["movement"].get("moves"),
        "travel",entry["travel_sum_m"],"gpu_c",entry["gpu_temp_max"],"slow",slow,flush=True)
    if not entry["valid"]:
        print("ERROR_LOG",(OUT/(label+".stdout.log")).read_text(encoding="utf8",errors="replace")[-3200:],flush=True)
        raise RuntimeError("Invalid measurement "+label)
    return entry

if __name__=="__main__":
    for n in range(1,6):
        for variant in (("A","B") if n%2 else ("B","A")):
            one(n,variant)
            time.sleep(3)
    for variant in ("A","B"):
        records=[r for r in ALL if r["variant"]==variant]
        print("AVERAGES",variant,"fps",statistics.mean(r["fps"] for r in records),
            "p99",statistics.mean(r["p99_ms"] for r in records),
            "physics",statistics.mean(r["physics_mean_ms"] for r in records),
            "multitick_fraction",statistics.mean(r["multi_ticks"]/r["total_frames"] for r in records),flush=True)
    print("COMPLETE_5_PAIRS",flush=True)
