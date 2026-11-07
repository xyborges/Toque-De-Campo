"""Five alternating A/B 28-bot Favela runs with window-focus and GPU thermal gates."""
from pathlib import Path
import csv
import json
import os
import statistics
import subprocess
import time
import threading

ROOT=Path(__file__).resolve().parents[1]
EXE=Path(r"C:\Users\Joao Borges\Documents\Codex\tools\Godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe")
RESULTS=ROOT/"work"/"ia2-qa-20261107"
GAME_RESULTS=ROOT/"work"/"ia2-real-28-bots-20261106"
RESULTS.mkdir(parents=True,exist_ok=True)
GAME_RESULTS.mkdir(parents=True,exist_ok=True)
(RESULTS/".gdignore").touch(exist_ok=True)
(GAME_RESULTS/".gdignore").touch(exist_ok=True)  # Skip import of raw GPU CSVs.
RUNS=[]
def temperature_sampler(path,stop):
    with path.open("w",encoding="utf8",newline="") as f:
        f.write("timestamp,temperature.gpu,utilization.gpu,clocks.sm,clocks_event_reasons.sw_thermal_slowdown\n")
        f.flush()
        while not stop.is_set():
            result=subprocess.run(["nvidia-smi","--query-gpu=timestamp,temperature.gpu,utilization.gpu,clocks.sm,clocks_event_reasons.sw_thermal_slowdown","--format=csv,noheader"],
                capture_output=True,text=True,timeout=10)
            if result.returncode==0 and result.stdout.strip():
                f.write(result.stdout.strip()+"\n")
                f.flush()
            stop.wait(1)
def gpu_stats(path):
    with path.open(newline="",encoding="utf8") as f: rows=list(csv.DictReader(f))
    temp=[float(r["temperature.gpu"].strip()) for r in rows if r.get("temperature.gpu","").strip()]
    slow=sum(r.get("clocks_event_reasons.sw_thermal_slowdown","").strip().lower()=="active" for r in rows)
    return {"temperature_max_c":max(temp) if temp else None,"temperature_mean_c":statistics.mean(temp) if temp else None,"thermal_slowdown_samples":slow,"samples":len(rows)}
def test_run(pair,variant):
    label=f"favela-cap-qa7-p{pair}-{variant}"
    result_file=GAME_RESULTS/(label+".json")
    assert not result_file.exists(),"Must not overwrite a previous raw measurement: "+label
    env=os.environ.copy()
    env.pop("TDC_IA2_REUSE_RESPAWN_WEAPON",None)
    env.pop("TDC_IA2_DEFER_REMOTE_RAGDOLL",None)
    env.pop("TDC_IA2_RAGDOLL_STRICT_CAP",None)
    args=[str(EXE),"--rendering-method","forward_plus","--resolution","1920x1080","--max-fps","0",
        "--path",str(ROOT),"--script","res://tests/ia2_qa_real_war_benchmark.gd","--",
        "--mode=cap","--optimized="+("0" if variant=="a" else "1"),"--map=favela","--duration=14",
        "--tag="+label]
    stop=threading.Event()
    gpu=RESULTS/(label+".gpu.csv")
    thread=threading.Thread(target=temperature_sampler,args=(gpu,stop))
    thread.start()
    try:
        with (RESULTS/(label+".stdout.log")).open("w",encoding="utf8") as out:
            proc=subprocess.run(args,cwd=ROOT,stdout=out,stderr=subprocess.STDOUT,env=env,timeout=200)
    finally:
        stop.set()
        thread.join(timeout=12)
    report=json.loads(result_file.read_text(encoding="utf8")) if result_file.exists() else {"valid":False,"failures":["no report"]}
    tele=gpu_stats(gpu)
    validity=proc.returncode==0 and report.get("valid")==True and report.get("unfocused_frames")==0 and report.get("bots")==28
    entry={"pair":pair,"variant":variant,"label":label,"exit":proc.returncode,"valid":validity,
        "fps":report.get("fps"),"p99_ms":report.get("frame",{}).get("p99_ms"),
        "multi_ticks":report.get("frames_multi_tick"),"total_frames":report.get("total_frames"),
        "max_ragdolls":report.get("max_ragdolls"),"callbacks":report.get("event_callbacks_ms"),
        "gpu":tele,"failures":report.get("failures",[])}
    RUNS.append(entry)
    print("RUN",label,"PASS" if validity else "INVALID","FPS",entry["fps"],"P99",entry["p99_ms"],"TEMP",tele["temperature_max_c"],"THERMAL",tele["thermal_slowdown_samples"],flush=True)
    (RESULTS/"favela-five-pairs-summary.json").write_text(json.dumps({"runs":RUNS},indent=2),encoding="utf8")
    if not validity:
        print("RUN_LOG_TAIL",(RESULTS/(label+".stdout.log")).read_text(encoding="utf8",errors="replace")[-2100:],flush=True)
    return validity
if __name__=="__main__":
    for pair in range(1,6):
        order=("a","b") if pair%2 else ("b","a")
        for variant in order:
            if not test_run(pair,variant):raise SystemExit(2)
            time.sleep(3)
    for variant in ("a","b"):
        items=[r for r in RUNS if r["variant"]==variant]
        print("AVERAGES",variant,"fps",statistics.mean(x["fps"] for x in items),"p99",statistics.mean(x["p99_ms"] for x in items),flush=True)
    print("QA_FAVELA_FIVE_PAIRS_COMPLETE",flush=True)
