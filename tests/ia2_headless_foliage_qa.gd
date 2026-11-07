extends SceneTree

# The dedicated server never draws hillside shrubs, grass or decorative
# rocks. Tree sites (and therefore physical trunks) must be EXACTLY the same
# after skipping the plans with independent RNGs.
func _initialize() -> void:
	_go.call_deferred()

func _go() -> void:
	var lots: Array[Dictionary]=WarFavelaMap.housing_plan()
	var started:=Time.get_ticks_usec()
	var full: Dictionary=WarFavelaHillside.plan(lots,WarFavelaMap.BASES_2D,
		WarFavelaMap.OBJECTIVES_2D,
		func(p: Vector2) -> float: return WarFavelaMap.road_distance(p),false)
	var full_ms:float=(Time.get_ticks_usec()-started)*.001
	started=Time.get_ticks_usec()
	var quick: Dictionary=WarFavelaHillside.plan(lots,WarFavelaMap.BASES_2D,
		WarFavelaMap.OBJECTIVES_2D,
		func(p: Vector2) -> float: return WarFavelaMap.road_distance(p),true)
	var quick_ms:float=(Time.get_ticks_usec()-started)*.001
	var errors: Array[String]=[]
	if lots.size()!=4313:errors.append("wrong houses")
	if JSON.stringify(full.trees)!=JSON.stringify(quick.trees):errors.append("TREE SITES DIVERGED")
	if not quick.shrubs.is_empty() or not quick.grass.is_empty() or not quick.rocks.is_empty():
		errors.append("decorative sites not skipped")
	if full.trees.size()!=1850 or full.shrubs.size()!=4700 or full.grass.size()!=13334 or full.rocks.size()!=480:
		errors.append("unexpected standard visual site counts")
	print("IA2_HEADLESS_FOLIAGE_QA ",JSON.stringify({
		"full_ms":full_ms,"skip_ms":quick_ms,
		"original_counts":{"trees":full.trees.size(),"shrubs":full.shrubs.size(),
			"grass":full.grass.size(),"rocks":full.rocks.size()},
		"skip_trees":quick.trees.size(),
		"tree_sha256":JSON.stringify(full.trees).sha256_text(),
		"skip_tree_sha256":JSON.stringify(quick.trees).sha256_text(),
		"errors":errors}))
	quit(0 if errors.is_empty() else 2)
