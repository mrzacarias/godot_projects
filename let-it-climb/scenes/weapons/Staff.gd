extends Node2D
class_name Staff

# Staff weapon for Let it Climb - magical ranged weapon (replaces Crossbow)

signal attack_completed
signal enemy_hit(enemy_node)

@export var level: int = 1
@export var max_level: int = 5
@export var base_damage: float = 25.0  # Higher damage than bow
@export var base_attack_rate: float = 0.8  # Slower than bow
@export var projectile_speed: float = 600.0  # Slower than arrows
@export var max_range: float = 500.0  # Longer range than bow

var current_damage: float
var current_attack_rate: float
var attack_timer: float = 0.0
var is_attacking: bool = false
var shots_per_attack: Array[int] = [1, 2, 3, 5, 8]  # Magic bolts per tier

# Sprite references for different levels
var staff_sprites: Array[Texture2D] = []
var staff_sprite_node: Sprite2D

func _ready():
	# Load all staff sprites (levels 1-5)
	for i in range(1, max_level + 1):
		var texture = load("res://assets/weapons/staff/" + str(i) + ".png")
		if texture:
			staff_sprites.append(texture)
		else:
			print("Warning: Could not load staff sprite level %d" % i)
	
	# Get references
	staff_sprite_node = get_node("StaffSprite")
	
	# Configure sprite properties
	staff_sprite_node.visible = false
	staff_sprite_node.z_index = 10
	staff_sprite_node.rotation = -1.5708  # 90 degrees counter-clockwise
	staff_sprite_node.scale = Vector2(0.3, 0.3)
	
	# Initialize stats
	update_stats()
	update_sprite()

func update_stats():
	"""Update weapon stats based on level"""
	var level_multiplier = 1.0 + (level - 1) * 0.35  # 35% increase per level (higher than bow)
	current_damage = base_damage * level_multiplier
	current_attack_rate = base_attack_rate * (1.0 + (level - 1) * 0.15)  # 15% faster per level

func update_sprite():
	"""Update sprite based on current level"""
	if staff_sprites.size() >= level and staff_sprite_node:
		staff_sprite_node.texture = staff_sprites[level - 1]

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
		current_damage = base_damage * dex_multiplier * (1.0 + (level - 1) * 0.35)

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
	"""Start staff attack"""
	if is_attacking:
		return
	
	is_attacking = true
	
	# Position staff at player location
	global_position = player_position
	
	# Show staff briefly
	if staff_sprite_node:
		staff_sprite_node.visible = true
		staff_sprite_node.rotation = facing_direction.angle()
	
	# Fire magic bolts based on level
	var shots = shots_per_attack[min(level - 1, shots_per_attack.size() - 1)]
	fire_magic_bolts(player_position, facing_direction, shots)
	
	# Attack duration
	var attack_duration = 0.3  # Slightly longer than bow for magic casting
	await get_tree().create_timer(attack_duration).timeout
	
	# End attack
	end_attack()

func fire_magic_bolts(start_position: Vector2, direction: Vector2, shot_count: int):
	"""Fire multiple magic bolts"""
	for i in range(shot_count):
		var bolt_direction = direction
		
		# Add spread for multiple shots
		if shot_count > 1:
			var max_spread = deg_to_rad(40)  # 40 degree total spread (wider than bow)
			var spread_step = max_spread / (shot_count - 1) if shot_count > 1 else 0
			var spread_angle = -max_spread / 2 + i * spread_step
			bolt_direction = direction.rotated(spread_angle)
		
		create_magic_bolt(start_position, bolt_direction)

func create_magic_bolt(start_position: Vector2, direction: Vector2):
	"""Create a magic bolt projectile"""
	# Create a magic bolt using Area2D
	var bolt = Area2D.new()
	bolt.collision_layer = 0
	bolt.collision_mask = 2  # Hit enemies
	
	# Add sprite (glowing orb effect)
	var sprite = ColorRect.new()
	sprite.size = Vector2(16, 16)
	sprite.color = Color.CYAN  # Magic blue color
	sprite.position = Vector2(-8, -8)  # Center the sprite
	bolt.add_child(sprite)
	
	# Add collision shape
	var collision = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 8
	collision.shape = shape
	bolt.add_child(collision)
	
	# Set bolt properties
	bolt.global_position = start_position
	bolt.rotation = direction.angle()
	
	# Add bolt to scene
	get_tree().current_scene.add_child(bolt)
	
	# Connect collision
	bolt.body_entered.connect(_on_bolt_hit_enemy.bind(bolt))
	
	# Move bolt
	var tween = create_tween()
	var end_position = start_position + direction * max_range
	var travel_time = max_range / projectile_speed
	
	tween.tween_property(bolt, "global_position", end_position, travel_time)
	tween.tween_callback(bolt.queue_free)

func _on_bolt_hit_enemy(bolt: Area2D, enemy: Node2D):
	"""Handle magic bolt hitting an enemy"""
	if enemy.has_method("take_damage") and not enemy.name == "Player":
		enemy.take_damage(current_damage)
		enemy_hit.emit(enemy)
		bolt.queue_free()

func end_attack():
	"""End the staff attack"""
	is_attacking = false
	
	# Hide staff
	if staff_sprite_node:
		staff_sprite_node.visible = false
	
	# Emit completion signal
	attack_completed.emit()

func get_weapon_info() -> Dictionary:
	"""Get current weapon information"""
	return {
		"name": "Staff",
		"level": level,
		"damage": current_damage,
		"attack_rate": current_attack_rate,
		"range": max_range,
		"shots": shots_per_attack[min(level - 1, shots_per_attack.size() - 1)]
	}
