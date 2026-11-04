extends SceneTree
func _initialize() -> void:
	for kind in ["vest","helmet","pack"]:
		for level in range(1,4):
			var path: String=BRProtectionAppearance.DIR+str(kind)+"_%d.tscn"%level
			if FileAccess.file_exists(path) and "--refresh-br-equipment" not in OS.get_cmdline_user_args():continue
			var piece:=BRProtectionAppearance.make(kind,level)
			for child in piece.get_children():child.owner=piece
			var packed:=PackedScene.new();packed.pack(piece);ResourceSaver.save(packed,path);piece.free()
	print("BR_PROTECTION_ASSETS_READY");quit()
