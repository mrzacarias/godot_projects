extends Node2D
class_name Bow

# Bow weapon for Let it Climb - ranged weapon that fires arrows

signal attack_completed
signal enemy_hit(enemy_node)

@export var level: int = 1
@export var max_level: int = 5
@export var base_damage: float = 15.0
@export var base_attack_rate: float = 1.0
@export var projectile_speed: float = 800.0
@export var max_range: float = 400.0

var current_damage: float
var current_attack_rate: float
var attack_timer: float = 0.0
var is_attacking: bool = false
var shots_per_attack: Array[int] = [1, 2, 3, 5, 8]  # Shots per tier

# Sprite references for different levels
var bow_sprites: Array[Texture2D] = []
var bow_sprite_node: Sprite2D

# Arrow projectile scene (will be created dynamically)
var arrow_scene: PackedScene

func _ready():
	# Load all bow sprites (levels 1-5)
	for i in range(1, max_level + 1):
		var texture = load("res://assets/weapons/bow/" + str(i) + ".png")
		if texture:
			bow_sprites.append(texture)
		else:
			print("Warning: Could not load bow sprite level %d" % i)
	
	# Get references
	bow_sprite_node = get_node("BowSprite")
	
	# Configure sprite properties
	bow_sprite_node.visible = false
	bow_sprite_node.z_index = 10
	bow_sprite_node.rotation = -1.5708  # 90 degrees counter-clockwise
	bow_sprite_node.scale = Vector2(0.3, 0.3)
	
	# Initialize stats
	update_stats()
	update_sprite()

func update_stats():
	"""Update weapon stats based on level"""
	var level_multiplier = 1.0 + (level - 1) * 0.25  # 25% increase per level
	current_damage = base_damage * level_multiplier
	current_attack_rate = base_attack_rate * (1.0 + (level - 1) * 0.2)  # 20% faster per level

func update_sprite():
	"""Update sprite based on current level"""
	if bow_sprites.size() >= level and bow_sprite_node:
		bow_sprite_node.texture = bow_sprites[level - 1]

func set_level(new_level: int):
	"""Set weapon level and update stats"""
	level = clamp(new_level, 1, max_level)
	update_stats()
	update_sprite()

func set_owner_stats(character):
	"""Set owner character stats for damage scaling"""
	if character and character.has_method("get_stat_value"):
		var dex_value = character.get_stat_value("dex")
		# Scale damage based on DEX (10 is baseline, each point above/below adds/removes 5%)
		var dex_multiplier = 1.0 + (dex_value - 10) * 0.05
		current_damage = base_damage * dex_multiplier * (1.0 + (level - 1) * 0.25)

func get_attack_cooldown() -> float:
	"""Get time between attacks"""
	return 1.0 / current_attack_rate

func can_attack() -> bool:
	"""Check if weapon can attack"""
	return not is_attacking

func has_targets_nearby(player_position: Vector2) -> bool:
	"""Check if there are enemies within attack range"""
	var all_enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in all_enemies:
		if enemy and is_instance_valid(enemy):
			var distance = player_position.distance_to(enemy.global_position)
			if distance <= max_range:
				return true
	
	return false

func start_attack(player_position: Vector2, facing_direction: Vector2):
	"""Start bow attack"""
	if is_attacking:
		return
	
	is_attacking = true
	
	# Position bow at player location
	global_position = player_position
	
	# Show bow briefly
	if bow_sprite_node:
		bow_sprite_node.visible = true
		bow_sprite_node.rotation = facing_direction.angle()
	
	# Fire arrows based on level
	var shots = shots_per_attack[min(level - 1, shots_per_attack.size() - 1)]
	fire_arrows(player_position, facing_direction, shots)
	
	# Attack duration
	var attack_duration = 0.2  # Quick ranged attack
	await get_tree().create_timer(attack_duration).timeout
	
	# End attack
	end_attack()

func fire_arrows(start_position: Vector2, direction: Vector2, shot_count: int):
	"""Fire multiple arrows"""
	for i in range(shot_count):
		var arrow_direction = direction
		
		# Add spread for multiple shots
		if shot_count > 1:
			var max_spread = deg_to_rad(30)  # 30 degree total spread
			var spread_step = max_spread / (shot_count - 1) if shot_count > 1 else 0
			var spread_angle = -max_spread / 2 + i * spread_step
			arrow_direction = direction.rotated(spread_angle)
		
		create_arrow(start_position, arrow_direction)

func create_arrow(start_position: Vector2, direction: Vector2):
	"""Create an arrow projectile"""
	# Create a simple arrow using Area2D
	var arrow = Area2D.new()
	arrow.collision_layer = 0
	arrow.collision_mask = 2  # Hit enemies
	
	# Add sprite (simple colored rectangle for now)
	var sprite = ColorRect.new()
	sprite.size = Vector2(20, 4)
	sprite.color = Color.BROWN
	sprite.position = Vector2(-10, -2)  # Center the sprite
	arrow.add_child(sprite)
	
	# Add collision shape
	var collision = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(20, 4)
	collision.shape = shape
	arrow.add_child(collision)
	
	# Set arrow properties
	arrow.global_position = start_position
	arrow.rotation = direction.angle()
	
	# Add arrow to scene
	get_tree().current_scene.add_child(arrow)
	
	# Connect collision
	arrow.body_entered.connect(_on_arrow_hit_enemy.bind(arrow))
	
	# Move arrow
	var tween = create_tween()
	var end_position = start_position + direction * max_range
	var travel_time = max_range / projectile_speed
	
	tween.tween_property(arrow, "global_position", end_position, travel_time)
	tween.tween_callback(arrow.queue_free)

func _on_arrow_hit_enemy(arrow: Area2D, enemy: Node2D):
	"""Handle arrow hitting an enemy"""
	if enemy.has_method("take_damage") and not enemy.name == "Player":
		enemy.take_damage(current_damage)
		enemy_hit.emit(enemy)
		arrow.queue_free()

func end_attack():
	"""End the bow attack"""
	is_attacking = false
	
	# Hide bow
	if bow_sprite_node:
		bow_sprite_node.visible = false
	
	# Emit completion signal
	attack_completed.emit()

func get_weapon_info() -> Dictionary:
	"""Get current weapon information"""
	return {
		"name": "Bow",
		"level": level,
		"damage": current_damage,
		"attack_rate": current_attack_rate,
		"range": max_range,
		"shots": shots_per_attack[min(level - 1, shots_per_attack.size() - 1)]
	}
