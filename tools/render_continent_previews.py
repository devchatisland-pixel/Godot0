"""Renders the Continent pack (FREEMODELS/curated/continent_buildings.glb) in the "Continent" theme:
bright continental daylight, blue sky, green land under a light grid.

Output: docs/model_previews_continent/<id>.png (one per building) and
        docs/continent_buildings.png (the whole pack on one sheet).
Needs:  playwright (chromium) and three.js in PREVIEW_ROOT (default tools/_preview_root, same as
        tools/render_vegas_previews.py).
"""
import os, http.server, threading
from urllib.parse import unquote
from playwright.sync_api import sync_playwright

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
T = os.environ.get("PREVIEW_ROOT", os.path.join(HERE, "tools", "_preview_root"))
PACK = os.environ.get("CONTINENT_PACK", os.path.join(HERE, "FREEMODELS", "curated", "continent_buildings.glb"))
OUT = os.environ.get("CONTINENT_OUT", os.path.join(HERE, "docs", "model_previews_continent"))
SHEET = os.environ.get("CONTINENT_SHEET", os.path.join(HERE, "docs", "continent_buildings.png"))
os.makedirs(OUT, exist_ok=True)

HTML = """<!doctype html><meta charset=utf-8><style>
body{margin:0;background:#cfe6f5;font-family:Segoe UI,Arial,sans-serif;color:#1f3a2a;position:relative}
canvas{display:block}#cap{position:absolute;left:0;right:0;bottom:0;height:56px;background:#e9f3df;border-top:3px solid #5f9a45;padding:6px 14px;box-sizing:border-box}
#n{font-size:20px;font-weight:700;color:#2f5d2a}#i{font-size:13px;color:#47647a;margin-top:3px}
</style><body><canvas id=c></canvas><div id=cap><div id=n></div><div id=i></div></div>
<script type=importmap>{"imports":{"three":"/three/build/three.module.js"}}</script><script type=module>
import * as THREE from '/three/build/three.module.js';
import {GLTFLoader} from '/three/examples/jsm/loaders/GLTFLoader.js';
const r = new THREE.WebGLRenderer({canvas:document.getElementById('c'),antialias:true,preserveDrawingBuffer:true});
const buf = await (await fetch('/pack.glb')).arrayBuffer();
const gltf = await new Promise((res,rej)=>new GLTFLoader().parse(buf,'',res,rej));
const root = gltf.scene.children[0];
const kids = [...root.children];
function sky(){ const c=document.createElement('canvas'); c.width=2; c.height=256; const x=c.getContext('2d');
  const g=x.createLinearGradient(0,0,0,256); g.addColorStop(0,'#5fa3dc'); g.addColorStop(0.7,'#bfe0f3'); g.addColorStop(1,'#eef6e6');
  x.fillStyle=g; x.fillRect(0,0,2,256); return new THREE.CanvasTexture(c); }
function scene(){ const s=new THREE.Scene(); s.background=sky();
  s.add(new THREE.HemisphereLight(0xdcefff,0x5c7d3c,1.7));
  const d=new THREE.DirectionalLight(0xfff3d6,2.4); d.position.set(6,10,5); s.add(d);
  const f=new THREE.DirectionalLight(0xbcd8ff,0.7); f.position.set(-6,3,-5); s.add(f); return s; }
function ground(s,cx,cz,w,h,y){ const m=new THREE.Mesh(new THREE.PlaneGeometry(w,h),new THREE.MeshLambertMaterial({color:0x8fbf6a}));
  m.rotation.x=-Math.PI/2; m.position.set(cx,y-0.01,cz); s.add(m);
  const gr=new THREE.GridHelper(Math.max(w,h),Math.round(Math.max(w,h)),0xe9f5d8,0xb7d89a); gr.position.set(cx,y,cz); s.add(gr); }
function stats(o){ let t=0; o.traverse(m=>{if(m.isMesh){const g=m.geometry;t+=(g.index?g.index.count:g.attributes.position.count)/3}}); return t; }
window.one = async (i) => {
  r.setSize(1024,744,false); kids.forEach((k,j)=>k.visible=(j===i));
  const s=scene(); s.add(gltf.scene);
  const o=kids[i]; const box=new THREE.Box3().setFromObject(o), size=box.getSize(new THREE.Vector3()), ctr=box.getCenter(new THREE.Vector3());
  const rad=Math.max(size.length()/2,0.001);
  ground(s,ctr.x,ctr.z,rad*3,rad*3,box.min.y);
  const cam=new THREE.PerspectiveCamera(35,1024/744,rad/100,rad*100);
  cam.position.copy(ctr).add(new THREE.Vector3(1,0.55,1.1).normalize().multiplyScalar(rad/Math.sin(35*Math.PI/360)*1.1)); cam.lookAt(ctr.x,ctr.y-rad*0.06,ctr.z);
  r.render(s,cam);
  document.getElementById('n').textContent='Continent  ·  '+o.name;
  document.getElementById('i').textContent=Math.round(stats(o)).toLocaleString()+' tris  ·  size '+size.x.toFixed(2)+' × '+size.y.toFixed(2)+' × '+size.z.toFixed(2)+' cells';
  s.remove(gltf.scene); return o.name;
};
window.sheet = async (cols) => {
  // every building on its own plot, laid out in rows
  const gap=0.8; let x=0,z=0,rowD=0; const rows=[]; const plots=[];
  const n=kids.length, per=Math.ceil(n/cols);
  const boxes=kids.map(k=>{k.position.set(0,0,0);k.updateMatrixWorld(true);return new THREE.Box3().setFromObject(k)});
  let maxW=0,maxD=0; boxes.forEach(b=>{maxW=Math.max(maxW,b.max.x-b.min.x);maxD=Math.max(maxD,b.max.z-b.min.z)});
  const cw=maxW+gap, cd=maxD+gap;
  kids.forEach((k,i)=>{const c=i%cols, rr=Math.floor(i/cols); const b=boxes[i]; const ctr=b.getCenter(new THREE.Vector3());
    k.position.set(c*cw-ctr.x, -b.min.y, rr*cd-ctr.z); k.visible=true;});
  const rowsN=Math.ceil(n/cols);
  const W=1900,H=Math.round(W*0.62); r.setSize(W,H,false);
  const s=scene(); s.add(gltf.scene);
  const gw=cols*cw+2, gd=rowsN*cd+2;
  ground(s,(cols-1)*cw/2,(rowsN-1)*cd/2,gw,gd,0);
  const ctr=new THREE.Vector3((cols-1)*cw/2,3,(rowsN-1)*cd/2);
  const cam=new THREE.PerspectiveCamera(30,W/H,0.1,1000);
  cam.position.copy(ctr).add(new THREE.Vector3(0.0,0.95,1.0).normalize().multiplyScalar(Math.max(gw,gd)*1.05)); cam.lookAt(ctr.x,1.8,ctr.z);
  r.render(s,cam);
  document.getElementById('n').textContent='Continent  ·  '+n+' buildings (procedural city 7, split into single buildings)';
  document.getElementById('i').textContent='buildings only, no roads or ground  ·  one cell = 16 source units';
  s.remove(gltf.scene); return [W,H];
};
window.names=()=>kids.map(k=>k.name);
window.ready=true;
</script>"""


class H(http.server.SimpleHTTPRequestHandler):
    def log_message(self, *a):
        pass

    def _send(self, b, ct):
        self.send_response(200)
        self.send_header("Content-Type", ct)
        self.send_header("Content-Length", str(len(b)))
        self.end_headers()
        self.wfile.write(b)

    def do_GET(self):
        if self.path == "/":
            return self._send(HTML.encode(), "text/html")
        if self.path == "/pack.glb":
            return self._send(open(PACK, "rb").read(), "model/gltf-binary")
        super().do_GET()


os.chdir(T)
srv = http.server.ThreadingHTTPServer(("127.0.0.1", 0), H)
PORT = srv.server_address[1]
threading.Thread(target=srv.serve_forever, daemon=True).start()
with sync_playwright() as p:
    br = p.chromium.launch(channel="chromium", args=["--use-gl=angle", "--use-angle=swiftshader",
                                                      "--enable-unsafe-swiftshader", "--ignore-gpu-blocklist"])
    pg = br.new_page(viewport={"width": 1024, "height": 800})
    pg.goto("http://127.0.0.1:%d/" % PORT)
    pg.wait_for_function("window.ready===true", timeout=180000)
    names = pg.evaluate("window.names()")
    for i, n in enumerate(names):
        pg.set_viewport_size({"width": 1024, "height": 800})
        pg.evaluate("i=>window.one(i)", i)
        pg.screenshot(path=os.path.join(OUT, n + ".png"))
        print("ok", n, flush=True)
    w, h = pg.evaluate("window.sheet(8)")
    pg.set_viewport_size({"width": w, "height": h + 56})
    pg.screenshot(path=SHEET)
    print("sheet", SHEET, flush=True)
    br.close()
