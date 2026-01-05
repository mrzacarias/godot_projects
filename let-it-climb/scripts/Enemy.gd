class_name Enemy
extends CharacterBody2D

# Base enemy class for Let it Climb

signal enemy_died(enemy: Enemy, exp_reward: int)
signal enemy_damaged(enemy: Enemy, damage: int)

@export var enemy_name: String = "Basic Enemy"
@export var base_speed: float = 100.0
@export var base_damage: int = 10
@export var base_hp: int = 50
@export var base_exp_reward: int = 5

# Current stats (scaled by floor)
var current_speed: float
var current_damage: int
var current_hp: int
var max_hp: int
var exp_reward: int

# Floor scaling
var floor_level: int = 1

# Movement and combat
var target_player: Node2D
var last_damage_time: float = 0.0
var damage_cooldown: float = 1.0

# Status effects
var status_effects: Dictionary = {}

# Visual feedback
@onready var sprite = %EnemySprite
@onready var health_bar = %HealthBar
@onready var hit_box = %HitBox
@onready var hurt_box = %HurtBox

func _ready():
	# Initialize stats
	calculate_stats()
	current_hp = max_hp
	
	# Find player
	find_player()
	
	# Setup health bar
	if health_bar:
		health_bar.max_value = max_hp
		health_bar.value = current_hp
		health_bar.visible = false  # Hide until damaged

func _physics_process(delta: float):
	# Update status effects
	update_status_effects(delta)
	
	# Move towards player
	move_towards_player(delta)
	
	# Handle combat
	handle_combat(delta)

func calculate_stats():
	"""Calculate current stats based on floor level"""
	# Scale stats based on floor (10% increase per floor)
	var floor_multiplier = 1.0 + (floor_level - 1) * 0.1
	
	current_speed = base_speed * floor_multiplier
	current_damage = int(base_damage * floor_multiplier)
	max_hp = int(base_hp * floor_multiplier)
	exp_reward = int(base_exp_reward * floor_multiplier)

func set_floor_level(floor: int):
	"""Set the floor level for stat scaling"""
	floor_level = floor
	calculate_stats()
	current_hp = max_hp
	
	if health_bar:
		health_bar.max_value = max_hp
		health_bar.value = current_hp

func find_player():
	"""Find the player node"""
	# Look for player in the scene
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		target_player = players[0]

func move_towards_player(delta: float):
	"""Move towards the player"""
	if not target_player or current_hp <= 0:
		return
	
	# Check if frozen
	if has_status_effect("freeze"):
		velocity = Vector2.ZERO
		move_and_slide()
		return
	
	# Calculate direction to player
	var direction = (target_player.global_position - global_position).normalized()
	
	# Apply movement
	velocity = direction * current_speed
	move_and_slide()
	
	# Handle sprite flipping
	if sprite and direction.x != 0:
		sprite.scale.x = sign(direction.x) * abs(sprite.scale.x)

func handle_combat(delta: float):
	"""Handle combat with player"""
	if not target_player or current_hp <= 0:
		return
	
	# Update damage cooldown
	if last_damage_time > 0:
		last_damage_time -= delta
	
	# Check if we can damage player (collision with hurt box)
	if hurt_box and last_damage_time <= 0:
		var overlapping_players = hurt_box.get_overlapping_bodies()
		for body in overlapping_players:
			if body == target_player:
				# Deal damage to player
				if target_player.has_method("take_damage"):
					target_player.take_damage(current_damage, global_position)
				last_damage_time = damage_cooldown
				break

func take_damage(damage: int, source_position: Vector2 = Vector2.ZERO):
	"""Take damage from player attacks"""
	if current_hp <= 0:
		return  # Already dead
	
	current_hp = max(0, current_hp - damage)
	
	# Update health bar
	if health_bar:
		health_bar.visible = true
		health_bar.value = current_hp
	
	# Visual feedback
	show_damage_feedback()
	
	# Knockback effect
	if source_position != Vector2.ZERO:
		apply_knockback(source_position)
	
	# Emit damage signal
	enemy_damaged.emit(self, damage)
	
	# Check for death
	if current_hp <= 0:
		die()

func apply_knockback(source_position: Vector2):
	"""Apply knockback effect"""
	var knockback_direction = (global_position - source_position).normalized()
	var knockback_force = 200.0
	velocity += knockback_direction * knockback_force

func show_damage_feedback():
	"""Show visual feedback when taking damage"""
	if sprite:
		var original_modulate = sprite.modulate
		sprite.modulate = Color(1.5, 1.5, 1.5, 1.0)  # White flash
		
		# Return to normal after brief delay
		await get_tree().create_timer(0.1).timeout
		if is_instance_valid(sprite):
			sprite.modulate = original_modulate

func die():
	"""Handle enemy death"""
	# Emit death signal with exp reward
	enemy_died.emit(self, exp_reward)
	
	# Death animation/effect
	play_death_effect()
	
	# Remove from scene
	queue_free()

func play_death_effect():
	"""Play death animation or effect"""
	# Simple fade out effect
	if sprite:
		var tween = create_tween()
		tween.tween_property(sprite, "modulate:a", 0.0, 0.3)

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
func get_element_resistance(element: GameConstants.ElementType) -> float:
	"""Get resistance to specific element (1.0 = normal, 0.5 = resistant, 2.0 = weak)"""
	return 1.0  # Default: no resistance or weakness

func take_elemental_damage(damage: int, element: GameConstants.ElementType, source_position: Vector2 = Vector2.ZERO):
	"""Take elemental damage with resistance calculation"""
	var resistance = get_element_resistance(element)
	var final_damage = int(damage * resistance)
	take_damage(final_damage, source_position)

# Save/load functionality (for persistent enemies if needed)
func to_save_data() -> Dictionary:
	"""Convert enemy to save data"""
	return {
		"enemy_name": enemy_name,
		"position": global_position,
		"current_hp": current_hp,
		"floor_level": floor_level
	}

func from_save_data(data: Dictionary):
	"""Load enemy from save data"""
	enemy_name = data.get("enemy_name", "Basic Enemy")
	global_position = data.get("position", Vector2.ZERO)
	floor_level = data.get("floor_level", 1)
	calculate_stats()
	current_hp = data.get("current_hp", max_hp)
