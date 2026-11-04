"""Install an approved signed local package in QA and boot its protected client."""
from __future__ import annotations
import argparse
import base64
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import time

from publish import DEFAULT_GODOT

ROOT = Path(__file__).resolve().parent


def sha(path):
    with path.open('rb') as source:
        return hashlib.file_digest(source, 'sha256').hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--build', type=int, required=True)
    parser.add_argument('--manifest', type=Path, default=ROOT / 'published/manifest.json')
    parser.add_argument('--godot', type=Path, default=DEFAULT_GODOT)
    args = parser.parse_args()
    envelope = json.loads(args.manifest.read_text(encoding='utf-8'))
    payload = json.loads(base64.b64decode(envelope['payload']))
    archive_name = payload.get('archive', '')
    if not re.fullmatch(r'releases/game-[0-9]+-[a-f0-9]{12}\.zip', archive_name):
        raise SystemExit('Unexpected local package name')
    archive = args.manifest.parent / archive_name
    work = ROOT.parent / 'work/signed-install-validation' / str(time.time_ns())
    # Keep the installed native DLL below Win32 MAX_PATH, as in the launcher's
    # normal per-user location. The repository/work nesting is much deeper.
    install = Path(tempfile.mkdtemp(prefix=f'tdc-install-{args.build}-'))
    project = work / 'project'
    project.mkdir(parents=True)
    for name in ('launcher.gd', 'game-icon.png', 'release-public.pem'):
        shutil.copy2(ROOT / 'launcher' / name, project / name)
    shutil.copy2(ROOT / 'tests/signed_install_validation.gd', project / 'validation.gd')
    (project / 'project.godot').write_text('config_version=5\n[application]\nconfig/name="Signed installation QA only"\n'
        '[rendering]\nrenderer/rendering_method="gl_compatibility"\n', encoding='utf-8')

    def run(label, command, timeout=60):
        result = subprocess.run(list(map(str, command)), stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
            text=True, encoding='utf-8', errors='replace', timeout=timeout,
            creationflags=getattr(subprocess, 'CREATE_NO_WINDOW', 0))
        (work / (label + '.log')).write_text(result.stdout, encoding='utf-8')
        if result.returncode or 'ERROR:' in result.stdout:
            raise AssertionError(f'{label}: exit {result.returncode}\n{result.stdout[-6000:]}')
        return result

    run('import', [args.godot, '--headless', '--path', project, '--editor', '--import'])
    source_report = project / 'results.json'
    run('install', [args.godot, '--headless', '--path', project, '--script', 'res://validation.gd', '--',
        '--manifest=' + str(args.manifest.resolve()), '--archive=' + str(archive.resolve()),
        '--build=' + str(args.build), '--install=' + str(install), '--report=' + str(source_report)])
    installation = json.loads(source_report.read_text(encoding='utf-8'))
    executable = Path(installation['metrics']['installed_folder']) / 'ToqueDeCampo.exe'
    run('protected-boot', [sys.executable, ROOT / 'validate_exported_client.py', '--game', executable,
        '--boot-only', '--timeout', '20'], timeout=40)
    boot = json.loads((ROOT.parent / 'work/exported-client-smoke.json').read_text(encoding='utf-8'))
    report = {'ok': bool(installation.get('ok')) and bool(boot.get('ok')), 'installation': installation,
        'protected_boot': boot, 'public_key_sha256': sha(project / 'release-public.pem'),
        'launcher_source_sha256': sha(project / 'launcher.gd'), 'manifest_sha256': sha(args.manifest),
        'published_launcher_sha256': sha(ROOT / 'published/ToqueDeCampo.exe'),
        'work': str(work), 'scope': 'Real signed local build verified/extracted using only public key; installed protected EXE booted with DLL loaded. No private key, server download, export, publication or full codec call.'}
    (work / 'results.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
    destination = ROOT.parent / 'work/signed-install-validation.json'
    destination.write_text(json.dumps(report, indent=2), encoding='utf-8')
    print(json.dumps(report))
    if not report['ok']:
        raise SystemExit(1)


if __name__ == '__main__':
    main()
