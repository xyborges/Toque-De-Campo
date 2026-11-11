#include "pose_math.h"
#include <algorithm>
#include <cmath>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/basis.hpp>
#include <godot_cpp/variant/quaternion.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/classes/node3d.hpp>
#include <godot_cpp/classes/object.hpp>
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
    ClassDB::bind_method(D_METHOD("arm_batch", "shoulders", "grips", "hand_bases", "upper_bases", "left_sides", "proportions", "cuffs"), &WarNativePoseMath::arm_batch);
    ClassDB::bind_method(D_METHOD("arm_batch_dicts", "inputs"), &WarNativePoseMath::arm_batch_dicts);
    ClassDB::bind_method(D_METHOD("apply_arms_direct", "inputs"), &WarNativePoseMath::apply_arms_direct);
    ClassDB::bind_method(D_METHOD("apply_upper_direct", "parts", "pelvis", "rest", "pitch", "lean", "torso_scale", "head_scale", "articulated"), &WarNativePoseMath::apply_upper_direct);
    ClassDB::bind_method(D_METHOD("separation_batch", "positions"), &WarNativePoseMath::separation_batch);
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

Array WarNativePoseMath::arm_batch(const PackedVector3Array &shoulders,
                                    const PackedVector3Array &grips,
                                    const Array &hand_bases, const Array &upper_bases,
                                    const PackedInt32Array &left_sides,
                                    const PackedFloat32Array &proportions,
                                    const PackedVector3Array &cuffs) const {
    const int count = std::min({shoulders.size(), grips.size(), hand_bases.size(),
                                upper_bases.size(), left_sides.size(),
                                proportions.size(), cuffs.size()});
    Array out;
    out.resize(count);
    constexpr real_t UPPER = real_t(0.37);
    constexpr real_t LOWER = real_t(0.35);
    for (int i = 0; i < count; ++i) {
        const Vector3 shoulder = shoulders[i];
        const Vector3 grip = grips[i];
        const Basis hand_basis = hand_bases[i];
        const Basis upper_basis = upper_bases[i];
        const real_t proportion = proportions[i];
        const Vector3 wrist = grip + hand_basis.xform(cuffs[i]);
        const Vector3 direction = wrist - shoulder;
        const real_t distance = direction.length();
        if (distance < real_t(0.01)) {
            out[i] = Array();
            continue;
        }
        real_t a = UPPER * proportion;
        real_t b = LOWER * proportion;
        const real_t stretch = std::max(real_t(1.0), distance / (a + b - real_t(0.003)));
        a *= stretch;
        b *= stretch;
        const Vector3 along = direction / distance;
        const Vector3 pole = upper_basis.xform(Vector3(left_sides[i] != 0 ? real_t(-0.75) : real_t(0.75),
                                                      real_t(-0.70), real_t(-0.25)));
        const Vector3 perpendicular = (pole - along * pole.dot(along)).normalized();
        const real_t projection = clamp_real((a * a - b * b + distance * distance) / (real_t(2) * distance), real_t(0), a);
        const Vector3 elbow = shoulder + along * projection
                            + perpendicular * std::sqrt(std::max(real_t(0), a * a - projection * projection));
        const Transform3D arm(Basis(Quaternion(Vector3(0, -1, 0), (elbow - shoulder).normalized())), shoulder);
        const Transform3D inverse = arm.affine_inverse();
        const Vector3 elbow_local = inverse.xform(elbow);
        const Vector3 wrist_local = inverse.xform(wrist);
        const Transform3D upper(Basis::from_scale(Vector3(proportion, a / UPPER, proportion)), Vector3(0, -a * real_t(0.5), 0));
        const Transform3D lower(Basis(Quaternion(Vector3(0, -1, 0), (wrist_local - elbow_local).normalized()))
                                * Basis::from_scale(Vector3(proportion, b / LOWER, proportion)),
                                (elbow_local + wrist_local) * real_t(0.5));
        const Transform3D hand(inverse.basis * hand_basis * Basis::from_scale(Vector3(proportion, proportion, proportion)),
                               inverse.xform(grip));
        Array solved;
        solved.resize(4);
        solved[0] = arm;
        solved[1] = upper;
        solved[2] = lower;
        solved[3] = hand;
        out[i] = solved;
    }
    return out;
}

Array WarNativePoseMath::arm_batch_dicts(const Array &inputs) const {
    // Input dictionaries were already assembled by WarHumanRig. Reuse them
    // directly instead of allocating 7 separate packed arrays in GDScript
    // for every pair of arms, which benchmarked slower than GDScript.
    PackedVector3Array shoulders, grips, cuffs;
    PackedInt32Array left_sides;
    PackedFloat32Array proportions;
    Array hand_bases, upper_bases;
    const int n = inputs.size();
    shoulders.resize(n); grips.resize(n); cuffs.resize(n);
    left_sides.resize(n); proportions.resize(n);
    hand_bases.resize(n); upper_bases.resize(n);
    for (int i = 0; i < n; ++i) {
        const Dictionary data = inputs[i];
        shoulders.set(i, data["shoulder"]);
        grips.set(i, data["grip"]);
        cuffs.set(i, data["cuff"]);
        hand_bases[i] = data["hand_basis"];
        upper_bases[i] = data["upper_basis"];
        const String side = data["side"];
        left_sides.set(i, side == "L" ? 1 : 0);
        const real_t proportion = data["proportion"];
        proportions.set(i, proportion);
    }
    return arm_batch(shoulders, grips, hand_bases, upper_bases, left_sides, proportions, cuffs);
}

int WarNativePoseMath::apply_arms_direct(const Array &inputs) const {
    // Pose math and scene application both happen in C++. No transform
    // arrays or result matrices cross back to GDScript.
    constexpr real_t UPPER = real_t(0.37);
    constexpr real_t LOWER = real_t(0.35);
    int applied = 0;
    for (int i = 0; i < inputs.size(); ++i) {
        const Dictionary data = inputs[i];
        Object *arm_object = data["arm"];
        Object *upper_object = data["upper"];
        Object *lower_object = data["lower"];
        Object *hand_object = data["hand"];
        Node3D *arm_node = Object::cast_to<Node3D>(arm_object);
        Node3D *upper_node = Object::cast_to<Node3D>(upper_object);
        Node3D *lower_node = Object::cast_to<Node3D>(lower_object);
        Node3D *hand_node = Object::cast_to<Node3D>(hand_object);
        if (!arm_node || !upper_node || !lower_node || !hand_node) {
            continue;
        }
        const Vector3 shoulder = data["shoulder"];
        const Vector3 grip = data["grip"];
        const Basis hand_basis = data["hand_basis"];
        const Basis upper_basis = data["upper_basis"];
        const Vector3 cuff = data["cuff"];
        const real_t proportion = data["proportion"];
        const String side = data["side"];
        const Vector3 wrist = grip + hand_basis.xform(cuff);
        const Vector3 direction = wrist - shoulder;
        const real_t distance = direction.length();
        if (distance < real_t(0.01)) {
            continue;
        }
        real_t a = UPPER * proportion;
        real_t b = LOWER * proportion;
        const real_t stretch = std::max(real_t(1), distance / (a + b - real_t(0.003)));
        a *= stretch; b *= stretch;
        const Vector3 along = direction / distance;
        const Vector3 pole = upper_basis.xform(Vector3(side == "L" ? real_t(-0.75) : real_t(0.75), real_t(-0.70), real_t(-0.25)));
        const Vector3 perpendicular = (pole - along * pole.dot(along)).normalized();
        const real_t projection = clamp_real((a * a - b * b + distance * distance) / (real_t(2) * distance), real_t(0), a);
        const Vector3 elbow = shoulder + along * projection
                            + perpendicular * std::sqrt(std::max(real_t(0), a * a - projection * projection));
        const Transform3D arm_pose(Basis(Quaternion(Vector3(0, -1, 0), (elbow - shoulder).normalized())), shoulder);
        const Transform3D inverse = arm_pose.affine_inverse();
        const Vector3 elbow_local = inverse.xform(elbow);
        const Vector3 wrist_local = inverse.xform(wrist);
        const Transform3D lower_pose(Basis(Quaternion(Vector3(0, -1, 0), (wrist_local - elbow_local).normalized()))
            * Basis::from_scale(Vector3(proportion, b / LOWER, proportion)), (elbow_local + wrist_local) * real_t(0.5));
        const Transform3D hand_pose(inverse.basis * hand_basis * Basis::from_scale(Vector3(proportion, proportion, proportion)), inverse.xform(grip));

        // Mirrors WarHumanRig._apply_arm; arm's rest origin is already
        // managed by stance/torso and MUST NOT be moved here.
        arm_node->set_basis(arm_pose.basis);
        upper_node->set_position(Vector3(0, -a * real_t(0.5), 0));
        upper_node->set_scale(Vector3(proportion, a / UPPER, proportion));
        lower_node->set_transform(lower_pose);
        hand_node->set_transform(hand_pose);
        ++applied;
    }
    return applied;
}

PackedVector3Array WarNativePoseMath::separation_batch(
    const PackedVector3Array &positions) const {
    const int count = positions.size();
    PackedVector3Array out;
    out.resize(count);
    constexpr real_t radius = real_t(1.1);
    constexpr real_t radius_sq = radius * radius;
    constexpr real_t minimum_sq = real_t(0.01) * real_t(0.01);
    for (int i = 0; i < count; ++i) {
        const Vector3 centre = positions[i];
        Vector3 total;
        for (int j = 0; j < count; ++j) {
            if (i == j) continue;
            const Vector3 other = positions[j];
            const real_t dx = centre.x - other.x;
            const real_t dz = centre.z - other.z;
            const real_t d_sq = dx * dx + dz * dz;
            if (d_sq <= minimum_sq || d_sq >= radius_sq) continue;
            const real_t distance = std::sqrt(d_sq);
            const real_t factor = (radius - distance) / distance;
            total.x += dx * factor;
            total.z += dz * factor;
        }
        out.set(i, total);
    }
    return out;
}

bool WarNativePoseMath::apply_upper_direct(const Dictionary &parts, Node3D *pelvis,
        const Dictionary &rest, double pitch, double lean, double torso_scale,
        double head_scale, bool articulated) const {
    // Resolve all nodes before mutating any of them; a partially imported
    // rig must fall back to the reference GDScript path, not half-pose.
    if (!pelvis) return false;
    if (!parts.has("torso") || !parts.has("head") || !parts.has("arm_l") ||
        !parts.has("arm_r") || !parts.has("leg_l") || !parts.has("leg_r")) return false;
    if (!rest.has("torso") || !rest.has("head") || !rest.has("left") ||
        !rest.has("right") || !rest.has("pelvis") || !rest.has("leg_l") ||
        !rest.has("leg_r")) return false;

    const auto node = [&parts](const char *key) -> Node3D * {
        Object *object = parts[key];
        return Object::cast_to<Node3D>(object);
    };
    Node3D *torso = node("torso");
    Node3D *head = node("head");
    Node3D *arm_l = node("arm_l");
    Node3D *arm_r = node("arm_r");
    Node3D *leg_l = node("leg_l");
    Node3D *leg_r = node("leg_r");
    if (!torso || !head || !arm_l || !arm_r || !leg_l || !leg_r) return false;

    const real_t l = real_t(lean);
    const real_t p = real_t(pitch);
    const real_t ts = clamp_real(real_t(torso_scale), real_t(0.65), real_t(1.5));
    const real_t hs = clamp_real(real_t(head_scale), real_t(0.65), real_t(1.5));
    const Transform3D upper = upper_transform(p, l);
    const real_t hip_shift = l * real_t(0.04);
    const Vector3 hip_offset(hip_shift, 0, 0);

    pelvis->set_position(Vector3(rest["pelvis"]) + hip_offset);
    Vector3 pelvis_rotation = pelvis->get_rotation();
    pelvis_rotation.z = -l * real_t(0.035);
    pelvis->set_rotation(pelvis_rotation);
    const real_t leg_roll = -std::atan2(hip_shift, real_t(0.78));
    const char *legs[] = {"leg_l", "leg_r"};
    Node3D *leg_nodes[] = {leg_l, leg_r};
    for (int i = 0; i < 2; ++i) {
        leg_nodes[i]->set_position(Vector3(rest[legs[i]]) + hip_offset);
        Vector3 leg_rotation = leg_nodes[i]->get_rotation();
        leg_rotation.z = leg_roll;
        leg_nodes[i]->set_rotation(leg_rotation);
    }

    // Read the authored gait/melee orientation BEFORE applying torso basis.
    const Basis animation = Basis::from_euler(torso->get_rotation());
    const Vector3 torso_rest = rest["torso"];
    torso->set_position(upper.xform(torso_rest));
    torso->set_basis(upper.basis * animation *
                     Basis::from_scale(Vector3(ts, ts, ts)));

    const Vector3 head_rest = rest["head"];
    const Vector3 neck(0, head_rest.y - real_t(0.21), 0);
    const Basis head_basis =
        Basis(Vector3(1, 0, 0), clamp_real(p * real_t(0.92), real_t(-1.12), real_t(1.12))) *
        Basis(Vector3(0, 0, 1), -l * real_t(0.18));
    head->set_position(upper.xform(neck) + head_basis.xform(head_rest - neck));
    head->set_basis(head_basis * Basis::from_scale(Vector3(hs, hs, hs)));

    Vector3 left_rest = rest["left"];
    Vector3 right_rest = rest["right"];
    if (articulated) {
        const real_t width = real_t(0.325) * ts + real_t(0.025);
        left_rest.x = (left_rest.x > 0 ? width : (left_rest.x < 0 ? -width : real_t(0)));
        right_rest.x = (right_rest.x > 0 ? width : (right_rest.x < 0 ? -width : real_t(0)));
    }
    arm_l->set_position(upper.xform(left_rest));
    arm_r->set_position(upper.xform(right_rest));
    return true;
}
