#!/usr/bin/env python3
"""Five paired A/B tests per IA2 flag, one native DTLS authority + one graphical client.
All measurements occur with 28 simulated online War bots; visuals are stressed locally,
not an assertion of 28 authoritative NPC deaths.
"""
from __future__ import annotations
import argparse
import csv
import json
import os
from pathlib import Path
import socket
import statistics
import subprocess
import time

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "work" / "ia2-enet-20261108"
GODOT = Path.home() / "Documents/Codex/2026-11-06/fa-a/work/Godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe"
CERTS = Path.home() / "Documents/Codex/2026-11-06/fa-a/work/Toque-De-Campo-ia2-architecture-cache/work/security182"

def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument("--pairs", type=int, default=5, choices=range(1, 6))
    parser.add_argument("--profiles", default="reuse,defer,cap")
    parser.add_argument("--segment-seconds", type=float, default=12.0)
    parser.add_argument("--godot", type=Path, default=GODOT)
    parser.add_argument("--timeout", type=float, default=900.0)
    return parser.parse_args()

def analysis(records, expected_pairs, profiles):
    outcomes = {}
    for profile in profiles:
        pairs = []
        for number in range(1, expected_pairs+1):
            options = [row for row in records if row["profile"] == profile and row["pair"] == number]
            if len(options)!=2 or {bool(i["optimized"]) for i in options}!={True,False}:
                raise RuntimeError(f"Missing pair: {profile} {number}")
            baseline = next(x for x in options if not x["optimized"])
            optimized = next(x for x in options if x["optimized"])
            if not baseline["valid"] or not optimized["valid"]:
                raise RuntimeError(f"Invalid pair: {profile} {number}")
            fb = float(baseline["frames"]["fps"]); fo = float(optimized["frames"]["fps"])
            p99b=float(baseline["frames"]["p99_ms"]); p99o=float(optimized["frames"]["p99_ms"])
            pairs.append({
                "profile":profile,"pair":number,
                "baseline_fps":fb,"optimized_fps":fo,"fps_change_pct":(fo/fb-1)*100,
                "baseline_p99_ms":p99b,"optimized_p99_ms":p99o,
                "p99_change_pct":(p99o/p99b-1)*100,
                "baseline_over33":baseline["frames"]["over33"],
                "optimized_over33":optimized["frames"]["over33"],
                "baseline_max_corpses":baseline["max_corpses"],
                "optimized_max_corpses":optimized["max_corpses"],
                "baseline_callbacks_ms":baseline["callbacks"].get("mean_ms",None),
                "optimized_callbacks_ms":optimized["callbacks"].get("mean_ms",None),
                "focus_lost":baseline["focus_lost"]+optimized["focus_lost"]
            })
        median_fps = statistics.median(i["fps_change_pct"] for i in pairs)
        median_p99 = statistics.median(i["p99_change_pct"] for i in pairs)
        better_fps = sum(i["fps_change_pct"]>0 for i in pairs)
        better_p99 = sum(i["p99_change_pct"]<0 for i in pairs)
        if profile in ("reuse","defer"):
            approved = better_fps>=4 and better_p99>=4 and median_fps>=3.0 and median_p99<=-3.0
        else:
            approved = all(i["optimized_max_corpses"]<=10 for i in pairs) and (
                median_fps>=-3.0 and median_p99<=5.0)
        outcomes[profile] = {
            "approved":approved,"median_fps_change_pct":median_fps,
            "median_p99_change_pct":median_p99,"fps_pair_wins":better_fps,
            "p99_pair_wins":better_p99,"pairs":pairs
        }
    return outcomes

def main():
    args=parse_args()
    profiles=args.profiles.split(",")
    assert set(profiles)<=set(["reuse","defer","cap"]) and profiles
    assert args.godot.is_file(), args.godot
    cert,key = CERTS/"test.crt",CERTS/"test.key"
    assert cert.is_file() and key.is_file(), "Missing isolated QA DTLS materials"
    OUT.mkdir(parents=True,exist_ok=True)
    for filename in ("server.json","client.json"):
        (OUT/filename).unlink(missing_ok=True)
    with socket.socket(socket.AF_INET,socket.SOCK_DGRAM) as reservation:
        reservation.bind(("127.0.0.1",0))
        port=reservation.getsockname()[1]
    jobs=[]
    try:
        for role in ("server","client"):
            env=os.environ.copy()
            env["APPDATA"]=str(OUT / f"{role}-appdata")
            for name in ("TDC_IA2_REUSE_RESPAWN_WEAPON","TDC_IA2_DEFER_REMOTE_RAGDOLL",
                         "TDC_IA2_RAGDOLL_STRICT_CAP"):
                env[name]="0"
            Path(env["APPDATA"]).mkdir(parents=True,exist_ok=True)
            out=(OUT/f"{role}.stdout.log").open("w",encoding="utf-8")
            command=[
                str(args.godot),"--path",str(ROOT),
                "--script","res://tests/ia2_enet_28bots_benchmark.gd",
                "--"
            ]
            command=[
                str(args.godot),
                "--headless" if role=="server" else "--resolution",
                *([] if role=="server" else ["1920x1080","--position","0,0"]),
                "--path",str(ROOT),
                "--script","res://tests/ia2_enet_28bots_benchmark.gd",
                "--","--naval-test-accounts","--map-uncached","--performance-probe",
                f"--role={role}",f"--war-port={port}",
                f"--naval-data={OUT/(role+'-data')}",
                f"--pairs={args.pairs}",f"--profiles={args.profiles}",
                f"--segment-seconds={args.segment_seconds}",
                f"--game-tls-cert={cert}",f"--game-tls-key={key}",
                f"--game-tls-ca={cert}","--game-tls-host=localhost"
            ]
            print("START",role,"port",port,flush=True)
            job=subprocess.Popen(command, cwd=ROOT, env=env, stdout=out,
                 stderr=subprocess.STDOUT, creationflags=getattr(subprocess,"CREATE_NO_WINDOW",0))
            jobs.append((role,job,out))
            time.sleep(1.2 if role=="server" else 0.3)
        deadline=time.monotonic()+args.timeout
        output_line_count = 0
        while time.monotonic()<deadline:
            if all(job.poll() is not None for _,job,_ in jobs):break
            time.sleep(2)
            if (OUT/"client.stdout.log").exists():
                data=(OUT/"client.stdout.log").read_text(encoding="utf8", errors="replace")
                rows=[x for x in data.splitlines() if x.startswith("IA2_ENET_SEGMENT ")]
                if len(rows)>output_line_count:
                    for line in rows[output_line_count:]:
                        try:
                            row=json.loads(line.split("IA2_ENET_SEGMENT ",1)[1])
                            print("SEGMENT",row["profile"],row["pair"],int(row["optimized"]),
                                  "fps",round(row["frames"].get("fps",0),2),
                                  "p99",round(row["frames"].get("p99_ms",0),2),
                                  "valid",row["valid"],flush=True)
                        except Exception as ex:print("PARSE",str(ex),flush=True)
                    output_line_count=len(rows)
            for role,job,_ in jobs:
                if job.poll() is not None and job.returncode!=0:
                    print("PROCESS_EXIT_EARLY",role,job.returncode,flush=True)
                    break
            if any(job.poll() is not None and job.returncode!=0 for _,job,_ in jobs):break
        valid=True
        for role,job,out in jobs:
            out.flush()
            if job.poll() is None:
                print("TIMEOUT",role,flush=True);valid=False
            elif job.returncode!=0:
                print("FAILED_PROCESS",role,job.returncode,flush=True);valid=False
            log=(OUT/f"{role}.stdout.log").read_text(encoding="utf8",errors="replace")
            print("LOG_TAIL",role,log[-1800:],flush=True)
            if "SCRIPT ERROR:" in log or "Parse Error:" in log:valid=False
            if not (OUT/f"{role}.json").is_file():valid=False
        if not valid:raise RuntimeError("No valid ENet comparison — inspect logs")
        server=json.loads((OUT/"server.json").read_text(encoding="utf8"))
        client=json.loads((OUT/"client.json").read_text(encoding="utf8"))
        if server["failures"] or client["failures"]:
            raise RuntimeError(f"Server errors: {server['failures']}, client: {client['failures']}")
        if server.get("server_min_bots")!=28 or server.get("bots_at_completion")!=28:
            raise RuntimeError("Bot server population invalid")
        if client.get("min_remote_actors")!=28 or client.get("dropped_focus_frames")!=0:
            raise RuntimeError("Client population or focus invalid")
        if client.get("renderer")=="gl_compatibility" or "GTX 1650" not in client.get("gpu",""):
            raise RuntimeError("GPU/render method invalid")
        if len(client["results"])!=args.pairs*2*len(profiles):
            raise RuntimeError(f"Unexpected segment count {len(client['results'])}")
        verdicts=analysis(client["results"],args.pairs,profiles)
        rows=[p for profile in profiles for p in verdicts[profile]["pairs"]]
        with (OUT/"summary.csv").open("w",newline="",encoding="utf8") as f:
            writer=csv.DictWriter(f,fieldnames=list(rows[0]))
            writer.writeheader()
            writer.writerows(rows)
        report={"valid":True,"pairs":args.pairs,"segment_seconds":args.segment_seconds,
                "profiles":profiles,"server":server,"client_environment":{k:v for k,v in client.items() if k not in ("results",)},
                "verdicts":verdicts}
        (OUT/"verdict.json").write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding="utf8")
        for profile,value in verdicts.items():
            print("VERDICT",profile, "APPROVE" if value["approved"] else "REJECT",
                  "fps median",round(value["median_fps_change_pct"],2),
                  "p99 median",round(value["median_p99_change_pct"],2),
                  "wins",value["fps_pair_wins"],value["p99_pair_wins"],flush=True)
        print("NETWORK_AB_COMPLETE",flush=True)
    finally:
        for role,job,out in jobs:
            if job.poll() is None:
                job.kill()
                job.wait(timeout=15)
            out.close()

if __name__=="__main__":main()
