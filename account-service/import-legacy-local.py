from pathlib import Path
import os,shutil,re,json
base=Path(os.environ['APPDATA'])/'Godot'/'app_userdata'
roots=[base/'Toque de Campo — Godot'/'naval'/'accounts',Path.cwd()/'user_data'/'naval'/'accounts']
launcher=base/'Toque de Campo Launcher'
if launcher.exists(): roots+=list(launcher.glob('profiles/naval/accounts'))
legacy=Path('C:/xampp/toque-de-campo-private/legacy');legacy.mkdir(exist_ok=True)
count=0
for folder in roots:
 if not folder.is_dir():continue
 for file in folder.glob('*.json'):
  if re.fullmatch('[a-f0-9]{64}',file.stem):
   data=json.loads(file.read_text(encoding='utf-8'));target=legacy/file.name
   if not target.exists():shutil.copy2(file,target);count+=1
print('Legacy profiles staged on private server:',count)
