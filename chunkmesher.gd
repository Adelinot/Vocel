class_name ChunkMesher
extends Node

const NEIGHBOR_OFFSETS = [
	Vector3i(0, 1, 0),   # TOP (+Y)
	Vector3i(0, -1, 0),  # BOTTOM (-Y)
	Vector3i(0, 0, 1),   # FRONT (+Z)
	Vector3i(0, 0, -1),  # BACK (-Z)
	Vector3i(-1, 0, 0),  # LEFT (-X)
	Vector3i(1, 0, 0)    # RIGHT (+X)
]

const FACE_NORMALS = [
	Vector3(0, 1, 0),   # TOP
	Vector3(0, -1, 0),  # BOTTOM
	Vector3(0, 0, 1),   # FRONT
	Vector3(0, 0, -1),  # BACK
	Vector3(-1, 0, 0),  # LEFT
	Vector3(1, 0, 0)    # RIGHT
]

# Meshes a single 16x16x16 subchunk while referencing full chunk voxels for seamless neighbor culling
static func build_subchunk_mesh_data(voxels: PackedByteArray, sub_y: int) -> Dictionary:
	var vertices = PackedVector3Array()
	var normals = PackedVector3Array()
	var uvs = PackedVector2Array()
	var colors = PackedColorArray()
	var indices = PackedInt32Array()
	var collision_faces = PackedVector3Array()
	
	var vertex_count: int = 0
	var y_start: int = sub_y * 16

	for face_idx in range(6):
		var offset = NEIGHBOR_OFFSETS[face_idx]
		var normal = FACE_NORMALS[face_idx]

		var mask = PackedInt32Array()
		mask.resize(256) # 16x16 slice

		for d in range(16): # 16 vertical layers per subchunk
			mask.fill(0)
			var global_y = y_start + d

			for v in range(16):
				for u in range(16):
					var x: int; var y: int; var z: int
					if face_idx == 0 or face_idx == 1: # Y Axis
						x = u; y = global_y; z = v
					elif face_idx == 2 or face_idx == 3: # Z Axis
						x = u; y = y_start + v; z = d
					else: # X Axis
						x = d; y = y_start + v; z = u

					var index = x + (z * 16) + (y * 256)
					var block_id = voxels[index]

					if block_id != BlockDatabase.BlockType.AIR:
						var nx = x + offset.x
						var ny = y + offset.y
						var nz = z + offset.z

						var visible: bool = false
						if nx < 0 or nx >= 16 or ny < 0 or ny >= 256 or nz < 0 or nz >= 16:
							visible = true
						else:
							var neighbor_id = voxels[nx + (nz * 16) + (ny * 256)]
							visible = BlockDatabase.IS_TRANSPARENT[neighbor_id]

						if visible:
							mask[u + (v * 16)] = block_id

			var n: int = 0
			while n < 256:
				var block_id = mask[n]
				if block_id != 0:
					var u = n % 16
					var v = n / 16

					var w: int = 1
					while u + w < 16 and mask[(u + w) + (v * 16)] == block_id:
						w += 1

					var h: int = 1
					while v + h < 16:
						var can_extend = true
						for k in range(w):
							if mask[(u + k) + ((v + h) * 16)] != block_id:
								can_extend = false
								break
						if can_extend:
							h += 1
						else:
							break

					var quad_verts: Array[Vector3] = []
					# Vertices relative to subchunk root (0.0 to 16.0 range)
					if face_idx == 0: # TOP
						quad_verts = [Vector3(u, d + 1, v + h), Vector3(u + w, d + 1, v + h), Vector3(u + w, d + 1, v), Vector3(u, d + 1, v)]
					elif face_idx == 1: # BOTTOM
						quad_verts = [Vector3(u, d, v), Vector3(u + w, d, v), Vector3(u + w, d, v + h), Vector3(u, d, v + h)]
					elif face_idx == 2: # FRONT
						quad_verts = [Vector3(u, v, d + 1), Vector3(u + w, v, d + 1), Vector3(u + w, v + h, d + 1), Vector3(u, v + h, d + 1)]
					elif face_idx == 3: # BACK
						quad_verts = [Vector3(u + w, v, d), Vector3(u, v, d), Vector3(u, v + h, d), Vector3(u + w, v + h, d)]
					elif face_idx == 4: # LEFT
						quad_verts = [Vector3(d, v, u), Vector3(d, v, u + w), Vector3(d, v + h, u + w), Vector3(d, v + h, u)]
					elif face_idx == 5: # RIGHT
						quad_verts = [Vector3(d + 1, v, u + w), Vector3(d + 1, v, u), Vector3(d + 1, v + h, u), Vector3(d + 1, v + h, u + w)]

					var uv_vec: Vector4 = BlockDatabase.BLOCK_UVS[block_id][face_idx]
					var col = Color(uv_vec.x, uv_vec.y, uv_vec.z, uv_vec.w)

					for quad_v in quad_verts:
						vertices.append(quad_v)
						normals.append(normal)
						colors.append(col)

					uvs.append(Vector2(0, h))
					uvs.append(Vector2(w, h))
					uvs.append(Vector2(w, 0))
					uvs.append(Vector2(0, 0))

					indices.append(vertex_count + 0)
					indices.append(vertex_count + 2)
					indices.append(vertex_count + 1)
					indices.append(vertex_count + 0)
					indices.append(vertex_count + 3)
					indices.append(vertex_count + 2)

					collision_faces.append(quad_verts[0])
					collision_faces.append(quad_verts[2])
					collision_faces.append(quad_verts[1])
					collision_faces.append(quad_verts[0])
					collision_faces.append(quad_verts[3])
					collision_faces.append(quad_verts[2])

					vertex_count += 4

					for ly in range(h):
						for lx in range(w):
							mask[(u + lx) + ((v + ly) * 16)] = 0

				n += 1

	return {
		"vertices": vertices,
		"normals": normals,
		"uvs": uvs,
		"colors": colors,
		"indices": indices,
		"collision_faces": collision_faces
	}
