"""Original Slayer facial construction; all dimensions in metres, Blender +Y front.

No third-party character geometry or textures. The builder owns only the Face group.
Separate from outfit/hair construction; supports rebuilds in an existing .blend.
"""
from dataclasses import asdict, dataclass
import math
import random

import bpy
from mathutils import Vector
from mathutils.geometry import delaunay_2d_cdt


@dataclass
class FaceConfig:
    eye_scale: float = 1.25
    eye_width: float = .80
    eye_opening_height: float = .80
    eye_outer_tilt: float = .075
    upper_lid_overlap: float = .09
    brow_height: float = .024
    brow_angle: float = .035
    brow_thickness: float = .0052
    chin_width: float = 1.08
    nose_projection: float = .92
    mouth_width: float = .027
    mouth_smirk: float = .0012
    head_width: float = 1.055
    chin_lift: float = .024
    eye_spacing: float = .047
    iris_scale: float = 1.10
    cheek_fullness: float = 1.12
    jaw_taper: float = .95
    nose_size: float = .90
    mouth_curvature: float = 1.15
    eyelid_thickness: float = .0008
    lip_fullness: float = 1.10

    def validate(self):
        limits = dict(eye_opening_height=(.60,1.05), eye_outer_tilt=(0,.18), upper_lid_overlap=(.05,.12),
                      brow_height=(.018,.034), brow_angle=(-.08,.15), brow_thickness=(.003,.008),
                      chin_width=(.85,1.2), nose_projection=(.7,1.2), mouth_width=(.022,.032), mouth_smirk=(0,.003),eye_scale=(1,1.45), eye_spacing=(.044,.052),
                      eye_width=(.7,1.15), head_width=(.95,1.09), chin_lift=(0,.035),
                      iris_scale=(.75,1.15), cheek_fullness=(.7,1.3),
                      jaw_taper=(.8,1.2), nose_size=(.7,1.2), mouth_curvature=(0,1.5),
                      eyelid_thickness=(.0008,.0022), lip_fullness=(1.0,2.0))
        for name, (lo,hi) in limits.items():
            value = getattr(self,name)
            if not math.isfinite(value) or not lo <= value <= hi:
                raise ValueError(f"{name} must be finite and in [{lo}, {hi}]")
        if self.eye_spacing-.031*self.eye_scale*self.eye_width < .004:
            raise ValueError("Eye spacing/scale must leave at least 8 mm between inner corners")


KEYS = ("Blink", "BrowRaise", "BrowLower", "Smile", "Frown", "MouthOpen", "Relaxed", "Focused", "Smirk")


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
        rx *= 1+(self.c.chin_width-1)*gaussian(z,1.622,.018)
        # Slight mandibular angle and temple inset interrupt the old featureless oval.
        rx += .0025*gaussian(z,1.659,.017)-.002*gaussian(z,1.783,.020)
        return rx,ry,cy

    def relief(self,x,z):
        # A flattened fourth-order tip lobe gives a small rounded profile rather
        # than the pointed silhouette of a single Gaussian nose bump.
        nose=self.c.nose_size*self.c.nose_projection*(.019*gaussian(x,0,.0105)*math.exp(-((z-1.721)/.0095)**4)
             +.010*gaussian(x,0,.007)*gaussian(z,1.742,.021)
             +.004*gaussian(abs(x),.009,.005)*gaussian(z,1.717,.005))
        cheeks=.007*self.c.cheek_fullness*gaussian(abs(x),.064,.023)*gaussian(z,1.727,.018)
        hollow=-.003*gaussian(abs(x),.073,.023)*gaussian(z,1.691,.018)
        muzzle=.0045*gaussian(x,0,.030)*gaussian(z,1.687,.016)
        chin=.004*gaussian(x,0,.029)*gaussian(z,1.650,.016)
        sockets=-.005*gaussian(abs(x),self.c.eye_spacing,.032)*gaussian(z,1.762,.016)
        ridge=.0035*gaussian(abs(x),self.c.eye_spacing,.031)*gaussian(z,1.783,.010)
        return nose+cheeks+hollow+muzzle+chin+sockets+ridge

    def surface(self,x,z):
        rx,ry,cy=self.section(z)
        front=0 if abs(x)>=rx-.000002 else math.sqrt(max(0,1-(x/max(rx,.001))**2))
        return cy+ry*front+self.relief(x,z)*front**2

    def eye_bounds(self,x,side, extra=0):
        c=self.c; cx=side*c.eye_spacing; width=.031*c.eye_scale*c.eye_width
        u=max(-1,min(1,(x-cx)/(width+extra)))
        # Super-elliptic corners taper without an oval's wide-open crown.
        arc=max(0,1-u*u)**.72
        iris=.0107*c.iris_scale
        upper=iris*(1-2*c.upper_lid_overlap)*c.eye_opening_height/.80
        lower=.0090*c.eye_opening_height/.80
        line=1.756+side*(x-cx)*c.eye_outer_tilt
        return line-(lower+extra)*arc,line+(upper+extra)*arc

    def outline(self,t,side,extra=0):
        width=.031*self.c.eye_scale*self.c.eye_width
        x=side*self.c.eye_spacing+(width+extra)*math.cos(t)
        lo,hi=self.eye_bounds(x,side,extra)
        return x,hi if math.sin(t)>=0 else lo

    def eye_front(self,x,z,side):
        # A real ellipsoid, set into the socket, with a consistent optical axis.
        cx=side*self.c.eye_spacing
        dx=x-cx; dz=z-1.756
        radius=.038*self.c.eye_scale/1.25
        dome=math.sqrt(max(.015,1-(dx/radius)**2-(dz/.032)**2))
        center=self.surface(cx,1.756)-.0125
        # Local tangent follows the curved face; the optical axes stay parallel.
        slope=(self.surface(cx+.001,1.756)-self.surface(cx-.001,1.756))/.002
        return center+.014*dome+dx*slope

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
                    lo,hi=self.eye_bounds(x,side)
                    z=max(lo+.00012,min(hi-.00012,z))
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
        # Constrained triangulation cuts actual socket apertures into the skin.
        # The front and back share silhouette vertices; no eye decals cover a solid head.
        sides,rings=96,96
        start=1.603+self.c.chin_lift
        rows=[]; planar=[]; edges=[]; front_rows=[]
        for i in range(rings):
            z=start+(1.898-start)*i/(rings-1)
            rx,ry,cy=self.section(z); row=[]
            for j in range(sides//2+1):
                t=math.pi+math.pi*j/(sides//2)
                row.append(self.vertex((rx*math.cos(t),cy+ry*math.sin(t),z)))
            rows.append(row)
            front_row=[]
            for j in range(sides//2+1):
                x=-rx+2*rx*j/(sides//2)
                inside=False
                for side in (-1,1):
                    w=.031*self.c.eye_scale*self.c.eye_width+.005
                    if abs(x-side*self.c.eye_spacing)<w:
                        lo,hi=self.eye_bounds(x,side,.005)
                        inside |= lo<z<hi
                if inside: continue
                front_row.append(len(planar)); planar.append(Vector((x,z)))
            front_rows.append(front_row)
        for a,b in zip(front_rows,front_rows[1:]):
            edges.extend(((a[0],b[0]),(a[-1],b[-1])))
        for row in (front_rows[0],front_rows[-1]):
            edges.extend(zip(row,row[1:]))
        for a,b in zip(rows,rows[1:]):
            for j in range(sides//2): self.polygon((a[j],a[j+1],b[j+1],b[j]),"FaceSkin")
        for side in (-1,1):
            loop=[]
            for j in range(64):
                x,z=self.outline(math.tau*j/64,side,.005)
                loop.append(len(planar)); planar.append(Vector((x,z)))
            edges.extend((loop[j],loop[(j+1)%64]) for j in range(64))
        verts,_,triangles,_,_,_=delaunay_2d_cdt(planar,edges,[],0,1e-7)
        ids=[self.vertex((v.x,self.surface(v.x,v.y),v.y)) for v in verts]
        for tri in triangles:
            x=sum(verts[i].x for i in tri)/len(tri); z=sum(verts[i].y for i in tri)/len(tri)
            inside=False
            for side in (-1,1):
                if abs(x-side*self.c.eye_spacing)<.031*self.c.eye_scale*self.c.eye_width+.005:
                    lo,hi=self.eye_bounds(x,side,.005)
                    inside |= lo<z<hi
            if not inside and abs(x)<=self.section(z)[0]+1e-7:
                self.polygon(tuple(ids[i] for i in reversed(tri)),"FaceSkin")
        # Cap scalp/chin using the front/back silhouette. Covered by hair/neck.
        for row_i in (0,rings-1):
            row=rows[row_i]
            z=start+(1.898-start)*row_i/(rings-1)
            rx,_,_=self.section(z)
            front=[self.vertex((rx-2*rx*j/48,self.surface(rx-2*rx*j/48,z),z)) for j in range(1,48)]
            boundary=row+front
            self.polygon(tuple(reversed(boundary)) if row_i==0 else tuple(boundary),"FaceSkin")

    def eye(self,s):
        c=self.c; cx=s*c.eye_spacing; cz=1.756; width=.031*c.eye_scale*c.eye_width
        tag=f"eye{s}"; n=64
        def outline(t,r=1,extra=0):
            x,z=self.outline(t,s,extra)
            return cx+(x-cx)*r,cz+(z-cz)*r
        center=self.vertex((cx,self.eye_front(cx,cz,s),cz),tag)
        previous=None
        for k in range(1,7):
            ids=[]; r=k/6
            for j in range(n):
                x,z=outline(math.tau*j/n,r)
                ids.append(self.vertex((x,self.eye_front(x,z,s),z),tag))
            for j in range(n):
                q=(j+1)%n
                self.polygon((center,ids[q],ids[j]) if previous is None else (previous[j],previous[q],ids[q],ids[j]),"FaceSclera")
            previous=ids
        # Lid inner edge follows the actual ellipsoid, outer edge joins the socket.
        # A soft anatomical roll and shallow upper crease replace the cosmetic ring.
        for k in range(7):
            q=k/6; ids=[]
            for j in range(n):
                t=math.tau*j/n; x,z=outline(t,extra=.005*q)
                innerx,innerz=outline(t)
                inner=self.eye_front(innerx,innerz,s)+c.eyelid_thickness
                outer=self.surface(x,z)
                y=inner*(1-q)+outer*q+.00065*math.sin(math.pi*q)
                if math.sin(t)>0: y-=.0005*math.sin(math.pi*q)**4
                ids.append(self.vertex((x,y,z),f"lid{s}"))
            if k:
                for j in range(n):
                    nxt=(j+1)%n
                    self.polygon((previous[j],previous[nxt],ids[nxt],ids[j]),"FaceSkin")
            previous=ids
        # Upturned tapered lash strip; thickness comes from a convex ribbon section.
        points=[]; widths=[]
        for j in range(33):
            t=math.pi*j/32
            x,z=outline(t)
            points.append((x,self.eye_front(x,z,s)+.0010,z))
            widths.append((.0010+.0018*max(0,s*(x-cx)/width))*(.4+.6*abs(math.sin(t))**.3))
        self.ribbon(points,widths,"FaceLash",f"lash{s}")
        outer=cx+s*width
        x,z=outline(0 if s>0 else math.pi)
        self.ribbon([(x,self.eye_front(x,z,s)+.0012,z),(outer+s*.005,self.eye_front(x,z,s)+.0005,z+.004)],
                    [.0028,.00005],"FaceLash",f"lash{s}")
        # Conforming iris, limbal ring, coloured radial fibers, pupil and two highlights.
        iris=.0107*c.iris_scale
        ix=cx-.0005; iz=cz+.0003
        for radius, material,offset in [(iris,"FaceLimbal",.0071),(iris*.93,"FaceIris",.0072)]:
            self.patch(ix,iz,radius,radius*.98,material,tag,offset,2,64)
        for j in range(48):
            t=math.tau*j/48
            points=[]
            for r in (.49,.78,.91):
                x,z=ix+iris*r*math.cos(t),iz+iris*r*.98*math.sin(t)
                lo,hi=self.eye_bounds(x,s)
                z=max(lo+.0002,min(hi-.0002,z))
                points.append((x,self.eye_front(x,z,s)+.0003,z))
            self.ribbon(points,[.00022,.0004,.00003],"FaceIrisGold" if j%3==0 else "FaceIrisFiber",tag,.00005)
        self.patch(ix,iz,iris*.40,iris*.46,"FacePupil",tag,.0074,2,48)
        self.patch(ix-.003,iz+.0034,.0022,.0020,"FaceGlint",tag,.0076,2,24)
        self.patch(ix+.0028,iz-.0035,.00085,.00075,"FaceGlint",tag,.0076,1,16)
        # No drawn crease arc or lower liner: these read as a second eye ring.
        # Shaped brow with a thick inner body, defined arch and tapered tail.
        points=[]; widths=[]
        for j in range(33):
            t=j/32; x=s*(.016+.072*t)
            z=cz+c.brow_height+.0035*math.sin(t*math.pi)+c.brow_angle*(abs(x)-.04)
            z+=(.0017 if s<0 else -.0004)  # confident asymmetric neutral expression
            points.append((x,self.surface(x,z)+.0022,z))
            widths.append(.00015+c.brow_thickness*(1-t**1.7)*min(1,.35+5*t))
        self.ribbon(points,widths,"FaceLash",f"brow{s}",.0010)

    def mouth(self):
        # The mouth seam stays narrow; fuller upper/lower tissue rolls out from
        # it and blends back into the face instead of looking like lip tubing.
        points=[]; widths=[]
        for j in range(49):
            t=-1+2*j/48; x=self.c.mouth_width*t; arch=max(0,1-t*t)
            z=1.683+self.c.mouth_curvature*.0015*t*t+self.c.mouth_smirk*t
            points.append((x,self.surface(x,z)+.0024,z))
            widths.append(.0012*arch+.0001)
        self.ribbon(points,widths,"FaceMouth","mouth",.001)
        for upper,material in ((True,"FaceLip"),(False,"FaceLipLight")):
            rows=[]
            for j in range(49):
                t=-1+2*j/48; x=self.c.mouth_width*t
                arch=max(0,1-t*t)
                smile=self.c.mouth_curvature*.0015*t*t+self.c.mouth_smirk*t
                cupid=.0013*gaussian(abs(t),.3,.18)-.0006*gaussian(t,0,.16)
                seam=1.683+smile
                thickness=(.0027 if upper else .0037)*self.c.lip_fullness*arch
                row=[]
                for k in range(5):
                    q=k/4 if upper else 1-k/4  # increasing Z for both strips
                    z=seam+(1 if upper else -1)*(.00045*arch+thickness*q)
                    if upper: z+=cupid*q*arch
                    projection=(.0018*(1-q)+.00005*q+(.0016 if upper else .0020)*self.c.lip_fullness*math.sin(math.pi*q))*arch+.00015
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
        if key in ("Relaxed","Focused"):
            if tag.startswith(("eye","lid","lash","socket")) or tag=="skin":
                line=1.756+s*(x-s*c.eye_spacing)*c.eye_outer_tilt
                # A continuous support field keeps welded socket triangles from
                # folding between fully moving lid edges and partly moving skin.
                low,high=self.eye_bounds(x,s,.005)
                distance=max(0,z-high,low-z,abs(x-s*c.eye_spacing)-(.031*c.eye_scale*c.eye_width+.005))
                weight=max(0,1-distance/.025)*front if tag=="skin" else 1
                z-=max(0,z-line)*(.30 if key=="Relaxed" else .20)*weight
            if tag.startswith("brow"):
                z-=.002 if key=="Relaxed" else .004
                if key=="Focused": z+=.10*(abs(x)-c.eye_spacing)
        elif key=="Smirk":
            if tag in ("mouth","upperlip","lowerlip"):
                z+=.0035*max(0,-x/c.mouth_width)**1.6
            elif tag=="skin":
                z+=.0015*gaussian(x,-.027,.018)*gaussian(z,1.683,.018)*front
        elif key=="Blink":
            if tag.startswith(("eye","lid","lash")):
                line=1.754+s*(x-s*c.eye_spacing)*c.eye_outer_tilt
                line+=.0018*((x-s*c.eye_spacing)/(.031*c.eye_scale*c.eye_width))**2
                # Iris/pupil/glints retract behind a closed, flattened lid slit.
                z=line+(z-line)*(.015 if tag.startswith("eye") else .04)
                y-=.010 if tag.startswith("eye") else .0003
                if tag.startswith("lash"):
                    z=line+float(tag.split(":")[1])
                    y=self.eye_front(x,z,s)+.0010
            elif tag.startswith("socket") or tag=="skin":
                # Move the socket aperture with the closed lid so no open hole remains.
                lo,hi=self.eye_bounds(x,s,.005)
                edge=hi if z>=1.756+s*(x-s*c.eye_spacing)*c.eye_outer_tilt else lo
                distance=abs(z-edge)
                weight=max(0,1-distance/.022)*max(0,min(1,(.044-abs(x-s*c.eye_spacing))/.008))
                line=1.754+s*(x-s*c.eye_spacing)*c.eye_outer_tilt
                line+=.0018*((x-s*c.eye_spacing)/(.031*c.eye_scale*c.eye_width))**2
                z+=(line-z)*.96*weight
        elif key in ("BrowRaise","BrowLower"):
            direction=1 if key=="BrowRaise" else -1
            if tag.startswith("brow"):
                z+=direction*(.008 if key=="BrowRaise" else .007)*(1-.35*min(1,abs(x)/.09))
                if key=="BrowLower": z+=.12*(abs(x)-.06)
            elif tag=="skin": z+=direction*.0025*gaussian(z,1.788,.017)*orbital
        elif key in ("Smile","Frown"):
            direction=1 if key=="Smile" else -1
            if tag in ("mouth","upperlip","lowerlip"):
                z+=direction*.006*(min(1,abs(x)/c.mouth_width)**1.7)
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
                    z+=(point[2]-(1.683+c.mouth_curvature*.0015*(x/c.mouth_width)**2+c.mouth_smirk*x/c.mouth_width))*13
            elif tag=="skin": z-=.006*weight
        # Keep attached surface details on the deformed facial curvature.
        if key!="Blink" and y>0:
            y+=self.surface(x,z)-oldsurface
        if key in ("Relaxed","Focused") and tag.startswith("lash"):
            # Keep the lash ribbon in front of the moving lid tissue.
            y=max(self.eye_front(x,z,s)+.0018,self.surface(x,z)+.0009)
        return (x,y,z)

    def build(self):
        a=self.api
        palette={"FaceSkin":("CE9D87",.62),"FaceSclera":("DDD7CB",.48),
                 "FaceLash":("191720",.65),"FaceLimbal":("193A37",.45),
                 "FaceIris":("528D7B",.40),"FaceIrisFiber":("7DAE91",.48),
                 "FaceIrisGold":("B2AB70",.45),"FacePupil":("101B21",.40),
                 "FaceGlint":("F8F5E9",.25),"FaceLip":("AD7472",.65),
                 "FaceLipLight":("BF8980",.62),"FaceMouth":("38242C",.85),
                 "FaceNostril":("8B5550",.75),"FaceFreckle":("9A6154",.78)}
        for name,(colour,roughness) in palette.items():
            if name not in a.MATS: a.mat(name,colour,roughness)
            else:
                material=a.MATS[name]; value=tuple(int(colour[i:i+2],16)/255 for i in (0,2,4))
                linear=tuple(v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4 for v in value)
                material.diffuse_color=(*linear,1)
                shader=material.node_tree.nodes.get("Principled BSDF")
                shader.inputs["Base Color"].default_value=(*linear,1)
                shader.inputs["Roughness"].default_value=roughness
        self.head(); self.eye(-1); self.eye(1); self.mouth()
        # Weld the socket/head boundary and the front/back silhouette before
        # normals or morphs are generated. This removes the old floating lid rim.
        used={v for face in self.faces for v in face}
        vertices=[]; tags=[]; lookup={}; remap={}
        for i,(point,tag) in enumerate(zip(self.verts,self.tags)):
            if i not in used: continue
            token=tuple(round(v,6) for v in point)
            if token not in lookup:
                lookup[token]=len(vertices); vertices.append(point); tags.append(tag)
            elif tag.startswith("lid"):
                tags[lookup[token]]=tag
            remap[i]=lookup[token]
        self.verts=vertices; self.tags=tags
        self.faces=[tuple(remap[i] for i in face) for face in self.faces]
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
            if tag.startswith("eye"):
                # Restrained upper-lid occlusion carried by exported vertex colour.
                shade=1-.17*max(0,min(1,(z-1.756)/.010))
                colours.data[i].color=(shade,shade,shade,1)
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
        obj["face_schema"]=2
        return obj


def build(api, config=None):
    return FaceBuilder(api,config or FaceConfig()).build()
