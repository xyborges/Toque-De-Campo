"""Paired exploratory QA ablations, with raw data and explicit validity checks."""
from __future__ import annotations
import argparse
import csv
import hashlib
import json
import re
import subprocess
import sys
import threading
import time
from pathlib import Path
import run_benchmark as official

ROOT = Path(__file__).resolve().parents[2]
CONTROLS = ["no-monitoring", "no-hitbox-space", "no-presentation", "no-bot-contact", "steps-2", "steps-3"]

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--controls", default=",".join(CONTROLS))
    parser.add_argument("--pairs", type=int, default=2)
    parser.add_argument("--pair-offset", type=int, default=0)
    parser.add_argument("--duration", type=float, default=30)
    parser.add_argument("--godot")
    parser.add_argument("--prefix", default="perf-audit")
    args = parser.parse_args()
    controls = args.controls.split(",")
    if any(c not in CONTROLS + ["baseline"] for c in controls) or args.pairs < 1:
        parser.error("invalid control or pair count")
    if args.pair_offset < 0 or not re.fullmatch(r"[A-Za-z0-9_-]{1,48}", args.prefix):
        parser.error("invalid pair offset or output prefix")
    if not 10 <= args.duration <= 120:
        parser.error("duration must be 10..120 seconds")
    engine = official.find_godot(args.godot)
    schedule = []
    for pair in range(args.pair_offset, args.pair_offset + args.pairs):
        for control in controls:
            order = ["baseline", control] if pair % 2 == 0 else [control, "baseline"]
            for side, variant in enumerate(order):
                schedule.append((f"{args.prefix}-{control}-p{pair+1}-{side}", variant, pair, control))
    files = []
    for label, *_ in schedule:
        files += [f"work/benchmark-results/{label}.json", f"work/perf-audit/{label}.log", f"work/perf-audit/{label}.gpu.csv", f"work/perf-audit/{label}.gpu-window.csv"]
    files += [f"work/perf-audit/{args.prefix}-aggregate.json"]
    coord = [sys.executable, "tools/ai_coord.py"]
    started = subprocess.run(coord + ["start", "--agent", "codex-perf-controls-runner", "--task", args.prefix] + files, cwd=ROOT, text=True, capture_output=True, check=True)
    sid = started.stdout.split("SESSAO ")[1].splitlines()[0]
    print(started.stdout, flush=True)
    destination = ROOT / "work/perf-audit"
    destination.mkdir(parents=True, exist_ok=True)
    source = {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest() for folder in ("scripts", "modes/war/scripts", "tests/benchmark") for p in (ROOT/folder).rglob("*.gd")}
    records = []
    try:
        subprocess.run(coord + ["check", sid], cwd=ROOT, check=True)
        for label, control, pair, contrast in schedule:
            if official.competing_godot_processes():
                raise RuntimeError("Another Godot is running; no process was terminated")
            output = ROOT / f"work/benchmark-results/{label}.json"
            if output.exists():
                raise RuntimeError(f"Refusing stale output: {output.name}")
            stop = threading.Event()
            collector = threading.Thread(target=official.gpu_collector, args=(stop, destination/f"{label}.gpu.csv"))
            collector.start()
            command = [str(engine), "--path", str(ROOT), "--resolution", "1920x1080", "--position", "0,0", "--script", "res://tests/benchmark/war_perf_controls.gd", "--", "--operation=favela", f"--duration={args.duration}", "--warmup=8", f"--label={label}", f"--control={control}", "--naval-data=" + str(destination/"profile")]
            print("START", label, control, flush=True)
            try:
                with (destination/f"{label}.log").open("w", encoding="utf-8") as log:
                    process = subprocess.Popen(command, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT, creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0))
                    interference = False
                    deadline = time.monotonic() + args.duration + 240
                    while process.poll() is None:
                        if time.monotonic() > deadline:
                            subprocess.run(["taskkill", "/PID", str(process.pid), "/T", "/F"], capture_output=True)
                            process.wait(timeout=30)
                            raise TimeoutError(label)
                        # Windows console + GUI child are two processes for one run.
                        if len(official.competing_godot_processes()) > 2:
                            interference = True
                        time.sleep(1)
                    code = process.returncode
            finally:
                stop.set()
                collector.join(timeout=15)
            runtime = (destination/f"{label}.log").read_text(encoding="utf-8", errors="replace")
            data = json.loads(output.read_text(encoding="utf-8")) if output.exists() else {}
            problems = []
            if code != 0: problems.append(f"exit {code}")
            if "SCRIPT ERROR:" in runtime or "\nERROR:" in runtime: problems.append("engine error")
            if not data.get("valid"): problems.append("fixture invalid")
            if data.get("focus", {}).get("unfocused_frames", 1): problems.append("lost focus")
            if data.get("bot_population", {}).get("minimum") != 28: problems.append("population")
            if data.get("renderer") != "forward_plus": problems.append("renderer")
            if interference: problems.append("competing Godot during measurement")
            if data.get("controlled_areas", 0) != 448 and control in ("no-monitoring", "no-hitbox-space"): problems.append("expected 28 x 16 hit regions")
            if control == "no-bot-contact" and data.get("directed_contact_exceptions") != 756: problems.append("expected 28 x 27 contact exceptions")
            gpu_window = destination/f"{label}.gpu-window.csv"
            gpu = official.select_gpu_measurement_rows(destination/f"{label}.gpu.csv", gpu_window, data)
            integrity = official.collection_integrity(data, args, gpu)
            problems += integrity["failed_checks"]
            gpu.pop("window_file", None)
            telemetry = list(csv.DictReader(gpu_window.open(encoding="utf-8"))) if gpu_window.exists() else []
            if any(hashlib.sha256((ROOT/path).read_bytes()).hexdigest() != digest for path, digest in source.items()):
                problems.append("source changed during batch")
            trace_seconds = sum(data.get("frame_time_trace_ms", [])) / 1000
            engine_ticks = sum(int(k) * int(v) for k, v in data.get("physics_ticks_per_frame", {}).items())
            engine_ratio = engine_ticks / data.get("physics_hz", 60) / trace_seconds if trace_seconds else None
            record = {"engine_simulation_wall_ratio": engine_ratio, "gpu_integrity": gpu, "integrity": integrity, "gpu_window_rows": telemetry, "label": label, "control": control, "pair": pair, "contrast": contrast, "problems": problems, "data": data}
            records.append(record)
            (destination/f"{args.prefix}-aggregate.json").write_text(json.dumps({"base_sha": official.command_output(["git", "rev-parse", "HEAD"]), "source_sha256": source, "duration": args.duration, "pairs": args.pairs, "records": records, "approval": "exploratory only; not a production performance gate", "cpu_temperature": None, "limitation": "CPU temperature unavailable; native hitbox ablations change combat; no remote clients"}, ensure_ascii=False, indent=2), encoding="utf-8")
            print(json.dumps({"label":label, "problems":problems, "frames":data.get("frames"), "physics":data.get("physics_ms"), "simulation_ratio":data.get("simulation_wall_ratio")}), flush=True)
            # A malformed fixture stops the batch; focus loss is retained as invalid evidence.
            if not data or code != 0 or "engine error" in problems:
                raise RuntimeError(f"Invalid fixture: {label}; inspect its log")
        subprocess.run(coord + ["checkpoint", sid, "--confirm-own-changes", "--note", "Raw exploratory measurements reviewed; invalid samples explicitly marked"], cwd=ROOT, check=True)
        subprocess.run(coord + ["finish", sid, "--notes", "Paired rendered ablations completed; see aggregate problems for invalid samples. Not gameplay approval."], cwd=ROOT, check=True)
    except BaseException:
        subprocess.run(coord + ["abort", sid, "--notes", "Batch interrupted; partial raw output retained; inspect logs, no gameplay promotion"], cwd=ROOT)
        raise

if __name__ == "__main__":
    main()
