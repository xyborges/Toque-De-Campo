"""Run P1b-P1i in separate processes and retain machine-readable evidence.

Reserve work/fpp-tpp-p1a-20261104/collision-rig-proxy-qa.json before running.
Performance gates are run separately, with no concurrent regression processes.
"""
import argparse
from hashlib import sha256
import json
import os
from pathlib import Path
import subprocess
import tempfile

SUITES = {
    "true_fpp_p1b_collision_rig_proxy": "COLLISION_RIG_PROXY_QA",
    "true_fpp_p1b_collision_math_arsenal": "P1B_ARSENAL_RESULT",
    "true_fpp_p1b_collision_stance_motion": "P1B_PRONE_RESULT",
    "true_fpp_p1b_pelvis_upright": "P1B_PELVIS_UPRIGHT",
    "true_fpp_p1c_collision_ads_iron": "P1C_ADS_IRON",
    "true_fpp_p1d_collision_reload": "P1D_RELOAD",
    "true_fpp_p1e_collision_optical_ads": "P1E_OPTICAL_ADS",
    "true_fpp_p1g_collision_authority": "P1G_COLLISION_AUTHORITY",
    "true_fpp_p1i_damage_ragdoll": "P1I_DAMAGE_RAGDOLL",
}

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--engine", type=Path, required=True)
args = parser.parse_args()
root = Path(__file__).resolve().parents[1]
engine = args.engine.resolve()
if engine.name.endswith("_console.exe"):
    engine = engine.with_name(engine.name.removesuffix("_console.exe") + ".exe")
output = Path(tempfile.mkdtemp(prefix="p1k-regression-"))
print(f"Evidence: {output}", flush=True)
(root / "work/fpp-tpp-p1a-20261104").mkdir(parents=True, exist_ok=True)
reports = {}
sources = [root / f"tests/{name}.gd" for name in SUITES]
sources += [root / "modes/war/scripts" / name for name in
            ("player.gd", "collision_pose_solver.gd", "collision_rig_proxy.gd")]
hashes = {str(path.relative_to(root)): sha256(path.read_bytes()).hexdigest() for path in sources}
for name, marker in SUITES.items():
    folder = output / name
    folder.mkdir()
    with (folder / "stdout.log").open("wb") as log:
        try:
            result = subprocess.run([
                str(engine), "--headless", "--path", str(root), "--fixed-fps", "60",
                "--script", f"res://tests/{name}.gd", "--", "--naval-test-accounts",
                f"--naval-data={folder / 'data'}"
            ], cwd=root, stdout=log, stderr=subprocess.STDOUT, timeout=150,
                env=dict(os.environ, APPDATA=str(folder), XDG_DATA_HOME=str(folder)),
                creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0))
            code = result.returncode
        except subprocess.TimeoutExpired:
            code = -1
    text = (folder / "stdout.log").read_text(encoding="utf-8", errors="replace")
    rows = [json.loads(line.removeprefix(marker + " ")) for line in text.splitlines()
            if line.startswith(marker + " ")]
    passed = code == 0 and len(rows) == 1 and rows[0].get("pass") is True and "ERROR:" not in text
    reports[name] = {"pass": passed, "exit_code": code, "reports": rows}
    print(f"{name}: {'PASS' if passed else 'FAIL'} {rows}", flush=True)
    if not passed:
        print(text[-6000:], flush=True)
unchanged = hashes == {str(path.relative_to(root)): sha256(path.read_bytes()).hexdigest() for path in sources}
summary = {"pass": unchanged and all(row["pass"] for row in reports.values()),
           "unchanged": unchanged, "source_sha256": hashes, "suites": reports}
(output / "results.json").write_text(json.dumps(summary, indent=2), encoding="utf-8")
print(f"P1K_REGRESSION pass={summary['pass']} suites={len(reports)}", flush=True)
raise SystemExit(0 if summary["pass"] else 1)
