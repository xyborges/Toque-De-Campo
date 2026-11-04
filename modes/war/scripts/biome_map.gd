extends RefCounted

# Pure visual data: never used for terrain height, hit tests or navigation.
const PATH:="res://assets/war/biomes/nova_grama.png"
const HALF:=1750.0
const PALETTE:=[Color8(48,150,54),Color8(108,65,50),Color8(178,151,80),Color8(174,165,145)]
var image: Image
var texture: ImageTexture

func load_map() -> bool:
	if image!=null and not image.is_empty(): return true
	if not ResourceLoader.exists(PATH): return false
	var source:=load(PATH) as Texture2D
	if source==null: return false
	image=source.get_image()
	if image==null or image.is_empty(): image=null;return false
	if image.is_compressed() and image.decompress()!=OK: image=null;return false
	image.convert(Image.FORMAT_RGBA8)
	return true

func colour_at(point: Vector2) -> Color:
	if image==null or image.is_empty() or not point.is_finite(): return Color.TRANSPARENT
	var x:=clampi(floori((point.x+HALF)/(2.*HALF)*image.get_width()),0,image.get_width()-1)
	var z:=clampi(floori((point.y+HALF)/(2.*HALF)*image.get_height()),0,image.get_height()-1)
	return image.get_pixel(x,z)

func region(point: Vector2) -> int:
	if image==null or image.is_empty() or not point.is_finite(): return -1
	var c:=colour_at(point);var smallest:=INF;var result:=0
	for i in PALETTE.size():
		var p: Color=PALETTE[i]
		var difference:=Vector3(c.r-p.r,c.g-p.g,c.b-p.b).length_squared()
		if difference<smallest: smallest=difference;result=i
	return result

func all_field(point: Vector2,radius: float) -> bool:
	# Use the same exact texel footprint for all callers, rather than just
	# checking five points and potentially missing a painted burnt stripe.
	return footprint_field(point,radius)

func footprint_field(point: Vector2,radius: float) -> bool:
	if image==null or image.is_empty() or not point.is_finite() or not is_finite(radius) or radius<0.: return false
	var first:=point-Vector2.ONE*radius;var last:=point+Vector2.ONE*radius
	if first.x< -HALF or first.y< -HALF or last.x>HALF or last.y>HALF: return false
	var size:=Vector2(image.get_width(),image.get_height())
	var lo: Vector2=(first+Vector2.ONE*HALF)/(2.*HALF)*size
	var hi: Vector2=(last+Vector2.ONE*HALF)/(2.*HALF)*size
	for x in range(clampi(floori(lo.x),0,image.get_width()-1),clampi(floori(hi.x),0,image.get_width()-1)+1):
		for z in range(clampi(floori(lo.y),0,image.get_height()-1),clampi(floori(hi.y),0,image.get_height()-1)+1):
			var centre:=(Vector2(x+.5,z+.5)/size)*(2.*HALF)-Vector2.ONE*HALF
			if region(centre)!=0: return false
	return true

func get_texture() -> Texture2D:
	if (image==null or image.is_empty()) and not load_map(): return null
	if texture==null: texture=ImageTexture.create_from_image(image)
	return texture
