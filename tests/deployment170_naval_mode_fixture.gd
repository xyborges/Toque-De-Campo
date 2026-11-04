extends NavalMode
# Exercise the production central-server navigation against this test's local ENet server.
func _central_enabled() -> bool: return true
func _central_endpoint() -> String: return "127.0.0.1:39583"
