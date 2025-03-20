extends Node2D

@export var target_mesh: MeshInstance3D  # Assign the 3D object to draw a wireframe for

var camera: Camera3D

# Parameters for the output image.
var image_width := 1280
var image_height := 720
var image: Image

func _ready():
	var viewport = get_viewport()
	camera = viewport.get_camera_3d()
	
	# Create a new image and fill with a background color (black in this case).
	image = Image.create(image_width, image_height, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 1))
	
	# Draw into the image.
	_draw_to_image()
	
	# Save the rendered image to disk.
	image.save_png("res://wireframe_output.png")
	print("Saved wireframe_output.png")

func _draw_to_image():
	if not target_mesh or not camera:
		return

	var mesh = target_mesh.mesh
	if not mesh:
		return

	for i in range(mesh.get_surface_count()):
		var arrays = mesh.surface_get_arrays(i)
		if arrays.size() == 0:
			continue

		var vertices = arrays[Mesh.ARRAY_VERTEX]
		var indices = arrays[Mesh.ARRAY_INDEX]

		# Extract only front-facing edges
		var front_facing_edges = _extract_front_facing_edges(vertices, indices)

		for key in front_facing_edges.keys():
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
			
			# Compute expected depth (in camera space) for each end.
			var depth1 = get_camera_depth(world_v1)
			var depth2 = get_camera_depth(world_v2)
			
			_draw_bresenham_line(screen_v1, screen_v2, Color(1, 1, 1), depth1, depth2)
			
func _extract_front_facing_edges(vertices: PackedVector3Array, indices: PackedInt32Array) -> Dictionary:
	var edge_set = {}
	for i in range(0, indices.size(), 3):
		if i + 2 >= indices.size():
			continue  

		var v1 = indices[i]  
		var v2 = indices[i+1]  
		var v3 = indices[i+2]  

		# Convert vertices to world space.
		var world_v1 = target_mesh.to_global(vertices[v1])
		var world_v2 = target_mesh.to_global(vertices[v2])
		var world_v3 = target_mesh.to_global(vertices[v3])

		# Compute face normal.
		var edge1 = world_v2 - world_v1
		var edge2 = world_v3 - world_v1
		var normal = edge1.cross(edge2).normalized()

		# Get direction from face to the camera.
		var to_camera = (camera.global_position - world_v1).normalized()

		# Determine if the face is front-facing.
		# (Using dot < 0 for front-facing; adjust if needed.)
		var is_front_facing = normal.dot(to_camera) < 0  
		
		if is_front_facing:
			_add_edge(edge_set, v1, v2)
			_add_edge(edge_set, v2, v3)
			_add_edge(edge_set, v3, v1)
	return edge_set

func _add_edge(edge_set: Dictionary, v1: int, v2: int):
	var edge = [min(v1, v2), max(v1, v2)]
	var key = str(edge[0]) + "-" + str(edge[1])
	if key not in edge_set:
		edge_set[key] = edge

# Instead of drawing to the screen, we write pixels to our image.
func _draw_bresenham_line(start: Vector2, end: Vector2, base_color: Color, expected_depth_start: float, expected_depth_end: float):
	var x0 = int(start.x)
	var y0 = int(start.y)
	var x1 = int(end.x)
	var y1 = int(end.y)
	
	var dx = abs(x1 - x0)
	var dy = abs(y1 - y0)
	var sx = 1 if x0 < x1 else -1
	var sy = 1 if y0 < y1 else -1
	var err = dx - dy
	
	var line_length = start.distance_to(end)
	
	while true:
		var current_point = Vector2(x0, y0)
		# Estimate t along the line.
		var t = start.distance_to(current_point) / line_length
		var expected_depth = lerp(expected_depth_start, expected_depth_end, t)
		
		var pixel_color = base_color
		if is_pixel_occluded(current_point, expected_depth):
			pixel_color = Color(1, 0, 0)  # Red if occluded
			
		# Only set the pixel if within the image bounds.
		if x0 >= 0 and x0 < image_width and y0 >= 0 and y0 < image_height:
			image.set_pixel(x0, y0, pixel_color)
			
		if x0 == x1 and y0 == y1:
			break
		var e2 = 2 * err
		if e2 > -dy:
			err -= dy
			x0 += sx
		if e2 < dx:
			err += dx
			y0 += sy

# This function casts a ray from the camera through the given screen pixel,
# compares the hit distance with the expected distance for that pixel along the edge,
# and returns true if another part of the mesh is closer.
func is_pixel_occluded(screen_pos: Vector2, expected_depth: float) -> bool:
	var max_distance = 4000.0  # Set an appropriate maximum ray distance.
	# Get the ray from the camera for this pixel.
	var ray_origin = camera.project_ray_origin(screen_pos)
	var ray_direction = camera.project_ray_normal(screen_pos)
	
	# Perform our manual ray-mesh intersection.
	var result = mesh_intersect_ray(ray_origin, ray_direction, max_distance)
	if result.has("position"):
		# Convert the hit position to camera space depth.
		var hit_depth = get_camera_depth(result["position"])
		# Use a threshold—here a relative threshold, adjust as needed.
		var threshold = expected_depth * 0.001
		if (expected_depth - hit_depth) > threshold:
			return true
	return false

# Helper function: Convert a world point into camera space and return its depth.
func get_camera_depth(world_point: Vector3) -> float:
	var cam_inv = camera.global_transform.inverse()
	var local_point = cam_inv * world_point
	# For an orthogonal camera (assuming it faces -Z), use the absolute z value.
	return abs(local_point.z)

# Iterates over the mesh data (all surfaces) and finds the closest ray-triangle intersection.
func mesh_intersect_ray(ray_origin: Vector3, ray_direction: Vector3, max_distance: float) -> Dictionary:
	var closest_t = max_distance
	var hit = false
	var hit_position = Vector3.ZERO
	
	var mesh = target_mesh.mesh
	if not mesh:
		return {}
		
	for surface in range(mesh.get_surface_count()):
		var arrays = mesh.surface_get_arrays(surface)
		if arrays.size() == 0:
			continue

		var vertices = arrays[Mesh.ARRAY_VERTEX]
		var indices = arrays[Mesh.ARRAY_INDEX]
		# Iterate over every triangle in this surface.
		for i in range(0, indices.size(), 3):
			var index0 = indices[i]
			var index1 = indices[i+1]
			var index2 = indices[i+2]
			# Transform vertices to world space.
			var v0 = target_mesh.to_global(vertices[index0])
			var v1 = target_mesh.to_global(vertices[index1])
			var v2 = target_mesh.to_global(vertices[index2])
			
			var t = ray_triangle_intersect(ray_origin, ray_direction, v0, v1, v2)
			if t < closest_t:
				closest_t = t
				hit = true
				hit_position = ray_origin + ray_direction * t
	if hit:
		return { "position": hit_position, "distance": closest_t }
	else:
		return {}
		
# Helper: Möller–Trumbore ray-triangle intersection.
# Returns the distance along the ray (t) if there's an intersection, or INF if none.
func ray_triangle_intersect(ray_origin: Vector3, ray_direction: Vector3, v0: Vector3, v1: Vector3, v2: Vector3) -> float:
	var epsilon = 0.00001
	var edge1 = v1 - v0
	var edge2 = v2 - v0
	var h = ray_direction.cross(edge2)
	var a = edge1.dot(h)
	if abs(a) < epsilon:
		return INF  # Ray is parallel to the triangle.
	var f = 1.0 / a
	var s = ray_origin - v0
	var u = f * s.dot(h)
	if u < 0.0 or u > 1.0:
		return INF
	var q = s.cross(edge1)
	var v = f * ray_direction.dot(q)
	if v < 0.0 or u + v > 1.0:
		return INF
	var t = f * edge2.dot(q)
	if t > epsilon:
		return t
	return INF
