#ifndef WAR_POSE_MATH_H
#define WAR_POSE_MATH_H
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>
#include <godot_cpp/variant/transform3d.hpp>
#include <godot_cpp/variant/vector3.hpp>
namespace godot {
class WarNativePoseMath final : public RefCounted {
    GDCLASS(WarNativePoseMath, RefCounted)
protected:
    static void _bind_methods();
public:
    Transform3D upper_transform(double pitch, double lean) const;
    Transform3D weapon_transform(double aim_pitch, double lean, double prone_weight,
                                 const Transform3D &body_root, const Vector3 &offset) const;
    Array upper_batch(const PackedFloat32Array &pitches, const PackedFloat32Array &leans) const;
    // One native crossing for N complete two-bone arm IK solutions. Each item
    // returns [arm, upper, lower, hand] Transform3D or [] for invalid reach.
    Array arm_batch_dicts(const Array &inputs) const;
    // Solve and apply the visual arms directly to existing Godot Node3D nodes.
    // Returns number of fully updated arms; GDScript can fall back on failure.
    int apply_arms_direct(const Array &inputs) const;
    // Calculate all bot separation forces with a single C++ call and compact
    // vector arrays. No physics world or Godot nodes are touched.
    PackedVector3Array separation_batch(const PackedVector3Array &positions) const;
    Array arm_batch(const PackedVector3Array &shoulders, const PackedVector3Array &grips,
                    const Array &hand_bases, const Array &upper_bases,
                    const PackedInt32Array &left_sides, const PackedFloat32Array &proportions,
                    const PackedVector3Array &cuffs) const;
};
}
#endif
