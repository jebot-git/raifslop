extends RefCounted
## Fixed eye-buffer size; never vary resolution to hide missed frames.
static func configure(interface:OpenXRInterface, viewport:Viewport) -> void:
 interface.render_target_size_multiplier=1.0
 interface.foveation_dynamic=false
 viewport.scaling_3d_scale=1.0
 if interface.is_foveation_supported():interface.foveation_level=2
 if 72.0 in interface.get_available_display_refresh_rates():interface.display_refresh_rate=72.0
 interface.set_cpu_level(OpenXRInterface.PERF_SETTINGS_LEVEL_SUSTAINED_HIGH)
 interface.set_gpu_level(OpenXRInterface.PERF_SETTINGS_LEVEL_SUSTAINED_HIGH)
