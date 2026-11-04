from pathlib import Path
import json
import sys

if len(sys.argv) != 2 or not sys.argv[1].startswith('nova-cpu-route-'):
    raise SystemExit('Informe o identificador do perfil.')
p = Path(__file__).resolve().parents[1] / 'work' / f'{sys.argv[1]}-offline.json'
d = json.loads(p.read_text(encoding='utf-8-sig'))
probe = d.get('probe', {})
if not probe.get('enabled') or not probe.get('scopes'):
    raise SystemExit('Perfil não registrou medições; não atribuir gargalos.')
scopes = sorted(probe['scopes'].items(), key=lambda pair: pair[1]['mean_ms'] * pair[1]['calls'], reverse=True)
print('Tempos inclusivos: escopos aninhados não são somáveis; instrumentação afeta desempenho.')
print(f"FPS mediano {d['median_fps']:.1f}; p99 {d['frame_p99_ms']:.1f} ms; pior {d['worst_ms']:.1f} ms.")
for name, value in scopes[:12]:
    print(f"{name}: {value['calls']} chamadas; média {value['mean_ms']:.3f} ms; maior {value['max_ms']:.2f} ms; tempo inclusivo total {value['mean_ms']*value['calls']/1000:.2f} s")
