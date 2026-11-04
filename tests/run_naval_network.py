import sys
from pathlib import Path
import heapq
import json
import random
import select
import socket
import subprocess
import threading
import time

ROOT = Path.cwd()
GODOT = r'C:\Users\Joao Borges\Documents\Codex\tools\Godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe'
stop = threading.Event()
stats = {'datagrams': 0, 'dropped': 0, 'delay_ms': [20, 65]}

def proxy():
    sockets = []
    peers = {}
    upstreams = {}
    queue = []
    serial = 0
    rng = random.Random(5732)
    for port in (39321, 39322):
        sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        sock.bind(('127.0.0.1', port))
        sock.setblocking(False)
        sockets.append(sock)
    try:
        while not stop.is_set():
            for sock in select.select(sockets+list(upstreams), [], [], .003)[0]:
                try: data, source = sock.recvfrom(65536)
                except ConnectionResetError: continue
                stats['datagrams'] += 1
                if sock in upstreams:
                    outgoing,destination = upstreams[sock]
                else:
                    identity=(sock,source)
                    if identity not in peers:
                        relay=socket.socket(socket.AF_INET,socket.SOCK_DGRAM)
                        relay.bind(('127.0.0.1',0));relay.setblocking(False)
                        peers[identity]=relay;upstreams[relay]=(sock,source)
                    outgoing=peers[identity]
                    destination = ('127.0.0.1', 39320)
                if rng.random() < .05:
                    stats['dropped'] += 1
                    continue
                serial += 1
                heapq.heappush(queue, (time.monotonic()+rng.uniform(.020,.065),serial,outgoing,data,destination))
            while queue and queue[0][0] <= time.monotonic():
                _,_,sock,data,destination = heapq.heappop(queue)
                sock.sendto(data,destination)
    finally:
        stats['client_endpoints']=len(peers)
        for sock in sockets+list(upstreams): sock.close()

thread = threading.Thread(target=proxy,daemon=True)
thread.start()
processes = []
try:
    for role, port in [('server',39320),('a',39321),('b',39322)]:
        log = open(ROOT/'work'/f'naval-network-{role}.stdout.log','w',encoding='utf-8')
        result_path = ROOT/'tests'/f'naval-network-{role}.json'
        if result_path.exists(): result_path.unlink()
        args = [GODOT,'--headless','--path',str(ROOT),'--script','tests/naval_network.gd','--max-fps','60','--log-file',str(ROOT/'work'/f'naval-network-{role}.log'),'--','--naval-test-accounts',f'--role={role}',f'--naval-port={port}',f'--naval-data={ROOT/"work"/f"naval-net-data-{role}"}']
        args += [f'--game-tls-cert={ROOT}/work/security182/test.crt',f'--game-tls-key={ROOT}/work/security182/test.key',f'--game-tls-ca={ROOT}/work/security182/test.crt']
        if '--visual' in sys.argv and role == 'a':
            args.remove('--headless')
            args[1:1] = ['--screen','0','--resolution','960x640','--position','20,20' if role == 'a' else '740,20']
            args.append('--visual')
        process = subprocess.Popen(args,stdout=log,stderr=subprocess.STDOUT,creationflags=subprocess.CREATE_NO_WINDOW)
        processes.append((role,process,log))
        if role == 'server': time.sleep(.5)
    deadline = time.monotonic()+52
    while time.monotonic()<deadline and any(p.poll() is None for _,p,_ in processes): time.sleep(.1)
finally:
    stop.set()
    thread.join(2)
    for role,process,log in processes:
        if process.poll() is None: process.kill()
        log.close()
    print('TRANSPORT',stats)
failed = False
for role,process,_ in processes:
    result = ROOT/'tests'/f'naval-network-{role}.json'
    if not result.exists():
        print(role,(ROOT/'work'/f'naval-network-{role}.stdout.log').read_text(encoding='utf-8',errors='replace')[-6000:])
        failed = True
    else:
        report = json.loads(result.read_text())
        print(report)
        failed |= bool(report['failures']) or process.returncode != 0
        output = (ROOT/'work'/f'naval-network-{role}.stdout.log').read_text(encoding='utf-8',errors='replace')
        # Delayed datagrams from a closed DTLS session are intentionally
        # rejected during reconnection. Record them; fail all application errors.
        late_records=output.count('ERROR: TLS handshake error: -30464')
        stats['rejected_late_dtls_records']=stats.get('rejected_late_dtls_records',0)+late_records
        checked=output.replace('ERROR: TLS handshake error: -30464','DTLS_LATE_RECORD_REJECTED')
        if 'ERROR:' in checked.replace("ERROR: Can't create shader cache folder, no shader caching will happen: user://",'') or 'MTU' in output:
            print(output[-6000:]); failed = True
(ROOT/'tests'/'naval-network-transport.json').write_text(json.dumps(stats))
raise SystemExit(1 if failed else 0)
