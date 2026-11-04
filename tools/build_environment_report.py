"""Build a local comparison gallery using unmodified engine screenshots."""
from pathlib import Path
import html,json
root=Path(__file__).resolve().parents[1]
views={
 'office':('Escritório · complexo administrativo industrial',[
  ('warehouse','Salão e estantes'),('annex','Corredor de serviço'),('workstations','Estações de trabalho')],
  ['reception','administration','archive','maintenance']),
 'desert':('Deserto · posto militar avançado',[
  ('outpost','Visão do posto'),('ground','Nível do jogador'),('dunes','Relevo e aproximação')],
  ['communications','logistics','maintenance']),
 'naval':('Naval · arquipélago militar',[
  ('lighthouse','Ilha do farol'),('archipelago','Arquipélago'),('harbor','Porto abandonado')],
  ['radar','fortification','night','seabed'])}
output=['''<!doctype html><html lang="pt-BR"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Toque de Campo · Extended look</title><style>
:root{color-scheme:dark}body{background:#071013;color:#e7ede8;font:16px system-ui;margin:0}main{max-width:1500px;margin:auto;padding:32px}h1{font-size:clamp(30px,5vw,60px)}h2{color:#b7cca1;margin-top:60px}p,figcaption{color:#97aaa9;line-height:1.6}.pair,.details{display:grid;grid-template-columns:1fr 1fr;gap:18px}figure{margin:10px 0 22px;background:#101a1c;border:1px solid #364746}img{width:100%;height:auto;display:block}figcaption{padding:14px}small{color:#b7cca1;letter-spacing:.1em}a{color:#b7cca1}.note{border-left:3px solid #b7cca1;padding:10px 20px;background:#101a1c}.details{grid-template-columns:repeat(auto-fit,minmax(300px,1fr))}table{border-collapse:collapse}td,th{padding:12px 22px;border-bottom:1px solid #364746;text-align:left}@media(max-width:850px){.pair{grid-template-columns:1fr}main{padding:16px}}
</style><main><small>TOQUE DE CAMPO · GODOT · 1.5.0</small><h1>Extended look dos mapas</h1>
<p>Capturas reais do motor. Os pares antes/depois usam exatamente as mesmas posições, alvos de câmera, FOV e resolução (1280 × 800). As imagens não foram retocadas.</p>
<p><a href="EXTENDED-LOOK.md">Relatório técnico</a> · <a href="MAPAS-ESTADO-ATUAL.md">Descrição dos mapas atuais</a></p>''']
base='tests/screens/extended-look'
for kind,(title,pairs,details) in views.items():
 output.append(f'<section><h2>{html.escape(title)}</h2>')
 for view,label in pairs:
  output.append(f'<h3>{html.escape(label)}</h3><div class="pair">')
  for version,name in [('before','ANTES · 1.4.1'),('after','DEPOIS · 1.5.0')]:
   output.append(f'<figure><img loading="lazy" src="{base}/{version}/{kind}-{view}.png" alt="{html.escape(label)} — {name}"><figcaption>{name}</figcaption></figure>')
  output.append('</div>')
 output.append('<h3>Detalhes do ambiente</h3><div class="details">')
 for view in details:
  if (root/base/'after'/f'{kind}-{view}.png').exists():
   output.append(f'<figure><img loading="lazy" src="{base}/after/{kind}-{view}.png"><figcaption>{html.escape(view)}</figcaption></figure>')
 output.append('</div></section>')
output.append('<h2>Câmera e colisão</h2><div class="pair">')
for name,label in [('door','Câmera encostada na porta: recuo e apresentação próxima'),('cabinet','Colisão com armários da administração')]:
 output.append(f'<figure><img loading="lazy" src="{base}/camera-{name}.png"><figcaption>{label}</figcaption></figure>')
output.append('</div><h2>Desempenho em combate offline</h2><table><tr><th>Mapa</th><th>NPCs ativos</th><th>FPS médio</th><th>Frame P95</th><th>Física média</th></tr>')
for kind in ['office','desert']:
 path=root/'tests'/f'environment-performance-{kind}.json'
 if path.exists():
  data=json.loads(path.read_text())
  output.append(f'<tr><td>{kind}</td><td>{data["npcs"]}</td><td>{data["fps"]:.1f}</td><td>{data["frame_p95_ms"]:.2f} ms</td><td>{data["physics_ms"]:.2f} ms</td></tr>')
output.append('''</table><p class="note">Medição curta neste PC, GTX 1650, 1280 × 800, limite de 60 FPS. Os passeios de câmera têm os NPCs ocultos/parados; a tabela acima usa NPCs ativos. Não é um benchmark de outros computadores ou teste prolongado. O fundo submarino é uma preparação do cenário; mergulho jogável não foi implementado.</p></main></html>''')
(root/'EXTENDED-LOOK-COMPARACAO.html').write_text('\n'.join(output),encoding='utf-8')
print('ENVIRONMENT_COMPARISON_READY',len(views),'maps',9,'fixed-camera pairs')
