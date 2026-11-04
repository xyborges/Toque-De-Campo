extends SceneTree
func _initialize() -> void:
	for road in [2,3]:
		var path:=WarRoads.rounded(WarRoads.ROUTES[road]);var rows: Array=[]
		for part in path.size()-1:
			var a: Vector2=path[part];var b: Vector2=path[part+1];var count:=maxi(1,ceili(a.distance_to(b)))
			for step in count:
				var p:=a.lerp(b,float(step)/count);var q:=a.lerp(b,float(step+1)/count)
				var h:=WarTerrain.height_at(p.x,p.y);var h2:=WarTerrain.height_at(q.x,q.y)
				var grade:=absf(h-h2)/p.distance_to(q)
				if grade>.12: rows.append({"p":str(p),"grade":grade,"h":h,"h2":h2,"raw":WarTerrain.raw_height(p.x,p.y),"base":WarTerrain._base(p.x,p.y),"profile":WarRoads.port_grade(p.x,p.y,999)})
		rows.sort_custom(func(a,b):return a.grade>b.grade)
		print("ROAD ",road," ",JSON.stringify(rows.slice(0,12)))
	quit()
