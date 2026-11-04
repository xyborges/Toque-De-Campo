extends RefCounted
class_name WarCityLife
static func build(k: EnvironmentKit) -> void:
	for index in WarUrbanLayout.CENTRES.size():
		var centre: Vector2=WarUrbanLayout.CENTRES[index]
		var previous:=Vector3.ZERO
		for pole in 7:
			var verge:=WarRoads.roadside(centre+Vector2(-78+pole*26,8))
			var p:=WarTerrain.point(verge.x,verge.y)
			var top:=p+Vector3(.4 if pole%5==0 else 0,6.5,0)
			k.beam(p,top,.15,.15,"wood:615d50",true)
			k.box("PowerCrossarm",top,Vector3(1.6,.12,.12),"steel:555e57")
			k.box("FibreSpliceClosure",p+Vector3(.15,3.5,0),Vector3(.16,.5,.14),"steel:353b35",false,Vector3.ZERO,true)
			if pole%3==0: k.box("TelecomDistribution",p+Vector3(.15,2.7,0),Vector3(.35,.48,.18),"steel:666c61",false,Vector3.ZERO,true)
			if previous!=Vector3.ZERO:
				var midpoint: Vector3=(previous+top)*.5-Vector3.UP*.6
				for dz in [-.45,.45]:
					k.beam(previous+Vector3(0,0,dz),midpoint+Vector3(0,0,dz),.025,.025,"steel:313933",false)
					k.beam(midpoint+Vector3(0,0,dz),top+Vector3(0,0,dz),.025,.025,"steel:313933",false)
				if pole==4 and index%3==0: k.beam(p+Vector3(0,3.3,0),p+Vector3(2,.08,3),.025,.025,"steel:313933",false)
			previous=top
		var stop:=WarTerrain.point(centre.x-8,centre.y+9)
		EnvironmentProps.canopy(k,stop,Vector2(5,2),2.6)
		k.box("BusStopBench",stop+Vector3.UP*.55,Vector3(3.5,.13,.5),"wood:726c59",true)
		k.sign_text("ЗУПИНКА",stop+Vector3(0,2.1,.8),2.8)
		for plot in 6:
			var p2:=centre+Vector2((plot%3)*42-42,(plot/3)*58-29)
			var p:=WarTerrain.point(p2.x,p2.y)
			var towards: float=1 if plot<3 else -1
			# Small walled yards, a gate facing the street, and a side alley.
			var fence_z:=p.z+towards*14
			for side in [-1.,1.]:
				var a:=WarTerrain.point(p.x+side*4,fence_z);var b:=WarTerrain.point(p.x+side*15,fence_z)
				k.wall("GardenWall",a,b,.65,"brick:80786b")
				k.cylinder("GatePost",a+Vector3.UP*.55,.07,1.1,"steel:4c5a50",true)
			var garden:=WarTerrain.point(p.x+14,p.z)
			WarVegetation.tree(k,garden,.55,plot%3==0 or index%4==0)
			if plot%2==0:
				k.crate(p+Vector3(8,.3,0));EnvironmentProps.drum(k,p+Vector3(9,0,1.5))
				k.chair(p+Vector3(8,.3,3),.4)
			if index in [0,1] and plot in [1,4]:
				k.sign_text("МАРКЕТ" if plot==1 else "АПТЕКА",p+Vector3(0,2,towards*8.65),4)
				k.desk(p+Vector3(-5,.4,3),0,false)
			elif plot%3==0:
				var at:=WarTerrain.point(p.x-15,p.z+4)
				k.box("GardenShed",at+Vector3.UP*1.15,Vector3(3.5,2.3,3),"wood:78715d",true)
				k.box("ShedRoof",at+Vector3.UP*2.4,Vector3(4,.17,3.6),"steel:73756a",true,Vector3(.1,0,0))
			if plot==3: k.box("TelecomCabinet",WarTerrain.point(p.x-18,fence_z)+Vector3.UP*.65,Vector3(.65,1.3,.45),"steel:798177",true)
	for team in 2:
		var port: Vector3=WarCoast.PORTS[team];var direction:=1. if team==0 else -1.
		var industrial:=WarTerrain.point(port.x+direction*65,port.z+95)
		WarHarbors.warehouse(k,industrial,team==0)
		for index in 3:
			var at:=WarTerrain.point(industrial.x+direction*(18+index*7),industrial.z)
			k.cylinder("IndustrialStorageTank",at+Vector3.UP*3.5,2.3,7,"steel:747c74",true)
			k.beam(at+Vector3.UP,at+Vector3(direction*6,1,0),.35,.35,"steel:4c5c55")
		var truck:=WarTerrain.point(industrial.x,industrial.z-24);EnvironmentProps.truck(k,truck)
		for index in 6: k.pallet(WarTerrain.point(industrial.x+index*2-5,industrial.z-14))
		for index in 7: EnvironmentProps.drum(k,WarTerrain.point(industrial.x+18,industrial.z+index*2-5),index%2==0)
		k.sign_text("ЛОГІСТИКА",industrial+Vector3.UP*6,7)
	k.root.set_meta("war_city_quarters",WarUrbanLayout.CENTRES.size())
