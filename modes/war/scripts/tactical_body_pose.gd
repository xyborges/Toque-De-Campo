extends RefCounted
class_name WarTacticalBodyPose

# R2A: pure pose intent, not an authoritative pose solver.
# These functions never read/modify the scene tree or allocate a per-actor
# object. Do not apply hip/torso targets to avatar_parts while CollisionRig
# P1 performance/equivalence is still blocked: hit regions are descendants
# of the same physical pivots and remote animation uses visual LOD.
#
# The first safe consumer (R2B) is the local FPP view copy only. It must not
# drive the real weapon, muzzle, server collision, CharacterBody or camera.
const HIP_STRAFE_TRAVEL := 0.014
const HIP_LANDING_DIP := 0.012
const HIP_LONGITUDINAL_TRAVEL := 0.006
const HIP_LONGITUDINAL_PITCH := 0.012
const HIP_LATERAL_YAW := 0.012
const HIP_LATERAL_ROLL := 0.016
const TORSO_LONGITUDINAL_PITCH := 0.022
const TORSO_LANDING_PITCH := 0.032
const TORSO_LATERAL_YAW := 0.010
const TORSO_LATERAL_ROLL := 0.028
const FPP_WEAPON_LONGITUDINAL_PITCH := 0.010
const FPP_WEAPON_LANDING_PITCH := 0.018
const FPP_WEAPON_LATERAL_YAW := 0.007
const FPP_WEAPON_LATERAL_ROLL := 0.020

static func _signed_weight(value: float) -> float:
	return clampf(value,-1.,1.) if is_finite(value) else 0.

static func _impact_weight(value: float) -> float:
	return clampf(value,0.,1.) if is_finite(value) else 0.

# Intended local, non-authoritative offset for a future visual-only hip
# adapter. The regular pelvis node also owns hit regions: never set it from
# this function until an independent collider-safe adapter passes QA.
static func hip_offset(longitudinal: float,lateral: float,landing: float) -> Vector3:
	var forward:=_signed_weight(longitudinal)
	var side:=_signed_weight(lateral)
	var impact:=_impact_weight(landing)
	return Vector3(side*HIP_STRAFE_TRAVEL,-impact*HIP_LANDING_DIP,-forward*HIP_LONGITUDINAL_TRAVEL)

static func hip_angles(longitudinal: float,lateral: float) -> Vector3:
	var forward:=_signed_weight(longitudinal)
	var side:=_signed_weight(lateral)
	return Vector3(-forward*HIP_LONGITUDINAL_PITCH,side*HIP_LATERAL_YAW,side*HIP_LATERAL_ROLL)

static func torso_angles(longitudinal: float,lateral: float,landing: float) -> Vector3:
	var forward:=_signed_weight(longitudinal)
	var side:=_signed_weight(lateral)
	var impact:=_impact_weight(landing)
	return Vector3(forward*TORSO_LONGITUDINAL_PITCH+impact*TORSO_LANDING_PITCH,-side*TORSO_LATERAL_YAW,-side*TORSO_LATERAL_ROLL)

# R2B: restrained additive rotation on the first-person presentation only.
# No time state here. The R1 weights already filter acceleration, sideways
# change and landing; a second filter would desync the visual action clock.
static func fpp_weapon_angles(longitudinal: float,lateral: float,landing: float) -> Vector3:
	var forward:=_signed_weight(longitudinal)
	var side:=_signed_weight(lateral)
	var impact:=_impact_weight(landing)
	return Vector3(forward*FPP_WEAPON_LONGITUDINAL_PITCH+impact*FPP_WEAPON_LANDING_PITCH,-side*FPP_WEAPON_LATERAL_YAW,-side*FPP_WEAPON_LATERAL_ROLL)
