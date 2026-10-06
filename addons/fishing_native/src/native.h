#pragma once
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/aabb.hpp>
#include <godot_cpp/variant/transform3d.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <vector>
namespace godot {
class FishingNative : public RefCounted {
 GDCLASS(FishingNative,RefCounted)
 struct Face {Vector3 a,b,c,center;AABB box;};
 struct Branch {AABB box;int begin=0,end=0,left=-1,right=-1;};
 std::vector<Face> faces;
 std::vector<Branch> branches;
 int partition(int begin,int end);
protected: static void _bind_methods();
public:
 bool set_faces(const Array &input);
 bool segment_obstructed(Vector3 start,Vector3 end) const;
 Dictionary surface_bounds(const PackedVector3Array &vertices,const PackedInt32Array &bones,const PackedFloat32Array &weights,const Array &palette,Transform3D mesh,Transform3D skeleton);
 PackedByteArray encode_pose(const Dictionary &data,const Array &locations);
 Dictionary decode_pose(const PackedByteArray &bytes,const Array &locations);
};
}
