extends "res://BaseEnemy.gd"

signal mob_destroyed(mob_node)

# Mob-specific properties
var is_in_safezone = false
var safezone_center = Vector2.ZERO
var safezone_radius = 0.0
var is_running_from_flashlight = false
var flashlight_flee_direction = Vector2.ZERO

# Daylight damage properties
var daylight_damage_timer = -1.0  # -1 means not active, >=0 means active
var daylight_damage_interval = 1.0  # Damage every second during day
var is_daylight_damage_active = false

# Audio system
var mob_yell_sound: AudioStreamPlayer

func _init():
	# Set mob-specific defaults
	speed = 150.0
	max_health = 10.0
	damage = 10.0
	knockback_strength = GameConstants.MOB_KNOCKBACK_STRENGTH

func _ready():
	# Call parent ready first
	super._ready()
	
	# Setup mob yell sound
	setup_mob_sound()
	
	# Cache mob-specific character sprite
	if has_node("%MobCharacter"):
		character_sprite = %MobCharacter

# Override virtual methods
func get_enemy_group() -> String:
	return "mobs"

func get_character_node_name() -> String:
	return "%MobCharacter"

func get_destruction_signal_name() -> String:
	return "mob_destroyed"

# Mob-specific behavior
func handle_special_behavior(_delta: float, _distance_to_player: float):
	"""Handle mob-specific behavior like safezone and flashlight fleeing"""
	# Handle daylight damage if active
	handle_daylight_damage(_delta)
	
	# Check for world bounds destruction
	check_world_bounds()
	
	# Handle flashlight fleeing behavior
	handle_flashlight_behavior()

func move_toward_player(_distance_to_player: float):
	"""Override movement to handle safezone and flashlight fleeing"""
	if not player or is_attacking:
		return
	
	var direction: Vector2
	var movement_speed = speed
	
	# Check if running from flashlight
	if is_running_from_flashlight:
		direction = flashlight_flee_direction.normalized()
		movement_speed = speed * 2.0  # Double speed when fleeing flashlight
	else:
		# Normal movement toward player, but respect safezone
		if is_in_safezone:
			# Move away from safezone center
			direction = (global_position - safezone_center).normalized()
		else:
			# Move toward player
			direction = (player.global_position - global_position).normalized()
	
	# Set velocity and move
	velocity = direction * movement_speed
	move_and_slide()
	
	# Update movement direction for sprite flipping
	if direction.x != 0:
		last_movement_direction = Vector2.RIGHT if direction.x > 0 else Vector2.LEFT
	
	# Handle sprite flipping and animations
	update_sprite_and_animation(direction)

# Mob-specific methods
func check_world_bounds():
	"""Check if mob is out of world bounds and destroy if so"""
	var world_size = Vector2(4320, 2880)  # Should use GameConstants
	var margin = 200.0  # Extra margin for destruction
	
	if global_position.x < -margin or global_position.x > world_size.x + margin or \
	   global_position.y < -margin or global_position.y > world_size.y + margin:
		# Mob is out of bounds, destroy it
		start_death_sequence()

func handle_flashlight_behavior():
	"""Handle flashlight avoidance behavior"""
	if not player:
		return
	
	# Once a mob starts running from flashlight, it stays in that state until death or off-screen
	if is_running_from_flashlight:
		# Keep running in the same direction - don't reset the flee state
		return
	
	# Check if player has flashlight active (only if not already running)
	var flashlight_active = false
	if player.has_method("is_flashlight_active"):
		flashlight_active = player.is_flashlight_active()
	
	if flashlight_active:
		# Get flashlight instance from game manager to use proper cone detection
		var game_manager = get_parent()
		if game_manager and game_manager.has_method("get_flashlight_item"):
			var flashlight_item = game_manager.get_flashlight_item()
			if flashlight_item:
				# Get flashlight position and player facing direction
				var flashlight_position = game_manager.get_flashlight_position()
				var player_facing_direction = game_manager.get_player_facing_direction()
				
				# Use proper cone detection instead of just distance
				if flashlight_item.is_mob_in_flashlight_cone(global_position, flashlight_position, player_facing_direction):
					# Start running away from flashlight (once started, never stops)
					is_running_from_flashlight = true
					flashlight_flee_direction = (global_position - flashlight_position).normalized()
					
					# Play mob yell sound when scared by flashlight
					if mob_yell_sound:
						mob_yell_sound.play()

func set_safezone(center: Vector2, radius: float):
	"""Set the safezone that this mob should avoid"""
	safezone_center = center
	safezone_radius = radius
	
	# Check if currently in safezone
	var distance_to_center = global_position.distance_to(center)
	is_in_safezone = distance_to_center <= radius

func clear_safezone():
	"""Clear the safezone"""
	is_in_safezone = false
	safezone_center = Vector2.ZERO
	safezone_radius = 0.0

func set_in_safezone(in_zone: bool, center: Vector2, radius: float):
	"""Set whether mob is in safezone (called by campfire)"""
	is_in_safezone = in_zone
	if in_zone:
		safezone_center = center
		safezone_radius = radius
	else:
		safezone_center = Vector2.ZERO
		safezone_radius = 0.0

func update_safezone_status():
	"""Update whether mob is currently in safezone"""
	if safezone_radius > 0:
		var distance_to_center = global_position.distance_to(safezone_center)
		is_in_safezone = distance_to_center <= safezone_radius

# Daybreak destruction (called by game manager)
func start_daybreak_destruction():
	"""Start destruction sequence for daybreak"""
	if not is_being_destroyed:
		start_death_sequence()

func start_death_sequence():
	"""Override to emit mob-specific signal"""
	if is_dying:
		return
	
	is_dying = true
	is_being_destroyed = true
	
	# Play death animation if available
	if character_sprite and character_sprite.has_method("play_dying_animation"):
		character_sprite.play_dying_animation()
		# Wait for death animation to complete
		await get_tree().create_timer(1.0).timeout
	
	# Start fade out effect (1 second)
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 1.0)
	await tween.finished
	
	# Emit mob-specific destruction signal
	mob_destroyed.emit(self)
	
	# Remove from scene
	queue_free()

# Daylight damage implementation
func start_daylight_damage():
	"""Start taking daylight damage and show fire effect"""
	if is_daylight_damage_active or is_dying:
		return
	
	is_daylight_damage_active = true
	daylight_damage_timer = 0.0
	
	# Show fire effect
	if has_node("%FireEffect"):
		var fire_effect = %FireEffect
		fire_effect.visible = true
		fire_effect.play("fire")
	
	# Mob starting daylight damage with fire effect

func stop_daylight_damage():
	"""Stop daylight damage and hide fire effect"""
	if not is_daylight_damage_active:
		return
	
	is_daylight_damage_active = false
	daylight_damage_timer = 0.0
	
	# Hide fire effect
	if has_node("%FireEffect"):
		var fire_effect = %FireEffect
		fire_effect.visible = false
		fire_effect.stop()
	
	# Mob stopping daylight damage

func handle_daylight_damage(delta: float):
	"""Handle daylight damage behavior for mobs"""
	if not is_daylight_damage_active:
		return
	
	# Apply damage over time
	daylight_damage_timer += delta
	if daylight_damage_timer >= 1.0:  # Damage every second
		take_damage(GameConstants.BOSS_DAYLIGHT_DAMAGE)  # Same damage as boss
		daylight_damage_timer = 0.0
		# Mob taking daylight damage

func setup_mob_sound():
	"""Setup the mob yell sound effect"""
	mob_yell_sound = AudioStreamPlayer.new()
	mob_yell_sound.name = "MobYellSound"
	mob_yell_sound.volume_db = 0.0
	mob_yell_sound.stream = load("res://assets/sounds/mob_yell.mp3")
	add_child(mob_yell_sound)
