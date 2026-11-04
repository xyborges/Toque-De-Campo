"""Summarize real measurements without treating co-hosted bots as twelve PCs."""
from pathlib import Path
import json
root=Path(__file__).resolve().parents[1]
folder=root/'work/perf181'
before=json.loads((folder/'library190-before-details.json').read_text())
after=json.loads((folder/'library190-release.json').read_text())
full=json.loads((folder/'war-bench-library190-final2-12-8.json').read_text())
light=json.loads((folder/'war-bench-library190-light-measured-12-8.json').read_text())
rows=[]
for a,b in zip(before['rows'],after['rows']):
    assert a['phase']==b['phase']
    rows.append({'phase':a['phase'],'before':a,'after':b})
summary={'gpu':after['gpu'],'resolution':after['render_size'],'static_views':rows,
         'full_clients_profiled':full,'light_clients_unprofiled':light,
         'limitations':['Static render measurements freeze gameplay simulation.',
                        'Network tests share one PC and CPU across the authority and twelve clients.',
                        'Eleven light agents keep only their local movement terrain; authority and renderer retain the complete map.',
                        '60 FPS under full twelve-player combat has not been demonstrated.']}
(root/'tests/library190-performance-comparison.json').write_text(json.dumps(summary,indent=2),encoding='utf-8')
lines=['# Benchmark 1.9.0','',f"Godot 4.7.2, Windows, {after['gpu']}, 1920 × 1080, Compatibility.",'',
       '## Comparação da renderização','',
       'Mesmas cinco câmeras, VSync desligado, sem limite de FPS e cinco segundos de amostras por vista após aquecimento. A simulação está congelada; a cena usa personagens, blindados e o mapa real. O resultado não representa uma partida de combate com 12 jogadores.', '',
       '| Vista | FPS antes | FPS depois | 1% low antes | 1% low depois | Draw calls antes/depois |','|---|---:|---:|---:|---:|---:|']
for r in rows:
    a,b=r['before'],r['after']
    lines.append(f"| {r['phase']} | {a['fps']:.1f} | {b['fps']:.1f} | {a['one_percent_low']:.1f} | {b['one_percent_low']:.1f} | {a['draw_calls']:.0f} / {b['draw_calls']:.0f} |")
lines+=['','O depois inclui 200 objetos adicionais, crateras, materiais do terreno e a integração modular. Instanciamento, agrupamento e LOD reduzem chamadas de desenho; isso não significa que todas as vistas tenham FPS superior ao cenário menos detalhado.', '',
        '## Carga de rede','',
        'Servidor autoritativo e 12 conexões reais por ENet/DTLS no mesmo PC. O cenário dispara armas, move quatro blindados, usa drones, gera explosões e desconecta um participante. As contas e a imortalidade são exclusivas do ensaio.', '',
        '| Ensaio | FPS médio no cliente visível | 1% low | Frame p95 | Pico |','|---|---:|---:|---:|---:|']
for label,data in [('12 clientes completos, com Profiler',full),('1 cliente completo + 11 agentes leves, sem Profiler',light)]:
    lines.append(f"| {label} | {data['average_fps']:.1f} | {data['one_percent_low']:.1f} | {data['frame_ms_p95']:.1f} ms | {data['frame_ms_max']:.1f} ms |")
lines+=['','Os 11 agentes leves conservam a superfície local necessária à movimentação; a autoridade e o cliente visível mantêm o mapa inteiro. Há concorrência de CPU entre 13 processos. A instrumentação do Profiler também acrescenta custo, por isso não se interpreta a diferença entre as duas linhas como um ganho da otimização.', '',
        '**A meta de 60 FPS estáveis em combate com 12 jogadores não foi demonstrada.** Os testes de carga passaram funcionalmente, mas ainda mostram picos e custo de CPU. Uma medição com clientes em PCs separados e a autoridade no Ubuntu continua necessária para separar o custo de simulação local do servidor de produção.', '',
        'Logs do Profiler: `work/perf181/war-bench-library190-final2-12-server.stdout.log` e `war-bench-library190-final2-12-8.stdout.log`. Dados completos: `tests/library190-performance-comparison.json`.', '',
        '## Verificação funcional','',
        'Os testes específicos verificam colisões idênticas no cliente/servidor, escavação, entrada e saída de trincheiras, encaixes, restauração do terreno, balística com resistência, passagem sonora de projéteis e tremor de impacto para operador/passageiro. A integração de rede também valida disparo, recarga, drone, morte, respawn e disparo do APC depois do respawn.']
(root/'BENCHMARK-1.9.0.md').write_text('\n'.join(lines)+'\n',encoding='utf-8')
print('MEASUREMENTS_REPORTED')
