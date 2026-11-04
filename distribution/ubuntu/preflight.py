"""Barreira antes do envio: recusa cedo o que o helper root recusaria tarde.

O `--deploy-only` envia centenas de MB antes de o helper autenticar o release.
Esta verificação reproduz as duas recusas previsíveis - build que não aumenta e
diretório de release já existente com conteúdo diferente - sem alterar nada na
VM. Sai com código 3 ou 4 e mensagem acionável; não envia arquivo algum.
"""
import argparse
import base64
import hashlib
import json
import pathlib
import ssl
import sys
import urllib.error
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parents[2]
SERVER = 'https://192.168.101.24'
CA = ROOT / 'assets/accounts/accounts-ca.crt'
RELEASE_FILES = ('ToqueDeCampo.x86_64', 'ToqueDeCampo.pck')


def payload_of(envelope_path):
    envelope = json.loads(envelope_path.read_text(encoding='utf-8'))
    return json.loads(base64.b64decode(envelope['payload'], validate=True)), envelope


def sha(path):
    with path.open('rb') as source:
        return hashlib.file_digest(source, 'sha256').hexdigest()


def abort(code, message):
    print('PREFLIGHT_FALHOU ' + message, file=sys.stderr, flush=True)
    raise SystemExit(code)


def live_build():
    context = ssl.create_default_context(cafile=str(CA))
    try:
        with urllib.request.urlopen(SERVER + '/manifest.json', context=context, timeout=15) as response:
            envelope = json.load(response)
        return int(json.loads(base64.b64decode(envelope['payload'], validate=True))['version'])
    except (urllib.error.URLError, OSError, ValueError, KeyError) as error:
        print('PREFLIGHT_AVISO servidor não consultado: ' + str(error), flush=True)
        return None


def differing_files(expected, remote):
    """Nomes cujo hash remoto não corresponde ao release autenticado."""
    return [name for name, digest in expected.items() if remote.get(name) != digest]


def remote_release(client, metadata, stage):
    sys.path.insert(0, str(ROOT / 'work/ssh-runtime'))
    import paramiko

    ssh = paramiko.SSHClient()
    ssh.load_host_keys(str(ROOT / 'distribution/private/ubuntu_known_hosts'))
    ssh.set_missing_host_key_policy(paramiko.RejectPolicy())
    ssh.connect('192.168.101.24', username='microgate',
                key_filename=str(ROOT / 'distribution/private/ubuntu_deploy_rsa'),
                look_for_keys=False, allow_agent=False, timeout=15)
    try:
        folder = '/opt/toque-de-campo/releases/build-' + str(client['version'])
        sftp = ssh.open_sftp()
        try:
            sftp.stat(folder)
        except IOError:
            return None
        finally:
            sftp.close()
        # Same three files the privileged helper authenticates before switching.
        expected = {name: metadata['hashes']['server/' + name] for name in RELEASE_FILES}
        expected['server-manifest.json'] = sha(stage / 'server-manifest.json')
        _, out, err = ssh.exec_command(
            'sha256sum -- ' + ' '.join(folder + '/' + name for name in expected), timeout=60)
        lines = out.read().decode().splitlines()
        error = err.read().decode().strip()
        if out.channel.recv_exit_status() or error:
            return {'folder': folder, 'error': error or 'falha ao ler hashes remotos'}
        remote = {line.split()[-1].rsplit('/', 1)[-1]: line.split()[0] for line in lines if line.strip()}
        differing = differing_files(expected, remote)
        return {'folder': folder, 'differing': differing}
    finally:
        ssh.close()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--stage', default='distribution/build/ubuntu')
    args = parser.parse_args()
    stage = pathlib.Path(args.stage)
    if not stage.is_absolute():
        stage = ROOT / stage
    stage = stage.resolve()
    if not (stage / 'server-manifest.json').is_file() or not (stage / 'public/manifest.json').is_file():
        abort(2, 'release não preparado em ' + str(stage) + '; rode o prepare antes.')
    metadata, _ = payload_of(stage / 'server-manifest.json')
    client, _ = payload_of(stage / 'public/manifest.json')
    if metadata['build'] != client['version']:
        abort(2, 'manifesto do servidor e do cliente divergem no número do build.')
    build = int(client['version'])
    missing = [name for name in [*RELEASE_FILES, 'server-manifest.json']
               if not (stage / 'server' / name if name in RELEASE_FILES else stage / name).is_file()]
    if missing:
        abort(2, 'artefato ausente no release preparado: ' + ', '.join(missing))
    for name in RELEASE_FILES:
        if sha(stage / 'server' / name) != metadata['hashes']['server/' + name]:
            abort(2, 'artefato local difere do manifesto assinado: ' + name)

    live = live_build()
    if live is not None and build <= live:
        abort(3, f'o build {build} não aumenta o build publicado ({live}). Refaça o prepare: '
                 'o número é calculado a partir de distribution/published/manifest.json.')
    if live is not None:
        print(f'PREFLIGHT build={build} publicado={live}', flush=True)

    release = remote_release(client, metadata, stage)
    if release and 'differing' in release and release['differing']:
        abort(4, f'{release["folder"]} já existe com conteúdo diferente do release autenticado '
                 f'({", ".join(release["differing"])}). Remova esse diretório como root na VM '
                 'ou publique com o próximo build. Nada foi enviado.')
    if release and 'folder' in release:
        print('PREFLIGHT release idêntico já presente, reenvio permitido: ' + release['folder'], flush=True)
    print('PREFLIGHT_OK build=' + str(build), flush=True)


if __name__ == '__main__':
    main()
