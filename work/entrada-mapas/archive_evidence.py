"""Archive QA evidence without private TLS keys, account profiles or credentials."""
from pathlib import Path
import gzip, hashlib, shutil, json
root=Path(__file__).resolve().parents[2]
base=root/"work/entrada-mapas"
enet=base/"enet"
inventory=[]
# Retain raw diagnostic JSON, but compress large per-frame traces.
for path in sorted(enet.glob("*-server.json")):
    if path.stat().st_size>100_000:
        packed=path.with_suffix(path.suffix+".gz")
        data=path.read_bytes()
        packed.write_bytes(gzip.compress(data,mtime=0))
        assert gzip.decompress(packed.read_bytes())==data
        inventory.append({"source":path.name,"archived":packed.name,
                          "sha256":hashlib.sha256(data).hexdigest(),
                          "bytes_raw":len(data),"bytes_gzip":packed.stat().st_size})
        path.unlink()
# Copy the previous two failures from existing local QA runner.
for role in ("server","alpha","bravo"):
    for suffix in (".stdout.log",".json"):
        src=root/"work"/f"1103-bots-{role}{suffix}"
        if src.exists():
            dst=enet/f"1103-qa-{role}{suffix}"
            shutil.copyfile(src,dst)
            inventory.append({"source":src.name,"archived":dst.name,"bytes_raw":dst.stat().st_size})
source=root/"work/1103-war-bots-network.json"
if source.exists():
    dest=enet/"1103-qa-summary.json"
    shutil.copyfile(source,dest)
    inventory.append({"source":source.name,"archived":dest.name,"bytes_raw":dest.stat().st_size})
(base/"enet-evidence-index.json").write_text(json.dumps(inventory,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
print("ARCHIVED_ITEMS",len(inventory))
