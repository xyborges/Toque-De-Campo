#ifndef WAR_POSE_MATH_H
#define WAR_POSE_MATH_H
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
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
};
}
#endif
