"""Compact report for one-world AA/AB sessions; never a publish decision."""
from pathlib import Path
import json
import re
import statistics
import sys

if len(sys.argv) != 2 or not re.fullmatch(r'nova-session-(aa|ab)-\d{8}-\d{6}', sys.argv[1]):
    raise SystemExit('Informe o identificador SESSION_RUN.')
prefix = sys.argv[1]
work = Path(__file__).resolve().parents[1] / 'work'
session = json.loads((work / f'{prefix}.json').read_text(encoding='utf-8-sig'))
hardware = [json.loads(line) for line in (work / f'{prefix}-hardware.jsonl').read_text(encoding='utf-8-sig').splitlines() if line.strip()]
pairs = int(session['pairs'])
if pairs < 5 or pairs > 7 or float(session['seconds']) not in (60.0, 120.0):
    raise SystemExit('Esta série não usa os 5–7 pares de 60 ou 120 s exigidos.')
order = [item for n in range(1, pairs + 1) for item in (f'a{n}', f'b{n}')] + [f'a{pairs + 1}']
reports = session['reports']
if [d['label'] for d in reports] != order:
    raise SystemExit('Sequência incompleta ou fora da ordem intercalada.')
mode = str(session['mode'])
records = {}
rows = []
for d in reports:
    name = d['label']
    expected_level = int(session['quality']) if mode == 'ab' and name.startswith('b') else 0
    if int(d['actors']) != 18 or d['resolution'] != '(1920.0, 1080.0)' or int(d['level']) != expected_level or float(d['sample_ms']) < float(session['seconds']) * 900:
        raise SystemExit(f'Cenário incompleto ou divergente em {name}.')
    samples = [s for s in hardware if d['start_unix'] <= s['unix'] <= d['end_unix']]
    outsiders = [p for s in samples for p in s.get('external_processes', []) if float(p['cpu_cores']) >= .5]
    reasons = []
    if len(samples) < 5: reasons.append('telemetria insuficiente')
    if outsiders: reasons.append('carga externa: ' + ', '.join(sorted({str(p['name']) for p in outsiders})))
    if any('gpu_error' in s or 'cpu_error' in s for s in samples): reasons.append('sensor com falha')
    def avg(key):
        values = [float(s[key]) for s in samples if s.get(key) is not None]
        return statistics.mean(values) if values else None
    def fmt(value): return f'{value:.0f}' if value is not None else '—'
    record = {'valid': not reasons, 'reasons': reasons, 'gpu_temp_c': avg('gpu_temp_c'), 'gpu_clock_mhz': avg('gpu_clock_mhz'), 'cpu_estimated_mhz': avg('cpu_estimated_mhz'), 'gpu_memory_used_mib': avg('gpu_memory_used_mib'), 'result': d}
    records[name] = record
    low = float(d.get('one_percent_low_fps', 1000 / d['p99_ms']))
    rows.append(f"| {name.upper()} | {d['fps']:.1f}/{d['median_fps']:.1f} | {low:.1f} | {d['p99_ms']:.1f} | {d['over33_per_min']:.1f} | {d['worst_ms']:.1f} | {int(d['draw_calls'])} | {fmt(record['gpu_temp_c'])}/{fmt(record['gpu_clock_mhz'])} | {fmt(record['cpu_estimated_mhz'])} | {fmt(record['gpu_memory_used_mib'])} | {'sim' if record['valid'] else 'não'} |")
comparisons = []
for n in range(1, pairs + 1):
    names = [f'a{n}', f'b{n}', f'a{n+1}']
    if not all(records[k]['valid'] for k in names): continue
    a, b, c = [records[k]['result'] for k in names]
    comparison = {'pair': n}
    for field in ('median_fps', 'p99_ms', 'over33_per_min'):
        reference = statistics.mean([float(a[field]), float(c[field])])
        comparison[field + '_delta_abs'] = float(b[field]) - reference
        comparison[field + '_delta_percent'] = (float(b[field]) / reference - 1) * 100 if reference > 0 else None
    comparisons.append(comparison)
def aggregate(field):
    values = [float(p[field + '_delta_percent']) for p in comparisons if p[field + '_delta_percent'] is not None]
    if not values: return 'indisponível'
    if mode == 'aa': values = [abs(v) for v in values]
    return f'{statistics.median(values):+.1f}% (pico {max(abs(v) for v in values):.1f}%)'
invalid = {name: value['reasons'] for name, value in records.items() if not value['valid']}
summary = {'mode': mode, 'valid_pairs': len(comparisons), 'comparisons': comparisons, 'invalid': invalid, 'records': records, 'release_approved': False, 'scope': 'One-world camera-route session, not player/vehicle traversal, networking or publish acceptance. CPU temperature unavailable; hardware/process sampling can miss interference.'}
(work / f'{prefix}-summary.json').write_text(json.dumps(summary, ensure_ascii=False, indent=2), encoding='utf-8')
lines = ['| Execução | FPS média/mediana | 1% low | p99 ms | >33/min | Pior ms | Draws | GPU °C/MHz | CPU MHz est. | VRAM MiB | Válida |', '|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|', *rows,
         f"Pares válidos {len(comparisons)}/{pairs}; {'ruído A/A' if mode == 'aa' else 'B vs referências'}: FPS {aggregate('median_fps')}; p99 {aggregate('p99_ms')}; >33/min {aggregate('over33_per_min')}.",
         'Inválidas por processo externo ≥0,5 núcleo, telemetria insuficiente ou falha de sensor. CPU térmica indisponível; detalhes no JSON.',
         'Sem aprovação de desempenho/publicação: exige ≥5 pares válidos, ruído aceitável e demais testes físicos/multiplayer.']
(work / f'{prefix}-summary.md').write_text('\n'.join(lines) + '\n', encoding='utf-8')
print('\n'.join(lines))
