"""Read-only validation: blender --background assets/characters/marshal/marshal.blend --python this_file."""
import hashlib
import json
import math
import struct
from pathlib import Path
import bpy
from mathutils import Vector

OUT=Path(__file__).resolve().parents[2]/"assets/characters/marshal"
checks=0


def check(ok, caption):
    global checks
    assert ok, caption
    checks+=1
    print("PASS",caption,flush=True)


def main():
    rig=bpy.data.objects["MarshalRig"]
    check(rig.type=="ARMATURE" and len(rig.data.bones)==19,"editable Blender armature has nineteen bones")
    for name in ["LeftCoatTail","RightCoatTail","LeftHand","RightHand","Neck","Head"]:
        check(name in rig.data.bones,"articulated bone "+name)
    for obj in bpy.data.objects:
        if obj.type!="MESH" or obj.name=="Marshal_Cannon": continue
        check(any(m.type=="ARMATURE" and m.object==rig for m in obj.modifiers),obj.name+" has a live armature modifier")
        good=True
        for v in obj.data.vertices:
            values=[g.weight for g in v.groups if g.weight>1e-8]
            good=good and 0<len(values)<=4 and abs(sum(values)-1)<1e-5 and all(math.isfinite(q) for q in v.co)
        check(good,obj.name+" finite normalized skin")
    face=bpy.data.objects["Marshal_Face"]
    check(all(k.value==0 for k in face.data.shape_keys.key_blocks),"saved facial morphs are neutral")
    cannon=bpy.data.objects["Marshal_Cannon"]
    hit,at,normal,_=cannon.ray_cast(Vector((0,.85,.04)),Vector((0,-1,0)))
    check(hit and .595<=at.y<=.605 and normal.y>.9,"cannon bore is recessed and faces forward")
    crown=[p for p in cannon.data.polygons if abs(p.center.y-.82)<.0001]
    check(crown and all(p.normal.y>.9 for p in crown),"muzzle annulus faces outward for Godot backface culling")
    raw=(OUT/"marshal.glb").read_bytes()
    magic,version,total=struct.unpack_from("<III",raw)
    check(magic==0x46546C67 and version==2 and total==len(raw),"valid GLB 2 container")
    length,kind=struct.unpack_from("<II",raw,12)
    check(kind==0x4E4F534A,"GLB JSON chunk")
    doc=json.loads(raw[20:20+length])
    check(len(doc["skins"])==1 and len(doc["skins"][0]["joints"])==19,"GLB contains the actual nineteen-bone Blender skin")
    names={n.get("name") for n in doc["nodes"]}
    check({"CannonMuzzle","LeftGrip","RightGrip","CigarTip","ShieldSocket"}<=names,"equipment sockets exported")
    skinned=0
    for node in doc["nodes"]:
        if "skin" not in node: continue
        skinned+=1
        m=doc["meshes"][node["mesh"]]
        for primitive in m["primitives"]:
            a=primitive["attributes"]
            check("JOINTS_0" in a and "WEIGHTS_0" in a and "JOINTS_1" not in a,"GLB four-influence attributes: "+m["name"])
            check(doc["accessors"][a["WEIGHTS_0"]]["count"]==doc["accessors"][a["POSITION"]]["count"],"skin vertex count: "+m["name"])
        if "weights" in m:
            check(all(v==0 for v in m["weights"]),"exported default morph weights neutral")
            check(m["extras"]["targetNames"]==["Blink","Focused","MouthOpen"],"three named GLB facial targets")
    check(skinned>=15,"all body groups exported as skinned meshes")
    report=json.loads((OUT/"model-report.json").read_text())
    check(report["triangles"]<=95000 and report["validated"],"within geometry budget")
    check(report["source_sha256"]==hashlib.sha256(raw).hexdigest(),"report matches current GLB bytes")
    print("MARSHAL_SOURCE_RESULT",checks,"checks, 0 failures",flush=True)


if __name__=="__main__": main()
