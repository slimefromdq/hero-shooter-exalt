"""Original Slayer facial construction; all dimensions in metres, Blender +Y front.

No third-party character geometry or textures. The builder owns only the Face group.
Separate from outfit/hair construction; supports rebuilds in an existing .blend.
"""
from dataclasses import asdict, dataclass
import math
import random

import bpy
from mathutils import Vector


@dataclass
class FaceConfig:
    eye_scale: float = 1.25
    eye_width: float = .80
    eye_height: float = 1.15
    head_width: float = 1.055
    chin_lift: float = .0075
    eye_tilt: float = .11
    eye_spacing: float = .047
    iris_scale: float = 1.07
    eyebrow_angle: float = .12
    cheek_fullness: float = 1.12
    jaw_taper: float = .95
    nose_size: float = .90
    mouth_curvature: float = 1.15
    eyelid_thickness: float = .0008
    lip_fullness: float = 1.6

    def validate(self):
        limits = dict(eye_scale=(1,1.45), eye_tilt=(-.1,.25), eye_spacing=(.044,.052),
                      eye_width=(.7,1.15), eye_height=(.85,1.25), head_width=(.95,1.09), chin_lift=(0,.012),
                      iris_scale=(.75,1.15), eyebrow_angle=(-.1,.3), cheek_fullness=(.7,1.3),
                      jaw_taper=(.8,1.2), nose_size=(.7,1.2), mouth_curvature=(0,1.5),
                      eyelid_thickness=(.0008,.0022), lip_fullness=(1.0,2.0))
        for name, (lo,hi) in limits.items():
            value = getattr(self,name)
            if not math.isfinite(value) or not lo <= value <= hi:
                raise ValueError(f"{name} must be finite and in [{lo}, {hi}]")
        if self.eye_spacing-.031*self.eye_scale*self.eye_width < .004:
            raise ValueError("Eye spacing/scale must leave at least 8 mm between inner corners")


KEYS = ("Blink", "BrowRaise", "BrowLower", "Smile", "Frown", "MouthOpen")


def gaussian(x, mean, width):
    return math.exp(-((x-mean)/width)**2)


class FaceBuilder:
    def __init__(self, api, config):
        config.validate()
        self.api, self.c = api, config
        self.verts, self.faces, self.materials, self.tags = [], [], [], []
        self.names = []
        self.rng = random.Random(92741)  # Independent of hair and all gameplay RNG.

    def vertex(self, point, tag="skin"):
        self.verts.append(tuple(point)); self.tags.append(tag)
        return len(self.verts)-1

    def polygon(self, indices, material):
        if material not in self.names: self.names.append(material)
        self.faces.append(tuple(indices)); self.materials.append(self.names.index(material))

    def section(self, z):
        # Dense Catmull interpolation gives a rounded chin and readable cheek planes.
        sections=[(1.603,.026,.037,.008),(1.622,.048,.051,.009),
                  (1.649,.068,.065,.007),(1.683,.084,.075,.003),
                  (1.718,.099,.084,0),(1.752,.107,.087,-.004),
                  (1.790,.104,.086,-.007),(1.827,.098,.082,-.009),
                  (1.862,.084,.071,-.011),(1.887,.058,.050,-.012),
                  (1.898,.003,.004,-.013)]
        # Lift the chin while leaving the eyes, crown and hair attachment fixed.
        sections=[(height+self.c.chin_lift*max(0,1-(height-1.603)/.10)**2,rx,ry,cy)
                  for height,rx,ry,cy in sections]
        i=next((i for i in range(len(sections)-1) if z <= sections[i+1][0]),len(sections)-2)
        a,b,c,d=[sections[j] for j in (max(0,i-1),i,i+1,min(len(sections)-1,i+2))]
        t=max(0,min(1,(z-b[0])/(c[0]-b[0])))
        result=[]
        for j in range(1,4):
            result.append(.5*(2*b[j]+(-a[j]+c[j])*t+(2*a[j]-5*b[j]+4*c[j]-d[j])*t*t+(-a[j]+3*b[j]-3*c[j]+d[j])*t**3))
        rx,ry,cy=result
        rx *= 1+(self.c.head_width-1)*gaussian(z,1.720,.080)
        rx *= 1-(self.c.jaw_taper-1)*.45*gaussian(z,1.65,.035)
        rx += .003*(self.c.cheek_fullness-1)*gaussian(z,1.728,.032)
        return rx,ry,cy

    def relief(self,x,z):
        # A flattened fourth-order tip lobe gives a small rounded profile rather
        # than the pointed silhouette of a single Gaussian nose bump.
        nose=self.c.nose_size*(.023*gaussian(x,0,.012)*math.exp(-((z-1.720)/.012)**4)
             +.012*gaussian(x,0,.0065)*gaussian(z,1.741,.022)
             +.005*gaussian(abs(x),.010,.006)*gaussian(z,1.716,.006))
        cheeks=.004*self.c.cheek_fullness*gaussian(abs(x),.060,.025)*gaussian(z,1.723,.021)
        muzzle=.0035*gaussian(x,0,.030)*gaussian(z,1.681,.016)
        sockets=-.002*gaussian(abs(x),self.c.eye_spacing,.033)*gaussian(z,1.760,.018)
        return nose+cheeks+muzzle+sockets

    def surface(self,x,z):
        rx,ry,cy=self.section(z)
        return cy+ry*math.sqrt(max(.015,1-(x/max(rx,.001))**2))+self.relief(x,z)

    def eye_front(self,x,z,side):
        u=(x-side*self.c.eye_spacing)/(.031*self.c.eye_scale*self.c.eye_width)
        line=1.756+side*(x-side*self.c.eye_spacing)*self.c.eye_tilt
        v=(z-line)/((.0108 if z>=line else .0078)*self.c.eye_scale*self.c.eye_height)
        r2=min(1,u*u+v*v)
        return self.surface(x,z)+.0017+.0053*(1-r2)

    def patch(self, cx,cz,rx,rz,material,tag,offset=.002, rings=3,segments=48):
        # A conforming elliptical disk, not a protruding eyeball sphere.
        center_y=self.eye_front(cx,cz,int(tag[3:]))+offset-.007 if tag.startswith("eye") else self.surface(cx,cz)+offset
        center=self.vertex((cx,center_y,cz),tag)
        previous=None
        for k in range(1,rings+1):
            ids=[]
            for j in range(segments):
                t=math.tau*j/segments; r=k/rings
                x,z=cx+rx*r*math.cos(t),cz+rz*r*math.sin(t)
                if tag.startswith("eye"):
                    side=int(tag[3:]); eye_x=side*self.c.eye_spacing
                    u=max(-1,min(1,(x-eye_x)/(.031*self.c.eye_scale*self.c.eye_width)))
                    arc=math.sqrt(max(0,1-u*u))
                    line=1.756+side*(x-eye_x)*self.c.eye_tilt
                    z=max(line-.0078*self.c.eye_scale*self.c.eye_height*arc+.00025,
                          min(line+.0108*self.c.eye_scale*self.c.eye_height*arc-.00025,z))
                y=self.eye_front(x,z,side)+offset-.007 if tag.startswith("eye") else self.surface(x,z)+offset
                ids.append(self.vertex((x,y,z),tag))
            for j in range(segments):
                q=(j+1)%segments
                self.polygon((center,ids[q],ids[j]) if previous is None else (previous[j],previous[q],ids[q],ids[j]),material)
            previous=ids

    def ribbon(self, points, widths, material, tag, depth=.0006):
        rows=[]
        for (x,y,z),width in zip(points,widths):
            tags=[tag]*3 if not tag.startswith("lash") else [tag+":"+str(offset) for offset in (-width*.5,0,width*.5)]
            rows.append([self.vertex((x,y-depth,z-width*.5),tags[0]),self.vertex((x,y,z),tags[1]),
                         self.vertex((x,y-depth,z+width*.5),tags[2])])
        for a,b in zip(rows,rows[1:]):
            self.polygon((a[0],b[0],b[1],a[1]),material)
            self.polygon((a[1],b[1],b[2],a[2]),material)

    def head(self):
        sides,rings=96,96
        for i in range(rings):
            start=1.603+self.c.chin_lift
            z=start+(1.898-start)*i/(rings-1)
            rx,ry,cy=self.section(z)
            for j in range(sides):
                t=math.tau*j/sides
                x=rx*math.cos(t); front=max(0,math.sin(t))
                y=cy+ry*math.sin(t)+self.relief(x,z)*front**8
                self.vertex((x,y,z))
        for i in range(rings-1):
            for j in range(sides):
                q=(j+1)%sides
                self.polygon((i*sides+j,i*sides+q,(i+1)*sides+q,(i+1)*sides+j),"FaceSkin")
        self.polygon(tuple(reversed(range(sides))),"FaceSkin")
        self.polygon(tuple((rings-1)*sides+j for j in range(sides)),"FaceSkin")

    def eye(self,s):
        c=self.c; cx=s*c.eye_spacing; cz=1.756; width=.031*c.eye_scale*c.eye_width
        tag=f"eye{s}"; n=64
        def outline(t,r=1, extra=0):
            x=cx+(width*r+extra)*math.cos(t)
            sine=math.sin(t)
            h=(.0108 if sine>=0 else .0078)*c.eye_scale*c.eye_height*r+extra
            z=cz+h*sine+s*(x-cx)*c.eye_tilt
            return x,z
        center=self.vertex((cx,self.surface(cx,cz)+.007,cz),tag)
        previous=None
        for k in range(1,5):
            ids=[]; r=k/4
            for j in range(n):
                x,z=outline(math.tau*j/n,r)
                ids.append(self.vertex((x,self.surface(x,z)+.0017+.0053*(1-r*r),z),tag))
            for j in range(n):
                q=(j+1)%n
                self.polygon((center,ids[q],ids[j]) if previous is None else (previous[j],previous[q],ids[q],ids[j]),"FaceSclera")
            previous=ids
        # A flush skin transition covers the sclera edge without a coloured ring
        # or raised pad. Only the upper lashes outline the eye.
        for k,expansion in enumerate((0,c.eyelid_thickness*.5,c.eyelid_thickness)):
            ids=[]
            for j in range(n):
                x,z=outline(math.tau*j/n,extra=expansion)
                y=self.surface(x,z)+(.0019 if k==0 else .0010 if k==1 else .00005)
                ids.append(self.vertex((x,y,z),f"lid{s}"))
            if k:
                for j in range(n):
                    q=(j+1)%n
                    self.polygon((previous[j],previous[q],ids[q],ids[j]),"FaceSkin")
            previous=ids
        # Upturned tapered lash strip; thickness comes from a convex ribbon section.
        points=[]; widths=[]
        for j in range(33):
            t=math.pi*j/32
            x,z=outline(t)
            points.append((x,self.surface(x,z)+.0032,z))
            widths.append((.0014+.0014*max(0,s*(x-cx)/width))*(.4+.6*abs(math.sin(t))**.3))
        self.ribbon(points,widths,"FaceLash",f"lash{s}")
        outer=cx+s*width
        x,z=outline(0 if s>0 else math.pi)
        self.ribbon([(x,self.surface(x,z)+.0034,z),(outer+s*.007,self.surface(outer,z)+.002,z+.006)],
                    [.0028,.00005],"FaceLash",f"lash{s}")
        # Conforming iris, limbal ring, coloured radial fibers, pupil and two highlights.
        iris=.0107*c.iris_scale
        ix=cx-.0005; iz=cz+.0008
        for radius, material,offset in [(iris,"FaceLimbal",.0078),(iris*.86,"FaceIris",.0080)]:
            self.patch(ix,iz,radius,radius*.98,material,tag,offset,2,64)
        for j in range(48):
            t=math.tau*j/48
            points=[]
            for r in (.49,.78,.86):
                x,z=ix+iris*r*math.cos(t),iz+iris*r*.98*math.sin(t)
                points.append((x,self.eye_front(x,z,s)+.00125,z))
            self.ribbon(points,[.00022,.0004,.00003],"FaceIrisGold" if j%3==0 else "FaceIrisFiber",tag,.00005)
        self.patch(ix,iz,iris*.39,iris*.48,"FacePupil",tag,.0086,2,48)
        self.patch(ix-.003,iz+.0034,.0022,.0020,"FaceGlint",tag,.009,2,24)
        self.patch(ix+.0028,iz-.0035,.00085,.00075,"FaceGlint",tag,.009,1,16)
        # No drawn crease arc or lower liner: these read as a second eye ring.
        # Shaped brow with a thick inner body, defined arch and tapered tail.
        points=[]; widths=[]
        for j in range(33):
            t=j/32; x=s*(.016+.072*t)
            z=1.787+.009*math.sin(t*math.pi*.9)+c.eyebrow_angle*(abs(x)-.04)
            z+=(.0017 if s<0 else -.0004)  # confident asymmetric neutral expression
            points.append((x,self.surface(x,z)+.0022,z))
            widths.append(.0003+.0068*math.sin(math.pi*(.12+.88*t))**.7)
        self.ribbon(points,widths,"FaceLash",f"brow{s}",.0010)

    def mouth(self):
        # The mouth seam stays narrow; fuller upper/lower tissue rolls out from
        # it and blends back into the face instead of looking like lip tubing.
        points=[]; widths=[]
        for j in range(49):
            t=-1+2*j/48; x=.028*t; arch=max(0,1-t*t)
            z=1.675+self.c.mouth_curvature*(.0028*t*t+.0014*t)
            points.append((x,self.surface(x,z)+.0024,z))
            widths.append(.0012*arch+.0001)
        self.ribbon(points,widths,"FaceMouth","mouth",.001)
        for upper,material in ((True,"FaceLip"),(False,"FaceLipLight")):
            rows=[]
            for j in range(49):
                t=-1+2*j/48; x=.028*t
                arch=max(0,1-t*t)
                smile=self.c.mouth_curvature*(.0028*t*t+.0014*t)
                cupid=.0013*gaussian(abs(t),.3,.18)-.0006*gaussian(t,0,.16)
                seam=1.675+smile
                thickness=(.0032 if upper else .0040)*self.c.lip_fullness*arch
                row=[]
                for k in range(5):
                    q=k/4 if upper else 1-k/4  # increasing Z for both strips
                    z=seam+(1 if upper else -1)*(.00045*arch+thickness*q)
                    if upper: z+=cupid*q*arch
                    projection=(.0031*(1-q)+.00015*q+(.0026 if upper else .0032)*self.c.lip_fullness*math.sin(math.pi*q))*arch+.00015
                    row.append(self.vertex((x,self.surface(x,z)+projection,z),"upperlip" if upper else "lowerlip"))
                rows.append(row)
            for a,b in zip(rows,rows[1:]):
                for k in range(4): self.polygon((a[k],a[k+1],b[k+1],b[k]),material)
        # Small inset nostrils follow the integrated nose wings rather than floating.
        for s in (-1,1):
            x=s*.0095*self.c.nose_size; z=1.715
            self.patch(x,z,.0026,.0009,"FaceNostril","skin",.0008,2,20)
        for s in (-1,1):
            for j in range(18):
                x=s*self.rng.uniform(.022,.084); z=self.rng.uniform(1.722,1.743)
                self.patch(x,z,self.rng.uniform(.00045,.0009),.00055,"FaceFreckle","skin",.0006,1,8)

    def morph(self, point,tag,key):
        x,y,z=point; c=self.c; oldsurface=self.surface(x,z) if y>0 else 0
        front=max(0,min(1,(y-.005)/.035))
        s=-1 if x<0 else 1
        orbital=gaussian(abs(x),c.eye_spacing,.036)*gaussian(z,1.760,.024)*front
        if key=="Blink":
            if tag.startswith(("eye","lid","lash")):
                line=1.754+s*(x-s*c.eye_spacing)*c.eye_tilt
                line+=.0018*((x-s*c.eye_spacing)/(.031*c.eye_scale*c.eye_width))**2
                # Iris/pupil/glints retract behind a closed, flattened lid slit.
                z=line+(z-line)*(.015 if tag.startswith("eye") else .04)
                y-=.010 if tag.startswith("eye") else .0003
                if tag.startswith("lash"):
                    z=line+float(tag.split(":")[1])
                    y=self.surface(x,z)+.0032
            elif tag=="skin": z-=.0015*orbital
        elif key in ("BrowRaise","BrowLower"):
            direction=1 if key=="BrowRaise" else -1
            if tag.startswith("brow"):
                z+=direction*(.008 if key=="BrowRaise" else .007)*(1-.35*min(1,abs(x)/.09))
                if key=="BrowLower": z+=.12*(abs(x)-.06)
            elif tag=="skin": z+=direction*.0025*gaussian(z,1.788,.017)*orbital
        elif key in ("Smile","Frown"):
            direction=1 if key=="Smile" else -1
            if tag in ("mouth","upperlip","lowerlip"):
                z+=direction*.006*(min(1,abs(x)/.028)**1.7)
                x*=1.08 if direction>0 else .96
            elif tag=="skin":
                z+=direction*.003*gaussian(abs(x),.034,.028)*gaussian(z,1.687,.027)*front
        elif key=="MouthOpen":
            weight=max(0,min(1,(1.704-z)/.042))*front
            if tag in ("mouth","upperlip","lowerlip"):
                if tag=="lowerlip": z-=.012*max(0,1-(x/.030)**2)
                elif tag=="mouth":
                    z-=.006*max(0,1-(x/.030)**2)
                    # Expand mouth interior ribbon into a dark cavity.
                    z+=(point[2]-(1.675+c.mouth_curvature*(.0028*(x/.028)**2+.0014*x/.028)))*13
            elif tag=="skin": z-=.006*weight
        # Keep attached surface details on the deformed facial curvature.
        if key!="Blink" and y>0:
            y+=self.surface(x,z)-oldsurface
        return (x,y,z)

    def build(self):
        a=self.api
        palette={"FaceSkin":("CE9D87",.62),"FaceSclera":("E8E1D7",.38),
                 "FaceLash":("191720",.65),"FaceLimbal":("193A37",.45),
                 "FaceIris":("528D7B",.40),"FaceIrisFiber":("7DAE91",.48),
                 "FaceIrisGold":("B2AB70",.45),"FacePupil":("101B21",.40),
                 "FaceGlint":("F8F5E9",.25),"FaceLip":("9C5660",.58),
                 "FaceLipLight":("B97979",.55),"FaceMouth":("38242C",.85),
                 "FaceNostril":("8B5550",.75),"FaceFreckle":("9A6154",.78)}
        for name,(colour,roughness) in palette.items():
            if name not in a.MATS: a.mat(name,colour,roughness)
        self.head(); self.eye(-1); self.eye(1); self.mouth()
        obj=a.mesh("Slayer expressive face",self.verts,self.faces,"FaceSkin","Face")
        obj.data.materials.clear()
        # Godot 4.7.2 drops the vertex-colour albedo flag on the first primitive.
        # Put the solid white sclera first (white COLOR_0 is a no-op), tinted skin
        # last. Newer importers also render this standard glTF ordering correctly.
        order=[name for name in self.names if name!="FaceSkin"]+["FaceSkin"]
        for name in order: obj.data.materials.append(a.MATS[name])
        for p,index in zip(obj.data.polygons,self.materials): p.material_index=order.index(self.names[index])
        # Vertex colours carry cheek/nose warmth and soft socket shadow into glTF.
        colours=obj.data.color_attributes.new(name="FaceTint",type="FLOAT_COLOR",domain="POINT")
        base=a.MATS["FaceSkin"].diffuse_color[:3]
        skin_vertices={v for polygon,index in zip(self.faces,self.materials)
                       if self.names[index]=="FaceSkin" for v in polygon}
        for i,((x,y,z),tag) in enumerate(zip(self.verts,self.tags)):
            warmth=(.30*gaussian(abs(x),.064,.026)*gaussian(z,1.727,.018)
                    +.38*gaussian(x,0,.014)*gaussian(z,1.722,.012)) if i in skin_vertices and y>0 else 0
            shadow=.13*gaussian(abs(x),self.c.eye_spacing,.036)*gaussian(z,1.777,.014) if i in skin_vertices and y>0 else 0
            if i in skin_vertices and y>0:
                shadow+=.12*gaussian(x,0,.014)*gaussian(z,1.710,.004)
            colours.data[i].color=(*(base[j]*(1-shadow)*(1-warmth*(.0,.4,.28)[j]) for j in range(3)),1)
            if i not in skin_vertices: colours.data[i].color=(1,1,1,1)
        material=a.MATS["FaceSkin"]
        # Exporter multiplies COLOR_0 by white base colour, matching Blender.
        bsdf=material.node_tree.nodes.get("Principled BSDF")
        bsdf.inputs["Base Color"].default_value=(1,1,1,1)
        if not any(n.type=="VERTEX_COLOR" for n in material.node_tree.nodes):
            node=material.node_tree.nodes.new("ShaderNodeVertexColor"); node.layer_name="FaceTint"
            material.node_tree.links.new(node.outputs["Color"],bsdf.inputs["Base Color"])
        obj.shape_key_add(name="Basis")
        for key in KEYS:
            shape=obj.shape_key_add(name=key)
            for vertex,point,tag in zip(shape.data,self.verts,self.tags): vertex.co=self.morph(point,tag,key)
            shape.value=0.0
        obj["face_config"]=__import__("json").dumps(asdict(self.c),sort_keys=True)
        obj["face_schema"]=1
        return obj


def build(api, config=None):
    return FaceBuilder(api,config or FaceConfig()).build()
