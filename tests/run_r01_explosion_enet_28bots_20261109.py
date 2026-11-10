#!/usr/bin/env python3
"""R01: actual 28-bot WarGame DTLS/ENet explosion audio QA.
Each peer has independent isolated APPDATA and QA port. No game deployment.
"""
from __future__ import annotations

import json
import os
from pathlib import Path
import socket
import subprocess
import time
import sys

ROOT = Path(__file__).resolve().parents[1]
MAP = os.environ.get("R01_AUDIO_QA_MAP","ukraine").lower()
assert MAP in ("ukraine","favela","afghan"), f"unsupported map: {MAP}"
OUT = ROOT / "work" / f"r01-explosion-enet-20261109-{MAP}"
GODOT = Path.home() / "Documents/Codex/2026-11-06/fa-a/work/Godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe"
CERTS = Path.home() / "Documents/Codex/2026-11-06/fa-a/work/Toque-De-Campo-ia2-architecture-cache/work/security182"

def run():
    assert GODOT.is_file(), f"Godot binary missing: {GODOT}"
    assert (CERTS / "test.crt").is_file(), "QA DTLS certificate missing"
    assert (CERTS / "test.key").is_file(), "QA DTLS key missing"
    OUT.mkdir(parents=True,exist_ok=True)
    for name in ("server.json","client.json"):
        (OUT/name).unlink(missing_ok=True)
    with socket.socket(socket.AF_INET,socket.SOCK_DGRAM) as sock:
        sock.bind(("127.0.0.1",0))
        port=sock.getsockname()[1]
    jobs=[]
    try:
        for role in ("server","client"):
            env=os.environ.copy()
            env["APPDATA"]=str(OUT / f"{role}-appdata")
            (OUT / f"{role}-appdata").mkdir(exist_ok=True)
            command=[str(GODOT)]
            if role=="server":command+=["--headless"]
            else:command+=["--resolution","1920x1080","--position","0,0"]
            command+=["--path",str(ROOT),"--script","res://tests/r01_explosion_enet_28bots_20261109.gd",
                "--","--naval-test-accounts",f"--role={role}",f"--war-port={port}",f"--war-map={MAP}",
                f"--naval-data={OUT/(role+'-data')}",
                f"--game-tls-cert={CERTS/'test.crt'}",f"--game-tls-key={CERTS/'test.key'}",
                f"--game-tls-ca={CERTS/'test.crt'}","--game-tls-host=localhost"]
            output=(OUT/f"{role}.stdout.log").open("w",encoding="utf8")
            process=subprocess.Popen(command,cwd=ROOT,env=env,stdout=output,stderr=subprocess.STDOUT,
                creationflags=getattr(subprocess,"CREATE_NO_WINDOW",0))
            jobs.append((role,process,output))
            print("R01_ENET_START",role,"port",port,"pid",process.pid,flush=True)
            time.sleep(1.5 if role=="server" else 0.1)
        deadline=time.monotonic()+600
        seen=0
        while time.monotonic()<deadline:
            time.sleep(3)
            client_log=OUT/"client.stdout.log"
            if client_log.exists():
                lines=[line for line in client_log.read_text(encoding="utf8",errors="replace").splitlines()
                       if line.startswith("R01_EXPLOSION_RECEIVED ")]
                if len(lines)>seen:
                    for line in lines[seen:]:
                        row=json.loads(line.split("R01_EXPLOSION_RECEIVED ",1)[1])
                        print("R01_ENET_CASE",row["case"],"bots",row["bot_count"],
                              "mix_peak_db",round(row["mixer"]["peak_db"],2),
                              "master_clip",row["master"]["clipped"],flush=True)
                    seen=len(lines)
            if all(job.poll() is not None for _,job,_ in jobs):break
            if any(job.poll() is not None and job.returncode != 0 for _,job,_ in jobs):
                print("R01_ENET_EARLY_EXIT",
                      [(role,p.poll()) for role,p,_ in jobs],flush=True)
                break
        valid=True
        for role,process,stream in jobs:
            stream.flush()
            log=(OUT/f"{role}.stdout.log").read_text(encoding="utf8",errors="replace")
            if process.poll() is None:
                print("R01_ENET_TIMEOUT",role,flush=True)
                valid=False
            elif process.returncode!=0:
                print("R01_ENET_PROCESS_FAILURE",role,process.returncode,flush=True)
                valid=False
            if "SCRIPT ERROR:" in log or "Parse Error:" in log:
                print("R01_ENET_SCRIPT_ERROR",role,flush=True)
                valid=False
            print("R01_ENET_LOG_TAIL",role,log[-1900:].replace("\n"," | "),flush=True)
        for role in ("server","client"):
            if not (OUT/f"{role}.json").is_file():
                valid=False
        if not valid:
            raise RuntimeError("End-to-end QA incomplete; inspect logs, do not certify")
        data={role:json.loads((OUT/f"{role}.json").read_text(encoding="utf8")) for role in ("server","client")}
        for role,report in data.items():
            print("R01_ENET_REPORT",role, "checks",report["checks"],"failures",report["failures"],
                  "events",len(report["events"]),"source_events",report["source_events"],flush=True)
            if report["failures"]:valid=False
        if data["client"]["client_min_remote_bots"] != 28 or data["server"]["server_min_bots"] != 28:
            valid=False
        if len(data["client"]["events"]) != 9 or data["server"]["source_events"] != 13:
            valid=False
        if not valid:
            raise RuntimeError("ENet explosion QA assertion failed")
        print("R01_EXPLOSION_ENET_28BOTS_APPROVED",flush=True)
    finally:
        for role,process,stream in jobs:
            if process.poll() is None:
                process.kill()
                process.wait(timeout=15)
            stream.close()

if __name__=="__main__":
    try:run()
    except Exception as err:
        print("R01_EXPLOSION_ENET_28BOTS_FAILED",str(err),flush=True)
        sys.exit(1)
