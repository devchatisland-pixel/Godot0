import sys, os, json, http.server, threading, functools
from playwright.sync_api import sync_playwright
T = os.path.join(os.path.dirname(os.path.abspath(__file__)), "_preview_root")
SRC = r"F:\Godot0-city\FREEMODELS\_incoming"
OUT = r"F:\Godot0-city\docs\model_previews"
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
ok=[];bad=[]
with sync_playwright() as p:
    br=p.chromium.launch(channel='chromium',args=['--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader','--ignore-gpu-blocklist'])
    pg=br.new_page(viewport={'width':1024,'height':800})
    pg.goto('http://127.0.0.1:8765/'); pg.wait_for_function('window.ready===true')
    for f in files:
        mb=round(os.path.getsize(os.path.join(SRC,f))/1048576,1)
        try:
            pg.evaluate('([n,m])=>window.render(n,m)',[f,mb])
            pg.screenshot(path=os.path.join(OUT,os.path.splitext(f)[0]+'.png')); ok.append(f); print('ok',f,flush=True)
        except Exception as e:
            bad.append((f,str(e)[:150])); print('FAIL',f,str(e)[:150],flush=True)
    br.close()
pass
