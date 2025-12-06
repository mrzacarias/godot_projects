extends Area2D

signal hit

@export var speed = 400.0
@export var lerp_speed = 3.0  # Speed of interpolation for smooth movement (reduced for slower movement)
@export var touch_speed_multiplier = 0.6  # Multiplier for touch/mouse movement speed

var target_position = Vector2.ZERO
var is_touch_control = false
var is_dragging = false
var screen_size = Vector2.ZERO
var world_size = Vector2(1920, 1080)  # Define world boundaries larger than viewport

func _ready():
	screen_size = get_viewport_rect().size
	target_position = position
	hide()

func do_animation(direction):
	if direction.length() > 0:
		direction = direction.normalized()
		$AnimatedSprite2D.play()
	else:
		$AnimatedSprite2D.stop()
	
	if direction.x != 0:
		$AnimatedSprite2D.animation = "right"
		$AnimatedSprite2D.flip_v = false
		$AnimatedSprite2D.flip_h = direction.x < 0
	elif direction.y != 0:
		$AnimatedSprite2D.animation = "up"
		$AnimatedSprite2D.flip_v = direction.y > 0
	
	return direction

func _process(delta):
	var direction = Vector2.ZERO
	
	# Handle keyboard input (existing functionality)
	var keyboard_input = Input.get_vector("move_left","move_right","move_up", "move_down")
	if keyboard_input != Vector2.ZERO:
		direction = keyboard_input
		is_touch_control = false
		target_position = position
		direction = do_animation(direction)
		position += direction * speed * delta
	elif is_touch_control:
		# Use interpolated movement for touch/mouse controls
		var distance_to_target = position.distance_to(target_position)
		if distance_to_target > 15.0:  # Only move if we're not close enough
			direction = (target_position - position).normalized()
			
			# Calculate movement speed based on distance (closer = slower)
			var distance_factor = min(distance_to_target / 200.0, 1.0)  # Normalize distance
			var adjusted_lerp_speed = lerp_speed * touch_speed_multiplier * distance_factor
			
			# Use lerp for smooth movement towards target
			var lerp_factor = min(adjusted_lerp_speed * delta, 0.8)  # Cap max lerp factor
			position = position.lerp(target_position, lerp_factor)
			
			# Handle animation
			do_animation(direction)
		else:
			do_animation(Vector2.ZERO)
	else:
		do_animation(Vector2.ZERO)
	
	# Clamp position to screen bounds
	position.x = clamp(position.x, 0, screen_size.x)
	position.y = clamp(position.y, 0, screen_size.y)
	target_position.x = clamp(target_position.x, 0, screen_size.x)
	target_position.y = clamp(target_position.y, 0, screen_size.y)

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
			target_position = event.position
		else:
			# Stop touch dragging
			is_dragging = false
	
	# Handle touch drag motion
	elif event is InputEventScreenDrag:
		if is_dragging:
			target_position = event.position
			is_touch_control = true

func start(new_position):
	position = new_position
	target_position = new_position
	is_touch_control = false
	is_dragging = false
	show()
	$CollisionShape2D.disabled = false

func reset_position(new_position: Vector2):
	position = new_position
	target_position = new_position
	is_touch_control = false
	is_dragging = false

func _on_body_entered(_body: Node2D) -> void:
	hide()
	$CollisionShape2D.set_deferred("disabled", true)
	emit_signal("hit")
