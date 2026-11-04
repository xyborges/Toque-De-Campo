<?php
declare(strict_types=1);
// Public entry point only. Database, signing keys and TLS keys live outside htdocs.
header('Content-Type: application/json; charset=utf-8');
header('Cache-Control: no-store');
header('X-Content-Type-Options: nosniff');
function answer(array $data, int $status=200): never {
    http_response_code($status); echo json_encode($data, JSON_UNESCAPED_UNICODE|JSON_THROW_ON_ERROR); exit;
}
function fail(string $message, int $status=400): never { answer(['ok'=>false,'error'=>$message],$status); }
if (($_SERVER['HTTPS'] ?? '') !== 'on') fail('Use HTTPS para acessar as contas.',426);
$private = getenv('TDC_ACCOUNTS_STORAGE') ?: ($_SERVER['TDC_ACCOUNTS_STORAGE'] ?? dirname($_SERVER['DOCUMENT_ROOT']).'/toque-de-campo-private');
if (!is_file($private.'/signing.pem')) fail('Serviço de contas não configurado.',503);
const SHIPS = ['light'=>0,'combat'=>1200,'heavy'=>2600,'assault'=>3900,'submarine'=>5200];
try {
    $db = new PDO('sqlite:'.$private.'/accounts.sqlite',null,null,[PDO::ATTR_ERRMODE=>PDO::ERRMODE_EXCEPTION]);
    $db->exec('PRAGMA busy_timeout=5000; PRAGMA foreign_keys=ON; PRAGMA journal_mode=WAL');
    $db->exec('CREATE TABLE IF NOT EXISTS users(id TEXT PRIMARY KEY, username TEXT UNIQUE NOT NULL, password TEXT NOT NULL, coins INTEGER NOT NULL CHECK(coins>=0), owned TEXT NOT NULL, selected TEXT NOT NULL, revision INTEGER NOT NULL DEFAULT 1);
        CREATE TABLE IF NOT EXISTS sessions(token TEXT PRIMARY KEY,user_id TEXT NOT NULL,device TEXT NOT NULL,expires INTEGER NOT NULL, FOREIGN KEY(user_id) REFERENCES users(id));
        CREATE TABLE IF NOT EXISTS limits(bucket TEXT PRIMARY KEY, count INTEGER NOT NULL, expires INTEGER NOT NULL);
        CREATE TABLE IF NOT EXISTS purchases(user_id TEXT NOT NULL,tx TEXT NOT NULL,ship TEXT NOT NULL, PRIMARY KEY(user_id,tx));
        CREATE TABLE IF NOT EXISTS matches(id TEXT PRIMARY KEY,host TEXT NOT NULL,players TEXT NOT NULL,expires INTEGER NOT NULL);
        CREATE TABLE IF NOT EXISTS rewards(match_id TEXT NOT NULL,event TEXT NOT NULL,victim TEXT NOT NULL,created INTEGER NOT NULL,PRIMARY KEY(match_id,event));
        CREATE TABLE IF NOT EXISTS server_cache(name TEXT PRIMARY KEY,created INTEGER NOT NULL,payload TEXT NOT NULL);
        CREATE TABLE IF NOT EXISTS match_deaths(match_id TEXT NOT NULL,event TEXT NOT NULL,victim TEXT NOT NULL,created INTEGER NOT NULL,PRIMARY KEY(match_id,event))');
    $db->exec("CREATE TABLE IF NOT EXISTS account_preferences(user_id TEXT PRIMARY KEY, settings TEXT NOT NULL DEFAULT '{}', revision INTEGER NOT NULL DEFAULT 0, FOREIGN KEY(user_id) REFERENCES users(id))");
    $columns=$db->query('PRAGMA table_info(users)')->fetchAll(PDO::FETCH_COLUMN,1);
    foreach (['kills','deaths'] as $column) if (!in_array($column,$columns,true)) $db->exec('ALTER TABLE users ADD COLUMN '.$column.' INTEGER NOT NULL DEFAULT 0');
    if (!in_array('appearance',$columns,true)) $db->exec("ALTER TABLE users ADD COLUMN appearance TEXT NOT NULL DEFAULT '{}'");
    $columns=$db->query('PRAGMA table_info(matches)')->fetchAll(PDO::FETCH_COLUMN,1);
    if (!in_array('mode',$columns,true)) $db->exec("ALTER TABLE matches ADD COLUMN mode TEXT NOT NULL DEFAULT 'naval'");
    function row(string $sql,array $args=[]): array|false { global $db; $q=$db->prepare($sql);$q->execute($args);return $q->fetch(PDO::FETCH_ASSOC); }
    function execute_sql(string $sql,array $args=[]): void { global $db; $q=$db->prepare($sql);$q->execute($args); }
    function record_match_death(string $match,string $event,string $victim): void {
        // Called inside the same transaction as the reward/death event. Both
        // messages use the server's victim-life key, so either arrival order
        // records one death without suppressing a genuine kill's later payout.
        $old=row('SELECT victim FROM match_deaths WHERE match_id=? AND event=?',[$match,$event]);
        if ($old) { if ($old['victim']!==$victim) fail('Evento de outra vítima.',409); return; }
        $legacy=row('SELECT victim FROM rewards WHERE match_id=? AND event=?',[$match,$event]);
        if ($legacy && $legacy['victim']!==$victim) fail('Evento de outra vítima.',409);
        execute_sql('INSERT INTO match_deaths VALUES(?,?,?,?)',[$match,$event,$victim,time()]);
        // Old releases already counted deaths through rewards. A late retry
        // must not migrate those historical deaths by counting them again.
        if (!$legacy) execute_sql('UPDATE users SET deaths=deaths+1,revision=revision+1 WHERE id=?',[$victim]);
    }
    function limit_action(string $bucket,int $max,int $seconds): void {
        global $db;
        $bucket=hash('sha256',$bucket);$now=time();
        $q=$db->prepare('INSERT INTO limits(bucket,count,expires) VALUES(?,1,?) ON CONFLICT(bucket) DO UPDATE SET count=CASE WHEN expires<? THEN 1 ELSE count+1 END,expires=CASE WHEN expires<? THEN excluded.expires ELSE expires END RETURNING count');
        $q->execute([$bucket,$now+$seconds,$now,$now]);
        if ((int)$q->fetchColumn()>$max) fail('Muitas tentativas. Aguarde alguns minutos.',429);
    }
    function public_profile(array $user): array {
        return ['id'=>$user['id'],'username'=>$user['username'],'coins'=>(int)$user['coins'],'owned'=>json_decode($user['owned'],true,16,JSON_THROW_ON_ERROR),'selected'=>$user['selected'],'revision'=>(int)$user['revision'],'kills'=>(int)($user['kills']??0),'deaths'=>(int)($user['deaths']??0),'appearance'=>(object)json_decode($user['appearance']??'{}',true,8,JSON_THROW_ON_ERROR)];
    }
    function envelope(array $profile,string $device): array {
        global $private;
        $profile['device']=$device;$profile['expires']=time()+900;$profile['issuer']='toque-accounts-v1';
        $payload=base64_encode(json_encode($profile,JSON_UNESCAPED_UNICODE|JSON_UNESCAPED_SLASHES|JSON_THROW_ON_ERROR));
        if (!openssl_sign($payload,$signature,file_get_contents($private.'/signing.pem'),OPENSSL_ALGO_SHA256)) throw new RuntimeException('ticket signing failed');
        return ['payload'=>$payload,'signature'=>base64_encode($signature)];
    }
    function send_profile(array $user,string $device,array $extra=[]): never {
        $profile=public_profile($user);answer(array_merge(['ok'=>true,'profile'=>$profile,'ticket'=>envelope($profile,$device)],$extra));
    }
    if ($_SERVER['REQUEST_METHOD']==='GET') answer(['ok'=>true,'service'=>'Toque de Campo Accounts','version'=>1]);
    if ($_SERVER['REQUEST_METHOD']!=='POST' || (int)($_SERVER['CONTENT_LENGTH']??0)>20000) fail('Requisição inválida.',413);
    $input=json_decode(file_get_contents('php://input'),true,32,JSON_THROW_ON_ERROR);
    if (!is_array($input)) fail('Requisição inválida.');
    $action=(string)($input['action']??''); $ip=$_SERVER['REMOTE_ADDR']??'unknown';
    limit_action('api:'.$ip,240,60);
    if (in_array($action,['register','login'],true)) {
        $username=strtolower(trim((string)($input['username']??'')));
        $password=(string)($input['password']??'');
        if (!preg_match('/^[a-z0-9_]{3,24}$/D',$username)) fail('Nome: use 3–24 caracteres a–z, 0–9 ou _.');
        $length=preg_match_all('/./us',$password);
        if ($length===false || $length<12 || $length>128) fail('Use uma senha com 12 a 128 caracteres.');
        limit_action('auth:'.$ip.':'.$username,12,900);limit_action('auth-ip:'.$ip,80,900);
        $pem=(string)($input['public_key']??'');$nonce=(string)($input['nonce']??'');
        $proof=base64_decode((string)($input['proof']??''),true);
        if (strlen($pem)>6000 || !preg_match('/^[a-f0-9]{32}$/D',$nonce) || $proof===false || openssl_verify('tdc-auth:'.$username.':'.$nonce,$proof,$pem,OPENSSL_ALGO_SHA256)!==1) fail('Identidade do dispositivo inválida.',401);
        $device=hash('sha256',$pem);
        $user=row('SELECT * FROM users WHERE username=?',[$username]);
        if ($action==='register') {
            limit_action('register:'.$ip,12,3600);
            if ($user) fail('Não foi possível criar a conta com esses dados.',409);
            $owned=['light'];$coins=0;$selected='light';
            // One-time migration is read from server-controlled legacy files only.
            $legacy=$private.'/legacy/'.$device.'.json';
            if (is_file($legacy)) {
                $old=json_decode(file_get_contents($legacy),true);
                if (is_array($old)) {
                    $owned=array_values(array_unique(array_merge(['light'],array_intersect((array)($old['owned']??[]),array_keys(SHIPS)))));
                    $coins=max(0,min(10000000,(int)($old['coins']??0)));
                    if (in_array($old['selected']??'', $owned,true)) $selected=$old['selected'];
                }
            }
            $id=bin2hex(random_bytes(16));$hash=password_hash($password,PASSWORD_ARGON2ID,['memory_cost'=>65536,'time_cost'=>3,'threads'=>1]);
            execute_sql('INSERT INTO users(id,username,password,coins,owned,selected) VALUES(?,?,?,?,?,?)',[$id,$username,$hash,$coins,json_encode($owned),$selected]);
            $user=row('SELECT * FROM users WHERE id=?',[$id]);
        } else {
            // Same expensive check and generic error for unknown users.
            $dummy='$argon2id$v=19$m=65536,t=3,p=1$MjIzNDU2Nzg5MDEyMzQ1Ng$GBOnZjDOLQlVBsdN3e7wyIDKSXvOULkveNyYOFvG31M';
            if (!password_verify($password,$user ? $user['password'] : $dummy) || !$user) fail('Nome ou senha incorretos.',401);
        }
        $token=bin2hex(random_bytes(32));
        execute_sql('DELETE FROM sessions WHERE expires<?',[time()]);
        execute_sql('INSERT INTO sessions VALUES(?,?,?,?)',[hash('sha256',$token),$user['id'],$device,time()+604800]);
        send_profile($user,$device,['token'=>$token]);
    }
    $authorization=$_SERVER['HTTP_AUTHORIZATION']??($_SERVER['REDIRECT_HTTP_AUTHORIZATION']??'');
    if ($authorization==='' && function_exists('getallheaders')) foreach (getallheaders() as $name=>$value) if (strtolower($name)==='authorization') $authorization=$value;
    $service=false;
    if (preg_match('/^Service ([a-f0-9]{64})$/D',$authorization,$m)) {
        $digest=is_file($private.'/service-token.sha256') ? trim(file_get_contents($private.'/service-token.sha256')) : '';
        if ($digest==='' || !hash_equals($digest,hash('sha256',$m[1]))) fail('Serviço não autorizado.',401);
        if (!in_array($action,['match_register','reward','match_wallet','match_death'],true)) fail('Ação não permitida ao serviço.',403);
        $user=['id'=>'dedicated-service'];$session=['device'=>'dedicated-service'];$service=true;
    } else {
        if (!preg_match('/^Bearer ([a-f0-9]{64})$/D',$authorization,$m)) fail('Entre na sua conta.',401);
        $session=row('SELECT * FROM sessions WHERE token=? AND expires>?',[hash('sha256',$m[1]),time()]);
        if (!$session) fail('Sessão expirada. Entre novamente.',401);
        $user=row('SELECT * FROM users WHERE id=?',[$session['user_id']]);
        if (!$user) fail('Entre na sua conta.',401);
    }
    // Online match authority lives exclusively on the dedicated servers.
    // A normal account must never register its own match, fabricate rewards or
    // inspect another participant's wallet, even when it is a room creator.
    if (!$service && in_array($action,['match_register','reward','match_wallet','match_death'],true)) {
        fail('Esta operação exige o servidor oficial da partida.',403);
    }
    if ($action==='logout') {execute_sql('DELETE FROM sessions WHERE token=?',[$session['token']]);answer(['ok'=>true]);}
    if ($action==='profile') send_profile($user,$session['device']);
    if ($action==='preferences_get' || $action==='preferences_set') {
        $allowed=['game','aim','audio','war_camera','naval'];
        $saved=row('SELECT settings,revision FROM account_preferences WHERE user_id=?',[$user['id']]);
        if ($action==='preferences_get') {
            $data=$saved ? json_decode($saved['settings'],true,16,JSON_THROW_ON_ERROR) : [];
            foreach ($data as $name=>$section) if (is_array($section)) $data[$name]=(object)$section;
            answer(['ok'=>true,'settings'=>(object)$data,'revision'=>(int)($saved['revision']??0)]);
        }
        limit_action('preferences:'.$user['id'],100,60);
        $sections=$input['sections']??null;
        if (!is_array($sections) || !$sections || count($sections)>count($allowed)) fail('Configurações inválidas.');
        $validate=function($value,int $depth=0) use (&$validate): bool {
            if ($depth>5) return false;
            if (is_bool($value) || is_int($value)) return true;
            if (is_float($value)) return is_finite($value) && abs($value)<=100000;
            if (!is_array($value) || count($value)>128) return false;
            foreach ($value as $key=>$child) {
                if (is_string($key) && !preg_match('/^[a-zA-Z0-9_:.-]{1,80}$/D',$key)) return false;
                if (!$validate($child,$depth+1)) return false;
            }
            return true;
        };
        foreach ($sections as $name=>$data) {
            if (!in_array($name,$allowed,true) || !is_array($data) || !$validate($data)) fail('Configurações inválidas.');
        }
        $db->exec('BEGIN IMMEDIATE');
        $saved=row('SELECT settings,revision FROM account_preferences WHERE user_id=?',[$user['id']]);
        $merged=$saved ? json_decode($saved['settings'],true,16,JSON_THROW_ON_ERROR) : [];
        foreach ($sections as $name=>$data) $merged[$name]=(object)$data;
        $encoded=json_encode((object)$merged,JSON_THROW_ON_ERROR);
        if (strlen($encoded)>16000) { $db->exec('ROLLBACK'); fail('Configurações muito grandes.',413); }
        $revision=(int)($saved['revision']??0)+1;
        execute_sql('INSERT INTO account_preferences(user_id,settings,revision) VALUES(?,?,?) ON CONFLICT(user_id) DO UPDATE SET settings=excluded.settings,revision=excluded.revision',[$user['id'],$encoded,$revision]);
        $db->exec('COMMIT');
        answer(['ok'=>true,'revision'=>$revision]);
    }
    if ($action==='rankings') {
        // Public account statistics only. The bearer is authenticated above;
        // no balances, scores or SQL fragments are accepted from the caller.
        $cached=row('SELECT created,payload FROM server_cache WHERE name=?',['global-ranking-v1']);
        $now=time();
        if ($cached && $now-(int)$cached['created']<3600) {
            answer(['ok'=>true,'rankings'=>json_decode($cached['payload'],true,16,JSON_THROW_ON_ERROR),'cached'=>true]);
        }
        $db->exec('BEGIN IMMEDIATE');
        // Another request might have refreshed while this request waited.
        $cached=row('SELECT created,payload FROM server_cache WHERE name=?',['global-ranking-v1']);
        if ($cached && $now-(int)$cached['created']<3600) {
            $db->exec('COMMIT');
            answer(['ok'=>true,'rankings'=>json_decode($cached['payload'],true,16,JSON_THROW_ON_ERROR),'cached'=>true]);
        }
        $lists=[];
        foreach (['kills'=>'kills DESC,deaths ASC','kd'=>'CAST(kills AS REAL)/MAX(deaths,1) DESC,kills DESC','deaths'=>'deaths DESC,kills DESC','coins'=>'coins DESC,kills DESC'] as $kind=>$order) {
            $query=$db->query('SELECT username,kills,deaths,coins FROM users '.($kind==='kd'?'WHERE kills+deaths>=20 ':'').'ORDER BY '.$order.',username ASC LIMIT 10');
            $lists[$kind]=[];
            foreach ($query->fetchAll(PDO::FETCH_ASSOC) as $entry) {
                $lists[$kind][]=['name'=>$entry['username'],'kills'=>(int)$entry['kills'],'deaths'=>(int)$entry['deaths'],'coins'=>(int)$entry['coins'],'kd'=>round((int)$entry['kills']/max(1,(int)$entry['deaths']),3)];
            }
        }
        $result=['generated_at'=>$now,'expires_at'=>$now+3600,'kd_min_participation'=>20,'lists'=>$lists];
        execute_sql('INSERT INTO server_cache(name,created,payload) VALUES(?,?,?) ON CONFLICT(name) DO UPDATE SET created=excluded.created,payload=excluded.payload',['global-ranking-v1',$now,json_encode($result,JSON_UNESCAPED_UNICODE|JSON_THROW_ON_ERROR)]);
        $db->exec('COMMIT');
        answer(['ok'=>true,'rankings'=>$result,'cached'=>false]);
    }
    if ($action==='appearance') {
        $appearance=$input['appearance']??null;
        if (!is_array($appearance) || !preg_match('/^#?[a-fA-F0-9]{6}$/D',(string)($appearance['skin']??''))) fail('Cor do uniforme inválida.');
        $clean=array_fill_keys(['head','torso','arms','legs'],1.0);
        $defaults=['skin'=>'c8946e','shirt'=>'998e72','pants'=>'4c5149','boots'=>'252b29'];
        $colors=$appearance['colors']??[];
        if (!is_array($colors)) fail('Cores inválidas.');
        foreach ($defaults as $part=>$fallback) {
            $value=(string)($colors[$part]??$fallback);
            if (!preg_match('/^#?[a-fA-F0-9]{6}$/D',$value)) fail('Cor inválida.');
            $defaults[$part]=strtolower(ltrim($value,'#'));
        }
        $encoded=json_encode(['skin'=>strtolower(ltrim($appearance['skin'],'#')),'proportions'=>$clean,'colors'=>$defaults],JSON_THROW_ON_ERROR);
        execute_sql('UPDATE users SET appearance=?,revision=revision+1 WHERE id=?',[$encoded,$user['id']]);
        send_profile(row('SELECT * FROM users WHERE id=?',[$user['id']]),$session['device']);
    }
    if ($action==='buy' || $action==='select') {
        $ship=(string)($input['ship']??'');if (!array_key_exists($ship,SHIPS)) fail('Navio inválido.');
        $db->exec('BEGIN IMMEDIATE');
        $user=row('SELECT * FROM users WHERE id=?',[$user['id']]);$owned=json_decode($user['owned'],true);
        if ($action==='buy') {
            $tx=(string)($input['transaction']??'');if (!preg_match('/^[a-f0-9]{32}$/D',$tx)) fail('Compra inválida.');
            $old=row('SELECT ship FROM purchases WHERE user_id=? AND tx=?',[$user['id'],$tx]);
            if ($old && $old['ship']!==$ship) fail('Identificador de compra já utilizado.',409);
            if (!$old && !in_array($ship,$owned,true)) {
                if ((int)$user['coins']<SHIPS[$ship]) fail('Saldo insuficiente.',409);
                $owned[]=$ship;$user['coins']=(int)$user['coins']-SHIPS[$ship];
                execute_sql('UPDATE users SET coins=?,owned=?,revision=revision+1 WHERE id=?',[$user['coins'],json_encode($owned),$user['id']]);
            }
            if (!$old) execute_sql('INSERT INTO purchases VALUES(?,?,?)',[$user['id'],$tx,$ship]);
        } else {
            if (!in_array($ship,$owned,true)) fail('Você ainda não possui esse navio.',409);
            execute_sql('UPDATE users SET selected=?,revision=revision+1 WHERE id=?',[$ship,$user['id']]);
        }
        $db->exec('COMMIT');send_profile(row('SELECT * FROM users WHERE id=?',[$user['id']]),$session['device']);
    }
    if ($action==='match_register') {
        $match=(string)($input['match']??'');$players=$input['players']??[];
        $matchMode=(string)($input['mode']??'naval');
        if (!in_array($matchMode,['naval','infantry','war'],true)) fail('Modo de partida inválido.',403);
        $maxPlayers=$matchMode==='war'?12:6;
        if (!preg_match('/^[a-f0-9]{32}$/D',$match) || !is_array($players) || count($players)<1 || count($players)>$maxPlayers) fail('Partida inválida.');
        foreach ($players as $id) if (!is_string($id) || !row('SELECT id FROM users WHERE id=?',[$id])) fail('Participante inválido.');
        $db->exec('BEGIN IMMEDIATE');
        $old=row('SELECT host,players,mode FROM matches WHERE id=?',[$match]);
        if ($old && $old['host']!==$user['id']) fail('Partida de outro anfitrião.',403);
        if ($old && $old['mode']!==$matchMode) fail('O modo de uma partida registrada não pode ser alterado.',409);
        if ($old) $players=array_values(array_unique(array_merge($players,json_decode($old['players'],true))));
        execute_sql('INSERT INTO matches(id,host,players,expires,mode) VALUES(?,?,?,?,?) ON CONFLICT(id) DO UPDATE SET players=excluded.players,expires=excluded.expires',[$match,$user['id'],json_encode(array_values(array_unique($players))),time()+86400,$matchMode]);
        $db->exec('COMMIT');
        answer(['ok'=>true]);
    }
    if ($action==='match_death') {
        $match=(string)($input['match']??'');$event=(string)($input['event']??'');$victim=(string)($input['victim']??'');
        $data=row('SELECT * FROM matches WHERE id=? AND host=? AND expires>?',[$match,$user['id'],time()]);
        if (!$data || strlen($event)>100 || strlen($event)<16 || !in_array($victim,json_decode($data['players'],true),true)) fail('Morte inválida.',403);
        $db->exec('BEGIN IMMEDIATE');record_match_death($match,$event,$victim);$db->exec('COMMIT');
        answer(['ok'=>true]);
    }
    if ($action==='reward') {
        $match=(string)($input['match']??'');$event=(string)($input['event']??'');$killer=(string)($input['killer']??'');$victim=(string)($input['victim']??'');
        $data=row('SELECT * FROM matches WHERE id=? AND host=? AND expires>?',[$match,$user['id'],time()]);
        if (!$data || strlen($event)>100 || strlen($event)<16 || $killer===$victim) fail('Recompensa inválida.',403);
        $players=json_decode($data['players'],true);
        if (!in_array($killer,$players,true) || !in_array($victim,$players,true)) fail('Participante inválido.',403);
        $db->exec('BEGIN IMMEDIATE');
        $old=row('SELECT event,victim FROM rewards WHERE match_id=? AND event=?',[$match,$event]);
        if ($old && $old['victim']!==$victim) fail('Evento de outra vítima.',409);
        if (!$old) {
            $recent=row('SELECT created FROM rewards WHERE match_id=? AND victim=? ORDER BY created DESC LIMIT 1',[$match,$victim]);
            if ($recent && time()-(int)$recent['created']<4) fail('Recompensa recebida recentemente.',429);
            record_match_death($match,$event,$victim);
            execute_sql('INSERT INTO rewards VALUES(?,?,?,?)',[$match,$event,$victim,time()]);
            execute_sql('UPDATE users SET coins=coins+?,kills=kills+1,revision=revision+1 WHERE id=?',[in_array($data['mode'],['infantry','war'],true)?30:100,$killer]);
        }
        $db->exec('COMMIT');answer(['ok'=>true]);
    }
    if ($action==='match_wallet') {
        $match=row('SELECT * FROM matches WHERE id=? AND host=? AND expires>?',[(string)($input['match']??''),$user['id'],time()]);
        $id=(string)($input['account']??'');
        if (!$match || !in_array($id,json_decode($match['players'],true),true)) fail('Participante inválido.',403);
        $account=row('SELECT * FROM users WHERE id=?',[$id]);
        if (!$account) fail('Conta inválida.');
        answer(['ok'=>true,'account'=>public_profile($account)]);
    }
    fail('Ação desconhecida.');
} catch (JsonException $e) { fail('JSON inválido.'); }
catch (Throwable $e) { error_log('TDC accounts: '.$e->getMessage());fail('Não foi possível concluir a operação. Tente novamente.',503); }
