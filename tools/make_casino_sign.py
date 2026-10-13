"""The neon words OCEAN VIEW of the Las Vegas building ("Building" of sarthakv049, CC-BY,
https://sketchfab.com/3d-models/building-402e75b533f84c219a4f6642e7734409) become CA$INO: the
letters C, A, I, N and O of the model are kept and moved, the dollar sign is built to their height
and depth. The word keeps the material and the middle of the old one.

    python tools/make_casino_sign.py <building.glb> <out.glb>
(the output goes to FREEMODELS/_incoming/building_vegas_casino.glb for tools/build_wave16_models.py)
"""
import sys,json,struct,math,numpy as np
src,dst=sys.argv[1],sys.argv[2]
d=open(src,'rb').read()
l=struct.unpack('<I',d[12:16])[0]
j=json.loads(d[20:20+l]); bl=struct.unpack('<I',d[20+l:24+l])[0]; bin=bytearray(d[28+l:28+l+bl])
CT={5126:('f',4),5123:('H',2),5125:('I',4),5121:('B',1)}; N={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4}
def acc(i):
    a=j['accessors'][i]; bv=j['bufferViews'][a['bufferView']]; t,s=CT[a['componentType']]; n=N[a['type']]
    off=bv.get('byteOffset',0)+a.get('byteOffset',0); st=bv.get('byteStride',s*n)
    return np.array([struct.unpack_from('<%d%s'%(n,t),bin,off+k*st) for k in range(a['count'])],dtype=t)
prim=j['meshes'][0]['primitives'][0]
P=acc(prim['attributes']['POSITION']).astype(float); Nn=acc(prim['attributes']['NORMAL']).astype(float)
UV=acc(prim['attributes']['TEXCOORD_0']).astype(float); I=acc(prim['indices']).reshape(-1,3)
# letters = connected parts, in reading order (towards -z): O C E A N V I E W
key={}; w=np.zeros(len(P),int)
for i,v in enumerate(P): w[i]=key.setdefault(tuple(np.round(v,4)),len(key))
par=list(range(len(key)))
def f(x):
    while par[x]!=x: par[x]=par[par[x]]; x=par[x]
    return x
for t in I:
    a,b,c=[f(w[v]) for v in t]; par[b]=a; par[c]=a
root=np.array([f(w[i]) for i in range(len(P))])
roots=sorted(set(root),key=lambda r:-P[root==r][:,2].mean())
assert len(roots)==9
L=dict(O=roots[0],C=roots[1],A=roots[3],N=roots[4],I=roots[6])
y0,y1=P[:,1].min(),P[:,1].max()
GAP=0.03; DW=0.25
widths={k:np.ptp(P[root==r][:,2]) for k,r in L.items()}; widths['$']=DW
word='CA$INO'
total=sum(widths[c] for c in word)+GAP*(len(word)-1)
centre=(P[:,2].min()+P[:,2].max())/2
cur=centre+total/2   # left edge of the word is the highest z
oP=[];oN=[];oU=[];oI=[]
def add_tri(a,b,c,n):
    a,b,c=map(np.array,(a,b,c)); n=np.array(n,float)
    if np.dot(np.cross(b-a,c-a),n)<0: b,c=c,b
    k=len(oP); oP.extend([a,b,c]); oN.extend([n]*3); oU.extend([[0,0]]*3); oI.append([k,k+1,k+2])
def glyph_pt(r,h,y,zl):  # r from the left edge of the glyph, h up from the middle
    return [XC-h,y,zl-r]
XC=(P[root==L['I']][:,0].min()+P[root==L['I']][:,0].max())/2
H=np.ptp(P[root==L['I']][:,0])
def prism(poly,zl):   # convex quad [(r,h)x4] extruded between y0 and y1
    f0=[glyph_pt(r,h,y0,zl) for r,h in poly]; f1=[glyph_pt(r,h,y1,zl) for r,h in poly]
    add_tri(f0[0],f0[1],f0[2],[0,-1,0]); add_tri(f0[0],f0[2],f0[3],[0,-1,0])
    add_tri(f1[0],f1[1],f1[2],[0,1,0]); add_tri(f1[0],f1[2],f1[3],[0,1,0])
    c=np.mean(f0,0)
    for k in range(4):
        a,b=np.array(f0[k]),np.array(f0[(k+1)%4]); a1,b1=np.array(f1[k]),np.array(f1[(k+1)%4])
        e=b-a; n=np.array([e[2],0,-e[0]]); n/=np.linalg.norm(n)+1e-12
        if np.dot(n,(a+b)/2-c)<0: n=-n
        add_tri(a,b,b1,n); add_tri(a,b1,a1,n)
def dollar(zl):
    st=0.085; rx=(DW-st)/2; ry=(H-st)/4; cx=DW/2
    pts=[]
    for k in range(0,25):   # upper bowl: from the top right, over the top, down the left, to the middle
        a=math.radians(20+250*k/24); pts.append((cx+rx*math.cos(a), ry+ry*math.sin(a)))
    for k in range(1,25):   # lower bowl: from the middle, down the right, under, up the left
        a=math.radians(90-250*k/24); pts.append((cx+rx*math.cos(a),-ry+ry*math.sin(a)))
    pts=np.array(pts); tan=np.gradient(pts,axis=0); tan/=np.linalg.norm(tan,axis=1,keepdims=True)
    nor=np.stack([-tan[:,1],tan[:,0]],1)*st/2
    for k in range(len(pts)-1):
        prism([tuple(pts[k]+nor[k]),tuple(pts[k+1]+nor[k+1]),tuple(pts[k+1]-nor[k+1]),tuple(pts[k]-nor[k])],zl)
    bw=0.04; ov=0.035
    prism([(cx-bw/2,-H/2-ov),(cx+bw/2,-H/2-ov),(cx+bw/2,H/2+ov),(cx-bw/2,H/2+ov)],zl)
for ch in word:
    if ch=='$': dollar(cur)
    else:
        m=root==L[ch]; idx=np.where(m)[0]; remap={v:k+len(oP) for k,v in enumerate(idx)}
        shift=cur-P[idx][:,2].max()
        tris=[[remap[v] for v in t] for t in I if m[t[0]]]
        for v in idx: oP.append(P[v]+[0,0,shift]); oN.append(Nn[v]); oU.append(UV[v])
        oI.extend(tris)
    cur-=widths[ch]+GAP
oP=np.array(oP,'<f4'); oN=np.array(oN,'<f4'); oU=np.array(oU,'<f4'); oI=np.array(oI,'<u2').reshape(-1)
def push(arr,target,ctype,typ,minmax=False):
    while len(bin)%4: bin.append(0)
    j['bufferViews'].append(dict(buffer=0,byteOffset=len(bin),byteLength=arr.nbytes,target=target)); bin.extend(arr.tobytes())
    a=dict(bufferView=len(j['bufferViews'])-1,componentType=ctype,count=len(arr) if arr.ndim>1 else arr.size,type=typ)
    if minmax: a['min']=arr.min(0).tolist(); a['max']=arr.max(0).tolist()
    j['accessors'].append(a); return len(j['accessors'])-1
prim['attributes']=dict(POSITION=push(oP,34962,5126,'VEC3',True),NORMAL=push(oN,34962,5126,'VEC3'),TEXCOORD_0=push(oU,34962,5126,'VEC2'))
prim['indices']=push(oI,34963,5123,'SCALAR')
while len(bin)%4: bin.append(0)
j['buffers'][0]['byteLength']=len(bin)
js=json.dumps(j,separators=(',',':')).encode('utf-8'); js+=b' '*(-len(js)%4)
out=struct.pack('<4sII',b'glTF',2,12+8+len(js)+8+len(bin))+struct.pack('<I4s',len(js),b'JSON')+js+struct.pack('<I4s',len(bin),b'BIN\0')+bytes(bin)
open(dst,'wb').write(out)
print('verts',len(oP),'tris',len(oI)//3,'word span z',oP[:,2].min(),oP[:,2].max(),'was',P[:,2].min(),P[:,2].max(),'x',oP[:,0].min(),oP[:,0].max())
