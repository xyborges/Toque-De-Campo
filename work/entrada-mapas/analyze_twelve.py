import csv,json,sys,statistics as s
from pathlib import Path
filename=Path(sys.argv[1])
rows=list(csv.DictReader(filename.open(encoding="utf-8-sig",newline="")))
expected=[0,0,0,1,1,0,0,1,1,0,0,1]
assert [int(x["variant"]) for x in rows]==expected,len(rows)
a=rows[2:]
aa=rows[:2]
def get(row,key):return float(row[key].replace(",","."))
pairs=[]
for i in range(5):
    u,v=a[i*2:i*2+2]
    orig=u if u["variant"]=="0" else v
    opt=v if orig is u else u
    pairs.append((orig,opt))
metrics={}
for k in ["world_ms","ready_ms","neighborhoods_ms","layout_ms"]:
    baseline=[get(o,k) for o,_ in pairs]
    optimized=[get(b,k) for _,b in pairs]
    m=s.mean(baseline); n=s.mean(optimized)
    aa_l,aa_r=get(aa[0],k),get(aa[1],k)
    metrics[k]={"A_mean":m,"B_mean":n,"gain_pct":(m-n)/m*100,
        "A_A_noise_pct":abs(aa_l-aa_r)/s.mean([aa_l,aa_r])*100,
        "A_range_noise_pct":(max(baseline)-min(baseline))/m*100,
        "B_wins":sum(get(o,k)>get(b,k) for o,b in pairs),
        "pair_gains_ms":[round(get(o,k)-get(b,k),3) for o,b in pairs]}
stats={"metric":metrics,"geometry_equal":len({r["geometry_hash"] for r in rows})==1,
       "runs":len(rows),"control_AA":2,"AB_pairs":5}
out=filename.with_name(filename.stem+"-analysis.json")
out.write_text(json.dumps(stats,indent=2,ensure_ascii=False)+"\n",encoding="utf-8")
print(json.dumps(stats,ensure_ascii=False))
