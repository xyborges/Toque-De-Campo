from __future__ import annotations
import csv, json, statistics as statistics
from pathlib import Path

directory = Path(__file__).resolve().parent
rows = list(csv.DictReader((directory / 'colliders-5pairs.csv').open(encoding='utf-8-sig', newline='')))
if len(rows) != 10:
    raise SystemExit(f"Ten runs required: received {len(rows)}")
order = [0,1,1,0,0,1,1,0,0,1]
assert [int(row['variant']) for row in rows] == order

def f(row, key):
    return float(row[key].replace(',', '.'))

baseline = [r for r in rows if r['variant']=='0']
optimized = [r for r in rows if r['variant']=='1']
metrics = ['ready_ms','map_build_ms','world_build_ms','neighborhoods_ms','hillside_ms','terrain_ms','layout_reservations_ms','flush_ms']
result = {"runs":len(rows),
    "all_shapes": sorted(set(int(r['colliders']) for r in rows)),
    "all_sectors": sorted(set(int(r['sectors']) for r in rows)),
    "all_probes": sorted(set(int(r['probes_hit']) for r in rows)),
    "geometry_hashes": sorted(set(r['geometry_sha256'] for r in rows)),
    "sorted_geometry_hashes": sorted(set(r['sorted_geometry_sha256'] for r in rows)),
    "unlabelled_geometry_hashes": sorted(set(r['unlabelled_sha256'] for r in rows)),
    "probe_hashes": sorted(set(r['probe_sha256'] for r in rows)),
    "metrics":{}}
for key in metrics:
    a = [f(x,key) for x in baseline]
    b = [f(x,key) for x in optimized]
    ma=statistics.mean(a); mb=statistics.mean(b)
    result['metrics'][key]={
        "original_mean":ma,
        "experimental_mean":mb,
        "change_ms":mb-ma,
        "gain_pct":100*(ma-mb)/ma,
        "control_noise_amplitude_over_mean_pct":100*(max(a)-min(a))/ma,
        "control_stdev_pct":100*statistics.stdev(a)/ma,
        "all_a":a,"all_b":b
    }
pairs=[]
for i in range(0,10,2):
    first,second=rows[i:i+2]
    a=first if first['variant']=='0' else second
    b=second if a is first else first
    pairs.append({"pair":i//2+1,"original_ready_ms":f(a,'ready_ms'),
        "experimental_ready_ms":f(b,'ready_ms'),
        "original_map_ms":f(a,'map_build_ms'),
        "experimental_map_ms":f(b,'map_build_ms'),
        "map_savings_ms":f(a,'map_build_ms')-f(b,'map_build_ms'),
        "ready_savings_ms":f(a,'ready_ms')-f(b,'ready_ms')})
result["pairs"]=pairs
result["map_wins"]=sum(p['map_savings_ms']>0 for p in pairs)
result["ready_wins"]=sum(p['ready_savings_ms']>0 for p in pairs)
result["strict_geometry_equivalence"] = (len(result['geometry_hashes'])==1 and len(result['unlabelled_geometry_hashes'])==1 and len(result['probe_hashes'])==1)
out = directory/'five-pairs-analysis.json'
out.write_text(json.dumps(result,indent=2,ensure_ascii=False)+'\n',encoding='utf-8')
print(json.dumps({"map_wins":result["map_wins"],"ready_wins":result["ready_wins"],
    "equivalence":result["strict_geometry_equivalence"],
    "map":result["metrics"]["map_build_ms"],
    "ready":result["metrics"]["ready_ms"],
    "pairs":pairs},ensure_ascii=False))
