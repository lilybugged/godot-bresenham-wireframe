extends Node3D

@export var target_mesh: MeshInstance3D
@export var wire_color: Color = Color(1.0, 1.0, 1.0)  # Default: White

var wireframe_instance: MeshInstance3D

func _ready():
	if not target_mesh or not target_mesh.mesh:
		push_error("No mesh assigned to WireframeRenderer!")
		return

	wireframe_instance = MeshInstance3D.new()
	add_child(wireframe_instance)

	# Generate wireframe mesh
	wireframe_instance.mesh = generate_wireframe_mesh(target_mesh.mesh)

	# Apply material
	var mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = wire_color
	wireframe_instance.material_override = mat

func generate_wireframe_mesh(mesh: ArrayMesh) -> Mesh:
	var surface_tool = SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_LINES)

	var arrays: Array = mesh.surface_get_arrays(0)
	
	# Convert PackedVector3Array to a normal Array[Vector3]
	var vertices: Array = Array(arrays[0]) if arrays[0] is PackedVector3Array else []
	
	# Convert PackedInt32Array to a normal Array[int]
	var indices: Array = Array(arrays[1]) if arrays.size() > 1 and arrays[1] is PackedInt32Array and arrays[1].size() > 0 else []

	var edges = {}

	if indices:
		# Indexed Mesh: Extract edges using indices
		for i in range(0, indices.size(), 3):
			add_edge(vertices, indices[i], indices[i + 1], edges, surface_tool)
			add_edge(vertices, indices[i + 1], indices[i + 2], edges, surface_tool)
			add_edge(vertices, indices[i + 2], indices[i], edges, surface_tool)
	else:
		# Non-Indexed Mesh: Extract edges directly from vertex order
		for i in range(0, vertices.size(), 3):
			add_edge(vertices, i, i + 1, edges, surface_tool)
			add_edge(vertices, i + 1, i + 2, edges, surface_tool)
			add_edge(vertices, i + 2, i, edges, surface_tool)

	surface_tool.index()
	return surface_tool.commit()

func add_edge(vertices: Array, i1: int, i2: int, edges: Dictionary, surface_tool: SurfaceTool):
	var key = Vector2i(min(i1, i2), max(i1, i2))  # Ensure uniqueness

	if edges.has(key):
		return
	edges[key] = true

	surface_tool.add_vertex(vertices[i1])  # Get actual vertex position
	surface_tool.add_vertex(vertices[i2])
