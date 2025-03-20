extends Node2D

@export var target_mesh: MeshInstance3D  # The 3D mesh to process
@export var output_path: String = "res://wireframe_output.png"  # Where to save the output image

var camera: Camera3D

func _ready() -> void:
	var viewport = get_viewport()
	camera = viewport.get_camera_3d()
	if not target_mesh or not camera:
		print("Target mesh or camera not assigned.")
		return
	# Wait one frame to ensure the window is fully initialized.
	await get_tree().process_frame
	generate_wireframe_image()


func generate_wireframe_image() -> void:
	# Use DisplayServer.window_get_size(0) to obtain nonzero dimensions.
	var window_size = DisplayServer.window_get_size(0)
	var width = int(window_size.x)
	var height = int(window_size.y)
	
	print("Creating image with size: ", width, " x ", height)
	
	# Call the static create() method on Image.
	var image = Image.create(width, height, false, Image.FORMAT_RGBA8)
	# Fill the image with a black background.
	image.fill(Color(0, 0, 0, 1))
	print("Image size after create: ", image.get_width(), " x ", image.get_height())
	
	# Get the mesh from the target mesh instance.
	var mesh = target_mesh.mesh
	if not mesh:
		print("No mesh found in target_mesh.")
		return
	
	# For each surface, extract all unique edges (from every triangle)
	for surface in range(mesh.get_surface_count()):
		var arrays = mesh.surface_get_arrays(surface)
		if arrays.is_empty():
			continue
		var vertices = arrays[Mesh.ARRAY_VERTEX]
		var indices = arrays[Mesh.ARRAY_INDEX]
		
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
		
		# For each edge, project its endpoints to screen space and draw the line with raycast verification.
		for key in edges.keys():
			var edge_indices = edges[key]
			var world_v1 = target_mesh.to_global(vertices[edge_indices[0]])
			var world_v2 = target_mesh.to_global(vertices[edge_indices[1]])
			
			var screen_v1 = camera.unproject_position(world_v1)
			var screen_v2 = camera.unproject_position(world_v2)
			
			_draw_line_with_raycast(screen_v1, screen_v2, world_v1, world_v2, image)
	
	# Save the final image.
	var save_err = image.save_png(output_path)
	if save_err == OK:
		print("Image saved successfully at ", output_path)
	else:
		print("Failed to save image. Error code: ", save_err)


# Helper function to add a unique edge (order-independent) to the dictionary.
func _add_edge(edge_dict: Dictionary, v1: int, v2: int) -> void:
	var key = str(min(v1, v2)) + "-" + str(max(v1, v2))
	if not edge_dict.has(key):
		edge_dict[key] = [v1, v2]


# Draws a line using Bresenham’s algorithm.
# For each pixel along the line, a ray is cast and compared to the interpolated 3D edge point.
# White indicates that the ray hit the edge (visible), while red indicates occlusion.
# This function only writes a red pixel if the current pixel is not already white.
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
	
	# For mapping pixel count along the line to a parameter t for interpolation.
	var total_pixels = max(dx, dy)
	var pixel_index = 0
	
	while true:
		# Calculate t (0.0 to 1.0) for the current pixel.
		var t = float(pixel_index) / float(total_pixels) if total_pixels > 0 else 0.0
		# Interpolate the world space point along the edge.
		var edge_point = world_start.lerp(world_end, t)
		
		# Determine the 3D ray for the current screen pixel.
		var screen_point = Vector2(x0, y0)
		var ray_origin = camera.project_ray_origin(screen_point)
		var ray_direction = camera.project_ray_normal(screen_point)
		var ray_end = ray_origin + ray_direction * 10000.0  # Cast far enough.
		
		# Set up the ray query parameters.
		var query = PhysicsRayQueryParameters3D.new()
		query.from = ray_origin
		query.to = ray_end
		
		# Perform the raycast using the physics space state.
		var space_state = get_viewport().get_world_3d().direct_space_state
		var result = space_state.intersect_ray(query)
		
		var hit = false
		if result:
			var hit_point = result.position
			# If the hit is near the interpolated edge point, consider it visible.
			if hit_point.distance_to(edge_point) < 0.1:
				hit = true
		
		# White if visible, red if occluded.
		var color = Color(1, 1, 1) if hit else Color(0, 0, 0)
		
		# Only set the pixel if white, or if not already white.
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
