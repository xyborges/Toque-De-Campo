extends RefCounted
class_name WarOutskirts
const VILLAGES:=[Vector2(-610,610),Vector2(610,-610),Vector2(-480,-790),Vector2(600,800)]
static func build(k: EnvironmentKit) -> void:
	var rng:=RandomNumberGenerator.new();rng.seed=1722510
	for centre in VILLAGES:
		for index in 8:
			var p: Vector2=centre+Vector2((index%4)*39-58,(index/4)*65-32)
			if WarTerrainEdits.replaces_lot(p): continue
			if WarTerrain.height_at(p.x,p.y)<5: continue
			# Deep individual foundations touch the sampled sloping ground.
			var at:=WarTerrain.point(p.x,p.y)
			WarHarbors.foundation(k,at+Vector3(0,-.2,0),Vector3(12.5,.5,9.5),"VillageFooting")
			WarStructures.house(k,p,index%3!=0)
			WarStructures.fence(k,p+Vector2(-12,10),p+Vector2(12,10))
			for piece in 6:
				var debris:=WarTerrain.point(p.x+rng.randf_range(-15,15),p.y+rng.randf_range(-13,13))
				k.box("BrokenMasonry",debris+Vector3.UP*.2,Vector3(.9,.4,.5),"brick:6b6258",piece<2,Vector3(.1,rng.randf()*TAU,.18),true)
		for index in 5:
			var at:=WarTerrain.point(centre.x+index*9-20,centre.y+78)
			k.cylinder("ScorchedUtilityPole",at+Vector3.UP*4,.14,8,"wood:343b34",true)
	for index in 110:
		var p:=WarTerrain.point(rng.randf_range(-1200,1200),rng.randf_range(-1100,1100))
		if p.y<4 or not WarVegetation.clear_site(Vector2(p.x,p.z)): continue
		k.rock(p+Vector3.UP*.4,Vector3(2,.8,1.3)*rng.randf_range(.6,1.5),index,true)
		if index%9==0:
			EnvironmentProps.truck(k,p)
			k.box("WreckedTruckCab",p+Vector3(0,1,1),Vector3(1.8,1.6,1.4),"steel:383d37",true,Vector3(.12,.25,.1))
	k.root.set_meta("war_outer_villages",VILLAGES.size())

