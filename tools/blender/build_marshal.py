"""Deterministic, original Marshal model and Blender skin. No external assets.

blender --background --python tools/blender/build_marshal.py -- --samples 32
Blender +Y front converts to Godot -Z. Equipment is exported in anchor space.
"""
import argparse
import hashlib
import json
import math
import sys
from pathlib import Path

import bpy
from mathutils import Matrix, Quaternion, Vector

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets/characters/marshal"
PARTS, MATERIALS, BONES = [], {}, {}
TAU = math.tau


def material(name, color, metal=0, rough=.55, emission=0):
    rgb = [int(color[i:i+2], 16)/255 for i in (0, 2, 4)]
    rgb = [v/12.92 if v <= .04045 else ((v+.055)/1.055)**2.4 for v in rgb]
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*rgb, 1)
    m.use_nodes = True
    p = m.node_tree.nodes.get("Principled BSDF")
    p.inputs["Base Color"].default_value = (*rgb, 1)
    p.inputs["Metallic"].default_value = metal
    p.inputs["Roughness"].default_value = rough
    p.inputs["Emission Color"].default_value = (*rgb, 1)
    p.inputs["Emission Strength"].default_value = emission
    MATERIALS[name] = m


def finish(obj, mat, group, smooth=True):
    obj.data.materials.append(MATERIALS[mat])
    obj["rig_group"] = group
    for p in obj.data.polygons:
        p.use_smooth = smooth
    PARTS.append(obj)
    return obj


def mesh(name, verts, faces, mat, group, smooth=True):
    data = bpy.data.meshes.new(name)
    data.from_pydata(verts, [], faces)
    data.update()
    obj = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(obj)
    return finish(obj, mat, group, smooth)


def ellipsoid(name, center, size, mat, group, segments=24, rings=12):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=rings, location=center)
    obj = bpy.context.object
    obj.name = name
    obj.scale = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return finish(obj, mat, group)


def box(name, center, size, mat, group, bevel=.015, rotation=None):
    bpy.ops.mesh.primitive_cube_add(size=1, location=center)
    obj = bpy.context.object
    obj.name = name
    obj.scale = size
    if rotation:
        obj.rotation_euler = rotation
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel:
        mod = obj.modifiers.new("Tailored edges", "BEVEL")
        mod.width, mod.segments = bevel, 3
        bpy.ops.object.modifier_apply(modifier=mod.name)
        mod = obj.modifiers.new("Corner normals", "WEIGHTED_NORMAL")
        bpy.ops.object.modifier_apply(modifier=mod.name)
    return finish(obj, mat, group, False)


def loft(name, rings, mat, group, sides=32, power=1, caps=True):
    verts = []
    for x, y, z, rx, ry in rings:
        for j in range(sides):
            c, s = math.cos(TAU*j/sides), math.sin(TAU*j/sides)
            verts.append((x+rx*math.copysign(abs(c)**power, c),
                          y+ry*math.copysign(abs(s)**power, s), z))
    faces = []
    for i in range(len(rings)-1):
        for j in range(sides):
            k = (j+1) % sides
            faces.append((i*sides+j, i*sides+k, (i+1)*sides+k, (i+1)*sides+j))
    if caps:
        faces.extend([tuple(reversed(range(sides))), tuple((len(rings)-1)*sides+j for j in range(sides))])
    return mesh(name, verts, faces, mat, group)


def sweep(name, points, radii, mat, group, sides=12, steps=5, flat=1):
    points = [Vector(p) for p in points]
    centers, widths = [], []
    for i in range(len(points)-1):
        a, b, c, d = points[max(0, i-1)], points[i], points[i+1], points[min(len(points)-1, i+2)]
        for j in range(steps):
            t = j/steps
            centers.append(.5*(2*b+(-a+c)*t+(2*a-5*b+4*c-d)*t*t+(-a+3*b-3*c+d)*t**3))
            widths.append(radii[i]*(1-t)+radii[i+1]*t)
    centers.append(points[-1]); widths.append(radii[-1])
    verts = []
    for i, p in enumerate(centers):
        tangent = (centers[min(i+1, len(centers)-1)]-centers[max(i-1, 0)]).normalized()
        side = tangent.cross(Vector((0, 1, 0))).normalized()
        if side.length < .1:
            side = tangent.cross(Vector((0, 0, 1))).normalized()
        other = tangent.cross(side).normalized()
        for j in range(sides):
            t = TAU*j/sides
            verts.append(p+widths[i]*(side*math.cos(t)+other*math.sin(t)*flat))
    faces = []
    for i in range(len(centers)-1):
        for j in range(sides):
            k = (j+1) % sides
            faces.append((i*sides+j, i*sides+k, (i+1)*sides+k, (i+1)*sides+j))
    faces.extend([tuple(reversed(range(sides))), tuple((len(centers)-1)*sides+j for j in range(sides))])
    return mesh(name, verts, faces, mat, group)


def tube(name, start, end, radius, mat, group, top=None, sides=32):
    a, b = Vector(start), Vector(end)
    bpy.ops.mesh.primitive_cone_add(vertices=sides, radius1=radius,
                                  radius2=radius if top is None else top, depth=(b-a).length,
                                  location=(a+b)/2)
    obj = bpy.context.object
    obj.name = name
    obj.rotation_euler = (b-a).to_track_quat("Z", "Y").to_euler()
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    return finish(obj, mat, group)


def panel(name, points, mat, group):
    # Give cloth panels thickness so back/edge views remain intentional.
    n = len(points)
    verts = list(points)+[(x, y-.012, z) for x, y, z in points]
    faces = [tuple(range(n)), tuple(reversed(range(n, n*2)))]
    faces += [(i, (i+1)%n, (i+1)%n+n, i+n) for i in range(n)]
    return mesh(name, verts, faces, mat, group, False)


def uniform():
    loft("Fitted broad officer coat", [(0,0,.87,.23,.145),(0,0,1.02,.30,.19),
         (0,0,1.23,.355,.22),(0,-.005,1.43,.40,.205),(0,0,1.51,.33,.16),
         (0,0,1.56,.15,.125)], "Navy", "Torso", power=.78)
    loft("Trouser seat", [(0,0,.74,.23,.145),(0,0,.88,.26,.17),(0,0,.98,.255,.16)], "Trouser", "Pelvis")
    loft("High red collar", [(0,0,1.48,.15,.14),(0,0,1.57,.16,.135),(0,0,1.61,.14,.12)], "Red", "Chest")
    for s, side in [(-1,"Left"),(1,"Right")]:
        loft("Tailored trouser "+side, [(s*.14,0,.36,.12,.115),(s*.15,0,.53,.14,.14),
             (s*.14,0,.73,.15,.155),(s*.13,0,.88,.145,.15)], "Trouser", side+"Thigh")
        loft("Polished boot shaft "+side, [(s*.15,0,.10,.115,.12),(s*.15,0,.28,.108,.108),
             (s*.15,0,.46,.125,.12),(s*.15,0,.49,.135,.13)], "Leather", side+"Calf")
        box("Boot toe "+side, (s*.15,.085,.085), (.245,.41,.17), "Leather", side+"Foot", .055)
        box("Boot sole "+side, (s*.15,.065,.025), (.25,.43,.05), "Black", side+"Foot", .018)
        tube("Boot cuff "+side,(s*.15,0,.46),(s*.15,0,.49),.145,"Gold",side+"Calf")
        for i in range(2):
            box("Boot buckle",(s*.265,.035,.26+i*.09),(.025,.07,.055),"Gold",side+"Calf",.006)
        # Natural A-pose, continuous sleeve and glove shapes.
        sweep("Full coat sleeve "+side,[(s*.345,0,1.46),(s*.45,0,1.40),(s*.51,0,1.27),
              (s*.55,.005,1.16),(s*.60,.015,1.04)], [.145,.16,.142,.125,.11],"Navy",side+"Sleeve",sides=20,steps=4)
        tube("Scarlet cuff "+side,(s*.58,.012,1.095),(s*.625,.02,.98),.12,"Red",side+"Forearm",top=.115)
        tube("Cuff braid "+side,(s*.618,.019,.993),(s*.625,.02,.976),.119,"Gold",side+"Forearm")
        ellipsoid("Leather glove "+side,(s*.645,.025,.935),(.105,.079,.115),"Glove",side+"Hand")
        for f in range(3):
            sweep("Glove finger seam",[(s*(.594+f*.027),.091,.965),(s*(.60+f*.027),.095,.915)],
                  [.003,.003],"Leather",side+"Hand",sides=6,steps=1)
        ellipsoid("Glove thumb",(s*.567,.06,.944),(.04,.045,.07),"Glove",side+"Hand",16,8)
        ellipsoid("Gold epaulette "+side,(s*.433,-.005,1.505),(.192,.225,.07),"Gold","Chest")
        ellipsoid("Epaulette navy inset",(s*.433,-.005,1.543),(.145,.17,.027),"NavyLight","Chest")
        for j in range(13):
            t = math.pi*(j/12)
            x = s*(.435+.178*math.sin(t))
            y = .20*math.cos(t)
            sweep("Epaulette gold bullion",[(x,y,1.50),(x+s*.01,y,1.44),(x+s*.012,y,1.375)],
                  [.014,.012,.007],"Gold","Chest",sides=8,steps=2)
        panel("Red turned lapel",[(s*.13,.147,1.555),(s*.31,.181,1.43),(s*.18,.23,1.28),
              (s*.045,.222,1.40)],"Red", "Chest")
        sweep("Lapel piping",[(s*.13,.16,1.55),(s*.30,.198,1.43),(s*.18,.245,1.29)], [.007]*3,"Gold","Chest",steps=2,sides=8)
        # Split tails keep the coat clear during crouch/stride.
        panel("Split coat tail "+side,[(s*.035,-.165,1.00),(s*.27,-.13,1.00),
              (s*.31,-.15,.59),(s*.08,-.20,.65)],"Navy",side+"CoatTail")
        sweep("Tail red facing",[(s*.28,-.14,.98),(s*.30,-.165,.62),(s*.09,-.215,.65)],
              [.011]*3,"Red",side+"CoatTail",steps=2,sides=8)
    # Ivory leather diagonal cross-belts with a raised edge, not flat decals.
    for s in [-1,1]:
        panel("Ivory cross belt",[(s*.275,.215,1.48),(s*.34,.199,1.43),(-s*.18,.213,.99),
              (-s*.245,.208,1.025)],"Ivory","Torso")
    loft("Waist belt",[(0,0,.96,.278,.183),(0,0,1.015,.289,.191)],"Leather","Pelvis",power=.75)
    box("Belt clasp",(0,.202,.993),(.15,.033,.09),"Gold","Pelvis",.012)
    box("Belt clasp inset",(0,.222,.993),(.09,.012,.047),"Red","Pelvis",.006)
    for z in [1.12,1.23,1.34,1.45]:
        for s in [-1,1]:
            ellipsoid("Coat brass button",(s*.10,.231,z),(.021,.012,.021),"Gold","Torso",12,6)
    for x,z in [(-.24,1.36),(-.29,1.39)]:
        box("Medal ribbon",(x,.215,z),(.034,.018,.09),"Red","Chest",.002)
        ellipsoid("Officer medal",(x,.234,z-.052),(.029,.01,.029),"Gold","Chest",12,6)
    sweep("Shoulder aiguillette",[(-.34,.17,1.48),(-.37,.245,1.32),(-.27,.258,1.19),(-.19,.24,1.36)],
          [.012]*4,"Gold","Chest",steps=5,sides=8)


def head():
    loft("Strong neck",[(0,0,1.49,.11,.10),(0,.005,1.63,.12,.115)],"Skin","Neck")
    loft("Sculpted commander head",[(0,.005,1.565,.095,.08),(0,.025,1.595,.155,.115),
         (0,.025,1.65,.178,.14),(0,.012,1.73,.195,.158),(0,0,1.83,.19,.155),
         (0,-.005,1.91,.17,.135),(0,-.01,1.95,.115,.095),(0,-.01,1.963,.025,.025)],"Skin","Head",sides=40,power=.78)
    ellipsoid("Broad square chin",(0,.105,1.613),(.13,.085,.064),"Skin","Head")
    for s in [-1,1]:
        ellipsoid("Ear",(s*.192,-.005,1.771),(.048,.035,.075),"Skin","Head",20,10)
        ellipsoid("Ear fold",(s*.214,.022,1.775),(.022,.012,.041),"SkinShadow","Head",16,8)
        ellipsoid("Cheek plane",(s*.127,.122,1.735),(.077,.052,.079),"SkinWarm","Head")
        ellipsoid("Temple hair",(s*.169,-.015,1.861),(.037,.139,.066),"HairShadow","Head")
        sweep("White sideburn",[(s*.184,.02,1.84),(s*.195,.07,1.76),(s*.172,.12,1.682)],
              [.029,.034,.009],"Ivory","Head",sides=12,flat=.7)
        ellipsoid("Deep eye socket",(s*.085,.148,1.82),(.075,.026,.043),"SkinShadow","Head")
        ellipsoid("Eye white",(s*.085,.170,1.816),(.057,.016,.024),"EyeWhite","Face",24,10)
        ellipsoid("Steel iris",(s*.077,.185,1.814),(.013,.007,.017),"Iris","Face",16,8)
        ellipsoid("Pupil",(s*.077,.191,1.814),(.006,.004,.012),"Black","Face",12,8)
        ellipsoid("Eye catchlight",(s*.077-.004,.194,1.821),(.003,.002,.004),"EyeWhite","Face",8,6)
        sweep("Stern upper eyelid",[(s*.027,.179,1.824),(s*.08,.19,1.831),(s*.14,.162,1.831)],
              [.005,.008,.004],"SkinWarm","Face",sides=8,steps=4)
        sweep("Lower eyelid",[(s*.03,.172,1.807),(s*.083,.18,1.796),(s*.14,.158,1.813)],
              [.003,.006,.003],"Skin","Face",sides=8,steps=3)
        sweep("Fierce eyebrow",[(s*.022,.164,1.857),(s*.078,.164,1.876),(s*.146,.137,1.866)],
              [.013,.018,.006],"HairShadow","Face",sides=10,steps=4,flat=.65)
        sweep("Eye age crease",[(s*.12,.17,1.783),(s*.154,.143,1.779)], [.0025,.001],"SkinShadow","Head",sides=6,steps=2)
    loft("Angular long nose",[(0,.181,1.72,.045,.04),(0,.221,1.745,.047,.052),
         (0,.198,1.78,.029,.047),(0,.154,1.85,.024,.022),(0,.14,1.87,.020,.018)],"SkinWarm","Head",sides=12,power=.65)
    for s in [-1,1]:
        ellipsoid("Nostril",(s*.033,.239,1.729),(.014,.008,.008),"SkinShadow","Head",12,6)
    ellipsoid("Mouth shadow",(0,.158,1.657),(.079,.015,.012),"Mouth","Face",24,8)
    sweep("Lower lip",[(-.063,.161,1.65),(0,.18,1.645),(.063,.161,1.65)],
          [.005,.010,.004],"Lip","Face",steps=4,sides=10)
    for s in [-1,1]:
        sweep("Magnificent ivory moustache",[(s*.008,.223,1.704),(s*.065,.229,1.695),
              (s*.142,.205,1.708),(s*.208,.176,1.755),(s*.231,.162,1.798)],
              [.026,.044,.041,.022,.002],"Ivory","Head",sides=16,steps=6,flat=.67)
        for j in range(3):
            sweep("Moustache sculpted strand",[(s*.025,.250+j*.001,1.700+j*.01),
                  (s*.113,.238,1.692+j*.012),(s*.183,.201,1.735+j*.008),(s*.219,.171,1.78)],
                  [.002,.003,.002,.0007],"HairShadow" if j==0 else "HairHighlight","Head",sides=6,steps=4)
    # Cigar exits at the mouth corner, below the moustache.
    tube("Cigar wrapper",(.068,.168,1.663),(.213,.35,1.688),.022,"Cigar","Head",top=.025,sides=20)
    tube("Cigar gold band",(.17,.295,1.680),(.183,.311,1.682),.0255,"Gold","Head",sides=20)
    tube("Cigar ash",(.209,.345,1.687),(.226,.367,1.69),.025,"Ash","Head",sides=20)
    tube("Cigar ember",(.223,.363,1.689),(.228,.369,1.69),.022,"Ember","Head",sides=20)


def hat():
    loft("Tall officer shako",[(0,-.005,1.91,.184,.145),(0,-.007,1.97,.191,.148),
         (0,-.017,2.18,.215,.156),(0,-.035,2.36,.236,.169),(0,-.035,2.39,.225,.161)],"Navy","Head",sides=40,power=.88)
    loft("Shako crown braid",[(0,-.035,2.365,.238,.172),(0,-.035,2.39,.231,.167)],"Gold","Head",sides=40,caps=False)
    loft("Shako bottom braid",[(0,-.005,1.938,.194,.152),(0,-.005,1.96,.194,.152)],"Gold","Head",sides=40)
    ellipsoid("Swept black visor",(0,.125,1.925),(.228,.172,.024),"Black","Head",32,10)
    sweep("Visor brass rim",[(-.217,.15,1.927),(-.15,.265,1.924),(0,.29,1.922),(.15,.265,1.924),(.217,.15,1.927)],
          [.006]*5,"Gold","Head",sides=8,steps=5)
    panel("Diagonal scarlet hat sash",[(-.19,.181,2.16),(-.19,.181,2.21),(.18,.172,2.035),(.18,.172,1.984)],"Red","Head")
    ellipsoid("Brass hat crest",(0,.151,2.20),(.065,.018,.085),"Gold","Head",24,12)
    ellipsoid("Crest navy inset",(0,.169,2.20),(.045,.009,.061),"NavyLight","Head",20,10)
    sweep("Crest flame",[(-.022,.184,2.176),(0,.186,2.246),(.022,.184,2.176)], [.006,.009,.006],"Gold","Head",sides=8,steps=2)
    tube("Crest bar",(-.03,.185,2.19),(.03,.185,2.19),.006,"Gold","Head",sides=8)
    ellipsoid("Cockade rosette",(-.193,.093,2.22),(.037,.03,.049),"Gold","Head",16,8)
    for j in range(5):
        sweep("Red hat tassel",[(-.19+(j-2)*.01,.11,2.20),(-.211+(j-2)*.012,.12,2.08),
              (-.223+(j-2)*.013,.12,1.99)], [.012,.011,.015],"Red","Head",sides=8,steps=3)
    # Layered swept feather blades, with center shafts and tapered tips.
    for j in range(6):
        sweep("Ivory plume blade",[(.15,-.04,2.33),(.24+j*.012,-.06,2.42+j*.025),
              (.24+j*.017,-.09,2.52+j*.024),(.19+j*.023,-.13,2.60+j*.013)],
              [.017,.055,.04,.001],"Ivory" if j%2 else "HairHighlight","Head",sides=12,steps=4,flat=.3)
    sweep("Plume quill",[(.15,-.04,2.33),(.255,-.08,2.51),(.29,-.13,2.66)],
          [.008,.006,.001],"Gold","Head",sides=8,steps=5)


def equipment():
    # Cannon authored in its Godot weapon-anchor equivalent: Blender +Y = -Z.
    box("Cannon carved stock",(0,-.075,-.055),(.20,.33,.20),"Leather","Cannon",.035)
    box("Cannon breech",(0,.075,0),(.29,.32,.28),"NavyLight","Cannon",.035)
    box("Cannon trigger grip",(0,-.06,-.17),(.085,.12,.23),"Leather","Cannon",.018,(-.25,0,0))
    # A genuinely open tube: no front cylinder cap may obstruct the bore.
    verts, faces = [], []
    for y,r in [(.12,.167),(.74,.205),(.74,.172),(.12,.13)]:
        for j in range(40):
            t=TAU*j/40
            verts.append((r*math.cos(t),y,.04+r*math.sin(t)))
    for i in range(4):
        for j in range(40):
            k=(j+1)%40; nxt=(i+1)%4
            faces.append((i*40+j,i*40+k,nxt*40+k,nxt*40+j))
    mesh("Cannon open barrel",verts,[tuple(reversed(f)) for f in faces],"NavyLight","Cannon")
    for y,rad in [(.17,.18),(.39,.19),(.67,.218)]:
        # Surface rings, rather than capped cylinders across the barrel opening.
        sweep("Cannon brass band",[(rad*math.cos(TAU*j/40),y,.04+rad*math.sin(TAU*j/40)) for j in range(41)],
              [.018]*41,"Gold","Cannon",sides=8,steps=1)
    # Open lip and a deep black recessed bore.
    verts, faces = [], []
    for y,r in [(.73,.224),(.82,.232),(.82,.177),(.60,.15)]:
        for j in range(40):
            t = TAU*j/40
            verts.append((r*math.cos(t),y,.04+r*math.sin(t)))
    for i in range(3):
        for j in range(40):
            k = (j+1)%40
            faces.append((i*40+j,i*40+k,(i+1)*40+k,(i+1)*40+j))
    mesh("Cannon hollow brass muzzle",verts,[tuple(reversed(f)) for f in faces],"Gold","Cannon")
    tube("Deep barrel bore",(0,.595,.04),(0,.601,.04),.151,"Black","Cannon",sides=40)
    tube("Left cannon support grip",(-.17,.31,-.09),(.08,.31,-.09),.034,"Leather","Cannon",sides=20)
    sweep("Cannon trigger guard",[(-.06,-.085,-.11),(-.06,.07,-.11),(-.06,.08,-.22),(-.06,-.07,-.24)],
          [.012]*4,"Gold","Cannon",sides=8,steps=4)
    tube("Trigger",(0,.015,-.10),(0,.025,-.17),.009,"Gold","Cannon",sides=10)
    for s in [-1,1]:
        ellipsoid("Cannon mounting rivet",(s*.147,.06,.015),(.015,.028,.028),"Gold","Cannon",12,8)
    # Forearm shield projector moves with the left arm, never owns collision.
    box("Shield emitter bracer",(-.632,-.03,1.045),(.235,.18,.17),"Gold","LeftForearm",.025)
    box("Shield navy face",(-.637,.065,1.045),(.18,.035,.13),"NavyLight","LeftForearm",.018)
    ellipsoid("Shield emitter lens",(-.637,.091,1.047),(.052,.018,.052),"Arcane","LeftForearm",24,12)
    for s in [-1,1]:
        box("Emitter vane",(-.637+s*.078,.10,1.045),(.017,.025,.10),"Gold","LeftForearm",.006)


def smooth(a, b, x):
    t = max(0, min(1, (x-a)/(b-a)))
    return t*t*(3-2*t)


def weights(group, point):
    x,y,z = point
    if group.endswith("Thigh"):
        side=group[:-5]
        thigh=smooth(.43,.56,z); hip=smooth(.79,.92,z)
        return {"Root":hip,side+"Thigh":(1-hip)*thigh,side+"Calf":(1-hip)*(1-thigh)}
    if group == "Neck":
        t=smooth(1.53,1.62,z)
        return {"Chest":1-t,"Head":t}
    if group in BONES:
        return {group:1}
    if group == "Head" or group == "Face": return {"Head":1}
    if group == "Neck":
        t = smooth(1.52,1.63,z)
        return {"Chest":1-t,"Head":t}
    if group == "Torso":
        t = smooth(1.12,1.4,z)
        return {"Spine":1-t,"Chest":t}
    if group == "Pelvis": return {"Root":1}
    if group.endswith("Sleeve"):
        side = group[:-6]
        t = smooth(1.12,1.27,z)
        chest = 1-smooth(.31,.40,abs(x))
        return {"Chest":chest,side+"UpperArm":(1-chest)*t,side+"Forearm":(1-chest)*(1-t)}
    raise ValueError(group)


def make_rig():
    data = bpy.data.armatures.new("MarshalArmature")
    rig = bpy.data.objects.new("MarshalRig",data)
    bpy.context.collection.objects.link(rig)
    bpy.context.view_layer.objects.active = rig
    rig.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    def bone(name, parent, at):
        b = data.edit_bones.new(name)
        b.head = at
        b.tail = Vector(at)+Vector((0,0,.08))
        if parent: b.parent = data.edit_bones[parent]
        BONES[name] = at
    bone("Root",None,(0,0,.88))
    bone("Spine","Root",(0,0,1.13))
    bone("Chest","Spine",(0,0,1.46))
    bone("Neck","Chest",(0,0,1.54))
    bone("Head","Neck",(0,0,1.63))
    for s,side in [(-1,"Left"),(1,"Right")]:
        bone(side+"UpperArm","Chest",(s*.39,0,1.46))
        bone(side+"Forearm",side+"UpperArm",(s*.55,.005,1.16))
        bone(side+"Hand",side+"Forearm",(s*.628,.02,.98))
        bone(side+"Thigh","Root",(s*.14,0,.88))
        bone(side+"Calf",side+"Thigh",(s*.15,0,.49))
        bone(side+"Foot",side+"Calf",(s*.15,0,.14))
        bone(side+"CoatTail","Root",(s*.16,-.16,.97))
    bpy.ops.object.mode_set(mode="OBJECT")
    rig.select_set(False)
    return rig


def assemble(rig):
    grouped = {}
    for obj in PARTS:
        group = obj["rig_group"]
        # Put every vertex in common model coordinates before joining/skinning.
        bpy.ops.object.select_all(action="DESELECT")
        obj.select_set(True); bpy.context.view_layer.objects.active = obj
        bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
        if group != "Cannon":
            for b in BONES: obj.vertex_groups.new(name=b)
            for v in obj.data.vertices:
                mapping = weights(group,v.co)
                for name,w in mapping.items():
                    if w > 1e-8: obj.vertex_groups[name].add([v.index],w,"REPLACE")
        grouped.setdefault(group,[]).append(obj)
    result = []
    for group, objects in grouped.items():
        bpy.ops.object.select_all(action="DESELECT")
        for obj in objects: obj.select_set(True)
        bpy.context.view_layer.objects.active = objects[0]
        bpy.ops.object.join()
        obj = bpy.context.object
        obj.name = "Marshal_"+group
        if group != "Cannon":
            obj.parent = rig
            mod = obj.modifiers.new("Marshal skin","ARMATURE")
            mod.object = rig
        if group == "Face":
            obj.shape_key_add(name="Basis")
            for name in ["Blink","Focused","MouthOpen"]:
                key = obj.shape_key_add(name=name)
                key.value = 0.0
                for v,k in zip(obj.data.vertices,key.data):
                    x,y,z = v.co
                    if name == "Blink" and 1.785 < z < 1.842:
                        k.co.z = 1.814+(z-1.814)*.06
                    if name == "Focused" and z > 1.845:
                        k.co.z -= .016*(1-min(1,abs(x)/.16))
                    if name == "MouthOpen" and z < 1.68:
                        k.co.z = 1.663+(z-1.663)*2.2
        result.append(obj)
    # Empty sockets exported with the skin; smoke follows the head via a bone.
    for name,at in [("CigarTip",(.228,.369,1.69)),("ShieldSocket",(-.637,.091,1.047))]:
        obj = bpy.data.objects.new(name,None)
        bpy.context.collection.objects.link(obj)
        obj.location = at
        obj["bone"] = "Head" if name == "CigarTip" else "LeftForearm"
        result.append(obj)
    cannon = next(o for o in result if o.name == "Marshal_Cannon")
    for name, at in [("CannonMuzzle",(0,.82,.04)),("RightGrip",(0,-.06,-.16)),("LeftGrip",(-.13,.31,-.09))]:
        obj = bpy.data.objects.new(name,None)
        bpy.context.collection.objects.link(obj)
        obj.parent = cannon
        obj.location = at
        result.append(obj)
    return result


def aim(obj, target):
    obj.rotation_euler = (Vector(target)-obj.location).to_track_quat("-Z","Y").to_euler()


def studio_pose(rig, cannon):
    """Review/source pose only: GLB was already exported in neutral bind pose."""
    cannon.location=(.13,-.08,1.34)
    for side,local_target in [("Right",Vector((0,-.06,-.16))), ("Left",Vector((-.13,.31,-.09)))]:
        upper,lower,hand=[rig.pose.bones[side+n] for n in ("UpperArm","Forearm","Hand")]
        start=Vector(BONES[upper.name]); elbow_rest=Vector(BONES[lower.name]); end_rest=Vector(BONES[hand.name])
        a,b=elbow_rest-start,end_rest-elbow_rest
        target=cannon.location+local_target
        direction=(target-start).normalized()
        distance=min((target-start).length,a.length+b.length-.002)
        hint=Vector((-.7 if side=="Left" else .7,-.3,-1))
        bend=(hint-direction*hint.dot(direction)).normalized()
        along=(a.length_squared-b.length_squared+distance*distance)/(2*distance)
        elbow=start+direction*along+bend*math.sqrt(max(0,a.length_squared-along*along))
        end=start+direction*distance
        def set_pose(pose,at,rotation):
            pose.matrix=Matrix.Translation(at)@rotation.to_matrix().to_4x4()@pose.bone.matrix_local.to_3x3().to_4x4()
            bpy.context.view_layer.update()
        set_pose(upper,start,a.normalized().rotation_difference((elbow-start).normalized()))
        set_pose(lower,elbow,b.normalized().rotation_difference((end-elbow).normalized()))
        set_pose(hand,end,Quaternion((1,0,0),math.pi/2))


def studio():
    world = bpy.data.worlds.new("Marshal studio")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (.16,.20,.27,1)
    world.node_tree.nodes["Background"].inputs[1].default_value = .45
    bpy.context.scene.world = world
    for name,at,power,size in [("Key",(3,4,5),650,4),("Fill",(-3,2,3),450,3),("Rim",(1,-3,4),850,3)]:
        data = bpy.data.lights.new(name,"AREA"); data.energy=power; data.shape="DISK"; data.size=size
        obj = bpy.data.objects.new(name,data); bpy.context.collection.objects.link(obj); obj.location=at; aim(obj,(0,0,1.3))
    data = bpy.data.cameras.new("ReviewCamera")
    camera = bpy.data.objects.new("ReviewCamera",data)
    bpy.context.collection.objects.link(camera)
    bpy.context.scene.camera = camera
    data.type = "ORTHO"
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.render.resolution_x = 1024; scene.render.resolution_y = 1024; scene.render.resolution_percentage = 100
    scene.view_settings.view_transform = "AgX"
    scene.render.image_settings.file_format="PNG"
    return camera


def validate(rig,objects):
    triangles,verts,skin_vertices = 0,0,0
    low,high = Vector((1e6,)*3),Vector((-1e6,)*3)
    for obj in objects:
        if obj.type != "MESH": continue
        assert not obj.data.validate(verbose=True), obj.name+" invalid geometry"
        obj.data.calc_loop_triangles()
        triangles += len(obj.data.loop_triangles); verts += len(obj.data.vertices)
        for v in obj.data.vertices:
            assert all(math.isfinite(q) for q in v.co)
            if obj.name != "Marshal_Cannon":
                values = [g.weight for g in v.groups if g.weight > 1e-8]
                assert 0 < len(values) <= 4 and abs(sum(values)-1) < 1e-5
                skin_vertices += 1
                for axis in range(3):
                    low[axis] = min(low[axis],v.co[axis]); high[axis] = max(high[axis],v.co[axis])
    assert triangles <= 95000 and abs(low.z) < .001
    report = {"blender":bpy.app.version_string,"triangles":triangles,"vertices":verts,"skin_vertices":skin_vertices,
              "bones":len(BONES),"max_influences":4,"rigged":True,"bounds_min":list(low),"bounds_max":list(high),
              "body_height_m":1.963,"height_with_hat_m":high.z,"facing_blender":"+Y","facing_godot":"-Z",
              "facial_morphs":["Blink","Focused","MouthOpen"],"validated":True,"gameplay_modified":False}
    (OUT/"model-report.json").write_text(json.dumps(report,indent=2)+"\n")
    print("MARSHAL_VALIDATED",json.dumps(report),flush=True)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--samples",type=int,default=32)
    parser.add_argument("--skip-renders",action="store_true")
    parser.add_argument("--views",nargs="*",default=["front","side","back","three-quarter","face"])
    args = parser.parse_args(sys.argv[sys.argv.index("--")+1:] if "--" in sys.argv else [])
    OUT.mkdir(parents=True,exist_ok=True); (OUT/"previews").mkdir(exist_ok=True)
    bpy.context.preferences.filepaths.save_version=0
    bpy.ops.object.select_all(action="SELECT"); bpy.ops.object.delete(use_global=False)
    for n,c,m,r,e in [("Navy","142d43",0,.67,0),("NavyLight","284764",.15,.48,0),("Trouser","263749",0,.8,0),
        ("Red","a52628",0,.6,0),("Gold","d3a35b",.65,.35,0),("Ivory","e9dfbe",0,.65,0),
        ("HairHighlight","fff2d0",0,.68,0),("HairShadow","a4947d",0,.7,0),("Skin","c88c70",0,.65,0),
        ("SkinWarm","c37f65",0,.68,0),("SkinShadow","875346",0,.75,0),("Lip","a26356",0,.65,0),
        ("Leather","372b29",0,.45,0),("Glove","71513c",0,.6,0),("Black","101c27",.12,.48,0),
        ("Mouth","43282a",0,.8,0),("EyeWhite","e8daba",0,.4,0),("Iris","6c8187",0,.35,0),
        ("Cigar","68402b",0,.9,0),("Ash","a49d95",0,.95,0),("Ember","ed6637",0,.8,1.8),("Arcane","75d4df",.15,.3,1)]:
        material(n,c,m,r,e)
    uniform(); head(); hat(); equipment()
    rig = make_rig(); objects = assemble(rig)
    validate(rig,objects)
    camera = studio()
    # Export the skin in bind pose. Cannon stays separate in anchor space.
    bpy.ops.object.select_all(action="DESELECT")
    rig.select_set(True)
    for obj in objects: obj.select_set(True)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.export_scene.gltf(filepath=str(OUT/"marshal.glb"),export_format="GLB",use_selection=True,
        export_yup=True,export_skins=True,export_morph=True,export_animations=False,export_extras=True,
        export_apply=False,export_all_influences=False)
    for obj in objects:
        if obj.type=="MESH" and obj.data.shape_keys:
            for key in obj.data.shape_keys.key_blocks: key.value=0.0
    report=json.loads((OUT/"model-report.json").read_text())
    report["source_sha256"]=hashlib.sha256((OUT/"marshal.glb").read_bytes()).hexdigest()
    (OUT/"model-report.json").write_text(json.dumps(report,indent=2)+"\n")
    # The editable source opens with the cannon displayed in hand area.
    cannon = next(o for o in objects if o.name=="Marshal_Cannon")
    studio_pose(rig,cannon)
    scene = bpy.context.scene
    scene.cycles.samples = args.samples
    views = {"front":((0,6,1.6),(0,0,1.33),3.0),"side":((6,0,1.6),(0,0,1.33),3.0),
             "back":((0,-6,1.6),(0,0,1.33),3.0),"three-quarter":((3.5,6,3),(0,.05,1.33),3.05),
             "face":((1.1,5,2.1),(0,.06,1.85),.85)}
    if not args.skip_renders:
        for name in args.views:
            at,target,size=views[name]; camera.location=at; aim(camera,target); camera.data.ortho_scale=size
            scene.render.filepath=str(OUT/"previews"/(name+".png")); bpy.ops.render.render(write_still=True)
    camera.location=(3.5,6,3); aim(camera,(0,.05,1.33)); camera.data.ortho_scale=3.05
    # Restore anchor-space cannon before saving; studio display uses a parent offset.
    cannon.location = (0,0,0)
    display = bpy.data.objects.new("Cannon studio placement - excluded from export",None)
    bpy.context.collection.objects.link(display); display.location=(.13,-.08,1.34)
    cannon.parent=display
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT/"marshal.blend"))
    # Keep the editable .blend as source; Godot consumes only the explicit GLB.
    (OUT/"marshal.blend.import").write_text('[remap]\n\nimporter="keep"\n\n[deps]\n\nsource_file="res://assets/characters/marshal/marshal.blend"\n')
    print("MARSHAL_ASSET_COMPLETE",str(OUT),flush=True)


if __name__ == "__main__":
    main()
