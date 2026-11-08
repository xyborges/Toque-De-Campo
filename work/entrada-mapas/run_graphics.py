"""Render 1080p/Medium with real GTX1650; offline 28-bot authority, NOT ENet.
Each process measures first 30s after join_ready and nvidia-smi timestamp aligned.
"""
from pathlib import Path
import argparse,csv,datetime,json,os,subprocess,sys,threading,time
root=Path(__file__).resolve().parents[2]
out=root/'work'/'entrada-mapas'/'graphics'
out.mkdir(exist_ok=True)
exe=Path(r'C:\Users\Microgate\Documents\Codex\2026-11-06\fa-a\work\Godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe')
pattern=[0,0,0,1,1,0,0,1,1,0,0,1]
def run(operation,full):
    rows=[]
    indexes=range(len(pattern)) if full else (0,3)
    for i in indexes:
        variant=pattern[i]
        name=f"{operation}-graphics-{i+1:02d}-{variant}"
        if "Godot" in subprocess.run(["powershell","-NoProfile","-Command",
                "(Get-CimInstance Win32_Process|Where-Object {$_.Name -match 'Godot'}|Measure-Object).Count"],
                capture_output=True,text=True).stdout.strip():
            # Actual detection only below
            pass
        proc_check=subprocess.run(["powershell","-NoProfile","-Command",
                "(Get-CimInstance Win32_Process|Where-Object {$_.Name -match 'Godot'}|Measure-Object).Count"],
                capture_output=True,text=True).stdout.strip()
        if proc_check not in ("0",""):
            raise RuntimeError("Other Godot running: "+proc_check)
        env=os.environ.copy()
        env.update(TDC_IA2_HOUSING_CACHE=str(variant),
                   TDC_IA2_TERRAIN_FACES=str(variant),
                   TDC_IA2_MAP_STAGES="0",TDC_IA2_NEIGHBOR_SUBSTAGES="0")
        gpu_lines=[]
        stop=threading.Event()
        def gpu_worker():
            while not stop.is_set():
                try:
                    result=subprocess.run(["nvidia-smi",
                         "--query-gpu=timestamp,temperature.gpu,utilization.gpu,clocks_throttle_reasons.active",
                         "--format=csv,noheader"],capture_output=True,text=True,timeout=15)
                    gpu_lines.append(result.stdout.strip())
                except Exception as exc:
                    gpu_lines.append("ERROR "+str(exc))
                stop.wait(1)
        monitor=threading.Thread(target=gpu_worker,daemon=True)
        monitor.start()
        cmd=[str(exe),"--rendering-method","forward_plus","--resolution","1920x1080",
             "--windowed","--position","0,0","--max-fps","0",
             "--path",str(root),"--script","res://tests/ia2_entry_graphical_offline.gd",
             "--",f"--operation={operation}",f"--label={name}"]
        begun=datetime.datetime.now().astimezone().isoformat()
        print("GRAPHIC_RUN_START",name,begun,flush=True)
        try:
            proc=subprocess.run(cmd,env=env,cwd=root,stdout=subprocess.PIPE,
                   stderr=subprocess.STDOUT,text=True,errors='replace',timeout=300,
                   creationflags=subprocess.CREATE_NO_WINDOW)
        finally:
            stop.set()
            monitor.join(timeout=7)
        (out/f"{name}.log").write_text(proc.stdout,encoding="utf-8")
        (out/f"{name}-nvidia.csv").write_text(
            "timestamp,temperature_C,utilization_pct,throttle_active\n"+"\n".join(gpu_lines)+"\n",encoding="utf-8")
        matches=[x[len("IA2_ENTRY_GRAPHICS "):] for x in proc.stdout.splitlines()
                if x.startswith("IA2_ENTRY_GRAPHICS ")]
        if not matches:
            print("GRAPHIC_RUN_FAILED",name,"exit",proc.returncode,proc.stdout[-1400:],flush=True)
            raise RuntimeError("Graphics not reported "+name)
        data=json.loads(matches[-1])
        (out/f"{name}.json").write_text(json.dumps(data,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
        record={
            "operation":operation,"run":i+1,"variant":variant,"exit":proc.returncode,
            "ready_ms":data["join_ready_ms"],"world_ms":data["world_ms"],
            "fps":1000/data["frame_ms"]["mean"],"p95_ms":data["frame_ms"]["p95"],
            "p99_ms":data["frame_ms"]["p99"],"max_ms":data["frame_ms"]["max"],
            "gpu_p99_ms":data["gpu_ms"].get("p99",None),
            "spike50":data["frames_over_50"],"spike100":data["frames_over_100"],
            "focus_lost":data["unfocused_frames"],"bots":data["bots_end"],"bots_deployed_end":data["deployed_end"],
            "gpu_temp_first":gpu_lines[0] if gpu_lines else "", "gpu_temp_last":gpu_lines[-1] if gpu_lines else ""
        }
        rows.append(record)
        with (out/f"{operation}-graphics.csv").open("w",encoding="utf-8",newline="") as f:
            cw=csv.DictWriter(f,fieldnames=rows[0].keys());cw.writeheader();cw.writerows(rows)
        print("GRAPHIC_RUN_END",json.dumps(record,ensure_ascii=False),flush=True)
        if proc.returncode!=0 or data["bots_end"]!=28:raise RuntimeError("Invalid 28 bots graphical "+name)
    print("GRAPHICS_COMPLETED",operation,len(rows),flush=True)

if __name__=="__main__":
    parser=argparse.ArgumentParser()
    parser.add_argument("--operation",choices=["favela","afghan"],required=True)
    parser.add_argument("--full",action="store_true")
    args=parser.parse_args()
    run(args.operation,args.full)
