"""Read-only integrity guard for the Afghanistan V13 and Ukraine prepared map builds."""
from pathlib import Path
import hashlib,json,sys

ROOT=Path(__file__).resolve().parents[1]
errors=[];report={}
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest() if p.is_file() else ""
def res(uri):
 if not str(uri).startswith("res://"):raise ValueError("Non-project resource path "+str(uri))
 return ROOT/str(uri)[6:]
def source_hash(paths):
 sig=""
 for uri in sorted(paths):
  if not res(uri).is_file():return ""
  sig+=uri+":"+sha(res(uri))+";"
 return hashlib.sha256(sig.encode("utf-8")).hexdigest()
def check(ok,label):
 print(("PASS " if ok else "FAIL ")+label)
 if not ok:errors.append(label)

fixed=["afghan_map","afghan_landform","afghan_environment","afghan_context","afghan_field_cover","afghan_tactical_density","afghan_density_stage2","afghan_density_stage3"]
nav_sources=["res://modes/battle_royale/map/"+n+".gd" for n in fixed]
nav_sources+=["res://modes/battle_royale/scenes/map_additions.tscn"]
nav_sources+=["res://modes/battle_royale/library/"+p.name for p in (ROOT/"modes/battle_royale/library").iterdir() if p.is_file() and p.suffix==".tscn"]
nav_path=ROOT/"modes/battle_royale/navigation/prepared/manifest.json"
if not nav_path.is_file():raise SystemExit("Missing BR navigation manifest")
nav=json.loads(nav_path.read_text(encoding="utf-8-sig"))
expected_nav_hash=source_hash(nav_sources)
shed_tiles=[x for x in nav.get("tiles",[]) if "/shed_" in str(x.get("path",""))]
shed_links=[x for x in nav.get("links",[]) if "v13_shed" in x]
check(nav.get("complete") is True,"BR navigation is complete")
check(nav.get("source_hash")==expected_nav_hash,"BR navigation V13 sources match")
check(len(shed_tiles)==12 and len(shed_links)==12,"Twelve V13 shelters have prepared regions and links")
check(all(res(x["path"]).is_file() and res(x["path"]).stat().st_size>100 for x in nav.get("tiles",[])),"All BR navigation mesh resources exist")
check(len(nav.get("spawns",[]))>=50 and len(nav.get("loot",[]))>=200,"BR prepared spawns and navigable loot present")
report["br"]={"regions":len(nav.get("tiles",[])),"links":len(nav.get("links",[])),"spawns":len(nav.get("spawns",[])),"navigable_loot":len(nav.get("loot",[])),"source_hash":expected_nav_hash}
for name in ["afghan","ukraine"]:
 path=ROOT/f"maps/prepared/{name}/manifest.json"
 if not path.is_file():raise SystemExit("Missing prepared map manifest "+name)
 manifest=json.loads(path.read_text(encoding="utf-8-sig"))
 calculated=source_hash(manifest.get("sources",[]))
 check(bool(calculated) and calculated==manifest.get("source_hash"),name+": input files match manifest")
 artifacts=manifest.get("artifacts",[])
 check(bool(artifacts) and all(res(a["path"]).is_file() and sha(res(a["path"]))==a["sha256"] for a in artifacts),name+": prepared resource hashes match")
 content=calculated+"".join(";"+a["path"]+":"+a["sha256"] for a in artifacts)
 check(hashlib.sha256(content.encode()).hexdigest()==manifest.get("content_hash"),name+": prepared content identity matches")
 report[name]={"version":manifest.get("version"),"sources":len(manifest.get("sources",[])),"artifacts":len(artifacts),"hash":manifest.get("content_hash")}
print("V13_MAP_GUARD "+json.dumps({"ok":not errors,"errors":errors,"results":report},ensure_ascii=False))
sys.exit(0 if not errors else 1)
