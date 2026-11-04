extends RefCounted
class_name GameAttachmentBehaviors

# Factories receive independent state/context. A future light, folding stock
# or laser registers one component here; mounting and inventory stay generic.
static var factories: Dictionary={}
static func register_factory(kind: String,factory: Callable) -> bool:
	if kind.is_empty() or not factory.is_valid():return false
	factories[kind]=factory;return true
static func unregister_factory(kind: String) -> void:factories.erase(kind)
static func create(kind: String,context: Dictionary) -> Object:
	var factory: Callable=factories.get(kind,Callable())
	return factory.call(context.duplicate(true)) if factory.is_valid() else null
static func release(component: Object) -> void:
	if not is_instance_valid(component):return
	if component.has_method("dispose"):component.call("dispose")
	if component is Node:component.queue_free()

class Optical extends RefCounted:
	var context: Dictionary
	var state: Dictionary={}
	func _init(value: Dictionary) -> void:context=value;state=Dictionary(value.get("state",{})).duplicate(true)
	func set_state(value: Dictionary) -> void:state=value.duplicate(true)
	func dispose() -> void:context.clear();state.clear()

static func ensure_defaults() -> void:
	if not factories.has("optical"):register_factory("optical",func(context: Dictionary):return Optical.new(context))
