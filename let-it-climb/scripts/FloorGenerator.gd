extends Node2D

# Floor generation system for Let it Climb

signal floor_generated

# Scene references
var tree_scene: PackedScene
var rock_scene: PackedScene
var chest_scene: PackedScene

# World settings
var world_size: Vector2 = Vector2(2880, 1920)
var center_safe_zone: float = 200.0  # Safe zone around center where player spawns

# Object counts per floor
var base_trees_per_floor: int = 15
var base_rocks_per_floor: int = 8
var base_chests_per_floor: int = 3

# Distance constraints
var min_tree_distance: float = 120.0
var min_rock_distance: float = 100.0
var min_chest_distance: float = 150.0
var min_object_distance: float = 80.0  # Minimum distance between any objects

# Current floor objects
var current_trees: Array[Node] = []
var current_rocks: Array[Node] = []
var current_chests: Array[Node] = []
var placed_positions: Array[Vector2] = []

func _ready():
	# Load scene references
	tree_scene = load("res://scenes/objects/Tree.tscn")
	rock_scene = load("res://scenes/objects/Rock.tscn")
	chest_scene = load("res://scenes/objects/Chest.tscn")

func generate_floor(floor_level: int):
	"""Generate a new floor with trees, rocks, and chests"""
	print("Generating floor %d..." % floor_level)
	
	# Clear existing objects
	clear_floor()
	
	# Calculate object counts based on floor level
	var tree_count = base_trees_per_floor + (floor_level - 1) * 2
	var rock_count = base_rocks_per_floor + (floor_level - 1) * 1
	var chest_count = base_chests_per_floor + (floor_level - 1) / 3.0  # More chests every 3 floors
	
	# Generate objects
	generate_trees(tree_count)
	generate_rocks(rock_count)
	generate_chests(chest_count)
	
	# Emit completion signal
	floor_generated.emit()
	
	print("Floor %d generated: %d trees, %d rocks, %d chests" % [floor_level, tree_count, rock_count, chest_count])

func clear_floor():
	"""Clear all objects from the current floor"""
	# Remove all current objects
	for tree in current_trees:
		if is_instance_valid(tree):
			tree.queue_free()
	
	for rock in current_rocks:
		if is_instance_valid(rock):
			rock.queue_free()
	
	for chest in current_chests:
		if is_instance_valid(chest):
			chest.queue_free()
	
	# Clear tracking arrays
	current_trees.clear()
	current_rocks.clear()
	current_chests.clear()
	placed_positions.clear()

func generate_trees(count: int):
	"""Generate trees on the floor"""
	if not tree_scene:
		return
	
	for i in range(count):
		var tree_position = generate_tree_position()
		if tree_position != Vector2.ZERO:
			var tree = tree_scene.instantiate()
			tree.global_position = tree_position
			add_child(tree)
			current_trees.append(tree)

func generate_rocks(count: int):
	"""Generate rocks on the floor"""
	if not rock_scene:
		return
	
	for i in range(count):
		var rock_position = generate_rock_position()
		if rock_position != Vector2.ZERO:
			var rock = rock_scene.instantiate()
			rock.global_position = rock_position
			add_child(rock)
			current_rocks.append(rock)

func generate_chests(count: int):
	"""Generate chests on the floor"""
	if not chest_scene:
		return
	
	for i in range(count):
		var chest_position = generate_chest_position()
		if chest_position != Vector2.ZERO:
			var chest = chest_scene.instantiate()
			chest.global_position = chest_position
			
			# Connect chest signals
			if chest.has_signal("chest_opened"):
				chest.chest_opened.connect(_on_chest_opened)
			
			add_child(chest)
			current_chests.append(chest)

func generate_tree_position() -> Vector2:
	"""Generate a valid position for a tree"""
	var attempts = 50
	
	for i in range(attempts):
		var pos = Vector2(
			randf_range(100, world_size.x - 100),
			randf_range(100, world_size.y - 100)
		)
		
		if is_valid_position(pos, min_tree_distance):
			placed_positions.append(pos)
			return pos
	
	return Vector2.ZERO

func generate_rock_position() -> Vector2:
	"""Generate a valid position for a rock"""
	var attempts = 50
	
	for i in range(attempts):
		var pos = Vector2(
			randf_range(100, world_size.x - 100),
			randf_range(100, world_size.y - 100)
		)
		
		if is_valid_position(pos, min_rock_distance):
			placed_positions.append(pos)
			return pos
	
	return Vector2.ZERO

func generate_chest_position() -> Vector2:
	"""Generate a valid position for a chest"""
	var attempts = 50
	
	for i in range(attempts):
		var pos = Vector2(
			randf_range(200, world_size.x - 200),
			randf_range(200, world_size.y - 200)
		)
		
		if is_valid_position(pos, min_chest_distance):
			placed_positions.append(pos)
			return pos
	
	return Vector2.ZERO

func is_valid_position(pos: Vector2, min_distance: float) -> bool:
	"""Check if a position is valid for placing an object"""
	# Check if too close to center (player spawn area)
	var center = world_size / 2
	if pos.distance_to(center) < center_safe_zone:
		return false
	
	# Check distance to other objects
	for existing_pos in placed_positions:
		if pos.distance_to(existing_pos) < min_distance:
			return false
	
	return true

func _on_chest_opened(chest_node):
	"""Handle chest being opened"""
	print("Chest opened!")
	
	# Remove from tracking array
	if chest_node in current_chests:
		current_chests.erase(chest_node)

func get_floor_info() -> Dictionary:
	"""Get information about current floor objects"""
	return {
		"trees": current_trees.size(),
		"rocks": current_rocks.size(),
		"chests": current_chests.size(),
		"total_objects": current_trees.size() + current_rocks.size() + current_chests.size()
	}

func get_remaining_chests() -> int:
	"""Get number of unopened chests remaining"""
	var unopened_count = 0
	for chest in current_chests:
		if is_instance_valid(chest) and chest.has_method("is_opened") and not chest.is_opened:
			unopened_count += 1
	return unopened_count
