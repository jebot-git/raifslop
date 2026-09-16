"""Measure HDR sunlight and rebake retained foreground UVs.

Blender --background --python tools/bake_panorama_lighting.py -- [location ...]
Uses scene yaw/sky energy from locations.gd. No calibrated lux claim: energy is
relative to the retained HDR exposure. The solar cap is removed from sky fill
and represented once by a directional light; full irradiance includes both.
"""
import bpy
import json
import math
import re
import sys
from pathlib import Path
import numpy as np
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
BAKE = ROOT / 'assets/textures/lighting'
REPORT = BAKE / 'panorama_lighting.json'
IDS = ['lakeside', 'lake_pier', 'gray_pier', 'bell_park_pier', 'simons_town_rocks', 'blouberg_sunrise_2']


def profile(location):
    line = next(l for l in (ROOT/'scripts/locations.gd').read_text().splitlines() if '"id": "'+location+'"' in l)
    return tuple(float(re.search('"'+key+r'":\s*([-\d.]+)', line)[1]) for key in ['yaw', 'sky_energy'])


def environment(location, yaw, energy):
    image = bpy.data.images.load(str(ROOT/'assets/environment/locations'/f'{location}_8k.hdr'), check_existing=False)
    # Retain the solar disk for measurement; downsampling first loses peak energy.
    w, h = image.size
    pixels = np.empty(w*h*4, dtype=np.float32)
    image.pixels.foreach_get(pixels)
    pixels = pixels.reshape(h,w,4)
    # Blender image rows start at the bottom, unlike panorama UVs in Godot.
    top = pixels[h//2:,:,:3]
    luma = top @ np.array([.2126,.7152,.0722],dtype=np.float32)
    row,col = np.unravel_index(np.argmax(luma),luma.shape)
    latitude = ((np.arange(h//2)+.5)/h)*math.pi
    longitude = (np.arange(w)+.5)/w*math.tau
    peak_lat = latitude[row]
    peak_lon = longitude[col]
    # Broad cloud glow uses a wider cap; hard solar disks remain narrow.
    contrast = float(luma.max()/max(np.median(luma),1e-6))
    radius = math.radians(2 if contrast > 100 else 8 if contrast > 8 else 16)
    cosine = (np.sin(latitude)[:,None]*math.sin(peak_lat)
              +np.cos(latitude)[:,None]*math.cos(peak_lat)*np.cos(longitude[None,:]-peak_lon))
    cap = cosine > math.cos(radius)
    ring = (cosine <= math.cos(radius)) & (cosine > math.cos(radius*1.5))
    fill = np.median(top[ring],axis=0)
    excess = np.maximum(top-fill,0)*cap[:,:,None]
    solid_angle = np.cos(latitude)[:,None]*(math.pi/h)*(math.tau/w)
    weight = (excess @ np.array([.2126,.7152,.0722]))*solid_angle
    # Godot panorama_uv: atan(x,-z)/TAU; scene yaw rotates the local vector.
    theta = longitude-math.radians(yaw)
    direction = np.array([(weight*np.cos(latitude)[:,None]*np.sin(theta)[None,:]).sum(),
                          (weight*np.sin(latitude)[:,None]).sum(),
                          -(weight*np.cos(latitude)[:,None]*np.cos(theta)[None,:]).sum()])
    direction /= np.linalg.norm(direction)
    rgb = (excess*solid_angle[:,:,None]).sum(axis=(0,1))*energy
    sun_energy = float(np.max(rgb))
    color = rgb/max(sun_energy,1e-8)
    elevation = math.asin(float(direction[1]))
    azimuth = math.atan2(float(direction[0]),float(direction[2]))
    # Preserve the diffuse sky beneath the solar cap; no second HDR sun.
    top[cap] -= excess[cap]
    image.pixels.foreach_set(pixels.ravel())
    return image, {'source':f'{location}_8k.hdr', 'yaw_degrees':yaw, 'sky_energy':energy,
                   'sun_direction':direction.tolist(), 'sun_rotation':[-math.degrees(elevation),math.degrees(azimuth),0],
                   'sun_energy':sun_energy, 'sun_color_linear':color.tolist(),
                   'sun_angular_diameter_degrees':.53 if contrast>100 else math.degrees(radius)*2,
                   'peak_to_median':contrast, 'extraction_cap_degrees':math.degrees(radius),
                   'diffuse_sky_mean':float(((luma-excess @ np.array([.2126,.7152,.0722]))*solid_angle).sum()/math.tau*energy),
                   'samples':48,'resolution':1024, 'energy_units':'relative HDR radiance; not calibrated lux'}


def box(scene,name,position,size,material):
    # Input is game Y-up, Blender Z-up.
    x,y,z=position
    bpy.ops.mesh.primitive_cube_add(size=1,location=(x,-z,y))
    ob=bpy.context.object;ob.name=name
    ob.scale=(size[0],size[2],size[1])
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    ob.data.materials.append(material)
    # World planar tiling matches the existing concrete rather than stretching a cube UV.
    for p in ob.data.polygons:
        axes=sorted(range(3),key=lambda a:abs(p.normal[a]))[:2]
        for i in p.loop_indices:
            v=ob.matrix_world @ ob.data.vertices[ob.data.loops[i].vertex_index].co
            ob.data.uv_layers[0].data[i].uv=(v[axes[0]]*.5,v[axes[1]]*.5)
    ob.data.uv_layers[0].name='UVMap'
    return ob


def move_billboard(foreground):
    # Move 60 cm toward open water (-Godot Z), 15 cm toward the pier (-X).
    # Select the authored board/legs by their original footprint, not pier rails.
    indices=set()
    for p in foreground.data.polygons:
        name=foreground.data.materials[p.material_index].name
        if not name.startswith(('FG_steel','FG_billboard_print')):continue
        vertices=[foreground.data.vertices[i].co for i in p.vertices]
        if all(3.09<=v.x<=3.26 and -3.86<=v.y<=.66 for v in vertices):indices.update(p.vertices)
    assert indices, 'Authored billboard geometry was not found'
    for i in indices:
        foreground.data.vertices[i].co.x-=.15
        foreground.data.vertices[i].co.y+=.6
    foreground.data.update()


def add_lake_authored(scene,foreground):
    version=scene.get('authored_harbour_details',0)
    if version>=2:
        if version==2:
            move_billboard(foreground);scene['authored_harbour_details']=3
        return foreground
    concrete=next(m for m in foreground.data.materials if m.name.startswith('FG_concrete'))
    steel=next(m for m in foreground.data.materials if m.name.startswith('FG_steel'))
    added=[]
    def add(name,p,s,m):added.append(box(scene,name,p,s,m))
    if not scene.get('authored_harbour_details'):
        add('RearMaintenanceLanding',(0,-.16,5.3),(5.4,.32,1.6),concrete)
        add('RearMaintenanceBridge',(-1,-.12,9.15),(2.2,.24,6.1),concrete)
        for z in [6.1,8.7,12.2]:
            for x in [-2.12,.12]:add('BridgeSupport',(x,-.5,z),(.08,2.8,.08),steel)
        for x in [-2.12,.12]:
            for y in [.45,.9]:add('BridgeRail',(x,y,9.15),(.055,.055,6.1),steel)
        add('RightHarbourBillboard',(3.2,1.38,1.6),(.10,2.60,4.5),steel)
        for z in [-.3,3.5]:add('BillboardPost',(3.2,.65,z),(.10,4,.10),steel)
    # Printed face has its own bake islands and UV0 for the original SVG artwork.
    paper=bpy.data.materials.new('FG_billboard_print');paper.use_nodes=True
    paper.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=.9
    mesh=bpy.data.meshes.new('BillboardPrint')
    mesh.from_pydata([(3.115,-z,y) for z,y in [(-.55,.16),(3.75,.16),(3.75,2.60),(-.55,2.60)]],[],[(0,1,2,3)])
    mesh.materials.append(paper);uv=mesh.uv_layers.new(name='UVMap')
    for i,co in enumerate([(0,0),(1,0),(1,1),(0,1)]):uv.data[i].uv=co
    face=bpy.data.objects.new('BillboardPrint',mesh);scene.collection.objects.link(face);added.append(face)
    bpy.ops.object.select_all(action='DESELECT')
    for ob in [foreground]+added:ob.select_set(True)
    bpy.context.view_layer.objects.active=foreground
    bpy.ops.object.join()
    foreground.data.uv_layers.active_index=1
    foreground.data.uv_layers['BakedUV'].active_render=True
    bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.uv.smart_project(angle_limit=math.radians(66),island_margin=.003)
    bpy.ops.object.mode_set(mode='OBJECT')
    move_billboard(foreground)
    scene['authored_harbour_details']=3
    return foreground


def filter_poster(image, foreground):
    """Average sample noise only within the planar sign's atlas island.

    Its smooth irradiance can be filtered without touching artwork, atlas neighbours
    or the hard contact shadows on the ground. Return its mean for the bake report.
    """
    w,h=image.size
    yy,xx=np.mgrid[:h,:w];points=np.stack(((xx+.5)/w,(yy+.5)/h),axis=-1)
    mask=np.zeros((h,w),dtype=bool)
    uv=foreground.data.uv_layers['BakedUV']
    for polygon in foreground.data.polygons:
        if not foreground.data.materials[polygon.material_index].name.startswith('FG_billboard_print'):continue
        coords=np.array([uv.data[i].uv[:] for i in polygon.loop_indices])
        for i in range(1,len(coords)-1):
            a,b,c=coords[[0,i,i+1]];ab=b-a;ac=c-a;v=points-a
            det=ab[0]*ac[1]-ab[1]*ac[0]
            u=(v[:,:,0]*ac[1]-v[:,:,1]*ac[0])/det
            t=(ab[0]*v[:,:,1]-ab[1]*v[:,:,0])/det
            mask|=(u>=0)&(t>=0)&(u+t<=1)
    if not mask.any():return None
    data=np.empty(w*h*4,dtype=np.float32);image.pixels.foreach_get(data);data=data.reshape(h,w,4)
    weighted=data*mask[:,:,None];weights=mask.astype(np.float32)
    for axis in [0,1]:
        weighted=sum(np.roll(weighted,offset,axis=axis) for offset in range(-4,5))/9
        weights=sum(np.roll(weights,offset,axis=axis) for offset in range(-4,5))/9
    data[mask]=weighted[mask]/weights[mask,None]
    image.pixels.foreach_set(data.ravel())
    return data[mask,:3].mean(axis=0).tolist()


def bake(location):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    path=ROOT/'source/locations'/f'{location}_lighting.blend'
    with bpy.data.libraries.load(str(path)) as (src,dst):dst.scenes=[src.scenes[0]]
    scene=dst.scenes[0];bpy.context.window.scene=scene
    for image in bpy.data.images:
        if image.packed_file:continue
        for folder in ['source/textures/foreground','source/textures/original','assets/models/locations/lit']:
            candidate=ROOT/folder/Path(image.filepath).name
            if candidate.is_file():image.filepath=str(candidate);image.reload();break
    for ob in list(scene.objects):
        if ob.type=='LIGHT':bpy.data.objects.remove(ob,do_unlink=True)
    foreground=next(o for o in scene.objects if 'BakedForeground' in o.name)
    if location=='lake_pier':foreground=add_lake_authored(scene,foreground)
    bpy.ops.object.select_all(action='DESELECT');foreground.select_set(True)
    bpy.context.view_layer.objects.active=foreground
    yaw,energy=profile(location)
    panorama,record=environment(location,yaw,energy)
    world=bpy.data.worlds.new('Measured panorama sky');world.use_nodes=True;scene.world=world
    nodes=world.node_tree.nodes;links=world.node_tree.links
    texture=nodes.new('ShaderNodeTexEnvironment');texture.image=panorama
    coord=nodes.new('ShaderNodeTexCoord');rotate=nodes.new('ShaderNodeVectorRotate')
    rotate.rotation_type='AXIS_ANGLE';rotate.inputs['Axis'].default_value=(0,0,1)
    rotate.inputs['Angle'].default_value=math.pi/2-math.radians(yaw)
    links.new(coord.outputs['Generated'],rotate.inputs['Vector']);links.new(rotate.outputs['Vector'],texture.inputs['Vector'])
    links.new(texture.outputs['Color'],nodes['Background'].inputs['Color'])
    nodes['Background'].inputs['Strength'].default_value=energy
    # Diffuse sky has no sharp solar disk; 1K keeps the retained source compact.
    panorama.scale(1024,512)
    panorama.pack()
    light=bpy.data.lights.new('Panorama measured sun','SUN')
    light.energy=record['sun_energy'];light.color=record['sun_color_linear']
    light.angle=math.radians(record['sun_angular_diameter_degrees'])
    sun=bpy.data.objects.new(light.name,light);scene.collection.objects.link(sun)
    d=record['sun_direction'];sun.rotation_euler=Vector((-d[0],d[2],-d[1])).to_track_quat('-Z','Y').to_euler()
    scene.render.engine='CYCLES';scene.cycles.device='CPU';scene.cycles.samples=48
    scene.render.threads_mode='FIXED';scene.render.threads=8
    scene.render.bake.margin=8;scene.view_settings.view_transform='Standard'
    originals=[]
    for m in foreground.data.materials:
        bs=m.node_tree.nodes.get('Principled BSDF')
        if bs:originals.append((bs,bs.inputs['Metallic'].default_value));bs.inputs['Metallic'].default_value=0
    kinds=['sky','irradiance']+(['ao'] if location=='lake_pier' else [])
    for kind in kinds:
        sun.hide_render=kind!='irradiance'
        image=bpy.data.images.new(location+'_'+kind,1024,1024,alpha=False,float_buffer=kind!='ao')
        image.colorspace_settings.name='Non-Color'
        for m in foreground.data.materials:
            n=m.node_tree.nodes.new('ShaderNodeTexImage');n.image=image;m.node_tree.nodes.active=n
        scene.render.bake.use_pass_direct=True;scene.render.bake.use_pass_indirect=True;scene.render.bake.use_pass_color=False
        bpy.ops.object.bake(type='AO' if kind=='ao' else 'DIFFUSE',uv_layer='BakedUV')
        if location=='lake_pier' and kind!='ao':
            mean=filter_poster(image,foreground)
            if kind=='irradiance':record['billboard_irradiance']=mean
        image.filepath_raw=str(BAKE/(location+'_'+kind+('.png' if kind=='ao' else '.exr')))
        image.file_format='PNG' if kind=='ao' else 'OPEN_EXR'
        if kind=='ao':image.save()
        else:
            scene.render.image_settings.file_format='OPEN_EXR';scene.render.image_settings.color_mode='RGB'
            scene.render.image_settings.color_depth='16';scene.render.image_settings.exr_codec='ZIP'
            image.save_render(image.filepath_raw,scene=scene)
        for m in foreground.data.materials:
            for n in list(m.node_tree.nodes):
                if n.type=='TEX_IMAGE' and n.image==image:m.node_tree.nodes.remove(n)
        bpy.data.images.remove(image)
        print('PANORAMA_BAKED',location,kind,flush=True)
    for bs,metal in originals:bs.inputs['Metallic'].default_value=metal
    sun.hide_render=False
    foreground.data.uv_layers.active_index=0;foreground.data.uv_layers['UVMap'].active_render=True
    # Export only the changed atlas/geometry. Other models retain identical UVs.
    if location=='lake_pier':
        output=ROOT/'assets/models/locations/lit/lake_pier.glb'
        bpy.ops.export_scene.gltf(filepath=str(output),export_format='GLB',use_active_scene=True,export_yup=True,export_apply=True,export_lights=False)
        manifest=ROOT/'assets/models/locations/manifest.json';data=json.loads(manifest.read_text())
        data[location]['bytes']=output.stat().st_size
        data[location]['triangles']=sum(sum(len(p.vertices)-2 for p in ob.data.polygons) for ob in scene.objects if ob.type=='MESH')
        manifest.write_text(json.dumps(data,indent=2)+'\n')
    bpy.data.libraries.write(str(path),{scene},path_remap='RELATIVE',fake_user=True,compress=True)
    records=json.loads(REPORT.read_text()) if REPORT.exists() else {}
    records[location]=record;REPORT.write_text(json.dumps(records,indent=2)+'\n')
    print('PANORAMA_LIGHTING_DONE',location,json.dumps(record),flush=True)

if __name__=='__main__':
    locations=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else IDS
    unknown=set(locations)-set(IDS)
    if unknown:raise ValueError(f"Unknown photographic locations: {sorted(unknown)}")
    for location in locations:bake(location)
