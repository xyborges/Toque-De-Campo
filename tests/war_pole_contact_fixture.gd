extends "res://tests/war_real_pole_fixture.gd"

# Overrides only the test fixture. The base game's WarPowerGrid and vehicle
# manager remain installed and unchanged.
var contact_adapter: RefCounted

func setup_contact_adapter() -> bool:
	if not init_pole_mirror(): return false
	contact_adapter=load("res://tests/war_pole_contact_adapter.gd").new()
	contact_adapter.game=self;contact_adapter.model=pole_model;contact_adapter.lookup=pole_lookup
	return true

func _apply_hit(owner_id: int,hit: Dictionary,damage: float,fallback_region:="chest",weapon:="ak",direction:=Vector3.ZERO) -> void:
	if contact_adapter and contact_adapter.enabled:
		var observation: Dictionary=contact_adapter.shot(hit,damage,direction)
		if bool(observation.get("handled",false)):
			if bool(observation.get("invalid",false)): pole_errors.append("contact outside isolated mirror or invalid")
			if not observation.event.is_empty(): pole_lab.present(observation.event)
			return
	super._apply_hit(owner_id,hit,damage,fallback_region,weapon,direction)
