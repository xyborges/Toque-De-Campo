"""Record cache provenance; do not regenerate content or change project code."""
from pathlib import Path
import hashlib,json,subprocess
root=Path(__file__).resolve().parents[2]
cache=root/"maps/prepared/favela/housing_plan_cache.res"
sources=["modes/war/scripts/favela_map.gd","modes/war/scripts/favela_layout.gd",
         "modes/war/scripts/favela_street_space.gd"]
def sha(path:Path):
    return hashlib.sha256(path.read_bytes()).hexdigest()
src={key:sha(root/key) for key in sources}
signature=hashlib.sha256(":".join(src.values()).encode("utf-8")).hexdigest()
expected="c32fd8a5d8a5b58b84f9d550ae3f1949d3316cbeecadfef721275d40eae15dd4"
assert signature==expected,(signature,expected)
base=subprocess.check_output(["git","-C",str(root),"rev-parse","HEAD"],text=True).strip()
result={"base_git_commit":base,"godot":"4.7.2.stable.official.ed1daf0bf",
        "flag":"TDC_IA2_HOUSING_CACHE=1","default_enabled":False,
        "cache_asset":"maps/prepared/favela/housing_plan_cache.res",
        "asset_bytes":cache.stat().st_size,"asset_sha256":sha(cache),
        "source_files_sha256":src,"source_signature":signature,
        "lots":4188,"plan_sha256":"9264a7d132a78bf2b9fc4966dab849dd92e66bb622321f547133febc60d3a479"}
out=Path(__file__).with_name("asset-provenance.json")
out.write_text(json.dumps(result,indent=2,ensure_ascii=False)+"\n",encoding="utf-8")
print(json.dumps({"asset_sha256":result["asset_sha256"],"signature":signature,"bytes":result["asset_bytes"]}))
