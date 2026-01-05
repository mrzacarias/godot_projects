extends Node2D
class_name Bat

# Bat weapon for Let it Climb - heavy hitting melee weapon (replaces Hammer)

signal attack_completed
signal enemy_hit(enemy_node)

@export var level: int = 1
@export var max_level: int = 5
@export var base_damage: float = 35.0  # Higher damage than sword/axe
@export var base_attack_rate: float = 0.7  # Slower than sword/axe
@export var attack_arc_degrees: float = 100.0

var current_damage: float
var current_attack_rate: float
var attack_timer: float = 0.0
var is_attacking: bool = false
var base_attack_range: float = 140.0  # Shorter range due to blunt weapon
var bat_reach_distance: float = 85.0  # Distance from pivot to bat head during swing

# Sprite references for different levels
var bat_sprites: Array[Texture2D] = []
var bat_sprite_node: Sprite2D

# Collision detection for bat hits
var bat_area: Area2D
var hit_targets: Array = []  # Track what we've already hit this attack

func _ready():
	# Load all bat sprites (levels 1-5)
	for i in range(1, max_level + 1):
		var texture = load("res://assets/weapons/bat/" + str(i) + ".png")
		if texture:
			bat_sprites.append(texture)
		else:
			print("Warning: Could not load bat sprite level %d" % i)
	
	# Get references
	bat_sprite_node = get_node("BatSprite")
	bat_area = %BatArea
	
	# Configure sprite properties
	bat_sprite_node.visible = false
	bat_sprite_node.z_index = 10
	bat_sprite_node.rotation = -1.5708  # 90 degrees counter-clockwise
	bat_sprite_node.scale = Vector2(0.3, 0.3)
	
	# Connect collision detection
	if bat_area:
		bat_area.body_entered.connect(_on_bat_area_body_entered)
	
	# Initialize stats
	update_stats()
	update_sprite()

func update_stats():
	"""Update weapon stats based on level"""
	var level_multiplier = 1.0 + (level - 1) * 0.4  # 40% increase per level (higher than other weapons)
	current_damage = base_damage * level_multiplier
	current_attack_rate = base_attack_rate * (1.0 + (level - 1) * 0.1)  # 10% faster per level

func update_sprite():
	"""Update sprite based on current level"""
	if bat_sprites.size() >= level and bat_sprite_node:
		bat_sprite_node.texture = bat_sprites[level - 1]

func set_level(new_level: int):
	"""Set weapon level and update stats"""
	level = clamp(new_level, 1, max_level)
	update_stats()
	update_sprite()

func set_owner_stats(character):
	"""Set owner character stats for damage scaling"""
	if character and character.has_method("get_stat_value"):
		var str_value = character.get_stat_value("str")
		# Scale damage based on STR (10 is baseline, each point above/below adds/removes 5%)
		var str_multiplier = 1.0 + (str_value - 10) * 0.05
		current_damage = base_damage * str_multiplier * (1.0 + (level - 1) * 0.4)

func get_attack_cooldown() -> float:
	"""Get time between attacks"""
	return 1.0 / current_attack_rate

func can_attack() -> bool:
	"""Check if weapon can attack"""
	return not is_attacking

func has_targets_nearby(player_position: Vector2) -> bool:
	"""Check if there are enemies within attack range"""
	# Get all bodies in the game
	var space_state = get_world_2d().direct_space_state
	if not space_state:
		return false
	
	# Simple distance check for enemies
	var all_enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in all_enemies:
		if enemy and is_instance_valid(enemy):
			var distance = player_position.distance_to(enemy.global_position)
			if distance <= base_attack_range:
				return true
	
	return false

func start_attack(player_position: Vector2, facing_direction: Vector2):
	"""Start bat attack"""
	if is_attacking:
		return
	
	is_attacking = true
	hit_targets.clear()
	
	# Position bat at player location
	global_position = player_position
	
	# Enable collision detection
	if bat_area:
		bat_area.monitoring = true
	
	# Show and animate bat
	if bat_sprite_node:
		bat_sprite_node.visible = true
		animate_bat_swing(facing_direction)
	
	# Attack duration (longer than sword due to heavy weapon)
	var attack_duration = 0.4  # 400ms attack animation
	await get_tree().create_timer(attack_duration).timeout
	
	# End attack
	end_attack()

func animate_bat_swing(facing_direction: Vector2):
	"""Animate the bat swing"""
	if not bat_sprite_node:
		return
	
	# Calculate swing positions (wider arc for bat)
	var start_angle = facing_direction.angle() - deg_to_rad(attack_arc_degrees / 2)
	var end_angle = facing_direction.angle() + deg_to_rad(attack_arc_degrees / 2)
	
	# Position bat at start of swing
	var start_pos = Vector2(cos(start_angle), sin(start_angle)) * bat_reach_distance
	bat_sprite_node.position = start_pos
	bat_sprite_node.rotation = start_angle + deg_to_rad(90) - 1.5708  # Bat points outward + base rotation
	
	# Create tween for swing animation
	var tween = create_tween()
	tween.set_parallel(true)
	
	# Animate position
	var end_pos = Vector2(cos(end_angle), sin(end_angle)) * bat_reach_distance
	tween.tween_property(bat_sprite_node, "position", end_pos, 0.4)
	
	# Animate rotation
	tween.tween_property(bat_sprite_node, "rotation", end_angle + deg_to_rad(90) - 1.5708, 0.4)

func end_attack():
	"""End the bat attack"""
	is_attacking = false
	
	# Hide bat
	if bat_sprite_node:
		bat_sprite_node.visible = false
	
	# Disable collision detection
	if bat_area:
		bat_area.monitoring = false
	
	# Reset position
	if bat_sprite_node:
		bat_sprite_node.position = Vector2.ZERO
		bat_sprite_node.rotation = -1.5708  # Reset to base rotation
	
	# Clear hit targets
	hit_targets.clear()
	
	# Emit completion signal
	attack_completed.emit()

func _on_bat_area_body_entered(body):
	"""Handle collision with potential targets"""
	# Only damage enemies that we haven't hit yet this attack
	if body.has_method("take_damage") and not body.name == "Player" and body not in hit_targets:
		hit_targets.append(body)
		hit_enemy(body)

func hit_enemy(enemy_node):
	"""Deal damage to an enemy"""
	if enemy_node and enemy_node.has_method("take_damage"):
		enemy_node.take_damage(current_damage)
		enemy_hit.emit(enemy_node)

func get_weapon_info() -> Dictionary:
	"""Get current weapon information"""
	return {
		"name": "Bat",
		"level": level,
		"damage": current_damage,
		"attack_rate": current_attack_rate,
		"range": base_attack_range,
		"arc": attack_arc_degrees
	}
