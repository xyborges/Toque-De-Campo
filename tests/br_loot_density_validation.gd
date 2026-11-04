extends SceneTree
var failures: Array[String]=[]
var checks:=0
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func run() -> void:
	var table:=load("res://modes/battle_royale/state/default_loot.tres") as BRLootTable
	var points: Array[Vector3]=[]
	for z in 20:
		for x in 20:points.append(Vector3(x*10,0,z*10))
	var regions:={}
	for p in points:regions[p]="home" if int(p.x/10)%2==0 else "storage"
	var first:=table.generate(points,regions,712907)
	var second:=table.generate(points,regions,712907)
	check(var_to_bytes(first)==var_to_bytes(second),"same seed produces deterministic loot")
	check(first.size()>points.size(),"anchors can produce clustered additional loot")
	check(first.size()<=table.max_items,"loot respects configured maximum")
	var counts:={}
	var positions:={}
	for item: Dictionary in first:
		var kind:=str(item.get("kind",""));counts[kind]=int(counts.get(kind,0))+1
		if item.has("position"):
			var p: Vector3=item.position
			positions[Vector2i(roundi(p.x*10),roundi(p.z*10))]=true
	check(int(counts.get("weapon",0))>0,"weapons remain represented")
	check(int(counts.get("ammo",0))>0,"ammunition represented")
	check(int(counts.get("grenade",0))>0,"grenades represented")
	check(int(counts.get("heal",0))>0 and int(counts.get("pack",0))>0,"survival gear represented")
	check(positions.size()>points.size(),"cluster spacing creates distinct ground positions")
	print("BR_LOOT_DENSITY_VALIDATION ",JSON.stringify({"ok":failures.is_empty(),"checks":checks,"failures":failures,"items":first.size(),"counts":counts}))
	quit(0 if failures.is_empty() else 1)
