#include "native.h"
#include <godot_cpp/godot.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/classes/geometry3d.hpp>
#include <algorithm>
#include <cmath>
using namespace godot;
void FishingNative::_bind_methods(){
 ClassDB::bind_method(D_METHOD("set_faces","faces"),&FishingNative::set_faces);
 ClassDB::bind_method(D_METHOD("segment_obstructed","start","end"),&FishingNative::segment_obstructed);
 ClassDB::bind_method(D_METHOD("surface_bounds","vertices","bones","weights","palette","mesh","skeleton"),&FishingNative::surface_bounds);
 ClassDB::bind_method(D_METHOD("encode_pose","data","locations"),&FishingNative::encode_pose);
 ClassDB::bind_method(D_METHOD("decode_pose","bytes","locations"),&FishingNative::decode_pose);
}
int FishingNative::partition(int begin,int end){
 Branch node;node.begin=begin;node.end=end;node.box=faces[begin].box;
 for(int i=begin+1;i<end;++i)node.box=node.box.merge(faces[i].box);
 const int index=branches.size();branches.push_back(node);
 if(end-begin>8){
  const Vector3 size=node.box.size;int axis=size.x>size.y?0:1;if(size.z>size[axis])axis=2;
  const int middle=(begin+end)/2;
  std::nth_element(faces.begin()+begin,faces.begin()+middle,faces.begin()+end,[axis](const Face &a,const Face &b){return a.center[axis]<b.center[axis];});
  const int left=partition(begin,middle),right=partition(middle,end);
  branches[index].left=left;branches[index].right=right;
 }
 return index;
}
bool FishingNative::set_faces(const Array &input){
 faces.clear();branches.clear();faces.reserve(input.size());
 for(int i=0;i<input.size();++i){
  if(input[i].get_type()!=Variant::PACKED_VECTOR3_ARRAY){faces.clear();return false;}
  PackedVector3Array tri=input[i];
  if(tri.size()!=3||!tri[0].is_finite()||!tri[1].is_finite()||!tri[2].is_finite()){faces.clear();return false;}
  Face face{tri[0],tri[1],tri[2],(tri[0]+tri[1]+tri[2])/3,AABB(tri[0],Vector3())};
  face.box.expand_to(tri[1]);face.box.expand_to(tri[2]);face.box.grow_by(.00001);faces.push_back(face);
 }
 if(!faces.empty())partition(0,faces.size());
 return true;
}
static bool crosses(const AABB &box,Vector3 origin,Vector3 delta){
 double low=0,high=1;
 for(int axis=0;axis<3;++axis){
  const double a=box.position[axis],b=a+box.size[axis];
  if(delta[axis]==0){if(origin[axis]<a||origin[axis]>b)return false;continue;}
  double near=(a-origin[axis])/delta[axis],far=(b-origin[axis])/delta[axis];if(near>far)std::swap(near,far);
  low=std::max(low,near);high=std::min(high,far);if(low>high)return false;
 }
 return true;
}
bool FishingNative::segment_obstructed(Vector3 start,Vector3 end) const{
 if(branches.empty()||!start.is_finite()||!end.is_finite())return false;
 std::vector<int> stack{0};const Vector3 delta=end-start;
 while(!stack.empty()){
  const Branch &node=branches[stack.back()];stack.pop_back();
  if(!crosses(node.box,start,delta))continue;
  if(node.left>=0){stack.push_back(node.left);stack.push_back(node.right);continue;}
  for(int i=node.begin;i<node.end;++i){
   const Face &f=faces[i];
   if(Geometry3D::get_singleton()->segment_intersects_triangle(start,end,f.a,f.b,f.c).get_type()!=Variant::NIL)return true;
  }
 }
 return false;
}
Dictionary FishingNative::surface_bounds(const PackedVector3Array &vertices,const PackedInt32Array &bones,const PackedFloat32Array &weights,const Array &palette,Transform3D mesh,Transform3D skeleton){
 Dictionary out;out["ok"]=false;
 const bool skinned=!bones.is_empty()||!weights.is_empty();
 const int count=vertices.is_empty()?0:bones.size()/vertices.size();
 if(skinned&&((count!=4&&count!=8)||bones.size()!=vertices.size()*count||weights.size()!=bones.size()))return out;
 std::vector<Transform3D> transforms;
 for(int i=0;i<palette.size();++i){if(palette[i].get_type()!=Variant::TRANSFORM3D)return out;transforms.push_back(palette[i]);}
 Vector3 minimum(INFINITY,INFINITY,INFINITY),maximum(-INFINITY,-INFINITY,-INFINITY);
 for(int64_t i=0;i<vertices.size();++i){
  const Vector3 vertex=vertices[i];Vector3 point=mesh.xform(vertex);
  if(skinned){
   Vector3 posed=vertex;
   for(int j=0;j<count;++j){
    const int64_t offset=i*count+j;const float weight=weights[offset];if(weight<=0)continue;
    const int bind=bones[offset];if(bind<0||bind>=int(transforms.size())||!std::isfinite(weight))return out;
    posed+=(transforms[bind].xform(vertex)-vertex)*weight;
   }
   point=skeleton.xform(posed);
  }
  if(!point.is_finite())return out;
  minimum=minimum.min(point);maximum=maximum.max(point);
 }
 out["ok"]=true;out["bounds"]=minimum.is_finite()?AABB(minimum,maximum-minimum):AABB();return out;
}
static void initialize(ModuleInitializationLevel level){if(level==MODULE_INITIALIZATION_LEVEL_SCENE)GDREGISTER_CLASS(FishingNative);}
static void terminate(ModuleInitializationLevel){}
extern "C" GDExtensionBool GDE_EXPORT fishing_native_init(GDExtensionInterfaceGetProcAddress get_proc,GDExtensionClassLibraryPtr library,GDExtensionInitialization *initialization){
 GDExtensionBinding::InitObject init(get_proc,library,initialization);init.register_initializer(initialize);init.register_terminator(terminate);init.set_minimum_library_initialization_level(MODULE_INITIALIZATION_LEVEL_SCENE);return init.init();
}
