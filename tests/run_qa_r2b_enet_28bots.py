#!/usr/bin/env python3
"""28 real bots in one ENet match, five alternating G3 FPP R2B OFF/ON pairs."""
import csv
import json
import os
from pathlib import Path
import socket
import statistics
import subprocess
import time
import argparse
import datetime

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/"work"/"r2b-bench-jj7"
ENGINE=Path.home()/"Documents"/"Codex"/"tools"/"Godot-4.7.2"/"Godot_v4.7.2-stable_win64_console.exe"
CERT=OUT/"tls"/"test.crt"
KEY=OUT/"tls"/"test.key"

def main():
    parser=argparse.ArgumentParser()
    parser.add_argument("--engine",type=Path,default=ENGINE)
    parser.add_argument("--pairs",type=int,default=5)
    parser.add_argument("--seconds",type=float,default=12)
    parser.add_argument("--timeout",type=float,default=660)
    args=parser.parse_args()
    OUT.mkdir(parents=True,exist_ok=True)
    assert args.engine.is_file() and CERT.is_file() and KEY.is_file(), "Missing Godot/test-only TLS"
    # Never accept a previous suite's results as output from this invocation.
    for old_name in ("server.json","client.json","verdict.json","pairs.csv"):
        (OUT/old_name).unlink(missing_ok=True)
    with socket.socket(socket.AF_INET,socket.SOCK_DGRAM) as reserved:
        reserved.bind(("127.0.0.1",0))
        port=reserved.getsockname()[1]
    processes=[]
    roles=("server","client")
    try:
        for role in roles:
            appdir=Path(os.environ.get("LOCALAPPDATA",str(OUT)))/"tdc-r2b-jj7-qa"/role
            appdir.mkdir(parents=True,exist_ok=True)
            env=os.environ.copy()
            env["APPDATA"]=str(appdir)
            env["TDC_TACTICAL_MOTION_PILOT"]="0"
            env["TDC_TACTICAL_BODY_PILOT"]="0"
            env["TDC_IA1_POSE_PROBE"]="0"
            env["TDC_IA1_IDLE_POSE_30HZ"]="0"
            env["TDC_IA1_VISUAL_ARM_LOD"]="0"
            args_g=[str(args.engine)]
            if role=="server":
                args_g+=["--headless"]
            else:
                args_g+=["--resolution","1920x1080","--position","0,0"]
            args_g+=["--path",str(ROOT),"--script","res://tests/qa_r2b_enet_28bots.gd",
                     "--","--naval-test-accounts","--map-uncached","--performance-probe",
                     f"--role={role}",f"--war-port={port}",
                     f"--naval-data={OUT/(role+'-data')}",f"--pairs={args.pairs}",
                     "--profiles=r2b",f"--segment-seconds={args.seconds}",
                     f"--game-tls-cert={CERT}",f"--game-tls-key={KEY}",
                     f"--game-tls-ca={CERT}","--game-tls-host=localhost"]
            outfile=(OUT/f"{role}.stdout.log").open("w",encoding="utf-8",errors="replace")
            job=subprocess.Popen(args_g,cwd=ROOT,env=env,stdout=outfile,stderr=subprocess.STDOUT,
                                 creationflags=getattr(subprocess,"CREATE_NO_WINDOW",0))
            processes.append((role,job,outfile))
            print("START",role,job.pid,"port",port,flush=True)
            time.sleep(1.2)
        observed=0
        deadline=time.monotonic()+args.timeout
        while time.monotonic()<deadline:
            time.sleep(2)
            c_log=(OUT/"client.stdout.log")
            if c_log.exists():
                lines=[row for row in c_log.read_text(encoding="utf-8",errors="replace").splitlines()
                       if row.startswith("R2B_ENET_SEGMENT ")]
                if len(lines)>observed:
                    for s in lines[observed:]:
                        try:
                            x=json.loads(s.split("R2B_ENET_SEGMENT ",1)[1])
                            print("SEGMENT",x.get("pair"),"ON" if x.get("optimized") else "OFF",
                                  "fps",round(x.get("frames",{}).get("fps",0),2),
                                  "p95",round(x.get("frames",{}).get("p95_ms",0),2),
                                  "p99",round(x.get("frames",{}).get("p99_ms",0),2),
                                  "path_m",round(x.get("path_m",0),1),"g3",x.get("g3_stayed"),"active",x.get("nonzero_pose_checks"),
                                  "valid",x.get("valid"),flush=True)
                        except Exception as e:print("LOG_PARSE_ERROR",e,flush=True)
                    observed=len(lines)
            if all(job.poll() is not None for _,job,_ in processes):
                break
            if any(job.poll() not in (None,0) for _,job,_ in processes):
                break
        for role,job,fp in processes:fp.flush()
        server_file=OUT/"server.json"
        client_file=OUT/"client.json"
        result={"base_commit":"ce2653e","branch":"ia/bench-realismo-r2b-jj7-20261109",
                "machine":"DESKTOP-JJ7U3G3","cpu":"i5-11400H","gpu":"GTX 1650",
                "window_seconds":args.seconds,"pairs":args.pairs,
                "timestamp":datetime.datetime.now().isoformat(timespec="seconds"),
                "processes":{role:job.poll() for role,job,_ in processes}}
        for role,job,_ in processes:
            log=(OUT/f"{role}.stdout.log").read_text(encoding="utf-8",errors="replace")
            result[role+"_script_errors"]=[row[:450] for row in log.splitlines() if "SCRIPT ERROR:" in row or "Parse Error:" in row][-8:]
            result[role+"_shader_cache_errors"]=[row[:350] for row in log.splitlines() if "Unable to create shader cache directory" in row][-8:]
            result[role+"_material_errors"]=[row[:350] for row in log.splitlines() if "Failed loading resource:" in row or "referenced non-existent resource" in row][-8:]
            result[role+"_udp_buffer_warnings"]=[row[:450] for row in log.splitlines() if "Buffer full, dropping packets!" in row]
        if server_file.exists() and client_file.exists():
            server=json.loads(server_file.read_text(encoding="utf-8-sig"))
            client=json.loads(client_file.read_text(encoding="utf-8-sig"))
            result["server"]={k:v for k,v in server.items() if k not in ("results","bot_diagnostics")}
            result["client"]={k:v for k,v in client.items() if k not in ("results",)}
            result["records"]=client.get("results",[])
            result["pairs_comparison"]=[]
            for n in range(1,args.pairs+1):
                rows=[r for r in result["records"] if r.get("pair")==n]
                if len(rows)==2 and {bool(r.get("optimized")) for r in rows}=={False,True}:
                    a=next(x for x in rows if not x["optimized"])
                    b=next(x for x in rows if x["optimized"])
                    item={"pair":n,"valid":a.get("valid") and b.get("valid"),
                          "off_fps":a["frames"]["fps"],"on_fps":b["frames"]["fps"],
                          "off_p95_ms":a["frames"]["p95_ms"],"on_p95_ms":b["frames"]["p95_ms"],
                          "off_p99_ms":a["frames"]["p99_ms"],"on_p99_ms":b["frames"]["p99_ms"],
                          "off_physics_mean_ms":a["physics"]["mean_ms"],
                          "on_physics_mean_ms":b["physics"]["mean_ms"],
                          "fps_change_pct":100*(b["frames"]["fps"]/a["frames"]["fps"]-1),
                          "p99_change_pct":100*(b["frames"]["p99_ms"]/a["frames"]["p99_ms"]-1)}
                    result["pairs_comparison"].append(item)
            valid=(len(result["pairs_comparison"])==args.pairs
                   and all(x["valid"] for x in result["pairs_comparison"])
                   and not server.get("failures")
                   and not client.get("failures")
                   and server.get("server_min_bots")==28
                   and server.get("bots_at_completion")==28
                   and client.get("min_remote_actors")==28
                   and client.get("dropped_focus_frames")==0
                   and client.get("physics_hz")==60
                   and str(client.get("render_texture")).replace(" ","") in ("[1920,1080]","(1920,1080)","(1920.0,1080.0)")
                   and abs(float(client.get("render_scale",0))-1.0)<.001
                   and "GTX 1650" in client.get("gpu","")
                   and client.get("renderer")!="gl_compatibility"
                   and all(job.poll()==0 for _,job,_ in processes)
                   and not result["server_script_errors"] and not result["client_script_errors"]
                   and not result["server_shader_cache_errors"] and not result["client_shader_cache_errors"]
                   and not result["server_material_errors"] and not result["client_material_errors"])
            result["valid"]=valid
            if result["pairs_comparison"]:
                pairs=result["pairs_comparison"]
                result["summary"]={"n":len(pairs),
                  "off_median_fps":statistics.median(x["off_fps"] for x in pairs),
                  "on_median_fps":statistics.median(x["on_fps"] for x in pairs),
                  "off_median_p99_ms":statistics.median(x["off_p99_ms"] for x in pairs),
                  "on_median_p99_ms":statistics.median(x["on_p99_ms"] for x in pairs),
                  "median_fps_change_pct":statistics.median(x["fps_change_pct"] for x in pairs),
                  "median_p99_change_pct":statistics.median(x["p99_change_pct"] for x in pairs),
                  "fps_wins":sum(x["fps_change_pct"]>0 for x in pairs),
                  "p99_wins":sum(x["p99_change_pct"]<0 for x in pairs)}
                print("SUMMARY",result["summary"],flush=True)
                with (OUT/"pairs.csv").open("w",encoding="utf-8",newline="") as f:
                    writer=csv.DictWriter(f,fieldnames=list(pairs[0]))
                    writer.writeheader();writer.writerows(pairs)
        else:
            result["valid"]=False
            result["missing_files"]=[str(path) for path in (server_file,client_file) if not path.exists()]
        (OUT/"verdict.json").write_text(json.dumps(result,indent=2,ensure_ascii=False,default=str),encoding="utf-8")
        print("VERDICT", "VALID" if result.get("valid") else "INVALID",
              "server_exit",result["processes"]["server"],"client_exit",result["processes"]["client"],
              "client_errors",result.get("client_script_errors"),"server_errors",result.get("server_script_errors"),
              "UDP_WARNINGS",len(result["client_udp_buffer_warnings"]),
              "SHADER_CACHE_ERRORS",len(result["client_shader_cache_errors"]),
              "MATERIAL_ERRORS",len(result["client_material_errors"]),flush=True)
        if not result.get("valid"):raise RuntimeError("Benchmark invalid; see verdict.json and logs")
    finally:
        for role,job,fp in processes:
            if job.poll() is None:
                subprocess.run(["taskkill","/PID",str(job.pid),"/T","/F"],
                               capture_output=True,creationflags=getattr(subprocess,"CREATE_NO_WINDOW",0))
                try:job.wait(timeout=10)
                except subprocess.TimeoutExpired:job.kill()
            fp.close()

if __name__=="__main__":
    main()
