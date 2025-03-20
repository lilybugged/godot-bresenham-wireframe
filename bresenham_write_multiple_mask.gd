extends Node3D

@export var mesh_path: String = "res://Cube_002.res"  # Path to your mesh resource
@export var output_image: String = "res://wireframe.png"
@export var image_size: Vector2i = Vector2i(1280, 720)
@export var depth_threshold: float = 0.9  # Pixels with depth above this are drawn as wireframe

var camera: Camera3D
var saved_cam_pos: Vector3
var depth_buffer: Image
var color_buffer: Image
var edges = []
var mesh_resource: Mesh  # Store our loaded mesh for later use

func _ready():
	call_deferred("initialize")

func initialize():
	# Create and configure an orthographic camera.
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 0.02  # Adjust as needed to "zoom in" on your model.
	add_child(camera)
	
	# Wait one frame so the camera is fully inside the scene tree.
	await get_tree().process_frame
	camera.global_position = Vector3(0, 0, 10)
	saved_cam_pos = camera.global_position
	
	# Load the mesh resource.
	mesh_resource = load(mesh_path)
	if not mesh_resource:
		print("Failed to load mesh!")
		return
	
	# Extract edges from the mesh.
	edges = extract_edges(mesh_resource)
	
	# Create a depth buffer (single-channel float image) and a color buffer.
	depth_buffer = Image.create(image_size.x, image_size.y, false, Image.FORMAT_RF)
	color_buffer = Image.create(image_size.x, image_size.y, false, Image.FORMAT_RGBA8)
	color_buffer.fill(Color(0, 0, 0, 1))
	
	# Render the depth buffer from the mesh by rasterizing its triangles.
	render_depth_buffer(mesh_resource)
	
	# Draw wireframe edges using Bresenham's algorithm.
	draw_wireframe()
	
	# Composite: Render the mesh normally behind the wireframe.
	var mesh_image = await render_normal_mesh()
	
	var composite_image = Image.create(image_size.x, image_size.y, false, Image.FORMAT_RGBA8)
	for x in range(image_size.x):
		for y in range(image_size.y):
			var wire_color = color_buffer.get_pixel(x, y)
			# If the wireframe pixel is black, use the normal mesh pixel.
			if wire_color.r < 0.01 and wire_color.g < 0.01 and wire_color.b < 0.01:
				composite_image.set_pixel(x, y, mesh_image.get_pixel(x, y))
			else:
				composite_image.set_pixel(x, y, wire_color)
	
	composite_image.generate_mipmaps()
	composite_image.save_png(output_image)
	print("Final composite saved to:", output_image)
	get_tree().quit()

func extract_edges(mesh: Mesh) -> Array:
	var edge_set = {}
	for i in range(mesh.get_surface_count()):
		var arr = mesh.surface_get_arrays(i)
		if arr.is_empty():
			continue
		var vertices = arr[Mesh.ARRAY_VERTEX]
		var indices = arr[Mesh.ARRAY_INDEX]
		for j in range(0, indices.size(), 3):
			var v0 = vertices[indices[j]]
			var v1 = vertices[indices[j+1]]
			var v2 = vertices[indices[j+2]]
			add_edge(edge_set, v0, v1)
			add_edge(edge_set, v1, v2)
			add_edge(edge_set, v2, v0)
	return edge_set.keys()

func add_edge(edge_set: Dictionary, v1: Vector3, v2: Vector3) -> void:
	if (v2.x < v1.x) or ((v2.x == v1.x) and (v2.y < v1.y)) or ((v2.x == v1.x) and (v2.y == v1.y) and (v2.z < v1.z)):
		var temp = v1
		v1 = v2
		v2 = temp
	var edge = [v1, v2]
	edge_set[edge] = true

func render_depth_buffer(mesh: Mesh) -> void:
	depth_buffer.fill(Color(1, 1, 1, 1))
	for i in range(mesh.get_surface_count()):
		var arr = mesh.surface_get_arrays(i)
		if arr.is_empty():
			continue
		var vertices = arr[Mesh.ARRAY_VERTEX]
		var indices = arr[Mesh.ARRAY_INDEX]
		for j in range(0, indices.size(), 3):
			var v0 = project_to_screen(vertices[indices[j]])
			var v1 = project_to_screen(vertices[indices[j+1]])
			var v2 = project_to_screen(vertices[indices[j+2]])
			rasterize_triangle_depth(v0, v1, v2)

func project_to_screen(vertex: Vector3) -> Vector2:
	var local = camera.global_transform.affine_inverse() * vertex
	var aspect = image_size.x / float(image_size.y)
	var half_height = camera.size / 2.0
	var half_width = half_height * aspect
	var x_ndc = local.x / half_width
	var y_ndc = local.y / half_height
	var screen_x = int((x_ndc * 0.5 + 0.5) * image_size.x)
	var screen_y = int((1.0 - (y_ndc * 0.5 + 0.5)) * image_size.y)
	screen_x = clamp(screen_x, 0, image_size.x - 1)
	screen_y = clamp(screen_y, 0, image_size.y - 1)
	print("Projected:", vertex, "-> Screen:", screen_x, screen_y)
	return Vector2(screen_x, screen_y)

func rasterize_triangle_depth(v0: Vector2, v1: Vector2, v2: Vector2) -> void:
	var sorted = [v0, v1, v2]
	sorted.sort_custom(Callable(self, "compare_y"))
	v0 = sorted[0]
	v1 = sorted[1]
	v2 = sorted[2]
	for y in range(v0.y, v2.y + 1):
		if y < 0 or y >= image_size.y:
			continue
		var x_start = clamp(interpolate_x(v0, v2, y), 0, image_size.x - 1)
		var x_end: int = 0
		if y < v1.y:
			x_end = interpolate_x(v0, v1, y)
		else:
			x_end = interpolate_x(v1, v2, y)
		x_end = clamp(x_end, 0, image_size.x - 1)
		for x in range(x_start, x_end + 1):
			if x < 0 or x >= image_size.x:
				continue
			depth_buffer.set_pixel(x, y, Color(0, 0, 0, 0))
			print("Setting depth buffer at:", x, y)

func compare_y(a: Vector2, b: Vector2) -> int:
	if a.y < b.y:
		return -1
	elif a.y > b.y:
		return 1
	return 0

func interpolate_x(v1: Vector2, v2: Vector2, y: int) -> int:
	if v1.y == v2.y:
		return v1.x
	return int(v1.x + (v2.x - v1.x) * (y - v1.y) / (v2.y - v1.y))

func draw_wireframe() -> void:
	for edge in edges:
		var p1 = project_to_screen(edge[0])
		var p2 = project_to_screen(edge[1])
		draw_bresenham_line(p1, p2)

func draw_bresenham_line(p1: Vector2, p2: Vector2) -> void:
	var dx = abs(p2.x - p1.x)
	var dy = -abs(p2.y - p1.y)
	var sx = 1 if p1.x < p2.x else -1
	var sy = 1 if p1.y < p2.y else -1
	var err = dx + dy
	var x = p1.x
	var y = p1.y
	while true:
		if x >= 0 and x < image_size.x and y >= 0 and y < image_size.y:
			var depth_value = depth_buffer.get_pixel(x, y).r
			if depth_value > depth_threshold:
				var scaled_depth = (depth_value - depth_threshold) / (1.0 - depth_threshold)
				var gray = Color(scaled_depth, scaled_depth, scaled_depth, 1)
				color_buffer.set_pixel(x, y, gray)
				print("Drawing pixel at:", x, y, "with depth:", depth_value)
		if x == p2.x and y == p2.y:
			break
		var e2 = 2 * err
		if e2 >= dy:
			err += dy
			x += sx
		if e2 <= dx:
			err += dx
			y += sy

func render_normal_mesh() -> Image:
	var vp = SubViewport.new()
	vp.size = image_size
	vp.render_target_update_mode = SubViewport.UpdateMode.UPDATE_ONCE
	vp.render_target_clear_mode = SubViewport.ClearMode.CLEAR_MODE_ALWAYS
	add_child(vp)
	
	var normal_cam = Camera3D.new()
	normal_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	normal_cam.size = camera.size
	vp.add_child(normal_cam)
	# Use call_deferred to set the camera's global position.
	normal_cam.call_deferred("set_global_position", saved_cam_pos)
	
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.mesh = mesh_resource
	mesh_instance.global_position = Vector3.ZERO
	vp.add_child(mesh_instance)
	
	await get_tree().process_frame  # Wait for the viewport to render.
	var mesh_img = vp.get_texture().get_image()
	mesh_img.flip_y()  # Flip if needed (viewport textures are often flipped)
	vp.queue_free()  # Clean up the temporary viewport.
	return mesh_img
