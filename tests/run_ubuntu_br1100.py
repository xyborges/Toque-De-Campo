"""Two real BR clients against the published server; no test account/route flags."""
from pathlib import Path
import json
import subprocess
import time

ROOT = Path(__file__).resolve().parent.parent
ENGINE = Path(r'C:\Users\Joao Borges\Documents\Codex\tools\Godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe')


def main():
    processes = []
    for role in ('host', 'guest'):
        for suffix in ('.json', '.stage.json'):
            (ROOT / f'work/ubuntu-br1100-{role}{suffix}').unlink(missing_ok=True)
    try:
        for role in ('host', 'guest'):
            output = (ROOT / f'work/ubuntu-br1100-{role}.stdout.log').open('w', encoding='utf-8')
            command = [str(ENGINE), '--headless', '--audio-driver', 'Dummy', '--max-fps', '60', '--path', str(ROOT),
                '--script', 'tests/ubuntu_br1100.gd', '--log-file', str(ROOT / f'work/ubuntu-br1100-{role}.log'), '--',
                '--role=' + role, '--naval-data=' + str(ROOT / f'work/ubuntu-br1100-{role}-account-data')]
            process = subprocess.Popen(command, cwd=ROOT, stdout=output, stderr=subprocess.STDOUT,
                creationflags=getattr(subprocess, 'CREATE_NO_WINDOW', 0))
            processes.append((role, process, output))
            time.sleep(.4)
        deadline = time.monotonic() + 165
        while time.monotonic() < deadline and any(process.poll() is None for _, process, _ in processes):
            time.sleep(.25)
        reports = {}
        failed = []
        for role, process, output in processes:
            output.flush()
            path = ROOT / f'work/ubuntu-br1100-{role}.json'
            report = json.loads(path.read_text(encoding='utf-8')) if path.exists() else {'ok': False, 'failures': ['no final report']}
            text = (ROOT / f'work/ubuntu-br1100-{role}.stdout.log').read_text(encoding='utf-8', errors='replace')
            report['exit_code'] = process.poll()
            report['log_errors'] = 'SCRIPT ERROR:' in text or '\nERROR:' in text
            reports[role] = report
            if process.poll() != 0 or not report.get('ok') or report['log_errors']:
                failed.append(role)
                print(role, text[-6000:], flush=True)
        summary = {'ok': not failed, 'clients': reports, 'failed': failed,
            'server': '192.168.101.24', 'broker_port': 3016,
            'configured_parallel_room_limit': 2, 'configured_room_ports': [3020, 3021],
            'parallelism_scope': 'Limit from deployed service configuration; live test exercises one shared room, not two concurrent rooms'}
        (ROOT / 'work/ubuntu-br1100-summary.json').write_text(json.dumps(summary, indent=2), encoding='utf-8')
        print(json.dumps({'ok': summary['ok'], 'failed': failed, 'reports': {role: {'checks': result.get('checks'),
            'failures': result.get('failures'), 'route': result.get('route'), 'elapsed_seconds': result.get('elapsed_seconds')}
            for role, result in reports.items()}}), flush=True)
        if failed:
            raise SystemExit(1)
    finally:
        for _, process, output in processes:
            if process.poll() is None:
                process.terminate()
                try: process.wait(timeout=5)
                except subprocess.TimeoutExpired: process.kill(); process.wait(timeout=5)
            output.close()


if __name__ == '__main__':
    main()
