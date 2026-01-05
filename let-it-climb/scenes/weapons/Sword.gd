extends Node2D
class_name Sword

# Sword weapon for Let it Climb - adapted from Axe but with different stats

signal attack_completed
signal enemy_hit(enemy_node)

@export var level: int = 1
@export var max_level: int = 5
@export var base_damage: float = 20.0
@export var base_attack_rate: float = 1.2  # attacks per second (faster than axe)
@export var attack_arc_degrees: float = 120.0  # wider arc than axe

var current_damage: float
var current_attack_rate: float
var attack_timer: float = 0.0
var is_attacking: bool = false
var base_attack_range: float = 130.0  # Slightly shorter range than axe
var sword_reach_distance: float = 90.0  # Distance from pivot to sword tip during swing

# Base rotation for sprite (90 degrees counter-clockwise)
const BASE_ROTATION: float = -1.5708

# Sprite references for different levels
var sword_sprites: Array[Texture2D] = []
var sword_sprite_node: Sprite2D

# Collision detection for sword hits
var sword_area: Area2D
var hit_targets: Array = []  # Track what we've already hit this attack

func _ready():
	# Load all sword sprites (levels 1-5)
	for i in range(1, max_level + 1):
		var texture = load("res://assets/weapons/sword/" + str(i) + ".png")
		if texture:
			sword_sprites.append(texture)
		else:
			print("Warning: Could not load sword sprite level %d" % i)
	
	# Get references
	sword_sprite_node = get_node("SwordSprite")
	sword_area = %SwordArea
	
	# Configure sprite properties
	sword_sprite_node.visible = false
	sword_sprite_node.z_index = 10
	sword_sprite_node.rotation = BASE_ROTATION  # 90 degrees counter-clockwise
	sword_sprite_node.scale = Vector2(0.3, 0.3)
	
	# Connect collision detection
	if sword_area:
		sword_area.body_entered.connect(_on_sword_area_body_entered)
	
	# Initialize stats
	update_stats()
	update_sprite()

func update_stats():
	"""Update weapon stats based on level"""
	var level_multiplier = 1.0 + (level - 1) * 0.3  # 30% increase per level
	current_damage = base_damage * level_multiplier
	current_attack_rate = base_attack_rate * (1.0 + (level - 1) * 0.15)  # 15% faster per level

func update_sprite():
	"""Update sprite based on current level"""
	if sword_sprites.size() >= level and sword_sprite_node:
		sword_sprite_node.texture = sword_sprites[level - 1]

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
		current_damage = base_damage * str_multiplier * (1.0 + (level - 1) * 0.3)

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
	
	# Create a query for nearby enemies
	var query = PhysicsPointQueryParameters2D.new()
	query.position = player_position
	query.collision_mask = 2  # Enemy layer
	
	# Check in a circle around the player
	var nearby_bodies = []
	var check_radius = base_attack_range
	
	# Simple distance check for enemies
	var all_enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in all_enemies:
		if enemy and is_instance_valid(enemy):
			var distance = player_position.distance_to(enemy.global_position)
			if distance <= check_radius:
				nearby_bodies.append(enemy)
	
	return nearby_bodies.size() > 0

func start_attack(player_position: Vector2, facing_direction: Vector2):
	"""Start sword attack"""
	if is_attacking:
		return
	
	is_attacking = true
	hit_targets.clear()
	
	# Position sword at player location
	global_position = player_position
	
	# Enable collision detection
	if sword_area:
		sword_area.monitoring = true
	
	# Show and animate sword
	if sword_sprite_node:
		sword_sprite_node.visible = true
		animate_sword_swing(facing_direction)
	
	# Attack duration
	var attack_duration = 0.3  # 300ms attack animation
	await get_tree().create_timer(attack_duration).timeout
	
	# End attack
	end_attack()

func animate_sword_swing(facing_direction: Vector2):
	"""Animate the sword swing"""
	if not sword_sprite_node:
		return
	
	# Calculate swing positions
	var start_angle = facing_direction.angle() - deg_to_rad(attack_arc_degrees / 2)
	var end_angle = facing_direction.angle() + deg_to_rad(attack_arc_degrees / 2)
	
	# Position sword at start of swing
	var start_pos = Vector2(cos(start_angle), sin(start_angle)) * sword_reach_distance
	sword_sprite_node.position = start_pos
	sword_sprite_node.rotation = start_angle + deg_to_rad(90) + BASE_ROTATION  # Sword points outward + base rotation
	
	# Create tween for swing animation
	var tween = create_tween()
	tween.set_parallel(true)
	
	# Animate position
	var end_pos = Vector2(cos(end_angle), sin(end_angle)) * sword_reach_distance
	tween.tween_property(sword_sprite_node, "position", end_pos, 0.3)
	
	# Animate rotation
	tween.tween_property(sword_sprite_node, "rotation", end_angle + deg_to_rad(90) + BASE_ROTATION, 0.3)

func end_attack():
	"""End the sword attack"""
	is_attacking = false
	
	# Hide sword
	if sword_sprite_node:
		sword_sprite_node.visible = false
	
	# Disable collision detection
	if sword_area:
		sword_area.monitoring = false
	
	# Reset position
	if sword_sprite_node:
		sword_sprite_node.position = Vector2.ZERO
		sword_sprite_node.rotation = BASE_ROTATION  # Reset to base rotation
	
	# Clear hit targets
	hit_targets.clear()
	
	# Emit completion signal
	attack_completed.emit()

func _on_sword_area_body_entered(body):
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
		"name": "Sword",
		"level": level,
		"damage": current_damage,
		"attack_rate": current_attack_rate,
		"range": base_attack_range,
		"arc": attack_arc_degrees
	}
