from __future__ import annotations
import csv,json,statistics as st
from pathlib import Path
directory=Path(__file__).resolve().parent
rows=list(csv.DictReader((directory/'foliage-5pairs.csv').open(encoding='utf-8-sig',newline='')))
if len(rows)!=10:raise SystemExit(f'Need 10 A/B runs, only have {len(rows)}')
pattern=[0,1,1,0,0,1,1,0,0,1]
assert [int(x['variant']) for x in rows]==pattern
# Godot may reorder sibling shapes inside a StaticBody3D even in A/A
# controls; physical equivalence must compare sorted descriptors and
# geometry+physics probes, not accidental scene-child traversal order.
full=[]
for i,variant in enumerate(pattern,1):
    name=f"foliage-{i:02d}-{variant}.json"
    full.append(json.loads((directory/name).read_text(encoding="utf-8")))
def num(r,k):return float(r[k].replace(',','.'))
A=[x for x in rows if x['variant']=='0']
B=[x for x in rows if x['variant']=='1']
metrics=['map_build_ms','ready_ms','world_build_ms','hillside_ms','neighborhoods_ms','layout_reservations_ms','terrain_ms']
summary={'runs':10,'checks':{
    'raw_scene_order_hashes':sorted(set(x['geometry_sha256'] for x in rows)),
    'sorted_geometry_hashes':sorted(set(x['sorted_geometry_sha256'] for x in full)),
    'unlabelled_geometry_hashes':sorted(set(x['unlabelled_sha256'] for x in full)),
    'sector_geometry_hashes':sorted(set(x['sectors_sha256'] for x in full)),
    'probe_hashes':sorted(set(x['probe_sha256'] for x in rows)),
    'collision_shapes':sorted(set(int(x['collision_shapes']) for x in rows)),
    'sector_count':sorted(set(int(x['sectors']) for x in rows)),
    'tree_count':sorted(set(int(x['hill_trees']) for x in rows)),
    'trunk_count':sorted(set(int(x['hill_colliders']) for x in rows)),
    'visual_counts_A':sorted(set((int(x['hill_shrubs']),int(x['hill_grass']),int(x['hill_rocks'])) for x in A)),
    'visual_counts_B':sorted(set((int(x['hill_shrubs']),int(x['hill_grass']),int(x['hill_rocks'])) for x in B))
},'metrics':{}}
for k in metrics:
    a=[num(r,k) for r in A];b=[num(r,k) for r in B]
    avg_a=st.mean(a);avg_b=st.mean(b)
    summary['metrics'][k]={'original_mean_ms':avg_a,
        'optimized_mean_ms':avg_b,'savings_ms':avg_a-avg_b,
        'gain_pct':100*(avg_a-avg_b)/avg_a,
        'baseline_noise_pct':100*(max(a)-min(a))/avg_a,
        'original':a,'optimized':b}
pairs=[]
for i in range(0,10,2):
    one,two=rows[i:i+2]
    a=one if one['variant']=='0' else two
    b=two if a is one else one
    pairs.append({'pair':i//2+1,'map_savings_ms':num(a,'map_build_ms')-num(b,'map_build_ms'),
        'ready_savings_ms':num(a,'ready_ms')-num(b,'ready_ms'),
        'hillside_savings_ms':num(a,'hillside_ms')-num(b,'hillside_ms')})
summary['pairs']=pairs
summary['map_wins']=sum(p['map_savings_ms']>0 for p in pairs)
summary['ready_wins']=sum(p['ready_savings_ms']>0 for p in pairs)
summary['all_collisions_preserved']=(summary['checks']['collision_shapes']==[11624] and
    summary['checks']['sector_count']==[254] and summary['checks']['tree_count']==[1850] and
    summary['checks']['trunk_count']==[78] and
    len(summary['checks']['sorted_geometry_hashes'])==1 and
    len(summary['checks']['unlabelled_geometry_hashes'])==1 and
    len(summary['checks']['sector_geometry_hashes'])==1 and
    len(summary['checks']['probe_hashes'])==1)
(directory/'foliage-5pairs-analysis.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps(summary,ensure_ascii=False))
