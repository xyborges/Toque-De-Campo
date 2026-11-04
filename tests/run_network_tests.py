import subprocess,threading,socket,select,time,heapq,random,json
from pathlib import Path
base=Path.cwd(); exe=r'C:\Users\Joao Borges\Documents\Codex\tools\Godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe'
for role_name in ('shooter','target'):
 ready_file=base/'tests'/('network-ready-'+role_name+'.txt')
 if ready_file.exists():ready_file.unlink()
stop=threading.Event(); stats={'datagrams':0,'dropped':0,'delay_ms':[20,70]}; rng=random.Random(426)
def proxy():
 # Give each client UDP endpoint its own upstream endpoint. Reusing one
 # upstream socket for successive ENet sessions used to mix delayed packets
 # from the departed client into its replacement, unlike separate PC sockets.
 listeners=[]; upstreams={}; sessions={}; pending=[]; serial=0
 for port in (39123,39124):
  sock=socket.socket(socket.AF_INET,socket.SOCK_DGRAM);sock.bind(('127.0.0.1',port));sock.setblocking(False);listeners.append(sock)
 try:
  while not stop.is_set():
   ready,_,_=select.select(listeners+list(upstreams),[],[],.005)
   for sock in ready:
    try: data,src=sock.recvfrom(65536)
    except ConnectionResetError: continue
    stats['datagrams']+=1
    if sock in upstreams:
     outgoing,dst=upstreams[sock]
    else:
     key=(sock,src)
     if key not in sessions:
      relay=socket.socket(socket.AF_INET,socket.SOCK_DGRAM);relay.bind(('127.0.0.1',0));relay.setblocking(False)
      sessions[key]=relay;upstreams[relay]=(sock,src)
     outgoing=sessions[key];dst=('127.0.0.1',39122)
    if rng.random()<.08: stats['dropped']+=1;continue
    serial+=1;heapq.heappush(pending,(time.monotonic()+rng.uniform(.020,.070),serial,outgoing,data,dst))
   while pending and pending[0][0]<=time.monotonic():
    _,_,sock,data,dst=heapq.heappop(pending);sock.sendto(data,dst)
 finally:
  stats['client_endpoints']=len(sessions)
  for sock in listeners+list(upstreams):sock.close()
thread=threading.Thread(target=proxy,daemon=True);thread.start()
processes=[];logs=[]
try:
 for role in ('server','shooter','target'):
  result=base/'tests'/('network-'+role+'-results.json')
  if result.exists():result.unlink()
  log=(base/'work'/('network-'+role+'.stdout.log')).open('w',encoding='utf-8');logs.append(log)
  args=[exe,'--headless','--path',str(base),'--script','tests/network_combat.gd','--log-file',str(base/'work'/('network-'+role+'.godot.log')),'--','--role='+role]
  args += [f'--game-tls-cert={base}/work/security182/test.crt',f'--game-tls-key={base}/work/security182/test.key',f'--game-tls-ca={base}/work/security182/test.crt']
  processes.append((role,subprocess.Popen(args,stdout=log,stderr=subprocess.STDOUT,creationflags=subprocess.CREATE_NO_WINDOW)))
  if role=='server':time.sleep(.6)
 deadline=time.monotonic()+48
 while time.monotonic()<deadline and any(p.poll() is None for _,p in processes):time.sleep(.1)
 for role,p in processes:
  if p.poll() is None:p.terminate();print(role,'TIMEOUT')
  else:print(role,'EXIT',p.returncode)
finally:
 stop.set();thread.join(2)
 for _,p in processes:
  if p.poll() is None:p.kill()
 for log in logs:log.close()
 (base/'tests/network-transport-results.json').write_text(json.dumps(stats),encoding='utf-8')
 print('TRANSPORT',stats)
 for role,_ in processes:
  path=base/'tests'/('network-'+role+'-results.json')
  if path.exists():print(path.name,path.read_text())
  else:print((base/'work'/('network-'+role+'.stdout.log')).read_text(encoding='utf-8',errors='replace')[-5000:])

reports=[json.loads((base/'tests'/('network-'+role+'-results.json')).read_text()) for role,_ in processes if (base/'tests'/('network-'+role+'-results.json')).exists()]
if len(reports)==3:
 print('DEATH_AUDIO_IDENTICAL',len({r['death_audio_index'] for r in reports})==1)
 if len({r['death_audio_index'] for r in reports})!=1: raise SystemExit(1)
if any(p.returncode!=0 for _,p in processes):raise SystemExit(1)

if len(reports)!=3 or any(r['failures'] for r in reports):raise SystemExit(1)
for role,_ in processes:
 text=(base/'work'/('network-'+role+'.stdout.log')).read_text(encoding='utf-8',errors='replace')
 if 'ERROR:' in text:raise SystemExit(1)
