extends Node2D

# Enemy spawning system for Let it Climb

signal wave_completed

@export var spawn_radius: float = 800.0
@export var min_spawn_distance: float = 300.0
@export var max_enemies_at_once: int = 20
@export var spawn_interval: float = 2.0

# Enemy scenes to spawn
var enemy_scenes: Array[PackedScene] = []
var current_floor: int = 1
var target_player: Node2D

# Spawning state
var active_enemies: Array[Node] = []
var spawn_timer: float = 0.0
var is_spawning: bool = false
var enemies_to_spawn: int = 0
var total_enemies_spawned: int = 0

# Wave system
var current_wave: int = 0
var enemies_per_wave: int = 10

func _ready():
	# Load enemy scenes
	load_enemy_scenes()
	
	# Find player
	find_player()

func _process(delta: float):
	if is_spawning:
		spawn_timer += delta
		
		if spawn_timer >= spawn_interval and can_spawn_enemy():
			spawn_enemy()
			spawn_timer = 0.0
		
		# Check if wave is complete
		check_wave_completion()

func load_enemy_scenes():
	"""Load enemy scene files"""
	var basic_enemy_scene = load("res://scenes/enemies/BasicEnemy.tscn")
	enemy_scenes.append(basic_enemy_scene)

func find_player():
	"""Find the player node"""
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		target_player = players[0]

func set_floor_level(floor_number: int):
	"""Set the current floor level"""
	current_floor = floor_number
	calculate_wave_parameters()

func calculate_wave_parameters():
	"""Calculate wave parameters based on floor level"""
	# More enemies and stronger enemies on higher floors
	enemies_per_wave = 10 + (current_floor - 1) * 2
	max_enemies_at_once = min(20 + (current_floor - 1), 50)  # Cap at 50
	spawn_interval = max(0.5, 2.0 - (current_floor - 1) * 0.1)  # Faster spawning on higher floors

func start_wave():
	"""Start spawning a new wave of enemies"""
	current_wave += 1
	enemies_to_spawn = enemies_per_wave
	total_enemies_spawned = 0
	is_spawning = true
	print("Starting wave %d on floor %d - %d enemies to spawn" % [current_wave, current_floor, enemies_to_spawn])

func stop_spawning():
	"""Stop spawning enemies"""
	is_spawning = false

func can_spawn_enemy() -> bool:
	"""Check if we can spawn another enemy"""
	return (active_enemies.size() < max_enemies_at_once and 
			total_enemies_spawned < enemies_to_spawn)

func spawn_enemy():
	"""Spawn a new enemy"""
	if enemy_scenes.is_empty():
		return
	
	# Choose random enemy scene
	var enemy_scene = enemy_scenes[randi() % enemy_scenes.size()]
	var enemy = enemy_scene.instantiate()
	
	# Set spawn position
	var spawn_pos = get_spawn_position()
	if spawn_pos == Vector2.ZERO:
		enemy.queue_free()
		return
	
	enemy.global_position = spawn_pos
	
	# Set floor level for enemy scaling
	if enemy.has_method("set_floor_level"):
		enemy.set_floor_level(current_floor)
	
	# Connect death signal
	if enemy.has_signal("enemy_died"):
		enemy.enemy_died.connect(_on_enemy_died)
	
	# Add to scene and track
	get_parent().add_child(enemy)
	active_enemies.append(enemy)
	total_enemies_spawned += 1
	
	print("Spawned enemy %d/%d" % [total_enemies_spawned, enemies_to_spawn])

func get_spawn_position() -> Vector2:
	"""Get a valid spawn position around the player"""
	if not target_player:
		return Vector2.ZERO
	
	var attempts = 20
	for i in range(attempts):
		# Generate random angle and distance
		var angle = randf() * TAU
		var distance = randf_range(min_spawn_distance, spawn_radius)
		
		var spawn_pos = target_player.global_position + Vector2.from_angle(angle) * distance
		
		if is_valid_spawn_position(spawn_pos):
			return spawn_pos
	
	return Vector2.ZERO

func is_valid_spawn_position(pos: Vector2) -> bool:
	"""Check if spawn position is valid"""
	# Basic validation - could add more checks for obstacles
	return pos.distance_to(target_player.global_position) >= min_spawn_distance

func check_wave_completion():
	"""Check if the current wave is complete"""
	# Clean up dead enemies
	active_enemies = active_enemies.filter(func(enemy): return is_instance_valid(enemy))
	
	# Check if wave is complete
	if total_enemies_spawned >= enemies_to_spawn and active_enemies.is_empty():
		is_spawning = false
		wave_completed.emit()
		print("Wave %d completed!" % current_wave)

func clear_all_enemies():
	"""Clear all active enemies"""
	for enemy in active_enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	active_enemies.clear()

func get_active_enemy_count() -> int:
	"""Get number of active enemies"""
	active_enemies = active_enemies.filter(func(enemy): return is_instance_valid(enemy))
	return active_enemies.size()

func get_enemies_remaining() -> int:
	"""Get number of enemies remaining in current wave"""
	return max(0, enemies_to_spawn - total_enemies_spawned) + get_active_enemy_count()

func _on_enemy_died(enemy: Node, exp_reward: int):
	"""Handle enemy death"""
	# Remove from active enemies
	if enemy in active_enemies:
		active_enemies.erase(enemy)
	
	# Award experience to player
	if target_player and target_player.has_method("gain_experience"):
		target_player.gain_experience(exp_reward)
	
	print("Enemy died, %d active enemies remaining" % active_enemies.size())

func force_spawn_enemy():
	"""Force spawn an enemy (for testing)"""
	if can_spawn_enemy():
		spawn_enemy()

func get_spawn_info() -> Dictionary:
	"""Get current spawning information"""
	return {
		"current_wave": current_wave,
		"current_floor": current_floor,
		"active_enemies": get_active_enemy_count(),
		"enemies_spawned": total_enemies_spawned,
		"enemies_to_spawn": enemies_to_spawn,
		"is_spawning": is_spawning,
		"enemies_remaining": get_enemies_remaining()
	}
