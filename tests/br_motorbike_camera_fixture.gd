extends "res://tests/br_completion_fixture.gd"

func gameplay_input_allowed() -> bool:
 # Headless has no captured pointer. Exercise the production look path as if
 # the match owns focus; this does not replace any camera or pose code.
 return phase=="active"
