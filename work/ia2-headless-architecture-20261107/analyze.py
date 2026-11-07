import csv,json,statistics as st
from pathlib import Path
p=Path(__file__).resolve().parent
rows=list(csv.DictReader((p/'architecture-5pairs.csv').open(encoding='utf-8-sig',newline='')))
if len(rows)!=10:raise ValueError(f'Expected 10 runs, got {len(rows)}')
pattern=[0,1,1,0,0,1,1,0,0,1]
if [int(r['variant']) for r in rows]!=pattern:raise ValueError('Wrong A/B order')
def f(r,k):return float(str(r[k]).replace(',','.'))
a=[r for r in rows if r['variant']=='0']
b=[r for r in rows if r['variant']=='1']
res={'base_commit':'ee969af','runs':len(rows),
    'original_world_ms':st.mean(f(r,'world_ms') for r in a),
    'optimized_world_ms':st.mean(f(r,'world_ms') for r in b),
    'original_ready_ms':st.mean(f(r,'ready_ms') for r in a),
    'optimized_ready_ms':st.mean(f(r,'ready_ms') for r in b)}
res['world_gain_pct']=100*(res['original_world_ms']-res['optimized_world_ms'])/res['original_world_ms']
res['ready_gain_pct']=100*(res['original_ready_ms']-res['optimized_ready_ms'])/res['original_ready_ms']
res['noise_world_pct']=100*(max(f(r,'world_ms') for r in a)-min(f(r,'world_ms') for r in a))/res['original_world_ms']
res['noise_ready_pct']=100*(max(f(r,'ready_ms') for r in a)-min(f(r,'ready_ms') for r in a))/res['original_ready_ms']
res['geometry_identical']=len({r['geometry_sha256'] for r in rows})==1
res['ray_results_identical']=len({r['ray_sha256'] for r in rows})==1
res['shape_counts_identical']=len({(r['houses'],r['tiles'],r['collisions'],r['total_shapes']) for r in rows})==1
pairs=[]
for i in range(5):
    left,right=rows[i*2:i*2+2]
    original=left if left['variant']=='0' else right
    optimized=right if original is left else left
    pairs.append({'pair':i+1,'original_world_ms':f(original,'world_ms'),'optimized_world_ms':f(optimized,'world_ms'),
                  'gain_world_pct':100*(f(original,'world_ms')-f(optimized,'world_ms'))/f(original,'world_ms'),
                  'original_ready_ms':f(original,'ready_ms'),'optimized_ready_ms':f(optimized,'ready_ms')})
res['pairs']=pairs
res['world_wins']=sum(r['gain_world_pct']>0 for r in pairs)
res['ready_wins']=sum(r['original_ready_ms']>r['optimized_ready_ms'] for r in pairs)
(p/'analysis.json').write_text(json.dumps(res,indent=2,ensure_ascii=False)+'\n',encoding='utf-8')
print('IA2_ARCH_ANALYSIS '+json.dumps(res,ensure_ascii=False))
