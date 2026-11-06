"""Fresh-process A/A or A/B CPU gate. Saves raw trials, paired deltas and source hashes."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import statistics
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--engine', required=True, type=Path)
    parser.add_argument('--pairs', type=int, default=5)
    parser.add_argument('--samples', type=int, default=600)
    parser.add_argument('--warmup', type=int, default=120)
    parser.add_argument('--mode', choices=('aa', 'ab'), default='ab')
    parser.add_argument('--profile', action='store_true')
    parser.add_argument('--control', type=Path, help='A/A control on the same source and machine')
    parser.add_argument('--output', type=Path, default=ROOT/'work/p1g-perf/results.json')
    args = parser.parse_args()
    if args.pairs < 1 or args.samples < 60 or args.warmup < 0:
        parser.error('Require pairs >= 1, samples >= 60, warmup >= 0')
    files = ['modes/war/scripts/player.gd', 'modes/war/scripts/collision_pose_solver.gd',
             'modes/war/scripts/collision_rig_proxy.gd', 'tests/true_fpp_p1g_paired_cost.gd']
    def source_hashes():
        return {name: hashlib.sha256((ROOT/name).read_bytes()).hexdigest() for name in files}
    hashes = source_hashes()
    engine = args.engine.resolve()
    # The Windows console executable spawns a second engine process. Launch
    # the actual engine with redirected handles so timeout/interrupt kills it
    # directly instead of leaving a CPU-heavy orphan behind.
    sibling = engine.with_name(engine.name.replace('_console.exe', '.exe'))
    if os.name == 'nt' and sibling.is_file():
        engine = sibling
    engine_hash = hashlib.sha256(engine.read_bytes()).hexdigest()
    directory = Path(tempfile.mkdtemp(prefix='p1g-paired-'))
    trials = []
    deltas = []
    for pair in range(args.pairs):
        group = {}
        for arm in ('A', 'B') if pair % 2 == 0 else ('B', 'A'):
            pilot = args.mode == 'ab' and arm == 'B'
            run_dir = directory / f'{pair}-{arm}'
            run_dir.mkdir()
            environment = os.environ.copy()
            environment['APPDATA'] = str(run_dir)
            command = [str(engine), '--headless', '--path', str(ROOT),
                       '--log-file', str(run_dir/'engine.log'), '--script',
                       'res://tests/true_fpp_p1g_paired_cost.gd', '--',
                       f'--samples={args.samples}', f'--warmup={args.warmup}',
                       '--naval-test-accounts', f'--naval-data={run_dir}/data']
            if pilot:
                command.append('--pilot')
            if args.profile:
                command.append('--profile')
            result = subprocess.run(command, cwd=ROOT, env=environment, text=True,
                                    encoding='utf-8', errors='replace', stdout=subprocess.PIPE,
                                    stderr=subprocess.STDOUT,
                                    timeout=60+(args.samples+args.warmup)/30,
                                    creationflags=getattr(subprocess, 'CREATE_NO_WINDOW', 0))
            (run_dir/'stdout.log').write_text(result.stdout, encoding='utf-8')
            reports = [json.loads(line[len('P1G_PAIRED '):]) for line in result.stdout.splitlines()
                       if line.startswith('P1G_PAIRED ')]
            if result.returncode or len(reports) != 1 or 'ERROR:' in result.stdout:
                raise RuntimeError(f'Invalid trial {pair}/{arm}: {result.stdout[-4000:]}')
            report = reports[0]
            if source_hashes() != hashes:
                raise RuntimeError('Source changed during measurement')
            if report['errors'] or report['pilot'] != pilot:
                raise RuntimeError(f'Invalid workload: {report}')
            report.update(pair=pair, arm=arm)
            group[arm] = report
            trials.append(report)
            print(json.dumps({'pair': pair, 'arm': arm, 'loop_ms': report['loop_ms'],
                              'fallback': report['fallback_reasons'], 'cost_us': report['profile_usec']}), flush=True)
        if any(group['A'][key] != group['B'][key] for key in ('visual_updates', 'state_sha256')):
            raise RuntimeError('Presentation workload or logical state differed between arms')
        deltas.append({key: (group['B']['loop_ms'][key]/group['A']['loop_ms'][key]-1)*100
                       for key in ('p50', 'p95', 'p99', 'mean')})
    median = {key: statistics.median(delta[key] for delta in deltas) for key in deltas[0]}
    report = {'mode': args.mode, 'profile': args.profile, 'trials': trials, 'paired_delta_percent': deltas,
              'median_delta_percent': median,
              'raw_threshold_pass': median['p50'] <= 0 and median['p99'] <= 5,
              'scope': 'Fixed synthetic 28-actor CPU/physics load; not full-map rendered/network release certification',
              'platform': platform.platform(), 'processor': platform.processor(), 'logs': str(directory),
              'engine': str(engine), 'engine_sha256': engine_hash, 'sha256': hashes}
    report['control_noise_percent'] = {key: max(abs(delta[key]) for delta in deltas)
                                       for key in ('p50', 'p99')} if args.mode == 'aa' else None
    report['control_valid'] = False
    if args.control:
        control = json.loads(args.control.read_text(encoding='utf-8'))
        report['control_valid'] = (
            control['mode'] == 'aa' and not control['profile'] and len(control['trials']) >= 10
            and control['sha256'] == report['sha256'] and control['platform'] == report['platform']
            and control['engine_sha256'] == report['engine_sha256']
            and all(control['control_noise_percent'][key] <= 5 for key in ('p50', 'p99'))
            and control['trials'][0]['samples'] == args.samples
            and control['trials'][0]['warmup'] == args.warmup
        )
    report['cpu_fixture_pass'] = (args.mode == 'ab' and not args.profile and args.pairs >= 5
                                  and report['control_valid'] and report['raw_threshold_pass'])
    report['status'] = ('pass_cpu_fixture' if report['cpu_fixture_pass'] else
                        'regression_observed' if args.mode == 'ab' and not report['raw_threshold_pass'] else
                        'inconclusive_control' if not report['control_valid'] else 'diagnostic')
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, indent=2), encoding='utf-8')
    print('P1G_SUMMARY', json.dumps({key: report[key] for key in ('mode', 'median_delta_percent', 'status', 'cpu_fixture_pass', 'logs')}), flush=True)
    return 0 if report['cpu_fixture_pass'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
