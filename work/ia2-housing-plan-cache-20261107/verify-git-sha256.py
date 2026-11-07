"""Generate/check SHA-256 over Git BLOBS, invariant across Windows/Linux EOL."""
from pathlib import Path
import hashlib,subprocess,sys
repo=Path(__file__).resolve().parents[2]
folder="work/ia2-housing-plan-cache-20261107"
manifest=repo/folder/"SHA256SUMS.txt"
def git(*args):
    return subprocess.check_output(["git","-C",str(repo),*args])
if "--generate" in sys.argv:
    paths=git("ls-files","--",folder).decode("utf-8").splitlines()
    paths=[p for p in paths if p != folder+"/SHA256SUMS.txt"]
    assert paths and all(".translation" not in p and not p.endswith(".csv.import") for p in paths)
    lines=[]
    for path in sorted(paths):
        payload=git("show",":"+path) # index normalized blob
        lines.append(hashlib.sha256(payload).hexdigest()+"  "+path)
    manifest.write_text("\n".join(lines)+"\n",encoding="utf-8",newline="\n")
    print("MANIFEST_GIT_BLOBS",len(lines))
else:
    checks=0
    for line in manifest.read_text(encoding="utf-8").splitlines():
        digest,path=line.split("  ",1)
        raw=git("show","HEAD:"+path)
        assert hashlib.sha256(raw).hexdigest()==digest,path
        checks+=1
    print("VERIFIED_GIT_BLOBS",checks)
