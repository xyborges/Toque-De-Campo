from pathlib import Path
import json
import re
import statistics
import sys

if len(sys.argv) != 2 or not re.fullmatch(r'(?:nova-grama9|nova-ground|nova-details|nova-mask)-\d{8}-\d{6}', sys.argv[1]):
    raise SystemExit('Informe o identificador BENCH_RUN impresso pelo teste.')
prefix = sys.argv[1]
work = Path(__file__).resolve().parents[1] / 'work'
labels = ('a1', 'b1', 'a2', 'b2', 'a3', 'b3', 'a4')
data = {label: json.loads((work / f'{prefix}-{label}-offline.json').read_text(encoding='utf-8-sig')) for label in labels}
hardware = [json.loads(line) for line in (work / f'{prefix}-hardware.jsonl').read_text(encoding='utf-8-sig').splitlines() if line.strip()]
lines = ['| Execução | FPS | 1% low | Pior ms | Desenhos | Primitivas | GPU °C / MHz | VRAM usada MiB | CPU MHz estimado | Nós | Memória MiB |',
         '|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|']
for label in labels:
    d = data[label]
    samples = [s for s in hardware if d['start_unix'] <= s['unix'] <= d['end_unix']]
    def avg(field):
        values = [float(s[field]) for s in samples if s.get(field) is not None]
        return f'{statistics.mean(values):.0f}' if values else '—'
    lines.append(f"| {label.upper()} | {d['fps']:.2f} | {d['one_percent_low']:.2f} | {d['worst_ms']:.2f} | {d['draw_calls']:.0f} | {d['max_primitives']:.0f} | {avg('gpu_temp_c')} / {avg('gpu_clock_mhz')} | {avg('gpu_memory_used_mib')} | {avg('cpu_estimated_mhz')} | {d['nodes']:.0f} | {d['static_memory_mib']:.1f} |")
lines += ['', '| Par | FPS B vs. referências adjacentes | 1% B vs. referências |', '|---|---:|---:|']
for n in range(1, 4):
    a1, b, a2 = data[f'a{n}'], data[f'b{n}'], data[f'a{n+1}']
    def delta(key):
        return (b[key] / statistics.mean([a1[key], a2[key]]) - 1) * 100
    lines.append(f"| B{n} | {delta('fps'):+.1f}% | {delta('one_percent_low'):+.1f}% |")
out = work / f'{prefix}-summary.md'
out.write_text('\n'.join(lines) + '\n', encoding='utf-8')
print(out.read_text(encoding='utf-8'))
