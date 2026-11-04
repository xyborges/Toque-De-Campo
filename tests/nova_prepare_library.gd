extends SceneTree

# Bake reusable source assets explicitly; never overwrite authored scenes.
const ASSETS=preload("res://modes/war/scripts/grass_assets.gd")

func _initialize() -> void:
	var root:=Node3D.new();root.name="GramaBaixa"
	root.set_meta("library_id","grama_baixa_2m");root.set_meta("surface","grass")
	root.set_meta("origin","ground");root.set_meta("visual_only",true)
	root.set_meta("asset_revision","nova-grama-preview")
	root.set_meta("dimensions",Vector2(2,2));root.set_meta("destructible",false)
	var close:=MeshInstance3D.new();close.name="Grass";close.mesh=ASSETS.blade_mesh(2);close.material_override=ASSETS.grass_material(2)
	close.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;close.visibility_range_end=42.;root.add_child(close);close.owner=root
	var scene:=PackedScene.new()
	var path:="res://modes/war/library/grama_baixa_2m.tscn"
	var result:=ERR_ALREADY_EXISTS
	var explicit_revision:=false
	# Refresh only a specific reviewed generated file. Normal generation still
	# preserves authored scenes, including edits made since the hash was read.
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--replace-sha256=") and FileAccess.file_exists(path):
			explicit_revision=arg.trim_prefix("--replace-sha256=").to_lower()==FileAccess.get_sha256(path)
	if not FileAccess.file_exists(path) or explicit_revision:
		result=scene.pack(root)
		if result==OK: result=ResourceSaver.save(scene,path)
	root.free()
	print("GRASS_LIBRARY ",JSON.stringify({"ok":result==OK or result==ERR_ALREADY_EXISTS,"existing":result==ERR_ALREADY_EXISTS,"error":result}))
	quit(0 if result==OK or result==ERR_ALREADY_EXISTS else 1)
