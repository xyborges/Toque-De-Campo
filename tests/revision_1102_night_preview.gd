extends "res://tests/afghan_territory_preview.gd"
func set_view(index: int) -> void:
	super.set_view(index)
	lights.apply_time((22.-BRAfghanAtmosphere.AFTERNOON_HOUR)*GameDayNight.PERIOD/24.,true)
