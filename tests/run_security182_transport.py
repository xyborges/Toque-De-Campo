from pathlib import Path
import json,os,select,socket,subprocess,threading,time
root=Path(__file__).resolve().parents[1];folder=root/'work/security182'
engine=r'C:/Users/Joao Borges/Documents/Codex/tools/Godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe'
records=[];negative_counts={};stop=threading.Event();proxy_errors=[]
def proxy():
    udp=socket.socket(socket.AF_INET,socket.SOCK_DGRAM);udp.bind(('127.0.0.1',39598));udp.setblocking(False)
    client=None
    try:
        while not stop.is_set():
            if not select.select([udp],[],[],.05)[0]:continue
            try:data,source=udp.recvfrom(65535)
            except ConnectionResetError:continue # Expected ICMP after the test closes/reopens its server socket.
            phase=(folder/'wire-phase.txt').read_text() if (folder/'wire-phase.txt').exists() else ''
            if phase=='encrypted':records.append(data)
            else:negative_counts[phase]=negative_counts.get(phase,0)+1
            if source[1]==39597:
                if client:udp.sendto(data,client)
            else:client=source;udp.sendto(data,('127.0.0.1',39597))
    except Exception as error:proxy_errors.append(str(error))
    finally:udp.close()
thread=threading.Thread(target=proxy);thread.start()
try:
    env=os.environ.copy();env['APPDATA']=str(Path.home()/'Documents/Codex/q182/transport');Path(env['APPDATA']).mkdir(parents=True,exist_ok=True)
    command=[engine,'--headless','--path',str(root),'--script','res://tests/security182_transport.gd','--',f'--game-tls-cert={folder}/test.crt',f'--game-tls-key={folder}/test.key',f'--game-tls-ca={folder}/test.crt']
    result=subprocess.run(command,cwd=root,env=env,capture_output=True,text=True,timeout=35)
    (folder/'transport.log').write_text(result.stdout+result.stderr,encoding='utf-8')
    print(result.stdout);print(result.stderr[-1500:])
    assert result.returncode==0,'Godot transport tests failed'
finally:stop.set();thread.join()
marker=b'TDC_PRIVATE_RPC_MARKER_182_6ae8b98e'
assert len(records)>3,'No captured DTLS traffic'
assert not proxy_errors,proxy_errors
assert negative_counts.get('untrusted',0)>2 and negative_counts.get('plaintext',0)>0,'Negative cases did not traverse the live proxy'
assert not any(marker in packet for packet in records),'Application payload leaked in plaintext'
assert all(len(packet)>=13 and packet[0] in (20,21,22,23) and packet[1]==254 for packet in records),'Unencrypted packet observed during the positive DTLS test'
report={'captured_datagrams':len(records),'all_dtls_records':True,'plaintext_application_marker_found':False,'negative_case_datagrams':negative_counts,'negative_cases':['untrusted CA rejected','unencrypted ENet rejected']}
(folder/'wire-results.json').write_text(json.dumps(report,indent=2));print(json.dumps(report))
