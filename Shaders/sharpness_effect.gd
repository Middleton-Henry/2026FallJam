@tool
class_name SharpnessCompositorEffect
extends CompositorEffect

# Sharpness intensity: 0.0 is no change, 1.0+ is noticeably sharper
@export_range(0.0, 5.0, 0.05) var sharpness_amount: float = 1.0

var rd: RenderingDevice
var shader: RID
var pipeline: RID

func _init() -> void:
	effect_callback_type = EFFECT_CALLBACK_TYPE_POST_TRANSPARENT
	RenderingServer.call_on_render_thread(_initialize_compute)

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		if shader.is_valid():
			rd.free_rid(shader)

func _initialize_compute() -> void:
	rd = RenderingServer.get_rendering_device()
	if not rd:
		return

	var shader_source := """#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(rgba16f, set = 0, binding = 0) uniform image2D screen_image;

layout(push_constant, std430) uniform Params {
	vec2 raster_size;
	float sharpness;
	float pad;
} pc;

void main() {
	ivec2 uv = ivec2(gl_GlobalInvocationID.xy);
	ivec2 size = ivec2(pc.raster_size);

	if (uv.x >= size.x || uv.y >= size.y) {
		return;
	}

	ivec2 maxc = size - ivec2(1);

	vec4 center = imageLoad(screen_image, uv);
	vec4 left   = imageLoad(screen_image, clamp(uv + ivec2(-1,  0), ivec2(0), maxc));
	vec4 right  = imageLoad(screen_image, clamp(uv + ivec2( 1,  0), ivec2(0), maxc));
	vec4 up     = imageLoad(screen_image, clamp(uv + ivec2( 0, -1), ivec2(0), maxc));
	vec4 down   = imageLoad(screen_image, clamp(uv + ivec2( 0,  1), ivec2(0), maxc));

	vec4 sharp_color = center + pc.sharpness * (4.0 * center - left - right - up - down);
	sharp_color.rgb = max(sharp_color.rgb, vec3(0.0));
	sharp_color.a = center.a;

	imageStore(screen_image, uv, sharp_color);
}
"""

	var shader_src := RDShaderSource.new()
	shader_src.language = RenderingDevice.SHADER_LANGUAGE_GLSL
	shader_src.source_compute = shader_source

	var shader_spirv: RDShaderSPIRV = rd.shader_compile_spirv_from_source(shader_src)
	if shader_spirv.compile_error_compute != "":
		push_error("Sharpness shader compilation error: " + shader_spirv.compile_error_compute)
		return

	shader = rd.shader_create_from_spirv(shader_spirv)
	if shader.is_valid():
		pipeline = rd.compute_pipeline_create(shader)

func _render_callback(p_effect_callback_type: int, p_render_data: RenderData) -> void:
	if not rd or not pipeline.is_valid():
		return
	if p_effect_callback_type != effect_callback_type:
		return

	var render_scene_buffers := p_render_data.get_render_scene_buffers() as RenderSceneBuffersRD
	if not render_scene_buffers:
		return

	var size: Vector2i = render_scene_buffers.get_internal_size()
	if size.x == 0 or size.y == 0:
		return

	var x_groups := ceili(size.x / 8.0)
	var y_groups := ceili(size.y / 8.0)

	var push_constants := PackedFloat32Array([size.x, size.y, sharpness_amount, 0.0])
	var push_bytes := push_constants.to_byte_array()

	var view_count: int = render_scene_buffers.get_view_count()
	for view in view_count:
		var screen_texture: RID = render_scene_buffers.get_color_layer(view)

		var uniform := RDUniform.new()
		uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
		uniform.binding = 0
		uniform.add_id(screen_texture)
		var uniform_set := UniformSetCacheRD.get_cache(shader, 0, [uniform])

		var compute_list := rd.compute_list_begin()
		rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
		rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
		rd.compute_list_set_push_constant(compute_list, push_bytes, push_bytes.size())
		rd.compute_list_dispatch(compute_list, x_groups, y_groups, 1)
		rd.compute_list_end()
