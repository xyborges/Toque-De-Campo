extends SceneTree
var records: Array[Dictionary]=[]
func _initialize() -> void:run.call_deferred()
func site(label: String,p: Vector3,half: Vector2,pose:=Basis.IDENTITY) -> void:
	var lo:=INF;var hi:=-INF;var max_slope:=0.
	for x in [-half.x,0.,half.x]:
		for z in [-half.y,0.,half.y]:
			var at:=p+pose*Vector3(x,0,z);var h:=WarTerrain.height_at(at.x,at.z);lo=minf(lo,h);hi=maxf(hi,h)
	for radius in [12.,22.]:
		for i in 8:
			var angle:=i*TAU/8.;var at:=p+Vector3(cos(angle)*radius,0,sin(angle)*radius)
			max_slope=maxf(max_slope,absf(rad_to_deg(atan2(WarTerrain.height_at(at.x,at.z)-p.y,radius))))
	records.append({"label":label,"point":p,"underlying":WarTerrain._base(p.x,p.z),"support_min":lo,"support_max":hi,"gap":p.y-hi,"buried":hi-p.y,"span":hi-lo,"approach_slope":max_slope})
func collect(node: Node,pose:=Transform3D.IDENTITY) -> void:
	if node is Node3D:pose=pose*node.transform
	var id:=str(node.get_meta("library_id",""))
	if id in ["casa_ruina","fachada_atingida"]:site(str(node.name),pose.origin,Vector2(node.get_meta("footprint",Vector2(12,10)))*.5,pose.basis)
	for child in node.get_children():collect(child,pose)
func run() -> void:
	WarTerrainEdits.prepare()
	for side in [-1,1]:
		for at in [Vector2(side*250,-135),Vector2(side*230,-205)]:site("ForwardHouse",WarTerrain.point(at.x,at.y),Vector2(6.25,4.75))
	for at in [Vector2(-66,82),Vector2(5,120),Vector2(64,88),Vector2(-45,150),Vector2(70,155),Vector2(10,45)]:site("CentralHouse",WarTerrain.point(at.x,at.y),Vector2(6.25,4.75))
	for centre in WarOutskirts.VILLAGES:
		for i in 8:
			var at: Vector2=centre+Vector2((i%4)*39-58,(i/4)*65-32)
			if not WarTerrainEdits.replaces_lot(at):site("VillageHouse",WarTerrain.point(at.x,at.y),Vector2(6.25,4.75))
	for centre in WarUrbanLayout.CENTRES:
		for i in 6:
			var at: Vector2=centre+Vector2((i%3)*42-42,(i/3)*58-29);site("TownBlock",WarTerrain.point(at.x,at.y),Vector2(11.5,9))
	for file in ["res://modes/war/scenes/map_additions.tscn","res://modes/war/scenes/east_port.tscn"]:
		var scene: Node3D=load(file).instantiate();collect(scene,Transform3D(Basis.IDENTITY,Vector3(1190,4,470) if "east_port" in file else Vector3.ZERO));scene.free()
	records.sort_custom(func(a,b):return float(a.approach_slope)>float(b.approach_slope))
	var report:={"count":records.size(),"sites":records}
	var maximum_gap:=0.;var maximum_span:=0.;var maximum_slope:=0.
	for record in records:
		maximum_gap=maxf(maximum_gap,absf(record.gap));maximum_span=maxf(maximum_span,record.span);maximum_slope=maxf(maximum_slope,record.approach_slope)
	report.maximum_foundation_error=maximum_gap;report.maximum_footprint_variation=maximum_span;report.maximum_approach_slope=maximum_slope
	report.ok=records.size()==122 and maximum_gap<.5 and maximum_span<1. and maximum_slope<45.
	NavalStorage.write_json("res://work/ukraine-building-sites.json",report)
	for record in records:
		if record.approach_slope>22. or record.span>1. or absf(record.gap)>1.:print(JSON.stringify(record))
	print("BUILDING_SITES ",records.size()," ok=",report.ok," foundation=",maximum_gap," slope=",maximum_slope);quit(0 if report.ok else 1)
