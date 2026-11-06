extends Control

var own_team:=-1
var tickets:=[0,0]
var states: Dictionary={}
var seconds:=0

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	custom_minimum_size=Vector2(500,82) if WarFavelaFrontline.enabled(WarRules.CURRENT_OPERATION) else Vector2(500,54)

func update_state(team: int,scores: Array,objectives: Dictionary,time_left: int) -> void:
	var changed:=team!=own_team or scores!=tickets or objectives!=states or time_left!=seconds
	if not changed: return
	own_team=team;tickets=scores.duplicate();states=objectives.duplicate(true);seconds=time_left;queue_redraw()

func _draw() -> void:
	var font:=get_theme_default_font()
	var width:=size.x;var scale:=minf(1.,width/500.)
	var center:=width*.5
	var frontline:=WarFavelaFrontline.enabled(WarRules.CURRENT_OPERATION)
	var offsets:=[-160.,-80.,0.,80.,160.] if frontline else [-218.,-174.,130.,174.,218.]
	var ids:=["A","B","C","D","E"]
	for i in ids.size():
		var state: Dictionary=states.get(ids[i],{})
		var owner:=int(state.get("owner",-1))
		var active:=WarFavelaFrontline.enabled(WarRules.CURRENT_OPERATION) and WarFavelaFrontline.can_capture(states,ids[i])
		var tint:=FieldTheme.INK if active else (FieldTheme.MUTED if owner<0 or own_team<0 else (FieldTheme.ACCENT if owner==own_team else FieldTheme.BAD))
		var at:=Vector2(center+float(offsets[i])*scale,20 if frontline else 27)
		draw_circle(at,14.,Color(.035,.065,.065,.7))
		draw_arc(at,14.,0,TAU,32,tint,4.5 if active else 2.5,true)
		if active:draw_arc(at,18.,0,TAU,32,FieldTheme.ACCENT,1.8,true)
		if bool(state.get("contested",false)): draw_arc(at,10.,0,TAU,24,FieldTheme.INK,1.,true)
		draw_string(font,at+Vector2(-13,5),ids[i],HORIZONTAL_ALIGNMENT_CENTER,26,15,FieldTheme.INK)
	var own:=int(tickets[own_team]) if own_team in [0,1] else 0
	var enemy:=int(tickets[1-own_team]) if own_team in [0,1] else 0
	if frontline:
		var front_id: String=WarFavelaFrontline.active_id(states)
		var front_name: String=str(WarRules.OBJECTIVES.get(front_id,{}).get("name",""))
		draw_string(font,Vector2(center-185,48),"ALVO ATUAL: "+front_id+" - "+front_name,
			HORIZONTAL_ALIGNMENT_CENTER,370,13,FieldTheme.ACCENT)
	var label:="%d   %02d:%02d   %d"%[own,seconds/60,seconds%60,enemy]
	draw_string(font,Vector2(center-112,70 if frontline else 33),label,HORIZONTAL_ALIGNMENT_CENTER,224,18,FieldTheme.INK)
