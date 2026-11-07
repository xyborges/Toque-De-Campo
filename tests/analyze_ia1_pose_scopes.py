"""Read immutable raw pose profiling windows and write tabular summaries."""
from pathlib import Path
import csv,json,statistics
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'work/pose-scopes-20261107'

def mean(v):return statistics.mean(v) if v else None
def load_valid(pattern):
    return [d for p in sorted(OUT.glob(pattern)) if (d:=json.loads(p.read_text())).get('valid') is True]

def main():
    all_data=load_valid('*.json')
    groups={}
    for d in all_data:
        if 'frame' not in d or 'smoke' in d['label']:continue
        key=(d['map'],'headless' if not d['visual'] else 'visual',d['enabled'])
        groups.setdefault(key,[]).append(d)
    tables=[];result={}
    tables.append('|Mapa/papel|Flag|n|FPS|P99 ms|Física monitor ms|Ticks/s|Frames multi tick %|Shots|GPU thermal amostras|\n|---|---|---:|---:|---:|---:|---:|---:|---:|---:|')
    for key,ds in sorted(groups.items()):
        m,kind,on=key
        fields={'runs':len(ds),'fps':mean([d['fps'] for d in ds]),'p99_ms':mean([d['frame']['p99_ms'] for d in ds]),'physics_ms':mean([d['physics']['mean_ms'] for d in ds]),'tick_hz':mean([d['tick_hz'] for d in ds]),'multi_tick_pct':mean([100*d['multi_tick_frames']/d['frame']['samples'] for d in ds]),'shots':[d['combat']['shots'] for d in ds]}
        result[str(key)]=fields
        tables.append(f"|{m}/{kind}|{on}|{len(ds)}|{fields['fps']:.2f}|{fields['p99_ms']:.2f}|{fields['physics_ms']:.2f}|{fields['tick_hz']:.2f}|{fields['multi_tick_pct']:.1f}|{fields['shots']}|ver CSV alinhado|")
        if on:
            scopes={}
            for d in ds:
                for name,row in d['probe']['scopes'].items():scopes.setdefault(name,[]).append(row)
            result[str(key)]['scopes']={s:{k:mean([r[k] for r in rows]) for k in ['inclusive_ms_per_tick','exclusive_ms_per_tick','inclusive_ms_per_frame','exclusive_ms_per_frame','sampled_calls']} for s,rows in scopes.items()}
    tables.append('\n|Mapa/contexto|Escopo|Incl. ms/tick|Excl. ms/tick|Incl. ms/frame|Excl. ms/frame|Chamadas amostradas/run|\n|---|---|---:|---:|---:|---:|---:|')
    for key,d in result.items():
        for scope,r in sorted(d.get('scopes',{}).items(),key=lambda t:-t[1]['inclusive_ms_per_tick']):
            tables.append(f"|{key}|{scope}|{r['inclusive_ms_per_tick']:.4f}|{r['exclusive_ms_per_tick']:.4f}|{r['inclusive_ms_per_frame']:.4f}|{r['exclusive_ms_per_frame']:.4f}|{r['sampled_calls']:.1f}|")
    (OUT/'analysis.json').write_text(json.dumps(result,indent=2),encoding='utf8')
    (OUT/'analysis-tables.md').write_text('\n'.join(tables)+'\n',encoding='utf8')
    print('ANALYZED',len(all_data),'raw valid windows',len(groups),'groups')

if __name__=='__main__':main()
