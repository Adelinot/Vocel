class_name Player
extends CharacterBody3D

@export_category("Movement Settings")
@export var SPEED: float = 8.0
@export var JUMP_VELOCITY: float = 6.5
@export var MOUSE_SENSITIVITY: float = 0.003
@export var REACH_DISTANCE: float = 6.0

@export_category("Node References")
@export var head: Node3D
@export var camera: Camera3D

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var selected_block: int = BlockDatabase.BlockType.DIRT

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if not head and has_node("Head"): head = $Head
	if not camera and has_node("Head/Camera3D"): camera = $Head/Camera3D

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		if head:
			head.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
			head.rotation.x = clamp(head.rotation.x, deg_to_rad(-89.0), deg_to_rad(89.0))

	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_1: selected_block = BlockDatabase.BlockType.GRASS
		elif event.keycode == KEY_2: selected_block = BlockDatabase.BlockType.DIRT
		elif event.keycode == KEY_3: selected_block = BlockDatabase.BlockType.STONE

	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if event.is_action_pressed("mb_left") or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed):
			interact_block(false)
		elif event.is_action_pressed("mb_right") or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed):
			interact_block(true)
			
func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta

	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	move_and_slide()

# PHYSICS SHAPE CAST: Prevents placing blocks inside player legs/body
func is_block_space_occupied(block_coords: Vector3i) -> bool:
	var space_state = get_world_3d().direct_space_state
	var shape = BoxShape3D.new()
	# 0.95 size to prevent false triggers against neighboring wall blocks
	shape.size = Vector3(0.95, 0.95, 0.95)
	
	var query = PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis(), Vector3(block_coords) + Vector3(0.5, 0.5, 0.5))
	
	var hits = space_state.intersect_shape(query)
	return hits.size() > 0

func interact_block(is_placing: bool) -> void:
	if not camera: return
	
	var space_state = get_world_3d().direct_space_state
	var ray_origin = camera.global_position
	var ray_end = ray_origin + (-camera.global_transform.basis.z * REACH_DISTANCE)
	
	var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	query.exclude = [self]
	
	var result = space_state.intersect_ray(query)
	
	if result:
		var hit_pos: Vector3 = result.position
		var hit_normal: Vector3 = result.normal
		
		var target_pos: Vector3
		if is_placing:
			target_pos = hit_pos + (hit_normal * 0.05)
		else:
			target_pos = hit_pos - (hit_normal * 0.05)
			
		var block_coords = Vector3i(
			int(floor(target_pos.x)),
			int(floor(target_pos.y)),
			int(floor(target_pos.z))
		)
		
		# Reject placement if the target space collides with player legs/body
		if is_placing and is_block_space_occupied(block_coords):
			return
		
		var chunk_node = get_parent_chunk(result.collider)
		if chunk_node:
			var block_to_set = selected_block if is_placing else BlockDatabase.BlockType.AIR
			chunk_node.set_block(block_coords.x, block_coords.y, block_coords.z, block_to_set)

func get_parent_chunk(node: Node) -> Chunk:
	var current = node
	while current:
		if current is Chunk:
			return current
		current = current.get_parent()
	return null
