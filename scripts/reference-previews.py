"""Generate local fallback illustrations, NOT GPU test snapshots.

CPU translation of the four SDF compositions and GGX direct lighting.
Procedural micro-normal/volume noise is approximated with sine fields here;
therefore these images are illustrative, not pixel references for the WGSL.
Requires Python, numpy, numba, scipy and Pillow. Not a runtime dependency.
Run from the project root: python scripts/reference-previews.py
"""
from pathlib import Path
import json, subprocess, math, sys
import numpy as np
from numba import njit, prange, set_num_threads
from PIL import Image, PngImagePlugin
from scipy.ndimage import map_coordinates
set_num_threads(4)
ROOT=Path(__file__).resolve().parents[1]
raw=subprocess.check_output(['node','--input-type=module','-e',"import {PRESETS,preset} from './src/model.ts'; import {uniforms} from './src/gpu/uniforms.ts'; console.log(JSON.stringify(PRESETS.map(p=>({id:p.id,s:preset(p.id),u:Object.values(uniforms(preset(p.id),960,540,{left:0,top:0,width:960,height:540},'final')).flat()}))));"],cwd=ROOT,text=True)
PRESETS=json.loads(raw)
PI=math.pi
@njit(cache=True)
def vec(x,y,z):return np.array([x,y,z])
@njit(cache=True)
def length(p):return math.sqrt(np.dot(p,p))
@njit(cache=True)
def norm(p):return p/max(1e-8,length(p))
@njit(cache=True)
def rot(x,y,a):return math.cos(a)*x-math.sin(a)*y,math.sin(a)*x+math.cos(a)*y
@njit(cache=True)
def phase(u):
 s=(int(u[3])*747796405+2891336453)&0xffffffff
 w=(((s>>((s>>28)+4))^s)*277803737)&0xffffffff
 return (((w>>22)^w)&0xffffff)/16777216*2*PI
@njit(cache=True)
def node(i,u):
 n=u[50]; f=float(i); ph=phase(u); a=f*2*PI/n+ph*.15
 if u[8]<.5:return vec(.72+.22*math.sin(f*2.4+ph),-1.8+f*.46,-.14+.34*math.cos(f*1.7))
 if u[8]<1.5:return vec(math.cos(a)*1.35*u[10],math.sin(a)*1.35*u[10],.45*math.sin(a*2+ph))
 if u[8]<2.5:return vec(math.cos(a)*1.06,.5*math.sin(a),-.52+.38*math.sin(a))
 return vec(.25*math.sin(f*1.9),(f-(n-1)*.5)*.83*u[10],.25*math.cos(f*1.7))
@njit(cache=True)
def core(u):
 if u[8]<.5:return vec(-.06,1.48,.1)
 if u[8]<1.5:return node(0,u)
 if u[8]<2.5:return vec(.06,.14,.16)
 return node(int(u[50])-1,u)
@njit(cache=True)
def ell(p,r):
 k0=length(p/r);k1=length(p/(r*r))
 if k1<.0001:return -min(r)
 return k0*(k0-1)/k1
@njit(cache=True)
def geo(p,u):
 x,y,z=p;body=10.;ph=phase(u)
 if u[8]<.5:
  for i in range(3):
   xx=x-.16*math.sin(y*1.6+ph*.25);zz=z-.16*math.cos(y*1.3+i)
   xx,zz=rot(xx,zz,y*u[9]+i*2.1+.09*math.sin(u[17]))
   r=(.48+.13*math.sin(y*1.9+ph+i*.7))*u[10]
   ring=abs(math.sqrt(xx*xx+zz*zz*1.55**2)-r)*.64-u[11]
   body=min(body,max(ring,-xx-.06,abs(y+i*.21)-1.78+i*.29))
  q=p-vec(-.05,1.39,-.12)
  body=min(body,max(length(q)-.56*u[10],-(length(q-vec(.16,.16,.22))-.55*u[10])))
 elif u[8]<1.5:
  for i in range(int(u[50])):
   q=p-node(i,u);q[0],q[1]=rot(q[0],q[1],i*2*PI/u[50])
   body=min(body,max(ell(q,vec(.35,.55,.32)),-ell(q-vec(.1,.09,.12),vec(.34,.5,.30))))
 elif u[8]<2.5:
  q=p.copy();q[0],q[1]=rot(q[0],q[1],.18*q[2]*u[9])
  body=max(ell(q,vec(1.04,1.47,.79)*u[10]),-ell(q-vec(.25,.24,.29),vec(1.02,1.3,.75)*u[10]))
  tor=math.sqrt((math.sqrt(q[0]**2+q[2]**2)-.79*u[10])**2+(q[1]*.72)**2)-u[11]
  body=min(body,tor)
 else:
  for i in range(int(u[50])):
   q=p-node(i,u);q[0],q[1]=rot(q[0],q[1],u[9]*i)
   body=min(body,max(ell(q,vec(.53,.42,.35)),-ell(q-vec(.14,.09,.14),vec(.48,.37,.32))))
 material=1
 d=length(p-core(u))-u[21]
 if d<body:body=d;material=2
 for i in range(int(u[50])):
  d=length(p-node(i,u))-(.043 if u[8]<.5 else .075)
  if d<body:body=d;material=3
 return body,material
@njit(cache=True)
def normal(p,u):
 e=.0015;n=vec(0.,0.,0.)
 for v in (vec(1.,-1.,-1.),vec(-1.,-1.,1.),vec(-1.,1.,-1.),vec(1.,1.,1.)):n+=v*geo(p+v*e,u)[0]
 n=norm(n)
 q=p*18+phase(u)
 # Deliberately approximate preview-only microtexture; not the MIT simplex port.
 grad=vec(math.cos(q[0])*math.sin(q[1]),math.sin(q[0])*math.cos(q[1]),math.cos(q[2]*.7))
 return norm(n-u[31]*.4*(grad-n*np.dot(grad,n)))
@njit(cache=True)
def brdf(n,v,l,u):
 nv=max(np.dot(n,v),.001);nl=max(np.dot(n,l),0.)
 if nl<=0:return vec(0.,0.,0.)
 h=norm(l+v);nh=max(np.dot(n,h),0.);vh=max(np.dot(v,h),0.)
 a=max(u[28]**2,.002);a2=a*a;D=a2/(PI*(nh*nh*(a2-1)+1)**2)
 vis=.5/max(nl*math.sqrt(nv*nv*(1-a2)+a2)+nv*math.sqrt(nl*nl*(1-a2)+a2),.0001)
 metal=u[36:39];f0=.04*(1-u[29])+metal*u[29];F=f0+(1-f0)*(1-vh)**5
 return ((1-F)*(1-u[29])*metal/PI+D*vis*F)*nl
@njit(cache=True)
def shadow(p,l,d,u):
 t=.014
 for i in range(24):
  if t>=d-.025:break
  h=geo(p+l*t,u)[0]
  if h<.0007:return 0.
  t+=max(h*.78,.012)
 return 1.
@njit(cache=True)
def point(p,n,v,pos,intensity,radius,u):
 delta=pos-p;d=max(length(delta),.0001);l=delta/d
 return brdf(n,v,l,u)*intensity/(d*d)*shadow(p+n*.004,l,max(0.,d-radius),u)
@njit(cache=True)
def light(p,n,v,u):
 key=vec(3.8*math.sin(u[22]),2.8,3.8*math.cos(u[22]));c=vec(0.,0.,0.)
 energy=u[40:43]
 for i in range(4):
  a=i*PI/2+PI/4
  c+=point(p,n,v,key+vec(math.cos(a)*.9,math.sin(a)*.9,0.),energy*u[20]*.72/(4*PI),0.,u)
 c+=point(p,n,v,vec(-3.,-1.,2.),u[36:39]*u[20]*u[23]/PI,0.,u)
 c+=point(p,n,v,core(u),energy*u[20]*.2/(4*PI),u[21],u)
 for i in range(int(u[50])):c+=point(p,n,v,node(i,u),energy*u[20]*.12/(4*PI*u[50]),.043 if u[8]<.5 else .075,u)
 return c
@njit(cache=True)
def density(p,u):
 x,y,z=p
 if u[8]<.5:r=math.sqrt((x-.2*math.sin(y*1.25+.15*math.sin(u[17])))**2+(z-.04)**2)
 elif u[8]<1.5:r=math.sqrt((math.sqrt(x*x+y*y)-1.35*u[10])**2+z*z)
 elif u[8]<2.5:r=length(p*vec(1.5,.72,1.5))
 else:r=math.sqrt((x-.12*math.sin(y*2))**2+z*z)
 noise=math.sin(x*2.3*u[26]+phase(u))*math.cos(y*2.3*u[26]+.24*math.cos(u[17]))*math.sin(z*2.3*u[26]+.24*math.sin(u[17]))
 return u[24]*math.exp(-r*r*11)*math.exp(-(abs(y)/2.6)**6)*(.65+.35*noise)
@njit(cache=True,parallel=True)
def render(w,h,u):
 img=np.zeros((h,w,3),dtype=np.float64)
 for yy in prange(h):
  for xx in range(w):
   x=(xx+.5-w*.5)/h-u[19]*.25;y=-(yy+.5-h*.5)/h-u[52]*.25
   x,y=rot(x,y,u[16]);ro=vec(0.,0.,6.8);rd=norm(vec(x*5.15/u[18],y*5.15/u[18],-6.8))
   ro[0],ro[2]=rot(ro[0],ro[2],u[53]);rd[0],rd[2]=rot(rd[0],rd[2],u[53])
   ro[1],ro[2]=rot(ro[1],ro[2],u[54]);rd[1],rd[2]=rot(rd[1],rd[2],u[54])
   bound=max(3.5,(u[50]-1)*.415*u[10]+.8) if u[8]>2.5 else 3.5
   b=np.dot(ro,rd);disc=b*b-np.dot(ro,ro)+bound*bound
   c=u[32:35].copy()
   if disc<=0:img[yy,xx]=c;continue
   near=max(0.,-b-math.sqrt(disc));far=-b+math.sqrt(disc);t=near;hit=False;mat=0
   for i in range(160):
    if t>=far:break
    d,mat=geo(ro+rd*t,u)
    if d<max(.0008,t/h*.16):hit=True;break
    t+=max(d*.63,.0006)
   if hit:
    p=ro+rd*t
    if mat>1:
     radius=u[21] if mat==2 else (.043 if u[8]<.5 else .075)
     share=.2 if mat==2 else .12/u[50]
     c=u[40:43]*u[20]*share/(4*PI*PI*radius*radius)
    else:c=light(p,normal(p,u),-rd,u)
   end=t if hit else far;dt=(end-near)/32;tr=1.;radiance=vec(0.,0.,0.)
   for i in range(32):
    p=ro+rd*(near+(i+.5)*dt);st=density(p,u)*1.8;stepT=math.exp(-st*dt)
    delta=core(u)-p;d2=max(np.dot(delta,delta),u[21]*u[21]);ct=np.dot(norm(delta),rd);g=u[25]
    hg=(1-g*g)/(4*PI*max(1+g*g-2*g*ct,.001)**1.5)
    rad=u[40:43]*u[20]*.2/(4*PI*d2)*hg
    radiance+=tr*(1-stepT)*.85*rad;tr*=stepT
   img[yy,xx]=np.maximum(c*tr+radiance,0)
 return img

def tone(c,u):
 e=np.maximum(c*2**u[35],0);l=np.sum(e*np.array([.2126,.7152,.0722]),axis=-1,keepdims=True)
 return e/(1+l)
def post(hdr,u):
 h,w,_=hdr.shape; yy,xx=np.mgrid[0:h,0:w];sc=np.zeros_like(hdr);weight=0;radius=u[46]*h/1080
 for r in range(1,4):
  wt=math.exp(-r*r*.5)
  for i in range(8):
   a=i*2*PI/8;coords=[yy+math.sin(a)*radius*r,xx+math.cos(a)*radius*r]
   for channel in range(3):sc[:,:,channel]+=map_coordinates(hdr[:,:,channel],coords,order=1,mode='nearest')*wt
   weight+=wt
 optical=hdr*(1-u[43])+sc/weight*u[43];col=tone(optical,u)
 bg=tone(u[32:35][None,:],u)[0];ink=tone((u[40:43]*3)[None,:],u)[0]
 if u[12]==1:
  cell=u[13]*h/1080;cx=(np.floor((xx+.5)/cell)+.5)*cell;cy=(np.floor((yy+.5)/cell)+.5)*cell
  sample=np.stack([map_coordinates(optical[:,:,c],[cy-.5,cx-.5],order=1,mode='nearest') for c in range(3)],axis=-1)
  inten=np.clip(np.sum(tone(sample,u)*[.2126,.7152,.0722],axis=-1)*2,0,1);rad=cell*u[14]*np.sqrt(inten)
  dist=np.sqrt((xx+.5-cx)**2+(yy+.5-cy)**2);t=np.clip((dist-(rad-.65))/1.3,0,1);cover=(1-t*t*(3-2*t))*(inten>=.025)
  col=bg+(ink-bg)*cover[:,:,None]
 elif u[12]==2:
  bayer=np.array([1,33,9,41,3,35,11,43,49,17,57,25,51,19,59,27,13,45,5,37,15,47,7,39,61,29,53,21,63,31,55,23,4,36,12,44,2,34,10,42,52,20,60,28,50,18,58,26,16,48,8,40,14,46,6,38,64,32,56,24,62,30,54,22]).reshape(8,8)/64
  cell=max(1,u[13]*h/1080*.25);p=bayer[(np.floor((yy+.5)/cell).astype(int)%8),(np.floor((xx+.5)/cell).astype(int)%8)]
  val=np.sum(col*[.2126,.7152,.0722],axis=-1)*1.7>=p
  col=col*(1-u[15])+(bg+(ink-bg)*val[:,:,None])*u[15]
 elif u[12]==3:col*= (.83+.17*np.cos((yy+.5)/max(h/1080,.2)*PI))[:,:,None]
 vig=np.maximum(0,1-u[45]*(((xx+.5-w*.5)/h)**2+((yy+.5-h*.5)/h)**2)*.8)
 col=np.maximum(col*vig[:,:,None],0)**u[39]
 display=np.where(col<=.0031308,col*12.92,1.055*np.maximum(col,0)**(1/2.4)-.055)
 # Exact same integer hash as shader, not a global random generator.
 n=(xx+yy*65537+int(u[3])*1597).astype(np.uint32);st=n*np.uint32(747796405)+np.uint32(2891336453)
 word=((st>>((st>>28)+4))^st)*np.uint32(277803737);grain=(((word>>22)^word)&0xffffff).astype(float)/16777216-.5
 return np.uint8(np.clip(display+grain[:,:,None]*u[44],0,1)*255+.5)

if __name__=='__main__':
 ids=sys.argv[1:]
 for p in PRESETS:
  if ids and p['id'] not in ids:continue
  print('CPU reference:',p['id'],flush=True)
  u=np.array(p['u'],dtype=float);w,h=512,288
  hdr=render(w,h,u);image=Image.fromarray(post(hdr,u))
  info=PngImagePlugin.PngInfo();info.add_text('Description','CPU illustration; GPU implementation not validated. Noise is approximated. See scripts/reference-previews.py.')
  (ROOT/'src/assets/presets').mkdir(parents=True,exist_ok=True)
  image.save(ROOT/f"src/assets/presets/{p['id']}.png",pnginfo=info)
  print('wrote',p['id'],flush=True)
