extends CharacterBody2D

signal health_depleted
signal experience_gained(amount: int)

@export var speed: float = 600.0
@export var health: float = 100.0
@export var max_health: float = 100.0
@export var lerp_speed: float = 3.0  # Speed of interpolation for smooth movement
@export var touch_speed_multiplier: float = 0.6  # Multiplier for touch/mouse movement speed
@export var speed_mult: float = 1.0

# Weapon system (currently sword, but keeping 'axe' variable name for compatibility)
var axe: Node2D
var axe_attack_timer: float = 0.0
var last_movement_direction: Vector2 = Vector2.RIGHT

# Death system
var is_dead: bool = false

# Damage system
var damage_cooldown_timer: float = 0.0
var damage_cooldown_duration: float = 1.0  # Cooldown between damage
var knockback_strength: float = 800.0
var knockback_duration: float = 0.3
var is_knocked_back: bool = false
var knockback_velocity: Vector2 = Vector2.ZERO

# Touch/Mouse movement
var target_position = Vector2.ZERO
var is_touch_control = false
var is_dragging = false

# Debug variables
var debug_touch_movement = false
var world_size = Vector2(2880, 1920)  # Tower floor size
var camera: Camera2D

# Cached node references
@onready var health_bar = %HealthBar
@onready var player_character = %PlayerCharacter
@onready var hurt_box = %HurtBox

# Movement system
var movement_manager

func _ready():
	# Initialize health
	health = max_health
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = health
	
	# Set up camera reference and limits
	if has_node("Camera2D"):
		camera = $Camera2D
		setup_camera_limits()
	
	# Initialize movement system
	movement_manager = PlayerMovement.MovementManager.new()
	
	# Initialize sword system
	if has_node("Sword"):
		axe = $Sword  # Keep variable name for compatibility
		if axe:
			if axe.has_signal("enemy_hit"):
				axe.enemy_hit.connect(_on_weapon_enemy_hit)
			print("Sword system initialized")
	
	# Connect hurt box for taking damage
	if hurt_box:
		hurt_box.body_entered.connect(_on_hurt_box_body_entered)
		hurt_box.area_entered.connect(_on_hurt_box_area_entered)
	
	# Initialize position
	target_position = global_position
	
	print("Player initialized with health: ", health)

func _physics_process(delta: float) -> void:
	# Don't process anything if dead
	if is_dead:
		return
	
	# Update damage cooldown
	if damage_cooldown_timer > 0:
		damage_cooldown_timer -= delta
	
	# Process movement using the movement manager
	if movement_manager:
		var calculated_velocity = movement_manager.process_movement(self, delta)
		movement_manager.apply_movement_and_constraints(self, calculated_velocity, delta)
	else:
		# Fallback to basic movement if manager failed to initialize
		handle_basic_movement(delta)
	
	# Handle weapon attacks (using survive-30-days logic)
	if axe:
		# Check if there are targets nearby first
		var has_targets = axe.has_targets_nearby(global_position)
		
		# Update attack timer (increment, not decrement)
		axe_attack_timer += delta
		
		# Only attack if there are targets nearby and cooldown is finished
		if has_targets and axe_attack_timer >= axe.get_attack_cooldown() and axe.can_attack():
			# Start attack in the direction the player is facing
			axe.start_attack(global_position, last_movement_direction)
			axe_attack_timer = 0.0
	
	# Handle damage detection
	handle_damage_detection()

func _input(event):
	# Debug toggle (press F1 to toggle touch movement debug)
	if event is InputEventKey and event.pressed and event.keycode == KEY_F1:
		debug_touch_movement = !debug_touch_movement
		print("Touch movement debug: ", debug_touch_movement)
		queue_redraw()
	
	# Handle mouse events
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				# Check if the click is on an interactable object before setting movement target
				var mouse_world_pos = screen_to_world_position(event.position)
				if not is_clicking_on_interactable(mouse_world_pos):
					# Start dragging - use screen_to_world_position for consistency with touch
					is_dragging = true
					is_touch_control = true
					target_position = mouse_world_pos
					if debug_touch_movement:
						queue_redraw()
			else:
				# Stop dragging
				is_dragging = false
	
	# Handle mouse motion for dragging
	elif event is InputEventMouseMotion and is_dragging:
		# Use screen_to_world_position for consistency with touch input
		target_position = screen_to_world_position(event.position)
		is_touch_control = true
		if debug_touch_movement:
			queue_redraw()
	
	# Handle touch events
	elif event is InputEventScreenTouch:
		if event.pressed:
			# Start touch dragging
			is_dragging = true
			is_touch_control = true
			target_position = screen_to_world_position(event.position)
			if debug_touch_movement:
				queue_redraw()
		else:
			# Stop touch dragging
			is_dragging = false
	
	# Handle touch drag motion
	elif event is InputEventScreenDrag:
		if is_dragging:
			target_position = screen_to_world_position(event.position)
			is_touch_control = true
			if debug_touch_movement:
				queue_redraw()

func handle_basic_movement(delta: float):
	"""Fallback movement system if movement manager fails"""
	var input_dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	
	if input_dir != Vector2.ZERO:
		is_touch_control = false
		target_position = global_position
		velocity = input_dir * speed * speed_mult
		last_movement_direction = input_dir.normalized()
	elif is_touch_control:
		# Touch/mouse movement
		var distance_to_target = global_position.distance_to(target_position)
		if distance_to_target > 15.0:
			var direction = (target_position - global_position).normalized()
			var distance_factor = min(distance_to_target / 200.0, 1.0)
			velocity = direction * speed * touch_speed_multiplier * distance_factor * speed_mult
		else:
			velocity = Vector2.ZERO
	else:
		velocity = Vector2.ZERO
	
	move_and_slide()
	apply_camera_bounds_constraint()

func handle_damage_detection():
	"""Handle damage from overlapping enemies"""
	if not hurt_box or damage_cooldown_timer > 0 or is_dead:
		return
	
	var overlapping_bodies = hurt_box.get_overlapping_bodies()
	if overlapping_bodies.size() > 0:
		var total_damage = 0
		var attacker_position = Vector2.ZERO
		
		for body in overlapping_bodies:
			# Only damage from enemies
			if body.is_in_group("enemies") and body.has_method("get_damage"):
				total_damage += body.get_damage()
				attacker_position = body.global_position
		
		if total_damage > 0:
			take_damage(total_damage, attacker_position)

func take_damage(damage_amount: float, attacker_position: Vector2 = Vector2.ZERO):
	"""Take damage and handle knockback"""
	# Check if already dead or damage cooldown
	if is_dead or damage_cooldown_timer > 0:
		return
	
	health -= damage_amount
	damage_cooldown_timer = damage_cooldown_duration
	
	# Update health bar
	if health_bar:
		health_bar.value = health
	
	# Apply knockback
	if attacker_position != Vector2.ZERO:
		apply_knockback(attacker_position)
	
	# Visual feedback
	show_damage_feedback()
	
	# Check for death
	if health <= 0:
		die()

func apply_knockback(attacker_position: Vector2):
	"""Apply knockback effect"""
	var knockback_direction = (global_position - attacker_position).normalized()
	knockback_velocity = knockback_direction * knockback_strength
	is_knocked_back = true
	
	# Stop touch control during knockback
	is_touch_control = false
	is_dragging = false

func show_damage_feedback():
	"""Show visual feedback when taking damage"""
	if player_character:
		var original_modulate = player_character.modulate
		player_character.modulate = Color(1.5, 0.5, 0.5, 1.0)  # Red tint
		
		# Return to normal after brief delay
		await get_tree().create_timer(0.15).timeout
		if is_instance_valid(player_character):
			player_character.modulate = original_modulate

func die():
	"""Handle player death"""
	# Prevent multiple death calls
	if is_dead:
		return
		
	is_dead = true
	print("Player died!")
	
	# Disable hurt box to prevent further damage
	if hurt_box:
		hurt_box.set_deferred("monitoring", false)
	
	# Play death animation
	if player_character and player_character.has_method("play_dead_animation"):
		player_character.play_dead_animation()
	
	# Emit death signal
	health_depleted.emit()

func set_world_size(size: Vector2):
	"""Set world size for bounds checking"""
	world_size = size
	setup_camera_limits()
	print("Player world size set to: ", world_size)

func setup_camera_limits():
	"""Set up camera limits to bound camera movement to world size"""
	if camera and world_size != Vector2.ZERO:
		camera.limit_left = 0
		camera.limit_top = 0
		camera.limit_right = int(world_size.x)
		camera.limit_bottom = int(world_size.y)

func reset_for_new_run():
	"""Reset player state for a new tower run"""
	is_dead = false
	health = max_health
	damage_cooldown_timer = 0.0
	is_knocked_back = false
	knockback_velocity = Vector2.ZERO
	
	# Re-enable hurt box
	if hurt_box:
		hurt_box.monitoring = true
	
	# Update health bar
	if health_bar:
		health_bar.value = health
	
	print("Player reset for new run - Health: ", health)

func reset_position(new_position: Vector2):
	"""Reset player position (used when advancing floors)"""
	global_position = new_position
	target_position = new_position
	velocity = Vector2.ZERO
	is_touch_control = false
	is_dragging = false

func heal_to_full():
	"""Heal player to full health"""
	health = max_health
	if health_bar:
		health_bar.value = health

func get_camera_bounds() -> Rect2:
	"""Get the current bounds of what the camera can see"""
	if not camera:
		return Rect2(Vector2.ZERO, world_size)
	
	# Get camera's current position and viewport size
	var camera_pos = camera.global_position
	var viewport_size = get_viewport_rect().size
	
	# Calculate the visible area bounds
	var half_viewport = viewport_size / 2
	var min_pos = Vector2(
		max(0, camera_pos.x - half_viewport.x),
		max(0, camera_pos.y - half_viewport.y)
	)
	var max_pos = Vector2(
		min(world_size.x, camera_pos.x + half_viewport.x),
		min(world_size.y, camera_pos.y + half_viewport.y)
	)
	
	return Rect2(min_pos, max_pos - min_pos)

func apply_camera_bounds_constraint():
	"""Clamp player position to camera bounds to prevent walking beyond map"""
	var camera_bounds = get_camera_bounds()
	
	# Clamp player position to camera bounds
	global_position.x = clamp(global_position.x, camera_bounds.position.x, camera_bounds.end.x)
	global_position.y = clamp(global_position.y, camera_bounds.position.y, camera_bounds.end.y)
	
	# Also clamp target position for touch controls
	if is_touch_control:
		target_position.x = clamp(target_position.x, camera_bounds.position.x, camera_bounds.end.x)
		target_position.y = clamp(target_position.y, camera_bounds.position.y, camera_bounds.end.y)

func screen_to_world_position(screen_pos: Vector2) -> Vector2:
	"""Convert screen coordinates to world coordinates"""
	if not camera:
		return screen_pos
	
	# Use the camera's get_screen_center_position() to get the actual center of what's being displayed
	var camera_center = camera.get_screen_center_position()
	var viewport_size = get_viewport_rect().size
	var screen_center = viewport_size / 2
	
	# Calculate offset from screen center
	var offset_from_center = screen_pos - screen_center
	
	# Convert to world coordinates
	return camera_center + offset_from_center

func is_clicking_on_interactable(click_pos: Vector2) -> bool:
	"""Check if the click position is on an interactable object"""
	# Check chests
	var chests = get_tree().get_nodes_in_group("chests")
	for chest in chests:
		if chest.has_method("open_chest"):
			# Check if player is within interaction range AND click is on chest area
			var player_distance = global_position.distance_to(chest.global_position)
			if player_distance <= 240.0:  # Player must be in interaction range
				# Check if click is within chest's interaction area
				var chest_rect = Rect2(chest.global_position - Vector2(45, 30), Vector2(90, 60))
				if chest_rect.has_point(click_pos):
					return true
	
	return false

func _draw():
	"""Debug drawing for touch movement"""
	if debug_touch_movement and is_touch_control:
		# Draw target position
		var target_local = to_local(target_position)
		draw_circle(target_local, 8.0, Color.WHITE)

# Signal handlers
func _on_hurt_box_body_entered(body):
	"""Handle body entering hurt box"""
	# Damage detection is handled in handle_damage_detection()
	pass

func _on_hurt_box_area_entered(area):
	"""Handle area entering hurt box"""
	# Handle area-based damage if needed
	pass

func _on_weapon_enemy_hit(enemy_node):
	"""Handle weapon hitting an enemy"""
	# Award experience when enemy is hit
	var exp_reward = 10  # Base experience
	experience_gained.emit(exp_reward)

# Equipment functions (for future use)
func equip_weapon(weapon_node: Node2D):
	"""Equip a weapon"""
	axe = weapon_node

func gain_experience(amount: int):
	"""Gain experience points"""
	experience_gained.emit(amount)
