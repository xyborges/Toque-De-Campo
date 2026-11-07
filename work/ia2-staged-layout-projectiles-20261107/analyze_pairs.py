import csv, json, statistics as st
from pathlib import Path
p=Path(__file__).resolve().parent
names=['projectile-5pairs.csv','ragdoll-single-5pairs.csv']
result={}
for name in names:
    f=p/name
    if not f.exists():
        print('PENDING',name)
        continue
    rows=list(csv.DictReader(f.open(encoding='utf-8-sig',newline='')))
    if len(rows)!=10:print('INCOMPLETE',name,len(rows));continue
    pattern=[0,1,1,0,0,1,1,0,0,1]
    if [int(row['variant']) for row in rows]!=pattern:raise ValueError('Incorrect alternation: '+name)
    key='mean_tick_ms' if 'projectile' in name else 'create_mean_ms'
    p99_key='p99_tick_ms' if 'projectile' in name else 'create_p99_ms'
    def get(r,k):return float(str(r[k]).replace(',','.'))
    a=[row for row in rows if row['variant']=='0']
    b=[row for row in rows if row['variant']=='1']
    am=st.mean(get(x,key) for x in a)
    bm=st.mean(get(x,key) for x in b)
    baseline_noise=(max(get(x,key) for x in a)-min(get(x,key) for x in a))/am*100
    pairs=[]
    for n in range(5):
        one,two=rows[n*2:n*2+2]
        base=one if one['variant']=='0' else two
        opt=two if base is one else one
        pairs.append({'n':n+1,'baseline_mean_ms':get(base,key),'optimized_mean_ms':get(opt,key),
            'delta_pct':100*(get(base,key)-get(opt,key))/get(base,key),
            'p99_delta_ms':get(base,p99_key)-get(opt,p99_key)})
    result[name]={'original_mean_ms':am,'optimized_mean_ms':bm,'relative_gain_pct':100*(am-bm)/am,
        'baseline_noise_pct':baseline_noise,'baseline_p99_mean_ms':st.mean(get(x,p99_key) for x in a),
        'optimized_p99_mean_ms':st.mean(get(x,p99_key) for x in b),
        'wins':sum(x['delta_pct']>0 for x in pairs),
        'p99_wins':sum(x['p99_delta_ms']>0 for x in pairs),
        'pairs':pairs}
out=p/'compared-five-pairs.json'
out.write_text(json.dumps(result,indent=2,ensure_ascii=False)+'\n',encoding='utf-8')
print(json.dumps(result,indent=2,ensure_ascii=False))

name='world-5pairs.csv'
f=p/name
if f.exists():
    rows=list(csv.DictReader(f.open(encoding='utf-8-sig',newline='')))
    if len(rows)==10:
        pattern=[0,1,1,0,0,1,1,0,0,1]
        assert [int(r['variant']) for r in rows]==pattern
        def n(r,k):return float(str(r[k]).replace(',','.'))
        a=[r for r in rows if r['variant']=='0']
        b=[r for r in rows if r['variant']=='1']
        am=st.mean(n(r,'total_ready_ms') for r in a)
        bm=st.mean(n(r,'total_ready_ms') for r in b)
        pairs=[]
        for idx in range(5):
            one,two=rows[idx*2:idx*2+2]
            base=one if one['variant']=='0' else two
            alt=two if base is one else one
            pairs.append({'n':idx+1,'original_ms':n(base,'total_ready_ms'),
                'staged_ms':n(alt,'total_ready_ms'),
                'delta_ms':n(base,'total_ready_ms')-n(alt,'total_ready_ms')})
        result[name]={
            'original_mean_ready_ms':am,'staged_mean_ready_ms':bm,
            'ready_gain_pct':100*(am-bm)/am,
            'original_noise_range_pct':100*(max(n(r,'total_ready_ms') for r in a)-min(n(r,'total_ready_ms') for r in a))/am,
            'max_staged_planner_slice_ms':max(n(r,'preparation_max_slice_ms') for r in b),
            'stage_prewarm_mean_ms':st.mean(n(r,'preparation_ms') for r in b),
            'original_world_build_mean_ms':st.mean(n(r,'world_build_ms') for r in a),
            'staged_world_build_mean_ms':st.mean(n(r,'world_build_ms') for r in b),
            'wins':sum(p['delta_ms']>0 for p in pairs),'pairs':pairs,
            'hashes_identical':len(set(r['digest'] for r in rows))==1,
            'geometry_identical':len(set((r['collisions'],r['tiles'],r['lots']) for r in rows))==1
        }
        print('WORLD_COMPARISON '+json.dumps(result[name],ensure_ascii=False))
    else:print('INCOMPLETE',name,len(rows))
else:print('PENDING',name)
(p/'compared-five-pairs.json').write_text(json.dumps(result,indent=2,ensure_ascii=False)+'\n',encoding='utf-8')
