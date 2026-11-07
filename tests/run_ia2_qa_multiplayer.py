"""Isolated 28-bot ENet admission/deployment test. Never contacts production."""
from pathlib import Path
import argparse
import json
import os
import subprocess
import time

BASE = Path(__file__).resolve().parents[1]
ENGINE = Path(r"C:\Users\Joao Borges\Documents\Codex\tools\Godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe")
OPENSSL = Path(r"C:\Program Files\Git\usr\bin\openssl.exe")
OUTPUT = BASE / "work" / "ia2-qa-20261107"
OUTPUT.mkdir(parents=True, exist_ok=True)
(OUTPUT / ".gdignore").touch(exist_ok=True)  # Godot must not scan test APPDATA/shader caches.

def certificate():
    cert_dir = OUTPUT / "temporary-dtls"
    cert_dir.mkdir(parents=True, exist_ok=True)
    cert, key = cert_dir / "cert.pem", cert_dir / "key.pem"
    if not cert.is_file() or not key.is_file():
        subprocess.run([str(OPENSSL), "req", "-x509", "-newkey", "rsa:2048", "-sha256", "-nodes",
            "-keyout", str(key), "-out", str(cert), "-days", "1",
            "-subj", "/CN=localhost", "-addext", "subjectAltName=DNS:localhost,IP:127.0.0.1"],
            check=True, capture_output=True, timeout=25)
    return cert, key

def run_case(operation, label, cap=-1):
    cert, key = certificate()
    jobs = []
    results = {}
    try:
        for role in ("server", "client"):
            logpath = OUTPUT / (label+"-"+role+".stdout.log")
            env = os.environ.copy()
            env["APPDATA"] = str(OUTPUT / ("appdata-"+label+"-"+role))
            Path(env["APPDATA"]).mkdir(parents=True, exist_ok=True)
            visual = ["--rendering-method", "forward_plus", "--resolution", "1920x1080", "--position", "0,0"] if role=="client" else ["--headless"]
            args = [str(ENGINE), *visual, "--max-fps", "0", "--path", str(BASE),
                "--script", "res://tests/ia2_qa_multiplayer_network.gd", "--",
                "--naval-test-accounts", "--war-operation="+operation,
                "--war-port=39761", "--role="+role, "--operation="+operation, "--label="+label, "--cap="+str(cap),
                "--naval-data="+str(OUTPUT / ("auth-"+label+"-"+role)),
                "--game-tls-cert="+str(cert), "--game-tls-key="+str(key), "--game-tls-ca="+str(cert)]
            output = logpath.open("w",encoding="utf-8")
            proc = subprocess.Popen(args, cwd=BASE,env=env,stdout=output,stderr=subprocess.STDOUT,creationflags=subprocess.CREATE_NO_WINDOW)
            jobs.append((role,proc,output,logpath))
            print("START",role,proc.pid,flush=True)
            time.sleep(2 if role=="server" else .2)
        deadline = time.monotonic() + 240
        while time.monotonic() < deadline and any(proc.poll() is None for _,proc,_,_ in jobs):
            for role,proc,out,logpath in jobs:
                logtxt=logpath.read_text(encoding="utf8",errors="replace") if logpath.exists() else ""
                if "SCRIPT ERROR:" in logtxt or "IA2_NET_INVALID" in logtxt:
                    print("EARLY_SCRIPT_ERROR",role,logtxt[-2400:],flush=True)
                    raise RuntimeError("GDScript error in "+role)
            time.sleep(.4)
        for role,proc,out,logpath in jobs:
            out.flush()
            reportpath=OUTPUT / (label+"-"+role+".json")
            result=json.loads(reportpath.read_text(encoding="utf8")) if reportpath.is_file() else {"valid":False,"failures":["no report"]}
            results[role]=result
            print("RESULT",role,"exit",proc.poll(), "valid",result.get("valid"),"bots",result.get("bots_observed"),"failures",result.get("failures"),flush=True)
            if proc.poll() is None or proc.poll()!=0 or not result.get("valid"):
                print("LOG_TAIL",role,logpath.read_text(encoding="utf8",errors="replace")[-2400:],flush=True)
        return all(results.get(role,{}).get("valid",False) for role in ("server","client"))
    finally:
        for role,proc,out,logpath in jobs:
            if proc.poll() is None:
                proc.terminate()
                try:proc.wait(timeout=4)
                except subprocess.TimeoutExpired:proc.kill()
            out.close()

if __name__=="__main__":
    parser=argparse.ArgumentParser()
    parser.add_argument("--operation",choices=("favela","afghan"),default="favela")
    parser.add_argument("--label",default="favela-enet-28-20261107")
    parser.add_argument("--cap",type=int,choices=(-1,0,1),default=-1)
    opt=parser.parse_args()
    success=run_case(opt.operation,opt.label,opt.cap)
    print("IA2_ENET_QA_"+("PASS" if success else "FAIL"),flush=True)
    raise SystemExit(0 if success else 2)
