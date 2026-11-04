"""Exercise the real PHP account endpoint against an isolated SQLite DB."""
from pathlib import Path
import hashlib,json,os,secrets,socket,sqlite3,subprocess,time,urllib.request,urllib.error

ROOT=Path(__file__).resolve().parents[1]
TEMP=ROOT/'work/ranking-api-test'
TEMP.mkdir(parents=True,exist_ok=True)
PRIVATE=TEMP/'private';PRIVATE.mkdir(exist_ok=True)
# Rankings never sign a profile; a nonempty fixture is enough for boot.
(PRIVATE/'signing.pem').write_text('isolated ranking fixture')
DB=PRIVATE/'accounts.sqlite'
if DB.exists(): DB.unlink()
con=sqlite3.connect(DB)
con.executescript('''CREATE TABLE users(id TEXT PRIMARY KEY,username TEXT UNIQUE NOT NULL,password TEXT NOT NULL,coins INTEGER NOT NULL,owned TEXT NOT NULL,selected TEXT NOT NULL,revision INTEGER NOT NULL DEFAULT 1,kills INTEGER NOT NULL DEFAULT 0,deaths INTEGER NOT NULL DEFAULT 0,appearance TEXT NOT NULL DEFAULT '{}');
CREATE TABLE sessions(token TEXT PRIMARY KEY,user_id TEXT NOT NULL,device TEXT NOT NULL,expires INTEGER NOT NULL);''')
for i in range(14):
    con.execute('INSERT INTO users(id,username,password,coins,owned,selected,kills,deaths) VALUES(?,?,?,?,?,?,?,?)',(str(i),f'player_{i:02d}','unused',i*100,'["light"]','light',30+i,14-i))
con.execute('INSERT INTO users(id,username,password,coins,owned,selected,kills,deaths) VALUES(?,?,?,?,?,?,?,?)',('tiny','tiny_sample','unused',2,'["light"]','light',1,0))
token=secrets.token_hex(32)
con.execute('INSERT INTO sessions VALUES(?,?,?,?)',(hashlib.sha256(token.encode()).hexdigest(),'0','fixture',int(time.time())+300));con.commit()
service=secrets.token_hex(32);(PRIVATE/'service-token.sha256').write_text(hashlib.sha256(service.encode()).hexdigest())
router=TEMP/'router.php';router.write_text('<?php $_SERVER["HTTPS"]="on"; require '+json.dumps(str(ROOT/'account-service/api.php').replace('\\','/'))+';')
sock=socket.socket();sock.bind(('127.0.0.1',0));port=sock.getsockname()[1];sock.close()
env=os.environ.copy();env['TDC_ACCOUNTS_STORAGE']=str(PRIVATE)
log=(TEMP/'server.log').open('w')
proc=subprocess.Popen([r'C:\xampp\php\php.exe','-S',f'127.0.0.1:{port}',str(router)],env=env,stdout=log,stderr=log,creationflags=subprocess.CREATE_NO_WINDOW)
checks=[]
def check(ok,label):
    checks.append({'ok':bool(ok),'label':label});print(('PASS ' if ok else 'FAIL ')+label,flush=True)
    if not ok: raise AssertionError(label)
def call(auth=None,extra=None):
    headers={'Content-Type':'application/json'}
    if auth:headers['Authorization']=auth
    req=urllib.request.Request(f'http://127.0.0.1:{port}/api.php',json.dumps({'action':'rankings',**(extra or {})}).encode(),headers)
    try:
        with urllib.request.urlopen(req,timeout=10) as response:return response.status,json.load(response)
    except urllib.error.HTTPError as error:return error.code,json.load(error)
try:
    time.sleep(.5)
    check(call()[0]==401,'unauthenticated ranking is rejected')
    check(call('Service '+service)[0]==403,'service capability does not expose unrelated user endpoints')
    code,first=call('Bearer '+token,{'coins':999999999,'order':'DROP TABLE users'})
    check(code==200 and first['ok'] and not first['cached'],'first authenticated request creates a server snapshot')
    data=first['rankings'];lists=data['lists']
    check(set(lists)=={'kills','kd','deaths','coins'} and all(len(v)==10 for v in lists.values()),'four top-ten classifications are generated')
    check(lists['coins'][0]['coins']==1300 and lists['coins'][0]['name']=='player_13','money comes from server balance, ignoring client-supplied values')
    check(lists['kills'][0]['kills']==43 and lists['deaths'][0]['deaths']==14,'kill/death order uses persistent counters')
    check(all(v['name']!='tiny_sample' for v in lists['kd']) and data['kd_min_participation']==20,'K/D excludes insufficient participation')
    check(all(set(v)=={'name','kills','deaths','coins','kd'} for rows in lists.values() for v in rows),'no IDs, password hashes or session data are exposed')
    con.execute('UPDATE users SET coins=7777,deaths=0,kills=50 WHERE id="0"');con.commit()
    _,cached=call('Bearer '+token)
    check(cached['cached'] and cached['rankings']==data,'opening again reuses the hourly cache after account changes')
    con.execute('UPDATE server_cache SET created=0');con.commit()
    _,fresh=call('Bearer '+token)
    check(not fresh['cached'] and fresh['rankings']['lists']['coins'][0]['coins']==7777,'hourly expiry refreshes current persistent balances')
    check(fresh['rankings']['lists']['kd'][0]['kd']==50,'zero deaths uses a safe denominator')
    check(con.execute('SELECT COUNT(*) FROM users').fetchone()[0]==15,'existing account schema/data is preserved')
finally:
    proc.terminate();proc.wait(timeout=10);log.close();con.close()
    (ROOT/'tests/account-rankings-results.json').write_text(json.dumps({'checks':checks},indent=2))
