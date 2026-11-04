from pathlib import Path
import subprocess
root=Path.cwd();engine=r'C:\Users\Joao Borges\Documents\Codex\tools\Godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe'
for name in ['combat_154','combat_153','combat_feedback_native','naval_damage_numbers','naval_visual_154']:
 result=subprocess.run([engine,'--path',str(root),'--script',f'tests/{name}.gd','--max-fps','60','--screen','0','--position','20,20','--resolution','1280x800','--log-file',str(root/f'work/update-154-final-{name}.log')],capture_output=True,text=True,timeout=35,creationflags=subprocess.CREATE_NO_WINDOW)
 text=result.stdout+result.stderr;(root/f'work/update-154-final-{name}.stdout.log').write_text(text,encoding='utf-8')
 print(name,result.returncode,text[-850:],flush=True)
 assert result.returncode==0 and 'ERROR:' not in text,text[-6500:]
