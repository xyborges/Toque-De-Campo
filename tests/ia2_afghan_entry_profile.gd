extends SceneTree

func _initialize() -> void:
	_measure.call_deferred()

func _measure() -> void:
	var begin:=Time.get_ticks_usec()
	var buildings: Array[Dictionary]=BRAfghanMap.building_layout()
	var first_ms: float=(Time.get_ticks_usec()-begin)*.001
	begin=Time.get_ticks_usec()
	var again: Array[Dictionary]=BRAfghanMap.building_layout()
	var second_ms: float=(Time.get_ticks_usec()-begin)*.001
	var report: Dictionary={
		"count":buildings.size(),"first_ms":first_ms,"second_ms":second_ms,
		"digest":JSON.stringify(buildings).sha256_text(),
		"identical":JSON.stringify(again).sha256_text()==JSON.stringify(buildings).sha256_text(),
		"memoized":BRAfghanLandform._ready,
		"engine":Engine.get_version_info()
	}
	print("IA2_AFGHAN_LAYOUT ",JSON.stringify(report))
	quit(0 if bool(report.identical) and bool(report.memoized) else 2)
