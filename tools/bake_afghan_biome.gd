extends SceneTree
const LAND=preload("res://modes/battle_royale/map/afghan_landform.gd")
const TARGET:="res://modes/battle_royale/map/afghan_biomes.png"
func _initialize() -> void:
	# Authored mask: after creation users can paint it without regeneration.
	if FileAccess.file_exists(TARGET) and not "--replace-biome" in OS.get_cmdline_user_args(): print("AFGHAN_BIOME_PRESERVED");quit();return
	var image:=Image.create(128,128,false,Image.FORMAT_RGBA8)
	var settlements:=LAND.village_centres()
	for y in 128:
		for x in 128:
			var p:=Vector2((x+.5)/128.*2000.-1000.,(y+.5)/128.*2000.-1000.)
			var village:=0.
			for c: Vector3 in settlements: village=maxf(village,1.-smoothstep(35.,160.,p.distance_to(Vector2(c.x,c.z))))
			var wet:=1.-smoothstep(10.,70.,absf(p.x-LAND.stream_center(p.y)))
			var dry:=1.-smoothstep(5.,38.,absf(p.y-(110.+67.*sin(p.x*.0025)+26.*sin(p.x*.0065))))
			var road: Dictionary=LAND._near_road(p)
			var track:=1.-smoothstep(float(road.width)*.5+1.,float(road.width)*.5+8.,float(road.distance))
			image.set_pixel(x,y,Color(village,wet,dry,track))
	image.save_png(TARGET);print("AFGHAN_BIOME_BAKED ",TARGET);quit()
