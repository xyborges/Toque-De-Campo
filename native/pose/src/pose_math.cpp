#include "pose_math.h"
#include <algorithm>
#include <cmath>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/basis.hpp>
using namespace godot;
namespace {
inline real_t clamp_real(real_t value, real_t lo, real_t hi) {
    return std::min(hi, std::max(lo, value));
}
inline real_t smoothstep(real_t edge0, real_t edge1, real_t value) {
    real_t t = clamp_real((value - edge0) / (edge1 - edge0), real_t(0), real_t(1));
    return t * t * (real_t(3) - real_t(2) * t);
}
}
void WarNativePoseMath::_bind_methods() {
    ClassDB::bind_method(D_METHOD("upper_transform", "pitch", "lean"), &WarNativePoseMath::upper_transform);
    ClassDB::bind_method(D_METHOD("weapon_transform", "aim_pitch", "lean", "prone_weight", "body_root", "offset"), &WarNativePoseMath::weapon_transform);
    ClassDB::bind_method(D_METHOD("upper_batch", "pitches", "leans"), &WarNativePoseMath::upper_batch);
}
Transform3D WarNativePoseMath::upper_transform(double pitch, double lean) const {
    const real_t bend = clamp_real(real_t(pitch) * real_t(0.42), real_t(-0.49), real_t(0.49));
    const Basis basis = Basis(Vector3(0, 0, 1), real_t(-lean) * real_t(0.18))
                      * Basis(Vector3(1, 0, 0), bend);
    const Vector3 waist(0, real_t(0.87), 0);
    return Transform3D(basis, waist + Vector3(real_t(lean) * real_t(0.04), 0, 0) - basis.xform(waist));
}
Transform3D WarNativePoseMath::weapon_transform(double aim_pitch, double lean, double prone_weight,
                                                  const Transform3D &body_root, const Vector3 &offset) const {
    const real_t pitch = real_t(aim_pitch);
    const real_t l = real_t(lean);
    const Basis aim = Basis(Vector3(1, 0, 0), pitch)
                    * Basis(Vector3(0, 0, 1), -l * real_t(0.18));
    const Transform3D upper = upper_transform(pitch, l);
    Vector3 shoulder = upper.xform(Vector3(0, real_t(1.42), 0));
    const real_t weight = clamp_real(real_t(prone_weight), real_t(0), real_t(1));
    shoulder = shoulder.lerp(Vector3(l * real_t(0.04), real_t(0.13), real_t(-0.64)), weight);
    const real_t clearance = (real_t(0.10) + real_t(0.07) * std::abs(l))
                           * smoothstep(real_t(0.4), real_t(1.3), -pitch);
    shoulder += upper.basis.xform(Vector3(0, 0, -clearance));
    return body_root * Transform3D(aim, shoulder + aim.xform(offset));
}
Array WarNativePoseMath::upper_batch(const PackedFloat32Array &pitches,
                                      const PackedFloat32Array &leans) const {
    const int count = std::min(pitches.size(), leans.size());
    Array transforms;
    transforms.resize(count);
    for (int i = 0; i < count; ++i) transforms[i] = upper_transform(pitches[i], leans[i]);
    return transforms;
}
