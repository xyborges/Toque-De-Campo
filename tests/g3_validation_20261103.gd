extends SceneTree

func _initialize() -> void:
	var errors: Array[String]=[]
	if not GameWeapons.ITEMS.has("g3"):errors.append("missing weapon blueprint")
	var item: Dictionary=CombatRules.weapon("g3")
	for required in ["damage","mag","speed","gravity","drag","reserve","reload","cooldown","spread"]:
		if not item.has(required):errors.append("missing "+required)
	if str(item.get("mode",""))!="auto":errors.append("wrong firing mode")
	if WarRules.primary_for("soldier",1)!=["g3"]:errors.append("wrong team 2 primary")
	if WarRules.primary_for("soldier",0)!=["fal"]:errors.append("team 1 changed")
	if WarRules.primary_for("marksman",1)!=["sniper"]:errors.append("marksman changed")
	if not GameWeapons.fresh_ammo().has("g3"):errors.append("magazine missing")
	if not CombatRules.fresh_reserves().has("g3"):errors.append("reserve missing")
	var loadout:=GameLoadouts.defaults("war",GameWeapons.INFANTRY_IDS,"soldier",1)
	if str(loadout.get("primary",""))!="g3":errors.append("default loadout wrong")
	var approved:=GameLoadouts.validate(loadout,"war",GameWeapons.INFANTRY_IDS,"soldier",1)
	if not approved.get("ok",false):errors.append("loadout rejected")
	var denied:=GameLoadouts.validate({"primary":"g3"},"war",GameWeapons.INFANTRY_IDS,"soldier",0)
	if denied.get("ok",false):errors.append("enemy team allowed G3")
	var model:=G3Model.create()
	if not model:errors.append("G3 model missing")
	else:
		for node in ["Muzzle","GripRight","SupportGrip","Magazine","ChargingHandle"]:
			if not model.has_node(node):errors.append("missing model node: "+node)
		if model.get_child_count()<5:errors.append("incomplete model")
		print("G3_MESH_CHILDREN=",model.get_child_count())
		model.free()
	var near:=GameCombatAudioCatalog.stream("res://audio/g3_near.mp3")
	var far:=GameCombatAudioCatalog.stream("res://audio/g3_far.mp3")
	if not near:errors.append("missing near audio")
	if not far:errors.append("missing distant audio")
	print("G3_STATS=",item)
	print("G3_LOADOUT=",approved)
	if errors.is_empty():print("G3_VALIDATION_PASS")
	else:
		for error in errors:push_error("G3_VALIDATION_FAIL: "+error)
	quit(0 if errors.is_empty() else 1)
