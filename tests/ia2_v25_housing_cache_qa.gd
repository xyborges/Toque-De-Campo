extends SceneTree

var mode: String="measure"
func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--mode="):mode=arg.trim_prefix("--mode=")
	_run.call_deferred()

func _run() -> void:
	WarFavelaMap.housing_lots.clear()
	var before_usec:=Time.get_ticks_usec()
	var lots: Array[Dictionary]=WarFavelaMap.housing_plan()
	var elapsed_ms: float=(Time.get_ticks_usec()-before_usec)*.001
	var digest: String=JSON.stringify(lots).sha256_text()
	var signature: String=WarFavelaMap.ia2_housing_source_signature()
	var report: Dictionary={"mode":mode,"count":lots.size(),"digest":digest,"signature":signature,
		"status":WarFavelaMap.ia2_housing_cache_stats.get("status",""),"elapsed_ms":elapsed_ms}
	if mode=="generate":
		var res:=Resource.new()
		res.set_meta("lots",lots)
		res.set_meta("digest",digest)
		res.set_meta("signature",signature)
		report["save_status"]=ResourceSaver.save(res,WarFavelaMap.IA2_HOUSING_CACHE_PATH)
		var loaded: Resource=ResourceLoader.load(WarFavelaMap.IA2_HOUSING_CACHE_PATH,"",ResourceLoader.CACHE_MODE_IGNORE)
		report["roundtrip_sha256"]=JSON.stringify(loaded.get_meta("lots",[]) if loaded else []).sha256_text()
	print("IA2_V25_PLAN ",JSON.stringify(report))
	var ok: bool=lots.size()>4000 and not signature.is_empty()
	if mode=="generate":ok=ok and int(report.get("save_status",-1))==0 and digest==report.roundtrip_sha256
	quit(0 if ok else 2)
