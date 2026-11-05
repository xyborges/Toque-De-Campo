"""Recompute only Favela's identity from the committed game sources.

Read-only by default. --write updates a *development candidate*, never deploys.
The game derives a map identity from sorted res:// sources, their sha256 hashes,
then hashes source identity and prepared artifacts (none for Favela currently).
"""
from __future__ import annotations
import argparse
import hashlib
import json
import os
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "maps/prepared/favela/manifest.json"

def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()

def compute() -> tuple[dict, str, str]:
    data = json.loads(MANIFEST.read_text(encoding="utf-8-sig"))
    if data.get("id") != "favela":
        raise ValueError("Expected Favela manifest")
    sources = data.get("sources")
    if not isinstance(sources, list) or len(sources) < 10 or len(set(sources)) != len(sources):
        raise ValueError("Favela source inventory is incomplete or duplicated")
    source_signature = ""
    for uri in sorted(sources):
        if not uri.startswith("res://"):
            raise ValueError("Non-project source: " + uri)
        path = (ROOT / uri[6:]).resolve()
        if not path.is_relative_to(ROOT) or not path.is_file():
            raise ValueError("Missing or external source: " + uri)
        source_signature += uri + ":" + digest(path.read_bytes()) + ";"
    source_hash = digest(source_signature.encode())
    artifact_records = data.get("artifacts", [])
    if not isinstance(artifact_records, list):
        raise ValueError("Invalid artifact records")
    content = source_hash
    for artifact in artifact_records:
        uri = artifact.get("path", "")
        if not uri.startswith("res://"):
            raise ValueError("Invalid prepared artifact path")
        path = (ROOT / uri[6:]).resolve()
        if not path.is_relative_to(ROOT) or not path.is_file():
            raise ValueError("Missing prepared artifact " + uri)
        actual = digest(path.read_bytes())
        if actual != artifact.get("sha256"):
            raise ValueError("Prepared artifact has a changed digest: " + uri)
        content += ";" + uri + ":" + actual
    return data, source_hash, digest(content.encode())

def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--write", action="store_true", help="Update only Favela manifest in the current worktree")
    args = parser.parse_args()
    data, source_hash, content_hash = compute()
    match = data.get("source_hash") == source_hash and data.get("content_hash") == content_hash
    print("FAVELA_MANIFEST", "MATCH" if match else "STALE",
          "version", data["version"], "inputs", len(data["sources"]),
          "old", data.get("source_hash"), "new", source_hash)
    if not args.write:
        return 0 if match else 1
    if match:
        print("NO_CHANGE")
        return 0
    previous = int(data.get("version", 0))
    data["version"] = previous + 1
    data["source_hash"] = source_hash
    data["content_hash"] = content_hash
    data["status"] = "testing"  # A release requires separate QA/approval.
    temp = MANIFEST.with_name(MANIFEST.name + ".candidate-tmp")
    try:
        temp.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        os.replace(temp, MANIFEST)
    finally:
        temp.unlink(missing_ok=True)
    _, verify_source, verify_content = compute()
    if source_hash != verify_source or content_hash != verify_content:
        raise RuntimeError("Manifest does not match source immediately after preparation")
    print("UPDATED_CANDIDATE", "version", data["version"], "status", data["status"])
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
