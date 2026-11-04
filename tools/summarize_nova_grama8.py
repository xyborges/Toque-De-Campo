from pathlib import Path
import json
import statistics

root = Path(__file__).resolve().parents[1]
work = root / 'work'
labels = ('a1', 'b1', 'a2', 'b2', 'a3', 'b3', 'a4')
data = {label: json.loads((work / f'nova-grama8-{label}-offline.json').read_text(encoding='utf-8-sig')) for label in labels}
hardware = [json.loads(line) for line in (work / 'nova-grama8-hardware.jsonl').read_text(encoding='utf-8-sig').splitlines() if line.strip()]

lines = ['| Execução | FPS | 1% low | Pior quadro (ms) | Desenhos | Triângulos | GPU °C / MHz | CPU MHz estimado |',
         '|---|---:|---:|---:|---:|---:|---:|---:|']
for label in labels:
    d = data[label]
    samples = [sample for sample in hardware if d['start_unix'] <= sample['unix'] <= d['end_unix']]
    def avg(field):
        values = [float(s[field]) for s in samples if s.get(field) is not None]
        return f'{statistics.mean(values):.0f}' if values else '—'
    lines.append(f"| {label.upper()} | {d['fps']:.2f} | {d['one_percent_low']:.2f} | {d['worst_ms']:.2f} | {d['draw_calls']:.0f} | {d['max_primitives']:.0f} | {avg('gpu_temp_c')} / {avg('gpu_clock_mhz')} | {avg('cpu_estimated_mhz')} |")

lines += ['', '| Par | FPS B vs. média das referências adjacentes | 1% B vs. referências |', '|---|---:|---:|']
for n in range(1, 4):
    a1, b, a2 = data[f'a{n}'], data[f'b{n}'], data[f'a{n+1}']
    delta = lambda key: (b[key] / statistics.mean([a1[key], a2[key]]) - 1) * 100
    lines.append(f"| B{n} | {delta('fps'):+.1f}% | {delta('one_percent_low'):+.1f}% |")
out = work / 'nova-grama8-ab-summary.md'
out.write_text('\n'.join(lines) + '\n', encoding='utf-8')
print(out.read_text(encoding='utf-8'))
