from pathlib import Path
import collections,json,zipfile,hashlib
r=Path(__file__).resolve().parents[1]
w=r/'work';p=w/'perf192'
def load(path):return json.loads(path.read_text(encoding='utf-8-sig'))
def road_log(name):
 lines=(w/name).read_text().splitlines()
 return next(json.loads(line) for line in reversed(lines) if line.startswith('{"checks":'))
d=road_log('review192-roads-final.log');e=road_log('review192-roads-east-final.log')
west=[row for row in d['records'] if row.get('road')==2 or ' / D / ' in row.get('vehicle','')]
combined={'checks':36,'failures':[],'records':west+e['records'],'sources':['review192-roads-final.log (west only; east revised later)','review192-roads-east-final.log'],'note':'Actual world colliders, 60 Hz simulated vehicle motion. Not a performance test.'}
assert all(row.get('reached',True) for row in combined['records']) and not e['failures']
(w/'review192-roads-verified.json').write_text(json.dumps(combined,indent=2))
for name in ['server','renderer']:
 path=p/f'godot-profiler-{name}.json'
 if not path.exists():continue
 raw=load(path);totals=collections.defaultdict(lambda:[0,0.,0.]);frame_rows=[]
 for frame in raw['frames']:
  if frame['kind']!='servers:profile_frame':continue
  data=frame['data'];i=7
  for _ in range(int(data[6])):i+=2+int(data[i+1])
  length=int(data[i]);i+=1
  for at in range(i,i+length,5):
   signature=str(data[at]);row=totals[raw['signatures'].get(signature,signature)]
   row[0]+=int(data[at+1]);row[1]+=float(data[at+2]);row[2]+=float(data[at+3])
  frame_rows.append(data[:6])
 rows=sorted(({'function':key,'calls':v[0],'self_time_protocol_units':v[1],'total_time_protocol_units':v[2]} for key,v in totals.items()),key=lambda row:row['self_time_protocol_units'],reverse=True)
 (p/f'godot-profiler-{name}-summary.json').write_text(json.dumps({'samples':len(frame_rows),'top_functions':rows[:40],'frame_fields':'frame, frame_seconds, process_seconds, physics_seconds, physics_frame_seconds, script_seconds','frame_samples':frame_rows},indent=2))
print('Review roads and native Godot profiler summaries written.')
