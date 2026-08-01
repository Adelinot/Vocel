extends Node3D

@onready var generator: ChunkGenerator = $ChunkGenerator
@onready var active_chunks: Node3D = $ActiveChunks
@onready var fps_label: Label = $UI/FPSLabel

@export var player_scene: PackedScene
@export var atlas_texture: Texture2D # Drag tileset.png into Inspector slot

var voxel_material: ShaderMaterial

func _ready() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	
	# Create Greedy Voxel Shader Material
	if atlas_texture:
		voxel_material = BlockDatabase.get_voxel_material(atlas_texture)
	
	build_test_chunk()
	spawn_player()

func _process(_delta: float) -> void:
	if fps_label:
		fps_label.text = "FPS: " + str(Engine.get_frames_per_second())

func build_test_chunk() -> void:
	var chunk = Chunk.new()
	chunk.setup(Vector2i(0, 0), generator, voxel_material)
	active_chunks.add_child(chunk)

func spawn_player() -> void:
	if player_scene:
		var player_instance = player_scene.instantiate()
		add_child(player_instance)
		player_instance.global_position = Vector3(8.0, 100.0, 8.0)
