"""Real ENet/DTLS WarGame movement test (Afghan map with verified prepared manifest).

Usage:
  python tests/run_war_locomotion_network.py --tls-dir path/to/work/security182
  TDC_QA_TLS_DIR=/path/to/work/security182 python tests/run_war_locomotion_network.py

Never uses production certificates or servers. Does not rewrite tracked test JSON.
"""
import argparse
import json
import os
from pathlib import Path
import socket
import subprocess
import sys
import tempfile
import time

ROOT=Path(__file__).resolve().parents[1]
DEFAULT_ENGINE=Path.home()/"Documents/Codex/tools/Godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe"
EXPECTED={"server":5,"mover":1,"observer":12}


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--engine",default=os.environ.get("GODOT_BIN",str(DEFAULT_ENGINE)))
    parser.add_argument("--tls-dir",default=os.environ.get("TDC_QA_TLS_DIR",str(ROOT/"work/security182")))
    parser.add_argument("--timeout",type=int,default=130)
    args=parser.parse_args()
    engine=Path(args.engine).expanduser().resolve()
    tls=Path(args.tls_dir).expanduser().resolve()
    cert,key=tls/"test.crt",tls/"test.key"
    if not engine.is_file() or not cert.is_file() or not key.is_file():
        print("FAIL: Godot or local test.crt/test.key missing. Supply --engine and --tls-dir.",flush=True)
        return 2

    preflight=subprocess.run([sys.executable,str(ROOT/"tools/map_release_preflight_readonly.py"),"--map","afghan"],
                           cwd=ROOT,capture_output=True,text=True)
    print(preflight.stdout.strip(),flush=True)
    if preflight.returncode:
        print("FAIL: Afghan prepared map is stale. Reprepare map; do not bypass content hash.",flush=True)
        return 2

    output=ROOT/"work/war-locomotion-qa"
    output.mkdir(parents=True,exist_ok=True)
    with socket.socket(socket.AF_INET,socket.SOCK_DGRAM) as reserved:
        reserved.bind(("127.0.0.1",0))
        port=reserved.getsockname()[1]
    print("NETWORK_QA_PORT",port,flush=True)
    jobs=[]
    try:
        for role in EXPECTED:
            report=output/(role+".json")
            report.unlink(missing_ok=True)
            stdout=output/(role+".stdout.log")
            log=stdout.open("w",encoding="utf-8")
            # Windows OpenGL shader cache paths include 64-char hashes; keep APPDATA short.
            profile=Path(tempfile.gettempdir())/"tdc-war-net-qa"/str(os.getpid())/role
            profile.mkdir(parents=True,exist_ok=True)
            env=os.environ.copy()
            env["APPDATA"]=str(profile)
            env["LOCALAPPDATA"]=str(profile/"local")
            argv=[str(engine),"--max-fps","60","--path",str(ROOT),
                  "--rendering-method","gl_compatibility","--script","res://tests/war_locomotion_network.gd"]
            argv+=["--headless"] if role!="observer" else ["--screen","0","--position","20,20","--resolution","1280x800"]
            argv+=["--","--naval-test-accounts","--role="+role,f"--war-port={port}","--war-map=afghan",
                   "--naval-data="+str(profile/"data"),
                   "--game-tls-cert="+str(cert),"--game-tls-key="+str(key),
                   "--game-tls-ca="+str(cert),"--game-tls-host=localhost"]
            proc=subprocess.Popen(argv,cwd=ROOT,env=env,stdout=log,stderr=subprocess.STDOUT,
                                  creationflags=getattr(subprocess,"CREATE_NO_WINDOW",0))
            jobs.append((role,proc,log,stdout,report))
            print("NETWORK_QA_START",role,proc.pid,flush=True)
            time.sleep(1.6)

        deadline=time.monotonic()+args.timeout
        last=time.monotonic()
        while any(proc.poll() is None for _,proc,*_ in jobs) and time.monotonic()<deadline:
            time.sleep(.3)
            if time.monotonic()-last>15:
                last=time.monotonic()
                print("NETWORK_QA_RUNNING",[(role,proc.poll()) for role,proc,*_ in jobs],flush=True)

        results={}
        for role,proc,log,stdout,report in jobs:
            log.flush()
            data=json.loads(report.read_text(encoding="utf-8")) if report.is_file() else {"failures":["missing report"]}
            text=stdout.read_text(encoding="utf-8",errors="replace")
            errors=[line for line in text.splitlines() if line.startswith(("ERROR:","SCRIPT ERROR:"))]
            good=(proc.poll()==0 and data.get("failures")==[] and
                  data.get("checks")==EXPECTED[role] and not errors)
            results[role]={"ok":good,"exit":proc.poll(),"checks":data.get("checks"),
                           "expected_checks":EXPECTED[role],"failures":data.get("failures"),
                           "samples":data.get("samples"),"errors":errors[:8]}
            print("NETWORK_QA_RESULT",role,json.dumps(results[role],ensure_ascii=False),flush=True)
        passed=all(result["ok"] for result in results.values())
        report={"ok":passed,"map":"afghan","renderer":"gl_compatibility (network validation only)",
                "test_transport":"real encrypted ENet/DTLS","roles":results}
        (output/"summary.json").write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding="utf-8")
        print("NETWORK_QA_GATE", "PASS" if passed else "FAIL",flush=True)
        return 0 if passed else 1
    finally:
        for role,proc,log,stdout,report in jobs:
            if proc.poll() is None:
                proc.kill()
                proc.wait()
            log.close()


if __name__=="__main__":
    sys.exit(main())
