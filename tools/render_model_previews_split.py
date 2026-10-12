import re
import sys, os, json, http.server, threading, functools
from playwright.sync_api import sync_playwright
T = os.path.join(os.path.dirname(os.path.abspath(__file__)), "_preview_root")
SRC = r"F:\Godot0-city\FREEMODELS\_incoming"
OUT = r"F:\Godot0-city\docs\model_previews_split"
os.makedirs(OUT, exist_ok=True)
HTML = """<!doctype html><meta charset=utf-8><style>
body{margin:0;background:#2b2f36;font-family:Segoe UI,Arial,sans-serif;color:#fff;width:1024px;height:800px;position:relative}
canvas{display:block}#cap{position:absolute;left:0;right:0;bottom:0;height:56px;background:#14161a;padding:6px 14px;box-sizing:border-box}
#n{font-size:20px;font-weight:600;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}#i{font-size:13px;color:#9aa3b0;margin-top:3px}
</style><body><canvas id=c width=1024 height=744></canvas><div id=cap><div id=n></div><div id=i></div></div>
<script type=importmap>{"imports":{"three":"/three/build/three.module.js"}}</script><script type=module>
import * as THREE from '/three/build/three.module.js';
import {GLTFLoader} from '/three/examples/jsm/loaders/GLTFLoader.js';
window.render = async (name, mb) => {
  const buf = await (await fetch('/model/'+encodeURIComponent(name))).arrayBuffer();
  const gltf = await new Promise((res,rej)=>new GLTFLoader().parse(buf,'',res,rej));
  const r = new THREE.WebGLRenderer({canvas:document.getElementById('c'),antialias:true,preserveDrawingBuffer:true});
  r.setSize(1024,744,false); r.setClearColor(0x3a404a);
  const s = new THREE.Scene(); s.add(new THREE.HemisphereLight(0xffffff,0x555566,2.2));
  const d = new THREE.DirectionalLight(0xffffff,2.5); d.position.set(5,10,7); s.add(d);
  s.add(gltf.scene);
  let tris=0, meshes=0; gltf.scene.traverse(o=>{if(o.isMesh){meshes++;const g=o.geometry;tris+=(g.index?g.index.count:g.attributes.position.count)/3}});
  const box = new THREE.Box3().setFromObject(gltf.scene), size=box.getSize(new THREE.Vector3()), ctr=box.getCenter(new THREE.Vector3());
  const rad = Math.max(size.length()/2,0.001);
  const cam = new THREE.PerspectiveCamera(35,1024/744,rad/100,rad*100);
  const dist = rad/Math.sin(35*Math.PI/360)*0.95;
  cam.position.copy(ctr).add(new THREE.Vector3(1,0.7,1.1).normalize().multiplyScalar(dist)); cam.lookAt(ctr);
  const grid = new THREE.GridHelper(rad*3,12,0x6a7280,0x4d5460); grid.position.set(ctr.x,box.min.y,ctr.z); s.add(grid);
  r.render(s,cam);
  document.getElementById('n').textContent = name;
  document.getElementById('i').textContent = `${mb} MB  ·  ${meshes} meshes  ·  ${Math.round(tris).toLocaleString()} tris  ·  size ${size.x.toFixed(1)} × ${size.y.toFixed(1)} × ${size.z.toFixed(1)}`;
  r.dispose(); return true;
};

window.load = async (name)=>{
  const buf=await (await fetch('/model/'+encodeURIComponent(name))).arrayBuffer();
  const g=await new Promise((a,b)=>new GLTFLoader().parse(buf,'',a,b));
  g.scene.updateMatrixWorld(true);
  let n=g.scene; while(n.children.length===1) n=n.children[0];
  const kids=n.children.filter(c=>{let m=0;c.traverse(o=>{if(o.isMesh)m++});return m>0});
  const boxes=kids.map(k=>new THREE.Box3().setFromObject(k));
  const vol=b=>{const s=b.getSize(new THREE.Vector3());return Math.max(s.x,1e-6)*Math.max(s.y,1e-6)*Math.max(s.z,1e-6)};
  let ov=0;
  boxes.forEach((b,i)=>{let hit=false;boxes.forEach((c,j)=>{if(i===j||hit)return;const x=b.clone().intersect(c);if(!x.isEmpty()&&vol(x)>0.5*Math.min(vol(b),vol(c)))hit=true});if(hit)ov++});
  window.cur={kids,boxes,scene:g.scene};
  return {n:kids.length,ov,names:kids.map(k=>k.name)};
};
window.renderKid = async (i,title,sub)=>{
  const {kids}=window.cur; const k=kids[i].clone(true);
  k.matrixAutoUpdate=false; k.matrix.copy(kids[i].matrixWorld); k.matrixWorld.copy(kids[i].matrixWorld);
  const r=window.R||(window.R=new THREE.WebGLRenderer({canvas:document.getElementById('c'),antialias:true,preserveDrawingBuffer:true}));
  r.setSize(1024,744,false); r.setClearColor(0x3a404a);
  const s=new THREE.Scene(); s.add(new THREE.HemisphereLight(0xffffff,0x555566,2.2));
  const d=new THREE.DirectionalLight(0xffffff,2.5); d.position.set(5,10,7); s.add(d); s.add(k);
  let tris=0; k.traverse(o=>{if(o.isMesh){const g=o.geometry;tris+=(g.index?g.index.count:g.attributes.position.count)/3}});
  const box=window.cur.boxes[i], size=box.getSize(new THREE.Vector3()), ctr=box.getCenter(new THREE.Vector3());
  const rad=Math.max(size.length()/2,0.001);
  const cam=new THREE.PerspectiveCamera(35,1024/744,rad/100,rad*100);
  const dist=rad/Math.sin(35*Math.PI/360)*0.95;
  cam.position.copy(ctr).add(new THREE.Vector3(1,0.7,1.1).normalize().multiplyScalar(dist)); cam.lookAt(ctr);
  const grid=new THREE.GridHelper(rad*3,12,0x6a7280,0x4d5460); grid.position.set(ctr.x,box.min.y,ctr.z); s.add(grid);
  r.render(s,cam);
  document.getElementById('n').textContent=title;
  document.getElementById('i').textContent=sub+`  ·  ${Math.round(tris).toLocaleString()} tris  ·  size ${size.x.toFixed(1)} × ${size.y.toFixed(1)} × ${size.z.toFixed(1)}`;
  return true;
};
window.ready=true;
</script>"""
class H(http.server.SimpleHTTPRequestHandler):
    def log_message(self,*a): pass
    def do_GET(self):
        if self.path=='/' :
            b=HTML.encode(); self.send_response(200); self.send_header('Content-Type','text/html'); self.send_header('Content-Length',str(len(b))); self.end_headers(); self.wfile.write(b); return
        if self.path.startswith('/model/'):
            from urllib.parse import unquote
            p=os.path.join(SRC,unquote(self.path[7:])); b=open(p,'rb').read()
            self.send_response(200); self.send_header('Content-Length',str(len(b))); self.end_headers(); self.wfile.write(b); return
        super().do_GET()
os.chdir(T)
srv=http.server.ThreadingHTTPServer(('127.0.0.1',8765),H); threading.Thread(target=srv.serve_forever,daemon=True).start()

files=sorted(f for f in os.listdir(SRC) if f.lower().endswith('.glb'))
only=sys.argv[1:]
summary={}
def clean(s): 
    s=re.sub(r'[^A-Za-z0-9._ -]+','',s).strip(' ._-'); return s
with sync_playwright() as p:
    br=p.chromium.launch(channel='chromium',args=['--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader','--ignore-gpu-blocklist'])
    pg=br.new_page(viewport={'width':1024,'height':800}); pg.goto('http://127.0.0.1:8765/'); pg.wait_for_function('window.ready===true')
    for f in files:
        if only and f not in only: continue
        r=pg.evaluate('n=>window.load(n)',f)
        frac=r['ov']/max(r['n'],1)
        pack = f[:-4] in ['100_lowpoly_buildings__buildings_pack', '54_vehicle_pack', 'buildings', 'buildings_pack', 'buildings_pack (1)', 'city_buildings_-_blackthornprod_video', 'european_building_facades', 'european_buildings_asset_pack_1', 'free_buildings_low_poly', 'low-poly_city_street_buildings_asset_pack', 'low-poly_container', 'low_poly_accommodations_buildings', 'low_poly_business_buildings_pack', 'low_poly_city__cartocity_pack__cartoonsih_city', 'low_poly_public_buildings_pack', 'low_poly_vehicle_mini_pack_8', 'lowpoly_buildings', 'lowpoly_city_street_pack_buildings_stylized', 'new_york_buildings', 'somewhat_low-poly_buildings', 'strike_fighters_apcifv_pack', 'strike_fighters_radar_pack', 'strike_fighters_tanks_pack']
        summary[f]=(r['n'],round(frac,2),pack); print(f[:50].ljust(51),r['n'],round(frac,2),'PACK' if pack else '-',flush=True)
        if not pack: continue
        base=os.path.splitext(f)[0]; d=os.path.join(OUT,clean(base) or 'pack'); os.makedirs(d,exist_ok=True)
        for i,nm in enumerate(r['names']):
            c=clean(nm); label=f"{i+1:03d}_{c}" if c else f"{i+1:03d}"
            fn=label[:80]+'.png'
            pg.evaluate('([i,t,s])=>window.renderKid(i,t,s)',[i,f"{base}  ›  {c or 'item '+str(i+1)}",f"item {i+1} of {r['n']}"])
            pg.screenshot(path=os.path.join(d,fn),clip={'x':0,'y':0,'width':1024,'height':800})
    br.close()
pass
