"""Two-process DTLS/ENet regression for the authoritative RPG shot.

Run from any cwd:
  python tests/run_rpg_range_multiplayer.py
  python tests/run_rpg_range_multiplayer.py --engine path/to/godot

Requires local QA certificates at work/security182/{test.crt,test.key}.
No production network/credentials are used.
"""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "work" / "rpg-range-qa"
ENGINE_DEFAULT = Path("C:/Users/Joao Borges/Documents/Codex/tools/Godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--engine", default=os.environ.get("GODOT_BIN", str(ENGINE_DEFAULT)))
    parser.add_argument("--timeout", type=int, default=65)
    args = parser.parse_args()
    engine = shutil.which(args.engine) or args.engine
    if not Path(engine).is_file() and not shutil.which(engine):
        raise RuntimeError("Godot executable unavailable: " + engine)
    cert = ROOT / "work" / "security182" / "test.crt"
    key = ROOT / "work" / "security182" / "test.key"
    if not cert.is_file() or not key.is_file():
        raise RuntimeError("Local QA DTLS test.crt and test.key are required in work/security182")
    OUT.mkdir(parents=True, exist_ok=True)
    jobs = []
    try:
        for role in ("server", "client"):
            report = OUT / ("gameplay-" + role + ".json")
            report.unlink(missing_ok=True)
            profile = OUT / ("runner-" + role)
            profile.mkdir(parents=True, exist_ok=True)
            logfile = OUT / ("runner-" + role + ".stdout.log")
            log = logfile.open("w", encoding="utf-8")
            env = os.environ.copy()
            env["APPDATA"] = str(profile)
            cmd = [engine, "--headless", "--max-fps", "90", "--path", str(ROOT),
                   "--script", "res://tests/rpg_range_multiplayer_qa.gd",
                   "--", "--role=" + role, "--naval-test-accounts",
                   "--naval-data=" + str(profile / "data"),
                   "--game-tls-cert=" + str(cert), "--game-tls-key=" + str(key),
                   "--game-tls-ca=" + str(cert), "--game-tls-host=localhost"]
            proc = subprocess.Popen(cmd, stdout=log, stderr=subprocess.STDOUT,
                                    cwd=ROOT, env=env,
                                    creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0))
            jobs.append((role, proc, log, logfile, report))
            time.sleep(1.8)
        deadline = time.monotonic() + args.timeout
        while time.monotonic() < deadline and any(p.poll() is None for _, p, _, _, _ in jobs):
            time.sleep(0.25)
        results = {}
        problems = []
        for role, proc, log, logfile, report in jobs:
            log.flush()
            data = json.loads(report.read_text(encoding="utf-8")) if report.exists() else {}
            output = logfile.read_text(encoding="utf-8", errors="replace")
            results[role] = {"exit": proc.poll(), "report": data}
            expected_checks = 17 if role == "server" else 4
            if (proc.poll() != 0 or data.get("checks") != expected_checks
                    or data.get("failures") != [] or "SCRIPT ERROR:" in output
                    or "ERROR:" in output):
                problems.append(role)
                print("FAIL", role, "LOG:", output[-3500:], flush=True)
            else:
                print("PASS", role, f"{expected_checks}/{expected_checks}", flush=True)
        summary = {"ok": not problems, "roles": results,
                   "scope": "two Godot processes, ENet DTLS, native client gadget RPC, "
                            "server WarVehicles authority, replicated projectile_event, "
                            "RPG velocity parity at 100/200/400/600 metres"}
        (OUT / "multiplayer-gate.json").write_text(
            json.dumps(summary, indent=2, ensure_ascii=False), encoding="utf-8")
        print(json.dumps(summary, ensure_ascii=False), flush=True)
        return 1 if problems else 0
    finally:
        for _, proc, log, _, _ in jobs:
            if proc.poll() is None:
                proc.kill()
                proc.wait()
            log.close()


if __name__ == "__main__":
    sys.exit(main())
