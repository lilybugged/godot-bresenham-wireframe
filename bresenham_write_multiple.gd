extends Node2D

@export var target_meshes: Array[MeshInstance3D]  # Array of meshes to process
@export var output_path: String = "res://wireframe_output.png"  # Where to save the output image

var camera: Camera3D

func _ready() -> void:
	var viewport = get_viewport()
	camera = viewport.get_camera_3d()
	if target_meshes.is_empty() or not camera:
		print("No target meshes or camera not assigned.")
		return
	# Wait one frame to ensure the window is fully initialized.
	await get_tree().process_frame
	generate_wireframe_image()


func generate_wireframe_image() -> void:
	# Get window dimensions.
	var window_size = DisplayServer.window_get_size(0)
	var width = int(window_size.x)
	var height = int(window_size.y)
	print("Creating image with size: ", width, " x ", height)
	
	# Create an image (using static Image.create).
	var image = Image.create(width, height, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 1))
	print("Image size after create: ", image.get_width(), " x ", image.get_height())
	
	# ============================================================
	# Part 1: Draw occlusion-based wireframe lines (red/white)
	# ============================================================
	for mesh_instance in target_meshes:
		if not mesh_instance:
			continue
		var mesh = mesh_instance.mesh
		if not mesh:
			continue
		# Process each surface of the mesh.
		for surface in range(mesh.get_surface_count()):
			var arrays = mesh.surface_get_arrays(surface)
			if arrays.is_empty():
				continue
			var vertices = arrays[Mesh.ARRAY_VERTEX]
			var indices = arrays[Mesh.ARRAY_INDEX]
			
			# Dictionary to store unique edges (by vertex indices).
			var edges = {}
			for i in range(0, indices.size(), 3):
				if i + 2 >= indices.size():
					continue
				var v1 = indices[i]
				var v2 = indices[i + 1]
				var v3 = indices[i + 2]
				_add_edge(edges, v1, v2)
				_add_edge(edges, v2, v3)
				_add_edge(edges, v3, v1)
			
			# For each unique edge, project endpoints to screen space and draw with raycast test.
			for key in edges.keys():
				var edge_indices = edges[key]
				var world_v1 = mesh_instance.to_global(vertices[edge_indices[0]])
				var world_v2 = mesh_instance.to_global(vertices[edge_indices[1]])
				var screen_v1 = camera.unproject_position(world_v1)
				var screen_v2 = camera.unproject_position(world_v2)
				_draw_line_with_raycast(screen_v1, screen_v2, world_v1, world_v2, image)
	
	# ============================================================
	# Part 2: Compute and draw silhouette edges (in blue)
	# ============================================================
	# For each mesh instance, we build a dictionary mapping an edge (by its key)
	# to an array of boolean flags indicating the face’s front-facing status.
	for mesh_instance in target_meshes:
		if not mesh_instance:
			continue
		var mesh = mesh_instance.mesh
		if not mesh:
			continue
		for surface in range(mesh.get_surface_count()):
			var arrays = mesh.surface_get_arrays(surface)
			if arrays.is_empty():
				continue
			var vertices = arrays[Mesh.ARRAY_VERTEX]
			var indices = arrays[Mesh.ARRAY_INDEX]
			var silhouette_edges = {}  # key -> Array of bools (front flags)
			
			# Iterate over each triangle.
			for i in range(0, indices.size(), 3):
				if i + 2 >= indices.size():
					continue
				var idx1 = indices[i]
				var idx2 = indices[i + 1]
				var idx3 = indices[i + 2]
				var world_v1 = mesh_instance.to_global(vertices[idx1])
				var world_v2 = mesh_instance.to_global(vertices[idx2])
				var world_v3 = mesh_instance.to_global(vertices[idx3])
				
				# Compute the face normal.
				var edge1 = world_v2 - world_v1
				var edge2 = world_v3 - world_v1
				var normal = edge1.cross(edge2).normalized()
				# Compute vector from one vertex to the camera.
				var to_camera = (camera.global_position - world_v1).normalized()
				# Use the same condition as before: front if normal.dot(to_camera) < 0.
				var front = normal.dot(to_camera) < 0
				
				_add_edge_silhouette(silhouette_edges, idx1, idx2, front)
				_add_edge_silhouette(silhouette_edges, idx2, idx3, front)
				_add_edge_silhouette(silhouette_edges, idx3, idx1, front)
			
			# Now, iterate over silhouette_edges:
			# If an edge is only in one triangle, or if it is in two with different front/back values, draw it.
			for key in silhouette_edges.keys():
				var flags = silhouette_edges[key]
				if flags.size() == 1 or (flags.size() == 2 and flags[0] != flags[1]):
					var parts = key.split("-")
					var v1_index = int(parts[0])
					var v2_index = int(parts[1])
					var world_v1 = mesh_instance.to_global(vertices[v1_index])
					var world_v2 = mesh_instance.to_global(vertices[v2_index])
					var screen_v1 = camera.unproject_position(world_v1)
					var screen_v2 = camera.unproject_position(world_v2)
					#debug option
					#_draw_line_silhouette(screen_v1, screen_v2, image)
	
	# ============================================================
	# Save the final image.
	var save_err = image.save_png(output_path)
	if save_err == OK:
		print("Image saved successfully at ", output_path)
	else:
		print("Failed to save image. Error code: ", save_err)


# Helper to add an edge (order-independent) to a dictionary.
func _add_edge(edge_dict: Dictionary, v1: int, v2: int) -> void:
	var key = str(min(v1, v2)) + "-" + str(max(v1, v2))
	if not edge_dict.has(key):
		edge_dict[key] = [v1, v2]


# Helper to add silhouette info to an edge dictionary.
# Each key maps to an array of booleans (front-facing flags).
func _add_edge_silhouette(sil_dict: Dictionary, v1: int, v2: int, front: bool) -> void:
	var key = str(min(v1, v2)) + "-" + str(max(v1, v2))
	if sil_dict.has(key):
		sil_dict[key].append(front)
	else:
		sil_dict[key] = [front]


# Draws a line using Bresenham’s algorithm with raycasting-based occlusion testing.
# For each pixel along the edge, if the camera’s ray hits near the interpolated 3D edge point,
# white is drawn; otherwise, red is drawn.
# Red is only written if the pixel is not already white.
func _draw_line_with_raycast(screen_start: Vector2, screen_end: Vector2, world_start: Vector3, world_end: Vector3, image: Image) -> void:
	var x0 = int(screen_start.x)
	var y0 = int(screen_start.y)
	var x1 = int(screen_end.x)
	var y1 = int(screen_end.y)
	var dx = abs(x1 - x0)
	var dy = abs(y1 - y0)
	var sx = 1 if x0 < x1 else -1
	var sy = 1 if y0 < y1 else -1
	var err = dx - dy
	var total_pixels = max(dx, dy)
	var pixel_index = 0
	
	while true:
		var t = float(pixel_index) / float(total_pixels) if total_pixels > 0 else 0.0
		var edge_point = world_start.lerp(world_end, t)
		var screen_point = Vector2(x0, y0)
		var ray_origin = camera.project_ray_origin(screen_point)
		var ray_direction = camera.project_ray_normal(screen_point)
		var ray_end = ray_origin + ray_direction * 10000.0
		
		var query = PhysicsRayQueryParameters3D.new()
		query.from = ray_origin
		query.to = ray_end
		
		var space_state = get_viewport().get_world_3d().direct_space_state
		var result = space_state.intersect_ray(query)
		var hit = false
		if result:
			var hit_point = result.position
			if hit_point.distance_to(edge_point) < 0.1:
				hit = true
		
		# White if visible; red otherwise.
		var color = Color(1, 1, 1)
		if !hit: color = Color(0, 0, 0)
		#debug option
		#if !hit: color = Color(1, 0, 0)
		if screen_point.x >= 0 and screen_point.y >= 0 and screen_point.x < image.get_width() and screen_point.y < image.get_height():
			var current_color = image.get_pixel(screen_point.x, screen_point.y)
			if color == Color(1, 1, 1) or current_color != Color(1, 1, 1):
				image.set_pixel(screen_point.x, screen_point.y, color)
		
		if x0 == x1 and y0 == y1:
			break
		var e2 = 2 * err
		if e2 > -dy:
			err -= dy
			x0 += sx
		if e2 < dx:
			err += dx
			y0 += sy
		pixel_index += 1


# Draws a line using Bresenham’s algorithm in a fixed silhouette color (blue).
# This function simply draws over the image without any occlusion testing.
func _draw_line_silhouette(screen_start: Vector2, screen_end: Vector2, image: Image) -> void:
	var x0 = int(screen_start.x)
	var y0 = int(screen_start.y)
	var x1 = int(screen_end.x)
	var y1 = int(screen_end.y)
	var dx = abs(x1 - x0)
	var dy = abs(y1 - y0)
	var sx = 1 if x0 < x1 else -1
	var sy = 1 if y0 < y1 else -1
	var err = dx - dy
	# Use blue for silhouette edges.
	var color = Color(0, 0, 1)
	
	while true:
		# Directly write the silhouette color (overriding any previous color).
		if x0 >= 0 and y0 >= 0 and x0 < image.get_width() and y0 < image.get_height():
			image.set_pixel(x0, y0, color)
		
		if x0 == x1 and y0 == y1:
			break
		var e2 = 2 * err
		if e2 > -dy:
			err -= dy
			x0 += sx
		if e2 < dx:
			err += dx
			y0 += sy
