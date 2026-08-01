class_name Chunk
extends Node3D

# Internal helper struct for subchunk nodes
class SubchunkData:
	var sub_y: int
	var node: Node3D
	var mesh_instance: MeshInstance3D
	var static_body: StaticBody3D
	var collision_shape: CollisionShape3D
	var is_meshing: bool = false
	var pending_rebuild: bool = false

var chunk_pos: Vector2i
var voxels: PackedByteArray
var subchunks: Array[SubchunkData] = []

@export var voxel_material: Material

func setup(pos: Vector2i, generator: ChunkGenerator, material: Material) -> void:
	chunk_pos = pos
	voxel_material = material
	
	# Background generation of 64 KB voxel array
	WorkerThreadPool.add_task(func():
		var data = generator.generate_chunk_data(chunk_pos)
		call_deferred("_on_data_generated", data)
	)

func _on_data_generated(data: PackedByteArray) -> void:
	voxels = data
	_create_subchunk_nodes()
	
	# Initial build for all active subchunks
	for sub_y in range(16):
		if _subchunk_has_blocks(sub_y):
			rebuild_subchunk_async(sub_y)

func _create_subchunk_nodes() -> void:
	subchunks.resize(16)
	for sub_y in range(16):
		var sub = SubchunkData.new()
		sub.sub_y = sub_y
		
		sub.node = Node3D.new()
		sub.node.name = "Subchunk_" + str(sub_y)
		sub.node.position = Vector3(0, sub_y * 16, 0)
		add_child(sub.node)
		
		sub.mesh_instance = MeshInstance3D.new()
		sub.node.add_child(sub.mesh_instance)
		
		sub.static_body = StaticBody3D.new()
		sub.collision_shape = CollisionShape3D.new()
		sub.static_body.add_child(sub.collision_shape)
		sub.mesh_instance.add_child(sub.static_body)
		
		subchunks[sub_y] = sub

func _subchunk_has_blocks(sub_y: int) -> bool:
	var y_start = sub_y * 16
	for y in range(y_start, y_start + 16):
		var y_offset = y * 256
		for z in range(16):
			var z_offset = z * 16
			for x in range(16):
				if voxels[x + z_offset + y_offset] != BlockDatabase.BlockType.AIR:
					return true
	return false

# Set block and update ONLY affected subchunk(s)
func set_block(x: int, y: int, z: int, block_id: int) -> bool:
	if x < 0 or x >= 16 or y < 0 or y >= 256 or z < 0 or z >= 16:
		return false
		
	var index = x + (z * 16) + (y * 256)
	if voxels[index] == block_id:
		return false
		
	voxels[index] = block_id
	
	var sub_y = y / 16
	rebuild_subchunk_async(sub_y)
	
	# Boundary checks: update adjacent subchunk if editing border face
	var local_y = y % 16
	if local_y == 0 and sub_y > 0:
		rebuild_subchunk_async(sub_y - 1)
	elif local_y == 15 and sub_y < 15:
		rebuild_subchunk_async(sub_y + 1)
		
	return true

# Async rebuild targeted to a single 16x16x16 subchunk
func rebuild_subchunk_async(sub_y: int) -> void:
	if sub_y < 0 or sub_y >= 16 or subchunks.size() == 0:
		return
		
	var sub = subchunks[sub_y]
	if sub.is_meshing:
		sub.pending_rebuild = true
		return
		
	sub.is_meshing = true
	var voxels_copy = voxels.duplicate()
	
	WorkerThreadPool.add_task(func():
		var mesh_data = ChunkMesher.build_subchunk_mesh_data(voxels_copy, sub_y)
		call_deferred("_apply_subchunk_mesh_data", sub_y, mesh_data)
	)

func _apply_subchunk_mesh_data(sub_y: int, mesh_data: Dictionary) -> void:
	var sub = subchunks[sub_y]
	sub.is_meshing = false
	
	var vertices: PackedVector3Array = mesh_data["vertices"]
	var collision_faces: PackedVector3Array = mesh_data["collision_faces"]
	
	if vertices.size() == 0:
		sub.mesh_instance.mesh = null
		sub.collision_shape.shape = null
		_check_pending(sub_y)
		return

	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = mesh_data["normals"]
	arrays[Mesh.ARRAY_TEX_UV] = mesh_data["uvs"]
	arrays[Mesh.ARRAY_COLOR] = mesh_data["colors"]
	arrays[Mesh.ARRAY_INDEX] = mesh_data["indices"]

	var array_mesh = ArrayMesh.new()
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	
	sub.mesh_instance.mesh = array_mesh
	if voxel_material:
		sub.mesh_instance.material_override = voxel_material
		
	var shape = ConcavePolygonShape3D.new()
	shape.set_faces(collision_faces)
	sub.collision_shape.shape = shape
	
	_check_pending(sub_y)

func _check_pending(sub_y: int) -> void:
	var sub = subchunks[sub_y]
	if sub.pending_rebuild:
		sub.pending_rebuild = false
		rebuild_subchunk_async(sub_y)
