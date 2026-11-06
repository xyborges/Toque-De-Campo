"""Run paired headless CPU trials. A/A must pass before an A/B can pass."""
import argparse
from hashlib import sha256
import json
import math
import os
import platform
from pathlib import Path
from statistics import median, mean
import subprocess
from export_true_fpp_p1k_qa import benchmark_sources, file_hash

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--engine", type=Path, required=True)
parser.add_argument("--output", type=Path, required=True)
parser.add_argument("--mode", choices=("aa", "ab"), required=True)
parser.add_argument("--control", type=Path)
parser.add_argument("--pairs", type=int, default=5)
parser.add_argument("--samples", type=int, default=600)
parser.add_argument("--warmup", type=int, default=120)
parser.add_argument("--pace-usec", type=int, default=0, help="Equal wall-clock tick pacing outside the measurement")
parser.add_argument("--affinity", type=lambda value: int(value, 0), default=0, help="Optional CPU mask, e.g. 0x4")
parser.add_argument("--exported", action="store_true", help="Run a Windows QA package whose main scene is the P1k benchmark")
args = parser.parse_args()
if args.pairs < 1 or args.samples < 60 or args.warmup < 0 or args.pace_usec < 0 or args.affinity < 0:
    parser.error("Use at least one pair, 60 samples and nonnegative warmup")
args.output = args.output.resolve()
args.output.mkdir(parents=True, exist_ok=False)
root = Path(__file__).resolve().parents[1]
fixture = "tests/true_fpp_p1k_paired_cost.gd"
files = sorted({fixture, "tests/war_optics_fixture.gd", "project.godot",
                "tests/run_true_fpp_p1k_paired_cost.py"} |
               {str(path.relative_to(root)).replace("\\", "/")
                for directory in ("scripts", "modes") for path in (root / directory).rglob("*.gd")})
if args.exported:
    files.extend(["tests/export_true_fpp_p1k_qa.py", "export_presets.cfg"])
engine = args.engine.resolve()
if os.name == "nt" and engine.name.endswith("_console.exe"):
    # Launch the engine itself so a timeout also stops its physics process.
    engine = engine.with_name(engine.name.removesuffix("_console.exe") + ".exe")
host = {"platform": platform.platform(), "processor": platform.processor()}

def hashes():
    result = {name: file_hash(root / name) for name in files}
    if args.exported:
        result.update({name: sha256(data).hexdigest() for name, data in benchmark_sources().items()})
    return result

source_hashes = hashes()
engine_hash = file_hash(engine)
pack = engine.with_suffix(".pck") if args.exported else None
pack_hash = file_hash(pack) if pack else None
if args.exported:
    manifest = json.loads((engine.parent / "p1k_export.json").read_text(encoding="utf-8"))
    required_hashes = dict(manifest["fixtures_sha256"], **manifest["gameplay_sha256"])
    required_hashes.update({"project.godot": manifest["project_sha256"],
                            "export_presets.cfg": manifest["export_presets_sha256"]})
    if (manifest["exe_sha256"] != engine_hash or manifest["pack_sha256"] != pack_hash or
            any(source_hashes.get(name) != digest for name, digest in required_hashes.items())):
        raise RuntimeError("Export contents or source hashes changed; build the P1k QA package again")
parameters = {"samples": args.samples, "warmup": args.warmup,
              "pace_usec": args.pace_usec, "affinity": args.affinity,
              "exported": args.exported, "pack_sha256": pack_hash}

def set_affinity(process):
    if not args.affinity:
        return
    if os.name == "nt":
        import ctypes
        from ctypes import wintypes
        kernel = ctypes.WinDLL("kernel32", use_last_error=True)
        kernel.SetProcessAffinityMask.argtypes = [wintypes.HANDLE, ctypes.c_size_t]
        kernel.SetProcessAffinityMask.restype = wintypes.BOOL
        if not kernel.SetProcessAffinityMask(process._handle, args.affinity):
            raise ctypes.WinError(ctypes.get_last_error())
    else:
        os.sched_setaffinity(process.pid, {i for i in range(args.affinity.bit_length()) if args.affinity & (1 << i)})

def run_trial(pair, arm):
    folder = args.output / f"{pair}-{arm}"
    folder.mkdir(exist_ok=True)
    env = dict(os.environ, APPDATA=str(folder), XDG_DATA_HOME=str(folder))
    pilot = args.mode == "ab" and arm == "B"
    if pack and file_hash(pack) != pack_hash:
        raise RuntimeError("Exported PCK changed between trials")
    command = [str(engine), "--headless", "--fixed-fps", "60", "--log-file", str(folder / "engine.log")]
    if not args.exported:
        command += ["--path", str(root), "--script", f"res://{fixture}"]
    command += ["--", f"--samples={args.samples}", f"--warmup={args.warmup}",
               f"--pace-usec={args.pace_usec}", "--naval-test-accounts",
               f"--naval-data={folder / 'data'}"]
    if pilot:
        command.append("--pilot")
    with (folder / "stdout.log").open("wb") as log:
        result = subprocess.Popen(command, cwd=engine.parent if args.exported else root,
                                  env=env, stdout=log, stderr=subprocess.STDOUT,
                                  creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0))
        try:
            set_affinity(result)
            result.wait(timeout=120 + (args.samples + args.warmup)*args.pace_usec/1_000_000)
        finally:
            if result.poll() is None:
                result.kill()
            result.wait()
    log = (folder / "stdout.log").read_text(encoding="utf-8", errors="replace")
    if args.exported and "P1K_EXPORT_ENTRY release=true qa=true" not in log.splitlines():
        raise RuntimeError(f"Export did not enter the release QA scene; see {folder/'stdout.log'}")
    reports = [json.loads(line.removeprefix("P1K_COST ")) for line in log.splitlines() if line.startswith("P1K_COST ")]
    if result.returncode or "ERROR:" in log or len(reports) != 1:
        details = {key: value for key, value in reports[0].items() if key != "raw_ms"} if reports else {}
        raise RuntimeError(f"Invalid trial {pair}/{arm}, exit={result.returncode}, {details}; see {folder/'stdout.log'}")
    trial = reports[0]
    if not trial["pass"] or trial["pilot"] != pilot or hashes() != source_hashes:
        raise RuntimeError(f"Authority/workload/source validation failed on trial {pair}/{arm}")
    values = sorted(trial["raw_ms"])
    if len(values) != args.samples or any(not math.isfinite(value) or value <= 0 for value in values):
        raise RuntimeError("Incorrect sample count or nonpositive measurement")
    trial["metrics_ms"] = {key: values[int((len(values)-1)*quantile)]
                           for key, quantile in (("p50", .5), ("p95", .95), ("p99", .99))}
    trial["metrics_ms"]["mean"] = mean(values)
    trial.update(pair=pair, arm=arm)
    print(f"{pair}/{arm}: {trial['metrics_ms']} solve={trial['solved']} shared={trial['shared']} fallback={trial['fallback']}", flush=True)
    return trial

trials = []
deltas = []
for index in range(args.pairs):
    group = {}
    for arm in ("A", "B") if index % 2 == 0 else ("B", "A"):
        group[arm] = run_trial(index, arm)
        trials.append(group[arm])
    if any(group["A"][key] != group["B"][key] for key in ("state_sha256", "visual_updates")):
        raise RuntimeError(f"Different logical state or scheduled visual work in pair {index}")
    deltas.append({key: 100*(group["B"]["metrics_ms"][key]/a-1) for key, a in group["A"]["metrics_ms"].items()})

medians = {key: median(row[key] for row in deltas) for key in deltas[0]}
noise = {key: max(abs(row[key]) for row in deltas) for key in ("p50", "p99")}
valid_control = False
if args.control:
    control = json.loads(args.control.read_text(encoding="utf-8"))
    valid_control = (control["mode"] == "aa" and control["pairs"] >= 5 and control["parameters"] == parameters
                     and control["source_sha256"] == source_hashes and control["engine_sha256"] == engine_hash
                     and control["host"] == host
                     and all(value <= 5 for value in control["max_absolute_delta_pct"].values()))
budget_ok = medians["p50"] <= 0 and medians["p99"] <= 5
passed = args.mode == "ab" and args.pairs >= 5 and budget_ok and valid_control
status = "pass_cpu_fixture" if passed else "inconclusive_control"
if args.mode == "ab" and not budget_ok:
    status = "regression_observed"
elif args.mode == "aa" and args.pairs >= 5 and all(value <= 5 for value in noise.values()):
    status = "pass_control"
summary = {"mode": args.mode, "status": status, "median_delta_pct": medians, "max_absolute_delta_pct": noise,
           "control_valid": valid_control, "pairs": args.pairs, "parameters": parameters,
           "source_sha256": source_hashes, "engine_sha256": engine_hash, "host": host}
(args.output / "results.json").write_text(json.dumps(dict(summary, trials=trials, paired_delta_pct=deltas), indent=2),
                                          encoding="utf-8")
print(json.dumps({key: summary[key] for key in ("mode", "status", "median_delta_pct", "max_absolute_delta_pct", "control_valid")}), flush=True)
raise SystemExit(0 if status in ("pass_control", "pass_cpu_fixture") else 1)
