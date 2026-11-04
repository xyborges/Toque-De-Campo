extends RigidBody3D

# Corpse physics has no reason to accumulate a solver launch from a wall
# contact. Bounds apply only to passive bodies, never to living movement.
func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	state.linear_velocity=state.linear_velocity.limit_length(10.0)
	state.angular_velocity=state.angular_velocity.limit_length(8.0)
