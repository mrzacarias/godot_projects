class_name BaseEnemy extends CharacterBody2D

# Base class for all enemies (mobs and bosses)
# Contains common functionality like health, attacks, movement, and animations

signal enemy_destroyed(enemy_node)

# Common enemy properties
@export var speed = 150.0
@export var max_health: float = 10.0
@export var damage = 10.0
@export var attack_range = GameConstants.ATTACK_RANGE
@export var attack_cooldown = GameConstants.ATTACK_COOLDOWN
@export var knockback_strength = GameConstants.MOB_KNOCKBACK_STRENGTH

# Health and state
var current_health: float
var is_being_destroyed = false
var is_dying = false

# Combat system
var is_attacking = false
var attack_timer = 0.0
var last_movement_direction: Vector2 = Vector2.RIGHT

# Cached references
@onready var player = get_node("/root/Game/Player")
@onready var game = get_node("/root/Game")
@onready var character_sprite: Node2D = null  # Will be set by subclasses
@onready var hurt_box: Area2D = null  # Will be set by subclasses

# Physics optimization
var physics_optimizer
var entity_id: String
var cached_distance_to_player: float = 0.0
var distance_cache_timer: float = 0.0
var distance_cache_duration: float = 0.1

# Virtual methods to be overridden by subclasses
func get_enemy_group() -> String:
	"""Return the group name for this enemy type"""
	return "enemies"

func get_character_node_name() -> String:
	"""Return the name of the character animation node"""
	return "%EnemyCharacter"

func get_destruction_signal_name() -> String:
	"""Return the name of the destruction signal"""
	return "enemy_destroyed"

func handle_special_behavior(_delta: float, _distance_to_player: float):
	"""Override this for enemy-specific behavior (boss special attacks, mob fleeing, etc.)"""
	pass

func can_attack(_distance_to_player: float) -> bool:
	"""Override this to add custom attack conditions"""
	return true

# Common initialization
func _ready():
	current_health = max_health
	add_to_group(get_enemy_group())
	
	# Initialize physics optimizer
	var PhysicsOptimizerClass = preload("res://PhysicsOptimizer.gd")
	physics_optimizer = PhysicsOptimizerClass.get_instance()
	entity_id = str(get_instance_id())
	
	# Cache character sprite reference
	var character_node_name = get_character_node_name()
	if has_node(character_node_name):
		character_sprite = get_node(character_node_name)
	
	# Cache hurt box reference
	if has_node("%HurtBox"):
		hurt_box = %HurtBox
	
	# Add to spatial grid
	if physics_optimizer:
		physics_optimizer.spatial_grid.add_entity(self, entity_id)
	
	# Start with idle animation
	if character_sprite and character_sprite.has_method("play_idle_animation"):
		character_sprite.play_idle_animation()

# Common physics processing
func _physics_process(delta: float) -> void:
	if not player or not is_instance_valid(player) or is_being_destroyed or is_dying:
		return
	
	# Check if game is paused for player death
	var game_node = get_parent()
	if game_node and game_node.has_method("get") and "is_player_dying" in game_node and game_node.is_player_dying:
		return  # Pause enemy behavior during player death
	
	# Update physics optimizer caches
	if physics_optimizer:
		physics_optimizer.update_caches(delta)
		physics_optimizer.spatial_grid.update_entity(self, entity_id)
	
	# Get cached distance to player
	var distance_to_player = get_cached_distance_to_player(delta)
	
	# Update attack timer
	attack_timer += delta
	
	# Handle special behavior (overridden by subclasses)
	handle_special_behavior(delta, distance_to_player)
	
	# Check if we should attack (use squared distance for performance)
	var attack_range_sq = attack_range * attack_range
	var PhysicsOptimizerClass = preload("res://PhysicsOptimizer.gd")
	if PhysicsOptimizerClass.is_within_range_squared(global_position, player.global_position, attack_range_sq) and attack_timer >= attack_cooldown and can_attack(distance_to_player):
		start_attack()
		attack_timer = 0.0
	elif not is_attacking:
		# Move toward player if not attacking
		move_toward_player(distance_to_player)

# Common movement logic
func move_toward_player(_distance_to_player: float):
	"""Move toward the player using physics collision"""
	if not player or is_attacking:
		return
	
	# Calculate direction to player using optimized function
	var PhysicsOptimizerClass = preload("res://PhysicsOptimizer.gd")
	var direction = PhysicsOptimizerClass.get_direction_fast(global_position, player.global_position)
	
	# Set velocity and move
	velocity = direction * speed
	move_and_slide()
	
	# Update movement direction for sprite flipping
	if direction.x != 0:
		last_movement_direction = Vector2.RIGHT if direction.x > 0 else Vector2.LEFT
	
	# Handle sprite flipping and animations
	update_sprite_and_animation(direction)

# Common sprite and animation handling
func update_sprite_and_animation(direction: Vector2):
	"""Update sprite flipping and animations based on movement"""
	if not character_sprite:
		return
	
	# Handle sprite flipping
	if direction.x > 0:
		character_sprite.scale.x = abs(character_sprite.scale.x)
	elif direction.x < 0:
		character_sprite.scale.x = -abs(character_sprite.scale.x)
	
	# Handle animations
	if velocity.length() > 0.0 and character_sprite.has_method("play_walk_animation"):
		character_sprite.play_walk_animation()
	elif character_sprite.has_method("play_idle_animation"):
		character_sprite.play_idle_animation()

# Common attack system
func start_attack():
	"""Start an attack sequence"""
	if is_attacking:
		return
	
	is_attacking = true
	
	# Play attack animation
	if character_sprite and character_sprite.has_method("play_attack_animation"):
		character_sprite.play_attack_animation()
	
	# Handle the attack logic
	handle_attack()

func handle_attack():
	"""Handle the attack logic - can be overridden for special attacks"""
	# Wait for attack animation
	await get_tree().create_timer(0.5).timeout
	
	# Check if player is still in range
	if player and is_instance_valid(player):
		var distance_to_player = global_position.distance_to(player.global_position)
		if distance_to_player <= attack_range:
			pass  # The player will handle damage through their HurtBox collision detection
	
	is_attacking = false
	
	# Return to appropriate animation
	if character_sprite:
		if velocity.length() > 0 and character_sprite.has_method("play_walk_animation"):
			character_sprite.play_walk_animation()
		elif character_sprite.has_method("play_idle_animation"):
			character_sprite.play_idle_animation()

# Common health and damage system
func take_damage(damage_amount: float):
	"""Take damage and handle death if health reaches 0"""
	if is_being_destroyed or is_dying:
		return
	
	current_health -= damage_amount
	
	# Visual feedback
	show_damage_effect()
	
	# Check for death
	if current_health <= 0:
		start_death_sequence()

func show_damage_effect():
	"""Show visual feedback when taking damage"""
	if not character_sprite:
		return
	
	# Play hurt animation if available
	if character_sprite.has_method("play_hurt_animation"):
		character_sprite.play_hurt_animation()
	
	# Flash red briefly
	var original_modulate = character_sprite.modulate
	character_sprite.modulate = Color.RED
	
	# Return to normal color after brief flash
	await get_tree().create_timer(GameConstants.DAMAGE_FLASH_DURATION).timeout
	if is_instance_valid(character_sprite):
		character_sprite.modulate = original_modulate

func start_death_sequence():
	"""Handle enemy death"""
	if is_dying:
		return
	
	is_dying = true
	is_being_destroyed = true
	
	# Play death animation if available
	if character_sprite and character_sprite.has_method("play_dying_animation"):
		character_sprite.play_dying_animation()
		# Wait for death animation to complete
		await get_tree().create_timer(1.0).timeout
	
	# Emit destruction signal
	enemy_destroyed.emit(self)
	
	# Remove from scene
	queue_free()

# Utility methods
func get_health_percentage() -> float:
	"""Get current health as a percentage"""
	return current_health / max_health if max_health > 0 else 0.0

func is_enemy_destroyed() -> bool:
	"""Check if enemy has been destroyed"""
	return is_being_destroyed or is_dying

func get_distance_to_player() -> float:
	"""Get current distance to player"""
	if not player or not is_instance_valid(player):
		return INF
	return global_position.distance_to(player.global_position)

func get_cached_distance_to_player(delta: float) -> float:
	"""Get cached distance to player for performance"""
	distance_cache_timer += delta
	
	if distance_cache_timer >= distance_cache_duration:
		cached_distance_to_player = get_distance_to_player()
		distance_cache_timer = 0.0
	
	return cached_distance_to_player

func start_daylight_damage():
	"""Handle daylight damage - override in subclasses"""
	pass

func _exit_tree():
	"""Clean up when enemy is removed"""
	if physics_optimizer:
		physics_optimizer.spatial_grid.remove_entity(entity_id)
