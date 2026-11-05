"""Run the P1j local ENet/DTLS gate with two independent clients."""
import argparse
import json
import os
from pathlib import Path
import socket
import subprocess
import tempfile
import time


ROOT = Path(__file__).resolve().parents[1]
ROLES = ("server", "shooter", "victim")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--engine", required=True, type=Path)
    parser.add_argument("--cert", required=True, type=Path, help="QA certificate for localhost")
    parser.add_argument("--key", required=True, type=Path, help="QA certificate private key")
    args = parser.parse_args()
    for path in (args.engine, args.cert, args.key):
        if not path.is_file():
            parser.error(f"file not found: {path}")

    output = Path(tempfile.mkdtemp(prefix="true-fpp-p1j-"))
    print(f"Logs: {output}", flush=True)
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as udp:
        udp.bind(("127.0.0.1", 0))
        port = udp.getsockname()[1]

    processes = {}
    try:
        for role in ROLES:
            directory = output / role
            directory.mkdir()
            environment = os.environ.copy()
            environment["APPDATA"] = str(directory)
            command = [
                str(args.engine.resolve()), "--headless", "--path", str(ROOT),
                "--log-file", str(directory / "engine.log"),
                "--script", "res://tests/true_fpp_p1j_network_collision.gd", "--",
                "--naval-test-accounts", f"--naval-data={directory / 'data'}",
                f"--role={role}", f"--p1j-port={port}",
                f"--game-tls-cert={args.cert.resolve()}", f"--game-tls-key={args.key.resolve()}",
                f"--game-tls-ca={args.cert.resolve()}", "--game-tls-host=localhost",
            ]
            if role == "server":
                command.append("--true-fpp-p1g-collision")
            with (directory / "stdout.log").open("wb") as log:
                processes[role] = subprocess.Popen(
                    command, stdout=log, stderr=subprocess.STDOUT, env=environment,
                    creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0),
                )
            if role == "server":
                time.sleep(2)

        deadline = time.monotonic() + 155
        while time.monotonic() < deadline and all(
            process.poll() in (None, 0) for process in processes.values()
        ):
            if all(process.poll() == 0 for process in processes.values()):
                break
            time.sleep(0.2)
    finally:
        for process in processes.values():
            if process.poll() is None:
                process.kill()
            process.wait()

    passed = True
    for role, process in processes.items():
        log = (output / role / "stdout.log").read_text(encoding="utf-8", errors="replace")
        reports = [line.removeprefix("P1J_NETWORK ") for line in log.splitlines()
                   if line.startswith("P1J_NETWORK ")]
        report = json.loads(reports[0]) if len(reports) == 1 else {}
        role_passed = (
            process.returncode == 0
            and report.get("role") == role
            and report.get("pass") is True
            and "ERROR:" not in log
            and "Parse Error" not in log
        )
        print(f"{role}: {process.returncode}, {report}", flush=True)
        if not role_passed:
            print(log, flush=True)
        passed &= role_passed
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
