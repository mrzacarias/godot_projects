extends StaticBody2D

signal boulder_destroyed(boulder_node)

@export var max_health: float = 10.0
@export var current_health: float = 10.0

var is_destroyed: bool = false
var destroyed_sprite_texture: Texture2D

func _ready():
	current_health = max_health
	is_destroyed = false
	
	# Load the destroyed boulder sprite (we'll use the same texture for now)
	destroyed_sprite_texture = load("res://assets/resources/boulder.png")

func take_damage(damage: float):
	"""Take damage and check if boulder should be destroyed"""
	# Don't take damage if already destroyed
	if is_destroyed:
		return
		
	current_health -= damage
	
	# Visual feedback - flash red briefly
	show_damage_effect()
	
	# Check if boulder should be destroyed
	if current_health <= 0:
		destroy_boulder()

func show_damage_effect():
	"""Show visual feedback when boulder takes damage"""
	# Don't show damage effect if already destroyed
	if is_destroyed:
		return
		
	var sprite = get_node("Sprite2D")
	if sprite:
		# Flash red briefly
		var original_modulate = sprite.modulate
		sprite.modulate = Color.RED
		
		# Return to normal color after 0.1 seconds
		await get_tree().create_timer(0.1).timeout
		if is_instance_valid(sprite):
			sprite.modulate = original_modulate

func destroy_boulder():
	"""Destroy the boulder when health reaches 0 - remove it completely"""
	is_destroyed = true
	
	# Emit signal for game tracking before removing from scene
	boulder_destroyed.emit(self)
	
	# Remove the boulder from the scene completely
	queue_free()
	
	# Optional: Add destruction effect here (particles, sound, etc.)

func get_health_percentage() -> float:
	"""Get current health as a percentage"""
	return current_health / max_health

func is_boulder_destroyed() -> bool:
	"""Check if boulder has been destroyed"""
	return is_destroyed

