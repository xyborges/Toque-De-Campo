extends "res://tests/afghan_territory_preview.gd"
const BASELINE=preload("res://work/afghan-before-finish/baseline_map.gd")
func create_map() -> Node3D:
	return BASELINE.new() if "--reference" in OS.get_cmdline_user_args() else Afghan.new()
