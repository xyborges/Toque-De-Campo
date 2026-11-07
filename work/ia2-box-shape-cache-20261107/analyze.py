import csv,json,statistics as stats
from pathlib import Path

root=Path(__file__).resolve().parent
rows=list(csv.DictReader((root/'boxes-5pairs.csv').open(encoding='utf-8-sig',newline='')))
assert len(rows)==10, f"Only {len(rows)} runs"
assert [int(r['variant']) for r in rows]==[0,1,1,0,0,1,1,0,0,1],"Alternation changed"
def num(r,k):return float(r[k].replace(',','.'))
a=[r for r in rows if r['variant']=='0']
b=[r for r in rows if r['variant']=='1']
pairs=[]
for i in range(5):
    first,second=rows[i*2:i*2+2]
    aa=first if first['variant']=='0' else second
    bb=second if first is aa else first
    pairs.append({'pair':i+1,
                  'original_world_ms':num(aa,'world_ms'),
                  'optimized_world_ms':num(bb,'world_ms'),
                  'delta_world_ms':num(aa,'world_ms')-num(bb,'world_ms'),
                  'delta_ready_ms':num(aa,'ready_ms')-num(bb,'ready_ms'),
                  'delta_create_ms':num(aa,'create_ms')-num(bb,'create_ms')})
def summary(k):
    original=stats.mean(num(r,k) for r in a)
    optimized=stats.mean(num(r,k) for r in b)
    return {'original_mean':original,'optimized_mean':optimized,'saved_ms':original-optimized,
            'gain_pct':100*(original-optimized)/original if original else None,
            'original_noise_amplitude_over_mean_pct':100*(max(num(r,k) for r in a)-min(num(r,k) for r in a))/original}
result={'runs':10,'pairs':pairs,'world':summary('world_ms'),'ready':summary('ready_ms'),
        'create':summary('create_ms'),'attach':summary('attach_ms'),
        'cache_hits_mean':stats.mean(num(r,'cache_hits') for r in b),
        'world_wins':sum(p['delta_world_ms']>0 for p in pairs),
        'ready_wins':sum(p['delta_ready_ms']>0 for p in pairs),
        'creation_wins':sum(p['delta_create_ms']>0 for p in pairs),
        'geometry_identical':len(set(r['geometry_sha256'] for r in rows))==1,
        'raycast_identical':len(set(r['ray_sha256'] for r in rows))==1,
        'box_count_identical':len(set(r['box_count'] for r in rows))==1,
        'resources_original_mean':stats.mean(num(r,'unique_resources') for r in a),
        'resources_cached_mean':stats.mean(num(r,'unique_resources') for r in b)}
(root/'analysis.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print('IA2_BOX_ANALYSIS '+json.dumps(result,ensure_ascii=False))
