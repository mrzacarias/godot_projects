extends Node2D
class_name Axe

# Axe weapon for Let it Climb - adapted from survive-30-days but only damages enemies

signal attack_completed
signal enemy_hit(enemy_node)

@export var level: int = 1
@export var max_level: int = 5
@export var base_damage: float = 25.0
@export var base_attack_rate: float = 1.0  # attacks per second
@export var attack_arc_degrees: float = 90.0

var current_damage: float
var current_attack_rate: float
var attack_timer: float = 0.0
var is_attacking: bool = false
var base_attack_range: float = 150.0  # Base range from player center
var axe_reach_distance: float = 100.0  # Distance from pivot to axe head during swing

# Sprite references for different levels
var axe_sprites: Array[Texture2D] = []
var axe_sprite_node: Sprite2D

# Collision detection for axe hits
var axe_area: Area2D
var hit_targets: Array = []  # Track what we've already hit this attack

func _ready():
	# Load all axe sprites (levels 1-5)
	for i in range(1, max_level + 1):
		var texture = load("res://assets/weapons/axe/" + str(i) + ".png")
		if texture:
			axe_sprites.append(texture)
		else:
			print("Warning: Could not load axe sprite level %d" % i)
	
	# Get references
	axe_sprite_node = get_node("AxeSprite")
	axe_area = %AxeArea
	
	# Configure sprite properties
	axe_sprite_node.visible = false
	axe_sprite_node.z_index = 10
	axe_sprite_node.rotation = -1.5708  # 90 degrees counter-clockwise
	axe_sprite_node.scale = Vector2(0.3, 0.3)
	
	# Connect collision detection
	if axe_area:
		axe_area.body_entered.connect(_on_axe_area_body_entered)
	
	# Initialize stats
	update_stats()

func _process(delta):
	if is_attacking:
		attack_timer += delta
		
		# Update axe position and rotation during attack
		update_attack_animation(delta)
		
		# Check if attack is complete
		if attack_timer >= get_attack_duration():
			call_deferred("complete_attack")

func update_stats():
	"""Update damage and attack rate based on current level"""
	current_damage = base_damage * level
	# Attack rate decreases by 0.2 each level (faster attacks)
	current_attack_rate = base_attack_rate - ((level - 1) * 0.2)
	current_attack_rate = max(current_attack_rate, 0.2)  # Minimum 0.2 seconds between attacks
	
	# Update sprite to match level
	if level <= axe_sprites.size() and axe_sprites[level - 1]:
		axe_sprite_node.texture = axe_sprites[level - 1]
		# Set pivot point for sweeping motion
		if axe_sprite_node.texture:
			var texture_size = axe_sprite_node.texture.get_size()
			axe_sprite_node.offset.x = texture_size.x * 1.0  # Move pivot for sweeping rotation
			axe_sprite_node.offset.y = 0

func level_up():
	"""Increase axe level if possible"""
	if level < max_level:
		level += 1
		update_stats()
		print("Axe leveled up to %d" % level)
		return true
	return false

func can_attack() -> bool:
	"""Check if axe can perform an attack"""
	return not is_attacking

func get_effective_attack_range() -> float:
	"""Calculate the effective attack range based on axe swing reach"""
	var full_range = base_attack_range + axe_reach_distance + 80.0
	return full_range * 0.6  # Reduce by 40% for balance

func has_targets_nearby(player_position: Vector2) -> bool:
	"""Check if there are enemies within attack range"""
	var space_state = get_world_2d().direct_space_state
	if not space_state:
		return false
		
	var query = PhysicsShapeQueryParameters2D.new()
	
	# Create a circle shape for attack range
	var circle_shape = CircleShape2D.new()
	circle_shape.radius = get_effective_attack_range()
	query.shape = circle_shape
	query.transform.origin = player_position
	query.collision_mask = 0xFFFFFFFF  # Check all collision layers
	
	# Query for collisions
	var results = space_state.intersect_shape(query)
	
	for result in results:
		var body = result["collider"]
		
		# Check if it's an enemy (has take_damage method and is not the player)
		if body.has_method("take_damage") and not body.name == "Player":
			return true
	
	return false

func start_attack(player_position: Vector2, player_facing_direction: Vector2):
	"""Start an axe attack from the player's position"""
	if not can_attack():
		return
	
	# Only attack if there are targets nearby
	if not has_targets_nearby(player_position):
		return
	
	is_attacking = true
	attack_timer = 0.0
	
	# Position axe with offset from player center
	var axe_pos_offset = Vector2(0, -30)  # Move axe 30px up from player center
	global_position = player_position + axe_pos_offset
	
	# Show axe sprite and enable collision detection
	axe_sprite_node.visible = true
	if axe_area:
		axe_area.monitoring = true
	
	# Clear hit targets for this new attack
	hit_targets.clear()
	
	# Check if this is a 360-degree attack (levels 4 and 5)
	var is_360_attack = (level >= 4)
	
	if is_360_attack:
		# 360-degree attack: full circle
		var base_angle = player_facing_direction.angle()
		var start_angle = base_angle
		var end_angle = start_angle + deg_to_rad(360.0)
		
		# Store angles for animation
		axe_sprite_node.rotation = start_angle - 1.5708  # Account for base rotation
		axe_sprite_node.set_meta("start_angle", start_angle)
		axe_sprite_node.set_meta("end_angle", end_angle)
		axe_sprite_node.set_meta("is_360_attack", true)
	else:
		# Regular arc attack: 90 degree arc in facing direction
		var base_angle = player_facing_direction.angle()
		var half_arc = deg_to_rad(attack_arc_degrees / 2.0)
		var start_angle = base_angle - half_arc
		var end_angle = base_angle + half_arc
		
		# Store angles for animation
		axe_sprite_node.rotation = start_angle - 1.5708  # Account for base rotation
		axe_sprite_node.set_meta("start_angle", start_angle)
		axe_sprite_node.set_meta("end_angle", end_angle)
		axe_sprite_node.set_meta("is_360_attack", false)

func update_attack_animation(_delta: float):
	"""Update axe position and rotation during attack"""
	var progress = attack_timer / get_attack_duration()
	progress = min(progress, 1.0)
	
	# Get stored angles
	var start_angle = axe_sprite_node.get_meta("start_angle", 0.0)
	var end_angle = axe_sprite_node.get_meta("end_angle", 0.0)
	
	# Interpolate rotation
	var current_angle = lerp_angle(start_angle, end_angle, progress)
	axe_sprite_node.rotation = current_angle - 1.5708  # Account for base rotation

func _on_axe_area_body_entered(body):
	"""Called when axe collides with something during attack"""
	if not is_attacking:
		return
	
	# Ignore the player itself
	if body.name == "Player":
		return
	
	# Avoid hitting the same target multiple times in one attack
	if body in hit_targets:
		return
	
	# Use survive-30-days logic: check for enemies by take_damage method and exclude player
	if body.has_method("take_damage") and not body.name == "Player":
		hit_enemy(body)
		hit_targets.append(body)

func hit_enemy(enemy_node):
	"""Handle hitting an enemy"""
	print("Axe hit enemy: %s for %d damage" % [enemy_node.name, current_damage])
	
	# Send damage signal to enemy (using survive-30-days signature)
	if enemy_node.has_method("take_damage"):
		enemy_node.take_damage(current_damage)
	
	enemy_hit.emit(enemy_node)

func complete_attack():
	"""Complete the current attack"""
	is_attacking = false
	attack_timer = 0.0
	
	# Clear hit targets for next attack
	hit_targets.clear()
	
	# Hide axe sprite and disable collision
	axe_sprite_node.visible = false
	axe_sprite_node.position = Vector2.ZERO
	axe_sprite_node.rotation = -1.5708  # Reset to base rotation
	if axe_area:
		axe_area.monitoring = false
	
	attack_completed.emit()

func get_attack_duration() -> float:
	"""Get the duration of an attack animation"""
	var is_360_attack = axe_sprite_node.get_meta("is_360_attack", false)
	return 0.8 if is_360_attack else 0.4  # 360 attacks take longer

func get_attack_cooldown() -> float:
	"""Get the cooldown between attacks based on current attack rate"""
	return current_attack_rate

func get_damage() -> float:
	"""Get current damage value"""
	return current_damage

func get_level() -> int:
	"""Get current level"""
	return level
