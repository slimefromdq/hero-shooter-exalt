"""Original modular Slayer asset. Run with Blender --background --python this_file.

Blender +Y is the face direction; glTF Y-up conversion maps it to Godot -Z.
No external assets, add-ons, textures, gameplay changes or rig are required.
"""
import argparse
import json
import math
import random
import sys
import hashlib
from pathlib import Path

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets/characters/slayer"
PREVIEWS = OUT / "previews"
RNG = random.Random(7419)
TAU = math.tau
MATS = {}
CHAR = None
PARTS = []
sys.path.insert(0, str(Path(__file__).resolve().parent))
import slayer_face


def mat(name, hex_colour, roughness=.5, metal=0, emission=0):
    colour = tuple(int(hex_colour[i:i + 2], 16) / 255 for i in (0, 2, 4))
    # Hex is authored in sRGB; Principled inputs are linear.
    linear = tuple(((v + .055) / 1.055) ** 2.4 if v > .04045 else v / 12.92 for v in colour)
    material = bpy.data.materials.new(name)
    material.diffuse_color = (*linear, 1)
    material.use_nodes = True
    bsdf = material.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*linear, 1)
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = metal
    if emission:
        bsdf.inputs["Emission Color"].default_value = (*linear, 1)
        bsdf.inputs["Emission Strength"].default_value = emission
    MATS[name] = material
    return material


def mesh(name, verts, faces, material, group, smooth=True):
    data = bpy.data.meshes.new(name)
    data.from_pydata(verts, [], faces)
    data.update()
    obj = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(obj)
    obj.parent = CHAR
    obj["rig_group"] = group
    obj.data.materials.append(MATS[material])
    for polygon in data.polygons:
        polygon.use_smooth = smooth
    PARTS.append(obj)
    return obj


def bevel(obj, width=.003, segments=2):
    mod = obj.modifiers.new("Soft manufactured edges", "BEVEL")
    mod.width, mod.segments = width, segments
    mod = obj.modifiers.new("Weighted corner normals", "WEIGHTED_NORMAL")
    mod.keep_sharp = True
    return obj


def loft(name, sections, material, group, sides=24, power=1.0):
    """Continuous elliptical rings (cx,cy,z,rx,ry), capped at both ends."""
    verts = []
    for cx, cy, z, rx, ry in sections:
        for j in range(sides):
            t = TAU * j / sides
            c, s = math.cos(t), math.sin(t)
            verts.append((cx + rx * math.copysign(abs(c) ** power, c),
                          cy + ry * math.copysign(abs(s) ** power, s), z))
    faces = []
    for i in range(len(sections) - 1):
        for j in range(sides):
            k = (j + 1) % sides
            faces.append((i*sides+j, i*sides+k, (i+1)*sides+k, (i+1)*sides+j))
    faces += [tuple(reversed(range(sides))), tuple((len(sections)-1)*sides+j for j in range(sides))]
    return mesh(name, verts, faces, material, group)


def catmull(points, steps=5):
    points = [Vector(p) for p in points]
    result = []
    for i in range(len(points) - 1):
        a, b, c, d = points[max(0, i-1)], points[i], points[i+1], points[min(len(points)-1, i+2)]
        for j in range(steps):
            t = j / steps
            result.append(.5*((2*b) + (-a+c)*t + (2*a-5*b+4*c-d)*t*t + (-a+3*b-3*c+d)*t*t*t))
    return result + [points[-1]]


def sweep(name, points, widths, depths, material, group, sides=12, steps=4):
    centres = catmull(points, steps)
    verts = []
    for i, centre in enumerate(centres):
        u = i / (len(centres)-1) * (len(widths)-1)
        k = min(int(u), len(widths)-2)
        f = u-k
        def radius(values):
            a,b,c,d=values[max(0,k-1)],values[k],values[k+1],values[min(len(values)-1,k+2)]
            return max(.0004,.5*(2*b+(-a+c)*f+(2*a-5*b+4*c-d)*f*f+(-a+3*b-3*c+d)*f*f*f))
        rx,ry=radius(widths),radius(depths)
        tangent = (centres[min(i+1,len(centres)-1)] - centres[max(i-1,0)]).normalized()
        side = tangent.cross(Vector((0, 1, 0))).normalized()
        if side.length < .1:
            side = tangent.cross(Vector((1, 0, 0))).normalized()
        other = tangent.cross(side).normalized()
        for j in range(sides):
            t = TAU*j/sides
            verts.append(centre + side*math.cos(t)*rx + other*math.sin(t)*ry)
    faces = []
    for i in range(len(centres)-1):
        for j in range(sides):
            k = (j+1)%sides
            faces.append((i*sides+j,i*sides+k,(i+1)*sides+k,(i+1)*sides+j))
    faces += [tuple(reversed(range(sides))), tuple((len(centres)-1)*sides+j for j in range(sides))]
    return mesh(name, verts, faces, material, group)


def curve(name, points, radius, material, group):
    data = bpy.data.curves.new(name, "CURVE")
    data.dimensions = "3D"
    data.resolution_u = 12
    data.bevel_depth = radius
    data.bevel_resolution = 2
    spline = data.splines.new("BEZIER")
    spline.bezier_points.add(len(points)-1)
    for knot, co in zip(spline.bezier_points, points):
        knot.co = co
        knot.handle_left_type = knot.handle_right_type = "AUTO"
    obj = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(obj)
    obj.parent = CHAR
    obj["rig_group"] = group
    data.materials.append(MATS[material])
    PARTS.append(obj)
    return obj


def plate(name, outline, thickness, material, group, edge=.002):
    # Outline coordinates are already in Blender XYZ; extrusion goes along Y.
    verts = [(x,y-thickness/2,z) for x,y,z in outline] + [(x,y+thickness/2,z) for x,y,z in outline]
    n = len(outline)
    faces = [tuple(reversed(range(n))), tuple(range(n,2*n))]
    faces += [(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    return bevel(mesh(name, verts, faces, material, group, False), edge)


def box(name, centre, size, material, group, edge=.003):
    x,y,z = centre
    a,b,c = (v/2 for v in size)
    return plate(name, [(x-a,y,z-c),(x+a,y,z-c),(x+a,y,z+c),(x-a,y,z+c)], b, material, group, edge)


def disk(name, centre, rx, rz, material, group, sides=24):
    x,y,z = centre
    verts = [(x,y+.001,z)]
    verts += [(x+rx*math.cos(TAU*i/sides),y,z+rz*math.sin(TAU*i/sides)) for i in range(sides)]
    return mesh(name,verts,[(0,(i+1)%sides+1,i+1) for i in range(sides)],material,group)


def body():
    loft("Fitted charcoal undershirt",[(0,0,.96,.164,.102),(0,0,1.04,.148,.093),
         (0,0,1.12,.119,.080),(0,0,1.20,.141,.093),(0,0,1.29,.174,.103),
         (0,0,1.36,.183,.108),(0,-.004,1.43,.188,.089),(0,-.005,1.48,.178,.074),
         (0,-.004,1.51,.061,.048)],"Cloth", "Torso",32)
    loft("Neck",[(0,-.006,1.48,.052,.047),(0,-.004,1.54,.050,.043),
         (0,0,1.60,.052,.047),(0,.004,1.65,.061,.051)],"Skin","Neck",24)
    loft("Trouser waist and pelvis",[(0,0,.87,.158,.10),(0,0,.93,.173,.113),
         (0,0,1.00,.167,.108),(0,0,1.065,.144,.095)],"Cloth","Pelvis",32)
    for side, label in [(-1,"R"),(1,"L")]:
        loft("Tailored thigh "+label,[(side*.105,0,.94,.092,.100),
             (side*.112,.004,.86,.099,.100),(side*.115,.010,.73,.089,.089),
             (side*.118,.023,.61,.065,.069),(side*.12,.025,.54,.061,.064)],"Cloth", "Thigh."+label,24)
        loft("Shaped calf "+label,[(side*.12,.025,.55,.061,.065),
             (side*.12,.005,.45,.072,.076),(side*.12,-.005,.36,.069,.070),
             (side*.12,-.007,.25,.050,.056),(side*.12,-.004,.18,.046,.051)],"Cloth","Calf."+label,24)
        x = side*.12
        plate("Articulated knee "+label,[(x-.043,.084,.49),(x+.043,.084,.49),
              (x+.05,.088,.59),(x,.094,.625),(x-.05,.088,.59)],.012,"Steel","Calf."+label,.006)
        curve("Trouser outer seam "+label,[(side*.194,0,.90),(side*.202,.005,.78),
              (side*.175,.02,.60),(side*.183,-.01,.40)],.0016,"Seam","Thigh."+label)
        plate("Thigh utility flap "+label,[(side*.175,.04,.84),(side*.213,.027,.82),
              (side*.202,.035,.71),(side*.162,.07,.73)],.011,"LeatherDark","Thigh."+label,.004)
        arm(side,label)
        boot(side,label)


def arm(s,label):
    sweep("Jacket upper sleeve "+label,[(s*.18,0,1.46),(s*.237,0,1.445),
          (s*.278,.003,1.35),(s*.314,.013,1.265)], [.067,.071,.061,.054],
          [.070,.067,.057,.049],"Burgundy","UpperArm."+label,16)
    sweep("Sleeve lower "+label,[(s*.31,.013,1.28),(s*.344,.022,1.19),(s*.374,.03,1.11)],
          [.054,.057,.044],[.050,.048,.037],"Burgundy","Forearm."+label,16)
    sweep("Leather bracer "+label,[(s*.353,.024,1.18),(s*.375,.036,1.095),(s*.399,.043,1.03)],
          [.063,.054,.036],[.055,.046,.033],"LeatherDark","Forearm."+label,16)
    for i in range(3):
        z=1.08+i*.035
        x=s*(.392-i*.012)
        box("Bracer silver fastening "+label+str(i),(x,.085,z),(.059,.012,.012),"Silver","Forearm."+label,.002)
    sweep("Palm "+label,[(s*.399,.044,1.045),(s*.416,.051,1.00),(s*.425,.058,.963)],
          [.032,.042,.033],[.027,.026,.021],"Glove","Hand."+label,16)
    for i in range(4):
        x=s*.425+(i-1.5)*.019
        length=[.064,.085,.082,.063][i]
        sweep("Finger %s %d"%(label,i),[(x,.06,.978),(x,.073,.95),
              (x,.084,.978-length)], [.0105,.010,.0065],[.011,.009,.006],"Skin","Hand."+label,8)
    sweep("Thumb "+label,[(s*.391,.066,1.007),(s*.381,.09,.982),(s*.393,.10,.96)],
          [.015,.012,.008],[.014,.011,.007],"Skin","Hand."+label,10)
    curve("Shoulder stitched join "+label,[(s*.21,.054,1.47),(s*.247,.066,1.44),
          (s*.277,.056,1.37)],.0013,"Seam","UpperArm."+label)


def boot(s,label):
    x=s*.12
    sections=[(x,.05,.005,.079,.148),(x,.052,.035,.084,.152),
              (x,.052,.063,.083,.151),(x,.052,.085,.078,.145)]
    loft("Boot rubber sole "+label,sections,"Rubber","Foot."+label,24,.7)
    loft("Shaped boot leather "+label,[(x,.05,.065,.076,.143),(x,.049,.11,.077,.140),
         (x,.04,.15,.071,.123),(x,.009,.20,.060,.078),
         (x,-.003,.29,.063,.069),(x,-.005,.365,.078,.083)],"BootLeather","Foot."+label,24,.82)
    loft("Boot top rim "+label,[(x,-.005,.350,.077,.082),(x,-.005,.365,.081,.087),
         (x,-.005,.378,.078,.084)],"LeatherDark","Foot."+label,24)
    plate("Reinforced toe cap "+label,[(x-.066,.158,.08),(x+.066,.158,.08),
          (x+.065,.18,.13),(x+.038,.183,.15),(x-.038,.183,.15),(x-.065,.18,.13)],.018,"Steel","Foot."+label,.006)
    plate("Boot rush shin "+label,[(x-.041,.062,.225),(x+.041,.062,.225),
          (x+.045,.067,.335),(x,.075,.357),(x-.045,.067,.335)],.012,"Steel","Foot."+label,.005)
    for i in range(5):
        z=.17+i*.024
        y=.109-i*.009
        curve("Boot lacing "+label+str(i),[(x-.038,y,z),(x,y+.006,z+.014),(x+.038,y,z)],.0023,"LeatherDark","Foot."+label)
    for i in range(5):
        box("Sole tread "+label+str(i),(x,.155-i*.055,.022),(.163,.018,.028),"Rubber","Foot."+label,.002)
    for dx in [-.058,.058]:
        disk("Boot rivet "+label+str(dx),(x+dx,.076,.32),.004,.004,"Silver","Foot."+label,12)


def clothing():
    # One continuous wraparound shell, with an intentional front opening.
    zs=[1.155,1.19,1.27,1.36,1.435,1.48]
    radii=[(.133,.095),(.15,.105),(.184,.115),(.202,.119),(.214,.103),(.194,.083)]
    verts=[]
    count=49
    for i,(z,(rx,ry)) in enumerate(zip(zs,radii)):
        for j in range(count):
            t=math.pi/2+.35+(TAU-.7)*j/(count-1)
            verts.append((rx*math.cos(t),ry*math.sin(t),z+(.012*math.cos(t) if i==0 else 0)))
    faces=[(i*count+j,i*count+j+1,(i+1)*count+j+1,(i+1)*count+j)
           for i in range(len(zs)-1) for j in range(count-1)]
    jacket=mesh("Curved cropped jacket shell",verts,faces,"Burgundy","Jacket.Torso")
    solid=jacket.modifiers.new("Leather thickness","SOLIDIFY")
    solid.thickness=.008
    for s,label in [(-1,"R"),(1,"L")]:
        plate("Asymmetric lapel "+label,[(s*.045,.113,1.22),(s*.123,.116,1.36),
              (s*.104,.091,1.49),(s*.041,.075,1.50),(s*.071,.126,1.36)],.012,"Lapel","Jacket.Torso",.004)
        curve("Lapel rolled edge "+label,[(s*.041,.083,1.50),(s*.106,.10,1.48),
              (s*.127,.124,1.36),(s*.045,.121,1.22)],.002,"Seam","Jacket.Torso")
        curve("Jacket bottom seam "+label,[(s*.048,.091,1.164),(s*.108,.065,1.166),
              (s*.133,0,1.166),(s*.07,-.08,1.166)],.0016,"Seam","Jacket.Torso")
    curve("Silver zipper tape",[(.049,.103,1.175),(.055,.114,1.27),(.066,.12,1.35)],.002,"Steel","Jacket.Torso")
    for i in range(13):
        box("Zipper tooth %02d"%i,(.050+i*.0011,.116,1.18+i*.012),(.008,.004,.0035),"Silver","Jacket.Torso",.0007)
    box("Zipper pull",(.052,.122,1.205),(.013,.005,.026),"Silver","Jacket.Torso",.002)
    # Shearling collar is a tailored band with tapered tufts, rather than fur spheres.
    for i in range(23):
        t=math.pi*.05 + math.pi*1.9*i/22
        x,y=.117*math.cos(t),.073*math.sin(t)
        if y>.035 and abs(x)<.065:
            continue
        sweep("Collar shearling %02d"%i,[(x*.7,y*.7,1.501),(x,y,1.535),
              (x*1.30,y*1.26,1.515)], [.017,.022,.001],[.01,.014,.001],"Shearling","Jacket.Torso",8,3)
    loft("Utility belt",[(0,0,1.007,.172,.113),(0,0,1.055,.157,.105)],"LeatherDark","Pelvis",32)
    for x in [-.16,-.095,.095,.16]:
        box("Belt loop "+str(x),(x,.072 if abs(x)>.1 else .101,1.032),(.015,.014,.066),"Burgundy","Pelvis",.002)
    # Rectangular open buckle with a silver fang inset.
    for x,z,size in [(-.029,1.031,(.010,.014,.051)),(.029,1.031,(.010,.014,.051)),
                     (0,1.053,(.060,.014,.010)),(0,1.010,(.060,.014,.010))]:
        box("Belt buckle",(x,.121,z),size,"Brass","Pelvis",.002)
    plate("Hunter fang buckle",[(-.010,.133,1.045),(.010,.133,1.045),(0,.137,1.018)],.004,"Silver","Pelvis",.001)
    curve("Diagonal hunter harness",[(-.155,.088,1.46),(-.085,.140,1.34),
          (.028,.129,1.20),(.155,.09,1.065)],.013,"LeatherBrown","Jacket.Torso")
    curve("Harness centre stitch",[(-.155,.103,1.46),(-.085,.154,1.34),
          (.028,.143,1.20),(.155,.104,1.065)],.0009,"Seam","Jacket.Torso")
    plate("Harness silver clasp",[(-.086,.154,1.335),(-.060,.151,1.315),
          (-.042,.153,1.335),(-.067,.155,1.356)],.007,"Silver","Jacket.Torso",.002)
    # Belt pouch follows the hip, with a shaped flap and restrained fastenings.
    pouch=box("Utility pouch",(-.174,.006,.965),(.086,.10,.135),"LeatherBrown","Pelvis",.012)
    plate("Pouch curved flap",[(-.215,.063,1.016),(-.133,.063,1.016),(-.139,.071,.967),
          (-.175,.075,.954),(-.209,.071,.967)],.008,"LeatherDark","Pelvis",.004)
    disk("Pouch snap",(-.175,.083,.975),.006,.006,"Brass","Pelvis",16)


def face_y(x,z):
    return .087*math.sqrt(max(.08,1-(x/.109)**2)) + .004


def legacy_face():
    loft("Sculpted head",[(0,.008,1.603,.031,.041),(0,.010,1.625,.055,.055),
         (0,.007,1.65,.076,.067),(0,.002,1.69,.092,.077),
         (0,0,1.725,.105,.086),(0,-.004,1.755,.106,.088),
         (0,-.007,1.79,.102,.085),(0,-.009,1.825,.097,.080),
         (0,-.010,1.86,.085,.071),(0,-.012,1.886,.059,.051),
         (0,-.013,1.897,.012,.015)],"Skin","Head",40)
    # Closed, smoothly tapered bridge/tip avoids a separate patch's visible open seam.
    loft("Shaped nose bridge and tip",[(0,.096,1.705,.010,.008),
         (0,.108,1.713,.014,.012),(0,.110,1.722,.012,.016),
         (0,.098,1.742,.008,.010),(0,.084,1.763,.005,.005)],"Skin","Head",20)
    for s,label in [(-1,"R"),(1,"L")]:
        curve("Nostril "+label,[(s*.006,.113,1.707),(s*.011,.110,1.709),(s*.012,.103,1.711)],.001,"SkinShadow","Head")
        eye(s,label)
        # Ear pinna and inset, mostly framed by sideburns.
        loft("Ear "+label,[(s*.103,-.004,1.69,.010,.017),(s*.114,.002,1.715,.015,.022),
             (s*.112,.002,1.755,.016,.025),(s*.105,-.002,1.775,.008,.014)],"Skin","Head",16)
        curve("Ear fold "+label,[(s*.117,.020,1.758),(s*.123,.020,1.735),(s*.116,.018,1.713)],.002,"SkinShadow","Head")
        curve("Gold earring "+label,[(s*.116,.012,1.705),(s*.126,.024,1.685),(s*.115,.030,1.673)],.002,"Brass","Head")
        plate("Earring fang "+label,[(s*.117,.029,1.681),(s*.127,.029,1.671),
              (s*.118,.033,1.641),(s*.111,.03,1.665)],.006,"Bone","Head",.001)
        for i in range(7):
            x=s*(.027+i*.008+RNG.uniform(-.002,.002))
            z=1.728+RNG.uniform(-.007,.008)
            disk("Freckle %s %d"%(label,i),(x,face_y(x,z)+.003,z),.0009+RNG.random()*.0005,.0008,"Freckle","Head",8)
    # Lips follow a small cupid bow; the mouth is not a flat painted rectangle.
    curve("Upper lip",[(-.027,.072,1.675),(-.010,.082,1.678),(0,.084,1.676),
          (.009,.082,1.679),(.027,.072,1.676)],.0017,"Lips","Head")
    curve("Lower lip",[(-.025,.074,1.674),(0,.085,1.670),(.025,.074,1.675)],.0018,"LipLight","Head")
    curve("Mouth opening",[(-.026,.074,1.674),(0,.086,1.674),(.027,.074,1.675)],.0007,"Mouth","Head")


def eye(s,label):
    cx=s*.047
    # Shallow almond patch, fitted to the curved face rather than a protruding sphere.
    n=32
    verts=[(cx,face_y(cx,1.755)+.010,1.756)]
    rim=[]
    for i in range(n):
        t=TAU*i/n
        x=cx+.031*math.cos(t)
        z=1.754+(.008 if math.sin(t)>0 else .005)*math.sin(t)+s*(x-cx)*.075
        rim.append((x,face_y(x,z)+.004,z))
    verts+=rim
    mesh("Almond eye white "+label,verts,[(0,(i+1)%n+1,i+1) for i in range(n)],"EyeWhite","Head")
    y=face_y(cx,1.756)+.012
    disk("Jade iris "+label,(cx,y,1.756),.0085,.0070,"Iris","Head",32)
    disk("Iris inner gold "+label,(cx,y+.0006,1.756),.0055,.0058,"IrisGold","Head",24)
    disk("Pupil "+label,(cx,y+.0012,1.756),.0033,.0050,"Mouth","Head",24)
    disk("Eye highlight "+label,(cx-.0028,y+.0018,1.760),.002,.002,"EyeWhite","Head",16)
    upper=[]
    for i in range(9):
        t=math.pi*i/8
        x=cx+.031*math.cos(t)
        z=1.754+.008*math.sin(t)+s*(x-cx)*.075
        upper.append((x,face_y(x,z)+.005,z))
    curve("Upper eyeliner "+label,upper,.0017,"Hair","Head")
    curve("Lower lash "+label,[rim[i] for i in range(16,32,3)],.0006,"SkinShadow","Head")
    outer=cx+s*.031
    curve("Lash wing "+label,[(outer,face_y(outer,1.757)+.006,1.757),
          (outer+s*.009,face_y(outer,1.757)+.004,1.764)],.0012,"Hair","Head")
    curve("Expressive brow "+label,[(s*.020,.087,1.779),(s*.045,.083,1.785),
          (s*.074,.069,1.784),(s*.083,.057,1.777)],.0035,"Hair","Head")


def face(config=None):
    slayer_face.build(sys.modules[__name__], config)
    # Preserve the original ear, earring and fang accessory construction exactly.
    for s,label in [(-1,"R"),(1,"L")]:
        loft("Ear "+label,[(s*.103,-.004,1.69,.010,.017),(s*.114,.002,1.715,.015,.022),
             (s*.112,.002,1.755,.016,.025),(s*.105,-.002,1.775,.008,.014)],"Skin","Head",16)
        curve("Ear fold "+label,[(s*.117,.020,1.758),(s*.123,.020,1.735),(s*.116,.018,1.713)],.002,"SkinShadow","Head")
        curve("Gold earring "+label,[(s*.116,.012,1.705),(s*.126,.024,1.685),(s*.115,.030,1.673)],.002,"Brass","Head")
        plate("Earring fang "+label,[(s*.117,.029,1.681),(s*.127,.029,1.671),
              (s*.118,.033,1.641),(s*.111,.03,1.665)],.006,"Bone","Head",.001)


def hair():
    # Scalp surface with a shaped hairline: short nape, higher brow opening.
    sides, rings=48,14
    verts=[]
    for i in range(rings):
        for j in range(sides):
            t=TAU*j/sides
            front=max(0,math.sin(t))
            end_phi=2.43-front*1.12
            phi=.035+(end_phi-.035)*i/(rings-1)
            verts.append((.115*math.sin(phi)*math.cos(t),
                          -.016+.098*math.sin(phi)*math.sin(t),1.795+.139*math.cos(phi)))
    faces=[(i*sides+j,i*sides+(j+1)%sides,(i+1)*sides+(j+1)%sides,(i+1)*sides+j)
           for i in range(rings-1) for j in range(sides)]
    mesh("Cohesive shag scalp",verts,faces,"Hair","Hair")
    # Layered nape and sides flare slightly but stay rooted in the scalp.
    for i in range(23):
        t=TAU*i/23
        if .22*math.pi<t<.78*math.pi:
            continue
        c,s=math.cos(t),math.sin(t)
        z=1.84+RNG.uniform(-.025,.025)
        pts=[(.068*c,-.014+.06*s,z),(.112*c,-.016+.093*s,z-.055),
             (.137*c,-.014+.115*s,z-.13),(.170*c,-.005+.133*s,z-.16+RNG.uniform(-.025,.025))]
        sweep("Shag outer clump %02d"%i,pts,[.012,.027,.019,.0004],
              [.003,.006,.004,.0003],"HairBlue" if i%4==0 else "Hair","Hair",8,5)
    # Crown layers overlap the base cap so rear/side views do not read as a helmet.
    for i in range(15):
        t=math.pi*.9+math.pi*1.25*i/14
        c,ss=math.cos(t),math.sin(t)
        pts=[(.012*c,-.015+.015*ss,1.923),(.069*c,-.016+.056*ss,1.914),
             (.105*c,-.016+.088*ss,1.848),(.134*c,-.012+.112*ss,1.765+RNG.uniform(-.018,.018))]
        sweep("Layered crown %02d"%i,pts,[.006,.028,.025,.0004],
              [.002,.005,.006,.0003],"HairBlue" if i%5==0 else "Hair","Hair",10,5)
    # Swept fringe covers one eye; varied depth prevents a helmet or uniform fringe.
    for i in range(6):
        offset=(i-2.5)*.013
        pts=[(-.052+offset,-.002,1.917-abs(offset)*.25),
             (-.014+offset,.075,1.897),(.040+offset*.8,.102+math.sin(i)*.003,1.823+math.sin(i)*.005),
             (.077+offset*.65,.096,1.750+math.sin(i*.9)*.012),(.115+offset*.7,.073,1.720+math.cos(i)*.016)]
        sweep("Asymmetric fringe %02d"%i,pts,[.012,.026,.032,.020,.0003],
              [.004,.009,.010,.007,.0003],"HairBlue" if i in [0,4] else "Hair","Hair",12,6)
    # Opposite temple stays open, with a strong curled cheek framing lock.
    for i in range(4):
        d=i*.008
        sweep("Open temple curl %d"%i,[(-.063-d,.038,1.886),(-.105-d,.067,1.81),
              (-.108-d,.061,1.735),(-.133-d,.08,1.718)],
              [.010,.024,.021,.0004],[.005,.009,.009,.0004],"HairBlue" if i==0 else "Hair","Hair",8,5)
    for i in range(4):
        d=(i-1.5)*.015
        sweep("Crown flick %d"%i,[(d-.01,-.025,1.914),(d-.025,-.018,1.941),
              (d-.065,-.008,1.945+i*.007),(d-.092,.008,1.931+i*.004)],
              [.015,.018,.008,.0003],[.007,.008,.005,.0003],"Hair","Hair",8,4)


def knife(name, x, y, z, group="Pelvis", angle=0):
    # Knives point down from belt; blade and grip use a shared design language.
    objs=[]
    objs.append(plate(name+" silver blade",[(x-.024,y,z),(x+.024,y,z),
                (x+.027,y,z-.085),(x,y,z-.185),(x-.027,y,z-.085)],.010,"Silver",group,.001))
    objs.append(box(name+" guard",(x,y,z+.004),(.069,.026,.019),"Silver",group,.002))
    objs.append(box(name+" wrapped grip",(x,y,z+.055),(.025,.023,.085),"LeatherDark",group,.003))
    for i in range(4):
        objs.append(box(name+" grip rib"+str(i),(x,y,z+.025+i*.018),(.030,.027,.007),"LeatherBrown",group,.001))
    objs.append(box(name+" pommel",(x,y,z+.104),(.032,.029,.017),"Silver",group,.002))
    if angle:
        origin=Vector((x,y,z))
        from mathutils import Matrix
        rot=Matrix.Rotation(angle,4,"Y")
        for obj in objs:
            if obj.type=="MESH":
                for v in obj.data.vertices:
                    v.co=origin+rot.to_3x3()@(v.co-origin)


def equipment():
    for i in range(3):
        x=.100+i*.055
        plate("Knife sheath %d"%i,[(x-.029,.101,1.025),(x+.029,.101,1.025),
              (x+.025,.105,.87),(x-.014,.105,.846),(x-.031,.101,.89)],.022,"LeatherDark","Pelvis",.003)
        knife("Belt silver knife %d"%i,x,.123,1.02)
        box("Sheath retention strap %d"%i,(x,.147,.985),(.063,.009,.019),"LeatherBrown","Pelvis",.002)
    shotgun()
    axe()


def shotgun():
    x,y=-.446,.086
    group="Shotgun"
    plate("Shotgun sculpted stock",[(x-.038,y,.55),(x+.038,y,.55),(x+.034,y,.70),
          (x+.016,y,.87),(x+.025,y,.99),(x-.026,y,.99),(x-.030,y,.79)],.070,"GunWood",group,.008)
    box("Shotgun stock heel",(x,y,.557),(.083,.081,.034),"Rubber",group,.004)
    box("Shotgun receiver",(x,y,1.036),(.077,.080,.174),"Steel",group,.008)
    loft("Shotgun barrel",[(x,y,1.09,.018,.018),(x,y,1.65,.018,.018)],"Steel",group,20)
    loft("Muzzle polished crown",[(x,y,1.625,.022,.022),(x,y,1.66,.022,.022)],"Silver",group,20)
    loft("Muzzle dark bore",[(x,y,1.661,.014,.014),(x,y,1.663,.014,.014)],"Mouth",group,20)
    loft("Tubular magazine",[(x+.039,y,1.10,.014,.014),(x+.039,y,1.45,.014,.014)],"Steel",group,16)
    box("Pump fore-end",(x+.017,y,1.27),(.078,.078,.19),"GunWood",group,.009)
    for i in range(7):
        box("Pump groove %d"%i,(x+.017,y+.041,1.195+i*.023),(.075,.006,.006),"LeatherDark",group,.001)
    box("Receiver silver sideplate",(x,y+.043,1.052),(.055,.006,.10),"Silver",group,.003)
    box("Ejection port",(x,y+.048,1.065),(.035,.004,.049),"Mouth",group,.002)
    curve("Shotgun trigger guard",[(x+.028,y+.025,1.007),(x+.075,y+.025,1.00),
          (x+.077,y+.025,.954),(x+.024,y+.025,.949)],.006,"Steel",group)
    curve("Shotgun trigger",[(x+.034,y+.028,.996),(x+.053,y+.028,.976)],.003,"Silver",group)
    box("Raised front sight",(x-.004,y+.023,1.614),(.012,.018,.020),"Silver",group,.002)


def axe():
    # Author in weapon-local coordinates, then mount diagonally across the back.
    before=len(PARTS)
    group="BackAxe"
    loft("Axe dark steel shaft",[(0,0,-.52,.022,.022),(0,0,.47,.022,.022)],"Steel",group,16)
    loft("Axe leather wrapped grip",[(0,0,-.48,.032,.030),(0,0,-.18,.032,.030)],"LeatherBrown",group,16)
    for i in range(8):
        loft("Axe grip wrap %d"%i,[(0,0,-.47+i*.036,.034,.032),(0,0,-.46+i*.036,.034,.032)],"Burgundy",group,12)
    for z in [-.50,-.17,.13,.43]:
        loft("Axe silver collar "+str(z),[(0,0,z,.034,.032),(0,0,z+.022,.034,.032)],"Silver",group,16)
    for s in [-1,1]:
        plate("Axe dark blade "+str(s),[(s*.025,0,.405),(s*.235,0,.53),
              (s*.325,0,.43),(s*.31,0,.20),(s*.18,0,.155),(s*.035,0,.26)],.065,"Steel",group,.008)
        plate("Axe polished cutting bevel "+str(s),[(s*.235,0,.53),(s*.325,0,.43),
              (s*.31,0,.20),(s*.18,0,.155),(s*.24,0,.24),(s*.26,0,.41)],.075,"Silver",group,.003)
    box("Axe sculpted hub",(0,0,.342),(.103,.104,.145),"Silver",group,.009)
    plate("Axe restrained violet rune",[(-.023,.056,.36),(0,.057,.40),(.023,.056,.36),(0,.057,.30)],.006,"Magic",group,.002)
    from mathutils import Matrix
    rot=Matrix.Rotation(-.48,3,"Y")
    origin=Vector((0,-.16,1.11))
    for obj in PARTS[before:]:
        for v in obj.data.vertices:
            v.co=origin+rot@v.co
    curve("Back axe sling",[(-.15,-.10,1.43),(-.075,-.168,1.22),(.12,-.13,1.02)],.018,"LeatherBrown","Jacket.Torso")
    box("Back sling retainer",(.03,-.191,1.18),(.12,.025,.07),"LeatherDark","Jacket.Torso",.007)


def setup_materials():
    mat("Skin","CE9D87",.58)
    mat("SkinShadow","865948",.65)
    mat("Freckle","8E5144",.75)
    mat("Lips","8E4B51",.45)
    mat("LipLight","AD6B68",.43)
    mat("Mouth","211A25",.5)
    mat("EyeWhite","DED9C7",.32)
    mat("Iris","457E78",.35)
    mat("IrisGold","638270",.35)
    mat("Hair","111721",.50)
    mat("HairBlue","202735",.50)
    mat("Burgundy","542039",.51)
    mat("Lapel","73364F",.51)
    mat("Cloth","1C1E26",.85)
    mat("Seam","AB7C76",.65)
    mat("LeatherDark","302A2D",.58)
    mat("LeatherBrown","735342",.54)
    mat("BootLeather","252731",.48)
    mat("Glove","343039",.62)
    mat("Rubber","171C23",.9)
    mat("Silver","C0CDD4",.29,.75)
    mat("Steel","343E4B",.35,.65)
    mat("Brass","B69764",.38,.65)
    mat("Bone","DBCCAC",.58)
    mat("Shearling","D3C7B4",.95)
    mat("GunWood","4B3039",.48)
    mat("Magic","9A719D",.4,.15,.25)


def unify_trousers():
    """Fuse the lofted pelvis/legs into continuous cloth, without cap intersections."""
    names=["Trouser waist and pelvis","Tailored thigh L","Tailored thigh R","Shaped calf L","Shaped calf R"]
    pieces=[bpy.data.objects[name] for name in names]
    bpy.ops.object.select_all(action="DESELECT")
    for obj in pieces:
        obj.select_set(True)
        PARTS.remove(obj)
    bpy.context.view_layer.objects.active=pieces[0]
    bpy.ops.object.join()
    obj=bpy.context.object
    obj.name="Continuous tailored trousers"
    remesh=obj.modifiers.new("Continuous cloth topology","REMESH")
    remesh.mode="VOXEL"
    remesh.voxel_size=.007
    remesh.use_smooth_shade=True
    bpy.ops.object.modifier_apply(modifier=remesh.name)
    smooth=obj.modifiers.new("Soften tailored transitions","SMOOTH")
    smooth.factor=.5
    smooth.iterations=4
    bpy.ops.object.modifier_apply(modifier=smooth.name)
    decimate=obj.modifiers.new("Cloth export budget","DECIMATE")
    decimate.ratio=.32
    decimate.use_collapse_triangulate=True
    bpy.ops.object.modifier_apply(modifier=decimate.name)
    PARTS.append(obj)


def bounds(objects):
    bpy.context.view_layer.update()
    deps=bpy.context.evaluated_depsgraph_get()
    points=[]
    for obj in objects:
        if obj.type not in {"MESH","CURVE"}: continue
        evaluated=obj.evaluated_get(deps)
        data=evaluated.to_mesh()
        points.extend(evaluated.matrix_world@vertex.co for vertex in data.vertices)
        evaluated.to_mesh_clear()
    return [min(p[i] for p in points) for i in range(3)], [max(p[i] for p in points) for i in range(3)]


def aim(obj, at):
    obj.rotation_euler=(Vector(at)-obj.location).to_track_quat("-Z","Y").to_euler()


def studio():
    global CHAR
    stage=bpy.data.collections.new("Studio - excluded from GLB")
    bpy.context.scene.collection.children.link(stage)
    def stage_obj(obj):
        for collection in list(obj.users_collection): collection.objects.unlink(obj)
        stage.objects.link(obj)
    bpy.ops.mesh.primitive_plane_add(size=200, location=(0,0,-.006))
    ground=bpy.context.object
    ground.name="Studio floor"
    ground.data.materials.append(mat("Studio","25303C",.8))
    stage_obj(ground)
    for name,position,energy,size,colour in [
        ("Key softbox",(2.5,3.8,4.8),450,4.0,(1,.87,.78)),
        ("Cool fill",(-3,2.0,2.4),250,3.0,(.68,.81,1)),
        ("Rim strip",(1.2,-2.5,3.4),350,2.5,(.90,.77,1)),
        ("Face bounce",(0,3,1.75),40,1.5,(1,.93,.87))]:
        data=bpy.data.lights.new(name,"AREA")
        data.energy, data.shape, data.size=energy,"DISK",size
        data.color=colour
        obj=bpy.data.objects.new(name,data)
        stage.objects.link(obj)
        obj.location=position
        aim(obj,(0,0,1))
    data=bpy.data.cameras.new("Preview Camera")
    camera=bpy.data.objects.new("Preview Camera",data)
    stage.objects.link(camera)
    bpy.context.scene.camera=camera
    scene=bpy.context.scene
    scene.render.engine="CYCLES"
    scene.cycles.samples=48
    scene.cycles.use_denoising=True
    scene.render.resolution_x=1000
    scene.render.resolution_y=1200
    scene.render.resolution_percentage=100
    scene.render.image_settings.file_format="PNG"
    scene.world.use_nodes=True
    background=scene.world.node_tree.nodes.get("Background")
    background.inputs["Color"].default_value=(.009,.014,.023,1)
    background.inputs["Strength"].default_value=.35
    scene.view_settings.view_transform="AgX"
    scene.render.film_transparent=False
    # GPU if supported, CPU fallback remains reproducible.
    try:
        prefs=bpy.context.preferences.addons["cycles"].preferences
        prefs.compute_device_type="OPTIX"
        prefs.get_devices()
        for device in prefs.devices: device.use=device.type!="CPU"
        if any(d.use for d in prefs.devices): scene.cycles.device="GPU"
    except Exception:
        pass
    return camera


def render_previews(camera, names=None, samples=None):
    scene=bpy.context.scene
    if samples: scene.cycles.samples=samples
    try:
        prefs=bpy.context.preferences.addons["cycles"].preferences
        prefs.compute_device_type="OPTIX"
        prefs.get_devices()
        for device in prefs.devices: device.use=device.type!="CPU"
        if any(d.use for d in prefs.devices): scene.cycles.device="GPU"
    except Exception:
        scene.cycles.device="CPU"
    views={
        "front":((0,5,1.12),(0,0,.96),"ORTHO",2.22),
        "side":((5,0,1.12),(0,0,.96),"ORTHO",2.22),
        "back":((0,-5,1.12),(0,0,.96),"ORTHO",2.22),
        "three-quarter":((2.7,4.6,2.1),(0,0,1.00),"PERSP",2.22),
        "face":((-.42,2.1,1.76),(0,.015,1.72),"ORTHO",.53),
        "equipment":((1.7,3.9,1.60),(0,.02,1.16),"ORTHO",1.10),
        "face-neutral":((0,2.1,1.73),(0,.015,1.72),"ORTHO",.40),
        "face-three-quarter":((-.9,1.7,1.76),(0,.015,1.72),"ORTHO",.43),
        "face-profile":((-2,.02,1.74),(0,.015,1.72),"ORTHO",.43),
        "face-smile":((-.35,2.1,1.75),(0,.015,1.72),"ORTHO",.40),
        "face-determined":((-.35,2.1,1.75),(0,.015,1.72),"ORTHO",.40),
        # Front-facing inspection at PlayerController's normal 3 m arm / 82 deg FOV,
        # 0.65 m shoulder, 1.75 m pivot and -0.12 rad pitch. No live camera edit.
        "gameplay-distance":((.65,3*math.cos(.12),1.75+3*math.sin(.12)),(.65,0,1.75),"PERSP",2.22),
        "face-relaxed":((-.35,2.1,1.75),(0,.015,1.72),"ORTHO",.40),
        "face-focused":((-.35,2.1,1.75),(0,.015,1.72),"ORTHO",.40),
        "face-smirk":((-.35,2.1,1.75),(0,.015,1.72),"ORTHO",.40),
        "face-blink":((0,2.1,1.73),(0,.015,1.72),"ORTHO",.40),
        "face-open-mouth":((0,2.1,1.73),(0,.015,1.72),"ORTHO",.40),
    }
    keys=bpy.data.objects.get("Slayer expressive face").data.shape_keys.key_blocks
    for name,(position,target,mode,scale) in views.items():
        if names and name not in names: continue
        camera.location=position
        aim(camera,target)
        camera.data.type=mode
        camera.data.ortho_scale=scale
        camera.data.lens=62
        camera.data.sensor_fit="AUTO"
        scene.render.resolution_x,scene.render.resolution_y=1000,1200
        if name=="gameplay-distance":
            scene.render.resolution_x,scene.render.resolution_y=1440,900
            camera.data.sensor_fit="VERTICAL"
            camera.data.sensor_height=24
            camera.data.lens=12/math.tan(math.radians(82)/2)
        for key in keys: key.value=0
        if name=="face-smile": keys["Smile"].value=1; keys["BrowRaise"].value=.25
        if name=="face-determined": keys["BrowLower"].value=1; keys["Frown"].value=.55
        if name=="face-relaxed": keys["Relaxed"].value=1
        if name=="face-focused": keys["Focused"].value=1
        if name=="face-smirk": keys["Smirk"].value=1
        if name=="face-blink": keys["Blink"].value=1
        if name=="face-open-mouth": keys["MouthOpen"].value=1
        # The held barrel crosses the jaw in an exact side projection. Exclude tools
        # only from face inspection renders; full-character renders/export retain them.
        hidden={obj:obj.hide_render for obj in PARTS if obj["rig_group"] in {"Shotgun","BackAxe"}}
        if name.startswith("face-"):
            for obj in hidden: obj.hide_render=True
        scene.render.filepath=str(PREVIEWS/(name+".png"))
        bpy.ops.render.render(write_still=True)
        for obj,value in hidden.items(): obj.hide_render=value
    for key in keys: key.value=0
    scene.render.resolution_x,scene.render.resolution_y=1000,1200
    camera.data.sensor_fit="AUTO"


def export_asset():
    # Preserve editable source components in .blend, join only temporary GLB copies.
    for original in PARTS:
        if original.type=="MESH" and original.data.shape_keys:
            for key in original.data.shape_keys.key_blocks: key.value=0.0
    bpy.ops.object.select_all(action="DESELECT")
    copies=[]
    groups={}
    for original in PARTS:
        duplicate=original.copy()
        duplicate.data=original.data.copy()
        bpy.context.collection.objects.link(duplicate)
        duplicate.parent=None
        duplicate.matrix_world=original.matrix_world.copy()
        duplicate.select_set(True)
        bpy.context.view_layer.objects.active=duplicate
        # Converting a morph mesh or applying topology modifiers destroys its keys.
        if not (duplicate.type=="MESH" and duplicate.data.shape_keys):
            bpy.ops.object.convert(target="MESH")
        duplicate=bpy.context.object
        for modifier in list(duplicate.modifiers):
            bpy.ops.object.modifier_apply(modifier=modifier.name)
        # Stable box-projected UV charts let Godot generate morph tangents. These
        # are temporary export UVs, not an authored texture atlas or geometry edit.
        if not duplicate.data.uv_layers:
            uv=duplicate.data.uv_layers.new(name="ExportUV")
            for polygon in duplicate.data.polygons:
                dominant=max(range(3),key=lambda axis:abs(polygon.normal[axis]))
                axes=[axis for axis in range(3) if axis!=dominant]
                for loop_index in polygon.loop_indices:
                    point=duplicate.data.vertices[duplicate.data.loops[loop_index].vertex_index].co
                    uv.data[loop_index].uv=(point[axes[0]],point[axes[1]])
        duplicate.select_set(False)
        groups.setdefault(original["rig_group"],[]).append(duplicate)
    for name, group in groups.items():
        bpy.ops.object.select_all(action="DESELECT")
        for obj in group: obj.select_set(True)
        bpy.context.view_layer.objects.active=group[0]
        if len(group)>1: bpy.ops.object.join()
        joined=bpy.context.object
        joined.name="Slayer_"+name
        copies.append(joined)
    bpy.ops.object.select_all(action="DESELECT")
    for obj in copies: obj.select_set(True)
    # Empty exported markers make bounds/facing verification explicit in Godot.
    markers=[]
    for name,location in [("Slayer_Forward",(0,.35*CHAR.scale.x,1.0*CHAR.scale.x)),
                          ("Slayer_Ground",(0,0,0))]:
        obj=bpy.data.objects.new(name,None)
        bpy.context.collection.objects.link(obj)
        obj.location=location
        obj.select_set(True)
        markers.append(obj)
    bpy.ops.export_scene.gltf(filepath=str(OUT/"slayer.glb"),export_format="GLB",
        use_selection=True,export_yup=True,export_apply=False,export_animations=False,
        export_morph=True,export_morph_normal=True,
        export_cameras=False,export_lights=False,export_materials="EXPORT")
    # Validate the actual baked export geometry using Blender's mesh validator.
    for obj in copies:
        if obj.data.validate(verbose=True,clean_customdata=False):
            raise RuntimeError("Invalid generated mesh was repaired: "+obj.name)
        if not all(math.isfinite(axis) for vertex in obj.data.vertices for axis in vertex.co):
            raise RuntimeError("Non-finite exported vertex: "+obj.name)
    # Inspect evaluated export meshes, not nominal pre-modifier counts.
    triangles=sum(sum(len(p.vertices)-2 for p in obj.data.polygons) for obj in copies)
    info={"blender":bpy.app.version_string,"source_objects":len(PARTS),
          "export_meshes":len(copies),"triangles":triangles,"materials":len(MATS)-1,
          "bounds_blender":bounds(copies),"facing_blender":"+Y","facing_godot":"-Z",
          "height_m":1.9,"rigged":False,"generated_with_seed":7419,
          "blender_mesh_validation_passed":True,
          "facial_shape_keys":list(slayer_face.KEYS),
          "face_config":json.loads(bpy.data.objects["Slayer expressive face"]["face_config"])}
    (OUT/"model-report.json").write_text(json.dumps(info,indent=2)+"\n")
    for obj in copies+markers: bpy.data.objects.remove(obj,do_unlink=True)


FRAMING_PREFIXES=("Asymmetric fringe ","Open temple curl ")


def adjust_front_hair():
    """Idempotent face-framing edit; rest coordinates retained in the editable mesh."""
    for obj in PARTS:
        if not obj.name.startswith(FRAMING_PREFIXES): continue
        rest=obj.data.attributes.get("SlayerFramingRest")
        if rest is None:
            rest=obj.data.attributes.new("SlayerFramingRest","FLOAT_VECTOR","POINT")
            for value,vertex in zip(rest.data,obj.data.vertices): value.vector=vertex.co
        for vertex,value in zip(obj.data.vertices,rest.data):
            x,y,z=value.vector
            weight=math.exp(-((z-1.785)/.070)**2)
            if obj.name.startswith("Open temple"):
                # Open the exposed brow and outer canthus without changing the tips.
                x-=.007*weight; y-=.002*weight
            else:
                # Sweep the dominant fringe a little farther toward the concealed eye.
                x+=.006*weight; y-=.002*weight
            vertex.co=(x,y,z)
        obj.data.update()


def preserved_fingerprint():
    result={}
    depsgraph=bpy.context.evaluated_depsgraph_get()
    for obj in PARTS:
        if obj["rig_group"]=="Face" or obj.name.startswith(FRAMING_PREFIXES): continue
        if obj["rig_group"]=="Head" and not obj.name.startswith(("Ear ","Ear fold ","Gold earring ","Earring fang ")): continue
        evaluated=obj.evaluated_get(depsgraph)
        data=evaluated.to_mesh()
        points=[tuple(round(v,8) for v in obj.matrix_world @ vertex.co) for vertex in data.vertices]
        topology=[tuple(p.vertices) for p in data.polygons]
        materials=[]
        for material in data.materials:
            if not material: continue
            bsdf=material.node_tree.nodes.get("Principled BSDF") if material.use_nodes else None
            materials.append([material.name,list(material.diffuse_color),
                bsdf.inputs["Roughness"].default_value if bsdf else None,
                bsdf.inputs["Metallic"].default_value if bsdf else None])
        result[obj.name]=hashlib.sha256(json.dumps([points,topology,materials]).encode()).hexdigest()
        evaluated.to_mesh_clear()
    return result


def main():
    global CHAR
    parser=argparse.ArgumentParser()
    parser.add_argument("--views",nargs="*")
    parser.add_argument("--samples",type=int,default=48)
    parser.add_argument("--face-only",action="store_true",help="Rebuild only the face in the saved editable asset")
    parser.add_argument("--face-config",type=Path,help="JSON overrides for slayer_face.FaceConfig")
    parser.add_argument("--skip-renders",action="store_true",help="Save/export only; keep existing preview images")
    args=parser.parse_args(sys.argv[sys.argv.index("--")+1:] if "--" in sys.argv else [])
    OUT.mkdir(parents=True,exist_ok=True)
    PREVIEWS.mkdir(exist_ok=True)
    bpy.context.preferences.filepaths.save_version=0
    config=slayer_face.FaceConfig(**(json.loads(args.face_config.read_text()) if args.face_config else {}))
    config.validate()
    if args.face_only:
        bpy.ops.wm.open_mainfile(filepath=str(OUT/"slayer.blend"))
        CHAR=bpy.data.objects["Slayer - editable modular source"]
        MATS.update({m.name:m for m in bpy.data.materials})
        PARTS.extend(o for o in bpy.data.objects if "rig_group" in o)
        before=preserved_fingerprint()
        adjust_front_hair()
        for obj in list(PARTS):
            if obj["rig_group"] in {"Face","Head"}:
                PARTS.remove(obj); bpy.data.objects.remove(obj,do_unlink=True)
        start=len(PARTS)
        face(config)
        for obj in PARTS[start:]: obj.location.z-=.035
        bpy.context.view_layer.update()
        after=preserved_fingerprint()
        if before!=after: raise RuntimeError("Face-only rebuild changed preserved geometry")
        (OUT/"face-preservation.json").write_text(json.dumps({"unchanged":True,"objects":len(before),
            "method":"SHA256 of evaluated world-space vertices, topology and material colour/roughness/metallic; includes original ears/earrings; excludes facial construction and ten explicitly permitted front hair clumps; rest coordinates retained in SlayerFramingRest",
            "adjusted_front_hair":[obj.name for obj in PARTS if obj.name.startswith(FRAMING_PREFIXES)],
            "object_hashes":after},indent=2)+"\n")
        camera=bpy.context.scene.camera
        bpy.ops.wm.save_as_mainfile(filepath=str(OUT/"slayer.blend"))
        export_asset()
        if not args.skip_renders: render_previews(camera,args.views,args.samples)
        bpy.ops.wm.save_as_mainfile(filepath=str(OUT/"slayer.blend"))
        print("SLAYER_FACE_COMPLETE",str(OUT),flush=True)
        return
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    bpy.context.preferences.filepaths.file_preview_type="NONE"
    bpy.context.preferences.filepaths.save_version=0
    setup_materials()
    CHAR=bpy.data.objects.new("Slayer - editable modular source",None)
    bpy.context.collection.objects.link(CHAR)
    CHAR["description"]="Original supernatural hunter. +Y front. Modular for future rigging."
    body()
    clothing()
    face(config)
    # Old face freckles consumed 42 random values. Keep the original hair seed stream.
    for _ in range(42): RNG.random()
    hair()
    equipment()
    adjust_front_hair()
    # Shorten the visible neck, retaining separate future-rig head/hair components.
    for obj in PARTS:
        if obj["rig_group"] in {"Head","Face","Hair"}:
            obj.location.z -= .035
    pelvis=bpy.data.objects.get("Trouser waist and pelvis")
    for vertex in pelvis.data.vertices:
        if abs(vertex.co.z-.87)<.001:
            weight=max(0,1-abs(vertex.co.x)/.095)
            vertex.co.y *= 1-.50*weight
            vertex.co.z += .075*weight
    pelvis.data.update()
    unify_trousers()
    neck=bpy.data.objects.get("Neck")
    for vertex in neck.data.vertices:
        vertex.co.z -= max(0,min(1,(vertex.co.z-1.48)/.12))*.035
    neck.data.update()
    minimum, maximum=bounds(PARTS)
    CHAR.scale=(1.9/(maximum[2]-minimum[2]),)*3
    CHAR.location.z=-minimum[2]*CHAR.scale.z
    bpy.context.view_layer.update()
    camera=studio()
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT/"slayer.blend"))
    export_asset()
    if not args.skip_renders: render_previews(camera,args.views,args.samples)
    # Save the three-quarter studio view as the scene's opening camera.
    camera.location=(2.7,4.6,2.1)
    aim(camera,(0,0,1))
    camera.data.type="PERSP"
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT/"slayer.blend"))
    print("SLAYER_ASSET_COMPLETE",str(OUT),flush=True)


if __name__=="__main__":
    main()
