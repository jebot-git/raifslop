#include "native.h"
#include <algorithm>
#include <cmath>
#include <cstring>
using namespace godot;
namespace {
const char *TRANSFORMS[]={"head","left","right","rod","fish"};
const char *VECTORS[]={"feet","motion","tip","bobber","bait_position","mouth","target"};
const char *BODY[]={"hips","chest","left_foot","right_foot","left_knee","right_knee","left_elbow","right_elbow","left_hand","right_hand"};
const char *FLAGS[]={"caught","in_hand","xr","left_valid","right_valid","bobber_visible","bait_visible"};
const char *INTEGERS[]={"state","rig","bait","species","rod_tier"};
const char *DOUBLES[]={"user_height","length","reel_angle"};
const char *CURLS[]={"left_curls","right_curls"};
const char *EXPRESSIONS[]={"mouth","expressions"};
struct Writer{
 std::vector<uint8_t> bytes;bool ok=true;
 void integer(uint64_t value,int size){for(int i=0;i<size;++i)bytes.push_back(uint8_t(value>>(8*i)));}
 template<class T> void floating(T value){if(!std::isfinite(value)){ok=false;return;}uint64_t bits=0;std::memcpy(&bits,&value,sizeof(T));integer(bits,sizeof(T));}
 void vector(Vector3 value){floating(float(value.x));floating(float(value.y));floating(float(value.z));}
 void transform(const Variant &value){
  if(value.get_type()!=Variant::TRANSFORM3D){ok=false;return;}
  Transform3D t=value;if(!t.basis.is_finite()){ok=false;return;}vector(t.origin);
  Quaternion q=t.basis.orthonormalized().get_rotation_quaternion();
  for(double c:{double(q.x),double(q.y),double(q.z),double(q.w)}){
   if(!std::isfinite(c)||std::abs(c)>1.00001){ok=false;return;}
   integer(uint16_t(int16_t(std::round(c*32767.0))),2);
  }
 }
 void weights(const Variant &value){
  if(value.get_type()!=Variant::PACKED_FLOAT32_ARRAY){ok=false;return;}
  PackedFloat32Array values=value;if(values.size()!=5){ok=false;return;}
  for(int i=0;i<5;++i){double v=values[i];if(!std::isfinite(v)||v<0||v>1){ok=false;return;}integer(uint8_t(std::round(v*255.0)),1);}
 }
 PackedByteArray finish(){PackedByteArray result;if(!ok||bytes.size()>512)return result;result.resize(bytes.size());std::memcpy(result.ptrw(),bytes.data(),bytes.size());return result;}
};
struct Reader{
 const PackedByteArray &bytes;int64_t cursor=0;bool ok=true;
 uint64_t integer(int size){if(cursor+size>bytes.size()){ok=false;return 0;}uint64_t result=0;for(int i=0;i<size;++i)result|=uint64_t(bytes[cursor++])<<(i*8);return result;}
 template<class T> T floating(){uint64_t bits=integer(sizeof(T));T value;std::memcpy(&value,&bits,sizeof(T));return value;}
 Vector3 vector(){float x=floating<float>(),y=floating<float>(),z=floating<float>();return Vector3(x,y,z);}
 Transform3D transform(){
  Vector3 origin=vector();double values[4];for(double &v:values){int n=integer(2);if(n>=32768)n-=65536;v=n/32767.0;}
  Quaternion q(values[0],values[1],values[2],values[3]);
  if(std::abs(q.length_squared()-1.0)>.001){ok=false;return Transform3D();}
  return Transform3D(Basis(q.normalized()),origin);
 }
 PackedFloat32Array weights(){PackedFloat32Array values;values.resize(5);for(int i=0;i<5;++i)values[i]=integer(1)/255.0;return values;}
};
bool numeric(const Variant &v){return v.get_type()==Variant::FLOAT||v.get_type()==Variant::INT;}
}
// Public script wrapper owns semantic/schema validation. These kernels also
// check container types and bounds so malformed direct calls cannot overrun data.
PackedByteArray FishingNative::encode_pose(const Dictionary &data,const Array &locations){
 for(const char *key:{"body","face"})if(data.get(key,Variant()).get_type()!=Variant::DICTIONARY)return {};
 if(data.get("serial",Variant()).get_type()!=Variant::INT||data.get("location",Variant()).get_type()!=Variant::STRING)return {};
 const int64_t location=locations.find(data["location"]);if(location<0||location>65535)return {};
 Writer w;w.bytes.reserve(512);w.integer(2,1);w.integer(int64_t(data["serial"]),4);w.integer(location,2);
 int flags=0;for(int i=0;i<7;++i){Variant value=data.get(FLAGS[i],Variant());if(value.get_type()!=Variant::BOOL)return {};if(bool(value))flags|=1<<i;}w.integer(flags,1);
 for(const char *key:INTEGERS){Variant value=data.get(key,Variant());if(value.get_type()!=Variant::INT)return {};int64_t n=value;if(n<0||n>255)return {};w.integer(n,1);}
 for(const char *key:DOUBLES){Variant value=data.get(key,Variant());if(!numeric(value))return {};w.floating(double(value));}
 Variant curl=data.get("curl",Variant());if(!numeric(curl)||!std::isfinite(double(curl))||double(curl)<0||double(curl)>1)return {};
 w.integer(uint8_t(std::round(double(curl)*255.0)),1);w.weights(data.get("visemes",Variant()));
 for(const char *key:TRANSFORMS)w.transform(data.get(key,Variant()));
 for(const char *key:VECTORS){Variant value=data.get(key,Variant());if(value.get_type()!=Variant::VECTOR3)return {};w.vector(value);}
 Dictionary body=data["body"],face=data["face"];int mask=0;
 for(int i=0;i<10;++i)if(body.has(BODY[i]))mask|=1<<i;
 for(int i=0;i<2;++i)if(body.has(CURLS[i]))mask|=1<<(10+i);
 w.integer(mask,2);for(int i=0;i<10;++i)if(mask&(1<<i))w.transform(body[BODY[i]]);
 for(int i=0;i<2;++i)if(mask&(1<<(10+i)))w.weights(body[CURLS[i]]);
 const int face_mask=face.is_empty()?0:1|(face.has("mouth")?2:0)|(face.has("expressions")?4:0);w.integer(face_mask,1);
 if(face_mask){
  for(const char *key:{"look","blink"}){Variant value=face.get(key,Variant());if(value.get_type()!=Variant::VECTOR2)return {};Vector2 v=value;w.floating(float(v.x));w.floating(float(v.y));}
  for(const char *key:{"gaze","lids"})if(face.get(key,Variant()).get_type()!=Variant::BOOL)return {};
  w.integer(int(bool(face["gaze"]))|(int(bool(face["lids"]))<<1),1);
  for(const char *key:EXPRESSIONS)if(face.has(key))w.weights(face[key]);
 }
 return w.finish();
}
Dictionary FishingNative::decode_pose(const PackedByteArray &bytes,const Array &locations){
 if(bytes.size()<230||bytes.size()>512||bytes[0]!=2)return {};
 Reader r{bytes};r.integer(1);Dictionary data,body,face;data["serial"]=int64_t(r.integer(4));int location=r.integer(2);if(location>=locations.size())return {};data["location"]=locations[location];
 int flags=r.integer(1);for(int i=0;i<7;++i)data[FLAGS[i]]=bool(flags&(1<<i));
 for(const char *key:INTEGERS)data[key]=int64_t(r.integer(1));
 for(const char *key:DOUBLES)data[key]=r.floating<double>();
 data["curl"]=r.integer(1)/255.0;data["visemes"]=r.weights();
 for(const char *key:TRANSFORMS)data[key]=r.transform();
 for(const char *key:VECTORS)data[key]=r.vector();
 int mask=r.integer(2);if(mask&~0xfff)return {};
 for(int i=0;i<10;++i)if(mask&(1<<i))body[BODY[i]]=r.transform();
 for(int i=0;i<2;++i)if(mask&(1<<(10+i)))body[CURLS[i]]=r.weights();
 int face_mask=r.integer(1);if(face_mask!=0&&face_mask!=1&&face_mask!=3&&face_mask!=5&&face_mask!=7)return {};
 if(face_mask){
  for(const char *key:{"look","blink"}){float x=r.floating<float>(),y=r.floating<float>();face[key]=Vector2(x,y);}
  int validity=r.integer(1);if(validity>3)return {};face["gaze"]=bool(validity&1);face["lids"]=bool(validity&2);
  for(int i=0;i<2;++i)if(face_mask&(2<<i))face[EXPRESSIONS[i]]=r.weights();
 }
 if(!r.ok||r.cursor!=bytes.size())return {};
 data["body"]=body;data["face"]=face;return data;
}
