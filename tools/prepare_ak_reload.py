"""Split the existing AK's magazine without replacing its mesh or texture.

The source is an inseparable textured glTF surface. Partitioning its original
triangles at the receiver/magazine seam provides a real removable magazine;
vertices, UVs, materials and the original barrel remain byte-for-byte shared.
This runs offline, never while loading a game or firing a weapon.
"""
import copy
import json
from pathlib import Path
import struct

ROOT = Path(__file__).resolve().parents[1]
source = ROOT / "assets/weapons/ak.glb"
target = ROOT / "assets/weapons/ak_animated.glb"
blob = source.read_bytes()
json_size = struct.unpack_from("<I", blob, 12)[0]
data = json.loads(blob[20 : 20 + json_size])
binary = bytearray(blob[28 + json_size :])


def values(index):
    access = data["accessors"][index]
    view = data["bufferViews"][access["bufferView"]]
    code = {5123: "H", 5125: "I", 5126: "f"}[access["componentType"]]
    size = {"SCALAR": 1, "VEC3": 3, "VEC2": 2}[access["type"]]
    offset = view.get("byteOffset", 0) + access.get("byteOffset", 0)
    stride = view.get("byteStride", struct.calcsize("<" + code) * size)
    return [struct.unpack_from("<" + code * size, binary, offset + i * stride) for i in range(access["count"])]


primitive = data["meshes"][0]["primitives"][0]
attributes = {name: values(index) for name, index in primitive["attributes"].items()}
positions = attributes["POSITION"]
indices = [value[0] for value in values(primitive["indices"])]
body, magazine = [], []


def intersection(a, b, t):
    index = len(positions)
    for name, sequence in attributes.items():
        sequence.append(tuple(x + (y - x) * t for x, y in zip(sequence[a], sequence[b])))
    return index


def split(polygon, axis, boundary, positive):
    inside, outside = [], []
    for i, a in enumerate(polygon):
        b = polygon[(i + 1) % len(polygon)]
        da = (positions[a][axis] - boundary) * positive
        db = (positions[b][axis] - boundary) * positive
        (inside if da >= 0 else outside).append(a)
        if (da > 0 and db < 0) or (da < 0 and db > 0):
            cut = intersection(a, b, da / (da - db))
            inside.append(cut)
            outside.append(cut)
    return inside, outside


def triangles(polygon, output):
    for i in range(1, len(polygon) - 1):
        output.extend([polygon[0], polygon[i], polygon[i + 1]])


for index in range(0, len(indices), 3):
    triangle = indices[index : index + 3]
    candidate, receiver = split(triangle, 1, 0.032, -1)
    triangles(receiver, body)
    if candidate:
        mag, grip = split(candidate, 0, -0.180, 1)
        triangles(grip, body)
        triangles(mag, magazine)

assert 100 < len(magazine) // 3 < 1500, "unexpected imported AK topology"
# The cut interpolates only boundary vertices, including their original UVs.
# That creates a straight magazine mouth instead of selecting jagged whole
# triangles. No arbitrary replacement model or texture is introduced.
for name, sequence in attributes.items():
    width = len(sequence[0])
    while len(binary) % 4:
        binary.append(0)
    start = len(binary)
    for value in sequence:
        binary.extend(struct.pack("<" + "f" * width, *value))
    view_id = len(data["bufferViews"])
    data["bufferViews"].append({"buffer": 0, "byteOffset": start, "byteLength": len(sequence) * width * 4, "target": 34962})
    access_id = len(data["accessors"])
    access = {"bufferView": view_id, "componentType": 5126, "count": len(sequence), "type": "VEC" + str(width)}
    if name == "POSITION":
        access["min"] = [min(v[a] for v in sequence) for a in range(3)]
        access["max"] = [max(v[a] for v in sequence) for a in range(3)]
    data["accessors"].append(access)
    primitive["attributes"][name] = access_id
meshes = []
for label, selected in [("ReceiverGeometry", body), ("MagazineGeometry", magazine)]:
    while len(binary) % 4:
        binary.append(0)
    start = len(binary)
    binary.extend(struct.pack("<" + "I" * len(selected), *selected))
    view_id = len(data["bufferViews"])
    data["bufferViews"].append({"buffer": 0, "byteOffset": start, "byteLength": len(selected) * 4, "target": 34963})
    access_id = len(data["accessors"])
    data["accessors"].append({"bufferView": view_id, "componentType": 5125, "count": len(selected), "type": "SCALAR", "min": [min(selected)], "max": [max(selected)]})
    piece = copy.deepcopy(primitive)
    piece["indices"] = access_id
    meshes.append({"name": label, "primitives": [piece]})
data["meshes"] = meshes
for node in list(data["nodes"]):
    if "mesh" not in node:
        continue
    del node["mesh"]
    node["children"] = []
    for index, name in enumerate(["ReceiverGeometry", "MagazineGeometry"]):
        node["children"].append(len(data["nodes"]))
        data["nodes"].append({"name": name, "mesh": index})
# Reuse the original texture files and discard superseded vertex/index data.
# This avoids exporting a second copy of the same AK textures and binary.
for index, image in enumerate(data.get("images", [])):
    image.pop("bufferView", None)
    image.pop("mimeType", None)
    image["uri"] = "ak_0.png" if index == 0 else "ak_1.jpg"
used = sorted({index for mesh in meshes for primitive in mesh["primitives"] for index in [primitive["indices"], *primitive["attributes"].values()]})
new_accessors, new_views, compact = [], [], bytearray()
access_map = {}
for old_index in used:
    access = copy.deepcopy(data["accessors"][old_index])
    view = copy.deepcopy(data["bufferViews"][access["bufferView"]])
    offset = view.get("byteOffset", 0)
    while len(compact) % 4:
        compact.append(0)
    view["byteOffset"] = len(compact)
    compact.extend(binary[offset : offset + view["byteLength"]])
    access["bufferView"] = len(new_views)
    new_views.append(view)
    access_map[old_index] = len(new_accessors)
    new_accessors.append(access)
for mesh in meshes:
    for primitive in mesh["primitives"]:
        primitive["indices"] = access_map[primitive["indices"]]
        primitive["attributes"] = {name: access_map[index] for name, index in primitive["attributes"].items()}
data["accessors"] = new_accessors
data["bufferViews"] = new_views
binary = compact
data["buffers"][0]["byteLength"] = len(binary)
data.setdefault("asset", {})["generator"] = "Toque de Campo: original AK magazine partition for shared reload"
encoded = json.dumps(data, separators=(",", ":")).encode()
encoded += b" " * (-len(encoded) % 4)
binary.extend(b"\0" * (-len(binary) % 4))
result = struct.pack("<4sII", b"glTF", 2, 12 + 8 + len(encoded) + 8 + len(binary))
result += struct.pack("<I4s", len(encoded), b"JSON") + encoded
result += struct.pack("<I4s", len(binary), b"BIN\0") + binary
target.write_bytes(result)
print(json.dumps({"source": str(source), "output": str(target), "source_triangles": len(indices) // 3, "body_triangles": len(body) // 3, "magazine_triangles": len(magazine) // 3, "preserves_original_vertices_uv_materials": True}))
