"""Smoke an existing protected game export; never export, sign or publish it."""
from __future__ import annotations
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import time

from publish import CLIENT_FILES

ROOT = Path(__file__).resolve().parent.parent


def digest(path):
    with path.open('rb') as source:
        return hashlib.file_digest(source, 'sha256').hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--game', type=Path, default=ROOT / 'distribution/build/game/ToqueDeCampo.exe')
    parser.add_argument('--timeout', type=int, default=60)
    parser.add_argument('--boot-only', action='store_true',
        help='Normal protected startup only; no script/path override or codec call')
    args = parser.parse_args()
    game = args.game.resolve()
    expected = [game.parent / name for name in CLIENT_FILES]
    for path in expected:
        if not path.is_file() or not path.stat().st_size:
            raise SystemExit('Export incomplete: ' + str(path))
    if game.name != CLIENT_FILES[0]:
        raise SystemExit('Expected production game filename: ' + CLIENT_FILES[0])
    work = ROOT / 'work' / 'exported-client-smoke' / str(time.time_ns())
    work.mkdir(parents=True)
    report_path = work / 'result.json'
    log_path = work / 'runtime.log'
    provenance = {path.name: {'size': path.stat().st_size, 'sha256': digest(path)} for path in expected}
    # Working beside the executable loads its paired PCK and prevents accidental
    # editor fallback. Protected templates forbid --path and --main-pack; never
    # weaken those protections just to run a smoke check.
    command = [str(game), '--headless', '--audio-driver', 'Dummy', '--log-file', str(log_path)]
    command += ['--max-fps', '60', '--quit-after', '180'] if args.boot_only else [
        '--script', str(ROOT / 'qa/exported_client_smoke.gd'), '--', '--report=' + str(report_path)]
    process = subprocess.Popen(command, cwd=game.parent, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
        text=True, encoding='utf-8', errors='replace',
        creationflags=getattr(subprocess, 'CREATE_NO_WINDOW', 0))
    modules = []
    if args.boot_only:
        time.sleep(1)
        if process.poll() is None:
            probe = subprocess.run(['powershell', '-NoProfile', '-Command',
                f'Get-Process -Id {process.pid} -ErrorAction SilentlyContinue | '
                'Select-Object -ExpandProperty Modules | '
                'Where-Object { $_.ModuleName -like "*godotopus*" } | '
                'Select-Object ModuleName,FileName | ConvertTo-Json -Compress'],
                stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, encoding='utf-8', errors='replace',
                timeout=8, creationflags=getattr(subprocess, 'CREATE_NO_WINDOW', 0))
            (work / 'modules.log').write_text(probe.stdout, encoding='utf-8')
            if probe.stdout.strip():
                try:
                    found = json.loads(probe.stdout)
                    modules = found if isinstance(found, list) else [found]
                except json.JSONDecodeError:
                    pass
    timed_out = False
    try:
        output = process.communicate(timeout=args.timeout)[0]
    except subprocess.TimeoutExpired:
        timed_out = True
        process.kill()
        output = process.communicate()[0]
    (work / 'process.log').write_text(output, encoding='utf-8')
    text = output + (log_path.read_text(encoding='utf-8', errors='replace') if log_path.exists() else '')
    if args.boot_only:
        loaded_codec = any(Path(record.get('FileName', '')).resolve() == expected[-1].resolve() for record in modules)
        report = {'ok': loaded_codec, 'loaded_codec_modules': modules,
            'scope': 'Normal protected startup and loaded DLL only; no encoded/decoded frames or resource assertions'}
    elif report_path.exists():
        report = json.loads(report_path.read_text(encoding='utf-8'))
    else:
        report = {'ok': False, 'failures': ['External QA script did not produce a report'],
            'scope': 'Incomplete exported QA invocation; no successful codec/resource assertion'}
    report['package'] = provenance
    report['work'] = str(work)
    report['exit_code'] = process.returncode
    report['timed_out'] = timed_out
    report['package_unchanged'] = all(path.stat().st_size == provenance[path.name]['size']
        and digest(path) == provenance[path.name]['sha256'] for path in expected)
    report['ok'] = bool(report.get('ok')) and not timed_out and process.returncode == 0 and report['package_unchanged'] \
        and 'SCRIPT ERROR:' not in text and 'ERROR:' not in text
    (work / 'results.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
    (ROOT / 'work/exported-client-smoke.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
    print(json.dumps(report))
    if not report['ok']:
        raise SystemExit(1)


if __name__ == '__main__':
    main()
