extends SceneTree
const Grid=preload("res://tests/impact_navigation_grid.gd")
func _initialize() -> void:
	var grid=Grid.new();var a:=Vector2i(0,0);var b:=Vector2i(1,0);var c:=Vector2i(2,0)
	grid.set_terrain(c,true);grid.add_object("tree",[a,b,c,a]);grid.add_object("wall",[b])
	var changed: Array[Vector2i]=grid.remove_object("tree")
	var valid: bool=changed.size()==3 and not grid.blocked(a) and grid.blocked(b) and grid.blocked(c)
	grid.remove_object("wall");valid=valid and not grid.blocked(b) and grid.blocked(c)
	print(JSON.stringify({"ok":valid,"updated_cells":changed.size(),"terrain_preserved":grid.blocked(c)}))
	quit(0 if valid else 1)
