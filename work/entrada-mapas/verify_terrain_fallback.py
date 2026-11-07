from pathlib import Path
import hashlib,os,subprocess,json,sys
root=Path(__file__).resolve().parents[2]
directory=root/"work/entrada-mapas"
target=root/"maps/prepared/favela/terrain_faces_cache.res"
godot=Path(r"C:\Users\Microgate\Documents\Codex\2026-11-06\fa-a\work\Godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe")
original=target.read_bytes()
original_sha=hashlib.sha256(original).hexdigest()
assert len(original)>6000000
assert not (target.with_suffix(".res.hidden")).exists()
base_env=os.environ.copy()
base_env.update({"TDC_IA2_HOUSING_CACHE":"1","TDC_IA2_TERRAIN_FACES":"1","TDC_IA2_MAP_STAGES":"1"})
def verify(label):
    out=subprocess.run([str(godot),"--headless","--path",str(root),
                        "--script","res://tests/ia2_housing_plan_cache_qa.gd","--","--run=999"],
        cwd=root,env=base_env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,errors="replace",timeout=90)
    (directory/f"fallback-terrain-{label}.log").write_text(out.stdout,encoding="utf-8")
    rows=[line.removeprefix("IA2_HOUSING_PLAN_BENCH ") for line in out.stdout.splitlines()
          if line.startswith("IA2_HOUSING_PLAN_BENCH ")]
    assert out.returncode==0 and len(rows)==1,(label,out.returncode,out.stdout[-2000:])
    record=json.loads(rows[0])
    assert record["terrain_cache_status"]=="fallback",(label,record["terrain_cache_status"])
    assert record["layout_status"]=="loaded",record
    assert record["houses"]==4188 and record["collisions"]==11146
    assert record["geometry_sha256"]=="ed382d5d98cbb2bb1471ac926b1cf890ee755213163ac8f2ddee32c33a48ca80"
    assert record["ray_sha256"]=="574841c454eb1f4ffe3703bfa0d5796c51cdb6676e428177b2468651a159f7b5"
    print("TERRAIN_FALLBACK_PASS",label,record["ready_ms"],flush=True)
held=target.with_suffix(".res.hidden")
try:
    target.rename(held)
    verify("missing")
finally:
    if held.exists():held.rename(target)
assert hashlib.sha256(target.read_bytes()).hexdigest()==original_sha
assert not held.exists()
sig=b"299a866a521d270f6521fe9f879737a02710300a3c4a8c1c83f2f7e6e0395326"
assert original.count(sig)==1,original.count(sig)
try:
    target.write_bytes(original.replace(sig,b"f"*64))
    verify("bad-signature")
finally:
    target.write_bytes(original)
assert hashlib.sha256(target.read_bytes()).hexdigest()==original_sha
print("RESOURCE_RESTORED_SHA256",original_sha)
