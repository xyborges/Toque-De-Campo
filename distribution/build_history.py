"""Prepare public historical notes from the project's dated release documents."""
from pathlib import Path
import json, re

root = Path(__file__).resolve().parents[1]
extra = {'1.4.1':'CORRECOES-1.4.1.md', '1.5.1':'CORRECOES-1.5.1.md', '1.8.1':'REVISAO-PUBLICACAO-1.8.1.md',
         '1.8.2':'SEGURANCA-1.8.2.md', '1.8.3':'CORRECOES-COMBATE-1.8.3.md'}
files = {p.stem.removeprefix('ATUALIZACAO-'):p for p in root.glob('ATUALIZACAO-*.md') if re.fullmatch(r'\d+\.\d+\.\d+',p.stem.removeprefix('ATUALIZACAO-'))}
files.update({version:root / name for version,name in extra.items()})
files.pop('1.6.2',None)  # Integrated into 1.6.3, not a separate public release.
skip = re.compile(r'verifica|test|valida|arquivo|código|c[oó]digo|publica|m[eé]tricas|benchmark|medi[cç]|lat[eê]ncia|evid[eê]ncia|risco|pend[eê]ncia|hist[oó]rico',re.I)
fix = re.compile(r'corrig|corre[cç]|ajust|trav|bug|falha|erro|evit|imped|resol|consert|repar|volt|restaur|bloque|desapare|regress|melhor',re.I)
technical = re.compile(r'\b(?:rpc|shader|class_name|gds?cript|protocolo|dtls|headless|runtime|build|godot|sha-?256)\b|res://|\.gd\b|work/',re.I)
def clean(text):
    text = re.sub(r'\[([^\]]+)\]\([^)]*\)',r'\1',text)
    text = re.sub(r'[`*_]', '', text)
    text = re.sub(r'\s+', ' ', text).strip(' -–')
    if len(text)>420:
        cut=text.rfind('. ',0,420)
        text=text[:cut+1] if cut>100 else text[:417].rstrip()+'…'
    return text

history=[]
for version,path in files.items():
    source=path.read_text(encoding='utf-8')
    lines=source.splitlines();heading='';added=[];corrected=[]
    for line in lines:
        if line.startswith('## '): heading=line[3:].strip();continue
        if skip.search(heading): continue
        text=''
        if line.startswith('- '): text=line[2:]
        elif line.startswith('| ') and line.count('|')>=3 and not line.startswith('|---'):
            cells=[v.strip() for v in line.strip('|').split('|')]
            if len(cells)>=3 and cells[0].lower() not in ('área','pedido','armamento') and len(cells[-1])>20: text=cells[0]+': '+cells[-1]
        text=clean(text)
        if len(text)<35 or technical.search(text): continue
        target=corrected if (line.startswith('| ') or fix.search(heading+' '+text[:140])) else added
        if text not in target and len(target)<8: target.append(text)
    title=clean(lines[0].lstrip('# ')) if lines else version
    if added or corrected: history.append({'version':version,'title':title,'additions':added,'fixes':corrected})

notes=root/'distribution/release-notes-1.6.10.json'
if notes.exists():
    data=json.loads(notes.read_text(encoding='utf-8'))
    history.append({'version':data['version'],'title':data['title'],'additions':[v['title']+': '+v['text'] for v in data['changes']], 'fixes':[]})
history.extend([
    {'version':'1.2.1','title':'1.2.1 — economia','additions':['A distribuição inicial de moedas foi removida.'],'fixes':[]},
    {'version':'1.3.0','title':'1.3.0 — login','additions':['Nova interface de login e acesso à conta.'],'fixes':[]},
    {'version':'1.3.1','title':'1.3.1 — músicas do login','additions':['Cinco faixas adicionadas à seleção musical do login.'],'fixes':[]},
    {'version':'1.4.0','title':'1.4.0 — interface','additions':['Menus, salas e HUD receberam tema visual compartilhado e fotografias nos cartões de modos.'],'fixes':[]},
    {'version':'1.5.0','title':'1.5.0 — Extended Look dos mapas','additions':['Atualização visual dos mapas existentes com novos detalhes de cenário e ambientação.'],'fixes':[]},
    {'version':'1.6.7','title':'1.6.7 — desempenho e ópticas','additions':['A sniper recebeu maior alcance e velocidade.'],'fixes':['Fumaça dos disparos de veículos foi otimizada; a visão térmica ficou restrita à óptica do operador.']},
    {'version':'1.8.3','title':'1.8.3 — combate','additions':[], 'fixes':['Disparo automático da FAL, uso da Glock e retorno às armas após equipar ou lançar granada receberam correções.', 'Estados de granada e disparo foram limpos nas transições e no respawn.']},
])
history.sort(key=lambda v:tuple(int(x) for x in v['version'].split('.')),reverse=True)
(root/'distribution/release-history.json').write_text(json.dumps(history,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print('VERSIONS',len(history),[item['version'] for item in history])
