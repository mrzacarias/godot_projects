extends CharacterBody2D

signal health_depleted

@export var speed = 600.0
@export var health = 100.0
@export var max_health = 100.0
@export var lerp_speed = 3.0  # Speed of interpolation for smooth movement (reduced for slower movement)
@export var touch_speed_multiplier = 0.6  # Multiplier for touch/mouse movement speed

@export var speed_mult = 1.0

var target_position = Vector2.ZERO
var is_touch_control = false
var is_dragging = false
var screen_size = Vector2.ZERO
var world_size = Vector2(2880, 1920)  # Define world boundaries larger than viewport (20% increase)
var camera: Camera2D

func _ready():
	health = max_health
	%ProgressBar.max_value = max_health
	%ProgressBar.value = health
	screen_size = get_viewport_rect().size
	target_position = global_position
	
	# Set up camera reference and limits
	camera = $Camera2D
	setup_camera_limits()

func _physics_process(delta: float) -> void:
	var direction = Vector2.ZERO
	
	# Handle keyboard input (existing functionality)
	var keyboard_input = Input.get_vector("move_left","move_right","move_up", "move_down")
	if keyboard_input != Vector2.ZERO:
		direction = keyboard_input
		is_touch_control = false
		target_position = global_position
		velocity = direction * speed * speed_mult
	elif is_touch_control:
		# Use interpolated movement for touch/mouse controls
		var distance_to_target = global_position.distance_to(target_position)
		if distance_to_target > 15.0:  # Only move if we're not close enough
			direction = (target_position - global_position).normalized()
			
			# Calculate movement speed based on distance (closer = slower)
			var distance_factor = min(distance_to_target / 200.0, 1.0)  # Normalize distance
			var adjusted_lerp_speed = lerp_speed * touch_speed_multiplier * distance_factor
			
			# Use lerp for smooth movement towards target
			var lerp_factor = min(adjusted_lerp_speed * delta, 0.8)  # Cap max lerp factor
			global_position = global_position.lerp(target_position, lerp_factor)
			
			# Set velocity for animation purposes (scaled down for touch)
			velocity = direction * speed * speed_mult * touch_speed_multiplier
		else:
			velocity = Vector2.ZERO
	else:
		velocity = direction * speed * speed_mult
	
	# Only call move_and_slide for keyboard input
	if not is_touch_control:
		move_and_slide()
	
	# Clamp position to camera bounds (what the camera can see)
	var camera_bounds = get_camera_bounds()
	global_position.x = clamp(global_position.x, camera_bounds.position.x, camera_bounds.end.x)
	global_position.y = clamp(global_position.y, camera_bounds.position.y, camera_bounds.end.y)
	target_position.x = clamp(target_position.x, camera_bounds.position.x, camera_bounds.end.x)
	target_position.y = clamp(target_position.y, camera_bounds.position.y, camera_bounds.end.y)
	
	# Handle sprite flipping based on movement direction
	if direction.x > 0:
		%CatCharacter.scale.x = abs(%CatCharacter.scale.x)
	elif direction.x < 0:
		%CatCharacter.scale.x = -abs(%CatCharacter.scale.x)
	
	# Handle animations
	if velocity.length() > 0.0:
		%CatCharacter.play_walk_animation()
	else:
		%CatCharacter.play_idle_animation()
	
	# Handle damage
	var overlapping_mobs = %HurtBox.get_overlapping_bodies()
	if overlapping_mobs.size() > 0:
		print("Overlapping mobs: ", overlapping_mobs.size(), " - Player moving: ", velocity.length() > 0)
		var damage = overlapping_mobs[0].damage
		health -= damage * overlapping_mobs.size() * delta
		%ProgressBar.value = health
		print("Health after damage: ", health)
		if health <= 0.0:
			health_depleted.emit()

func _input(event):
	# Handle mouse events
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				# Start dragging
				is_dragging = true
				is_touch_control = true
				target_position = get_global_mouse_position()
			else:
				# Stop dragging
				is_dragging = false
	
	# Handle mouse motion for dragging
	elif event is InputEventMouseMotion and is_dragging:
		target_position = get_global_mouse_position()
		is_touch_control = true
	
	# Handle touch events
	elif event is InputEventScreenTouch:
		if event.pressed:
			# Start touch dragging
			is_dragging = true
			is_touch_control = true
			target_position = screen_to_world_position(event.position)
		else:
			# Stop touch dragging
			is_dragging = false
	
	# Handle touch drag motion
	elif event is InputEventScreenDrag:
		if is_dragging:
			target_position = screen_to_world_position(event.position)
			is_touch_control = true

func reset_position(new_position: Vector2):
	global_position = new_position
	target_position = new_position
	is_touch_control = false
	is_dragging = false
	velocity = Vector2.ZERO
	
	# Reset health bar display
	%ProgressBar.max_value = max_health
	%ProgressBar.value = health

func setup_camera_limits():
	"""Set up camera limits to bound camera movement to world size"""
	if camera:
		camera.limit_left = 0
		camera.limit_top = 0
		camera.limit_right = world_size.x
		camera.limit_bottom = world_size.y

func get_camera_bounds() -> Rect2:
	"""Get the current bounds of what the camera can see"""
	if not camera:
		return Rect2(Vector2.ZERO, screen_size)
	
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

func screen_to_world_position(screen_pos: Vector2) -> Vector2:
	"""Convert screen coordinates to world coordinates considering camera position"""
	if not camera:
		return screen_pos
	
	# Get the camera's current position and viewport size
	var viewport_size = get_viewport_rect().size
	var camera_pos = camera.global_position
	
	# Convert screen position to world position
	# Screen center corresponds to camera position
	var screen_center = viewport_size / 2
	var offset_from_center = screen_pos - screen_center
	var world_pos = camera_pos + offset_from_center
	
	return world_pos
