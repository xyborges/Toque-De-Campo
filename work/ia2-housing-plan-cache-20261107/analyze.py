import csv,json,statistics as st
from pathlib import Path
p=Path(__file__).resolve().parent
rows=list(csv.DictReader((p/'housing-5pairs.csv').open(encoding='utf-8-sig',newline='')))
assert len(rows)==10,f'Expected 10 runs, got {len(rows)}'
assert [int(r['variant']) for r in rows]==[0,1,1,0,0,1,1,0,0,1]
def n(r,k):return float(r[k].replace(',','.'))
a=[r for r in rows if r['variant']=='0']
b=[r for r in rows if r['variant']=='1']
pairs=[]
for i in range(5):
    x,y=rows[2*i:2*i+2]
    aa=x if x['variant']=='0' else y
    bb=y if x is aa else x
    pairs.append({'pair':i+1,'original_layout_ms':n(aa,'layout_ms'),'cached_layout_ms':n(bb,'layout_ms'),
       'original_world_ms':n(aa,'world_ms'),'cached_world_ms':n(bb,'world_ms'),
       'original_ready_ms':n(aa,'ready_ms'),'cached_ready_ms':n(bb,'ready_ms'),
       'layout_saved_ms':n(aa,'layout_ms')-n(bb,'layout_ms'),
       'world_saved_ms':n(aa,'world_ms')-n(bb,'world_ms'),
       'ready_saved_ms':n(aa,'ready_ms')-n(bb,'ready_ms')})
def summary(k):
    av=st.mean(n(r,k) for r in a)
    bv=st.mean(n(r,k) for r in b)
    return {'original_mean_ms':av,'cached_mean_ms':bv,'saved_ms':av-bv,
        'gain_pct':100*(av-bv)/av,
        'baseline_noise_range_over_mean_pct':100*(max(n(r,k) for r in a)-min(n(r,k) for r in a))/av,
        'original_median_ms':st.median(n(r,k) for r in a),
        'cached_median_ms':st.median(n(r,k) for r in b)}
stats={'runs':10,'layout':summary('layout_ms'),'world':summary('world_ms'),
       'ready':summary('ready_ms'),
       'wins':{'layout':sum(x['layout_saved_ms']>0 for x in pairs),
              'world':sum(x['world_saved_ms']>0 for x in pairs),
              'ready':sum(x['ready_saved_ms']>0 for x in pairs)},
       'geometry_identical':len({r['geometry_sha256'] for r in rows})==1,
       'lots_identical':len({r['plan_sha256'] for r in rows})==1,
       'raycasts_identical':len({r['ray_sha256'] for r in rows})==1,
       'counts_identical':len({(r['lots'],r['collision_shapes'],r['houses']) for r in rows})==1,
       'pairs':pairs}
(p/'analysis.json').write_text(json.dumps(stats,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print('IA2_HOUSING_ANALYSIS '+json.dumps(stats,ensure_ascii=False))
