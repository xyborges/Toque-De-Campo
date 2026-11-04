"""Validate the exact native client package without exports or production keys."""
from __future__ import annotations
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import time

from publish import CLIENT_FILES, DEFAULT_GODOT, client_files

ROOT = Path(__file__).resolve().parent


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', type=Path, default=DEFAULT_GODOT)
    args = parser.parse_args()
    work = ROOT.parent / 'work' / 'native-package-validation' / str(time.time_ns())
    project = work / 'project'
    project.mkdir(parents=True)
    for name in ('launcher.gd', 'game-icon.png'):
        shutil.copy2(ROOT / 'launcher' / name, project / name)
    shutil.copy2(ROOT / 'tests' / 'native_package_validation.gd', project / 'validation.gd')
    (project / 'project.godot').write_text('config_version=5\n[application]\nconfig/name="Native package QA only"\n'
        '[rendering]\nrenderer/rendering_method="gl_compatibility"\n', encoding='utf-8')

    # Publisher uses the same explicit set for completeness, ZIP entries and the
    # signed per-file manifest. Unknown files in the export folder never join it.
    game = work / 'publisher-fixture'
    game.mkdir()
    for name in CLIENT_FILES:
        (game / name).write_bytes(('QA only: ' + name).encode())
    (game / 'extra.dll').write_bytes(b'excluded QA payload')
    files = client_files(game)
    assert tuple(files) == CLIENT_FILES and len(files) == 3
    assert 'extra.dll' not in files
    for name, record in files.items():
        data = (game / name).read_bytes()
        assert record == {'size': len(data), 'sha256': hashlib.sha256(data).hexdigest()}
    dll = game / CLIENT_FILES[-1]
    dll_bytes = dll.read_bytes()
    dll.unlink()
    for reason in ('missing DLL', 'empty DLL'):
        try:
            client_files(game)
        except RuntimeError as error:
            assert CLIENT_FILES[-1] in str(error)
        else:
            raise AssertionError('Publisher accepted ' + reason)
        dll.write_bytes(b'')
    dll.write_bytes(dll_bytes)

    def run(label, *arguments):
        result = subprocess.run([str(args.godot), '--headless', '--path', str(project), *arguments],
            stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, encoding='utf-8', errors='replace',
            timeout=60, creationflags=getattr(subprocess, 'CREATE_NO_WINDOW', 0))
        (work / (label + '.log')).write_text(result.stdout, encoding='utf-8')
        if result.returncode or 'SCRIPT ERROR:' in result.stdout:
            raise AssertionError(label + ': ' + result.stdout)

    run('import', '--editor', '--import')
    run('validation', '--script', 'res://validation.gd')
    report = json.loads((project / 'results.json').read_text(encoding='utf-8'))
    report['publisher_checks'] = 7
    report['work'] = str(work)
    destination = ROOT.parent / 'work' / 'native-package-validation.json'
    destination.write_text(json.dumps(report, indent=2), encoding='utf-8')
    print(json.dumps(report))


if __name__ == '__main__':
    main()
