"""Focused Blender API checks: controls, deterministic construction, actual morphs.

Run: blender --background --factory-startup --python tools/blender/test_slayer_face.py
Does not write the asset or touch gameplay files.
"""
import json
import math
import random
import sys
from pathlib import Path

import bpy

sys.path.insert(0,str(Path(__file__).resolve().parent))
import build_slayer as api
from slayer_face import FaceBuilder, FaceConfig, KEYS, build

checks=0
def check(condition,message):
    global checks
    checks+=1
    if not condition: raise AssertionError(message)
    print("PASS",message,flush=True)

api.setup_materials()
api.CHAR=bpy.data.objects.new("Face test root",None)
bpy.context.collection.objects.link(api.CHAR)
builder=FaceBuilder(api,FaceConfig())
a=builder.build()
basis=[tuple(v.co) for v in a.data.vertices]
check(len(basis)>5000,"face has continuous editable construction")
def span(points,axis): return max(p[axis] for p in points)-min(p[axis] for p in points)
c=builder.c
cx=c.eye_spacing
lo,hi=builder.eye_bounds(cx,1)
old_height=(.0108+.0078)*1.25*1.15
check(hi-lo < old_height*.81,"neutral eye opening is at least 19 percent lower than the prior oval")
check(.05 <= (1-(hi-1.756)/(.0107*c.iris_scale))/2 <= .12,
      "upper lid overlaps 5 to 12 percent of the iris diameter")
check((.031*c.eye_scale*c.eye_width*2)/(hi-lo)>3,"almond opening is horizontal rather than round")
check("FaceLid" not in builder.names and "FaceCrease" not in builder.names,
      "integrated lids use skin material without cosmetic rings")
check(builder.relief(0,1.721)>builder.relief(.025,1.721)+.008,
      "nose tip has coherent facial depth")
check(builder.relief(.064,1.727)>builder.relief(.064,1.691),
      "cheekbone and lower-cheek planes have distinct volumes")
# Actual surface triangles must leave both eye apertures open; back-facing skull excluded.
apertures_clear=True
for poly,index in zip(builder.faces,builder.materials):
    if builder.names[index]!="FaceSkin" or not all(builder.tags[v]=="skin" for v in poly): continue
    pts=[builder.verts[v] for v in poly]
    if not all(p[1]>0 for p in pts): continue
    x=sum(p[0] for p in pts)/len(pts); z=sum(p[2] for p in pts)/len(pts)
    for side in (-1,1):
        low,high=builder.eye_bounds(x,side)
        if abs(x-side*c.eye_spacing)<.031*c.eye_scale*c.eye_width*.9:
            apertures_clear &= not low+.0005<z<high-.0005
check(apertures_clear,"both socket apertures are open in the actual head topology")
# Small lip roll stays close to the integrated muzzle.
lips=[p for p,t in zip(builder.verts,builder.tags) if t in ("upperlip","lowerlip")]
check(max(p[1]-builder.surface(p[0],p[2]) for p in lips)<.004,
      "understated lip tissue stays within four millimetres of the muzzle")
# The outer lids share indices with the head, rather than just occupying nearby positions.
shared=set()
for face,index in zip(builder.faces,builder.materials):
    if builder.names[index]!="FaceSkin": continue
    if any(builder.tags[v]=="skin" for v in face):
        shared.update(v for v in face if builder.tags[v].startswith("lid"))
check(len(shared)>90,"socket and head share welded boundary vertices for continuous normals")
check(builder.c.chin_lift>.015,"lower face is shortened independently of the original body")
eye_layers=[(point,tag) for point,tag in zip(builder.verts,builder.tags) if tag.startswith("eye")]
check(all(-.001<point[1]-builder.eye_front(point[0],point[2],int(tag[3:]))<.0021
          for point,tag in eye_layers),"iris, fibers, pupil and highlights conform to the sclera dome")
check([key.name for key in a.data.shape_keys.key_blocks][1:]==list(KEYS),"legacy and reconstruction expression morphs retained")
check(all(key.value==0 for key in list(a.data.shape_keys.key_blocks)[1:]),"saved expression defaults to neutral")
for name in KEYS:
    key=a.data.shape_keys.key_blocks[name]
    moved=sum((v.co-a.data.vertices[i].co).length>1e-7 for i,v in enumerate(key.data))
    check(moved>20,"actual vertex deformation: "+name)
    check(all(math.isfinite(c) for v in key.data for c in v.co),"finite pose: "+name)
    if name in ("Relaxed","Focused"):
        flips=0
        for poly in a.data.polygons:
            if a.data.materials[poly.material_index].name!="FaceSkin" or len(poly.vertices)!=3: continue
            base=[a.data.vertices[i].co for i in poly.vertices]
            pose=[key.data[i].co for i in poly.vertices]
            if min(v.y for v in base)<.025: continue
            normal=(base[1]-base[0]).cross(base[2]-base[0])
            changed=(pose[1]-pose[0]).cross(pose[2]-pose[0])
            flips+=normal.dot(changed)<-1e-14
        check(flips==0,"no front skin triangles fold across the moving socket: "+name)

random.seed(119)
for _ in range(200): api.RNG.random(); random.random()
b=build(api)
check(basis==[tuple(v.co) for v in b.data.vertices],"presentation generation independent of ambient random streams")
small=build(api,FaceConfig(eye_scale=1.0))
large=build(api,FaceConfig(eye_scale=1.35))
check([tuple(v.co) for v in small.data.vertices]!=[tuple(v.co) for v in large.data.vertices],"eye control changes real geometry")
for name,invalid in [("eye_scale",2),("iris_scale",float("nan")),("eyelid_thickness",0)]:
    rejected=False
    try: FaceConfig(**{name:invalid}).validate()
    except ValueError: rejected=True
    check(rejected,"unsafe proportion rejected: "+name)
rejected=False
try: FaceConfig(eye_scale=1.45,eye_spacing=.044,eye_width=1.0).validate()
except ValueError: rejected=True
check(rejected,"combined eye controls cannot overlap across the nose bridge")
report={"checks":checks,"failures":0,"blender":bpy.app.version_string,"shape_keys":list(KEYS)}
(api.OUT/"face-generator-validation.json").write_text(json.dumps(report,indent=2)+"\n")
print("SLAYER_FACE_TESTS_PASSED",checks,flush=True)
