"""Repeat before/after sequentially, with no competing test process."""
from pathlib import Path
import subprocess,sys
root=Path(__file__).resolve().parents[1]
for suffix,project in [('fix-A2',root/'work/war-lag-fix-baseline'),('fix-B3',root)]:
 subprocess.run([sys.executable,str(root/'tests/run_war_lag_load.py'),'--counts','28','--suffix',suffix,'--authority','--project',str(project)],cwd=root,check=True)
