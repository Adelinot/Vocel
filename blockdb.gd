class_name BlockDatabase
extends Node

const ATLAS_WIDTH: float = 48.0
const ATLAS_HEIGHT: float = 64.0
const TEXTURE_SIZE: float = 16.0

const UV_STEP_X: float = TEXTURE_SIZE / ATLAS_WIDTH  # 1/3
const UV_STEP_Y: float = TEXTURE_SIZE / ATLAS_HEIGHT # 1/4

enum Face { TOP, BOTTOM, FRONT, BACK, LEFT, RIGHT }

enum BlockType {
	AIR = 0,
	GRASS = 1,
	DIRT = 2,
	STONE = 3,
	BEDROCK = 4
}

static var IS_TRANSPARENT: Array[bool] = [
	true,  # AIR
	false, # GRASS
	false, # DIRT
	false, # STONE
	false  # BEDROCK
]

# Fixed Atlas Mapping:
# Grass Top: (0,0), Grass Side: (1,0), Dirt: (2,0), Stone: (1,1), Bedrock: (0,1)
static var BLOCK_UVS: Dictionary = {
	BlockType.GRASS: [
		Vector4(0.0 * UV_STEP_X, 0.0 * UV_STEP_Y, 1.0 * UV_STEP_X, 1.0 * UV_STEP_Y), # TOP (0,0)
		Vector4(2.0 * UV_STEP_X, 0.0 * UV_STEP_Y, 3.0 * UV_STEP_X, 1.0 * UV_STEP_Y), # BOTTOM Dirt (2,0)
		Vector4(1.0 * UV_STEP_X, 0.0 * UV_STEP_Y, 2.0 * UV_STEP_X, 1.0 * UV_STEP_Y), # FRONT Side (1,0)
		Vector4(1.0 * UV_STEP_X, 0.0 * UV_STEP_Y, 2.0 * UV_STEP_X, 1.0 * UV_STEP_Y), # BACK Side (1,0)
		Vector4(1.0 * UV_STEP_X, 0.0 * UV_STEP_Y, 2.0 * UV_STEP_X, 1.0 * UV_STEP_Y), # LEFT Side (1,0)
		Vector4(1.0 * UV_STEP_X, 0.0 * UV_STEP_Y, 2.0 * UV_STEP_X, 1.0 * UV_STEP_Y)  # RIGHT Side (1,0)
	],
	BlockType.DIRT: [
		Vector4(2.0 * UV_STEP_X, 0.0 * UV_STEP_Y, 3.0 * UV_STEP_X, 1.0 * UV_STEP_Y),
		Vector4(2.0 * UV_STEP_X, 0.0 * UV_STEP_Y, 3.0 * UV_STEP_X, 1.0 * UV_STEP_Y),
		Vector4(2.0 * UV_STEP_X, 0.0 * UV_STEP_Y, 3.0 * UV_STEP_X, 1.0 * UV_STEP_Y),
		Vector4(2.0 * UV_STEP_X, 0.0 * UV_STEP_Y, 3.0 * UV_STEP_X, 1.0 * UV_STEP_Y),
		Vector4(2.0 * UV_STEP_X, 0.0 * UV_STEP_Y, 3.0 * UV_STEP_X, 1.0 * UV_STEP_Y),
		Vector4(2.0 * UV_STEP_X, 0.0 * UV_STEP_Y, 3.0 * UV_STEP_X, 1.0 * UV_STEP_Y)
	],
	BlockType.STONE: [
		Vector4(1.0 * UV_STEP_X, 1.0 * UV_STEP_Y, 2.0 * UV_STEP_X, 2.0 * UV_STEP_Y),
		Vector4(1.0 * UV_STEP_X, 1.0 * UV_STEP_Y, 2.0 * UV_STEP_X, 2.0 * UV_STEP_Y),
		Vector4(1.0 * UV_STEP_X, 1.0 * UV_STEP_Y, 2.0 * UV_STEP_X, 2.0 * UV_STEP_Y),
		Vector4(1.0 * UV_STEP_X, 1.0 * UV_STEP_Y, 2.0 * UV_STEP_X, 2.0 * UV_STEP_Y),
		Vector4(1.0 * UV_STEP_X, 1.0 * UV_STEP_Y, 2.0 * UV_STEP_X, 2.0 * UV_STEP_Y),
		Vector4(1.0 * UV_STEP_X, 1.0 * UV_STEP_Y, 2.0 * UV_STEP_X, 2.0 * UV_STEP_Y)
	],
	BlockType.BEDROCK: [
		Vector4(0.0 * UV_STEP_X, 1.0 * UV_STEP_Y, 1.0 * UV_STEP_X, 2.0 * UV_STEP_Y),
		Vector4(0.0 * UV_STEP_X, 1.0 * UV_STEP_Y, 1.0 * UV_STEP_X, 2.0 * UV_STEP_Y),
		Vector4(0.0 * UV_STEP_X, 1.0 * UV_STEP_Y, 1.0 * UV_STEP_X, 2.0 * UV_STEP_Y),
		Vector4(0.0 * UV_STEP_X, 1.0 * UV_STEP_Y, 1.0 * UV_STEP_X, 2.0 * UV_STEP_Y),
		Vector4(0.0 * UV_STEP_X, 1.0 * UV_STEP_Y, 1.0 * UV_STEP_X, 2.0 * UV_STEP_Y),
		Vector4(0.0 * UV_STEP_X, 1.0 * UV_STEP_Y, 1.0 * UV_STEP_X, 2.0 * UV_STEP_Y)
	]
}

static var _cached_material: ShaderMaterial = null

# Custom Shader: Tile Wrapping + World Position Hashing for Random Texture Rotation
static func get_voxel_material(atlas_texture: Texture2D) -> ShaderMaterial:
	if _cached_material != null:
		return _cached_material

	var shader = Shader.new()
	shader.code = """
	shader_type spatial;
	render_mode cull_back, depth_draw_always;

	uniform sampler2D texture_atlas : filter_nearest, source_color;

	varying vec4 v_uv_rect;
	varying vec3 v_world_pos;

	float hash(vec2 p) {
		return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
	}

	void vertex() {
		v_uv_rect = COLOR;
		v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	}

	void fragment() {
		vec2 block_grid = floor(v_world_pos.xz + v_world_pos.yy);
		float rnd = hash(block_grid);

		vec2 local_uv = fract(UV);

		// Randomly rotate local texture coordinates per 1m block tile
		if (rnd > 0.75) {
			local_uv = vec2(1.0 - local_uv.y, local_uv.x);
		} else if (rnd > 0.5) {
			local_uv = vec2(1.0 - local_uv.x, 1.0 - local_uv.y);
		} else if (rnd > 0.25) {
			local_uv = vec2(local_uv.y, 1.0 - local_uv.x);
		}

		vec2 final_uv = mix(v_uv_rect.xy, v_uv_rect.zw, local_uv);
		ALBEDO = texture(texture_atlas, final_uv).rgb;
	}
	"""

	_cached_material = ShaderMaterial.new()
	_cached_material.shader = shader
	if atlas_texture:
		_cached_material.set_shader_parameter("texture_atlas", atlas_texture)

	return _cached_material
