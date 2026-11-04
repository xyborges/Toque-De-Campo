"""Local functional QA only: real headless authority plus two GL clients.

Does not publish, stop an existing game, use a real account or benchmark FPS.
The second client starts only after the first world has passed its snapshot.
"""
from datetime import datetime
from pathlib import Path
import json
import socket
import subprocess
import time

ROOT = Path(__file__).resolve().parents[1]
ENGINE = ROOT.parents[3] / "tools/Godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe"
PREFIX = "nova-grass-network-" + datetime.now().strftime("%Y%m%d-%H%M%S-%f")
WORK = ROOT / "work"
WORK.mkdir(exist_ok=True)
CERT = WORK / "security182/test.crt"
KEY = WORK / "security182/test.key"
if not ENGINE.is_file() or not CERT.is_file() or not KEY.is_file():
    raise SystemExit("Godot ou certificados de QA ausentes; não houve tentativa de conexão.")

# Share the benchmark lease: opening fails on Windows while the exclusive
# PowerShell benchmark is active, and its next exclusive open fails while
# this functional test holds the file. No simultaneous GPU test sessions.
try:
    lease = (WORK / "performance-benchmark.lock").open("a+b")
except OSError:
    raise SystemExit("Há uma medição ativa; teste de rede não iniciado.")

processes = []
failures = []
with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as reservation:
    reservation.bind(("127.0.0.1", 0))
    port = reservation.getsockname()[1]

def start(role):
    log_path = WORK / f"{PREFIX}-{role}.stdout.log"
    log = log_path.open("w", encoding="utf-8")
    display = ["--headless"] if role == "server" else [
        "--rendering-method", "gl_compatibility", "--screen", "0",
        "--resolution", "640x480", "--position", "0,30" if role == "first" else "660,30",
    ]
    command = [
        str(ENGINE), *display, "--max-fps", "30", "--path", str(ROOT),
        "--script", "res://tests/nova_grass_network.gd",
        "--log-file", str(WORK / f"{PREFIX}-{role}.log"), "--",
        "--naval-test-accounts", f"--role={role}", f"--qa-run={PREFIX}",
        f"--grass-port={port}", f"--naval-data={WORK / (PREFIX + '-' + role + '-data')}",
        f"--game-tls-cert={CERT}", f"--game-tls-key={KEY}", f"--game-tls-ca={CERT}",
    ]
    proc = subprocess.Popen(command, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT,
                            creationflags=subprocess.CREATE_NO_WINDOW)
    processes.append((role, proc, log, log_path))
    return proc

try:
    print("NOVA_GRASS_NETWORK_RUN", PREFIX, flush=True)
    server = start("server")
    time.sleep(.7)
    first = start("first")
    marker = WORK / f"{PREFIX}-first-ready.json"
    deadline = time.monotonic() + 220
    while not marker.exists() and time.monotonic() < deadline and server.poll() is None and first.poll() is None:
        time.sleep(.2)
    if not marker.exists():
        raise RuntimeError("Primeiro cliente não concluiu o mundo independente; ver logs desta série.")
    start("late")
    deadline = time.monotonic() + 260
    while time.monotonic() < deadline and any(p.poll() is None for _, p, _, _ in processes):
        time.sleep(.2)
    reports = {}
    for role, proc, log, log_path in processes:
        log.flush()
        report_path = WORK / f"{PREFIX}-{role}.json"
        report = json.loads(report_path.read_text(encoding="utf-8-sig")) if report_path.exists() else {"ok": False, "failures": ["missing report"]}
        reports[role] = report
        output = log_path.read_text(encoding="utf-8", errors="replace")
        errors = [line for line in output.splitlines() if line.startswith(("ERROR:", "SCRIPT ERROR:"))]
        warnings = [line for line in output.splitlines() if line.startswith("WARNING:")]
        report["engine_warnings"] = warnings
        if proc.poll() != 0 or not report.get("ok") or errors:
            failures.append({"role": role, "exit_code": proc.poll(), "failures": report.get("failures", []), "engine_errors": errors[:10]})
        print(f"{role}: {'PASS' if proc.poll() == 0 and report.get('ok') and not errors else 'FAIL'}; checks={report.get('checks', 0)}; cleanup={report.get('cleanup_ok', False)}; warnings={len(warnings)}", flush=True)
    summary = {"ok": not failures, "reports": reports, "failures": failures,
               "scope": "Functional local DTLS/graphical grass/late join/headless/cleanup only. Not a benchmark or publication approval."}
    (WORK / f"{PREFIX}-summary.json").write_text(json.dumps(summary, ensure_ascii=False, indent=2), encoding="utf-8")
    print("Sem publicação; resultado em work/" + PREFIX + "-summary.json", flush=True)
    if failures: raise SystemExit(1)
except Exception as exc:
    print("NOVA_GRASS_NETWORK_FAIL", str(exc), flush=True)
    raise SystemExit(1)
finally:
    for _, proc, log, _ in processes:
        if proc.poll() is None:
            proc.terminate()
            try: proc.wait(timeout=7)
            except subprocess.TimeoutExpired: proc.kill(); proc.wait(timeout=5)
        log.close()
    lease.close()
