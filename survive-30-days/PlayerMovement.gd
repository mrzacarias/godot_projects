class_name PlayerMovement

# Movement strategy classes for cleaner player movement logic

# Base movement strategy
class MovementStrategy:
	func calculate_movement(_player: CharacterBody2D, _delta: float) -> Vector2:
		return Vector2.ZERO
	
	func get_priority() -> int:
		return 0  # Lower number = higher priority

# Knockback movement (highest priority)
class KnockbackMovement extends MovementStrategy:
	func calculate_movement(player: CharacterBody2D, delta: float) -> Vector2:
		if not player.is_knocked_back:
			return Vector2.ZERO
		
		# Apply knockback velocity with much faster decay (90% faster recovery)
		player.knockback_velocity = player.knockback_velocity.lerp(Vector2.ZERO, delta * 50.0)
		
		# Stop knockback when velocity is very small
		if player.knockback_velocity.length() < 10.0:
			player.is_knocked_back = false
			player.knockback_velocity = Vector2.ZERO
		
		return player.knockback_velocity
	
	func get_priority() -> int:
		return 1

# Keyboard movement (medium priority)
class KeyboardMovement extends MovementStrategy:
	func calculate_movement(player: CharacterBody2D, _delta: float) -> Vector2:
		var keyboard_input = Input.get_vector("move_left", "move_right", "move_up", "move_down")
		
		if keyboard_input != Vector2.ZERO:
			# Switch to keyboard control
			player.is_touch_control = false
			player.target_position = player.global_position
			
			# Return keyboard-based velocity
			return keyboard_input * player.speed * player.speed_mult
		
		return Vector2.ZERO
	
	func get_priority() -> int:
		return 2

# Touch/Mouse movement (lowest priority)
class TouchMovement extends MovementStrategy:
	func calculate_movement(player: CharacterBody2D, _delta: float) -> Vector2:
		if not player.is_touch_control:
			return Vector2.ZERO
		
		var distance_to_target = player.global_position.distance_to(player.target_position)
		
		# Only move if we're not close enough to target
		if distance_to_target > 15.0:  # GameConstants.TOUCH_MOVEMENT_THRESHOLD
			var direction = (player.target_position - player.global_position).normalized()
			
			# Calculate movement speed based on distance (closer = slower)
			var distance_factor = min(distance_to_target / 200.0, 1.0)
			var adjusted_speed = player.speed * player.speed_mult * player.touch_speed_multiplier * distance_factor
			
			return direction * adjusted_speed
		
		return Vector2.ZERO
	
	func get_priority() -> int:
		return 3

# Movement manager that handles all movement strategies
class MovementManager:
	var strategies: Array[MovementStrategy] = []
	var cached_camera_bounds: Rect2
	var camera_bounds_cache_timer: float = 0.0
	var camera_bounds_cache_duration: float = 0.1  # Cache for 100ms
	
	func _init():
		# Initialize movement strategies in priority order
		strategies.append(KnockbackMovement.new())
		strategies.append(KeyboardMovement.new())
		strategies.append(TouchMovement.new())
		
		# Sort by priority (lower number = higher priority)
		strategies.sort_custom(func(a, b): return a.get_priority() < b.get_priority())
	
	func process_movement(player: CharacterBody2D, delta: float) -> Vector2:
		"""Process all movement strategies and return the final velocity"""
		if player.is_dying:
			return Vector2.ZERO
		
		# Try each movement strategy in priority order
		for strategy in strategies:
			var movement = strategy.calculate_movement(player, delta)
			if movement != Vector2.ZERO:
				return movement
		
		# No movement strategy produced movement
		return Vector2.ZERO
	
	func apply_movement_and_constraints(player: CharacterBody2D, velocity: Vector2, delta: float):
		"""Apply movement and handle position constraints"""
		# Set velocity and move
		player.velocity = velocity
		player.move_and_slide()
		
		# Apply position constraints
		apply_camera_bounds_constraint(player, delta)
		
		# Update sprite and animations
		update_player_visuals(player, velocity)
	
	func apply_camera_bounds_constraint(player: CharacterBody2D, delta: float):
		"""Clamp player position to camera bounds with caching"""
		# Update camera bounds cache if needed
		camera_bounds_cache_timer += delta
		if camera_bounds_cache_timer >= camera_bounds_cache_duration or cached_camera_bounds == Rect2():
			if player.has_method("get_camera_bounds"):
				cached_camera_bounds = player.get_camera_bounds()
			else:
				# Fallback to world bounds if camera bounds not available
				cached_camera_bounds = Rect2(Vector2.ZERO, Vector2(4320, 2880))
			camera_bounds_cache_timer = 0.0
		
		# Clamp player position
		player.global_position.x = clamp(player.global_position.x, cached_camera_bounds.position.x, cached_camera_bounds.end.x)
		player.global_position.y = clamp(player.global_position.y, cached_camera_bounds.position.y, cached_camera_bounds.end.y)
		
		# Also clamp target position for touch controls
		if player.is_touch_control:
			player.target_position.x = clamp(player.target_position.x, cached_camera_bounds.position.x, cached_camera_bounds.end.x)
			player.target_position.y = clamp(player.target_position.y, cached_camera_bounds.position.y, cached_camera_bounds.end.y)
	
	func update_player_visuals(player: CharacterBody2D, velocity: Vector2):
		"""Update player sprite flipping and animations"""
		if not player.player_character or player.is_dying:
			return  # Don't update visuals if player is dying
		
		var direction = velocity.normalized()
		
		# Handle sprite flipping based on movement direction
		if direction.x > 0:
			player.player_character.scale.x = abs(player.player_character.scale.x)
			player.last_movement_direction = Vector2.RIGHT
		elif direction.x < 0:
			player.player_character.scale.x = -abs(player.player_character.scale.x)
			player.last_movement_direction = Vector2.LEFT
		elif direction.y > 0:
			player.last_movement_direction = Vector2.DOWN
		elif direction.y < 0:
			player.last_movement_direction = Vector2.UP
		
		# Handle animations
		if velocity.length() > 0.0:
			player.player_character.play_walk_animation()
		else:
			player.player_character.play_idle_animation()
