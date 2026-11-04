extends "res://tests/war_hud_fixture.gd"
var elimination_events: Array=[]
func war_elimination(event_id: String,friendly: bool) -> void:
	elimination_events.append([event_id,friendly])
	super.war_elimination(event_id,friendly)
