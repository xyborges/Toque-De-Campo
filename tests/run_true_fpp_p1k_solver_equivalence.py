"""Extract the pinned pre-optimization solver and compare its numerical output.

Reserve work/p1k-reference/collision_pose_solver.gd before running this writer.
"""
import argparse
from pathlib import Path
import subprocess
import tempfile

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--engine", type=Path, required=True)
args = parser.parse_args()
root = Path(__file__).resolve().parents[1]
source = subprocess.check_output([
    "git", "show", "59477c5:modes/war/scripts/collision_pose_solver.gd"
], cwd=root).decode("utf-8")
reference = root / "work/p1k-reference/collision_pose_solver.gd"
reference.parent.mkdir(parents=True, exist_ok=True)
reference.write_text(source.replace("class_name WarCollisionPoseSolver\n", ""), encoding="utf-8")
engine = args.engine.resolve()
if engine.name.endswith("_console.exe"):
    engine = engine.with_name(engine.name.removesuffix("_console.exe") + ".exe")
output = Path(tempfile.mkdtemp(prefix="p1k-equivalence-"))
with (output / "stdout.log").open("w", encoding="utf-8") as log:
    result = subprocess.run([
        str(engine), "--headless", "--path", str(root), "--fixed-fps", "60",
        "--script", "res://tests/true_fpp_p1k_solver_equivalence.gd", "--",
        "--naval-test-accounts", f"--naval-data={output / 'data'}"
    ], cwd=root, stdout=log, stderr=subprocess.STDOUT, timeout=150,
        creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0))
text = (output / "stdout.log").read_text(encoding="utf-8", errors="replace")
print(text)
print(f"Evidence: {output}")
raise SystemExit(result.returncode or (1 if "ERROR:" in text or '"pass":true' not in text else 0))
