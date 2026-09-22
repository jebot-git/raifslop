shader_type sky;
#include "res://addons/golfminus/shaders/panorama_sampling.gdshaderinc"
void sky() {
	COLOR = panorama_sample(EYEDIR, !AT_CUBEMAP_PASS);
}
