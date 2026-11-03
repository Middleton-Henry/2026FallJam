extends Node
#couldn't get this to work properly
@export var camera: Camera3D
@export var rect: CanvasItem

func _process(_delta: float) -> void:
	var mat := rect.material as ShaderMaterial

	var q := camera.global_transform.basis.get_rotation_quaternion()

	mat.set_shader_parameter(
		"camera_rotation",
		Vector4(q.x, q.y, q.z, q.w)
	)

	mat.set_shader_parameter(
		"camera_position",
		camera.global_position
	)

	mat.set_shader_parameter(
		"camera_fov",
		deg_to_rad(camera.fov)
	)

	var viewport_size := camera.get_viewport().get_visible_rect().size

	mat.set_shader_parameter(
		"camera_aspect",
		viewport_size.x / viewport_size.y
	)
