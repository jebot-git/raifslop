"""Fold existing rod GLBs into three sections, preserving materials and UVs."""
from pathlib import Path
import json, struct
import numpy as np
ROOT=Path(__file__).resolve().parents[1]
def fold(path):
    raw=path.read_bytes();size=struct.unpack_from('<I',raw,12)[0];doc=json.loads(raw[20:20+size]);binary=bytearray(raw[28+size:])
    node=doc['nodes'][0];x,y,z,w=node.get('rotation',[0,0,0,1])
    rotation=np.array([[1-2*(y*y+z*z),2*(x*y-z*w),2*(x*z+y*w)],[2*(x*y+z*w),1-2*(x*x+z*z),2*(y*z-x*w)],[2*(x*z-y*w),2*(y*z+x*w),1-2*(x*x+y*y)]])
    def read(index):
        a=doc['accessors'][index];v=doc['bufferViews'][a['bufferView']];count={'SCALAR':1,'VEC2':2,'VEC3':3}[a['type']];dtype={5126:'<f4',5123:'<u2',5125:'<u4'}[a['componentType']]
        return np.ndarray((a['count'],count),dtype=dtype,buffer=binary,offset=v.get('byteOffset',0)+a.get('byteOffset',0),strides=(v.get('byteStride',count*np.dtype(dtype).itemsize),np.dtype(dtype).itemsize)).copy()
    def clip(poly,plane,above):
        result=[]
        for a,b in zip(poly,poly[1:]+poly[:1]):
            ai=(a[2]>=plane) if above else (a[2]<=plane);bi=(b[2]>=plane) if above else (b[2]<=plane)
            if ai:result.append(a)
            if ai!=bi:result.append(a+(b-a)*((plane-a[2])/(b[2]-a[2])))
        return result
    def store(values,kind):
        values=np.asarray(values,dtype='<f4');binary.extend(b'\0'*((-len(binary))%4));offset=len(binary);binary.extend(values.tobytes())
        doc['bufferViews'].append({'buffer':0,'byteOffset':offset,'byteLength':values.nbytes})
        a={'bufferView':len(doc['bufferViews'])-1,'componentType':5126,'count':len(values),'type':kind}
        if kind=='VEC3':a.update(min=values.min(axis=0).tolist(),max=values.max(axis=0).tolist())
        doc['accessors'].append(a);return len(doc['accessors'])-1
    primitives=[]
    for primitive in doc['meshes'][0]['primitives']:
        attrs=primitive['attributes'];pos=read(attrs['POSITION'])@rotation.T+node.get('translation',[0,0,0]);normal=read(attrs['NORMAL'])@rotation.T;uv=read(attrs['TEXCOORD_0'])
        vertices=np.concatenate([pos,normal,uv],axis=1);indices=read(primitive['indices']).ravel() if 'indices' in primitive else np.arange(len(vertices));result=[]
        for ids in indices.reshape(-1,3):
            triangle=[vertices[i] for i in ids]
            for part in range(3):
                poly=clip(triangle,-.45,part==0)
                if part>0:poly=clip(poly,-1.05,part==1)
                if len(poly)<3:continue
                for i in range(1,len(poly)-1):
                    for point in [poly[0],poly[i],poly[i+1]]:
                        point=point.copy()
                        if part==1:
                            point[0]=.03-point[0];point[2]=-.90-point[2];point[3]*=-1;point[5]*=-1
                        elif part==2:point[0]+=.06;point[2]+=1.20
                        point[3:6]/=max(np.linalg.norm(point[3:6]),1e-8);result.append(point)
        result=np.asarray(result)
        primitives.append({'attributes':{'POSITION':store(result[:,:3],'VEC3'),'NORMAL':store(result[:,3:6],'VEC3'),'TEXCOORD_0':store(result[:,6:],'VEC2')},'material':primitive['material'],'mode':4})
    doc['meshes']=[{'name':path.stem+' folded','primitives':primitives}];doc['nodes']=[{'mesh':0,'name':'Folded rod'}];doc['scenes']=[{'nodes':[0]}];doc['scene']=0;doc['buffers']=[{'byteLength':len(binary)}]
    encoded=json.dumps(doc,separators=(',',':')).encode();encoded+=b' '*((-len(encoded))%4);binary.extend(b'\0'*((-len(binary))%4))
    output=struct.pack('<III',0x46546c67,2,28+len(encoded)+len(binary))+struct.pack('<II',len(encoded),0x4e4f534a)+encoded+struct.pack('<II',len(binary),0x004e4942)+binary
    path.with_name(path.stem+'_folded.glb').write_bytes(output);print(path.stem,'folded',len(output),'bytes')
for name in ['willow','reed','heron','kingfisher']:fold(ROOT/'assets/models/rods'/f'{name}.glb')
