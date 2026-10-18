"""Standard-library structural checks for the generated self-contained GLB."""
import hashlib
import json
import math
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
FOLDER = ROOT / "assets/characters/slayer"
data = (FOLDER / "slayer.glb").read_bytes()
checks = 0


def check(condition, caption):
    global checks
    checks += 1
    if not condition:
        raise AssertionError(caption)


magic, version, length = struct.unpack_from("<III", data)
check(magic == 0x46546C67 and version == 2, "GLB 2.0 header")
check(length == len(data), "declared file length")
offset, chunks = 12, {}
while offset < len(data):
    size, kind = struct.unpack_from("<II", data, offset)
    offset += 8
    check(offset + size <= len(data), "chunk bounds")
    chunks[kind] = data[offset:offset + size]
    offset += size
gltf = json.loads(chunks[0x4E4F534A])
binary = chunks[0x004E4942]
check(gltf["asset"]["version"] == "2.0", "glTF schema version")
check(len(gltf["buffers"]) == 1 and "uri" not in gltf["buffers"][0], "embedded binary buffer")
check(not gltf.get("images"), "solid PBR materials have no external texture dependencies")
check(not gltf.get("animations") and not gltf.get("skins"), "static review mesh without a fake rig")
for view in gltf["bufferViews"]:
    check(view.get("byteOffset", 0) + view["byteLength"] <= len(binary), "buffer view bounds")


def values(index):
    accessor = gltf["accessors"][index]
    component = {5121: "B", 5123: "H", 5125: "I", 5126: "f"}[accessor["componentType"]]
    count = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}[accessor["type"]]
    fmt = "<" + component * count
    size = struct.calcsize(fmt)
    result=[(0,)*count for _ in range(accessor["count"])]
    if "bufferView" in accessor:
        view = gltf["bufferViews"][accessor["bufferView"]]
        start = view.get("byteOffset", 0) + accessor.get("byteOffset", 0)
        stride = view.get("byteStride", size)
        result=[struct.unpack_from(fmt, binary, start + i * stride) for i in range(accessor["count"])]
    if "sparse" in accessor:
        sparse=accessor["sparse"]
        indices=sparse["indices"]; offsets=sparse["values"]
        iview=gltf["bufferViews"][indices["bufferView"]]
        vview=gltf["bufferViews"][offsets["bufferView"]]
        ifmt="<"+{5121:"B",5123:"H",5125:"I"}[indices["componentType"]]
        istart=iview.get("byteOffset",0)+indices.get("byteOffset",0)
        vstart=vview.get("byteOffset",0)+offsets.get("byteOffset",0)
        for i in range(sparse["count"]):
            target=struct.unpack_from(ifmt,binary,istart+i*struct.calcsize(ifmt))[0]
            check(target<len(result),"sparse morph index bounds")
            result[target]=struct.unpack_from(fmt,binary,vstart+i*size)
    return result


triangles = 0
primitives = 0
expected_keys=["Blink","BrowRaise","BrowLower","Smile","Frown","MouthOpen","Relaxed","Focused","Smirk"]
morph_meshes=0
motion={key:0 for key in expected_keys}
for mesh in gltf["meshes"]:
    targets=mesh.get("extras",{}).get("targetNames",[])
    if targets:
        morph_meshes+=1
        check(targets==expected_keys,"all nine ordered facial morph names survive export")
        check(all(weight==0 for weight in mesh.get("weights",[])),"neutral expression is exported")
        check(gltf["materials"][mesh["primitives"][-1]["material"]]["name"]=="FaceSkin","tinted skin primitive ordering retained for Godot 4.7.2")
    for primitive in mesh["primitives"]:
        primitives += 1
        check(primitive.get("mode", 4) == 4, "triangle primitive")
        vertices = values(primitive["attributes"]["POSITION"])
        check("TEXCOORD_0" in primitive["attributes"],"export UVs support generated morph tangents")
        uv=values(primitive["attributes"]["TEXCOORD_0"])
        check(len(uv)==len(vertices) and all(math.isfinite(c) for p in uv for c in p),"finite UVs span every export vertex")
        check(all(math.isfinite(c) for vertex in vertices for c in vertex), "finite positions")
        normals = values(primitive["attributes"]["NORMAL"])
        check(all(.95 < sum(c * c for c in normal) < 1.05 for normal in normals), "unit normals")
        indices = [value[0] for value in values(primitive["indices"])]
        check(len(indices) % 3 == 0 and max(indices) < len(vertices), "valid triangle indices")
        triangles += len(indices) // 3
        material = gltf["materials"][primitive["material"]]
        check("pbrMetallicRoughness" in material, "exported PBR material")
        if targets:
            check(len(primitive.get("targets",[]))==len(expected_keys),"morph targets span every face material primitive")
            for name,target in zip(targets,primitive["targets"]):
                delta=values(target["POSITION"])
                check(len(delta)==len(vertices),"morph topology matches basis")
                check(all(math.isfinite(c) and abs(c)<.06 for v in delta for c in v),"finite bounded facial morph deltas")
                motion[name]+=sum(any(abs(c)>1e-7 for c in v) for v in delta)
check(morph_meshes==1,"one isolated facial morph mesh")
for name,count in motion.items(): check(count>20,"nontrivial geometry deformation: "+name)
check(70000<triangles<95000,"detailed face remains within 95k review triangle budget")
preservation=json.loads((FOLDER/"face-preservation.json").read_text())
check(preservation["unchanged"] and preservation["objects"]>200,"protected body, outfit, hair and weapon geometry preserved")
report = {
    "checks": checks, "failures": 0, "glb_version": version,
    "file_bytes": len(data), "sha256": hashlib.sha256(data).hexdigest(),
    "meshes": len(gltf["meshes"]), "primitives": primitives,
    "triangles": triangles, "materials": len(gltf["materials"]),
    "external_dependencies": 0,
    "facial_shape_keys":expected_keys,"moved_vertices_by_key":motion,
    "method": "GLB header/buffer/index/normal/PBR checks; Godot import tested separately",
}
(FOLDER / "glb-validation.json").write_text(json.dumps(report, indent=2) + "\n")
print(json.dumps(report, indent=2))
