#!/usr/bin/env python3
"""Run 1 Favela authority and 2 ENet clients; keep all output out of res://."""
import argparse
import json
import os
from pathlib import Path
import subprocess
import tempfile
import time

DEFAULT_GODOT = Path(r"C:\Users\Joao Borges\Documents\Codex\tools\Godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe")

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--project", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--godot", type=Path, default=DEFAULT_GODOT)
    parser.add_argument("--script", type=Path, default=Path(__file__).with_name("favela_network_qa.gd"))
    parser.add_argument("--seconds", type=float, default=145.0)
    args = parser.parse_args()
    output = Path(tempfile.mkdtemp(prefix="favela-enet-"))
    print("QA output:", output, flush=True)
    jobs = []
    try:
        for role in ("server","alpha","bravo"):
            report = output / (role + ".json")
            logpath = output / (role + ".log")
            environment = os.environ.copy()
            environment["FAVELA_NET_QA_DIR"] = str(output)
            environment["APPDATA"] = str(output / (role + "-appdata"))
            Path(environment["APPDATA"]).mkdir(parents=True, exist_ok=True)
            handle = logpath.open("w", encoding="utf-8")
            # Explicit QA-only DTLS materials; never use production credentials.
            # Existing test certificate is kept in the local main work/ sandbox.
            tls = args.project.parents[1] / "campo-cartunesco-godot" / "campo-cartunesco-godot" / "work" / "security182"
            if not tls.exists():
                tls = Path(r"C:\Users\Joao Borges\Documents\campo-cartunesco-godot\campo-cartunesco-godot\work\security182")
            cert, key = tls / "test.crt", tls / "test.key"
            if not cert.exists() or not key.exists():
                raise FileNotFoundError("Missing local QA DTLS certificate in "+str(tls))
            command = [str(args.godot), "--headless", "--max-fps", "60",
                       "--path", str(args.project), "--script", str(args.script),
                       "--", "--naval-test-accounts", f"--role={role}",
                       f"--naval-data={output / (role+'-data')}",
                       f"--game-tls-cert={cert}", f"--game-tls-key={key}",
                       f"--game-tls-ca={cert}"]
            proc = subprocess.Popen(command, env=environment, stdout=handle,
                                    stderr=subprocess.STDOUT,
                                    creationflags=getattr(subprocess,"CREATE_NO_WINDOW",0))
            jobs.append((role, proc, handle, report, logpath))
            time.sleep(1.0 if role=="server" else .6)
        deadline = time.monotonic() + args.seconds
        while time.monotonic() < deadline and any(p.poll() is None for _,p,_,_,_ in jobs):
            time.sleep(.35)
        errors = []
        for role, proc, handle, report, logpath in jobs:
            handle.flush()
            log = logpath.read_text(encoding="utf-8",errors="replace")
            data = json.loads(report.read_text(encoding="utf-8")) if report.exists() else {"failures":["no json report"]}
            print(role, "exit", proc.poll(), json.dumps(data,ensure_ascii=False),flush=True)
            significant = [line for line in log.splitlines() if line.startswith(("SCRIPT ERROR:","ERROR:"))]
            if significant: print("GODOT_ERRORS",role,significant[-8:],flush=True)
            if proc.poll()!=0 or data.get("failures") or significant:
                errors.append(role)
                print("LOGTAIL",role,log[-3600:],flush=True)
        if errors: raise RuntimeError("Favela ENet failed: "+", ".join(errors))
        print("FAVELA_ENET_PASS",flush=True)
    finally:
        for _,proc,handle,_,_ in jobs:
            if proc.poll() is None:
                proc.kill()
                proc.wait(timeout=10)
            handle.close()

if __name__=="__main__":
    main()
