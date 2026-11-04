extends RefCounted
class_name GameAttachmentIcons
static var cache: Dictionary={}
static func texture(category: String) -> Texture2D:
	category=str({"muzzle_device":"muzzle","flashlight":"side","laser":"side","grip":"underbarrel"}.get(category,category))
	if cache.has(category):return cache[category]
	var shapes: Dictionary={
		"optic":"<path d='M8 20h28v10H8zM14 30v5m16-5v5M5 18v14m34-14v14'/><circle cx='22' cy='25' r='5'/>",
		"muzzle":"<path d='M6 21h9v9H6m9-12h21v15H15zM21 19v13m8-13v13'/>",
		"magazine":"<path d='M15 8h16v15l-6 16H11l5-16zM20 13h6m-7 6h6m-7 6h6m-8 6h6'/>",
		"stock":"<path d='M8 15h8l9 8h12v8H22l-6 6H8z'/>",
		"side":"<path d='M10 19h24v13H10zM34 21l6-4v17l-6-4M15 19v-5h13v5'/>",
		"underbarrel":"<path d='M10 10h25v7H10zM19 17l-4 21h12l4-21'/>",
		"adapter":"<path d='M8 11h13v8h15v14H23v-8H8z'/>",
		"attachment":"<path d='M14 8h16v9h9v16H30v9H14v-9H5V17h9z'/>"}
	var svg: String="<svg xmlns='http://www.w3.org/2000/svg' width='48' height='48' viewBox='0 0 48 48'><g fill='none' stroke='#dce5dc' stroke-width='2' stroke-linejoin='round' stroke-linecap='round'>"+str(shapes.get(category,shapes.attachment))+"</g></svg>"
	var image:=Image.new();image.load_svg_from_string(svg);cache[category]=ImageTexture.create_from_image(image)
	return cache[category]
