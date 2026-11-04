extends Node3D
var yaw:=0.
var pitch:=-.20
var target:=Vector3(0,1.2,0)
var distance:=7.
var current:=0
var pose_index:=0
const POSES:=["mira","inclinar","recarregar"]
const TARGETS:=[Vector3(-1,1.,0),Vector3(8,1.4,1),Vector3(-10,1.4,-8),Vector3(-15,3.,-11),Vector3(1,.8,-12),Vector3(-13,2.,10),Vector3(13,0.,12),Vector3(-10,0.,-30),Vector3(-20,0.,20),Vector3(28,1.,12),Vector3(-30,4.,-44),Vector3(-10,.6,-44),Vector3(10,1.,-44),Vector3(30,.3,-44),Vector3(-30,.4,36),Vector3(-10,.4,36),Vector3(10,.1,36),Vector3(30,0.,36)]
func _ready() -> void:
	get_viewport().msaa_3d=Viewport.MSAA_4X
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	var layer:=CanvasLayer.new();add_child(layer)
	var label:=Label.new();label.text="REFERÊNCIAS    ·    1–0 / TAB: objetos    ·    P: animação    ·    botão direito: olhar    ·    roda: distância"
	label.position=Vector2(20,20);label.add_theme_font_size_override("font_size",16);layer.add_child(label)
	update_camera()
	play_pose()
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode==KEY_ESCAPE: Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
		if event.keycode==KEY_P and not event.echo: pose_index=(pose_index+1)%POSES.size();play_pose()
		if event.keycode==KEY_TAB and not event.echo:
			current=(current+1)%TARGETS.size();target=TARGETS[current];distance=18 if current==10 else 10;update_camera()
		if event.keycode>=KEY_0 and event.keycode<=KEY_9:
			current=9 if event.keycode==KEY_0 else event.keycode-KEY_1;target=TARGETS[current];distance=24 if current in [7,8] else (12 if current==1 else 8);update_camera()
	if event is InputEventMouseButton:
		if event.button_index==MOUSE_BUTTON_RIGHT: Input.mouse_mode=Input.MOUSE_MODE_CAPTURED if event.pressed else Input.MOUSE_MODE_VISIBLE
		if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			distance=clampf(distance+(-.6 if event.button_index==MOUSE_BUTTON_WHEEL_UP else .6),1.2,45);update_camera()
	if event is InputEventMouseMotion and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED:
		yaw-=event.relative.x*.004;pitch=clampf(pitch-event.relative.y*.004,-1.2,1.2);update_camera()
func update_camera() -> void:
	var camera: Camera3D=$Camera
	camera.position=target+Basis.from_euler(Vector3(pitch,yaw,0))*Vector3.BACK*distance;camera.look_at(target)

func play_pose() -> void:
	for player: AnimationPlayer in find_children("Poses","AnimationPlayer",true,false):
		if player.has_animation(POSES[pose_index]): player.play(POSES[pose_index])
