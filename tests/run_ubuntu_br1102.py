"""Explicitly gated three-client BR build73 production verification.
Default mode only checks local sources. --run-live must be requested explicitly.
"""
from pathlib import Path
import argparse, base64, json, re, shlex, ssl, subprocess, sys, time, urllib.request, zipfile
ROOT=Path(__file__).resolve().parent.parent
ENGINE=Path(r'C:\Users\Joao Borges\Documents\Codex\tools\Godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe')
ROLES=('host','guest','third')

def server_close_evidence(reports):
    # Only a bounded read of the tested room is authorized here. No service,
    # process, database, deployment or firewall mutation is performed.
    rooms={str(row.get('metrics',{}).get('route_room','')) for row in reports.values()}
    peers=[int(row.get('metrics',{}).get('local_peer',0)) for row in reports.values()]
    if len(rooms)!=1 or not all(re.fullmatch('[a-f0-9]{32}',room) for room in rooms):
        return {'ok':False,'error':'clients did not identify one room'}
    room=next(iter(rooms))
    sys.path.insert(0,str(ROOT/'work/ssh-runtime'))
    import paramiko
    credential=Path.home()/'.codex/credentials/toque-microgate-192.168.101.24.dpapi'
    cmd="$encrypted=(Get-Content -LiteralPath '"+str(credential)+"' -Raw).Trim();$secret=ConvertTo-SecureString $encrypted;$pointer=[Runtime.InteropServices.Marshal]::SecureStringToBSTR($secret);try {[Console]::Write([Runtime.InteropServices.Marshal]::PtrToStringBSTR($pointer))} finally {[Runtime.InteropServices.Marshal]::ZeroFreeBSTR($pointer);$secret.Dispose()}"
    secret=subprocess.run(['pwsh.exe','-NoProfile','-NonInteractive','-Command',cmd],capture_output=True,check=True).stdout.decode()
    probe="""import pathlib,json,time
base=pathlib.Path('/var/lib/toque-de-campo/game/br-matches')/ROOM
status={}
for attempt in range(12):
 try:status=json.loads((base/'status.json').read_text())
 except:pass
 if status.get('phase')=='cancelled' and status.get('humans')==0:break
 time.sleep(.5)
events=[];peer_files=[]
for path in (base/'diagnostics').glob('*.jsonl'):
 if '-peer-' in path.name:
  if any(path.name.endswith('-peer-%d.jsonl'%p) for p in PEERS):peer_files.append(path.name)
  continue
 for line in path.read_text(errors='replace').splitlines():
  try:row=json.loads(line)
  except:continue
  if row.get('event') in ['boot','br_admitted','br_client_ready','br_round_start','br_peer_disconnected','br_sync_timeout','br_admission_rejected','engine_error']:
   d=row.get('details',{});events.append({'event':row.get('event'),'utc':row.get('utc'),'peer':d.get('peer'),'generation':d.get('generation'),'build':d.get('build'),'reason':d.get('reason')})
print(json.dumps({'ok':status.get('phase')=='cancelled' and status.get('humans')==0,'phase':status.get('phase'),'humans':status.get('humans'),'room':ROOM,'peer_files':peer_files,'events':events[-100:],'scope':'Bounded read-only room status and sanitized session/peer event metadata; no native microphone or audibility claim'}))
""".replace('ROOM',repr(room)).replace('PEERS',repr(peers))
    ssh=paramiko.SSHClient();ssh.load_host_keys(str(ROOT/'distribution/private/ubuntu_known_hosts'));ssh.set_missing_host_key_policy(paramiko.RejectPolicy())
    try:
        ssh.connect('192.168.101.24',username='microgate',key_filename=str(ROOT/'distribution/private/ubuntu_deploy_rsa'),look_for_keys=False,allow_agent=False,timeout=15)
        inp,out,err=ssh.exec_command("sudo -S -p '' -- /usr/bin/python3 -c "+shlex.quote(probe),timeout=25)
        inp.write(secret+'\n');inp.flush();inp.channel.shutdown_write()
        data=out.read().decode();error=err.read().decode();code=out.channel.recv_exit_status()
        if code:raise RuntimeError(error.replace(secret,'[redacted]'))
        return json.loads(data)
    finally:secret='';ssh.close()

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--run-live',action='store_true')
    parser.add_argument('--prepare-only',action='store_true')
    parser.add_argument('--expected-build',type=int,default=73)
    args=parser.parse_args()
    cmd=[str(ENGINE),'--headless','--path',str(ROOT),'--script','tests/ubuntu_br1102.gd','--check-only','--log-file',str(ROOT/'work/ubuntu-br1102-parse.log')]
    prepared=subprocess.run(cmd,cwd=ROOT,capture_output=True,text=True,encoding='utf8',errors='replace',timeout=45,creationflags=subprocess.CREATE_NO_WINDOW)
    if prepared.returncode or 'SCRIPT ERROR' in prepared.stdout+prepared.stderr:raise SystemExit('Source parsing failed; inspect work/ubuntu-br1102-parse.log')
    for name in ['naval-e2e-credentials.json','ubuntu-war-passenger-credentials.json']:
        if not (ROOT/'work'/name).is_file():raise SystemExit('Existing private QA credentials unavailable')
    if args.prepare_only or not args.run_live:
        print('PREPARED BR1102: source checks passed; three existing QA accounts; no login, broker, server process or publication attempted. Await explicit --run-live authorization.')
        return
    context=ssl.create_default_context(cafile=str(ROOT/'assets/accounts/accounts-ca.crt'))
    with urllib.request.urlopen('https://192.168.101.24/manifest.json',context=context,timeout=20) as response:manifest=json.load(response)
    payload=json.loads(base64.b64decode(manifest['payload']))
    if payload.get('version')!=args.expected_build or payload.get('version_name')!='1.10.2':raise SystemExit('Published build is not approved1.10.2/build'+str(args.expected_build)+'; refusing live clients')
    jobs=[]
    for role in ROLES:
        for suffix in ['.json','.stage.json']:(ROOT/f'work/ubuntu-br1102-{role}{suffix}').unlink(missing_ok=True)
    reports={};failed=[]
    try:
        for role in ROLES:
            output=(ROOT/f'work/ubuntu-br1102-{role}.stdout.log').open('w',encoding='utf8')
            cmd=[str(ENGINE),'--headless','--audio-driver','Dummy','--max-fps','60','--path',str(ROOT),'--script','tests/ubuntu_br1102.gd','--log-file',str(ROOT/f'work/ubuntu-br1102-{role}.log'),'--','--role='+role,'--naval-data='+str(ROOT/f'work/ubuntu-br1102-{role}-account-data')]
            jobs.append((role,subprocess.Popen(cmd,cwd=ROOT,stdout=output,stderr=subprocess.STDOUT,creationflags=subprocess.CREATE_NO_WINDOW),output));time.sleep(.4)
        limit=time.monotonic()+215
        while time.monotonic()<limit and any(p.poll() is None for _,p,_ in jobs):time.sleep(.25)
        for role,process,output in jobs:
            output.flush();path=ROOT/f'work/ubuntu-br1102-{role}.json'
            report=json.loads(path.read_text()) if path.is_file() else {'ok':False,'failures':['no final report']}
            content=(ROOT/f'work/ubuntu-br1102-{role}.stdout.log').read_text(errors='replace')
            report.update(exit_code=process.poll(),log_errors='SCRIPT ERROR:' in content or '\nERROR:' in content,buffer_full='Buffer full, dropping packets!' in content)
            archive=Path(report.get('metrics',{}).get('diagnostic_zip',''))
            report['diagnostics']={'ok':False,'events':[]}
            if archive.is_file():
                with zipfile.ZipFile(archive) as zipped:
                    rows=[]
                    for name in zipped.namelist():
                        if name.endswith('.jsonl'):
                            for line in zipped.read(name).decode(errors='replace').splitlines():
                                try:rows.append(json.loads(line))
                                except:pass
                    report['diagnostics']={'ok':bool(rows),'jsonl_files':len(zipped.namelist()),'events':sorted(set(str(row.get('event','')) for row in rows)),'bytes':archive.stat().st_size}
            reports[role]=report
            if process.poll()!=0 or not report.get('ok') or report['log_errors'] or not report['diagnostics']['ok']:failed.append(role)
        close=server_close_evidence(reports) if not failed else {'ok':False,'skipped':'clients failed'}
        summary={'ok':not failed and close.get('ok',False),'expected_build':args.expected_build,'published_version':payload['version_name'],'clients':reports,'failed':failed,'server_close':close,'server':'192.168.101.24','broker_port':3016,'parallelism_scope':'one shared real room with3humans+28bots; two-room capacity not measured'}
        (ROOT/'work/ubuntu-br1102-summary.json').write_text(json.dumps(summary,indent=2),encoding='utf8')
        print(json.dumps({'ok':summary['ok'],'failed':failed,'server_close':close,'clients':{k:{'checks':v.get('checks'),'failures':v.get('failures'),'log_errors':v['log_errors'],'buffer_full':v['buffer_full'],'route':v.get('route'),'diagnostics':v['diagnostics']} for k,v in reports.items()}}),flush=True)
        if not summary['ok']:raise SystemExit(1)
    finally:
        for _,p,output in jobs:
            if p.poll() is None:
                p.terminate()
                try:p.wait(timeout=5)
                except subprocess.TimeoutExpired:p.kill();p.wait(timeout=5)
            output.close()

if __name__=='__main__':main()
