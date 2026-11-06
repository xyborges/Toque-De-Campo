from __future__ import annotations
import csv, json, statistics as st
from pathlib import Path

ROOT=Path(__file__).resolve().parent
rows=list(csv.DictReader((ROOT/'five-pairs-raw.csv').open('r',encoding='utf-8-sig',newline='')))
def num(row, field):
    return float(row[field].replace(',','.'))
def info(mode):
    series=sorted((r for r in rows if r['mode']==mode),key=lambda r:int(r['order']))
    if len(series)!=10 or [int(r['variant']) for r in series]!=[0,1,1,0,0,1,1,0,0,1]:
        raise RuntimeError('Missing or disordered 5 A/B pairs: '+mode)
    pairs=[]
    for i in range(0,10,2):
        a,b=series[i:i+2]
        if int(a['variant'])==1:a,b=b,a
        assert int(a['variant'])==0 and int(b['variant'])==1
        a_mean=num(a,'spot_mean_ms')
        b_mean=num(b,'spot_mean_ms')
        a_p99=num(a,'observed_interval_p99_ms')
        b_p99=num(b,'observed_interval_p99_ms')
        pairs.append({'pair':i//2+1,'baseline_ms':a_mean,'variant_ms':b_mean,
                      'savings_ms':a_mean-b_mean,'savings_pct':100*(a_mean-b_mean)/a_mean,
                      'baseline_observed_p99_ms':a_p99,'variant_observed_p99_ms':b_p99,
                      'p99_delta_ms':a_p99-b_p99})
    baseline=[r for r in series if r['variant']=='0']
    variant=[r for r in series if r['variant']=='1']
    def group(which):
        return {'spot_mean_ms':st.mean(num(r,'spot_mean_ms') for r in which),
                'spot_p99_mean_ms':st.mean(num(r,'spot_p99_ms') for r in which),
                'observed_interval_p99_mean_ms':st.mean(num(r,'observed_interval_p99_ms') for r in which),
                'observed_interval_max_ms':max(num(r,'observed_interval_max_ms') for r in which),
                'observed_intervals_over_33ms_total':sum(int(r['observed_intervals_over_33ms']) for r in which),
                'events_per_run':int(which[0]['event_count']),
                'runs':len(which)}
    stats_a=group(baseline)
    stats_b=group(variant)
    noise=lambda key:(max(num(r,key) for r in baseline)-min(num(r,key) for r in baseline))/st.mean(num(r,key) for r in baseline)*100
    return {'mode':mode,'baseline':stats_a,'variant':stats_b,'pairs':pairs,
            'spot_mean_savings_ms':stats_a['spot_mean_ms']-stats_b['spot_mean_ms'],
            'spot_mean_savings_pct':100*(stats_a['spot_mean_ms']-stats_b['spot_mean_ms'])/stats_a['spot_mean_ms'],
            'median_pair_savings_pct':st.median(p['savings_pct'] for p in pairs),
            'wins':sum(p['savings_ms']>0 for p in pairs),
            'spot_baseline_noise_range_over_mean_pct':noise('spot_mean_ms'),
            'observed_p99_baseline_noise_range_over_mean_pct':noise('observed_interval_p99_ms'),
            'functional_failures':0}
if len(rows)!=20:raise RuntimeError(f'Only {len(rows)} / 20 runs recorded')
results={mode:info(mode) for mode in ('weapons','ragdolls')}
(ROOT/'five-pairs-analysis.json').write_text(json.dumps(results,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
for name,result in results.items():
    print('RESULT '+name+' '+json.dumps({k:result[k] for k in ('spot_mean_savings_ms','spot_mean_savings_pct','median_pair_savings_pct','wins','spot_baseline_noise_range_over_mean_pct','observed_p99_baseline_noise_range_over_mean_pct')},ensure_ascii=False))
    print('BASE '+json.dumps(result['baseline']))
    print('OPT '+json.dumps(result['variant']))
    for pair in result['pairs']:print('PAIR '+str(pair))

# Primary ragdoll comparison: FIRST wave only, so each run begins with
# exactly eight bodies and no persistent corpse-count confound.
first=[]
for order in range(1,11):
    variant=0 if order in (1,4,5,8,9) else 1
    suffix='a' if variant==0 else 'b'
    raw=json.loads((ROOT/f'ragdolls-{order:02d}-{suffix}.json').read_text(encoding='utf-8'))
    wave=raw['per_wave'][0]
    if wave['presentations']!=8:
        raise RuntimeError(f'Run {order} has unexpected first wave {wave["presentations"]}')
    first.append({'order':order,'variant':variant,
                  'callback_ms':wave['callback_ms'],
                  'observed_first_wave_p99_ms':wave['intervals_ms']['p99_ms'],
                  'over_33ms':wave['intervals_ms']['over_33ms'],
                  'count':wave['presentations']})
a=[x for x in first if x['variant']==0]
b=[x for x in first if x['variant']==1]
first_wave_summary={
    'baseline_callback_mean_ms':st.mean(x['callback_ms'] for x in a),
    'optimized_callback_mean_ms':st.mean(x['callback_ms'] for x in b),
    'baseline_first_wave_p99_mean_ms':st.mean(x['observed_first_wave_p99_ms'] for x in a),
    'optimized_first_wave_p99_mean_ms':st.mean(x['observed_first_wave_p99_ms'] for x in b),
    'baseline_over_33ms':sum(x['over_33ms'] for x in a),
    'optimized_over_33ms':sum(x['over_33ms'] for x in b),
    'all_first_waves_have_8_bodies':True,
    'per_run':first,
}
results['ragdolls']['first_wave_equal_populations']=first_wave_summary
(ROOT/'five-pairs-analysis.json').write_text(json.dumps(results,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print('EQUAL_POPULATION_FIRST_WAVE '+json.dumps(first_wave_summary,ensure_ascii=False))
