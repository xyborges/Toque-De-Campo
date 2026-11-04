extends SceneTree
const BIOME=preload("res://modes/war/scripts/biome_map.gd")
var errors: Array[String]=[]

func check(value: bool,message: String) -> void:
	if not value: errors.append(message)

func _initialize() -> void:
	var map=BIOME.new()
	map.image=Image.create(350,350,false,Image.FORMAT_RGBA8)
	map.image.fill(BIOME.PALETTE[0]);map.image.set_pixel(175,175,BIOME.PALETTE[1])
	check(map.region(Vector2(5,5))==1,"burnt texel recognized")
	check(not map.footprint_field(Vector2(-.5,5),1.3),"footprint overlapping narrow burnt texel rejected")
	check(map.footprint_field(Vector2(-15,-15),1.3),"field accepted")
	check(not map.footprint_field(Vector2(1750,0),1.3),"out of bounds rejected")
	for i in 4:
		map.image.set_pixel(0,0,BIOME.PALETTE[i])
		check(map.region(Vector2(-1745,-1745))==i,"all palette colours classified")
	var component=load("res://modes/war/scripts/vegetation_visuals.gd").new()
	var world:=Node3D.new();root.add_child(world);world.add_child(component);component.initialize(world)
	if DisplayServer.get_name()=="headless":
		check(not component.available and not component.apply_level(3),"headless allocates no visual terrain or foliage")
		check(component.biome==null and component.ground==null and component.streamer==null,"headless visual resources remain absent")
	world.free()
	print(JSON.stringify({"ok":errors.is_empty(),"errors":errors}));quit(0 if errors.is_empty() else 1)
