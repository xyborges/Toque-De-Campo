from pathlib import Path
import subprocess,json,sys
root=Path.cwd();engine=r'C:\Users\Joao Borges\Documents\Codex\tools\Godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe'
for map_name in ('desert','office'):
 for label in ('before','after'):
  path=root/f'work/render-154-{label}-{map_name}.stdout.log'
  report=root/f'tests/combat-render-{label}-{map_name}.json'
  if '--resume' in sys.argv and path.exists() and report.exists() and len(json.loads(report.read_text()).get('results',[]))==6:
   text=path.read_text(encoding='utf-8',errors='replace')
   errors=[line for line in text.splitlines() if 'ERROR:' in line]
   assert not errors or (label=='before' and all(line=='ERROR: Lambda capture at index 0 was freed. Passed "null" instead.' for line in errors)),errors
   print('COMPLETED',map_name,label,json.loads(report.read_text()),flush=True);continue
  with path.open('w',encoding='utf-8') as output:
   result=subprocess.run([engine,'--debug','--profiling','--max-fps','60','--path',str(root),'--script','tests/combat_render_benchmark.gd','--screen','0','--position','0,0','--resolution','1920x1080','--log-file',str(root/f'work/render-154-{label}-{map_name}.log'),'--',f'--label={label}',f'--map={map_name}'],stdout=output,stderr=subprocess.STDOUT,timeout=70,creationflags=subprocess.CREATE_NO_WINDOW)
  text=path.read_text(encoding='utf-8',errors='replace')
  errors=[line for line in text.splitlines() if 'ERROR:' in line]
  # Preserve the old renderer's known shutdown timer failure in the log.
  # It occurs after all six samples; never accept errors from current code.
  assert result.returncode==0 and (not errors or (label=='before' and all(line=='ERROR: Lambda capture at index 0 was freed. Passed "null" instead.' for line in errors))),text[-6000:]
  data=json.loads((root/f'tests/combat-render-{label}-{map_name}.json').read_text())
  assert len(data['results'])==6,data
  print(map_name,label,data,flush=True)
