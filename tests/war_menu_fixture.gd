extends "res://tests/late_join_fixture.gd"

var war_launches: Array[bool]=[]

func open_war(offline: bool=false, operation: String=WarOperation.UKRAINE) -> void:
	war_launches.append(offline)
