extends Node3D  # We use Node3D to manage the wireframe separately

var line_mesh: ImmediateMesh
var line_instance: MeshInstance3D
var line_material: StandardMaterial3D

func _ready():
	# Create wireframe mesh
	line_mesh = ImmediateMesh.new()
	line_material = StandardMaterial3D.new()
	line_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	line_material.albedo_color = Color(1, 1, 1)  # White lines

	# Create an instance to display the wireframe
	line_instance = MeshInstance3D.new()
	line_instance.mesh = line_mesh
	line_instance.material_override = line_material
	line_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	add_child(line_instance)

func _process(_delta):
	_draw_wireframe()

func _draw_wireframe():
	if not get_parent() or not get_parent() is MeshInstance3D:
		return

	var mesh = get_parent().mesh
	var camera = get_viewport().get_camera_3d()
	if not mesh or not camera:
		return

	line_mesh.clear_surfaces()
	line_mesh.surface_begin(Mesh.PRIMITIVE_LINES, line_material)

	for i in range(mesh.get_surface_count()):
		var arrays = mesh.surface_get_arrays(i)
		if arrays.is_empty():
			continue

		var vertices = arrays[Mesh.ARRAY_VERTEX]
		var indices = arrays[Mesh.ARRAY_INDEX]

		var edge_set = _extract_edges(vertices, indices)

		for key in edge_set.keys():
			var split_key = key.split("-")
			if split_key.size() < 2:
				continue

			var v1_index = int(split_key[0])
			var v2_index = int(split_key[1])

			if v1_index >= vertices.size() or v2_index >= vertices.size():
				continue

			var v1 = get_parent().to_global(vertices[v1_index])
			var v2 = get_parent().to_global(vertices[v2_index])

			if !_is_edge_visible(v1, v2):
				continue

			_draw_bresenham_3d(v1, v2, camera)

	line_mesh.surface_end()

func _draw_bresenham_3d(start: Vector3, end: Vector3, camera: Camera3D):
	var screen_start = camera.unproject_position(start)
	var screen_end = camera.unproject_position(end)

	var screen_points = _bresenham_2d(screen_start, screen_end)

	for i in range(screen_points.size() - 1):
		var v1 = camera.project_ray_origin(screen_points[i]).normalized() * start.length()
		var v2 = camera.project_ray_origin(screen_points[i + 1]).normalized() * end.length()

		line_mesh.surface_set_color(Color(1, 1, 1, 1))
		line_mesh.surface_add_vertex(v1)
		line_mesh.surface_add_vertex(v2)

func _bresenham_2d(start: Vector2, end: Vector2) -> Array:
	var points = []
	var x0 = int(start.x)
	var y0 = int(start.y)
	var x1 = int(end.x)
	var y1 = int(end.y)

	var dx = abs(x1 - x0)
	var dy = abs(y1 - y0)
	var sx = 1 if x0 < x1 else -1
	var sy = 1 if y0 < y1 else -1
	var err = dx - dy

	while true:
		points.append(Vector2(x0, y0))
		if x0 == x1 and y0 == y1:
			break
		var e2 = err * 2
		if e2 > -dy:
			err -= dy
			x0 += sx
		if e2 < dx:
			err += dx
			y0 += sy

	return points

func _extract_edges(vertices: PackedVector3Array, indices: PackedInt32Array) -> Dictionary:
	var edge_set = {}

	if indices.is_empty():
		for i in range(0, vertices.size(), 3):
			_add_edge(edge_set, i, i+1)
			_add_edge(edge_set, i+1, i+2)
			_add_edge(edge_set, i+2, i)
	else:
		for i in range(0, indices.size(), 3):
			if i + 2 >= indices.size():
				continue  

			var v1 = indices[i]  
			var v2 = indices[i+1]  
			var v3 = indices[i+2]  

			_add_edge(edge_set, v1, v2)
			_add_edge(edge_set, v2, v3)
			_add_edge(edge_set, v3, v1)

	return edge_set

func _add_edge(edge_set: Dictionary, v1: int, v2: int):
	var edge = [min(v1, v2), max(v1, v2)]
	var key = str(edge[0]) + "-" + str(edge[1])

	if key in edge_set:
		edge_set.erase(key)  
	else:
		edge_set[key] = edge

func _is_edge_visible(v1: Vector3, v2: Vector3) -> bool:
	var cam = get_viewport().get_camera_3d()
	if not cam:
		return true

	var view_dir = cam.global_transform.origin - (v1 + v2) * 0.5
	return view_dir.dot((v2 - v1).cross(Vector3.UP).normalized()) > 0.0
