extends Node2D
class_name Knives

# Knives weapon for Let it Climb - fast throwing knives

signal attack_completed
signal enemy_hit(enemy_node)

@export var level: int = 1
@export var max_level: int = 5
@export var base_damage: float = 12.0  # Lower damage but very fast
@export var base_attack_rate: float = 1.5  # Fastest ranged weapon
@export var projectile_speed: float = 1000.0  # Fastest projectiles
@export var max_range: float = 300.0  # Medium range

var current_damage: float
var current_attack_rate: float
var attack_timer: float = 0.0
var is_attacking: bool = false
var shots_per_attack: Array[int] = [1, 2, 3, 5, 8]  # Knives per tier

# Sprite references for different levels
var knives_sprites: Array[Texture2D] = []
var knives_sprite_node: Sprite2D

func _ready():
	# Load all knives sprites (levels 1-5)
	for i in range(1, max_level + 1):
		var texture = load("res://assets/weapons/knives/" + str(i) + ".png")
		if texture:
			knives_sprites.append(texture)
		else:
			print("Warning: Could not load knives sprite level %d" % i)
	
	# Get references
	knives_sprite_node = get_node("KnivesSprite")
	
	# Configure sprite properties
	knives_sprite_node.visible = false
	knives_sprite_node.z_index = 10
	knives_sprite_node.rotation = -1.5708  # 90 degrees counter-clockwise
	knives_sprite_node.scale = Vector2(0.3, 0.3)
	
	# Initialize stats
	update_stats()
	update_sprite()

func update_stats():
	"""Update weapon stats based on level"""
	var level_multiplier = 1.0 + (level - 1) * 0.3  # 30% increase per level
	current_damage = base_damage * level_multiplier
	current_attack_rate = base_attack_rate * (1.0 + (level - 1) * 0.25)  # 25% faster per level

func update_sprite():
	"""Update sprite based on current level"""
	if knives_sprites.size() >= level and knives_sprite_node:
		knives_sprite_node.texture = knives_sprites[level - 1]

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
		current_damage = base_damage * dex_multiplier * (1.0 + (level - 1) * 0.3)

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
	"""Start knives attack"""
	if is_attacking:
		return
	
	is_attacking = true
	
	# Position knives at player location
	global_position = player_position
	
	# Show knives briefly
	if knives_sprite_node:
		knives_sprite_node.visible = true
		knives_sprite_node.rotation = facing_direction.angle()
	
	# Throw knives based on level
	var shots = shots_per_attack[min(level - 1, shots_per_attack.size() - 1)]
	throw_knives(player_position, facing_direction, shots)
	
	# Attack duration (very fast)
	var attack_duration = 0.15  # Fastest attack
	await get_tree().create_timer(attack_duration).timeout
	
	# End attack
	end_attack()

func throw_knives(start_position: Vector2, direction: Vector2, shot_count: int):
	"""Throw multiple knives"""
	for i in range(shot_count):
		var knife_direction = direction
		
		# Add spread for multiple shots
		if shot_count > 1:
			var max_spread = deg_to_rad(25)  # 25 degree total spread (tighter than other ranged)
			var spread_step = max_spread / (shot_count - 1) if shot_count > 1 else 0
			var spread_angle = -max_spread / 2 + i * spread_step
			knife_direction = direction.rotated(spread_angle)
		
		create_knife(start_position, knife_direction)

func create_knife(start_position: Vector2, direction: Vector2):
	"""Create a knife projectile"""
	# Create a knife using Area2D
	var knife = Area2D.new()
	knife.collision_layer = 0
	knife.collision_mask = 2  # Hit enemies
	
	# Add sprite (small blade)
	var sprite = ColorRect.new()
	sprite.size = Vector2(12, 3)
	sprite.color = Color.SILVER  # Metallic color
	sprite.position = Vector2(-6, -1.5)  # Center the sprite
	knife.add_child(sprite)
	
	# Add collision shape
	var collision = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(12, 3)
	collision.shape = shape
	knife.add_child(collision)
	
	# Set knife properties
	knife.global_position = start_position
	knife.rotation = direction.angle()
	
	# Add knife to scene
	get_tree().current_scene.add_child(knife)
	
	# Connect collision
	knife.body_entered.connect(_on_knife_hit_enemy.bind(knife))
	
	# Move knife
	var tween = create_tween()
	var end_position = start_position + direction * max_range
	var travel_time = max_range / projectile_speed
	
	tween.tween_property(knife, "global_position", end_position, travel_time)
	tween.tween_callback(knife.queue_free)

func _on_knife_hit_enemy(knife: Area2D, enemy: Node2D):
	"""Handle knife hitting an enemy"""
	if enemy.has_method("take_damage") and not enemy.name == "Player":
		enemy.take_damage(current_damage)
		enemy_hit.emit(enemy)
		knife.queue_free()

func end_attack():
	"""End the knives attack"""
	is_attacking = false
	
	# Hide knives
	if knives_sprite_node:
		knives_sprite_node.visible = false
	
	# Emit completion signal
	attack_completed.emit()

func get_weapon_info() -> Dictionary:
	"""Get current weapon information"""
	return {
		"name": "Knives",
		"level": level,
		"damage": current_damage,
		"attack_rate": current_attack_rate,
		"range": max_range,
		"shots": shots_per_attack[min(level - 1, shots_per_attack.size() - 1)]
	}
