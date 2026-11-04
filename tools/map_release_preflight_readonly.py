"""Read-only release preflight for Godot map manifests. Never builds or restores files."""
from pathlib import Path
import argparse
import hashlib
import json

IDS = ("ukraine", "afghan", "desert", "office", "naval")

def digest(path):
    h = hashlib.sha256()
    with path.open("rb") as reader:
        for chunk in iter(lambda: reader.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()

def inspect(root, map_id):
    manifest = root / "maps" / "prepared" / map_id / "manifest.json"
    row = {"map": map_id, "ready": False, "version": None,
           "missing_sources": [], "changed_since_manifest": [],
           "missing_artifacts": [], "altered_artifacts": []}
    if not manifest.is_file():
        row["problem"] = "prepared manifest is absent"
        return row
    try:
        obj = json.loads(manifest.read_text(encoding="utf-8-sig"))
    except (ValueError, OSError) as error:
        row["problem"] = f"manifest cannot be read: {error}"
        return row
    row["version"] = obj.get("version")
    pieces = []
    for uri in sorted(obj.get("sources", [])):
        if not isinstance(uri, str) or not uri.startswith("res://"):
            row["missing_sources"].append(str(uri))
            continue
        path = root / uri[6:]
        if not path.is_file():
            row["missing_sources"].append(uri)
            continue
        pieces.append(f"{uri}:{digest(path)};")
        if path.stat().st_mtime > manifest.stat().st_mtime:
            row["changed_since_manifest"].append(uri)
    current = hashlib.sha256("".join(pieces).encode("utf-8")).hexdigest()
    row["source_hash_matches"] = (not row["missing_sources"] and
                                  current == obj.get("source_hash", ""))
    for art in obj.get("artifacts", []):
        uri = art.get("path", "")
        if not isinstance(uri, str) or not uri.startswith("res://"):
            row["missing_artifacts"].append(str(uri))
            continue
        path = root / uri[6:]
        if not path.is_file():
            row["missing_artifacts"].append(uri)
        elif digest(path) != art.get("sha256", ""):
            row["altered_artifacts"].append(uri)
    row["ready"] = bool(obj.get("version", 0) > 0 and
                        len(obj.get("content_hash", "")) == 64 and
                        row["source_hash_matches"] and
                        not row["missing_artifacts"] and
                        not row["altered_artifacts"])
    return row

def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    ap.add_argument("--map", choices=("all", *IDS), default="all")
    ap.add_argument("--json", action="store_true")
    args = ap.parse_args()
    root = args.root.resolve()
    reports = [inspect(root, name) for name in (IDS if args.map == "all" else (args.map,))]
    if args.json:
        print(json.dumps(reports, indent=2, ensure_ascii=False))
    else:
        for row in reports:
            print(f"{row['map'].upper()}: {'READY' if row['ready'] else 'STALE'} (version {row['version']})")
            if not row["ready"]:
                print(f"  source hash matches: {row.get('source_hash_matches', False)}")
                for key in ("missing_sources", "changed_since_manifest", "missing_artifacts", "altered_artifacts"):
                    items = row[key]
                    if items:
                        print(f"  {key}: {len(items)} | examples: {', '.join(items[:4])}")
                if row.get("problem"):
                    print("  problem:", row["problem"])
        print("READ ONLY: no manifests, assets or deleted files were changed.")
    return 0 if all(item["ready"] for item in reports) else 2

if __name__ == "__main__":
    raise SystemExit(main())
