"""Export Windows game + launcher and atomically publish a signed release."""
from __future__ import annotations
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import zipfile
from release_notes import load_notes

ROOT = Path(__file__).resolve().parent
PROJECT = ROOT.parent
DEFAULT_GODOT = Path(r'C:\Users\Joao Borges\Documents\Codex\tools\Godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe')
CLIENT_FILES = ('ToqueDeCampo.exe', 'ToqueDeCampo.pck',
                'libgodotopus.windows.template_release.x86_64.dll')

def run(godot, *arguments):
    command = [str(godot), '--headless', '--log-file', str(ROOT / 'build' / 'export-engine.log'), *map(str, arguments)]
    environment=os.environ.copy()
    package_key=ROOT/'private'/'pck-key.hex'
    if package_key.is_file():
        value=package_key.read_text(encoding='ascii').strip()
        if len(value)!=64 or any(char not in '0123456789abcdef' for char in value): raise RuntimeError('Chave de proteção do pacote inválida.')
        environment['GODOT_SCRIPT_ENCRYPTION_KEY']=value
    result = subprocess.run(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True,env=environment,
                            creationflags=getattr(subprocess, 'CREATE_NO_WINDOW', 0))
    (ROOT / 'build' / 'last-export.log').write_text(result.stdout, encoding='utf-8')
    if result.returncode or 'SCRIPT ERROR:' in result.stdout or 'Export failed' in result.stdout:
        raise RuntimeError(result.stdout[-12000:])

def sha(path):
    with path.open('rb') as source:
        return hashlib.file_digest(source, 'sha256').hexdigest()

def client_files(game):
    """Only the explicitly approved runtime files may enter a client release."""
    files = {}
    for name in CLIENT_FILES:
        path = game / name
        if not path.is_file() or path.stat().st_size < 1:
            raise RuntimeError('Exportacao incompleta: ' + name)
        files[name] = {'size': path.stat().st_size, 'sha256': sha(path)}
    return files

def publish(args):
    notes = load_notes(args.version)
    godot = args.godot
    game = ROOT / 'build' / 'game'
    game.mkdir(parents=True, exist_ok=True)
    public = ROOT / 'published'
    (public / 'releases').mkdir(parents=True, exist_ok=True)
    private = ROOT / 'private'
    private.mkdir(exist_ok=True)
    if not (private/'pck-key.hex').is_file() or not (private/'templates/godot.windows.template_release.x86_64.exe').is_file():
        raise RuntimeError('Runtime protegido ou chave de proteção ausente. A publicação não pode usar um pacote sem criptografia.')
    key = private / 'release-private.pem'
    pub = ROOT / 'launcher' / 'release-public.pem'
    manifest_path = public / 'manifest.json'
    if key.exists() != pub.exists():
        raise RuntimeError('Par de chaves incompleto. Restaure o backup; nao gere outra chave para launchers existentes.')
    if not key.exists():
        if manifest_path.exists(): raise RuntimeError('Chaves da publicacao anterior ausentes.')
        run(godot, '--path', ROOT / 'launcher', '--script', ROOT / 'launcher' / 'sign.gd',
            '--', 'keygen', key, pub)
    run(godot, '--path', PROJECT, '--export-release', 'Windows Desktop', game / 'ToqueDeCampo.exe')
    files = client_files(game)
    if not manifest_path.exists() or args.launcher:
        run(godot, '--path', ROOT / 'launcher', '--editor', '--import')
        run(godot, '--path', ROOT / 'launcher', '--export-release', 'Windows Desktop', ROOT / 'build' / 'ToqueDeCampo.exe')
        launcher = ROOT / 'build' / 'ToqueDeCampo.exe'
        import shutil
        shutil.copy2(launcher, public / 'ToqueDeCampo.exe.tmp')
        os.replace(public / 'ToqueDeCampo.exe.tmp', public / 'ToqueDeCampo.exe')
    previous = 0
    if manifest_path.exists():
        import base64
        envelope = json.loads(manifest_path.read_text(encoding='utf-8'))
        previous = int(json.loads(base64.b64decode(envelope['payload']))['version'])
    version = previous + 1
    archive = ROOT / 'build' / 'release.zip'
    with zipfile.ZipFile(archive, 'w', compression=zipfile.ZIP_DEFLATED, compresslevel=6) as output:
        for name in CLIENT_FILES:
            output.write(game / name, name)
    digest = sha(archive)
    archive_name = f'game-{version}-{digest[:12]}.zip'
    payload = {
        'schema': 1, 'version': version, 'version_name': args.version or f'1.0.{previous}',
        'release_notes': notes,
        'archive': f'releases/{archive_name}', 'size': archive.stat().st_size, 'sha256': digest,
        'files': files,
    }
    payload_path = ROOT / 'build' / 'payload.json'
    payload_path.write_text(json.dumps(payload, separators=(',', ':')), encoding='utf-8')
    envelope_path = ROOT / 'build' / 'manifest.json'
    run(godot, '--path', ROOT / 'launcher', '--script', ROOT / 'launcher' / 'sign.gd',
        '--', 'sign', key, payload_path, envelope_path)
    import shutil
    shutil.copy2(archive, public / 'releases' / (archive_name + '.tmp'))
    os.replace(public / 'releases' / (archive_name + '.tmp'), public / 'releases' / archive_name)
    # Switch manifest last: clients see either the complete old or complete new release.
    shutil.copy2(envelope_path, public / 'manifest.json.tmp')
    os.replace(public / 'manifest.json.tmp', manifest_path)
    print(f'Publicado {payload["version_name"]} (build {version}), {payload["size"] / 1048576:.1f} MB')
    print('Executavel para os amigos:', public / 'ToqueDeCampo.exe')
    print('Downloads Ubuntu: https://192.168.101.24/')
    if not args.skip_xampp:
        from prepare_xampp import prepare
        prepare(godot, rebuild_launcher=args.launcher)

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', type=Path, default=DEFAULT_GODOT)
    parser.add_argument('--version', help='Nome exibido; o numero de build sempre aumenta automaticamente')
    parser.add_argument('--skip-xampp', action='store_true', help='Preparar a publicacao para outro servidor')
    parser.add_argument('--launcher', action='store_true', help='Reexportar o launcher para novas distribuicoes')
    publish(parser.parse_args())
