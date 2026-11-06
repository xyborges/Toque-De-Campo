#!/usr/bin/env python3
"""Benchmark de Guerra portatil, com verificacao de integridade da coleta."""
from __future__ import annotations

import argparse
import csv
from datetime import datetime
import json
import math
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
PROTOCOL = "war-1080p-28-bots-focus-gpu-v2"
GPU_FIELDS = ["name", "temperature.gpu", "utilization.gpu",
              "clocks.sm", "power.draw", "pstate"]
GPU_CSV_FIELDS = ["sample_unix_ms", "query_duration_ms", "gpu_index"] + GPU_FIELDS


def command_output(command: list[str], timeout: int = 10) -> str:
    try:
        result = subprocess.run(
            command, cwd=ROOT, capture_output=True, text=True,
            errors="replace", timeout=timeout, check=False
        )
        return result.stdout.strip() if result.returncode == 0 else ""
    except (OSError, subprocess.TimeoutExpired):
        return ""


def find_godot(explicit: str | None) -> Path:
    paths = [explicit, os.getenv("GODOT_BIN"), os.getenv("GODOT_PATH")]
    paths += [shutil.which(name) for name in
              ("godot", "godot4", "Godot", "godot.exe", "godot4.exe")]
    tools = Path.home() / "Documents" / "Codex" / "tools"
    if tools.exists():
        paths += [str(f) for f in sorted(tools.glob("Godot-*/*_console.exe"),
                                         reverse=True)]
        paths += [str(f) for f in sorted(tools.glob("Godot-*/*.exe"),
                                         reverse=True)
                  if "console" not in f.name.lower()]
    for candidate in paths:
        if candidate and Path(candidate).is_file():
            return Path(candidate).resolve()
    raise FileNotFoundError(
        "Godot nao localizado. Use --godot CAMINHO ou defina GODOT_BIN."
    )



def competing_godot_processes() -> list[dict]:
    """Identifica processos Godot ANTES de abrir o jogo, sem matar nada."""
    if os.name == "nt":
        output = command_output(["tasklist", "/fo", "csv", "/nh"], timeout=15)
        if not output:
            raise RuntimeError("nao foi possivel listar processos com tasklist")
        entries = csv.reader(output.splitlines())
        result = []
        for row in entries:
            if len(row) < 2 or not row[0].lower().startswith("godot"):
                continue
            result.append({"image": row[0], "pid": row[1]})
        return result
    output = command_output(["ps", "-eo", "comm=,pid="], timeout=15)
    if not output:
        raise RuntimeError("nao foi possivel listar processos com ps")
    result = []
    for line in output.splitlines():
        chunks = line.strip().rsplit(maxsplit=1)
        if len(chunks) == 2 and "godot" in chunks[0].lower():
            result.append({"image": chunks[0], "pid": chunks[1]})
    return result


def gpu_collector(stop: threading.Event, destination: Path) -> None:
    """Cada amostra usa relogio UTC da maquina, como Time do Godot.

    A janela de medicao e informada pelo proprio Godot, entao o tempo de
    importacao/carregamento nao contamina a estatistica da GPU.
    """
    smi = shutil.which("nvidia-smi")
    if not smi:
        return
    with destination.open("w", newline="", encoding="utf-8") as file:
        writer = csv.DictWriter(file, fieldnames=GPU_CSV_FIELDS)
        writer.writeheader()
        while not stop.is_set():
            query_start = time.time_ns()
            try:
                result = subprocess.run(
                    [smi, "--query-gpu=" + ",".join(GPU_FIELDS),
                     "--format=csv,noheader"],
                    capture_output=True, text=True, errors="replace",
                    timeout=4, check=False
                )
                query_end = time.time_ns()
                if result.returncode == 0:
                    for gpu_index, row in enumerate(csv.reader(result.stdout.splitlines())):
                        if len(row) != len(GPU_FIELDS):
                            continue
                        values = dict(zip(GPU_FIELDS, [v.strip() for v in row]))
                        writer.writerow({
                            "sample_unix_ms": (query_start + query_end) // 2_000_000,
                            "query_duration_ms": round(
                                (query_end - query_start) / 1_000_000, 2),
                            "gpu_index": gpu_index,
                            **values
                        })
                    file.flush()
            except (OSError, subprocess.TimeoutExpired):
                pass
            stop.wait(1.0)


def select_gpu_measurement_rows(
    source: Path, destination: Path, raw: dict
) -> dict:
    """Recorta o CSV, sem alterar o log integral ou inventar amostras.

    Exige correspondencia do nome da GPU quando ha varias placas.
    """
    window = raw.get("measurement_window_unix_ms", {})
    start = int(window.get("start", 0))
    end = int(window.get("end", 0))
    status = {
        "available": source.is_file(), "window_start_unix_ms": start,
        "window_end_unix_ms": end, "total_samples": 0,
        "window_samples": 0, "matching_gpu": False,
        "gpu_name": raw.get("gpu_name", ""),
        "window_file": None, "window_span_covered": False,
        "window_max_gap_ms": None,
    }
    if not source.is_file():
        return status
    with source.open(newline="", encoding="utf-8") as file:
        rows = list(csv.DictReader(file))
    status["total_samples"] = len(rows)
    if not rows or start <= 0 or end <= start:
        return status
    target = str(raw.get("gpu_name", "")).lower().strip()
    matches = [row for row in rows
               if str(row.get("name", "")).lower().strip() == target]
    status["matching_gpu"] = bool(matches)
    if not matches:
        return status
    measured = [row for row in matches
                if start <= int(row["sample_unix_ms"]) <= end]
    status["window_samples"] = len(measured)
    if measured:
        stamps = sorted(int(row["sample_unix_ms"]) for row in measured)
        max_gap = max((b - a for a, b in zip(stamps, stamps[1:])), default=0)
        status["window_max_gap_ms"] = max_gap
        status["window_span_covered"] = (
            stamps[0] <= start + 3000 and stamps[-1] >= end - 3000
            and max_gap <= 4000
        )
    # Preserve the original UTC timestamps and actual nvidia-smi output.
    with destination.open("w", newline="", encoding="utf-8") as file:
        writer = csv.DictWriter(file, fieldnames=GPU_CSV_FIELDS)
        writer.writeheader()
        writer.writerows(measured)
    status["window_file"] = str(destination)
    if measured:
        status["first_sample_unix_ms"] = int(measured[0]["sample_unix_ms"])
        status["last_sample_unix_ms"] = int(measured[-1]["sample_unix_ms"])
    return status


def collection_integrity(report: dict, args, gpu: dict) -> dict:
    """Uma coleta com foco perdido nao pode ser chamada de FPS reprovado."""
    duration = int(args.duration)
    frames = report.get("frames", {})
    focus = report.get("focus", {})
    population = report.get("bot_population", {})
    window = report.get("measurement_window_unix_ms", {})
    trace = report.get("frame_time_trace_ms", [])
    total = int(focus.get("total_frames", 0))
    focused = int(focus.get("focused_frames", -1))
    unfocused = int(focus.get("unfocused_frames", -1))
    start = int(window.get("start", 0))
    end = int(window.get("end", 0))
    gpu_name = str(report.get("gpu_name", "")).lower()
    nvidia = "nvidia" in gpu_name
    try:
        numeric_trace = [float(v) for v in trace]
        trace_good = bool(numeric_trace) and all(
            math.isfinite(ms) and ms > 0 for ms in numeric_trace)
    except (TypeError, ValueError):
        trace_good = False
        numeric_trace = []
    raw_avg_ms = sum(numeric_trace) / len(numeric_trace) if trace_good else 0
    reported_avg_ms = float(frames.get("mean_ms", -1))
    expected_gpu_samples = max(2, duration // 2) if nvidia else 0
    checks = {
        "metadata_v2": report.get("collection_protocol") == PROTOCOL,
        "full_window": start > 0 and end > start and
                       duration * 900 <= end - start <= duration * 1150 + 2000,
        "focus_all_frames": total > 0 and focused == total and unfocused == 0
                            and focus.get("start_focused") is True
                            and int(focus.get("transitions", -1)) == 0,
        "population_28_stable": population.get("minimum") == 28 and
                                population.get("at_end") == 28 and
                                int(population.get("samples", 0)) >= max(2, duration // 2),
        "uncapped_vsync_off": report.get("actual_vsync") == 0 and
                              report.get("actual_fps_cap") == 0,
        "real_simulation": report.get("qa_presentation_only") is False and
                           report.get("qa_frozen_scene") is False,
        "raw_frames_complete": trace_good and
                               len(numeric_trace) == int(frames.get("samples", 0)) and
                               len(numeric_trace) >= duration * 10 and
                               abs(raw_avg_ms - reported_avg_ms) < .001 and
                               len(numeric_trace) == total and
                               abs(sum(numeric_trace) - (end - start)) <= max(1000, .05 * (end - start)),
        "gpu_window_synchronized": (not nvidia) or
            (bool(gpu.get("matching_gpu")) and
             int(gpu.get("window_samples", 0)) >= expected_gpu_samples
             and bool(gpu.get("window_span_covered"))),
    }
    return {
        "valid": all(checks.values()), "checks": checks,
        "failed_checks": [name for name, okay in checks.items() if not okay],
        "focus_percentage": round(100 * focused / max(1, total), 3),
        "nvidia_samples_expected": expected_gpu_samples,
        "window_duration_ms": end - start,
    }


def limits_report(report: dict, config: dict, operation: str, renderer: str) -> dict:
    """Mantem o gate numerico independente da qualidade da coleta."""
    targets = config["acceptance_targets"]
    frames = report.get("frames", {})
    checks = {
        "valid_fixture": report.get("valid") is True,
        "correct_operation": report.get("operation") == operation,
        "correct_renderer": report.get("renderer") == renderer,
        "28_deployed_bots": report.get("actual_bots") == 28,
        "full_1080p": report.get("render_texture") == [1920, 1080],
        "scale_100_percent": abs(float(report.get("internal_scale", 0)) - 1) < .001,
        "average_fps": float(frames.get("average_fps", 0)) >= targets["average_fps_min"],
        "median_fps": float(report.get("median_fps", 0)) >= targets["median_fps_min"],
        "one_percent_low_fps": float(frames.get("one_percent_low_fps", 0))
                                >= targets["one_percent_low_fps_min"],
        "p95_ms": float(frames.get("p95_ms", 1e9)) <= targets["frame_p95_ms_max"],
        "p99_ms": float(frames.get("p99_ms", 1e9)) <= targets["frame_p99_ms_max"],
        "over_50_ms_per_min": float(report.get("over50_per_min", 1e9))
                              <= targets["over_50_ms_per_min_max"],
        "over_100_ms_count": int(report.get("over100_count", 999999))
                             <= targets["over_100_ms_count_max"],
        "enough_samples": int(frames.get("samples", 0)) >= 100,
    }
    return {
        "passed": all(checks.values()), "checks": checks,
        "failed_checks": [key for key, okay in checks.items() if not okay]
    }


def main() -> int:
    defaults = json.loads(CONFIG_FILE.read_text(encoding="utf-8"))
    scenario = defaults["scenario"]
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", help="Caminho do executavel Godot ou GODOT_BIN")
    parser.add_argument("--operation", choices=["favela", "afghan", "ukraine"],
                        default=scenario["default_operation"])
    parser.add_argument("--renderer", choices=["forward_plus", "gl_compatibility"],
                        default=scenario["default_renderer"])
    parser.add_argument("--warmup", type=int, default=scenario["warmup_seconds"])
    parser.add_argument("--duration", type=int, default=scenario["duration_seconds"])
    parser.add_argument("--tag", default="", help="Identificador livre para este teste")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--allow-fail", action="store_true",
                        help="Ignora somente reprovacao de FPS, nao coleta invalida")
    args = parser.parse_args()

    if not 4 <= args.warmup <= 30 or not 10 <= args.duration <= 120:
        parser.error("warmup: 4-30 s; duration: 10-120 s")
    try:
        godot = find_godot(args.godot)
    except FileNotFoundError as error:
        parser.error(str(error))
    if not (ROOT / "project.godot").is_file() or not (ROOT / FIXTURE).is_file():
        parser.error("Execute usando um clone completo do projeto Godot")

    hostname = re.sub(r"[^a-zA-Z0-9-]+", "-", platform.node())[:35] or "host"
    tag = re.sub(r"[^a-zA-Z0-9-]+", "-", args.tag)[:40]
    run_id = "-".join(filter(None, (
        datetime.now().strftime("%Y%m%d-%H%M%S-%f"), hostname, args.operation,
        args.renderer, tag
    )))
    command = [
        str(godot), "--path", str(ROOT), "--rendering-method", args.renderer,
        "--resolution", "1920x1080", "--script", FIXTURE, "--",
        "--operation=" + args.operation, "--warmup=" + str(args.warmup),
        "--duration=" + str(args.duration), "--label=" + run_id,
    ]
    print("Godot:", godot, flush=True)
    print("Comando:", subprocess.list2cmdline(command), flush=True)
    print("Cenario: 1080p/Medio/100%, 28 bots, VSync off, FPS uncapped",
          flush=True)
    if args.dry_run:
        return 0

    try:
        competing = competing_godot_processes()
    except RuntimeError as error:
        print(f"ERRO: preflight de processos indisponivel: {error}",
              file=sys.stderr)
        return 5
    if competing:
        print("ERRO: existem outros processos Godot no computador.", file=sys.stderr)
        print("Feche os editores, testes e servidores locais antes da coleta:",
              competing, file=sys.stderr)
        return 5

    OUTPUT.mkdir(parents=True, exist_ok=True)
    log_path = OUTPUT / (run_id + ".log")
    raw_path = OUTPUT / (run_id + ".json")
    summary_path = OUTPUT / (run_id + ".summary.json")
    gpu_path = OUTPUT / (run_id + ".gpu.csv")
    gpu_window_path = OUTPUT / (run_id + ".gpu-measurement.csv")
    stop = threading.Event()
    watcher = threading.Thread(target=gpu_collector, args=(stop, gpu_path),
                               daemon=True)
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
                print("ERRO: Godot excedeu 240s; log:", log_path, file=sys.stderr)
                return 2
    finally:
        stop.set()
        watcher.join(timeout=5)

    try:
        competing_after = competing_godot_processes()
    except RuntimeError:
        competing_after = [{"image": "UNVERIFIED", "pid": "?"}]

    if code != 0:
        print(f"ERRO: Godot retornou {code}. Log: {log_path}", file=sys.stderr)
        return 2
    if not raw_path.is_file():
        print(f"ERRO: relatorio ausente: {raw_path}", file=sys.stderr)
        return 2

    try:
        report = json.loads(raw_path.read_text(encoding="utf-8"))
        gpu = select_gpu_measurement_rows(gpu_path, gpu_window_path, report)
        integrity = collection_integrity(report, args, gpu)
        integrity["checks"]["no_concurrent_godot_after"] = not competing_after
        integrity["valid"] = all(integrity["checks"].values())
        integrity["failed_checks"] = [
            key for key, good in integrity["checks"].items() if not good
        ]
        performance = limits_report(report, defaults, args.operation, args.renderer)
    except (OSError, ValueError, TypeError, KeyError) as error:
        print(f"ERRO: relatorio invalido: {error}", file=sys.stderr)
        return 2

    official = (args.duration == scenario["duration_seconds"] and
                args.warmup == scenario["warmup_seconds"] and
                args.renderer == scenario["default_renderer"] and
                args.operation == scenario["default_operation"])
    if not integrity["valid"]:
        status = "COLETA_INVALIDA"
    elif not official:
        status = "DIAGNOSTICO_APROVADO" if performance["passed"] else "DIAGNOSTICO_REPROVADO"
    else:
        status = "APROVADO" if performance["passed"] else "REPROVADO"

    summary = {
        "benchmark_version": "2.0", "collection_protocol": PROTOCOL,
        "run_id": run_id, "git_sha": git_sha, "git_worktree_dirty": git_dirty,
        "godot_version": engine_version, "godot_executable": str(godot),
        "system": {
            "machine": platform.node(), "os": platform.platform(),
            "cpu": platform.processor()
        },
        "scenario": {
            "operation": args.operation, "renderer": args.renderer,
            "duration_seconds": args.duration, "warmup_seconds": args.warmup,
            "resolution": [1920, 1080], "bots": 28, "preset": "Medio"
        },
        "official_profile": official,
        "elapsed_seconds": round(time.monotonic() - started, 2),
        "engine_gpu": report.get("gpu_name"),
        "reference_hardware": defaults["reference_hardware"],
        "measurement_window_unix_ms": report.get("measurement_window_unix_ms"),
        "focus": report.get("focus"),
        "bot_population": report.get("bot_population"),
        "gpu_collection": gpu,
        "concurrent_godot_after": competing_after,
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
        "integrity": integrity, "evaluation": performance, "status": status,
        "files": {
            "raw": str(raw_path), "log": str(log_path),
            "nvidia_all": str(gpu_path) if gpu_path.exists() else None,
            "nvidia_measurement": gpu["window_file"]
        }
    }
    summary_path.write_text(json.dumps(summary, ensure_ascii=False, indent=2),
                            encoding="utf-8")

    print(f"\nGTX 1650 GATE: {status}", flush=True)
    for name, value in summary["metrics"].items():
        print(f"  {name}: {value}", flush=True)
    print(f"Foco: {integrity['focus_percentage']}%", flush=True)
    print(f"GPU samples: {gpu['window_samples']} dentro de janela", flush=True)
    if integrity["failed_checks"]:
        print("COLETA INVALIDA:", ", ".join(integrity["failed_checks"]), flush=True)
    if performance["failed_checks"]:
        print("METAS NAO ATENDIDAS:", ", ".join(performance["failed_checks"]),
              flush=True)
    print("Resumo:", summary_path, flush=True)
    if not integrity["valid"]:
        return 4
    if not performance["passed"] and not args.allow_fail:
        return 3
    return 0


if __name__ == "__main__":
    sys.exit(main())
