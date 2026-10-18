"""Validate the saved editable source, not just the generator's in-memory scene."""
import json
import sys
from pathlib import Path

import bpy

sys.path.insert(0,str(Path(__file__).resolve().parent))
import build_slayer as api
from slayer_face import KEYS

bpy.ops.wm.open_mainfile(filepath=str(api.OUT/"slayer.blend"))
api.CHAR=bpy.data.objects["Slayer - editable modular source"]
api.PARTS.extend(obj for obj in bpy.data.objects if "rig_group" in obj)
face=bpy.data.objects["Slayer expressive face"]
checks=0
def check(ok,message):
    global checks
    checks+=1
    if not ok: raise AssertionError(message)
    print("PASS",message,flush=True)

check(face.type=="MESH" and face.parent==api.CHAR,"editable facial mesh retains character hierarchy")
check([k.name for k in face.data.shape_keys.key_blocks][1:]==list(KEYS),"saved source contains nine named relative morphs")
check(all(k.value==0 for k in list(face.data.shape_keys.key_blocks)[1:]),"saved source opens in neutral expression")
check(face.data.color_attributes.get("FaceTint") is not None,"editable skin colour variation is retained")
check(not any(obj.type=="ARMATURE" for obj in api.PARTS),"source remains compatible with its original unrigged state")
check(all(not obj.hide_render for obj in api.PARTS if obj["rig_group"] in {"Shotgun","BackAxe"}),"inspection renders restored weapon visibility in saved source")
expected=json.loads((api.OUT/"face-preservation.json").read_text())["object_hashes"]
actual=api.preserved_fingerprint()
authorized={obj.name for obj in api.PARTS if obj["rig_group"] in {"Head","Hair","Neck"}}
check(expected==actual,"saved source preserves all 243 protected component hashes")
check(len(actual)==243,"ears, earrings, unedited hair, outfit, body and weapons remain present")
framing=[obj for obj in api.PARTS if obj.name.startswith(api.FRAMING_PREFIXES)]
check(len(framing)==10 and all(obj.data.attributes.get("SlayerFramingRest") for obj in framing),
      "ten authorized front clumps retain editable original rest coordinates")
old_positions={obj.name:[tuple(v.co) for v in obj.data.vertices] for obj in framing}
api.adjust_front_hair()
check(all(old_positions[obj.name]==[tuple(v.co) for v in obj.data.vertices] for obj in framing),
      "face-framing adjustment is idempotent across repeated regeneration")
bpy.ops.wm.open_mainfile(filepath=str(api.OUT/"rollback/pre-reconstruction/slayer.blend"))
api.CHAR=bpy.data.objects["Slayer - editable modular source"]
api.PARTS.clear(); api.PARTS.extend(obj for obj in bpy.data.objects if "rig_group" in obj)
check({name:value for name,value in actual.items() if name not in authorized}=={name:value for name,value in api.preserved_fingerprint().items() if name not in authorized},"body, outfit and equipment match the original rollback; authorized neck/head placement excluded")
report={"checks":checks,"failures":0,"blender":bpy.app.version_string,"preserved_components":len(actual),
        "adjusted_front_clumps":10,"baseline":"rollback/pre-reconstruction/slayer.blend","shape_keys":list(KEYS)}
(api.OUT/"face-native-validation.json").write_text(json.dumps(report,indent=2)+"\n")
print("SLAYER_SAVED_BLEND_PASSED",checks,flush=True)
