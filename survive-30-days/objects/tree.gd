extends StaticBody2D

signal tree_destroyed(tree_node)

@export var max_health: float = 5.0
@export var current_health: float = 5.0

var is_cut: bool = false
var cut_sprite_texture: Texture2D

func _ready():
	current_health = max_health
	is_cut = false
	
	# Load the cut tree sprite
	cut_sprite_texture = load("res://assets/resources/pine_tree_cut.png")
	if not cut_sprite_texture:
		print("Warning: Could not load pine_tree_cut.png")
	
	# Tree spawned with health

func take_damage(damage: float):
	"""Take damage and check if tree should be cut down"""
	# Don't take damage if already cut
	if is_cut:
		return
		
	current_health -= damage
	# Tree took damage
	
	# Visual feedback - flash red briefly
	show_damage_effect()
	
	# Check if tree should be cut down
	if current_health <= 0:
		cut_down_tree()

func show_damage_effect():
	"""Show visual feedback when tree takes damage"""
	# Don't show damage effect if already cut
	if is_cut:
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

func cut_down_tree():
	"""Cut down the tree when health reaches 0 - change sprite but keep collision"""
	# Tree cut down
	is_cut = true
	
	# Change sprite to cut version
	var sprite = get_node("Sprite2D")
	if sprite and cut_sprite_texture:
		sprite.texture = cut_sprite_texture
		# Changed tree sprite to cut version
	
	# Reduce shadow size to 50% when tree is cut
	var shadow = get_node("GroundShadow")
	if shadow:
		shadow.scale = shadow.scale * 0.5
		# Reduced shadow size to 50%
	
	# Emit signal for game tracking (but don't remove from scene)
	tree_destroyed.emit(self)
	
	# Optional: Add cut effect here (particles, sound, etc.)

func get_health_percentage() -> float:
	"""Get current health as a percentage"""
	return current_health / max_health

func is_destroyed() -> bool:
	"""Check if tree is destroyed"""
	return current_health <= 0

func is_tree_cut() -> bool:
	"""Check if tree has been cut down"""
	return is_cut
