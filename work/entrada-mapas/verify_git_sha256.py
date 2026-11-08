"""Generate/verify SHA256 from Git BLOBS, stable under Windows CRLF normalization.
Usage: python work/entrada-mapas/verify_git_sha256.py --generate
       python work/entrada-mapas/verify_git_sha256.py
"""
from pathlib import Path
import hashlib,subprocess,sys
repo=Path(__file__).resolve().parents[2]
base="work/entrada-mapas"
manifest=repo/base/"SHA256SUMS.txt"
def git(*args):
    return subprocess.check_output(["git","-C",str(repo),*args])
if "--generate" in sys.argv:
    paths=git("ls-files","--",base,
        "modes/war/scripts/favela_map.gd",
        "maps/prepared/favela/housing_plan_cache.res",
        "maps/prepared/favela/terrain_faces_cache.res",
        "tests/ia2_entry_graphical_offline.gd",
        "tests/ia2_entry_enet_graphics.gd",
        "tests/ia2_entry_combined_60s.gd",
        "tests/ia2_afghan_entry_profile.gd",
        "tests/ia2_terrain_faces_cache_qa.gd",
        "tests/ia2_housing_plan_cache_qa.gd").decode("utf-8").splitlines()
    paths=[path for path in sorted(set(paths)) if path!=base+"/SHA256SUMS.txt"]
    assert all(not any(s in p.lower() for s in ("ephemeral-cert","appdata-","-account","private-key",".pem")) for p in paths)
    entries=[hashlib.sha256(git("show",":"+p)).hexdigest()+"  "+p for p in paths]
    manifest.write_text("\n".join(entries)+"\n",encoding="utf-8",newline="\n")
    print("INDEX_SHA256_ENTRIES",len(entries))
else:
    count=0
    for line in manifest.read_text(encoding="utf-8").splitlines():
        digest,path=line.split("  ",1)
        assert hashlib.sha256(git("show","HEAD:"+path)).hexdigest()==digest,path
        count+=1
    print("VERIFIED_HEAD_SHA256_ENTRIES",count)
