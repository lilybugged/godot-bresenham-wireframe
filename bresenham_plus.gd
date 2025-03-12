extends Node2D  # This draws the wireframe over the 3D view using Bresenham's algorithm

@export var target_mesh: MeshInstance3D  # Assign the 3D object to draw a wireframe for

var camera: Camera3D

func _ready():
	var viewport = get_viewport()
	camera = viewport.get_camera_3d()

func _process(_delta):
	if not target_mesh or not camera:
		return
	queue_redraw()

func _draw():
	if not target_mesh or not camera:
		return

	var mesh = target_mesh.mesh
	if not mesh:
		return

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

			var world_v1 = target_mesh.to_global(vertices[v1_index])
			var world_v2 = target_mesh.to_global(vertices[v2_index])

			var screen_v1 = camera.unproject_position(world_v1)
			var screen_v2 = camera.unproject_position(world_v2)

			_draw_bresenham_line(screen_v1, screen_v2, Color(1, 1, 1))

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
		edge_set.erase(key)  # Remove duplicates
	else:
		edge_set[key] = edge

func _draw_bresenham_line(start: Vector2, end: Vector2, color: Color):
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
		draw_rect(Rect2(Vector2(x0, y0), Vector2(1, 1)), color)  # Draw pixel
		if x0 == x1 and y0 == y1:
			break
		var e2 = 2 * err
		if e2 > -dy:
			err -= dy
			x0 += sx
		if e2 < dx:
			err += dx
			y0 += sy
