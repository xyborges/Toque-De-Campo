"""Isolated Fase 1 A/B runner: 28 bots, Forward+, 1080p, GPU telemetry."""
import argparse
import csv
import datetime
import json
from pathlib import Path
import shutil
import subprocess
import threading
import time

ROOT=Path(__file__).resolve().parent.parent
OUT=ROOT/"work"/"ia2-custo-corpo-20261106"
QUERY="timestamp,name,temperature.gpu,utilization.gpu,clocks.sm,power.draw,clocks_throttle_reasons.active"
FALLBACK="timestamp,name,temperature.gpu,utilization.gpu,clocks.sm,power.draw"

def gpu_row():
    exe=shutil.which("nvidia-smi")
    if not exe:return None
    for fields in (QUERY,FALLBACK):
        try:
            p=subprocess.run([exe,"--query-gpu="+fields,"--format=csv,noheader,nounits"],
                capture_output=True,text=True,errors="replace",timeout=5)
            if p.returncode==0 and p.stdout.strip():
                row=next(csv.reader(p.stdout.strip().splitlines()))
                return [int(time.time()*1000),*[s.strip() for s in row[:6]],
                        row[6].strip() if fields==QUERY else "UNAVAILABLE"]
        except (OSError,subprocess.TimeoutExpired,csv.Error,IndexError):
            continue
    return None

def gpu_monitor(stop,path):
    with path.open("w",newline="",encoding="utf-8") as f:
        w=csv.writer(f)
        w.writerow(["unix_ms","gpu_timestamp","name","temp_c","gpu_util_pct",
                    "sm_clock_mhz","power_w","throttle_active"])
        while not stop.is_set():
            row=gpu_row()
            if row:w.writerow(row);f.flush()
            stop.wait(1)

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--godot",required=True,type=Path)
    ap.add_argument("--operation",choices=["afghan","favela"],required=True)
    ap.add_argument("--variant",choices=["on","off"],required=True)
    ap.add_argument("--seconds",type=float,default=20)
    ap.add_argument("--warmup",type=float,default=8)
    ap.add_argument("--tag",default="smoke")
    a=ap.parse_args()
    if not a.godot.is_file():raise SystemExit("Godot não localizado")
    rows=subprocess.run(["tasklist","/fo","csv","/nh"],capture_output=True,
        text=True,errors="replace",timeout=15).stdout
    if any(row.lower().startswith('"godot') for row in rows.splitlines()):
        raise SystemExit("Godot concorrente detectado: coleta não iniciada")
    OUT.mkdir(parents=True,exist_ok=True)
    label="ia2-%s-%s-%s-%s"%(datetime.datetime.now().strftime("%Y%m%d-%H%M%S"),
            a.operation,a.variant,a.tag)
    logfile=OUT/(label+".log")
    gpu=OUT/(label+".gpu.csv")
    raw=ROOT/"work"/"benchmark-results"/(label+".json")
    cmd=[str(a.godot),"--path",str(ROOT),"--rendering-method","forward_plus",
         "--resolution","1920x1080","--script","res://tests/ia2_cost_benchmark.gd",
         "--","--operation="+a.operation,"--warmup="+str(a.warmup),
         "--duration="+str(a.seconds),"--label="+label,"--ia2-profile-bots"]
    if a.variant=="off":cmd.append("--ia2-brain-off")
    stopper=threading.Event()
    watcher=threading.Thread(target=gpu_monitor,args=(stopper,gpu),daemon=True)
    watcher.start()
    print("RUN",label,flush=True)
    try:
        with logfile.open("w",encoding="utf-8") as out:
            code=subprocess.run(cmd,cwd=ROOT,stdout=out,stderr=subprocess.STDOUT,
                                timeout=250).returncode
    except subprocess.TimeoutExpired:
        print("TIMEOUT",label,flush=True);return 2
    finally:
        stopper.set()
        watcher.join(timeout=7)
    if code!=0 or not raw.exists():
        print("INVALID",label,"exit",code,
              logfile.read_text(encoding="utf-8",errors="replace")[-2500:],flush=True)
        return 2
    data=json.loads(raw.read_text(encoding="utf-8"))
    target=OUT/(label+".json")
    shutil.copyfile(raw,target)
    focus=data.get("focus",{})
    bots=data.get("bot_population",{})
    valid=data.get("renderer")=="forward_plus"
    valid=valid and data.get("actual_bots")==28 and data.get("actual_bots_end")==28
    valid=valid and bots.get("minimum")==28 and focus.get("unfocused_frames")==0
    valid=valid and data.get("render_texture")==[1920,1080]
    valid=valid and data.get("ia2_phase1",{}).get("profiling",{}).get("enabled")
    print("RESULT",json.dumps({"label":label,"valid":bool(valid),"fps":data["frames"]["average_fps"],
        "p99":data["frames"]["p99_ms"],"physics_ms":data["physics_ms"]["mean_ms"],
        "gpu_ms":data["gpu_ms"]["mean_ms"],"unfocused":focus.get("unfocused_frames"),
        "bots":bots.get("minimum"),"renderer":data.get("renderer"),
        "data":str(target)},ensure_ascii=False),flush=True)
    return 0 if valid else 3

if __name__=="__main__":raise SystemExit(main())
