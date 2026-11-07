import csv,json,statistics as st
from pathlib import Path
root=Path(__file__).parent
rows=list(csv.DictReader((root/'combined-60s-24runs.csv').open(encoding='utf-8-sig',newline='')))
assert len(rows)==24,len(rows)
out={}
for op in ('favela','afghan'):
    data=[r for r in rows if r['operation']==op]
    expected=[0,0,0,1,1,0,0,1,1,0,0,1]
    assert [int(r['variant']) for r in data]==expected,(op,data)
    def val(r,k):return float(r[k].replace(',','.'))
    a=data[2:]
    pairs=[]
    for n in range(5):
        x,y=a[n*2:n*2+2]
        original=x if x['variant']=='0' else y
        optimized=y if original is x else x
        pairs.append((original,optimized))
    metrics={}
    for k in ['world_ms','ready_ms','frame_mean_ms','frame_p95_ms','frame_p99_ms','frame_max_ms','physics_p99_ms','multi_tick_frames']:
        av=st.mean(val(x,k) for x,y in pairs)
        bv=st.mean(val(y,k) for x,y in pairs)
        noise=(max(val(x,k) for x,y in pairs)-min(val(x,k) for x,y in pairs))/av*100 if av else None
        aa=abs(val(data[0],k)-val(data[1],k))/st.mean([val(data[0],k),val(data[1],k)])*100 if val(data[0],k)+val(data[1],k) else None
        metrics[k]={'A_mean':av,'B_mean':bv,'delta':bv-av,'improvement_pct':(av-bv)/av*100 if av else None,
                    'A_range_noise_pct':noise,'A_A_noise_pct':aa,'B_wins':sum(val(x,k)>val(y,k) for x,y in pairs),
                    'pairs_delta_A_minus_B':[round(val(x,k)-val(y,k),3) for x,y in pairs]}
    out[op]={'runs':len(data),'AA':2,'pairs':5,'metrics':metrics,
             'bot_shots_range':[min(val(x,'shots') for x in data),max(val(x,'shots') for x in data)],
             'gpu_temperature_rows':[(x['gpu_start'],x['gpu_end']) for x in data[:2]]}
(root/'combined-analysis.json').write_text(json.dumps(out,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print('COMBINED_SUMMARY',json.dumps({op:{'ready':out[op]['metrics']['ready_ms'],
    'world':out[op]['metrics']['world_ms'],'frame_p99':out[op]['metrics']['frame_p99_ms'],
    'bot_shots_range':out[op]['bot_shots_range']} for op in out},ensure_ascii=False))
