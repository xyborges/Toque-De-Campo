#!/usr/bin/env python3
"""Portable Godot 1080p/28-bot performance benchmark; runs without changing game files."""
from __future__ import annotations

import argparse
import csv
from datetime import datetime
import json
import os
from pathlib import Path
import platform
import re
import shutil
import subprocess
import sys
import threading
import time

ROOT = Path(__file__).resolve().parents[2]
CONFIG_FILE = Path(__file__).with_name("benchmark_config.json")
FIXTURE = "tests/benchmark/war_1080p_benchmark.gd"
OUTPUT = ROOT / "work" / "benchmark-results"


def command_output(command: list[str], timeout: int = 10) -> str:
    try:
        process = subprocess.run(
            command, cwd=ROOT, capture_output=True, text=True,
            errors="replace", timeout=timeout, check=False
        )
        return process.stdout.strip() if process.returncode == 0 else ""
    except (OSError, subprocess.TimeoutExpired):
        return ""


def find_godot(explicit: str | None) -> Path:
    paths = [explicit, os.getenv("GODOT_BIN"), os.getenv("GODOT_PATH")]
    paths += [shutil.which(name) for name in
              ("godot", "godot4", "Godot", "godot.exe", "godot4.exe")]
    # Optional home-relative fallback for the original development machine.
    tools = Path.home() / "Documents" / "Codex" / "tools"
    if tools.exists():
        paths += [str(file) for file in sorted(
            tools.glob("Godot-*/*_console.exe"), reverse=True
        )]
        paths += [str(file) for file in sorted(
            tools.glob("Godot-*/*.exe"), reverse=True
        ) if "console" not in file.name.lower()]
    for candidate in paths:
        if candidate and Path(candidate).is_file():
            return Path(candidate).resolve()
    raise FileNotFoundError(
        "Godot nao localizado. Use --godot CAMINHO ou defina GODOT_BIN."
    )


def gpu_collector(stop: threading.Event, destination: Path) -> None:
    smi = shutil.which("nvidia-smi")
    if not smi:
        return
    fields = "timestamp,temperature.gpu,utilization.gpu,clocks.sm,power.draw,pstate"
    with destination.open("w", newline="", encoding="utf-8") as file:
        writer = csv.writer(file)
        writer.writerow(fields.split(","))
        while not stop.is_set():
            try:
                proc = subprocess.run(
                    [smi, "--query-gpu=" + fields, "--format=csv,noheader"],
                    capture_output=True, text=True, errors="replace", timeout=4
                )
                if proc.returncode == 0 and proc.stdout.strip():
                    writer.writerow(next(csv.reader(proc.stdout.splitlines())))
                    file.flush()
            except (OSError, subprocess.TimeoutExpired, StopIteration):
                pass
            stop.wait(1.0)


def limits_report(report: dict, config: dict, operation: str, renderer: str) -> dict:
    targets = config["acceptance_targets"]
    frames = report.get("frames", {})
    checks = {
        "valid_fixture": report.get("valid") is True,
        "correct_operation": report.get("operation") == operation,
        "correct_renderer": report.get("renderer") == renderer,
        "28_deployed_bots": report.get("actual_bots") == 28,
        "full_1080p": report.get("render_texture") == [1920, 1080],
        "scale_100_percent": abs(float(report.get("internal_scale", 0)) - 1) < 0.001,
        "average_fps": float(frames.get("average_fps", 0)) >= targets["average_fps_min"],
        "median_fps": float(report.get("median_fps", 0)) >= targets["median_fps_min"],
        "one_percent_low_fps": (
            float(frames.get("one_percent_low_fps", 0))
            >= targets["one_percent_low_fps_min"]
        ),
        "p95_ms": float(frames.get("p95_ms", 1e9)) <= targets["frame_p95_ms_max"],
        "p99_ms": float(frames.get("p99_ms", 1e9)) <= targets["frame_p99_ms_max"],
        "over_50_ms_per_min": (
            float(report.get("over50_per_min", 1e9))
            <= targets["over_50_ms_per_min_max"]
        ),
        "over_100_ms_count": (
            int(report.get("over100_count", 999999))
            <= targets["over_100_ms_count_max"]
        ),
        "enough_samples": int(frames.get("samples", 0)) >= 100,
    }
    return {"passed": all(checks.values()), "checks": checks,
            "failed_checks": [key for key, okay in checks.items() if not okay]}


def main() -> int:
    defaults = json.loads(CONFIG_FILE.read_text(encoding="utf-8"))
    scenario = defaults["scenario"]
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", help="Caminho do executavel Godot (ou GODOT_BIN)")
    parser.add_argument("--operation", choices=["favela", "afghan", "ukraine"],
                        default=scenario["default_operation"])
    parser.add_argument("--renderer", choices=["forward_plus", "gl_compatibility"],
                        default=scenario["default_renderer"])
    parser.add_argument("--warmup", type=int, default=scenario["warmup_seconds"])
    parser.add_argument("--duration", type=int, default=scenario["duration_seconds"])
    parser.add_argument("--tag", default="", help="Identificador livre para este teste")
    parser.add_argument("--dry-run", action="store_true", help="Mostrar comando, nao rodar")
    parser.add_argument("--allow-fail", action="store_true",
                        help="Nao usar status de performance como exit code")
    args = parser.parse_args()

    if not 4 <= args.warmup <= 30 or not 10 <= args.duration <= 120:
        parser.error("warmup precisa estar entre 4-30 s; duration entre 10-120 s")
    try:
        godot = find_godot(args.godot)
    except FileNotFoundError as exc:
        parser.error(str(exc))
    if not (ROOT / "project.godot").is_file() or not (ROOT / FIXTURE).is_file():
        parser.error("Execute usando um clone completo do projeto Godot")

    host = re.sub(r"[^a-zA-Z0-9-]+", "-", platform.node())[:35] or "host"
    tag = re.sub(r"[^a-zA-Z0-9-]+", "-", args.tag)[:40]
    run_id = "-".join(filter(None, (
        datetime.now().strftime("%Y%m%d-%H%M%S"), host, args.operation,
        args.renderer, tag
    )))
    command = [
        str(godot), "--path", str(ROOT),
        "--rendering-method", args.renderer,
        "--resolution", "1920x1080",
        "--script", FIXTURE, "--",
        "--operation=" + args.operation,
        "--warmup=" + str(args.warmup),
        "--duration=" + str(args.duration),
        "--label=" + run_id
    ]
    print("Godot:", godot, flush=True)
    print("Comando:", subprocess.list2cmdline(command), flush=True)
    print("Cenario: 1080p/Medio/100%, 28 bots, VSync off, FPS uncapped",
          flush=True)
    if args.dry_run:
        return 0

    OUTPUT.mkdir(parents=True, exist_ok=True)
    log_path = OUTPUT / (run_id + ".log")
    raw_path = OUTPUT / (run_id + ".json")
    summary_path = OUTPUT / (run_id + ".summary.json")
    gpu_path = OUTPUT / (run_id + ".gpu.csv")
    stop = threading.Event()
    watcher = threading.Thread(
        target=gpu_collector, args=(stop, gpu_path), daemon=True
    )
    engine_version = command_output([str(godot), "--version"])
    git_sha = command_output(["git", "rev-parse", "HEAD"])
    git_dirty = bool(command_output(["git", "status", "--porcelain"]))
    print("Log:", log_path, flush=True)
    started = time.monotonic()
    watcher.start()
    try:
        with log_path.open("w", encoding="utf-8") as log:
            proc = subprocess.Popen(
                command, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT
            )
            try:
                code = proc.wait(timeout=240)
            except subprocess.TimeoutExpired:
                proc.kill()
                proc.wait()
                print("ERRO: Godot excedeu 240s; verifique o log.", file=sys.stderr)
                return 2
    finally:
        stop.set()
        watcher.join(timeout=5)

    if code != 0:
        print(f"ERRO: Godot retornou {code}. Log: {log_path}", file=sys.stderr)
        return 2
    if not raw_path.is_file():
        print(f"ERRO: relatorio ausente: {raw_path}", file=sys.stderr)
        return 2

    try:
        report = json.loads(raw_path.read_text(encoding="utf-8"))
        evaluation = limits_report(report, defaults, args.operation, args.renderer)
    except (OSError, ValueError, TypeError, KeyError) as exc:
        print(f"ERRO: relatorio invalido: {exc}", file=sys.stderr)
        return 2

    summary = {
        "benchmark_version": "1.0",
        "run_id": run_id,
        "git_sha": git_sha,
        "git_worktree_dirty": git_dirty,
        "godot_version": engine_version,
        "godot_executable": str(godot),
        "system": {
            "machine": platform.node(),
            "os": platform.platform(),
            "cpu": platform.processor()
        },
        "scenario": {
            "operation": args.operation, "renderer": args.renderer,
            "duration_seconds": args.duration, "warmup_seconds": args.warmup,
            "resolution": [1920, 1080], "bots": 28, "preset": "Medio"
        },
        "elapsed_seconds": round(time.monotonic() - started, 2),
        "engine_gpu": report.get("gpu_name"),
        "reference_hardware": defaults["reference_hardware"],
        "metrics": {
            "average_fps": report["frames"].get("average_fps"),
            "median_fps": report.get("median_fps"),
            "one_percent_low_fps": report["frames"].get("one_percent_low_fps"),
            "frame_p95_ms": report["frames"].get("p95_ms"),
            "frame_p99_ms": report["frames"].get("p99_ms"),
            "over_50_ms_per_min": report.get("over50_per_min"),
            "over_100_ms_count": report.get("over100_count"),
            "bots": report.get("actual_bots"),
            "gpu_ms_mean": report.get("gpu_ms", {}).get("mean_ms"),
            "physics_ms_mean": report.get("physics_ms", {}).get("mean_ms")
        },
        "evaluation": evaluation,
        "files": {
            "raw": str(raw_path), "log": str(log_path),
            "nvidia": str(gpu_path) if gpu_path.exists() else None
        }
    }
    summary_path.write_text(json.dumps(summary, indent=2, ensure_ascii=False),
                            encoding="utf-8")
    status = "APROVADO" if evaluation["passed"] else "REPROVADO"
    print(f"\nGTX 1650 REFERENCE GATE: {status}", flush=True)
    for name, value in summary["metrics"].items():
        print(f"  {name}: {value}", flush=True)
    if evaluation["failed_checks"]:
        print("Falhou:", ", ".join(evaluation["failed_checks"]), flush=True)
    print("Resumo:", summary_path, flush=True)
    if not evaluation["passed"] and not args.allow_fail:
        return 3
    return 0


if __name__ == "__main__":
    sys.exit(main())
