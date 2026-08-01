class_name ChunkGenerator
extends Node

# Fixed Chunk Dimensions
const SIZE_X: int = 16
const SIZE_Y: int = 256
const SIZE_Z: int = 16
const TOTAL_VOXELS: int = SIZE_X * SIZE_Y * SIZE_Z

# Helper function: Convert 3D local coordinates into 1D flat array index
static func get_voxel_index(x: int, y: int, z: int) -> int:
	return x + (z * SIZE_X) + (y * SIZE_X * SIZE_Z)

# Allocates and returns a fresh, populated block array for a single chunk
func generate_chunk_data(chunk_pos: Vector2i) -> PackedByteArray:
	var voxels = PackedByteArray()
	voxels.resize(TOTAL_VOXELS)
	voxels.fill(BlockDatabase.BlockType.AIR) # Default fill with Air (0)
	
	# Basic terrain test height generation (Will be replaced with FastNoiseLite in World Generation)
	for x in range(SIZE_X):
		for z in range(SIZE_Z):
			# Simple wave pattern for testing
			var surface_y = int(64.0 + sin((chunk_pos.x * SIZE_X + x) * 0.1) * 4.0 + cos((chunk_pos.y * SIZE_Z + z) * 0.1) * 4.0)
			
			for y in range(SIZE_Y):
				var index = get_voxel_index(x, y, z)
				
				if y == 0:
					voxels[index] = BlockDatabase.BlockType.BEDROCK
				elif y < surface_y - 4:
					voxels[index] = BlockDatabase.BlockType.STONE
				elif y < surface_y:
					voxels[index] = BlockDatabase.BlockType.DIRT
				elif y == surface_y:
					voxels[index] = BlockDatabase.BlockType.GRASS
				else:
					voxels[index] = BlockDatabase.BlockType.AIR
					
	return voxels
