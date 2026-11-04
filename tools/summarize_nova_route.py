from pathlib import Path
import json
import re
import statistics
import sys

if len(sys.argv) not in (2,3) or not re.fullmatch(r'nova-(?:route|natural)-aa-\d{8}-\d{6}', sys.argv[1]):
    raise SystemExit('Informe o identificador da série.')
prefix = sys.argv[1]
work = Path(__file__).resolve().parents[1] / 'work'
pair_count = 7 if prefix.startswith('nova-natural-aa-') else 5
if len(sys.argv)==3:
    pair_count=int(sys.argv[2])
    if pair_count not in (5,6,7): raise SystemExit('Use entre 5 e 7 pares completos.')
labels = [item for n in range(1, pair_count + 1) for item in (f'a{n}', f'b{n}')] + [f'a{pair_count + 1}']
data = {name: json.loads((work / f'{prefix}-{name}-offline.json').read_text(encoding='utf-8-sig')) for name in labels}
hardware = [json.loads(line) for line in (work / f'{prefix}-hardware.jsonl').read_text(encoding='utf-8-sig').splitlines() if line.strip()]
rows = []
valid = {}
for name, d in data.items():
    samples = [s for s in hardware if d['start_unix'] <= s['unix'] <= d['end_unix']]
    def mean(key):
        values = [float(s[key]) for s in samples if s.get(key) is not None]
        return statistics.mean(values) if values else None
    interfering = set()
    highest = ('—', 0.0)
    for sample in samples:
        for proc in sample.get('external_processes', []):
            value = float(proc['cpu_cores'])
            if value > highest[1]: highest = (str(proc['name']), value)
            if value >= .5: interfering.add(int(proc['id']))
    valid[name] = bool(samples) and not interfering
    def fmt(value): return f'{value:.0f}' if value is not None else '—'
    rows.append(f"| {name.upper()} | {d['median_fps']:.1f} | {d['frame_p99_ms']:.1f} | {d['over33_frames_per_minute']:.1f} | {d['worst_ms']:.1f} | {fmt(mean('gpu_temp_c'))}/{fmt(mean('gpu_clock_mhz'))} | {fmt(mean('cpu_estimated_mhz'))} | {highest[0]} {highest[1]:.2f} | {'sim' if valid[name] else 'não'} |")
def pair_error(field):
    errors = []
    for n in range(1, pair_count + 1):
        a, b, c = f'a{n}', f'b{n}', f'a{n+1}'
        if not all(valid[k] for k in (a,b,c)): continue
        baseline = statistics.mean([float(data[a][field]),float(data[c][field])])
        if baseline > 0: errors.append(abs(float(data[b][field]) / baseline - 1) * 100)
    return errors
def range_text(values):
    return f'mediana {statistics.median(values):.1f}%, máximo {max(values):.1f}% ({len(values)} pares)' if values else 'sem pares válidos'
lines = ['| Execução | FPS mediano | p99 ms | >33 ms/min | Pior ms | GPU °C/MHz | CPU MHz estimado | Maior processo externo, núcleos | Válida |',
         '|---|---:|---:|---:|---:|---:|---:|---|---|', *rows,
         f"Ruído FPS: {range_text(pair_error('median_fps'))}; p99: {range_text(pair_error('frame_p99_ms'))}; >33 ms/min: {range_text(pair_error('over33_frames_per_minute'))}.",
         'Inválida: sem telemetria ou qualquer processo externo ≥0,5 núcleo em uma amostra. Temperatura da CPU indisponível. Percurso por câmera; não é teste físico com jogador.' ]
out = work / f'{prefix}-summary.md'
out.write_text('\n'.join(lines) + '\n', encoding='utf-8')
print(out.read_text(encoding='utf-8'))
