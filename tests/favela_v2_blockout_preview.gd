extends SceneTree
## Prévia macro: orçamento leve e isolado, sem instanciar o mapa 1.5 km.
const TOPO=preload("res://modes/war/scripts/favela_v2_topology.gd")
const IMAGE_PATH="res://work/favela-v2-phase1-macro.png"

class LayoutCanvas extends Node2D:
	const TOPO=preload("res://modes/war/scripts/favela_v2_topology.gd")
	const SCALE:=1.16
	const CENTER:=Vector2(640,408)
	var houses: Array[Dictionary]=[]

	func project(p: Vector2)->Vector2:
		return CENTER+p*SCALE

	func _ready()->void:
		houses=_make_houses()
		queue_redraw()

	func _away_from_other_routes(p: Vector2)->bool:
		for road: Dictionary in TOPO.LINKS:
			var poly:=TOPO.polyline(road)
			for j in poly.size()-1:
				var nearest:=Geometry2D.get_closest_point_to_segment(p,poly[j],poly[j+1])
				if p.distance_to(nearest)<float(road["width"])*.5+3.8:return false
		return true

	func _make_houses()->Array[Dictionary]:
		var result: Array[Dictionary]=[]
		for link: Dictionary in TOPO.LINKS:
			var west:=str(TOPO.NODES[str(link["a"])]["zone"])==TOPO.SECTOR_LEFT or str(TOPO.NODES[str(link["b"])]["zone"])==TOPO.SECTOR_LEFT
			var points:=TOPO.polyline(link)
			var spacing:=13.0 if west else 20.5
			for segment in points.size()-1:
				var a: Vector2=points[segment]
				var b: Vector2=points[segment+1]
				var axis: Vector2=(b-a).normalized()
				var normal:=Vector2(-axis.y,axis.x)
				var count:=maxi(1,floori(a.distance_to(b)/spacing))
				for index in count:
					var fraction: float=(float(index)+.5)/float(count)
					if fraction<.14 or fraction>.86:continue
					for side in [-1,1]:
						var offset:=float(link["width"])*.5+(6.1 if west else 8.7)
						var jitter: float=float(posmod(index+segment*3+side*7+str(link["id"]).length(),5)-2)*.35
						var point:=a.lerp(b,fraction)+normal*float(side)*(offset+jitter)
						if not TOPO.BOUNDS.grow(-17.0).has_point(point):continue
						if not _away_from_other_routes(point):continue
						var near_base:=false
						for base_id in ["base_sul","base_norte"]:
							if point.distance_to(TOPO.NODES[base_id]["p"])<39.0:near_base=true
						if near_base:continue
						for center_id in ["praca","campinho","mercadinho","patio_oeste"]:
							if point.distance_to(TOPO.NODES[center_id]["p"])<17.0:near_base=true
						if near_base:continue
						var too_close:=false
						for built: Dictionary in result:
							if point.distance_squared_to(built["p"]) < (116.0 if west else 210.0):
								too_close=true
								break
						if too_close:continue
						result.append({"p":point,"side":side,"west":west,
							"size":Vector2(9.1,10.2) if west else Vector2(11.1,10.3)})
		return result

	func _draw()->void:
		draw_rect(Rect2(Vector2.ZERO,Vector2(1280,825)),Color("#f8f7f2"))
		for hill: Dictionary in TOPO.HILL_CONTOURS:
			var poly:=PackedVector2Array()
			var center: Vector2=hill["center"]
			var radius: Vector2=hill["radius"]
			for k in 72:
				var a:=TAU*float(k)/72.0
				var rough:=1.0+.045*sin(float(k)*.72)
				poly.append(project(center+Vector2(cos(a)*radius.x,sin(a)*radius.y)*rough))
			draw_colored_polygon(poly,Color(0.82,0.59,0.30,.13))
			poly.append(poly[0])
			draw_polyline(poly,Color("#df8b41"),2.6,true)
		for house: Dictionary in houses:
			var at:=project(house["p"])
			var size: Vector2=house["size"]*SCALE
			var rect:=Rect2(at-size*.5,size)
			draw_rect(rect,Color("#e4d8e5"))
			draw_rect(rect,Color("#9956a1"),false,1.6)
		for link: Dictionary in TOPO.LINKS:
			var poly:=PackedVector2Array()
			for point: Vector2 in TOPO.polyline(link):poly.append(project(point))
			var w:=float(link["width"])*SCALE
			draw_polyline(poly,Color("#252628"),w+3.6,true)
			var color:=Color("#c6c7c1") if str(link["kind"])=="rua" else Color("#ddd7ca")
			if str(link["kind"])=="escada":color=Color("#e3dfd2")
			draw_polyline(poly,color,w,true)
			if str(link["kind"])=="escada":
				_draw_stair_treads(poly,w)
		# Functional spaces only. Final objectives remain unassigned.
		for id in ["praca","campinho","mercadinho","patio_oeste"]:
			var p: Vector2=project(TOPO.NODES[id]["p"])
			var radius:=Vector2(26,19) if id=="campinho" else Vector2(14,12)
			draw_rect(Rect2(p-radius,pow(1.0,0.0)*radius*2.0),
				Color("#b9c8a1") if id=="campinho" else Color("#dbd4bb"))
			draw_rect(Rect2(p-radius,radius*2.0),Color("#4f6751") if id=="campinho" else Color("#9c8556"),false,1.5)
		for id in ["base_sul","base_norte"]:
			var p: Vector2=project(TOPO.NODES[id]["p"])
			draw_circle(p,13,Color("#536bc5") if id=="base_sul" else Color("#c75353"))
			draw_arc(p,15,0,TAU,32,Color("#262c33"),2.2,true)
		# The west has exactly one connection: foreground explanatory marker.
		var gateway=project(TOPO.NODES["portal_oeste"]["p"])
		draw_arc(gateway,12,0,TAU,48,Color("#b87b24"),2.6,true)
		var font:=ThemeDB.fallback_font
		draw_string(font,Vector2(30,35),"FAVELA V2  /  ETAPA 1 — BLOCKOUT DE VIAS",HORIZONTAL_ALIGNMENT_LEFT,-1,21,Color("#272625"))
		draw_string(font,Vector2(30,61),"Morro esquerdo: acesso exclusivamente pelo miolo | sem ligacao com a base norte",HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("#544a40"))
		draw_string(font,Vector2(30,797),"Ruas e becos = preto/concreto  |  escadoes = faixas  |  casas = roxo  |  limites do morro = laranja",HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("#635447"))
		for id in ["praca","campinho","patio_oeste","mirante","base_sul","base_norte"]:
			var title: String=str(id).replace("_"," ").capitalize()
			draw_string(font,project(TOPO.NODES[id]["p"])+Vector2(17,-8),
				title,HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("#433d42"))
		draw_string(font,gateway+Vector2(10,22),"Portao do miolo (unica entrada)",HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("#9a6d27"))

	func _draw_stair_treads(points: PackedVector2Array,walk_width: float)->void:
		for n in points.size()-1:
			var a:=points[n]
			var b:=points[n+1]
			var tangent: Vector2=(b-a).normalized()
			var normal:=Vector2(-tangent.y,tangent.x)
			var length:=a.distance_to(b)
			var steps:=maxi(1,ceili(length/8.0))
			for j in range(1,steps):
				var middle:=a.lerp(b,float(j)/float(steps))
				draw_line(middle-normal*walk_width*.46,middle+normal*walk_width*.46,Color("#8d8578"),1.0)

func _initialize()->void:
	_run.call_deferred()

func _run()->void:
	DisplayServer.window_set_size(Vector2i(1280,825))
	root.content_scale_size=Vector2i(1280,825)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_VIEWPORT
	var layout:=LayoutCanvas.new()
	root.add_child(layout)
	for i in 8:await process_frame
	await RenderingServer.frame_post_draw
	var output=ProjectSettings.globalize_path(IMAGE_PATH)
	var error:=root.get_texture().get_image().save_png(IMAGE_PATH)
	var left_houses:=0
	for house: Dictionary in layout.houses:
		if bool(house["west"]):left_houses+=1
	print("FAVELA_V2_BLOCKOUT ",JSON.stringify({"saved":error,
		"path":output,"houses":layout.houses.size(),
		"left_houses":left_houses,
		"routes":TOPO.LINKS.size(),
		"west_gateway_links":TOPO.left_gate_links().size()}))
	layout.queue_free()
	quit(0 if error==OK and left_houses>=20 else 1)
