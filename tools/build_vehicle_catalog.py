#!/usr/bin/env python3
"""Split the two Sketchfab vehicle packs into one GLB per vehicle and build the catalog.

Usage:  python tools/build_vehicle_catalog.py <54_vehicle_pack.glb> <low_poly_vehicle_mini_pack_8.glb>
Needs:  numpy, scipy, Pillow.   Writes into ./vehicles (models/, thumbs/, catalog.json, CATALOG.md).
Nothing outside vehicles/ is touched.
"""
import sys, re, json, os, struct, io
import numpy as np
from PIL import Image
CT={5120:np.int8,5121:np.uint8,5122:np.int16,5123:np.uint16,5125:np.uint32,5126:np.float32}
NC={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4,'MAT4':16}
class GLB:
    def __init__(s,p):
        d=open(p,'rb').read()
        l,t=struct.unpack('<II',d[12:20]); s.j=json.loads(d[20:20+l])
        o=20+l; l2,t2=struct.unpack('<II',d[o:o+8]); s.bin=d[o+8:o+8+l2]
    def acc(s,i):
        a=s.j['accessors'][i]; bv=s.j['bufferViews'][a['bufferView']]
        n=NC[a['type']]; dt=np.dtype(CT[a['componentType']])
        off=bv.get('byteOffset',0)+a.get('byteOffset',0)
        stride=bv.get('byteStride') or n*dt.itemsize
        if stride==n*dt.itemsize:
            r=np.frombuffer(s.bin,dt,a['count']*n,off).reshape(a['count'],n)
        else:
            r=np.stack([np.frombuffer(s.bin,dt,n,off+k*stride) for k in range(a['count'])])
        return r.copy()
    def image(s,i):
        bv=s.j['bufferViews'][s.j['images'][i]['bufferView']]
        o=bv.get('byteOffset',0)
        return Image.open(io.BytesIO(s.bin[o:o+bv['byteLength']])).convert('RGBA')
    def node_mat(s,n):
        if 'matrix' in n: return np.array(n['matrix']).reshape(4,4).T
        m=np.eye(4)
        if 'scale' in n: m=np.diag(list(n['scale'])+[1])@m
        if 'rotation' in n:
            x,y,z,w=n['rotation']
            R=np.array([[1-2*(y*y+z*z),2*(x*y-z*w),2*(x*z+y*w)],[2*(x*y+z*w),1-2*(x*x+z*z),2*(y*z-x*w)],[2*(x*z-y*w),2*(y*z+x*w),1-2*(x*x+y*y)]])
            M=np.eye(4); M[:3,:3]=R; m=M@m
        if 'translation' in n:
            M=np.eye(4); M[:3,3]=n['translation']; m=M@m
        return m
    def walk(s):
        """yield (node_index, node, world_matrix) for nodes with mesh"""
        out=[]
        def rec(i,P):
            n=s.j['nodes'][i]; W=P@s.node_mat(n)
            if 'mesh' in n: out.append((i,n,W))
            for c in n.get('children',[]): rec(c,W)
        for r in s.j['scenes'][0]['nodes']: rec(r,np.eye(4))
        return out
    def prims(s):
        """list of dict(node,name,pos,nrm,uv,idx,material,world)  positions in world space"""
        res=[]
        for i,n,W in s.walk():
            for pr in s.j['meshes'][n['mesh']]['primitives']:
                at=pr['attributes']
                P=s.acc(at['POSITION']).astype(float); P=(np.c_[P,np.ones(len(P))]@W.T)[:,:3]
                N=s.acc(at['NORMAL']).astype(float)@np.linalg.inv(W[:3,:3]).T if 'NORMAL' in at else None
                if N is not None: N/=np.linalg.norm(N,axis=1,keepdims=True)+1e-9
                uv=s.acc(at['TEXCOORD_0']).astype(float) if 'TEXCOORD_0' in at else None
                idx=s.acc(pr['indices']).reshape(-1,3).astype(np.int64) if 'indices' in pr else np.arange(len(P)).reshape(-1,3)
                res.append(dict(node=i,name=n.get('name'),pos=P,nrm=N,uv=uv,idx=idx,material=pr.get('material'),mesh=n['mesh']))
        return res
    def material_image(s,mi):
        m=s.j['materials'][mi]; bt=m.get('pbrMetallicRoughness',{}).get('baseColorTexture')
        col=m.get('pbrMetallicRoughness',{}).get('baseColorFactor',[1,1,1,1])
        if bt is None: return None,col
        t=s.j['textures'][bt['index']]
        return s.image(t['source']),col

# ---- pack assembly ----
from scipy.sparse import coo_matrix
from scipy.sparse.csgraph import connected_components

def weld_components(pos,idx):
    key=np.round(pos,4); _,inv=np.unique(key,axis=0,return_inverse=True); inv=inv.ravel()
    t=inv[idx]; n=inv.max()+1
    r=np.r_[t[:,0],t[:,1]]; c=np.r_[t[:,1],t[:,2]]
    g=coo_matrix((np.ones(len(r)),(r,c)),shape=(n,n))
    _,lab=connected_components(g,directed=False)
    return lab[t[:,0]]   # label per triangle

def sub(p,mask_tri):
    idx=p['idx'][mask_tri]; used=np.unique(idx); remap=-np.ones(len(p['pos']),int); remap[used]=np.arange(len(used))
    q=dict(p); q['pos']=p['pos'][used]; q['nrm']=p['nrm'][used] if p['nrm'] is not None else None
    q['uv']=p['uv'][used] if p['uv'] is not None else None; q['idx']=remap[idx]; return q

def pack1(PACK1):
    g=GLB(PACK1); ps=g.prims()
    veh={}  # id -> list of parts
    glass=None
    for p in ps:
        mname=g.j['materials'][p['material']]['name']
        if mname=='st_gls': glass=p; continue
        m=re.match(r'st_(\d+)',mname); veh.setdefault(int(m.group(1)),[]).append(dict(p,mat=mname))
    boxes={k:(np.min([q['pos'].min(0) for q in v],0),np.max([q['pos'].max(0) for q in v],0)) for k,v in veh.items()}
    lab=weld_components(glass['pos'],glass['idx'])
    gmat=glass['material']
    for l in np.unique(lab):
        m=lab==l; q=sub(glass,m); c=q['pos'].mean(0)
        best=None;bd=1e9
        for k,(lo,hi) in boxes.items():
            ctr=(lo+hi)/2; d=np.linalg.norm((c-ctr)*[1,0,1])  # horizontal
            inside=np.all(c[[0,2]]>=lo[[0]+[2]]-0.02) and np.all(c[[0,2]]<=hi[[0]+[2]]+0.02)
            if inside and d<bd: bd=d;best=k
        if best is None:
            best=min(boxes,key=lambda k:np.linalg.norm((c-(boxes[k][0]+boxes[k][1])/2)*[1,0,1]))
        veh[best].append(dict(q,mat='glass'))
    return g,veh

def pack2(PACK2):
    g=GLB(PACK2); ps=g.prims()
    # group by top-level vehicle node (child of RootNode)
    root=g.j['nodes'][2]['children']
    parent={}
    for i,n in enumerate(g.j['nodes']):
        for c in n.get('children',[]): parent[c]=i
    veh={}
    for p in ps:
        n=p['node']
        while parent[n] not in (2,): n=parent[n]
        veh.setdefault(g.j['nodes'][n]['name'],[]).append(dict(p,mat='palette'))
    return g,veh

# ---- software renderer (thumbnails) ----
def render(parts,g,W=360,H=270,yaw=-35,pitch=28,bg=(238,238,245),dims=None):
    """parts: list of dict(pos,nrm,uv,idx,mat/material). g: GLB for textures. Returns PIL image."""
    allp=np.concatenate([p['pos'] for p in parts]); c=(allp.min(0)+allp.max(0))/2
    ya,pa=np.radians(yaw),np.radians(pitch)
    Ry=np.array([[np.cos(ya),0,np.sin(ya)],[0,1,0],[-np.sin(ya),0,np.cos(ya)]])
    Rx=np.array([[1,0,0],[0,np.cos(pa),-np.sin(pa)],[0,np.sin(pa),np.cos(pa)]])
    R=Rx@Ry
    pts=(allp-c)@R.T; ext=np.abs(pts[:,:2]).max(); s=min(W,H)*0.46/ext
    img=np.zeros((H,W,3),np.float32); img[:]=bg; zb=np.full((H,W),1e9,np.float32)
    L=np.array([0.4,0.8,0.5]); L/=np.linalg.norm(L)
    cache={}
    for p in parts:
        mi=p.get('material')
        if mi not in cache: cache[mi]=g.material_image(mi) if mi is not None else (None,[1,1,1,1])
        tex,col=cache[mi]
        tex=np.asarray(tex)[:,:,:3].astype(np.float32) if tex is not None else None
        P=(p['pos']-c)@R.T
        sx=W/2+P[:,0]*s; sy=H/2-P[:,1]*s; sz=-P[:,2]
        N=p['nrm']@R.T if p['nrm'] is not None else None
        for t in p['idx']:
            x=sx[t];y=sy[t]
            x0=int(max(np.floor(x.min()),0));x1=int(min(np.ceil(x.max()),W-1));y0=int(max(np.floor(y.min()),0));y1=int(min(np.ceil(y.max()),H-1))
            if x1<x0 or y1<y0: continue
            den=(y[1]-y[2])*(x[0]-x[2])+(x[2]-x[1])*(y[0]-y[2])
            if abs(den)<1e-9: continue
            gx,gy=np.meshgrid(np.arange(x0,x1+1)+.5,np.arange(y0,y1+1)+.5)
            a=((y[1]-y[2])*(gx-x[2])+(x[2]-x[1])*(gy-y[2]))/den
            b=((y[2]-y[0])*(gx-x[2])+(x[0]-x[2])*(gy-y[2]))/den
            cc=1-a-b; m=(a>=-1e-4)&(b>=-1e-4)&(cc>=-1e-4)
            if not m.any(): continue
            z=a*sz[t[0]]+b*sz[t[1]]+cc*sz[t[2]]
            sub=zb[y0:y1+1,x0:x1+1]; m&=z<sub
            if not m.any(): continue
            if tex is not None and p['uv'] is not None:
                uv=a[...,None]*p['uv'][t[0]]+b[...,None]*p['uv'][t[1]]+cc[...,None]*p['uv'][t[2]]
                th,tw=tex.shape[:2]
                u=np.clip((uv[...,0]%1)*tw,0,tw-1).astype(int); v=np.clip((uv[...,1]%1)*th,0,th-1).astype(int)
                rgb=tex[v,u]
            else:
                rgb=np.broadcast_to(np.array(col[:3])*255,(*gx.shape,3))
            if N is not None:
                n=a[...,None]*N[t[0]]+b[...,None]*N[t[1]]+cc[...,None]*N[t[2]]
                n/=np.linalg.norm(n,axis=-1,keepdims=True)+1e-9
                # light in view space: from upper-left-front
                sh=0.55+0.45*np.clip(n@np.array([-0.4,0.7,0.6]),-1,1)*0+0.45*np.clip((n@np.array([-0.4,0.7,0.6])),0,1)
                rgb=rgb*sh[...,None]
            sub[m]=z[m]; reg=img[y0:y1+1,x0:x1+1]; reg[m]=rgb[m]
    return Image.fromarray(np.clip(img,0,255).astype(np.uint8))


# ---- catalog table (names identified visually; edit freely and re-run) ----
# source key -> (category, model, sub_model, slug)
PACK54 = {
 1:("Cars","SUV","Off-road 4x4, navy","suv_offroad_navy"),
 2:("Vans","Van","Conversion van, white","van_conversion_white"),
 3:("Cars","Sedan","Classic 70s, maroon","sedan_classic_maroon"),
 4:("Cars","Sedan","Modern, silver","sedan_modern_silver"),
 5:("Cars","Sedan","90s, teal","sedan_90s_teal"),
 6:("Municipal & Emergency","Garbage truck","Rear loader","garbage_truck"),
 7:("Trucks","Box truck","Delivery, yellow","box_truck_delivery_yellow"),
 8:("Municipal & Emergency","Tow truck","Yellow","tow_truck_yellow"),
 9:("Trucks","Flatbed truck","With loader crane, orange","flatbed_crane_orange"),
 10:("Trucks","Tanker","Water tanker","tanker_water"),
 11:("Municipal & Emergency","Ambulance","Box ambulance","ambulance"),
 12:("Wrecks","Chassis wreck","Rusted frame","wreck_chassis"),
 13:("Trucks","Stake truck","Open bed, blue","stake_truck_blue"),
 14:("Semi tractors","Long-nose","Red","semi_longnose_red"),
 15:("Trucks","Dump truck","6x4, yellow/grey","dump_truck_yellow"),
 16:("Trucks","Dump truck","6x4, brown","dump_truck_brown"),
 17:("Construction & Industrial","Excavator","Tracked, yellow","excavator_yellow"),
 18:("Trucks","Tanker","Fuel tanker","tanker_fuel"),
 19:("Semi tractors","Sleeper cab","Blue","semi_sleeper_blue"),
 20:("Semi tractors","Cab-over","Yellow/brown","semi_cabover_yellow"),
 21:("Farm & Forestry","Harvester","Olive green","harvester_olive"),
 22:("Motorcycles","Cruiser","Red","motorcycle_cruiser_red"),
 23:("Wrecks","Hatchback wreck","Rusty","wreck_hatchback"),
 24:("Cars","Sedan","Classic hardtop, teal","sedan_hardtop_teal"),
 25:("Pickups","Pickup","Vintage, blue","pickup_vintage_blue"),
 26:("Pickups","Pickup","1940s style, red","pickup_40s_red"),
 27:("Semi tractors","Long-nose","Black","semi_longnose_black"),
 28:("Motorcycles","Dirt bike","Yellow","dirtbike_yellow"),
 29:("Semi tractors","Day cab","Red","semi_daycab_red"),
 30:("Cars","Sedan","Modern, damaged, grey","sedan_modern_damaged_grey"),
 31:("Buses & RVs","Motorhome","Class A, beige","rv_class_a_beige"),
 32:("Buses & RVs","Coach bus","White/blue stripe","bus_coach_white"),
 33:("Municipal & Emergency","Fire truck","Red pumper","fire_truck"),
 34:("Buses & RVs","Intercity bus","Dark grey","bus_intercity_dark"),
 35:("Construction & Industrial","Mobile crane","Truck-mounted, red/yellow","crane_truck_mobile"),
 36:("Buses & RVs","Motorhome","Class C, white/blue","rv_class_c_white"),
 37:("Wrecks","Car shell","Olive body shell","wreck_car_shell"),
 38:("Construction & Industrial","Wheel loader","Grapple, yellow","loader_grapple_yellow"),
 39:("Construction & Industrial","Forklift","Orange/black","forklift"),
 40:("Construction & Industrial","Crawler crane","Dragline, black boom","crane_crawler"),
 41:("Construction & Industrial","Wheel loader","Claw bucket, yellow","loader_claw_yellow"),
 42:("Farm & Forestry","Forwarder","Timber, green","forwarder_green"),
 43:("Farm & Forestry","Tractor","Vintage with trailer","tractor_vintage_trailer"),
 44:("Trucks","Flatbed truck","With boom, orange","flatbed_boom_orange"),
 45:("Aircraft","Biplane","Crop duster, yellow","biplane_yellow"),
 46:("Aircraft","Helicopter","Military, olive","helicopter_military"),
 47:("Aircraft","Attack aircraft","Twin-tail, blue-grey","aircraft_attack"),
 48:("Trailers","Flatbed trailer","Log/stake, rust","trailer_flatbed_rust"),
 49:("Trailers","Site cabin","Construction office trailer","trailer_site_cabin"),
 50:("Trailers","Box trailer","Silver","trailer_box_silver"),
 51:("Trailers","Crane trailer","Flatbed with crane","trailer_crane"),
 52:("Trailers","Semi trailer","Box, brown","trailer_semi_brown"),
 53:("Construction & Industrial","Road roller","Yellow","road_roller_yellow"),
 54:("Construction & Industrial","Scissor lift","Orange","scissor_lift"),
}
# mini pack 8: 5 models x 3 colours, node order is row-major (1..5, 1.001..5.001, 1.002..5.002)
MINI_MODELS = {1:("Sedan","sedan"),2:("Station wagon","wagon"),3:("Wagon, sloped rear","wagon_sloped"),
               4:("Long sedan","long_sedan"),5:("Pickup","pickup")}
MINI_COLOURS = {
 1:["Black","Dark red","Mustard"], 2:["Mustard","Blue","Teal"], 3:["Red","Black","Burgundy"],
 4:["Black","Silver","Charcoal"], 5:["Blue","Mustard","Olive"]}
# conversion to a common frame: front = -Z (Godot forward), Y up, wheels on y=0, XZ-centred, ~metres
ROT_Y = {"pack54":-90.0, "mini8":180.0, "jpcar":0.0, "uspolice":90.0}   # degrees about Y, or a 3x3 matrix
ROT_Y["rosomak"] = np.array([[-1,0,0],[0,0,-1],[0,-1,0]],float)  # source is -Z-up, length along Y, front +Y
SCALE = {"pack54":27.0, "mini8":1.0,   # pack54 is ~1/27 real size (sedan 0.176 -> 4.75 m)
         "jpcar":1.3, "uspolice":0.9, "rosomak":1.0}
WHEEL_NODES = {"Object_36","Object_38","Object_40","Object_42","Object_48","Object_50","Object_52","Object_54"}
CREDITS = {
 "jpcar":("Japanese Police Car low poly","SPixy01","https://sketchfab.com/3d-models/japanese-police-car-low-poly-07bc7b73bf4541d1bb4683af771bf2f2"),
 "uspolice":("POLICE CAR - LOW POLY","Jasmin Daniel","https://sketchfab.com/3d-models/police-car-low-poly-0f5b12ea1f474887b9664fd7a171c17a"),
 "rosomak":("KTO Rosomak (old version)","Stachwel","https://sketchfab.com/3d-models/kto-rosomak-old-version-779d15dada5e4b0eb174a98b2ca03fd4"),
 "pack54":("54 Vehicle Pack","PorscheAaron (HotWheelsA)","https://sketchfab.com/3d-models/54-vehicle-pack-10575d5318f244e5987d45239dbc6247"),
 "mini8":("Low Poly Vehicle Mini Pack 8","Vladek","https://sketchfab.com/3d-models/low-poly-vehicle-mini-pack-8-52ee24ff6eb2479891fe68e6ce46af28"),
}

def rotm(deg):
    a=np.radians(deg); c,s=np.cos(a),np.sin(a)
    return np.array([[c,0,s],[0,1,0],[-s,0,c]])

def transform(parts,pack):
    """-> new parts, ground at y=0, XZ-centred, rotated/scaled; plus (w,h,l) extents."""
    r=ROT_Y[pack]; R=rotm(r) if np.isscalar(r) else r; k=SCALE[pack]
    allp=np.concatenate([p['pos'] for p in parts])@R.T*k
    lo,hi=allp.min(0),allp.max(0); off=np.array([(lo[0]+hi[0])/2,lo[1],(lo[2]+hi[2])/2])
    out=[]
    for p in parts:
        q=dict(p); q['pos']=(p['pos']@R.T)*k-off
        q['nrm']=p['nrm']@R.T if p['nrm'] is not None else None
        out.append(q)
    return out,(hi-lo)

def group_parts(parts,pack):
    """Name and merge parts. Wheels get their pivot at the wheel centre so they can spin."""
    groups={}; order=[]
    allp=np.concatenate([p['pos'] for p in parts]); ctr=(allp.min(0)+allp.max(0))/2
    for p in parts:
        m=p['mat']
        if pack=='pack54':
            if m=='glass': name='Glass'
            else:
                mm=re.match(r'st_\d+_(\d+)',m)
                name='Body_%s'%mm.group(1) if mm else 'Body'
        elif pack in ('jpcar','uspolice','rosomak'):
            name=re.sub(r'_[Mm]aterial.*$','',p['name']).replace('.','_')
            ext=p['pos'].max(0)-p['pos'].min(0)
            if p['name'] in WHEEL_NODES or (pack=='jpcar' and name.startswith('Cylinder') and ext.max()>0.4):
                c=p['pos'].mean(0)
                name=('Wheel_%s%s'%('R' if c[0]>ctr[0] else 'L','F' if c[2]<ctr[2] else 'B'))
                if pack=='rosomak': name='Wheel_%s_%d'%('R' if c[0]>ctr[0] else 'L',int(round((c[2]-allp[:,2].min())/1.4)))
            elif pack=='uspolice': name='Body'
        else:
            n=p['name']
            if re.match(r'w\d',n):
                c=p['pos'].mean(0)
                name='Wheel_%s%s'%('F' if c[2]<ctr[2] else 'R','R' if c[0]>ctr[0] else 'L')
            elif re.match(r'(e\d|Cylinder)',n): name='Interior'
            else: name='Body'
        if name not in groups: groups[name]=[]; order.append(name)
        groups[name].append(p)
    res=[]
    for name in order:
        ps=groups[name]; off=0; pos=[];nrm=[];uv=[];idx=[]
        for p in ps:
            pos.append(p['pos']);nrm.append(p['nrm']);uv.append(p['uv']);idx.append(p['idx']+off);off+=len(p['pos'])
        pos=np.concatenate(pos); pivot=np.zeros(3)
        if name.startswith('Wheel_'): pivot=(pos.min(0)+pos.max(0))/2
        res.append(dict(name=name,pos=pos-pivot,nrm=np.concatenate(nrm),uv=np.concatenate(uv),idx=np.concatenate(idx),
                        material=ps[0]['material'],pivot=pivot))
    return res

def write_glb(path,g,meshes,title):
    """meshes: list of dict(name,pos,nrm,uv,idx,material,pivot) -> single-file GLB (textures embedded)."""
    chunks=[]; bvs=[]; accs=[]
    def add(data,target=None):
        pad=(-sum(len(c) for c in chunks))%4
        if pad: chunks.append(b'\0'*pad)
        o=sum(len(c) for c in chunks); chunks.append(data)
        bv={'buffer':0,'byteOffset':o,'byteLength':len(data)}
        if target: bv['target']=target
        bvs.append(bv); return len(bvs)-1
    imgs=[];texs=[];mats=[];matmap={};imgmap={}
    gj=g.j
    for m in meshes:
        mi=m['material']
        if mi in matmap: continue
        sm=gj['materials'][mi]; pbr=sm.get('pbrMetallicRoughness',{})
        bt=pbr.get('baseColorTexture')
        mat={'name':sm.get('name','mat'),'doubleSided':True,
             'pbrMetallicRoughness':{'metallicFactor':0.0,'roughnessFactor':min(1.0,pbr.get('roughnessFactor',0.8))}}
        if 'baseColorFactor' in pbr: mat['pbrMetallicRoughness']['baseColorFactor']=pbr['baseColorFactor']
        if bt is not None:
            src=gj['textures'][bt['index']]['source']
            if src not in imgmap:
                b=gj['bufferViews'][gj['images'][src]['bufferView']]; o=b.get('byteOffset',0)
                bv=add(g.bin[o:o+b['byteLength']])
                imgs.append({'bufferView':bv,'mimeType':gj['images'][src]['mimeType']})
                texs.append({'sampler':0,'source':len(imgs)-1}); imgmap[src]=len(texs)-1
            info={'index':imgmap[src]}
            tt=bt.get('extensions',{}).get('KHR_texture_transform')
            if tt: info['extensions']={'KHR_texture_transform':tt}
            mat['pbrMetallicRoughness']['baseColorTexture']=info
        mats.append(mat); matmap[mi]=len(mats)-1
    nodes=[];meshj=[]
    def acc(arr,ct,typ,target,minmax=False):
        bv=add(arr.tobytes(),target)
        a={'bufferView':bv,'componentType':ct,'count':int(arr.shape[0]),'type':typ}
        if minmax: a['min']=[float(x) for x in arr.min(0)]; a['max']=[float(x) for x in arr.max(0)]
        accs.append(a); return len(accs)-1
    for m in meshes:
        P=m['pos'].astype('<f4'); N=m['nrm'].astype('<f4'); U=m['uv'].astype('<f4')
        I=m['idx'].astype('<u4').ravel()
        ap=acc(P,5126,'VEC3',34962,True); an=acc(N,5126,'VEC3',34962); au=acc(U,5126,'VEC2',34962)
        ai=acc(I,5125,'SCALAR',34963)
        meshj.append({'name':m['name'],'primitives':[{'attributes':{'POSITION':ap,'NORMAL':an,'TEXCOORD_0':au},
                                                       'indices':ai,'material':matmap[m['material']]}]})
        n={'name':m['name'],'mesh':len(meshj)-1}
        if np.any(m['pivot']): n['translation']=[float(x) for x in m['pivot']]
        nodes.append(n)
    root={'name':title,'children':list(range(1,len(nodes)+1))}
    doc={'asset':{'version':'2.0','generator':'tools/build_vehicle_catalog.py'},'scene':0,'scenes':[{'nodes':[0]}],
         'nodes':[root]+nodes,'meshes':meshj,'materials':mats,'textures':texs,'images':imgs,
         'samplers':[{'magFilter':9729,'minFilter':9987,'wrapS':10497,'wrapT':10497}],
         'accessors':accs,'bufferViews':bvs,'buffers':[{'byteLength':0}]}
    if any('extensions' in mt['pbrMetallicRoughness'].get('baseColorTexture',{}) for mt in mats):
        doc['extensionsUsed']=['KHR_texture_transform']
    binb=b''.join(chunks); binb+=b'\0'*((-len(binb))%4); doc['buffers'][0]['byteLength']=len(binb)
    js=json.dumps(doc,separators=(',',':')).encode(); js+=b' '*((-len(js))%4)
    total=12+8+len(js)+8+len(binb)
    with open(path,'wb') as f:
        f.write(struct.pack('<4sII',b'glTF',2,total)); f.write(struct.pack('<I4s',len(js),b'JSON')+js)
        f.write(struct.pack('<I4s',len(binb),b'BIN\0')+binb)

def main(p1,p2,out='vehicles'):
    os.makedirs(out+'/models',exist_ok=True); os.makedirs(out+'/thumbs',exist_ok=True)
    entries=[]; jobs=[]
    g1,v1=pack1(p1)
    for k in sorted(v1):
        cat,model,sub,slug=PACK54[k]
        jobs.append(dict(g=g1,parts=v1[k],pack='pack54',src='st_%d'%k,category=cat,model=model,sub=sub,
                         id='p54_%02d_%s'%(k,slug),order=k))
    g2,v2=pack2(p2)
    for i,key in enumerate(v2):
        mid=i%5+1; row=i//5
        model,mslug=MINI_MODELS[mid]; col=MINI_COLOURS[mid][row]
        jobs.append(dict(g=g2,parts=v2[key],pack='mini8',src='node '+key,category='Pickups' if mid==5 else 'Cars',
                         model=model,sub=col,id='m8_%s_%s'%(mslug,col.lower().replace(' ','_')),order=100+i))
    for key,fname in (('jpcar','japanese_police_car_low_poly.glb'),('uspolice','police_car_-_low_poly.glb'),('rosomak','kto_rosomak_old_version.glb')):
        path=os.path.join(os.path.dirname(os.path.abspath(p1)),fname)
        if not os.path.exists(path): print('skip (missing)',path); continue
        g=GLB(path); ps=[dict(p,mat='x') for p in g.prims()]
        if key=='jpcar':   # file holds two cars side by side
            for side,(sub,sl) in ((-1,('Black, unmarked','black')),(1,('Black and white patrol','patrol'))):
                part=[p for p in ps if (p['pos'][:,0].mean()<0)==(side<0)]
                jobs.append(dict(g=g,parts=part,pack=key,src='x<0' if side<0 else 'x>0',category='Municipal & Emergency',
                                 model='Police car (JP)',sub=sub,id='police_jp_'+sl,order=200+side))
        elif key=='uspolice':
            jobs.append(dict(g=g,parts=ps,pack=key,src='single mesh',category='Municipal & Emergency',model='Police car (US)',
                             sub='Black and white',id='police_us_cruiser',order=210))
        else:
            jobs.append(dict(g=g,parts=ps,pack=key,src='8x8 APC',category='Military',model='Rosomak APC',
                             sub='Old version, camo green',id='rosomak_apc',order=220))
    for j in jobs:
        tp,dims=transform(j['parts'],j['pack'])
        meshes=group_parts(tp,j['pack'])
        cat=j['category'].lower().replace(' & ','_').replace(' ','_')
        os.makedirs('%s/models/%s'%(out,cat),exist_ok=True)
        rel='models/%s/%s.glb'%(cat,j['id'])
        write_glb('%s/%s'%(out,rel),j['g'],meshes,j['id'])
        render(tp,j['g'],320,240,yaw=145,pitch=26).save('%s/thumbs/%s.png'%(out,j['id']),optimize=True)
        entries.append(dict(id=j['id'],name='%s (%s)'%(j['model'],j['sub']),category=j['category'],model=j['model'],
            sub_model=j['sub'],pack=j['pack'],source=j['src'],file='res://vehicles/'+rel,
            thumbnail='res://vehicles/thumbs/%s.png'%j['id'],parts=[m['name'] for m in meshes],
            triangles=int(sum(len(p['idx']) for p in tp)),
            size_m=dict(width=round(float(dims[0]),2),height=round(float(dims[1]),2),length=round(float(dims[2]),2)),
            _order=j['order']))
    entries.sort(key=lambda e:(e['category'],e['model'],e['_order']))
    for e in entries: e.pop('_order')
    with open(out+'/catalog.json','w') as f:
        json.dump(dict(version=1,orientation='front=-Z, up=+Y, origin at ground centre, approx. metres',
                       credits={k:dict(title=v[0],author=v[1],url=v[2],license='CC-BY-4.0') for k,v in CREDITS.items()},
                       vehicles=entries),f,indent=1)
    write_md(out,entries); write_sheet(out,entries)
    print(len(entries),'vehicles written to',out)

def write_md(out,entries):
    L=['# Vehicle catalog','',
       '%d vehicles. Each is a standalone GLB in `models/<category>/<id>.glb` (front = -Z, Y up, origin on the ground at the centre, approx. metres).'%len(entries),
       'Machine-readable list: [`catalog.json`](catalog.json). Overview image: [`catalog_sheet.png`](catalog_sheet.png).','',
       '`id` is the stable key. Names were identified visually, so correct them in `tools/build_vehicle_catalog.py` and re-run.','']
    cats={}
    for e in entries: cats.setdefault(e['category'],[]).append(e)
    for c,es in cats.items():
        L+=['## %s (%d)'%(c,len(es)),'','| Preview | id | Model | Sub-model | L x W x H (m) | Parts | Tris |','|---|---|---|---|---|---|---|']
        for e in es:
            s=e['size_m']
            L.append('| ![](thumbs/%s.png) | `%s` | %s | %s | %.1f x %.1f x %.1f | %s | %d |'%(
                e['id'],e['id'],e['model'],e['sub_model'],s['length'],s['width'],s['height'],', '.join(e['parts']),e['triangles']))
        L.append('')
    L+=['## Credits','','Both packs are licensed **CC BY 4.0**; attribution is required when shipping.','']
    for v in CREDITS.values(): L.append('- "%s" by %s - %s'%v)
    L+=['','Regenerate: `python tools/build_vehicle_catalog.py <54_vehicle_pack.glb> <low_poly_vehicle_mini_pack_8.glb>`','']
    open(out+'/CATALOG.md','w',encoding='utf-8').write('\n'.join(L))

def write_sheet(out,entries):
    from PIL import ImageDraw
    cols=6; w,h=240,215; rows=(len(entries)+cols-1)//cols
    sh=Image.new('RGB',(w*cols,h*rows),(238,238,245)); d=ImageDraw.Draw(sh)
    for i,e in enumerate(entries):
        t=Image.open('%s/thumbs/%s.png'%(out,e['id'])).resize((w,int(w*0.75)))
        x,y=(i%cols)*w,(i//cols)*h; sh.paste(t,(x,y))
        d.text((x+4,y+h-34),e['id'],fill=(0,0,0)); d.text((x+4,y+h-20),('%s / %s / %s'%(e['category'],e['model'],e['sub_model']))[:40],fill=(70,70,70))
    sh.save(out+'/catalog_sheet.png',optimize=True)

if __name__=='__main__':
    main(sys.argv[1],sys.argv[2])
