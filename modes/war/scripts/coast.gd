extends RefCounted
class_name WarCoast
# One concave bay in the west; the east port is an open coastal terminal.
const SEA_LEVEL:=0.0
const PORTS:=[Vector3(-820,4,-430),Vector3(1190,4,470)]
const BERTHS:=[[Vector3(-1020,0,-485),Vector3(-1030,0,-385)],[Vector3(1350,0,440),Vector3(1350,0,550)]]
const BAY_CENTER:=Vector2(-1110,-430)
const BAY_RADIUS:=Vector2(275,245)
const BAY_CAPES:=[Vector2(-1350,-165),Vector2(-1360,-695)]
const BAY_LINKS:=[[Vector2(-1360,-705),Vector2(-1050,-740)],[Vector2(-1350,-165),Vector2(-1080,-145)]]
static func inland(x: float,z: float) -> float:
	var angle:=atan2(z,x)
	var edge:=(1-sqrt(pow(x/1370,2)+pow(z/1300,2)))*1250
	edge+=16*sin(angle*7)+10*cos(angle*11)
	# Two headlands frame a genuinely concave geographical bay. The open
	# mouth stays west; both berths keep a clear route to the surrounding sea.
	for centre: Vector2 in BAY_CAPES:
		var cape: Vector2=(Vector2(x,z)-centre)/Vector2(240,155)
		edge=maxf(edge,(1-cape.length())*155)
	for link: Array in BAY_LINKS:
		var nearest:=Geometry2D.get_closest_point_to_segment(Vector2(x,z),link[0],link[1])
		edge=maxf(edge,85-Vector2(x,z).distance_to(nearest))
	var bay:=(Vector2(x-BAY_CENTER.x,z-BAY_CENTER.y)/BAY_RADIUS).length()
	bay=(bay-1)*245
	return minf(edge,bay)

static func height(x: float,z: float,land: float) -> float:
	var d:=inland(x,z)
	return lerpf(-19.,maxf(4,land),smoothstep(-55,85,d))

static func wet(x: float,z: float) -> bool:
	return WarTerrain.height_at(x,z)<-.4

static func wave(point: Vector3,clock: float) -> float:
	var storm:=WarWeather.intensity(clock)
	return NavalCatalog.wave(point,clock)*(1+storm*2.2)
