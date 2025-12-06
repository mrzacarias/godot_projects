extends Node2D
class_name Axe

signal attack_completed
signal tree_hit(tree_node)
signal boulder_hit(boulder_node)
signal enemy_hit(enemy_node)

# GameText is available globally via class_name

@export var level: int = 1
@export var max_level: int = 5
@export var base_damage: float = 2.0
@export var base_attack_rate: float = 1.0  # attacks per second
@export var attack_arc_degrees: float = 45.0

var current_damage: float
var current_attack_rate: float
var attack_timer: float = 0.0
var is_attacking: bool = false
var base_attack_range: float = GameConstants.ATTACK_RANGE  # Base range from player center
var axe_reach_distance: float = 100.0  # Distance from pivot to axe head during swing

# Sprite references for different levels
var axe_sprites: Array[Texture2D] = []
var axe_sprite_node: Sprite2D

# Collision detection for axe hits
var axe_area: Area2D
var axe_collision_shape: CollisionShape2D
var axe_collision_shapes: Array[CollisionShape2D] = []  # Multiple collision shapes for better coverage
var hit_targets: Array = []  # Track what we've already hit this attack

# Audio system
var axe_swing_sound: AudioStreamPlayer
var enemy_hurt_sound: AudioStreamPlayer
var boss_damage_sound: AudioStreamPlayer
var tree_damage_sound: AudioStreamPlayer
var boulder_damage_sound: AudioStreamPlayer

func _ready():
	# Load all axe sprites (levels 1-5)
	for i in range(1, max_level + 1):
		var texture = load("res://assets/items/axe/" + str(i) + ".png")
		if texture:
			axe_sprites.append(texture)
		else:
			print(GameText.AXE_SPRITE_LOAD_WARNING % i)
	
	# Get the sprite node from the scene (if it exists) or create one
	axe_sprite_node = get_node("AxeSprite") if has_node("AxeSprite") else null
	if not axe_sprite_node:
		# Fallback: create sprite node programmatically if scene doesn't have one
		axe_sprite_node = Sprite2D.new()
		axe_sprite_node.name = "AxeSprite"
		add_child(axe_sprite_node)
	
	# Configure sprite properties
	axe_sprite_node.visible = false  # Hidden by default
	axe_sprite_node.z_index = 10  # Render above other objects
	axe_sprite_node.scale = Vector2(0.3, 0.3)  # Reduce size by 70%
	
	# Create collision detection area
	setup_collision_detection()
	
	# Setup axe sounds
	setup_axe_sounds()
	
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
		# Set pivot point further to the left - beyond the sprite edge for more sweeping motion
		if axe_sprite_node.texture:
			var texture_size = axe_sprite_node.texture.get_size()
			axe_sprite_node.offset.x = texture_size.x * 1.0  # Move pivot further left for more sweeping rotation
			axe_sprite_node.offset.y = 0  # Keep vertical center
	
	# Axe stats updated

func level_up():
	"""Increase axe level if possible"""
	if level < max_level:
		level += 1
		update_stats()
		print(GameText.AXE_LEVELED_UP % level)
		return true
	return false

func reset_to_level_one():
	"""Reset axe to level 1"""
	level = 1
	update_stats()
	print(GameText.AXE_RESET_TO_LEVEL_ONE)

func can_attack() -> bool:
	"""Check if axe can perform an attack"""
	return not is_attacking

func get_effective_attack_range() -> float:
	"""Calculate the effective attack range based on axe swing reach"""
	# The axe can reach: base range + distance from pivot to axe head + collision shape size
	# Reduced by 40% total (30% + 10% more)
	var full_range = base_attack_range + axe_reach_distance + 80.0  # 80 is half the collision shape width (160/2)
	return full_range * 0.6  # Reduce by 40% total (was 30%, now 40%)

func has_targets_nearby(player_position: Vector2) -> bool:
	"""Check if there are any trees, boulders, or enemies within attack range"""
	var space_state = get_world_2d().direct_space_state
	if not space_state:
		return false
		
	var query = PhysicsShapeQueryParameters2D.new()
	
	# Create a circle shape for detection range - use effective attack range
	var circle_shape = CircleShape2D.new()
	circle_shape.radius = get_effective_attack_range()
	query.shape = circle_shape
	query.transform.origin = player_position
	query.collision_mask = 0xFFFFFFFF  # Check all collision layers
	
	# Query for collisions
	var results = space_state.intersect_shape(query)
	
	for result in results:
		var body = result["collider"]
		
		# Check if it's a tree (but not cut) - use same logic as collision detection
		if body.get_script() and body.get_script().get_path().ends_with("tree.gd"):
			# Only target trees that aren't cut yet using the cut flag
			var is_cut = body.get("is_cut") if body.has_method("get") and "is_cut" in body else false
			if not is_cut:
				return true
		elif body.name.begins_with("Tree"):
			# Fallback name-based detection for trees
			var is_cut = body.get("is_cut") if body.has_method("get") and "is_cut" in body else false
			if not is_cut:
				return true
		# Check if it's a boulder (but not destroyed)
		elif body.get_script() and body.get_script().get_path().ends_with("boulder.gd"):
			# Only target boulders that aren't destroyed yet
			if not body.has_method("is_boulder_destroyed") or not body.is_boulder_destroyed():
				return true
		elif body.name.begins_with("Boulder"):
			# Fallback name-based detection for boulders
			if not body.has_method("is_boulder_destroyed") or not body.is_boulder_destroyed():
				return true
		elif body.has_method("take_damage") and not body.name == "Player":
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
	
	# Play axe swing sound
	if axe_swing_sound:
		axe_swing_sound.play()
	
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
		# 360-degree attack: same sweeping motion but full circle
		# Start from the same position as regular attack but continue full circle
		var base_angle = player_facing_direction.angle()
		var flashlight_cone_half_angle = deg_to_rad(45.0)
		
		# Start at bottom of flashlight cone, but rotate full 360 degrees
		var start_angle = base_angle - flashlight_cone_half_angle  # Same start as regular attack
		var end_angle = start_angle + deg_to_rad(360.0)           # Full circle from that point
		
		# Store angles for animation
		axe_sprite_node.rotation = start_angle
		axe_sprite_node.set_meta("start_angle", start_angle)
		axe_sprite_node.set_meta("end_angle", end_angle)
		axe_sprite_node.set_meta("is_360_attack", true)
	else:
		# Regular arc attack: Follow flashlight cone (90 degrees total, 45 degrees each side)
		var base_angle = player_facing_direction.angle()
		var flashlight_cone_half_angle = deg_to_rad(45.0)  # Half of 90-degree flashlight cone
		
		# Start at bottom of flashlight cone, end at top of flashlight cone
		var start_angle = base_angle - flashlight_cone_half_angle  # Bottom of cone
		var end_angle = base_angle + flashlight_cone_half_angle    # Top of cone
		
		# Store angles for animation
		axe_sprite_node.rotation = start_angle
		axe_sprite_node.set_meta("start_angle", start_angle)
		axe_sprite_node.set_meta("end_angle", end_angle)
		axe_sprite_node.set_meta("is_360_attack", false)
	
	# Note: Target detection now handled by collision system during animation

func update_attack_animation(_delta):
	"""Update axe position and rotation during attack"""
	var attack_progress = attack_timer / get_attack_duration()
	
	# Get stored angles from metadata
	var start_angle = axe_sprite_node.get_meta("start_angle", 0.0)
	var end_angle = axe_sprite_node.get_meta("end_angle", deg_to_rad(45))
	
	# Animate the axe rotation around the base of the axe (pivot point)
	var current_angle = lerp(start_angle, end_angle, attack_progress)
	axe_sprite_node.rotation = current_angle
	
	# Keep the sprite at the center of the node - rotation happens around the pivot point (base of axe)
	# The pivot is set via offset in update_stats(), so the axe rotates around its base
	axe_sprite_node.position = Vector2.ZERO
	
	# Collision detection happens automatically via signals

func setup_collision_detection():
	"""Set up collision detection for the axe"""
	# Try to get Area2D from scene first
	axe_area = axe_sprite_node.get_node("AxeArea") if axe_sprite_node.has_node("AxeArea") else null
	
	if axe_area:
		# Use existing area from scene - it should have collision shapes positioned correctly
		axe_area.collision_layer = 0
		axe_area.collision_mask = 15
		axe_area.monitoring = false
		
		# Get existing collision shape
		axe_collision_shape = axe_area.get_node("CollisionShape2D") if axe_area.has_node("CollisionShape2D") else null
	else:
		# Create simple Area2D with one collision shape
		axe_area = Area2D.new()
		axe_area.name = "AxeArea"
		axe_area.collision_layer = 0
		axe_area.collision_mask = 15
		axe_area.monitoring = false
		axe_sprite_node.add_child(axe_area)
		
		# Create single collision shape at axe blade position
		axe_collision_shape = CollisionShape2D.new()
		var rect_shape = RectangleShape2D.new()
		rect_shape.size = Vector2(80, 30)
		axe_collision_shape.shape = rect_shape
		axe_collision_shape.position = Vector2(40, 0)  # Simple position at blade
		axe_area.add_child(axe_collision_shape)
	
	# Connect collision signals
	if axe_area and not axe_area.body_entered.is_connected(_on_axe_area_body_entered):
		axe_area.body_entered.connect(_on_axe_area_body_entered)

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
	
	# Check what type of object we hit and handle accordingly
	# First check by script/class type since names might be auto-generated
	if body.get_script() and body.get_script().get_path().ends_with("tree.gd"):
		# Check if tree is already cut using the cut flag
		var is_cut = body.get("is_cut") if body.has_method("get") and "is_cut" in body else false
		if not is_cut:
			hit_tree(body)
			hit_targets.append(body)
	elif body.get_script() and body.get_script().get_path().ends_with("boulder.gd"):
		if not body.has_method("is_boulder_destroyed") or not body.is_boulder_destroyed():
			hit_boulder(body)
			hit_targets.append(body)
	# Fallback to name-based detection
	elif body.name.begins_with("Tree"):
		# Check if tree is already cut using the cut flag
		var is_cut = body.get("is_cut") if body.has_method("get") and "is_cut" in body else false
		if not is_cut:
			hit_tree(body)
			hit_targets.append(body)
	elif body.name.begins_with("Boulder") and (not body.has_method("is_boulder_destroyed") or not body.is_boulder_destroyed()):
		hit_boulder(body)
		hit_targets.append(body)
	elif body.has_method("take_damage") and not body.name == "Player":
		hit_enemy(body)
		hit_targets.append(body)

func complete_attack():
	"""Complete the current attack"""
	is_attacking = false
	attack_timer = 0.0
	
	# Clear hit targets for next attack
	hit_targets.clear()
	
	# Hide axe sprite and disable collision
	axe_sprite_node.visible = false
	axe_sprite_node.position = Vector2.ZERO
	if axe_area:
		axe_area.monitoring = false  # This should be safe now since complete_attack is called deferred
	
	attack_completed.emit()

func get_attack_duration() -> float:
	"""Get the duration of a single attack animation"""
	# 360-degree attacks take longer than regular attacks
	if level >= 4:
		return 0.6  # 600ms for 360-degree attack
	else:
		return 0.3  # 300ms for regular arc attack

func get_attack_cooldown() -> float:
	"""Get the cooldown between attacks based on current attack rate"""
	return current_attack_rate

func check_for_targets(player_position: Vector2):
	"""Check for trees, boulders, and enemies in attack range and hit them"""
	var space_state = get_world_2d().direct_space_state
	if not space_state:
		return
		
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
		
		# Check if it's a tree (but not cut)
		if body.name.begins_with("Tree"):
			# Only hit trees that aren't cut yet
			if not body.has_method("is_tree_cut") or not body.is_tree_cut():
				hit_tree(body)
		# Check if it's a boulder (but not destroyed)
		elif body.name.begins_with("Boulder"):
			# Only hit boulders that aren't destroyed yet
			if not body.has_method("is_boulder_destroyed") or not body.is_boulder_destroyed():
				hit_boulder(body)
		# Check if it's an enemy (has take_damage method)
		elif body.has_method("take_damage"):
			hit_enemy(body)

func hit_tree(tree_node):
	"""Handle hitting a tree"""
	# Axe hit tree
	
	# Play tree damage sound
	if tree_damage_sound:
		tree_damage_sound.play()
	
	# Check tree health before applying damage to see if this hit will cut it
	var tree_health_before = tree_node.current_health if tree_node.has_method("get") and "current_health" in tree_node else 0.0
	var will_be_cut = tree_health_before <= current_damage
	
	# Send damage signal to tree
	if tree_node.has_method("take_damage"):
		tree_node.take_damage(current_damage)
	
	# If this hit cut the tree, stop the attack animation
	if will_be_cut:
		# Tree was cut by this hit, stopping attack animation
		call_deferred("complete_attack")  # Use call_deferred to avoid signal blocking
		return
	
	tree_hit.emit(tree_node)

func hit_boulder(boulder_node):
	"""Handle hitting a boulder"""
	# Axe hit boulder
	
	# Play boulder damage sound
	if boulder_damage_sound:
		boulder_damage_sound.play()
	
	# Send damage signal to boulder
	if boulder_node.has_method("take_damage"):
		boulder_node.take_damage(current_damage)
	
	# Check if boulder was destroyed and stop attack if so
	if boulder_node.has_method("is_boulder_destroyed") and boulder_node.is_boulder_destroyed():
		# Boulder was destroyed, stopping attack animation
		call_deferred("complete_attack")  # Use call_deferred to avoid signal blocking
		return
	
	boulder_hit.emit(boulder_node)

func hit_enemy(enemy_node):
	"""Handle hitting an enemy"""
	# Axe hit enemy
	
	# Detect if it's a boss or regular mob and play appropriate sound
	var is_boss = false
	
	# Check by script path first (most reliable)
	if enemy_node.get_script() and enemy_node.get_script().get_path().ends_with("boss.gd"):
		is_boss = true
	# Fallback to name-based detection
	elif enemy_node.name.begins_with("Boss"):
		is_boss = true
	
	# Play appropriate sound based on enemy type
	if is_boss and boss_damage_sound:
		boss_damage_sound.play()
	elif not is_boss and enemy_hurt_sound:
		enemy_hurt_sound.play()
	
	# Send damage signal to enemy
	if enemy_node.has_method("take_damage"):
		enemy_node.take_damage(current_damage)
	
	enemy_hit.emit(enemy_node)

func get_damage() -> float:
	"""Get current damage value"""
	return current_damage

func get_level() -> int:
	"""Get current level"""
	return level

func setup_axe_sounds():
	"""Setup the axe sound effects"""
	# Setup axe swing sound
	axe_swing_sound = AudioStreamPlayer.new()
	axe_swing_sound.name = "AxeSwingSound"
	axe_swing_sound.volume_db = 0.0
	axe_swing_sound.stream = load("res://assets/sounds/axe_swing.mp3")
	add_child(axe_swing_sound)
	
	# Setup enemy hurt sound (for regular mobs)
	enemy_hurt_sound = AudioStreamPlayer.new()
	enemy_hurt_sound.name = "EnemyHurtSound"
	enemy_hurt_sound.volume_db = 0.0
	enemy_hurt_sound.stream = load("res://assets/sounds/enemy_hurt.mp3")
	add_child(enemy_hurt_sound)
	
	# Setup boss damage sound (for bosses)
	boss_damage_sound = AudioStreamPlayer.new()
	boss_damage_sound.name = "BossDamageSound"
	boss_damage_sound.volume_db = 0.0
	boss_damage_sound.stream = load("res://assets/sounds/boss_damage.mp3")
	add_child(boss_damage_sound)
	
	# Setup tree damage sound (for trees)
	tree_damage_sound = AudioStreamPlayer.new()
	tree_damage_sound.name = "TreeDamageSound"
	tree_damage_sound.volume_db = 0.0
	tree_damage_sound.stream = load("res://assets/sounds/tree_damage.mp3")
	add_child(tree_damage_sound)
	
	# Setup boulder damage sound (for boulders)
	boulder_damage_sound = AudioStreamPlayer.new()
	boulder_damage_sound.name = "BoulderDamageSound"
	boulder_damage_sound.volume_db = 0.0
	boulder_damage_sound.stream = load("res://assets/sounds/boulder_damage.mp3")
	add_child(boulder_damage_sound)
