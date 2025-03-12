extends Node2D

@export var target_meshes: Array[MeshInstance3D]  # List of all meshes in the scene
var camera: Camera3D
var depth_buffer = {}  # Stores closest depth per pixel
var z_buffer = {}  # Per-pixel Z-depth storage

func _ready():
	var viewport = get_viewport()
	camera = viewport.get_camera_3d()

func _process(_delta):
	if not target_meshes or not camera:
		return
	queue_redraw()

func _draw():
	if not target_meshes or not camera:
		return

	# Reset depth buffers and fill z-buffer with "infinity" values
	depth_buffer.clear()
	z_buffer.clear()
	
	# Use viewport size to create a depth map
	var viewport_size = get_viewport_rect().size
	for x in range(viewport_size.x):
		for y in range(viewport_size.y):
			z_buffer[Vector2(x, y)] = INF  # Initialize with a large value

	var all_edges = []

	# Gather all edges from all meshes
	for target_mesh in target_meshes:
		var mesh = target_mesh.mesh
		if not mesh:
			continue

		for i in range(mesh.get_surface_count()):
			var arrays = mesh.surface_get_arrays(i)
			if arrays.is_empty():
				continue

			var vertices = arrays[Mesh.ARRAY_VERTEX]
			var indices = arrays[Mesh.ARRAY_INDEX]

			var edge_set = _extract_front_facing_edges(target_mesh, vertices, indices)

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

				# Convert to screen space
				var screen_v1 = camera.unproject_position(world_v1)
				var screen_v2 = camera.unproject_position(world_v2)

				# Get world depth values
				var depth_v1 = (camera.global_transform.origin - world_v1).length()
				var depth_v2 = (camera.global_transform.origin - world_v2).length()

				# Store edge data for drawing
				all_edges.append([screen_v1, screen_v2, depth_v1, depth_v2])

	# Sort edges globally by depth (farther edges drawn first)
	all_edges.sort_custom(func(a, b): return min(a[2], a[3]) > min(b[2], b[3]))

	# Draw all edges with proper occlusion
	for edge in all_edges:
		_draw_bresenham_line_with_depth(edge[0], edge[1], edge[2], edge[3], Color(1, 1, 1))

func _extract_front_facing_edges(target_mesh: MeshInstance3D, vertices: PackedVector3Array, indices: PackedInt32Array) -> Dictionary:
	var edge_set = {}

	for i in range(0, indices.size(), 3):
		if i + 2 >= indices.size():
			continue

		var v1 = indices[i]
		var v2 = indices[i+1]
		var v3 = indices[i+2]

		# Convert vertices to world space
		var world_v1 = target_mesh.to_global(vertices[v1])
		var world_v2 = target_mesh.to_global(vertices[v2])
		var world_v3 = target_mesh.to_global(vertices[v3])

		# Compute face normal
		var edge1 = world_v2 - world_v1
		var edge2 = world_v3 - world_v1
		var normal = edge1.cross(edge2).normalized()

		# Get direction from face to the camera
		var to_camera = (camera.global_position - world_v1).normalized()

		# Determine if the face is front-facing
		var is_front_facing = normal.dot(to_camera) < 0

		# Only add edges from front-facing triangles
		if is_front_facing:
			edge_set["%d-%d" % [min(v1, v2), max(v1, v2)]] = [v1, v2]
			edge_set["%d-%d" % [min(v2, v3), max(v2, v3)]] = [v2, v3]
			edge_set["%d-%d" % [min(v3, v1), max(v3, v1)]] = [v3, v1]

	return edge_set
