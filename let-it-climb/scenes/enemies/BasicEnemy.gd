extends CharacterBody2D

# Basic Enemy for Let it Climb - based on vamlike-survivors mob system

signal enemy_died(enemy: Node, exp_reward: int)

@export var base_speed: float = 150.0
@export var base_health: int = 30
@export var base_damage: int = 15
@export var base_exp_reward: int = 10

# Current stats (scaled by floor)
var current_speed: float
var current_health: int
var max_health: int
var current_damage: int
var exp_reward: int

# Floor scaling
var floor_level: int = 1

# Movement and targeting
var target_player: Node2D

# Status effects
var status_effects: Dictionary = {}

# References
@onready var slime_character = %Slime
@onready var hurt_box = %HurtBox

func _ready():
	# Add to enemies group for player detection
	add_to_group("enemies")
	
	# Find player
	find_player()
	
	# Calculate stats based on floor
	calculate_stats()
	current_health = max_health
	
	# Start walking animation
	if slime_character:
		slime_character.play_walk()

func _physics_process(delta: float) -> void:
	if current_health <= 0:
		return
	
	# Update status effects
	update_status_effects(delta)
	
	# Move towards player
	move_towards_player(delta)

func find_player():
	"""Find the player node"""
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		target_player = players[0]

func calculate_stats():
	"""Calculate current stats based on floor level"""
	# Scale stats based on floor (15% increase per floor)
	var floor_multiplier = 1.0 + (floor_level - 1) * 0.15
	
	current_speed = base_speed * floor_multiplier
	max_health = int(base_health * floor_multiplier)
	current_damage = int(base_damage * floor_multiplier)
	exp_reward = int(base_exp_reward * floor_multiplier)

func set_floor_level(floor_number: int):
	"""Set the floor level for stat scaling"""
	floor_level = floor_number
	calculate_stats()
	current_health = max_health

func move_towards_player(_delta: float):
	"""Move towards the player"""
	if not target_player:
		return
	
	# Check if frozen
	if has_status_effect("freeze"):
		velocity = Vector2.ZERO
		move_and_slide()
		return
	
	# Calculate direction to player
	var direction = global_position.direction_to(target_player.global_position)
	
	# Apply movement
	velocity = direction * current_speed
	move_and_slide()

func take_damage(damage: int):
	"""Take damage from player attacks"""
	if current_health <= 0:
		return  # Already dead
	
	current_health = max(0, current_health - damage)
	
	# Play hurt animation
	if slime_character:
		slime_character.play_hurt()
	
	# Visual feedback
	show_damage_feedback()
	
	# Check for death
	if current_health <= 0:
		die()

func apply_knockback(source_position: Vector2):
	"""Apply knockback effect"""
	var knockback_direction = (global_position - source_position).normalized()
	var knockback_force = 300.0
	velocity += knockback_direction * knockback_force

func show_damage_feedback():
	"""Show visual feedback when taking damage"""
	# The slime character already handles visual feedback through animations
	pass

func die():
	"""Handle enemy death"""
	# Emit death signal with exp reward
	enemy_died.emit(self, exp_reward)
	
	# Play death effect (simple fade for now)
	play_death_effect()
	
	# Remove from scene
	queue_free()

func play_death_effect():
	"""Play death animation or effect"""
	# Simple fade out effect
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.3)

func apply_status_effect(effect_name: String, value: int, duration: float):
	"""Apply a status effect to the enemy"""
	status_effects[effect_name] = {
		"value": value,
		"duration": duration,
		"timer": duration
	}

func has_status_effect(effect_name: String) -> bool:
	"""Check if enemy has a specific status effect"""
	return effect_name in status_effects

func update_status_effects(delta: float):
	"""Update all active status effects"""
	var effects_to_remove = []
	
	for effect_name in status_effects:
		var effect = status_effects[effect_name]
		effect.timer -= delta
		
		# Apply effect
		match effect_name:
			"burn":
				# Deal burn damage over time
				if fmod(effect.timer, 0.5) < delta:  # Every 0.5 seconds
					take_damage(effect.value)
			"freeze":
				# Freezing is handled in movement
				pass
		
		# Remove expired effects
		if effect.timer <= 0:
			effects_to_remove.append(effect_name)
	
	# Clean up expired effects
	for effect_name in effects_to_remove:
		status_effects.erase(effect_name)

func get_damage() -> int:
	"""Get current damage value for collision detection"""
	return current_damage

func get_position_for_spawning() -> Vector2:
	"""Get position for spawning (used by spawner)"""
	return global_position

func set_target(player: Node2D):
	"""Set the target player"""
	target_player = player

# Elemental weaknesses/strengths (can be overridden by specific enemy types)
func get_element_resistance(_element: GameConstants.ElementType) -> float:
	"""Get resistance to specific element (1.0 = normal, 0.5 = resistant, 2.0 = weak)"""
	return 1.0  # Default: no resistance or weakness

func take_elemental_damage(damage: int, element: GameConstants.ElementType, _source_position: Vector2 = Vector2.ZERO):
	"""Take elemental damage with resistance calculation"""
	var resistance = get_element_resistance(element)
	var final_damage = int(damage * resistance)
	take_damage(final_damage)
