"""Exercise account/server capabilities against real PHP and isolated SQLite.

No production credentials, accounts, services or network hosts are accessed.
The local-only router supplies HTTPS=on; production TLS enforcement is unchanged.
"""
from pathlib import Path
import hashlib
import json
import os
import secrets
import socket
import sqlite3
import subprocess
import time
import urllib.error
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
TEMP = ROOT / 'work/account-authority-test'
TEMP.mkdir(parents=True, exist_ok=True)
PRIVATE = TEMP / 'private'
PRIVATE.mkdir(exist_ok=True)
PHP = r'C:\xampp\php\php.exe'
env = os.environ.copy()
env['TDC_ACCOUNTS_STORAGE'] = str(PRIVATE)
env['OPENSSL_CONF'] = r'C:\xampp\apache\conf\openssl.cnf'
bootstrap = r'''
$server=openssl_pkey_new(['private_key_bits'=>2048,'private_key_type'=>OPENSSL_KEYTYPE_RSA]);
if (!$server || !openssl_pkey_export($server,$pem)) exit(1);
file_put_contents(getenv('TDC_ACCOUNTS_STORAGE').'/signing.pem',$pem);
$device=openssl_pkey_new(['private_key_bits'=>2048,'private_key_type'=>OPENSSL_KEYTYPE_RSA]);
$public=openssl_pkey_get_details($device)['key'];$nonce=bin2hex(random_bytes(16));
openssl_sign('tdc-auth:authority_user:'.$nonce,$proof,$device,OPENSSL_ALGO_SHA256);
echo json_encode(['password'=>password_hash('test-only-password-123!',PASSWORD_ARGON2ID,['memory_cost'=>8192,'time_cost'=>1,'threads'=>1]),'public_key'=>$public,'nonce'=>$nonce,'proof'=>base64_encode($proof)]);
'''
identity = json.loads(subprocess.check_output([PHP, '-r', bootstrap], env=env))
DB = PRIVATE / 'accounts.sqlite'
for suffix in ('', '-wal', '-shm'):
    path = Path(str(DB) + suffix)
    if path.exists():
        path.unlink()
con = sqlite3.connect(DB)
con.executescript('''CREATE TABLE users(id TEXT PRIMARY KEY,username TEXT UNIQUE NOT NULL,password TEXT NOT NULL,coins INTEGER NOT NULL,owned TEXT NOT NULL,selected TEXT NOT NULL,revision INTEGER NOT NULL DEFAULT 1,kills INTEGER NOT NULL DEFAULT 0,deaths INTEGER NOT NULL DEFAULT 0,appearance TEXT NOT NULL DEFAULT '{}');
CREATE TABLE sessions(token TEXT PRIMARY KEY,user_id TEXT NOT NULL,device TEXT NOT NULL,expires INTEGER NOT NULL);''')
killer, victim, outsider = ('1' * 32, '2' * 32, '3' * 32)
for identifier, username in ((killer, 'authority_user'), (victim, 'victim_user'), (outsider, 'outsider_user')):
    con.execute('INSERT INTO users(id,username,password,coins,owned,selected) VALUES(?,?,?,?,?,?)',
                (identifier, username, identity['password'], 5000, '["light"]', 'light'))
token, service = secrets.token_hex(32), secrets.token_hex(32)
con.execute('INSERT INTO sessions VALUES(?,?,?,?)',
            (hashlib.sha256(token.encode()).hexdigest(), killer, 'fixture', int(time.time()) + 300))
con.commit()
(PRIVATE / 'service-token.sha256').write_text(hashlib.sha256(service.encode()).hexdigest())
router = TEMP / 'router.php'
router.write_text('<?php $_SERVER["HTTPS"]="on"; require ' + json.dumps(str(ROOT / 'account-service/api.php').replace('\\', '/')) + ';')
sock = socket.socket()
sock.bind(('127.0.0.1', 0))
port = sock.getsockname()[1]
sock.close()
log = (TEMP / 'server.log').open('w')
proc = subprocess.Popen([PHP, '-S', f'127.0.0.1:{port}', str(router)], env=env,
                        stdout=log, stderr=log, creationflags=getattr(subprocess, 'CREATE_NO_WINDOW', 0))
checks = []


def check(ok, label):
    checks.append({'ok': bool(ok), 'label': label})
    print(('PASS ' if ok else 'FAIL ') + label, flush=True)
    if not ok:
        raise AssertionError(label)


def call(action, auth=None, **values):
    headers = {'Content-Type': 'application/json'}
    if auth:
        headers['Authorization'] = auth
    request = urllib.request.Request(f'http://127.0.0.1:{port}/api.php',
                                     json.dumps({'action': action, **values}).encode(), headers)
    try:
        with urllib.request.urlopen(request, timeout=10) as response:
            return response.status, json.load(response)
    except urllib.error.HTTPError as error:
        return error.code, json.load(error)


def account(identifier):
    return con.execute('SELECT coins,kills,deaths,revision FROM users WHERE id=?', (identifier,)).fetchone()


try:
    deadline = time.monotonic() + 5
    while True:
        try:
            with urllib.request.urlopen(f'http://127.0.0.1:{port}/api.php', timeout=1) as response:
                json.load(response)
            break
        except (urllib.error.URLError, ConnectionError):
            if time.monotonic() >= deadline:
                raise
            time.sleep(.05)
    bearer, authority = 'Bearer ' + token, 'Service ' + service
    other_token = secrets.token_hex(32)
    con.execute('INSERT INTO sessions VALUES(?,?,?,?)',
                (hashlib.sha256(other_token.encode()).hexdigest(), outsider, 'other-device', int(time.time()) + 300))
    con.commit()
    other_bearer = 'Bearer ' + other_token
    check(call('preferences_get')[0] == 401, 'preferences require authentication')
    check(call('preferences_get', authority)[0] == 403, 'game service cannot read player preferences')
    check(call('preferences_get', bearer)[1]['settings'] == {}, 'new account starts with no cloud preferences')
    settings={'game':{'aa':2,'fps':60},'aim':{'schema':2,'profiles':{'weapon:fal':{'normal':.72,'aim':.65}}}}
    check(call('preferences_set', bearer, sections=settings)[0] == 200, 'authenticated player stores settings')
    check(call('preferences_get', bearer)[1]['settings'] == settings, 'settings are returned to the same account')
    check(call('preferences_get', other_bearer)[1]['settings'] == {}, 'another account cannot read those settings')
    check(call('preferences_set', other_bearer, sections={'game':{'aa':1}})[0] == 200, 'second account stores separate settings')
    check(call('preferences_get', bearer)[1]['settings'] == settings, 'second account cannot overwrite first account')
    check(call('preferences_set', bearer, sections={'audio':{'Music':.4}})[0] == 200 and
          call('preferences_get', bearer)[1]['settings']['aim'] == settings['aim'], 'updating one category preserves others')
    check(call('preferences_set', bearer, sections={'account_id':{'value':1}})[0] == 400, 'unknown preference category is rejected')
    check(call('preferences_set', bearer, sections={'game':{'data':'injected'}})[0] == 400, 'non-numeric preference data is rejected')
    check(call('match_register', match=secrets.token_hex(16), players=[killer, victim])[0] == 401,
          'match authority requires authentication')
    check(call('match_register', 'Service ' + '0' * 64, match=secrets.token_hex(16), players=[killer, victim])[0] == 401,
          'incorrect service capability is rejected')
    for mode in ('naval', 'infantry', 'war'):
        match = secrets.token_hex(16)
        values = {'match': match, 'mode': mode, 'players': [killer, victim],
                  'event': match + ':fake-kill', 'killer': killer, 'victim': victim, 'account': victim}
        for action in ('match_register', 'reward', 'match_wallet'):
            code, result = call(action, bearer, **values)
            check(code == 403 and not result['ok'] and 'account' not in result,
                  mode + ': normal account cannot call ' + action)
    check(con.execute('SELECT COUNT(*) FROM matches').fetchone()[0] == 0 and
          con.execute('SELECT COUNT(*) FROM rewards').fetchone()[0] == 0 and account(killer)[:3] == (5000, 0, 0),
          'rejected client requests do not create matches, kills or money')
    for action in ('profile', 'rankings', 'buy', 'select', 'appearance', 'logout'):
        check(call(action, authority)[0] == 403, 'service remains restricted from user action ' + action)
    expected_coins = 5000
    for mode, payout in (('naval', 100), ('infantry', 30), ('war', 30)):
        match = secrets.token_hex(16)
        check(call('match_register', authority, match=match, mode=mode, players=[killer, victim])[0] == 200,
              mode + ': dedicated service registers the match')
        check(call('match_register', authority, match=match, mode=mode, players=[killer, victim])[0] == 200,
              mode + ': registering the same roster is idempotent')
        other_mode = 'war' if mode != 'war' else 'naval'
        check(call('match_register', authority, match=match, mode=other_mode, players=[killer, victim])[0] == 409,
              mode + ': registered rules cannot be changed to another payout mode')
        check(call('match_wallet', authority, match=match, account=outsider)[0] == 403,
              mode + ': wallet access requires actual match participation')
        for action in ('match_register', 'reward', 'match_wallet'):
            check(call(action, bearer, match=match, mode=mode, players=[killer, victim], account=victim,
                       event=match + ':fake-kill', killer=killer, victim=victim)[0] == 403,
                  mode + ': bearer remains rejected for a genuine server match (' + action + ')')
        event = match + ':authoritative-death'
        payload = {'match': match, 'event': event, 'killer': killer, 'victim': victim}
        check(call('reward', authority, **payload)[0] == 200, mode + ': valid server death awards a reward')
        expected_coins += payout
        before_killer, before_victim = account(killer), account(victim)
        check(before_killer[0] == expected_coins, mode + ': exact server-controlled payout is persisted')
        check(call('reward', authority, **payload)[0] == 200 and account(killer) == before_killer and account(victim) == before_victim,
              mode + ': duplicate death never adds money, kills, deaths or revision')
        check(call('reward', authority, **{**payload, 'event': event + ':another'})[0] == 429,
              mode + ': rapid repeat-victim farming is rejected')
        code, wallet = call('match_wallet', authority, match=match, account=killer)
        check(code == 200 and wallet['account']['coins'] == expected_coins,
              mode + ': dedicated server receives the confirmed wallet')
        con.execute('UPDATE matches SET expires=? WHERE id=?', (int(time.time()) - 1, match))
        con.commit()
        check(call('reward', authority, **{**payload, 'event': event + ':expired'})[0] == 403 and
              call('match_wallet', authority, match=match, account=killer)[0] == 403,
              mode + ': expired match cannot reward or read wallets')
    check(account(killer)[1:3] == (3, 0) and account(victim)[1:3] == (0, 3),
          'only the three authoritative deaths affect lifetime statistics')
    # Keep the original three-mode assertions above unchanged. These additional
    # cases exercise death-only persistence, independently of kill payouts.
    check(call('match_death', match=secrets.token_hex(16), event='unauthenticated-death', victim=victim)[0] == 401,
          'death-only persistence requires authentication')
    check(call('match_death', 'Service ' + '0' * 64, match=secrets.token_hex(16),
               event='invalid-service-death', victim=victim)[0] == 401,
          'death-only persistence rejects an invalid service capability')
    for mode, payout in (('naval', 100), ('infantry', 30), ('war', 30)):
        match = secrets.token_hex(16)
        check(call('match_register', authority, match=match, mode=mode, players=[killer, victim])[0] == 200,
              mode + ': service registers a death-only test match')
        before_killer, before_victim = account(killer), account(victim)
        check(call('match_death', bearer, match=match, event=match + ':bearer', victim=victim)[0] == 403,
              mode + ': bearer cannot persist a death even in a genuine server match')
        check(call('match_death', authority, match=match, event=match + ':outsider', victim=outsider)[0] == 403,
              mode + ': death victim must be an actual match participant')
        check(account(killer) == before_killer and account(victim) == before_victim,
              mode + ': refused death events do not change money, statistics or revision')
        for cause, dead, other in (('environment', victim, killer), ('self', killer, victim)):
            event = match + ':' + cause
            before, other_before = account(dead), account(other)
            check(call('match_death', authority, match=match, event=event, victim=dead)[0] == 200 and
                  account(dead) == (before[0], before[1], before[2] + 1, before[3] + 1) and
                  account(other) == other_before,
                  mode + ': ' + cause + ' death increments only the victim death and revision')
            after = account(dead)
            check(call('match_death', authority, match=match, event=event, victim=dead)[0] == 200 and
                  account(dead) == after and account(other) == other_before,
                  mode + ': duplicate ' + cause + ' death changes no counter, wallet or revision')
            check(con.execute('SELECT victim FROM match_deaths WHERE match_id=? AND event=?',
                              (match, event)).fetchone() == (dead,),
                  mode + ': ' + cause + ' death has one durable server event')
        event = match + ':environment'
        before_killer, before_victim = account(killer), account(victim)
        check(call('match_death', authority, match=match, event=event, victim=killer)[0] == 409 and
              account(killer) == before_killer and account(victim) == before_victim,
              mode + ': reusing a death event for a different victim is rejected atomically')
        check(call('reward', authority, match=match, event=event, killer=victim, victim=killer)[0] == 409 and
              account(killer) == before_killer and account(victim) == before_victim,
              mode + ': a conflicting reward cannot redirect an already recorded death')
        con.execute('UPDATE matches SET expires=? WHERE id=?', (int(time.time()) - 1, match))
        con.commit()
        check(call('match_death', authority, match=match, event=match + ':expired', victim=victim)[0] == 403 and
              account(killer) == before_killer and account(victim) == before_victim,
              mode + ': expired match cannot persist a death')

        # A reliable retry may arrive before or after the kill/reward message.
        # The two operations deliberately share the same victim-life event key.
        for order in ('death-first', 'reward-first'):
            match = secrets.token_hex(16)
            check(call('match_register', authority, match=match, mode=mode, players=[killer, victim])[0] == 200,
                  mode + ': service registers ' + order + ' test match')
            event = match + ':' + order
            payload = {'match': match, 'event': event, 'killer': killer, 'victim': victim}
            before_killer, before_victim = account(killer), account(victim)
            first, second = ('match_death', 'reward') if order == 'death-first' else ('reward', 'match_death')
            check(call(first, authority, **payload)[0] == 200,
                  mode + ': ' + order + ' accepts the first authoritative event')
            if first == 'match_death':
                check(account(killer) == before_killer and
                      account(victim) == (before_victim[0], before_victim[1], before_victim[2] + 1, before_victim[3] + 1),
                      mode + ': early death does not pre-award a kill or coins')
            check(call(second, authority, **payload)[0] == 200 and
                  account(killer) == (before_killer[0] + payout, before_killer[1] + 1, before_killer[2], before_killer[3] + 1) and
                  account(victim) == (before_victim[0], before_victim[1], before_victim[2] + 1, before_victim[3] + 1),
                  mode + ': ' + order + ' records exactly one death, kill and payout')
            expected_coins += payout
            after_killer, after_victim = account(killer), account(victim)
            check(call('reward', authority, **payload)[0] == 200 and call('match_death', authority, **payload)[0] == 200 and
                  account(killer) == after_killer and account(victim) == after_victim,
                  mode + ': retries of both ' + order + ' messages do not change revision or totals')
            check(con.execute('SELECT COUNT(*) FROM match_deaths WHERE match_id=? AND event=?', (match, event)).fetchone()[0] == 1 and
                  con.execute('SELECT COUNT(*) FROM rewards WHERE match_id=? AND event=?', (match, event)).fetchone()[0] == 1,
                  mode + ': ' + order + ' uses one durable death and one durable reward record')

        match, event = secrets.token_hex(16), secrets.token_hex(32)
        check(call('match_register', authority, match=match, mode=mode, players=[killer, victim])[0] == 200,
              mode + ': service registers historical-reward migration fixture')
        # Reproduce an old release's rows/counters, which predate match_deaths.
        # SQL is fixture preparation only; all migration/retry checks use PHP.
        con.execute('INSERT INTO rewards VALUES(?,?,?,?)', (match, event, victim, int(time.time()) - 10))
        con.execute('UPDATE users SET coins=coins+?,kills=kills+1,revision=revision+1 WHERE id=?', (payout, killer))
        con.execute('UPDATE users SET deaths=deaths+1,revision=revision+1 WHERE id=?', (victim,))
        con.commit()
        expected_coins += payout
        before_killer, before_victim = account(killer), account(victim)
        check(call('match_death', authority, match=match, event=event, victim=victim)[0] == 200 and
              account(killer) == before_killer and account(victim) == before_victim,
              mode + ': migrating a historical rewarded death never counts it again')
        check(call('match_death', authority, match=match, event=event, victim=victim)[0] == 200 and
              call('reward', authority, match=match, event=event, killer=killer, victim=victim)[0] == 200 and
              account(killer) == before_killer and account(victim) == before_victim,
              mode + ': historical death/reward retries preserve counters and revision')
        check(con.execute('SELECT victim FROM match_deaths WHERE match_id=? AND event=?', (match, event)).fetchone() == (victim,),
              mode + ': historical death is added to deduplication storage without a second increment')
    # Records created by an old account-hosted client must not restore the old
    # privilege: authorization is checked before looking up match ownership.
    legacy_match = secrets.token_hex(16)
    con.execute('INSERT INTO matches(id,host,players,expires,mode) VALUES(?,?,?,?,?)',
                (legacy_match, killer, json.dumps([killer, victim]), int(time.time()) + 600, 'naval'))
    con.commit()
    check(call('reward', bearer, match=legacy_match, event=legacy_match + ':legacy-death', killer=killer, victim=victim)[0] == 403 and
          call('match_wallet', bearer, match=legacy_match, account=victim)[0] == 403,
          'legacy account-owned match does not bypass dedicated authority')
    code, profile = call('profile', bearer)
    check(code == 200 and profile['profile']['id'] == killer and 'ticket' in profile,
          'normal profile and signed ticket remain available')
    tx = secrets.token_hex(16)
    code, bought = call('buy', bearer, ship='combat', transaction=tx)
    check(code == 200 and bought['profile']['coins'] == expected_coins - 1200 and 'combat' in bought['profile']['owned'],
          'normal ship purchase remains available with exact server price')
    code, bought_again = call('buy', bearer, ship='combat', transaction=tx)
    check(code == 200 and bought_again['profile']['coins'] == expected_coins - 1200,
          'normal repeated purchase remains idempotent')
    code, selected = call('select', bearer, ship='combat')
    check(code == 200 and selected['profile']['selected'] == 'combat',
          'normal ship selection remains available')
    appearance = {'skin': '#8b985f', 'proportions': {'head': 1.1, 'torso': 1.0, 'arms': .9, 'legs': 1.05}}
    code, dressed = call('appearance', bearer, appearance=appearance)
    check(code == 200 and dressed['profile']['appearance']['proportions'] == appearance['proportions'],
          'normal character proportions remain persistent')
    code, ranked = call('rankings', bearer)
    check(code == 200 and ranked['ok'] and ranked['rankings']['lists']['coins'][0]['coins'] == 5000,
          'normal ranking remains available and uses persistent server balances')
    code, logged_in = call('login', username='authority_user', password='test-only-password-123!',
                           **{key: identity[key] for key in ('public_key', 'nonce', 'proof')})
    check(code == 200 and logged_in['profile']['id'] == killer and len(logged_in.get('token', '')) == 64,
          'password and device-proof login remain functional')
    login_auth = 'Bearer ' + logged_in['token']
    check(call('logout', login_auth)[0] == 200 and call('profile', login_auth)[0] == 401,
          'normal logout revokes the authenticated session')
finally:
    proc.terminate()
    proc.wait(timeout=10)
    log.close()
    con.close()
    (ROOT / 'tests/account-authority-results.json').write_text(json.dumps({'checks': checks}, indent=2))
