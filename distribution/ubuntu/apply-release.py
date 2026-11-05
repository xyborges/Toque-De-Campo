#!/usr/bin/python3
"""Authenticate the bounded release, then activate it with full rollback.

Importing performs no privileged operation; local tests use isolated fixtures.
"""
import base64
import hashlib
import json
import os
import pathlib
import re
import shutil
import sqlite3
import ssl
import stat
import subprocess
import sys
import tempfile
import time
import urllib.request

STAGE = pathlib.Path('/home/microgate/toque-deploy')
WEB = pathlib.Path('/var/www/toque-de-campo')
APP = pathlib.Path('/opt/toque-de-campo')
GAME_DATA = pathlib.Path('/var/lib/toque-de-campo/game')
WAR_UNIT = pathlib.Path('/etc/systemd/system/toque-war.service')
WAR_AFGHAN_UNIT = pathlib.Path('/etc/systemd/system/toque-war-afghan.service')
WAR_FAVELA_UNIT = pathlib.Path('/etc/systemd/system/toque-war-favela.service')
BR_UNIT = pathlib.Path('/etc/systemd/system/toque-br.service')
PUBLIC_KEY = '/etc/toque-de-campo/release-public.pem'
SERVICE_STATUS = {'toque-naval': ('naval-status.json', 3012),
                  'toque-pvp': ('pvp-status.json', 3010),
                  'toque-war': ('war-status.json', 3014),
                  'toque-war-afghan': ('war-afghan-status.json', 3015),
                  'toque-war-favela': ('war-favela-status.json', 3017),
                  'toque-br': ('br-broker-status.json', 3016)}
BASE_ARTIFACTS = {'server/ToqueDeCampo.x86_64', 'server/ToqueDeCampo.pck',
                  'public/api.php', 'public/index.html', 'public/ToqueDeCampo.exe',
                  'public/manifest.json'}
WAR_EXEC = ('/opt/toque-de-campo/current/ToqueDeCampo.x86_64 --headless '
            '--max-fps 60 --log-file /var/lib/toque-de-campo/game/war.log '
            '-- --war-server --naval-data=/var/lib/toque-de-campo/game '
            '--accounts-service-token=/etc/toque-de-campo/service-token')
# A release authorizes game files, not arbitrary privileged systemd directives.
# Do not allow ExecStartPre/Post, root, environment expansion or extra writes.
WAR_DIRECTIVES = {
    'Unit': {'Description': 'Toque de Campo - Guerra Conquista',
             'After': 'network-online.target nginx.service php8.3-fpm.service',
             'Wants': 'network-online.target'},
    'Service': {'Type': 'simple', 'User': 'toque-server', 'Group': 'toque-server',
                'WorkingDirectory': '/opt/toque-de-campo/current',
                'ExecStart': WAR_EXEC, 'Restart': 'on-failure', 'RestartSec': '3',
                'TimeoutStopSec': '15', 'NoNewPrivileges': 'true',
                'PrivateTmp': 'true', 'ProtectSystem': 'strict',
                'ProtectHome': 'true',
                'ReadWritePaths': '/var/lib/toque-de-campo/game',
                'RestrictAddressFamilies': 'AF_INET AF_INET6 AF_UNIX',
                'MemoryMax': '2G', 'TasksMax': '128', 'LimitNOFILE': '65536'},
    'Install': {'WantedBy': 'multi-user.target'}}
WAR_AFGHAN_EXEC = ('/opt/toque-de-campo/current/ToqueDeCampo.x86_64 --headless '
                   '--max-fps 60 --log-file /var/lib/toque-de-campo/game/war-afghan.log '
                   '-- --war-server --war-map=afghan --naval-data=/var/lib/toque-de-campo/game '
                   '--accounts-service-token=/etc/toque-de-campo/service-token')
WAR_AFGHAN_DIRECTIVES = {
    'Unit': {'Description': 'Toque de Campo - Guerra Deserto Afegao',
             'After': 'network-online.target nginx.service php8.3-fpm.service',
             'Wants': 'network-online.target'},
    'Service': {'Type': 'simple', 'User': 'toque-server', 'Group': 'toque-server',
                'WorkingDirectory': '/opt/toque-de-campo/current',
                'ExecStart': WAR_AFGHAN_EXEC, 'Restart': 'on-failure', 'RestartSec': '3',
                'TimeoutStopSec': '15', 'NoNewPrivileges': 'true',
                'PrivateTmp': 'true', 'ProtectSystem': 'strict',
                'ProtectHome': 'true',
                'ReadWritePaths': '/var/lib/toque-de-campo/game',
                'RestrictAddressFamilies': 'AF_INET AF_INET6 AF_UNIX',
                'MemoryMax': '2G', 'TasksMax': '128', 'LimitNOFILE': '65536'},
    'Install': {'WantedBy': 'multi-user.target'}}
WAR_FAVELA_EXEC = ('/opt/toque-de-campo/current/ToqueDeCampo.x86_64 --headless '
                   '--max-fps 60 --log-file /var/lib/toque-de-campo/game/war-favela.log '
                   '-- --war-server --war-map=favela --naval-data=/var/lib/toque-de-campo/game '
                   '--accounts-service-token=/etc/toque-de-campo/service-token')
WAR_FAVELA_DIRECTIVES = {
    'Unit': {'Description': 'Toque de Campo - Guerra Favela',
             'After': 'network-online.target nginx.service php8.3-fpm.service',
             'Wants': 'network-online.target'},
    'Service': {'Type': 'simple', 'User': 'toque-server', 'Group': 'toque-server',
                'WorkingDirectory': '/opt/toque-de-campo/current',
                'ExecStart': WAR_FAVELA_EXEC, 'Restart': 'on-failure', 'RestartSec': '3',
                'TimeoutStopSec': '15', 'NoNewPrivileges': 'true',
                'PrivateTmp': 'true', 'ProtectSystem': 'strict',
                'ProtectHome': 'true',
                'ReadWritePaths': '/var/lib/toque-de-campo/game',
                'RestrictAddressFamilies': 'AF_INET AF_INET6 AF_UNIX',
                'MemoryMax': '2G', 'TasksMax': '128', 'LimitNOFILE': '65536'},
    'Install': {'WantedBy': 'multi-user.target'}}
BR_EXEC = ('/opt/toque-de-campo/current/ToqueDeCampo.x86_64 --headless '
           '--max-fps 20 --log-file /var/lib/toque-de-campo/game/br-broker.log '
           '-- --br-server --br-max-rooms=2 --naval-data=/var/lib/toque-de-campo/game '
           '--accounts-service-token=/etc/toque-de-campo/service-token')
BR_DIRECTIVES = {
    'Unit': {'Description': 'Toque de Campo - Battle Royale matchmaking',
             'After': 'network-online.target nginx.service php8.3-fpm.service',
             'Wants': 'network-online.target'},
    'Service': {'Type': 'simple', 'User': 'toque-server', 'Group': 'toque-server',
                'WorkingDirectory': '/opt/toque-de-campo/current',
                'ExecStart': BR_EXEC, 'Restart': 'on-failure', 'RestartSec': '3',
                'TimeoutStopSec': '15', 'KillMode': 'control-group',
                'NoNewPrivileges': 'true', 'PrivateTmp': 'true',
                'ProtectSystem': 'strict', 'ProtectHome': 'true',
                'ReadWritePaths': '/var/lib/toque-de-campo/game',
                'RestrictAddressFamilies': 'AF_INET AF_INET6 AF_UNIX',
                'MemoryMax': '4G', 'TasksMax': '512', 'LimitNOFILE': '65536'},
    'Install': {'WantedBy': 'multi-user.target'}}


def run(*command, check=True):
    return subprocess.run(command, check=check, text=True, capture_output=True)


def read_bounded(path, limit):
    descriptor = os.open(path, os.O_RDONLY | getattr(os, 'O_NOFOLLOW', 0))
    with os.fdopen(descriptor, 'rb') as stream:
        info = os.fstat(stream.fileno())
        if not stat.S_ISREG(info.st_mode) or info.st_size > limit:
            raise ValueError('Invalid or oversized artifact: ' + str(path.name))
        data = stream.read(limit + 1)
        if len(data) > limit:
            raise ValueError('Artifact grew beyond its limit: ' + str(path.name))
        return data


def verify(envelope):
    raw = read_bounded(envelope, 262144)
    data = json.loads(raw)
    payload = base64.b64decode(data['payload'], validate=True)
    signature = base64.b64decode(data['signature'], validate=True)
    if len(payload) > 131072 or len(signature) > 8192:
        raise ValueError('Oversized signed envelope')
    with tempfile.TemporaryDirectory(prefix='toque-signature-') as temp:
        folder = pathlib.Path(temp)
        (folder / 'payload').write_bytes(payload)
        (folder / 'sig').write_bytes(signature)
        run('openssl', 'dgst', '-sha256', '-verify', PUBLIC_KEY, '-signature',
            str(folder / 'sig'), str(folder / 'payload'))
    result = json.loads(payload)
    if not isinstance(result, dict):
        raise ValueError('Invalid signed payload')
    return result, raw


def sha(file):
    with file.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def atomic_copy(source, destination, mode=0o644):
    destination.parent.mkdir(parents=True, exist_ok=True)
    descriptor, name = tempfile.mkstemp(prefix='.' + destination.name + '.',
                                         dir=destination.parent)
    temporary = pathlib.Path(name)
    try:
        with os.fdopen(descriptor, 'wb') as target, source.open('rb') as stream:
            shutil.copyfileobj(stream, target)
            target.flush()
            os.fsync(target.fileno())
        temporary.chmod(mode)
        os.replace(temporary, destination)
    finally:
        temporary.unlink(missing_ok=True)


def validate_artifacts(metadata, client):
    if type(metadata.get('schema')) is not int or metadata['schema'] != 1 or metadata.get('build') != client.get('version'):
        raise ValueError('Invalid schema or server/client build mismatch')
    if type(client.get('version')) is not int or client['version'] < 1:
        raise ValueError('Invalid client build')
    archive = client.get('archive', '')
    if not re.fullmatch(r'releases/game-[a-zA-Z0-9.-]+\.zip', archive):
        raise ValueError('Invalid client archive')
    if not re.fullmatch(r'[a-f0-9]{64}', client.get('sha256', '')):
        raise ValueError('Invalid client digest')
    if metadata.get('version') != client.get('version_name'):
        raise ValueError('Server/client display version mismatch')
    hashes = metadata.get('hashes')
    if not isinstance(hashes, dict):
        raise ValueError('Invalid artifact list')
    required = BASE_ARTIFACTS | {'public/' + archive}
    if not required.issubset(hashes) or set(hashes) - required - {'server/toque-war.service', 'server/toque-war-afghan.service', 'server/toque-war-favela.service', 'server/toque-br.service'}:
        raise ValueError('Incomplete release or unexpected artifact')
    if any(not isinstance(digest, str) or not re.fullmatch(r'[a-f0-9]{64}', digest)
           for digest in hashes.values()):
        raise ValueError('Invalid artifact digest')
    return archive


def artifact_limit(name):
    if name.endswith('.service'):
        return 16384
    if name.endswith('.php'):
        return 2097152
    if name.endswith('.html'):
        return 1048576
    if name.endswith('.json'):
        return 262144
    return 536870912


def validate_unit(path, directives, label):
    parsed, section = {}, None
    for raw in read_bounded(path, 16384).decode('utf-8').splitlines():
        line = raw.strip()
        if not line or line.startswith(('#', ';')):
            continue
        if line.startswith('[') and line.endswith(']'):
            section = line[1:-1]
            if section not in directives or section in parsed:
                raise ValueError('Unsupported or duplicate ' + label + ' unit section')
            parsed[section] = {}
        elif section and '=' in line:
            key, value = line.split('=', 1)
            if key in parsed[section]:
                raise ValueError('Duplicate ' + label + ' unit directive')
            parsed[section][key] = value
        else:
            raise ValueError('Malformed ' + label + ' unit')
    if parsed != directives:
        raise ValueError(label + ' unit differs from the permitted service policy')


def validate_war_unit(path):
    validate_unit(path, WAR_DIRECTIVES, 'War')


def validate_war_afghan_unit(path):
    validate_unit(path, WAR_AFGHAN_DIRECTIVES, 'War Afghan')


def validate_war_favela_unit(path):
    validate_unit(path, WAR_FAVELA_DIRECTIVES, 'War Favela')


def validate_br_unit(path):
    validate_unit(path, BR_DIRECTIVES, 'BR')


def active(unit):
    return run('systemctl', 'is-active', '--quiet', unit, check=False).returncode == 0


def read_status(path):
    value = json.loads(read_bounded(path, 8192))
    if not isinstance(value, dict) or type(value.get('connections')) is not int:
        raise ValueError('Invalid server heartbeat: ' + path.name)
    connections, updated = value['connections'], value.get('updated')
    if connections < 0 or connections > 4096 or not isinstance(updated, (int, float)):
        raise ValueError('Invalid server heartbeat: ' + path.name)
    if not 0 <= time.time() - updated < 15:
        raise ValueError('Stale or future server heartbeat: ' + path.name)
    return value


def br_room_process_matches(pid, room_id):
    """Reject stale room files whose PID has been recycled by an unrelated process."""
    process = pathlib.Path('/proc') / str(pid)
    try:
        executable = os.readlink(process / 'exe')
        arguments = [item.decode('utf-8', 'surrogateescape')
                     for item in (process / 'cmdline').read_bytes().split(b'\0') if item]
    except (FileNotFoundError, ProcessLookupError, PermissionError, OSError):
        return False
    release_root = str(APP / 'releases') + '/build-'
    if not executable.startswith(release_root) or not executable.endswith('/ToqueDeCampo.x86_64'):
        return False
    return '--br-room' in arguments and '--br-room-id=' + room_id in arguments


def guard_players():
    for unit, (name, _) in SERVICE_STATUS.items():
        path = GAME_DATA / name
        running = active(unit)
        if not path.exists():
            if running:
                raise RuntimeError('Cannot confirm an empty active server: ' + unit)
            continue
        try:
            status = read_status(path)
        except (ValueError, OSError):
            if running:
                raise RuntimeError('Cannot confirm an empty active server: ' + unit)
            continue
        if status['connections'] > 0:
            raise RuntimeError('Há jogadores conectados; a publicação foi adiada. '
                               'Tente quando as salas estiverem vazias.')
    # A room's admitted players outlive the short connection to the broker.
    # Check child mailboxes too, including when a broker process has failed.
    rooms = GAME_DATA / 'br-matches'
    if rooms.is_dir():
        for path in rooms.glob('*/status.json'):
            try:
                status = json.loads(read_bounded(path, 8192))
                pid, humans = status.get('pid'), status.get('humans')
                if type(pid) is not int or pid <= 1 or type(humans) is not int or not 0 <= humans <= 12:
                    raise ValueError('Invalid BR room heartbeat')
                try:
                    os.kill(pid, 0)
                except ProcessLookupError:
                    continue
                if not br_room_process_matches(pid, path.parent.name):
                    continue
                updated = status.get('heartbeat')
                if not isinstance(updated, (int, float)) or not 0 <= time.time() - updated < 15:
                    raise ValueError('Stale live BR room heartbeat')
                if humans:
                    raise RuntimeError('Há jogadores conectados; a publicação foi adiada. '
                                       'Tente quando as salas estiverem vazias.')
            except (ValueError, OSError) as error:
                raise RuntimeError('Cannot confirm an empty BR room: ' + path.parent.name) from error


def process_owns_udp(pid, port):
    """Require the service's MainPID to own the actual listening UDP socket."""
    if pid <= 1:
        return False
    process = pathlib.Path('/proc') / str(pid)
    inodes = set()
    for descriptor in (process / 'fd').iterdir():
        try:
            target = os.readlink(descriptor)
            if target.startswith('socket:['):
                inodes.add(target[8:-1])
        except OSError:
            continue
    for family in ('udp', 'udp6'):
        table = process / 'net' / family
        if not table.exists():
            continue
        for line in table.read_text().splitlines()[1:]:
            parts = line.split()
            if len(parts) > 9 and int(parts[1].rsplit(':', 1)[1], 16) == port and parts[9] in inodes:
                return True
    return False


def services_healthy(units, started_ns, timeout=25):
    deadline = time.monotonic() + timeout
    failures = {}
    while time.monotonic() < deadline:
        failures = {}
        for unit in units:
            try:
                if not active(unit):
                    raise RuntimeError('service inactive')
                pid = int(run('systemctl', 'show', '--property=MainPID', '--value', unit).stdout.strip())
                name, port = SERVICE_STATUS[unit]
                path = GAME_DATA / name
                read_status(path)
                if path.stat().st_mtime_ns < started_ns:
                    raise RuntimeError('no heartbeat from the new process')
                if not process_owns_udp(pid, port):
                    raise RuntimeError('MainPID does not own UDP ' + str(port))
            except (OSError, ValueError, RuntimeError, subprocess.CalledProcessError) as error:
                failures[unit] = str(error)
        if not failures:
            return
        time.sleep(0.5)
    raise RuntimeError('Game service health failed: ' + json.dumps(failures, ensure_ascii=False))


def accounts_healthy():
    context = ssl.create_default_context(cafile='/etc/toque-de-campo/tls/ca.crt')
    with urllib.request.urlopen('https://127.0.0.1/accounts/api.php', context=context, timeout=5) as response:
        if not json.load(response).get('ok'):
            raise RuntimeError('Accounts health failed')


def replace_current(target):
    next_link = APP / 'current.next'
    if next_link.is_symlink():
        next_link.unlink()
    elif next_link.exists():
        raise RuntimeError('Unexpected non-symlink current.next')
    next_link.symlink_to(target)
    os.replace(next_link, APP / 'current')


def activate(stage, client, archive, release):
    """Restore the previous API/site/unit/enable state as well as the game."""
    unit_source = stage / 'server/toque-war.service'
    afghan_unit_source = stage / 'server/toque-war-afghan.service'
    favela_unit_source = stage / 'server/toque-war-favela.service'
    units = ['toque-naval', 'toque-pvp']
    if unit_source.is_file() or WAR_UNIT.is_file():
        units.append('toque-war')
    if afghan_unit_source.is_file() or WAR_AFGHAN_UNIT.is_file():
        units.append('toque-war-afghan')
    if favela_unit_source.is_file() or WAR_FAVELA_UNIT.is_file():
        units.append('toque-war-favela')
    br_source = stage / 'server/toque-br.service'
    if br_source.is_file() or BR_UNIT.is_file():
        units.append('toque-br')
    previous = os.readlink(APP / 'current') if (APP / 'current').is_symlink() else None
    previous_active = [unit for unit in units if active(unit)]
    enabled_state = run('systemctl', 'is-enabled', 'toque-war', check=False).stdout.strip()
    afghan_enabled_state = run('systemctl', 'is-enabled', 'toque-war-afghan', check=False).stdout.strip() if 'toque-war-afghan' in units else None
    favela_enabled_state = run('systemctl', 'is-enabled', 'toque-war-favela', check=False).stdout.strip() if 'toque-war-favela' in units else None
    br_enabled_state = run('systemctl', 'is-enabled', 'toque-br', check=False).stdout.strip() if 'toque-br' in units else None
    destinations = [(stage / 'public/api.php', WEB / 'accounts/api.php'),
                    (stage / 'public' / archive, WEB / archive),
                    (stage / 'public/ToqueDeCampo.exe', WEB / 'ToqueDeCampo.exe'),
                    (stage / 'public/index.html', WEB / 'index.html'),
                    (stage / 'public/manifest.json', WEB / 'manifest.json')]
    if unit_source.is_file():
        destinations.append((unit_source, WAR_UNIT))
    if afghan_unit_source.is_file():
        destinations.append((afghan_unit_source, WAR_AFGHAN_UNIT))
    if favela_unit_source.is_file():
        destinations.append((favela_unit_source, WAR_FAVELA_UNIT))
    if br_source.is_file():
        destinations.append((br_source, BR_UNIT))
    with tempfile.TemporaryDirectory(prefix='toque-rollback-') as folder:
        backups = []
        for index, (_, destination) in enumerate(destinations):
            saved = pathlib.Path(folder) / str(index)
            if destination.exists():
                if destination.is_symlink() or not destination.is_file():
                    raise RuntimeError('Unexpected destination type: ' + str(destination))
                shutil.copy2(destination, saved)
                backups.append((destination, saved, stat.S_IMODE(destination.stat().st_mode)))
            else:
                backups.append((destination, None, 0o644))
        guard_players()  # Recheck after backup/export work, immediately before restart.
        try:
            if unit_source.is_file():
                atomic_copy(unit_source, WAR_UNIT)
            if afghan_unit_source.is_file():
                atomic_copy(afghan_unit_source, WAR_AFGHAN_UNIT)
            if favela_unit_source.is_file():
                atomic_copy(favela_unit_source, WAR_FAVELA_UNIT)
            if br_source.is_file():
                atomic_copy(br_source, BR_UNIT)
            if unit_source.is_file() or afghan_unit_source.is_file() or favela_unit_source.is_file() or br_source.is_file():
                run('systemctl', 'daemon-reload')
            atomic_copy(stage / 'public/api.php', WEB / 'accounts/api.php')
            started_ns = time.time_ns()
            replace_current(release)
            run('systemctl', 'restart', *units)
            services_healthy(units, started_ns)
            accounts_healthy()
            # Publish the signed manifest last; clients only see a ready build.
            for source, destination in destinations[1:5]:
                atomic_copy(source, destination)
            if unit_source.is_file():
                run('systemctl', 'enable', 'toque-war')
            if afghan_unit_source.is_file():
                run('systemctl', 'enable', 'toque-war-afghan')
            if favela_unit_source.is_file():
                run('systemctl', 'enable', 'toque-war-favela')
            if br_source.is_file():
                run('systemctl', 'enable', 'toque-br')
        except BaseException:
            rollback_errors = []
            def recover(description, callback):
                try:
                    callback()
                except Exception as error:
                    rollback_errors.append(description + ': ' + str(error))
            recover('stop failed release', lambda: run('systemctl', 'stop', *units))
            if previous:
                recover('restore current release', lambda: replace_current(previous))
            elif (APP / 'current').is_symlink():
                (APP / 'current').unlink()
            if enabled_state not in ('enabled', 'enabled-runtime'):
                recover('disable new War unit', lambda: run('systemctl', 'disable', 'toque-war', check=False))
            if afghan_enabled_state is not None and afghan_enabled_state not in ('enabled', 'enabled-runtime'):
                recover('disable new Afghan War unit', lambda: run('systemctl', 'disable', 'toque-war-afghan', check=False))
            if favela_enabled_state is not None and favela_enabled_state not in ('enabled', 'enabled-runtime'):
                recover('disable new Favela War unit', lambda: run('systemctl', 'disable', 'toque-war-favela', check=False))
            if br_enabled_state is not None and br_enabled_state not in ('enabled', 'enabled-runtime'):
                recover('disable new BR unit', lambda: run('systemctl', 'disable', 'toque-br', check=False))
            for destination, saved, mode in reversed(backups):
                if saved is None:
                    recover('remove new ' + destination.name, lambda target=destination: target.unlink(missing_ok=True))
                else:
                    recover('restore ' + destination.name,
                            lambda source=saved, target=destination, bits=mode: atomic_copy(source, target, bits))
            recover('reload restored units', lambda: run('systemctl', 'daemon-reload'))
            if enabled_state in ('enabled', 'enabled-runtime'):
                command = ('systemctl', 'enable', '--runtime', 'toque-war') if enabled_state == 'enabled-runtime' else ('systemctl', 'enable', 'toque-war')
                recover('restore War enable state', lambda: run(*command))
            if afghan_enabled_state in ('enabled', 'enabled-runtime'):
                command = ('systemctl', 'enable', '--runtime', 'toque-war-afghan') if afghan_enabled_state == 'enabled-runtime' else ('systemctl', 'enable', 'toque-war-afghan')
                recover('restore Afghan War enable state', lambda: run(*command))
            if favela_enabled_state in ('enabled', 'enabled-runtime'):
                command = ('systemctl', 'enable', '--runtime', 'toque-war-favela') if favela_enabled_state == 'enabled-runtime' else ('systemctl', 'enable', 'toque-war-favela')
                recover('restore Favela War enable state', lambda: run(*command))
            if br_enabled_state in ('enabled', 'enabled-runtime'):
                command = ('systemctl', 'enable', '--runtime', 'toque-br') if br_enabled_state == 'enabled-runtime' else ('systemctl', 'enable', 'toque-br')
                recover('restore BR enable state', lambda: run(*command))
            if previous and previous_active:
                recover('restart previous services', lambda: run('systemctl', 'restart', *previous_active))
            if rollback_errors:
                print('ROLLBACK_NEEDS_ATTENTION ' + json.dumps(rollback_errors), file=sys.stderr)
            else:
                print('ROLLED_BACK previous game, API, downloads and War service state', file=sys.stderr)
            raise


def deploy():
    metadata, signed_metadata = verify(STAGE / 'server-manifest.json')
    client, _ = verify(STAGE / 'public/manifest.json')
    archive = validate_artifacts(metadata, client)
    with tempfile.TemporaryDirectory(prefix='toque-release-') as folder:
        verified_stage = pathlib.Path(folder)
        total = 0
        for name, digest in metadata['hashes'].items():
            data = read_bounded(STAGE / name, artifact_limit(name))
            total += len(data)
            if total > 1610612736:
                raise ValueError('Release exceeds the total size limit')
            if hashlib.sha256(data).hexdigest() != digest:
                raise ValueError('Artifact hash mismatch: ' + name)
            target = verified_stage / name
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(data)
            del data
        (verified_stage / 'server-manifest.json').write_bytes(signed_metadata)
        verified_client, _ = verify(verified_stage / 'public/manifest.json')
        if verified_client != client or sha(verified_stage / 'public' / archive) != client['sha256']:
            raise ValueError('Client archive or quarantined manifest mismatch')
        if (verified_stage / 'server/toque-war.service').is_file():
            validate_war_unit(verified_stage / 'server/toque-war.service')
        elif WAR_UNIT.is_file():
            raise ValueError('Release omits the installed War service artifact')
        if (verified_stage / 'server/toque-war-afghan.service').is_file():
            validate_war_afghan_unit(verified_stage / 'server/toque-war-afghan.service')
        elif WAR_AFGHAN_UNIT.is_file():
            raise ValueError('Release omits the installed Afghan War service artifact')
        if (verified_stage / 'server/toque-war-favela.service').is_file():
            validate_war_favela_unit(verified_stage / 'server/toque-war-favela.service')
        elif WAR_FAVELA_UNIT.is_file():
            raise ValueError('Release omits the installed Favela War service artifact')
        if (verified_stage / 'server/toque-br.service').is_file():
            validate_br_unit(verified_stage / 'server/toque-br.service')
        elif BR_UNIT.is_file():
            raise ValueError('Release omits the installed BR service artifact')
        current = 0
        if (WEB / 'manifest.json').exists():
            current = int(verify(WEB / 'manifest.json')[0]['version'])
        if client['version'] <= current:
            raise ValueError('Release must increase the build number')
        guard_players()
        if '--check' in sys.argv:
            print('VERIFIED_READY build=' + str(client['version']))
            return
        backup = pathlib.Path('/var/backups/toque-de-campo')
        backup.mkdir(mode=0o700, parents=True, exist_ok=True)
        with sqlite3.connect('file:/var/lib/toque-de-campo/accounts/accounts.sqlite?mode=ro', uri=True) as source:
            with sqlite3.connect(str(backup / ('before-build-' + str(client['version']) + '.sqlite'))) as dest:
                source.backup(dest)
        release = APP / 'releases' / ('build-' + str(client['version']))
        if release.exists():
            expected = {'ToqueDeCampo.x86_64': metadata['hashes']['server/ToqueDeCampo.x86_64'],
                        'ToqueDeCampo.pck': metadata['hashes']['server/ToqueDeCampo.pck'],
                        'server-manifest.json': hashlib.sha256(signed_metadata).hexdigest()}
            if release.is_symlink() or any(not (release / name).is_file() or (release / name).is_symlink() or sha(release / name) != digest for name, digest in expected.items()):
                raise RuntimeError('Existing build directory differs from the authenticated release')
        else:
            release.mkdir(parents=True)
            for name in ('ToqueDeCampo.x86_64', 'ToqueDeCampo.pck'):
                atomic_copy(verified_stage / 'server' / name, release / name, 0o755 if name.endswith('x86_64') else 0o644)
            atomic_copy(verified_stage / 'server-manifest.json', release / 'server-manifest.json')
        activate(verified_stage, client, archive, release)
        print('DEPLOYED build=' + str(client['version']) + ' version=' + str(client['version_name']))


def main():
    if sys.argv[1:] not in ([], ['--check']):
        raise SystemExit('Usage: toque-deploy [--check]')
    # Linux only. Import inside main keeps isolated tests usable on Windows.
    import fcntl
    with open('/run/lock/toque-deploy.lock', 'a', encoding='utf-8') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        deploy()


if __name__ == '__main__':
    main()
