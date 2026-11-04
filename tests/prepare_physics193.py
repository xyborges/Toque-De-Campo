from pathlib import Path
import subprocess
r=Path(__file__).resolve().parents[1]
t=r/'work/physics193';t.mkdir(exist_ok=True)
for name in ['assets','audio','modes','scripts','scenes','shaders','themes','addons','tests','qa','.godot']:
 target=t/name
 if not target.exists():
  subprocess.run(['cmd','/c','mklink','/J',str(target),str(r/name)],check=True,capture_output=True)
(t/'work').mkdir(exist_ok=True)
source=(r/'project.godot').read_text().replace('[physics]','[physics]\n\n3d/physics_engine="Jolt Physics"\njolt_physics_3d/motion_queries/recovery_amount=1.0')
(t/'project.godot').write_text(source)
print(t)
