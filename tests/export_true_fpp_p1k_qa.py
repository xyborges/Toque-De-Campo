"""Export the existing P1k workload as the entry scene of a local Windows QA build.

Run in an isolated worktree. Reserve project.godot and the three paths in
benchmark_sources(), including the two generated .gd.uid files, before export.
"""
import argparse
from contextlib import ExitStack
from hashlib import file_digest, sha256
import json
import os
from pathlib import Path
import subprocess


ROOT = Path(__file__).resolve().parents[1]
BENCHMARK = "tests/true_fpp_p1k_paired_cost.gd"
FIXTURE = "tests/war_optics_fixture.gd"
QA_SCRIPT = "qa/p1k_paired_cost.gd"
QA_FIXTURE = "qa/p1k_cost_fixture.gd"
QA_SCENE = "qa/p1k_paired_cost.tscn"


def benchmark_sources():
    """Adapt the SceneTree entry point while keeping the timed loop identical."""
    source = (ROOT / BENCHMARK).read_text(encoding="utf-8")
    for original, replacement in (
        ("extends SceneTree", "extends Node"),
        ("func _initialize() -> void:", 'func _ready() -> void:\n'
         '\tprint("P1K_EXPORT_ENTRY release=", OS.has_feature("release"), " qa=", OS.has_feature("qa"))'),
        (f"res://{FIXTURE}", f"res://{QA_FIXTURE}"),
        ("\troot.add_child(game)", "\tget_tree().root.add_child(game)"),
        ("await process_frame", "await get_tree().process_frame"),
        ("await physics_frame", "await get_tree().physics_frame"),
        ("\tquit(", "\tget_tree().quit("),
    ):
        if original not in source:
            raise RuntimeError(f"Benchmark entry changed: {original!r}")
        source = source.replace(original, replacement)
    scene = f'''[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://{QA_SCRIPT}" id="1"]

[node name="P1kBenchmark" type="Node"]
script = ExtResource("1")
'''
    return {name: contents.replace("\n", os.linesep).encode("utf-8") for name, contents in {
        QA_SCRIPT: source,
        QA_FIXTURE: (ROOT / FIXTURE).read_text(encoding="utf-8"),
        QA_SCENE: scene,
    }.items()}


def file_hash(path):
    with path.open("rb") as stream:
        return file_digest(stream, "sha256").hexdigest()


def gameplay_hashes():
    return {path.relative_to(ROOT).as_posix(): file_hash(path)
            for directory in ("scripts", "modes") for path in (ROOT / directory).rglob("*.gd")}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--engine", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path, help="New directory outside the project")
    args = parser.parse_args()
    engine = args.engine.resolve()
    if os.name == "nt" and engine.name.endswith("_console.exe"):
        engine = engine.with_name(engine.name.removesuffix("_console.exe") + ".exe")
    if not engine.is_file():
        parser.error(f"Godot executable not found: {engine}")
    output = args.output.resolve()
    if output == ROOT or ROOT in output.parents:
        parser.error("Choose an output directory outside the project")
    output.mkdir(parents=True, exist_ok=False)
    config = ROOT / "project.godot"
    original = config.read_bytes()
    default_scene = b'run/main_scene="res://scenes/main.tscn"'
    if original.count(default_scene) != 1:
        raise RuntimeError("Unexpected project main scene")
    temporary = original.replace(default_scene, f'run/main_scene="res://{QA_SCENE}"'.encode())
    sources = benchmark_sources()
    targets = [ROOT / path for path in sources]
    uid_paths = [path.with_suffix(".gd.uid") for path in targets if path.suffix == ".gd"]
    if any(path.exists() for path in targets + uid_paths):
        raise RuntimeError("QA staging paths already exist; inspect before re-exporting")
    gameplay = gameplay_hashes()
    presets_hash = file_hash(ROOT / "export_presets.cfg")
    executable = output / "P1kBenchmark.exe"
    with ExitStack() as cleanup:
        for path in uid_paths:
            cleanup.callback(path.unlink, missing_ok=True)
        for name, data in sources.items():
            path = ROOT / name
            with path.open("xb") as stream:
                cleanup.callback(path.unlink)
                stream.write(data)
        try:
            config.write_bytes(temporary)
            with (output / "export.log").open("wb") as log:
                process = subprocess.run([
                    str(engine), "--headless", "--path", str(ROOT),
                    "--export-release", "Windows QA", str(executable),
                ], cwd=ROOT, stdout=log, stderr=subprocess.STDOUT, timeout=420,
                    creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0))
        finally:
            if config.read_bytes() != temporary:
                raise RuntimeError("project.godot changed during export; inspect before restoring")
            config.write_bytes(original)
    log = (output / "export.log").read_text(encoding="utf-8", errors="replace")
    if process.returncode or "ERROR:" in log or not executable.is_file():
        raise RuntimeError(f"Windows QA export failed; see {output / 'export.log'}")
    if gameplay_hashes() != gameplay or file_hash(ROOT / "export_presets.cfg") != presets_hash:
        raise RuntimeError("Gameplay or export preset changed during export")
    manifest = {
        "fixtures_sha256": {name: sha256(data).hexdigest() for name, data in sources.items()},
        "exe_sha256": file_hash(executable),
        "pack_sha256": file_hash(executable.with_suffix(".pck")),
        "project_sha256": sha256(original).hexdigest(),
        "export_presets_sha256": presets_hash,
        "gameplay_sha256": gameplay,
    }
    (output / "p1k_export.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(f"Windows QA export: {executable}")


if __name__ == "__main__":
    main()
