"""Map audit/build/validation/benchmark entry point. Writes generated outputs only."""
from pathlib import Path
import argparse
import hashlib
import json
import os
import subprocess
import sys
from datetime import datetime

ROOT = Path(__file__).resolve().parents[1]
IDS = ("ukraine", "afghan", "desert", "office", "naval")
DEFAULT_ENGINE = Path.home() / "Documents/Codex/tools/Godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe"


def sources(map_id):
    common = ["scripts/maps", "tools/maps/adapter.gd", "tools/maps/pipeline.gd", "scripts/environment/environment_kit.gd", "scripts/environment/environment_props.gd"]
    specific = {
        "ukraine": ["modes/war/scripts", "modes/war/library", "modes/war/scenes", "assets/war/biomes", "modes/war/shaders"],
        "afghan": ["modes/battle_royale/map", "modes/battle_royale/library", "modes/battle_royale/scenes"],
        "desert": ["scripts/environment/desert_map.gd", "scripts/environment/desert_terrain.gd", "modes/war/scripts/grass_assets.gd", "modes/war/shaders/grass_field.gdshader"],
        "office": ["scripts/environment/office_map.gd"],
        "naval": ["scripts/environment/naval_islands.gd", "modes/naval/shaders"],
    }
    paths = set()
    for folder in common + specific[map_id]:
        base = ROOT / folder
        for path in ([base] if base.is_file() else base.rglob("*")):
            if path.is_file() and path.suffix in {".gd", ".gdshader", ".tscn", ".png", ".json"} and not {"baked", "prepared"}.intersection(path.parts):
                paths.add("res://" + path.relative_to(ROOT).as_posix())
    extra = {
        "ukraine": ["scripts/offline_director.gd", "modes/naval/scripts/catalog.gd"],
        "afghan": ["modes/battle_royale/navigation/navigation.gd", "modes/battle_royale/navigation/prepared/manifest.json"],
        "desert": ["scripts/offline_director.gd"],
        "office": ["scripts/offline_director.gd"],
        "naval": ["modes/naval/scripts/catalog.gd"],
    }
    for path in extra[map_id]:
        paths.add("res://" + path)
    return sorted(paths)


def run_engine(engine, operation, map_id, output, extra=()):
    prefix = output / f"{map_id}-{operation}"
    args = [str(engine), "--path", str(ROOT), "--rendering-method", "gl_compatibility", "--log-file", str(prefix.with_suffix(".log"))]
    if operation != "measure":
        args += ["--headless", "--script", "res://tools/maps/pipeline.gd"]
    else:
        args += ["--resolution", "1920x1080", "--script", "res://tools/maps/benchmark.gd"]
    args += ["--", f"--operation={operation}", f"--map={map_id}", "--output=" + output.as_posix(), *extra]
    if operation == "prepare":
        args += ["--map-uncached"]
    environment = os.environ.copy()
    environment["APPDATA"] = str(output / "runtime-appdata")
    args += ["--naval-test-accounts", "--naval-data=" + (output / "qa-profile").as_posix()]
    with prefix.with_suffix(".stdout.log").open("w", encoding="utf-8") as log:
        proc = subprocess.Popen(args, cwd=ROOT, env=environment, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, encoding="utf-8", errors="replace", creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0))
        for line in proc.stdout:
            log.write(line)
            log.flush()
            if line.startswith(("MAP_", "ERROR:", "SCRIPT ERROR:", "Parse Error")):
                print(line.rstrip(), flush=True)
        code = proc.wait()
    text = prefix.with_suffix(".stdout.log").read_text(encoding="utf-8")
    if "SCRIPT ERROR:" in text or "Parse Error" in text:
        return 2
    return code


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("operation", choices=["audit", "prepare", "validate", "measure"])
    parser.add_argument("--map", default="all", choices=["all", *IDS])
    parser.add_argument("--engine", type=Path, default=Path(os.environ.get("GODOT_EXE", DEFAULT_ENGINE)))
    parser.add_argument("--output", type=Path)
    parser.add_argument("--seconds", type=float, default=120)
    parser.add_argument("--pairs", type=int, default=5)
    parser.add_argument("--participants", type=int, default=18)
    parser.add_argument("--mode", choices=["aa", "ab"], default="ab")
    args = parser.parse_args()
    if not args.engine.is_file():
        parser.error("Godot executable not found; use --engine or GODOT_EXE")
    output = (args.output or ROOT / "work/maps" / datetime.now().strftime("%Y%m%d-%H%M%S")).resolve()
    output.mkdir(parents=True, exist_ok=True)
    data = {}
    for map_id in IDS:
        data[map_id] = {"sources": sources(map_id), "reservations": {"ukraine": ["roads", "trenches", "bases", "objectives", "authored_terrain"], "afghan": ["stream", "roads", "irrigation", "farmland", "property_access"], "desert": ["outpost", "spawn_pads", "approaches"], "office": ["doors", "corridors", "rooms"], "naval": ["islands", "ports", "water_lanes"]}[map_id], "benchmark": {"resolution": [1920, 1080], "renderer": "gl_compatibility", "seconds": 120, "pairs": 5, "median_loss_max_percent": 5, "worst_frame_max_ms": 50, "vram_limit_mib": 4096}}
    input_path = output / "input.json"
    input_path.write_text(json.dumps(data, indent=2), encoding="utf-8")
    selected = IDS if args.map == "all" else [args.map]
    result = 0
    for map_id in selected:
        extra = [f"--seconds={args.seconds}", f"--pairs={args.pairs}", f"--participants={args.participants}", f"--bench-mode={args.mode}"] if args.operation == "measure" else []
        result = max(result, run_engine(args.engine, args.operation, map_id, output, ["--input=" + input_path.as_posix(), *extra]))
    print("Reports:", output)
    return result


if __name__ == "__main__":
    sys.exit(main())
