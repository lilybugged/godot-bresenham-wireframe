extends Node

# Optional: set a save path for testing
@export var save_path : String = "user://depth.png"

@onready var viewport : SubViewport = self.get_node("SubViewportContainer/SubViewport")
@onready var depth_display : TextureRect = $DepthDisplay

func _ready():
	# Create a shader that samples the built-in depth texture and writes it as a grayscale color.
	var shader = Shader.new()
	shader.code = '''
		shader_type spatial;
		render_mode unshaded;
		uniform sampler2D DEPTH_TEXTURE : hint_depth_texture, filter_linear_mipmap;
		// Note: DEPTH_TEXTURE is provided by the engine only inside shaders.
		void fragment() {
			// Sample the depth texture using SCREEN_UV.
			// The value "depth" will be in [0, 1], where 0 is near and 1 is far.
			float depth = texture(DEPTH_TEXTURE, SCREEN_UV).r;
			// Output the depth value as grayscale.
			COLOR = vec4(depth, depth, depth, 1.0);
		}
	'''
	var shader_material = ShaderMaterial.new()
	shader_material.shader = shader
	# Apply this shader material to the TextureRect that will display the depth data.
	depth_display.material = shader_material

func _process(delta):
	# For demonstration: press the "ui_accept" action (Enter/Space by default) to capture the depth image.
	if Input.is_action_just_pressed("ui_accept"):
		var depth_image = capture_depth_image()
		# Save the image to disk (for debugging purposes)
		depth_image.save_png(save_path)
		print("Depth image saved to: ", save_path)

func capture_depth_image() -> Image:
	# Get the rendered texture from the viewport.
	var texture : Texture2D = viewport.get_texture()
	# Retrieve its image data.
	var image : Image = texture.get_data()
	# Depending on your settings you might need to flip the image vertically.
	image.flip_y()
	return image
