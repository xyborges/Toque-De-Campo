"""Local real ENet/DTLS QA with dedicated headless WarGame + GUI player
and late joiner, never touching production/launcher. Requires Godot 4.7.2."""
from pathlib import Path
import argparse,csv,datetime,json,os,subprocess,sys,threading,time

ROOT=Path(__file__).resolve().parents[2]
GODOT=Path(r"C:\Users\Microgate\Documents\Codex\2026-11-06\fa-a\work\Godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe")
OPENSSL=Path(r"C:\Program Files\Git\usr\bin\openssl.exe")
ROOT_OUT=ROOT/"work"/"entrada-mapas"/"enet"
ROOT_OUT.mkdir(parents=True,exist_ok=True)
(ROOT_OUT/".gdignore").touch(exist_ok=True)

def wait_for_marker(path,marker,timeout=130):
    stop=time.monotonic()+timeout
    while time.monotonic()<stop:
        if path.exists() and marker in path.read_text(encoding="utf-8",errors="replace"):
            return True
        time.sleep(.4)
    return False

def tls_files():
    directory=ROOT_OUT/"ephemeral-cert"
    directory.mkdir(parents=True,exist_ok=True)
    cert=directory/"cert.pem"; key=directory/"key.pem"
    if not cert.exists() or not key.exists():
        subprocess.run([str(OPENSSL),"req","-x509","-newkey","rsa:2048","-nodes",
                        "-days","1","-keyout",str(key),"-out",str(cert),
                        "-subj","/CN=localhost","-addext","subjectAltName=DNS:localhost,IP:127.0.0.1"],
                       check=True,capture_output=True,text=True)
    return cert,key

def pct(values,q):
    if not values:return None
    ordered=sorted(values)
    return ordered[min(len(ordered)-1,max(0,int(len(ordered)*q+.999999)-1))]

def run_one(operation,cache,port):
    label=f"enet-{datetime.datetime.now().strftime('%Y%m%d-%H%M%S')}-{operation}-{cache}"
    cert,key=tls_files()
    paths={}
    handles=[]
    start_second=0
    gpu_stop=threading.Event()
    gpu_raw=[]
    def monitor_gpu():
        while not gpu_stop.is_set():
            proc=subprocess.run(["nvidia-smi","--query-gpu=timestamp,temperature.gpu,utilization.gpu,clocks_throttle_reasons.active",
                                 "--format=csv,noheader"],capture_output=True,text=True,timeout=15)
            gpu_raw.append(proc.stdout.strip())
            gpu_stop.wait(1.0)
    monitor=threading.Thread(target=monitor_gpu,daemon=True)
    def launch(role,windowed):
        path=ROOT_OUT/f"{label}-{role}.stdout.log"
        handles.append((role,path.open("w",encoding="utf-8"),None))
        env=os.environ.copy()
        env["APPDATA"]=str(ROOT_OUT/f"appdata-{label}-{role}")
        Path(env["APPDATA"]).mkdir(parents=True,exist_ok=True)
        env["TDC_IA2_HOUSING_CACHE"]=str(cache)
        env["TDC_IA2_TERRAIN_FACES"]=str(cache)
        env["TDC_IA2_MAP_STAGES"]="0"
        env["TDC_IA2_NEIGHBOR_SUBSTAGES"]="0"
        env["TDC_IA2_FAST_HEADLESS_BOX"]="0"
        display=["--rendering-method","forward_plus","--resolution","1920x1080","--position","0,0","--windowed","--max-fps","0"] if windowed else ["--headless","--max-fps","60"]
        data=ROOT_OUT/f"{label}-{role}-account"
        cmd=[str(GODOT),*display,"--path",str(ROOT),"--script","res://tests/ia2_entry_enet_graphics.gd","--",
             "--naval-test-accounts",f"--war-operation={operation}",f"--naval-data={data}",f"--war-port={port}",f"--game-tls-cert={cert}",
             f"--game-tls-key={key}",f"--game-tls-ca={cert}",
             f"--role={role}",f"--operation={operation}",f"--label={label}"]
        output=handles[-1][1]
        process=subprocess.Popen(cmd,cwd=ROOT,env=env,stdout=output,stderr=subprocess.STDOUT,creationflags=subprocess.CREATE_NO_WINDOW)
        handles[-1]=(role,output,process)
        paths[role]=ROOT_OUT/f"{label}-{role}.stdout.log"
        print("IA2_ENET_LAUNCH",label,role,"pid",process.pid,flush=True)
    monitor.start()
    try:
        if (others:=subprocess.run(["powershell","-NoProfile","-Command",
                                    "(Get-CimInstance Win32_Process | Where-Object { $_.Name -match 'Godot' } | Measure-Object).Count"],
                    capture_output=True,text=True)).stdout.strip() not in ["0",""]:
            raise RuntimeError("Cannot test with a concurrent Godot process")
        launch("server",False)
        if not wait_for_marker(paths["server"],"IA2_ENET_HOST_READY",75):
            raise RuntimeError("Authority never reported listening: "+paths["server"].read_text(errors="replace")[-1800:])
        launch("client1",True)
        if not wait_for_marker(paths["client1"],"IA2_ENET_CLIENT_READY client1",135):
            raise RuntimeError("First client failed to join: "+paths["client1"].read_text(errors="replace")[-2500:])
        time.sleep(8)
        start_second=int(time.time()*1000)
        launch("client2",False)
        if not wait_for_marker(paths["client2"],"IA2_ENET_CLIENT_READY client2",115):
            raise RuntimeError("Second client failed to join: "+paths["client2"].read_text(errors="replace")[-2500:])
        limit=time.monotonic()+120
        while time.monotonic()<limit:
            if all((ROOT_OUT/f"{label}-{role}.json").exists() for role in ("client1","client2")):break
            time.sleep(.5)
        (ROOT_OUT/f"STOP_{label}").write_text("stop",encoding="utf-8")
        for role,file,proc in handles:
            try:proc.wait(timeout=18)
            except subprocess.TimeoutExpired:proc.kill();proc.wait(timeout=5)
        reports={}
        for role in ("server","client1","client2"):
            target=ROOT_OUT/f"{label}-{role}.json"
            reports[role]=json.loads(target.read_text(encoding="utf-8")) if target.exists() else {"error":"missing report","log":paths[role].read_text(errors="replace")[-1500:]}
        join2=int(reports.get("client2",{}).get("join_unix_ms",0))
        old=reports.get("client1",{}).get("frames",[])
        before=[float(f["ms"]) for f in old if start_second-10000<=int(f["t"])<start_second]
        during=[float(f["ms"]) for f in old if start_second<=int(f["t"])<=join2+5000]
        serv=reports.get("server",{}).get("frames",[])
        serv_during=[x for x in serv if start_second<=int(x["t"])<=join2+5000]
        result={"label":label,"operation":operation,"cache":cache,"port":port,
            "second_launch_unix_ms":start_second,
            "second_join_unix_ms":join2,
            "second_join_wall_ms":join2-start_second if join2 else None,
            "first_client_before_join_p99_ms":pct(before,.99),
            "first_client_during_join_p99_ms":pct(during,.99),
            "first_client_during_join_max_ms":max(during) if during else None,
            "server_during_second_join_max_physics_ms":max((float(x["physics_ms"]) for x in serv_during),default=None),
            "server_during_second_join_max_ticks":max((int(x["ticks"]) for x in serv_during),default=None),
            "rows":{"server":{k:v for k,v in reports["server"].items() if k!="frames"},
                    "client1":{k:v for k,v in reports["client1"].items() if k!="frames"},
                    "client2":{k:v for k,v in reports["client2"].items() if k!="frames"}},
            "gpu_raw_csv":f"{label}-nvidia-smi.csv"}
        with (ROOT_OUT/f"{label}-nvidia-smi.csv").open("w",encoding="utf-8",newline="") as f:
            f.write("timestamp,temperature_C,utilization_pct,throttle_active\n")
            f.write("\n".join(gpu_raw)+"\n")
        (ROOT_OUT/f"{label}-summary.json").write_text(json.dumps(result,indent=2,ensure_ascii=False)+"\n",encoding="utf-8")
        print("IA2_ENET_RESULT",json.dumps(result,ensure_ascii=False),flush=True)
        valid=bool(reports["server"].get("valid_connection")) and bool(reports["server"].get("authority"))
        valid=valid and all(reports[x].get("join_ready",False) for x in ("client1","client2"))
        valid=valid and all(v.get("bots_seen",0)==28 for v in reports.values())
        valid=valid and len(during)>5 and int(reports["client1"].get("join_unix_ms",0))>0
        return 0 if valid else 2
    finally:
        gpu_stop.set()
        monitor.join(timeout=6)
        for role,out,proc in handles:
            if proc.poll() is None:
                proc.kill()
                proc.wait(timeout=8)
            out.close()
        (ROOT_OUT/f"STOP_{label}").unlink(missing_ok=True)

if __name__=="__main__":
    parser=argparse.ArgumentParser()
    parser.add_argument("--operation",choices=["favela","afghan"],default="favela")
    parser.add_argument("--cache",type=int,choices=[0,1],default=1)
    parser.add_argument("--port",type=int,default=39761)
    a=parser.parse_args()
    sys.exit(run_one(a.operation,a.cache,a.port))
