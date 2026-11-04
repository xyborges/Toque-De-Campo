from pathlib import Path
import json
import re
import statistics
import sys

if len(sys.argv) != 2 or not re.fullmatch(r'breakage-ab-\d{8}-\d{6}', sys.argv[1]):
    raise SystemExit('Informe o identificador BENCH_RUN impresso pelo teste.')
prefix = sys.argv[1]
work = Path(__file__).resolve().parents[1] / 'work'
labels = ('a1', 'b1', 'a2', 'b2', 'a3', 'b3', 'a4')
data = {label: json.loads((work / f'{prefix}-{label}-offline.json').read_text(encoding='utf-8-sig')) for label in labels}
hardware = [json.loads(line) for line in (work / f'{prefix}-hardware.jsonl').read_text(encoding='utf-8-sig').splitlines() if line.strip()]
lines = ['| Execução | FPS | 1% low | Pior ms | GPU °C / MHz | CPU MHz estimado | Árvores | Corpos ativos |',
         '|---|---:|---:|---:|---:|---:|---:|---:|']
for label in labels:
    d = data[label]
    samples = [s for s in hardware if d['start_unix'] <= s['unix'] <= d['end_unix']]
    def avg(field):
        values = [float(s[field]) for s in samples if s.get(field) is not None]
        return f'{statistics.mean(values):.0f}' if values else '—'
    lines.append(f"| {label.upper()} | {d['fps']:.2f} | {d['one_percent_low']:.2f} | {d['worst_ms']:.2f} | {avg('gpu_temp_c')} / {avg('gpu_clock_mhz')} | {avg('cpu_estimated_mhz')} | {d['destroyed_trees']} | {d['active_debris_peak']} |")
lines += ['', '| Par | FPS B vs. referências adjacentes | 1% B vs. referências |', '|---|---:|---:|']
for n in range(1, 4):
    a1, b, a2 = data[f'a{n}'], data[f'b{n}'], data[f'a{n+1}']
    def delta(key): return (b[key] / statistics.mean([a1[key], a2[key]]) - 1) * 100
    lines.append(f"| B{n} | {delta('fps'):+.1f}% | {delta('one_percent_low'):+.1f}% |")
lines += ['', 'Alvos percorridos (a ordem e as coordenadas precisam ser equivalentes entre variantes):']
for label in labels:
    lines.append(f"- {label.upper()}: {data[label]['target_positions']}")
lines += ['', 'Pior quadro em até 200 ms após cada evento (não atribui causalidade isoladamente):']
for label in labels:
    d = data[label]
    frames = d.get('motion_probe', {}).get('frames', [])
    near = []
    for event in d.get('scenario_events', []):
        after = [float(frame[1]) for frame in frames if float(event.get('elapsed_ms', -1000)) <= float(frame[0]) <= float(event.get('elapsed_ms', -1000)) + 200]
        if after:
            near.append(f"{event['kind']} {max(after):.1f} ms")
    lines.append(f"- {label.upper()}: " + ', '.join(near))
out = work / f'{prefix}-summary.md'
out.write_text('\n'.join(lines) + '\n', encoding='utf-8')
print(out.read_text(encoding='utf-8'))
