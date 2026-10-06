extends RefCounted
## Shared numerical bank surface for clients and dedicated servers.
static func ground_height(x:float,z:float,far:bool)->float:
 # Match the authored terrain triangles, including their linear interpolation.
 var x0:float=floor((x+120.0)/4.0)*4.0-120.0
 var fx:float=(x-x0)/4.0
 var edge0:float=sin(x0*.07)*.65+sin(x0*.19)*.2
 var edge1:float=sin((x0+4)*.07)*.65+sin((x0+4)*.19)*.2
 var edge:float=lerpf(edge0,edge1,fx)
 var t:float=clampf((-19.0+edge-z)/45.0 if far else (z+3.6-edge)/38.0,0,1)
 var start:float=0.0 if t<.09 else .09
 var step:float=.09/12.0 if t<.09 else .91/12.0
 var t0:float=start+floor((t-start)/step)*step
 var fz:float=(t-t0)/step
 var a:float=bank_height(x0,t0,far)
 var b:float=bank_height(x0+4,t0,far)
 var c:float=bank_height(x0,t0+step,far)
 var d:float=bank_height(x0+4,t0+step,far)
 return a+(b-a)*fx+(c-a)*fz if fx+fz<=1.0 else d+(c-d)*(1.0-fx)+(b-d)*(1.0-fz)
static func bank_height(x:float,t:float,far:bool)->float:
 if not far:return -.6+minf(t*15.0,1.0)*.65+maxf(t-.2,0)*1.8
 return -.8+minf(t*7.0,1.0)*2.3+t*(3.0+sin(x*.055)*2.0)+sin(x*.13+t*8)*.22*minf(t*8,1)
