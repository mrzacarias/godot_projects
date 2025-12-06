extends CharacterBody2D

signal health_depleted

# GameText is available globally via class_name

@export var speed = 600.0
@export var health = 100.0
@export var max_health = 100.0
@export var lerp_speed = 3.0  # Speed of interpolation for smooth movement (reduced for slower movement)
@export var touch_speed_multiplier = GameConstants.TOUCH_SPEED_MULTIPLIER  # Multiplier for touch/mouse movement speed

@export var speed_mult = 1.0

# Axe system
var axe: Axe
var axe_attack_timer: float = 0.0
var last_movement_direction: Vector2 = Vector2.RIGHT

# Flashlight visual system
var flashlight_sprite: Sprite2D

# Rock throwing system
var rock_throw_timer: float = 0.0
var rock_throw_cooldown: float = 1.5  # Cooldown between rock throws
var rock_throw_range: float = 450.0  # Fixed range for rock throwing
var rock_projectile_scene = preload("res://items/rock_projectile.tscn")

# Death system
var is_dying = false

# Damage system
var damage_cooldown_timer: float = 0.0
var damage_cooldown_duration: float = GameConstants.DAMAGE_COOLDOWN_DURATION  # Cooldown between damage
var knockback_strength: float = 800.0  # Default knockback force (fallback if attacker doesn't have one)
var knockback_duration: float = GameConstants.KNOCKBACK_DURATION  # Knockback duration
var is_knocked_back: bool = false
var knockback_velocity: Vector2 = Vector2.ZERO
var screen_shake_intensity: float = 0.0
var screen_shake_duration: float = 0.0

var target_position = Vector2.ZERO
var is_touch_control = false
var is_dragging = false

# Debug variables (set to true for testing touch movement)
var debug_touch_movement = false
var screen_size = Vector2.ZERO
var world_size = Vector2(4320, 2880)  # Define world boundaries to match game world size (50% bigger)
var camera: Camera2D

# Cached node references for performance
@onready var health_bar = %HealthBar
@onready var player_character = %PlayerCharacter
@onready var hurt_box = %HurtBox

# Movement system
var movement_manager

# Physics optimization
var physics_optimizer

# Audio system
var game_over_sound: AudioStreamPlayer
var player_damage_sound: AudioStreamPlayer

func _ready():
	health = max_health
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = health
		update_health_bar_size()
	screen_size = get_viewport_rect().size
	target_position = global_position
	
	# Setup game over sound
	setup_game_over_sound()
	
	# Setup player damage sound
	setup_player_damage_sound()
	
	# Debug: Check if player character is properly cached
	if player_character:
		# Player character cached successfully
		pass
	else:
		print("ERROR: Player character not found!")
	
	# Set up camera reference and limits
	if has_node("Camera2D"):
		camera = $Camera2D
		setup_camera_limits()
	
	# Initialize movement system
	var PlayerMovementClass = preload("res://PlayerMovement.gd")
	movement_manager = PlayerMovementClass.MovementManager.new()
	
	if not movement_manager:
		print("WARNING: Failed to initialize movement manager, using fallback movement")
	
	# Initialize physics optimizer
	var PhysicsOptimizerClass = preload("res://PhysicsOptimizer.gd")
	physics_optimizer = PhysicsOptimizerClass.get_instance()
	
	# Initialize axe
	setup_axe()
	
	# Initialize flashlight visual
	setup_flashlight_visual()

func _process(_delta: float) -> void:
	# Update cursor based on mouse position over interactables
	update_cursor_for_interactables()
	
	# Update flashlight visual
	update_flashlight_visual()

func _draw():
	# Debug: Draw touch target position
	if debug_touch_movement and is_touch_control:
		var target_local = to_local(target_position)
		draw_circle(target_local, 10.0, Color.RED)
		draw_circle(target_local, 8.0, Color.WHITE)

func _physics_process(delta: float) -> void:
	# Don't process anything if dying (except the death sequence itself handles the animation)
	if is_dying:
		return
	
	# Process movement using the movement manager
	if movement_manager:
		var calculated_velocity = movement_manager.process_movement(self, delta)
		movement_manager.apply_movement_and_constraints(self, calculated_velocity, delta)
	else:
		# Fallback to basic movement if manager failed to initialize
		handle_basic_movement(delta)
	
	# Handle axe attacks
	handle_axe_attacks(delta)
	
	# Handle rock throwing
	handle_rock_throwing(delta)
	
	# Handle damage cooldown timer
	if damage_cooldown_timer > 0:
		damage_cooldown_timer -= delta
	
	# Handle screen shake
	handle_screen_shake(delta)
	
	# Handle damage (only if not in cooldown)
	if hurt_box and damage_cooldown_timer <= 0:
		var overlapping_mobs = physics_optimizer.collision_optimizer.get_overlapping_bodies(hurt_box, "player") if physics_optimizer else hurt_box.get_overlapping_bodies()
		if overlapping_mobs.size() > 0:
			# Filter out any freed/invalid objects
			var valid_mobs = []
			for mob in overlapping_mobs:
				if is_instance_valid(mob) and mob.has_method("get") and "damage" in mob:
					valid_mobs.append(mob)
			
			if valid_mobs.size() > 0:
				var attacker = valid_mobs[0]
				var damage = attacker.damage
				
				# Apply instant damage (removed delta multiplication)
				health -= damage * valid_mobs.size()
				
				# Play player damage sound
				if player_damage_sound:
					player_damage_sound.play()
				
				# Apply knockback using attacker's knockback strength
				var attacker_knockback = attacker.knockback_strength if "knockback_strength" in attacker else knockback_strength
				apply_knockback(attacker.global_position, attacker_knockback)
				
				# Start damage cooldown
				damage_cooldown_timer = damage_cooldown_duration
				
				if health_bar:
					health_bar.value = health
				if health <= 0.0:
					start_death_sequence()

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

func reset_position(new_position: Vector2):
	global_position = new_position
	target_position = new_position
	is_touch_control = false
	is_dragging = false
	velocity = Vector2.ZERO
	is_dying = false  # Reset dying state
	
	# Reset health bar display
	if health_bar:
		health_bar.visible = true  # Make sure health bar is visible again
		health_bar.max_value = max_health
		health_bar.value = health
		update_health_bar_size()

func reset_axe():
	"""Reset the axe to level 1"""
	if axe and axe.has_method("reset_to_level_one"):
		axe.reset_to_level_one()

func apply_knockback(attacker_position: Vector2, force: float = 0.0):
	"""Apply knockback effect when taking damage"""
	# Use provided force or fallback to player's default knockback strength
	var actual_force = force if force > 0.0 else knockback_strength
	
	# Calculate knockback direction (away from attacker)
	var knockback_direction = (global_position - attacker_position).normalized()
	
	# Apply knockback velocity with some randomness for more dynamic feel
	var base_knockback = knockback_direction * actual_force
	var random_variation = Vector2(randf_range(-50, 50), randf_range(-50, 50))
	knockback_velocity = base_knockback + random_variation
	is_knocked_back = true
	
	# Add screen shake effect
	screen_shake_intensity = 8.0  # Shake intensity
	screen_shake_duration = 0.3   # Shake duration
	
	# Stop current movement
	is_touch_control = false
	is_dragging = false
	
	# Visual feedback - flash the player sprite briefly
	show_damage_visual_feedback()

func show_damage_visual_feedback():
	"""Show visual feedback when player takes damage"""
	if has_node("%PlayerCharacter"):
		var character_node = %PlayerCharacter
		var original_modulate = character_node.modulate
		
		# Flash red briefly
		character_node.modulate = Color(1.5, 0.5, 0.5, 1.0)  # Bright red tint
		
		# Return to normal color after 0.15 seconds
		await get_tree().create_timer(0.15).timeout
		if is_instance_valid(character_node):
			character_node.modulate = original_modulate

func update_cursor_for_interactables():
	"""Update cursor to hand when hovering over interactable objects"""
	var mouse_pos = get_global_mouse_position()
	
	if is_mouse_over_interactable(mouse_pos):
		Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND)
	else:
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)

func is_mouse_over_interactable(mouse_pos: Vector2) -> bool:
	"""Check if mouse is over an interactable object that the player can reach"""
	var game_node = get_parent()
	if not game_node:
		return false
	
	# Check campfires
	var campfires = game_node.find_children("", "StaticBody2D", true, false)
	for campfire in campfires:
		if campfire.has_method("try_add_fuel"):  # This identifies it as a campfire
			# Check if player is within interaction range AND mouse is over campfire area
			var player_distance = global_position.distance_to(campfire.global_position)
			if player_distance <= 200.0:  # Player must be in interaction range
				# Check if mouse is within campfire's interaction area
				var campfire_rect = Rect2(campfire.global_position - Vector2(60, 60), Vector2(120, 120))
				if campfire_rect.has_point(mouse_pos):
					return true
	
	# Check chests
	var chests = game_node.find_children("", "StaticBody2D", true, false)
	for chest in chests:
		if chest.has_method("open_chest"):  # This identifies it as a chest
			# Check if player is within interaction range AND mouse is over chest area
			var player_distance = global_position.distance_to(chest.global_position)
			if player_distance <= 240.0:  # Player must be in interaction range
				# Check if mouse is within chest's interaction area (50% bigger for touch screens)
				var chest_rect = Rect2(chest.global_position - Vector2(45, 30), Vector2(90, 60))
				if chest_rect.has_point(mouse_pos):
					return true
	
	return false

func is_clicking_on_interactable(click_pos: Vector2) -> bool:
	"""Check if the click position is on an interactable object that the player can reach"""
	var game_node = get_parent()
	if not game_node:
		return false
	
	# Check campfires
	var campfires = game_node.find_children("", "StaticBody2D", true, false)
	for campfire in campfires:
		if campfire.has_method("try_add_fuel"):  # This identifies it as a campfire
			# Check if player is within interaction range AND click is on campfire area
			var player_distance = global_position.distance_to(campfire.global_position)
			if player_distance <= 200.0:  # Player must be in interaction range
				# Check if click is within campfire's interaction area (50% bigger for touch screens)
				var campfire_rect = Rect2(campfire.global_position - Vector2(90, 90), Vector2(180, 180))
				if campfire_rect.has_point(click_pos):
					return true
	
	# Check chests
	var chests = game_node.find_children("", "StaticBody2D", true, false)
	for chest in chests:
		if chest.has_method("open_chest"):  # This identifies it as a chest
			# Check if player is within interaction range AND click is on chest area
			var player_distance = global_position.distance_to(chest.global_position)
			if player_distance <= 240.0:  # Player must be in interaction range
				# Check if click is within chest's interaction area (50% bigger for touch screens)
				var chest_rect = Rect2(chest.global_position - Vector2(45, 30), Vector2(90, 60))
				if chest_rect.has_point(click_pos):
					return true
	
	return false

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

func get_player_screen_position() -> Vector2:
	"""Get the player's current position on screen using proper camera transformation"""
	if not camera:
		return Vector2.ZERO
	
	# Use the camera's get_screen_center_position() to get the actual center of what's being displayed
	var camera_center = camera.get_screen_center_position()
	var viewport_size = get_viewport_rect().size
	var screen_center = viewport_size / 2
	
	# Calculate player's offset from the actual camera center
	var player_offset_from_camera = global_position - camera_center
	
	# Convert to screen coordinates
	var player_screen_pos = screen_center + player_offset_from_camera
	
	return player_screen_pos

func screen_to_world_position(screen_pos: Vector2) -> Vector2:
	"""Convert screen coordinates to world coordinates relative to player position"""
	if not camera:
		return screen_pos
	
	# Get the player's current screen position
	var player_screen_pos = get_player_screen_position()
	
	# Calculate the offset from the touch position to the player's screen position
	var offset_from_player = screen_pos - player_screen_pos
	
	# Convert to world position: player's world position + the screen offset
	# This ensures that clicking left of player = move left, clicking right = move right
	var world_pos = global_position + offset_from_player
	
	# Debug output (remove this later)
	if debug_touch_movement:
		print("Screen pos: ", screen_pos)
		print("Player screen pos: ", player_screen_pos)
		print("Offset from player: ", offset_from_player)
		print("Player world pos: ", global_position)
		print("Target world pos: ", world_pos)
		print("---")
	
	return world_pos

func add_starting_items():
	"""Add starting items to the player's inventory"""
	# Get the HUD node and add axe to inventory
	var hud = get_node("../HUD")
	if hud and hud.has_method("add_item_to_inventory"):
		# Get the current axe level and corresponding texture
		var current_level = axe.level if axe else 1  # Default to 1 (starting level)
		var axe_texture = load("res://assets/items/axe/" + str(current_level) + ".png")
		if axe_texture:
			hud.add_item_to_inventory(GameText.ITEM_AXE, axe_texture, current_level)

func setup_axe():
	"""Initialize the axe system"""
	# Load and instantiate the axe scene
	var axe_scene = preload("res://items/axe.tscn")
	axe = axe_scene.instantiate()
	add_child(axe)
	
	# Connect axe signals
	axe.attack_completed.connect(_on_axe_attack_completed)
	axe.tree_hit.connect(_on_axe_tree_hit)
	axe.enemy_hit.connect(_on_axe_enemy_hit)
	
	# Update inventory to match axe level (for testing with level 5)
	call_deferred("update_axe_inventory_display")

func setup_flashlight_visual():
	"""Initialize the flashlight visual system"""
	# Create flashlight sprite node
	flashlight_sprite = Sprite2D.new()
	flashlight_sprite.name = "FlashlightSprite"
	add_child(flashlight_sprite)
	
	# Load flashlight texture
	var flashlight_texture = load("res://assets/items/flashlight/flashlight.png")
	if flashlight_texture:
		flashlight_sprite.texture = flashlight_texture
	
	# Configure sprite properties
	flashlight_sprite.visible = false  # Hidden by default
	flashlight_sprite.z_index = 5  # Render above player but below axe
	flashlight_sprite.scale = Vector2(0.01, 0.01)
	
	# Set rotation offset to correct the original image rotation
	flashlight_sprite.rotation_degrees = 45.0  # Rotate 45 degrees clockwise

func handle_basic_movement(_delta: float):
	"""Fallback basic movement if movement manager fails"""
	if is_dying:
		return
	
	var direction = Vector2.ZERO
	
	# Handle keyboard input
	var keyboard_input = Input.get_vector("move_left","move_right","move_up", "move_down")
	if keyboard_input != Vector2.ZERO:
		direction = keyboard_input
		is_touch_control = false
		target_position = global_position
		velocity = direction * speed * speed_mult
	elif is_touch_control:
		var distance_to_target = global_position.distance_to(target_position)
		if distance_to_target > 15.0:
			direction = (target_position - global_position).normalized()
			var distance_factor = min(distance_to_target / 200.0, 1.0)
			var adjusted_speed = speed * speed_mult * touch_speed_multiplier * distance_factor
			velocity = direction * adjusted_speed
		else:
			velocity = Vector2.ZERO
	else:
		velocity = direction * speed * speed_mult
	
	# Move and apply constraints
	move_and_slide()
	
	# Apply camera bounds
	var camera_bounds = get_camera_bounds()
	global_position.x = clamp(global_position.x, camera_bounds.position.x, camera_bounds.end.x)
	global_position.y = clamp(global_position.y, camera_bounds.position.y, camera_bounds.end.y)
	
	if is_touch_control:
		target_position.x = clamp(target_position.x, camera_bounds.position.x, camera_bounds.end.x)
		target_position.y = clamp(target_position.y, camera_bounds.position.y, camera_bounds.end.y)
	
	# Handle animations (only if not dying)
	if player_character and not is_dying:
		if direction.x > 0:
			player_character.scale.x = abs(player_character.scale.x)
			last_movement_direction = Vector2.RIGHT
		elif direction.x < 0:
			player_character.scale.x = -abs(player_character.scale.x)
			last_movement_direction = Vector2.LEFT
		elif direction.y > 0:
			last_movement_direction = Vector2.DOWN
		elif direction.y < 0:
			last_movement_direction = Vector2.UP
		
		if velocity.length() > 0.0:
			player_character.play_walk_animation()
		else:
			player_character.play_idle_animation()

func handle_screen_shake(delta: float):
	"""Handle screen shake effects"""
	if screen_shake_duration > 0:
		screen_shake_duration -= delta
		if camera:
			var shake_offset = Vector2(
				randf_range(-screen_shake_intensity, screen_shake_intensity),
				randf_range(-screen_shake_intensity, screen_shake_intensity)
			)
			camera.offset = shake_offset
		
		if screen_shake_duration <= 0:
			screen_shake_intensity = 0.0
			if camera:
				camera.offset = Vector2.ZERO

func handle_axe_attacks(delta):
	"""Handle automatic axe attacks"""
	if not axe:
		return
	
	# Check if there are targets nearby first
	var has_targets = axe.has_targets_nearby(global_position)
	
	# Update attack timer
	axe_attack_timer += delta
	
	# Only attack if there are targets nearby and cooldown is finished
	if has_targets and axe_attack_timer >= axe.get_attack_cooldown() and axe.can_attack():
		# Start attack in the direction the player is facing
		axe.start_attack(global_position, last_movement_direction)
		axe_attack_timer = 0.0

func _on_axe_attack_completed():
	"""Called when axe attack animation completes"""
	pass  # Could add sound effects or other feedback here

func _on_axe_tree_hit(_tree_node):
	"""Called when axe hits a tree"""
	pass  # Could add sound effects or other feedback here

func _on_axe_enemy_hit(_enemy_node):
	"""Called when axe hits an enemy"""
	pass  # Could add sound effects or other feedback here

func get_axe() -> Axe:
	"""Get reference to player's axe"""
	return axe

func level_up_axe():
	"""Level up the player's axe"""
	if axe and axe.level_up():
		# Update inventory display with new level and sprite
		var hud = get_node("../HUD")
		if hud and hud.has_method("level_up_item_in_inventory"):
			hud.level_up_item_in_inventory(GameText.ITEM_AXE)
		return true
	return false

func update_axe_inventory_display():
	"""Update the axe display in inventory to match current level"""
	if not axe:
		return
		
	var hud = get_node("../HUD")
	if hud:
		var inventory = hud.get_inventory()
		if inventory and inventory.has_method("update_item_level"):
			inventory.update_item_level(GameText.ITEM_AXE, axe.level)

func sync_axe_with_inventory():
	"""Sync axe level with inventory level"""
	var hud = get_node("../HUD")
	if hud and hud.has_method("get_item_level_from_inventory") and axe:
		var inventory_level = hud.get_item_level_from_inventory(GameText.ITEM_AXE)
		if inventory_level != axe.level:
			axe.level = inventory_level
			axe.update_stats()

func heal_to_full():
	"""Heal player to full health"""
	health = max_health
	if health_bar:
		health_bar.value = health

func update_health_bar_size():
	"""Update health bar size based on max health (scales with health upgrades)"""
	if not health_bar:
		return
	
	# Base health bar width (50% of original 138px = 69px)
	var base_width = 69.0
	var base_health = 100.0  # Original health value
	
	# Calculate scale factor based on max health
	var scale_factor = max_health / base_health
	
	# Calculate new width
	var new_width = base_width * scale_factor
	
	# Update health bar position and size
	health_bar.offset_left = -new_width / 2.0
	health_bar.offset_right = new_width / 2.0
	
	# Keep the same vertical position
	# offset_top and offset_bottom remain unchanged

func is_flashlight_active() -> bool:
	"""Check if player's flashlight is currently active"""
	# Get the game node to access flashlight_item
	var game_node = get_parent()
	if game_node and game_node.has_method("get") and "flashlight_item" in game_node:
		var flashlight_item = game_node.flashlight_item
		if flashlight_item and flashlight_item.has_method("is_flashlight_active"):
			return flashlight_item.is_flashlight_active()
	return false

func update_flashlight_visual():
	"""Update flashlight visual position, rotation, and visibility"""
	if not flashlight_sprite:
		return
	
	# Check if player has flashlight in inventory
	var has_flashlight = false
	var hud = get_node("../HUD")
	if hud and hud.has_method("get_inventory"):
		var inventory = hud.get_inventory()
		if inventory and inventory.has_method("has_item"):
			has_flashlight = inventory.has_item(GameText.ITEM_FLASHLIGHT)
	
	# Check if it's night time
	var is_night = false
	var game_manager = get_parent()
	if game_manager and game_manager.has_method("get") and "is_night" in game_manager:
		is_night = game_manager.is_night
	
	# Show/hide flashlight based on inventory AND night time
	flashlight_sprite.visible = has_flashlight and is_night
	
	if has_flashlight and is_night:
		# Position flashlight in player's hand (similar to axe positioning)
		var flashlight_offset = Vector2(0, -32)  # Move up by 32px from player center
		
		# Add horizontal offset based on facing direction
		if last_movement_direction.x > 0:  # Facing right
			flashlight_offset += Vector2(25, 0)
		elif last_movement_direction.x < 0:  # Facing left
			flashlight_offset += Vector2(-25, 0)
		elif last_movement_direction.y > 0:  # Facing down
			flashlight_offset += Vector2(25, 0)  # Default to right when facing down
		elif last_movement_direction.y < 0:  # Facing up
			flashlight_offset += Vector2(25, 0)  # Default to right when facing up
		
		flashlight_sprite.position = flashlight_offset
		
		# Rotate flashlight to face the same direction as player (plus 45° correction)
		var base_rotation = last_movement_direction.angle()
		flashlight_sprite.rotation = base_rotation + deg_to_rad(45.0)  # Add 45° clockwise correction

func start_death_sequence():
	"""Start the player death sequence with animation"""
	if is_dying:
		return  # Already dying
	
	print("Player death sequence started!")
	is_dying = true
	velocity = Vector2.ZERO  # Stop movement
	
	# Play game over sound and fade out day/night music
	if game_over_sound:
		game_over_sound.play()
	
	# Fade out day/night music
	var game_node = get_parent()
	if game_node and game_node.has_method("fade_out_game_music"):
		game_node.fade_out_game_music()
	
	# Hide everything except player and show black background
	if game_node and game_node.has_method("hide_everything_for_death"):
		game_node.hide_everything_for_death()
	
	# Center camera on player slowly (similar to victory sequence)
	if camera:
		var player_position = global_position
		var camera_tween = create_tween()
		camera_tween.tween_property(camera, "global_position", player_position, 2.0)
		await camera_tween.finished
	
	# Play dead animation
	if player_character:
		# Player character found, attempting to play death animation
		if player_character.has_method("play_dead_animation"):
			# Playing dead animation
			player_character.play_dead_animation()
		elif player_character.has_method("play_dying_animation"):
			# Playing dying animation
			player_character.play_dying_animation()
		else:
			print("Warning: Player character has no death animation method")
	else:
		print("Error: Player character not found!")
	
	# Wait for death animation to complete (1.5 seconds since camera took 2 seconds)
	await get_tree().create_timer(1.5).timeout
	
	# Don't show everything back - keep black background for game over screen
	# The game over screen will handle its own display
	
	# Emit health depleted signal after animation
	health_depleted.emit()

func handle_rock_throwing(delta):
	"""Handle automatic rock throwing at enemies"""
	# Update rock throw timer
	rock_throw_timer += delta
	
	# Check if we can throw a rock (have rocks and cooldown is finished)
	if rock_throw_timer >= rock_throw_cooldown and can_throw_rock():
		var target = find_rock_target()
		if target:
			throw_rock_at_target(target)
			rock_throw_timer = 0.0

func can_throw_rock() -> bool:
	"""Check if player can throw a rock"""
	# Need to have at least 1 rock in inventory
	var hud = get_node("../HUD")
	if hud and hud.has_method("has_material"):
		return hud.has_material("rock", 1)
	return false

func find_rock_target() -> Node:
	"""Find the closest enemy within rock throwing range"""
	var space_state = get_world_2d().direct_space_state
	if not space_state:
		return null
	
	var query = PhysicsShapeQueryParameters2D.new()
	
	# Create a circle shape for rock throwing range
	var circle_shape = CircleShape2D.new()
	circle_shape.radius = rock_throw_range
	query.shape = circle_shape
	query.transform.origin = global_position
	query.collision_mask = 0xFFFFFFFF  # Check all collision layers
	
	# Query for collisions
	var results = space_state.intersect_shape(query)
	
	var closest_enemy = null
	var closest_distance = rock_throw_range + 1.0
	
	for result in results:
		var body = result["collider"]
		
		# Check if it's specifically a mob or boss (not just any entity with take_damage)
		var is_mob = body.get_script() and body.get_script().get_path().ends_with("mob.gd")
		var is_boss = body.get_script() and body.get_script().get_path().ends_with("boss.gd")
		var is_mob_by_name = body.name.begins_with("Mob")
		var is_boss_by_name = body.name.begins_with("Boss")
		
		if (is_mob or is_boss or is_mob_by_name or is_boss_by_name) and body.has_method("take_damage"):
			var distance = global_position.distance_to(body.global_position)
			if distance < closest_distance:
				closest_distance = distance
				closest_enemy = body
	
	return closest_enemy

func throw_rock_at_target(target: Node):
	"""Throw a rock at the specified target"""
	# Check if we still have rocks
	if not can_throw_rock():
		return
	
	# Remove one rock from inventory
	var hud = get_node("../HUD")
	if hud and hud.has_method("remove_material_from_inventory"):
		if not hud.remove_material_from_inventory("rock", 1):
			return  # Failed to remove rock
	
	# Create rock projectile
	var rock = rock_projectile_scene.instantiate()
	get_parent().add_child(rock)
	
	# Connect rock hit signal
	rock.rock_hit.connect(func(_target_node): pass)  # Rock hit registered
	
	# Launch rock at target
	var start_pos = global_position + Vector2(0, -20)  # Slightly above player
	var target_pos = target.global_position
	rock.launch_at_target(start_pos, target_pos)
	
	# Rock thrown at target

func setup_game_over_sound():
	"""Setup the game over sound effect"""
	game_over_sound = AudioStreamPlayer.new()
	game_over_sound.name = "GameOverSound"
	game_over_sound.volume_db = 0.0
	game_over_sound.stream = load("res://assets/sounds/game_over.mp3")
	add_child(game_over_sound)

func setup_player_damage_sound():
	"""Setup the player damage sound effect"""
	player_damage_sound = AudioStreamPlayer.new()
	player_damage_sound.name = "PlayerDamageSound"
	player_damage_sound.volume_db = 0.0
	player_damage_sound.stream = load("res://assets/sounds/player_damage.mp3")
	add_child(player_damage_sound)
