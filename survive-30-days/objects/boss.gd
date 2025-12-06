extends "res://BaseEnemy.gd"

signal boss_destroyed(boss_node)

# Boss-specific properties
var is_final_boss = false
var hurt_timer = 0.0
var hurt_duration = GameConstants.HURT_ANIMATION_DURATION
var daylight_damage_timer = -1.0  # -1 means not active, >=0 means active
var daylight_damage_interval = 1.0  # Damage every second during day
var max_axe_damage = 25.0  # 5x max level axe damage (5.0 * 5 = 25.0)
var is_daylight_damage_active = false

# Audio system
var boss_die_sound: AudioStreamPlayer

func _init():
	# Set boss-specific defaults
	speed = 200.0
	max_health = 60.0  # 3x mob health
	damage = 40.0  # 2x mob damage
	knockback_strength = GameConstants.BOSS_KNOCKBACK_STRENGTH

func _ready():
	# Call parent ready first
	super._ready()
	
	# Setup boss death sound
	setup_boss_sound()
	
	# Cache boss-specific character sprite
	if has_node("%BossCharacter"):
		character_sprite = %BossCharacter

# Override virtual methods
func get_enemy_group() -> String:
	return "bosses"

func get_character_node_name() -> String:
	return "%BossCharacter"

func get_destruction_signal_name() -> String:
	return "boss_destroyed"

# Boss-specific behavior
func handle_special_behavior(delta: float, distance_to_player: float):
	"""Handle boss-specific behavior like hurt timer and collision-based attacks"""
	# Don't process behavior if dying - let the dying animation play
	if is_dying:
		return
	
	# Handle daylight damage if active
	if is_daylight_damage_active and daylight_damage_timer >= 0:
		daylight_damage_timer += delta
		if daylight_damage_timer >= daylight_damage_interval:
			# Boss taking daylight damage
			take_damage(max_axe_damage)
			daylight_damage_timer = 0.0  # Reset timer for next damage tick
		
		# Show hurt animation and stop moving during daylight damage
		if character_sprite and character_sprite.has_method("play_hurt_animation"):
			character_sprite.play_hurt_animation()
		
		# Stop movement during daylight damage
		velocity = Vector2.ZERO
		return  # Don't process normal behavior while taking daylight damage
	
	# Handle hurt animation timer
	if hurt_timer > 0:
		hurt_timer -= delta
		if hurt_timer <= 0:
			# Return to appropriate animation after hurt (only if not dying)
			if character_sprite and not is_dying:
				if velocity.length() > 0:
					character_sprite.play_walk_animation()
				else:
					character_sprite.play_idle_animation()
	
	# Check if boss is colliding with player hurt box and maintain slashing animation
	if hurt_box and hurt_timer <= 0:
		var overlapping_areas = physics_optimizer.collision_optimizer.get_overlapping_areas(hurt_box, entity_id) if physics_optimizer else hurt_box.get_overlapping_areas()
		var is_colliding_with_player = false
		
		for area in overlapping_areas:
			if area.name == "HurtBox" and area.get_parent() == player:
				is_colliding_with_player = true
				break
		
		if is_colliding_with_player:
			# Keep playing slashing animation while colliding with player
			if character_sprite:
				character_sprite.play_attack_animation()
		elif is_attacking and not is_colliding_with_player:
			# Stop attacking if no longer colliding (but still respect timed attacks)
			if distance_to_player > attack_range:
				is_attacking = false

func can_attack(_distance_to_player: float) -> bool:
	"""Boss can attack if not in hurt state and not taking daylight damage"""
	return hurt_timer <= 0 and not is_daylight_damage_active

func move_toward_player(distance_to_player: float):
	"""Override movement to prevent movement during daylight damage"""
	if is_daylight_damage_active:
		velocity = Vector2.ZERO  # Stop all movement during daylight damage
		return
	
	# Call parent movement logic if not taking daylight damage
	super.move_toward_player(distance_to_player)

# Boss-specific methods
func set_final_boss(final: bool):
	"""Set this boss as the final boss"""
	is_final_boss = final
	
	if final:
		# Final boss gets enhanced stats for extra challenge
		max_health *= 2.0  # Double health
		current_health = max_health  # Update current health to match
		speed *= 2.0  # Double speed
		print("Final Boss enhanced: Health = ", max_health, ", Speed = ", speed)

func show_damage_effect():
	"""Override to add hurt timer for boss"""
	super.show_damage_effect()
	
	# Set hurt timer to prevent immediate attacks
	hurt_timer = hurt_duration
	
	# Play hurt animation
	if character_sprite and character_sprite.has_method("play_hurt_animation"):
		character_sprite.play_hurt_animation()

func get_sprite_node():
	"""Get the sprite node for visual effects"""
	if character_sprite:
		return character_sprite
	return null

func start_daylight_damage():
	"""Handle daylight damage - boss takes damage equivalent to max level axe"""
	if is_dying or is_being_destroyed or is_final_boss or is_daylight_damage_active:
		return  # Final boss is immune to daylight damage, or already active
	
	# Boss starting daylight damage
	# Start taking damage every second during daylight
	is_daylight_damage_active = true
	daylight_damage_timer = 0.0

func stop_daylight_damage():
	"""Stop daylight damage when night comes"""
	if is_daylight_damage_active:
		# Boss stopping daylight damage
		is_daylight_damage_active = false
		daylight_damage_timer = -1.0

func start_death_sequence():
	"""Override to emit boss-specific signal"""
	if is_dying:
		return
	
	print("Boss: Starting death sequence")
	is_dying = true
	is_being_destroyed = true
	
	# Play boss death sound
	if boss_die_sound:
		boss_die_sound.play()
	
	# Stop daylight damage
	is_daylight_damage_active = false
	daylight_damage_timer = -1.0
	
	# Stop all movement
	velocity = Vector2.ZERO
	
	# Emit boss-specific destruction signal immediately (for victory sequence timing)
	boss_destroyed.emit(self)
	
	# Play death animation if available
	if character_sprite and character_sprite.has_method("play_dying_animation"):
		# Boss calling play_dying_animation
		character_sprite.play_dying_animation()
		# Wait for death animation to complete (longer time for 15 frames)
		await get_tree().create_timer(2.0).timeout
	else:
		# Boss: No dying animation method found
		pass
	
	# Start fade out effect (1 second)
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 1.0)
	await tween.finished
	
	# For final boss, don't queue_free immediately - let victory sequence handle cleanup
	if not is_final_boss:
		queue_free()
	# Final boss will be cleaned up by the victory sequence

func setup_boss_sound():
	"""Setup the boss death sound effect"""
	boss_die_sound = AudioStreamPlayer.new()
	boss_die_sound.name = "BossDieSound"
	boss_die_sound.volume_db = 0.0
	boss_die_sound.stream = load("res://assets/sounds/boss_die.mp3")
	add_child(boss_die_sound)
