"""Read-only gameplay probe: offline headless authority (not ENet) and entry timings.
Never touch production servers, game code, saved preferences or main.
"""
import argparse
import csv
from datetime import datetime
import hashlib
import json
import pathlib
import subprocess
import threading
import time
import os
import platform

ROOT=pathlib.Path(__file__).resolve().parent.parent
OUT=ROOT/"work"/"ia2-diagnostico-entrada-v25-20261106"
QUERY=("timestamp,name,temperature.gpu,utilization.gpu,clocks.sm,power.draw,"
       "clocks_throttle_reasons.active,clocks_throttle_reasons.sw_thermal_slowdown,"
       "clocks_throttle_reasons.hw_thermal_slowdown")
HEADER=["unix_ms","gpu_timestamp","gpu_name","temp_c","util_pct","sm_clock_mhz",
        "power_w","throttle_active","sw_thermal","hw_thermal"]
def gpu_rows(stop,path):
    with path.open("w",encoding="utf-8",newline="") as f:
        writer=csv.writer(f)
        writer.writerow(HEADER);f.flush()
        while not stop.is_set():
            try:
                cp=subprocess.run(["nvidia-smi","--query-gpu="+QUERY,
                    "--format=csv,noheader,nounits"],capture_output=True,
                    text=True,timeout=5,creationflags=getattr(subprocess,"CREATE_NO_WINDOW",0))
                if cp.returncode==0:
                    row=next(csv.reader([cp.stdout.strip().splitlines()[0]]))
                    if len(row)==9:writer.writerow([int(time.time()*1000),*map(str.strip,row)]);f.flush()
            except (OSError,ValueError,subprocess.TimeoutExpired,IndexError):
                pass
            stop.wait(1.0)

def running_godot():
    result=subprocess.run(["tasklist","/fo","csv","/nh"],capture_output=True,
                          text=True,timeout=15)
    return [row for row in csv.reader(result.stdout.splitlines())
            if row and "godot" in row[0].lower()]

def run(godot,label,operation,bots,duration,warmup):
    jobs=running_godot()
    if jobs:raise RuntimeError("Godot concorrente: "+str(jobs[:5]))
    OUT.mkdir(exist_ok=True,parents=True)
    output=OUT/(label+".json")
    output.unlink(missing_ok=True)
    log=OUT/(label+".log")
    gpu=OUT/(label+".gpu.csv")
    stop=threading.Event()
    watcher=threading.Thread(target=gpu_rows,args=(stop,gpu),daemon=True)
    command=[str(godot),"--headless","--max-fps","60","--path",str(ROOT),
        "--script","res://tests/ia2_authority_entry_probe.gd","--",
        "--ia2-profile-bots","--operation="+operation,"--bots="+str(bots),
        "--duration="+str(duration),"--warmup="+str(warmup),"--label="+label]
    print("RUN",label,"map",operation,"bots",bots,flush=True)
    watcher.start()
    t0=time.monotonic()
    try:
        with log.open("w",encoding="utf-8") as out:
            proc=subprocess.run(command,cwd=ROOT,stdout=out,stderr=subprocess.STDOUT,
                                timeout=duration+240)
        rc=proc.returncode
    finally:
        stop.set();watcher.join(timeout=6)
    if rc!=0 or not output.is_file():
        print("FAIL",label,"return",rc,flush=True)
        print(log.read_text(encoding="utf-8",errors="replace")[-1800:],flush=True)
        raise RuntimeError("QA failed "+label)
    data=json.loads(output.read_text(encoding="utf-8"))
    n=int(data["population_min"])
    measured=float(data["measurement"]["duration_seconds"])
    if n!=bots or abs(measured-duration)>4 or data["expected_bots"]!=bots:
        raise RuntimeError("invalid population/duration "+label)
    metrics=data["measurement"]
    info={"case":label,"seconds":round(measured,2),"bots":n,
        "entry_to_ready_ms":round(data["entry"]["root_add_to_join_ready_ms"],1),
        "world_ms":round(data["entry"]["world_build_ms"],1),
        "entry_to_bots_ms":round(data["entry"]["root_add_to_bots_ready_ms"],1),
        "tick_rate":round(metrics["physics_ticks_per_real_second"],2),
        "frame_p99_ms":round(metrics["frame_interval_ms"]["p99_ms"],2),
        "physics_monitor_p99_ms":round(metrics["physics_monitor_ms"]["p99_ms"],2),
        "over100":metrics["over100_frames"],
        "frames_ge4_ticks":metrics["ticks_ge4_frames"],
        "sha256":hashlib.sha256(output.read_bytes()).hexdigest()}
    print("SUCCESS",json.dumps(info,ensure_ascii=False),flush=True)
    return info

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--godot",type=pathlib.Path,required=True)
    ap.add_argument("--operation",choices=("favela","afghan"),default="favela")
    ap.add_argument("--bots",type=int,choices=(0,28),default=28)
    ap.add_argument("--duration",type=int,default=120)
    ap.add_argument("--warmup",type=int,default=8)
    ap.add_argument("--tag",default="warm")
    args=ap.parse_args()
    if not args.godot.is_file():raise SystemExit("Godot unavailable")
    host=platform.node()
    label=f"headless-{args.operation}-{args.bots}bots-{args.tag}-{datetime.now():%Y%m%d-%H%M%S}"
    entry=run(args.godot,label,args.operation,args.bots,args.duration,args.warmup)
    summary=OUT/"sessions.jsonl"
    with summary.open("a",encoding="utf-8") as f:f.write(json.dumps(entry,ensure_ascii=False)+"\n")
    print("SESSION_LOG",summary,flush=True)

if __name__=="__main__":main()
