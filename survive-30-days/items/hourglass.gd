extends Node2D
class_name Hourglass

signal hourglass_upgraded(new_level: int, new_multiplier: float)

# GameText is available globally via class_name

@export var max_level: int = 4  # Max level 4 = 5x speed
@export var texture_path: String = "res://assets/items/hourglass/hourglass.png"

var level: int = 0
var is_active: bool = false
var time_multiplier: float = 1.0

func _ready():
	# Initialize hourglass
	pass

func get_level() -> int:
	"""Get current hourglass level"""
	return level

func get_time_multiplier() -> float:
	"""Get current time multiplier"""
	return time_multiplier

func is_at_max_level() -> bool:
	"""Check if hourglass is at maximum level"""
	return level >= max_level

func is_hourglass_active() -> bool:
	"""Check if hourglass effect is active"""
	return is_active

func upgrade() -> bool:
	"""Upgrade the hourglass effect (max 5x speed)"""
	if level >= max_level:
		# Hourglass already at max level
		return false
	
	level += 1
	is_active = true
	time_multiplier = 1.0 + level  # 2x for first, 3x for second, etc. (max 5x)
	# Hourglass effect level updated
	
	hourglass_upgraded.emit(level, time_multiplier)
	return true

func reset():
	"""Reset hourglass to initial state"""
	level = 0
	is_active = false
	time_multiplier = 1.0

func get_texture() -> Texture2D:
	"""Get hourglass texture for inventory"""
	return load(texture_path)

func give_to_player(hud, game_node) -> bool:
	"""Give hourglass to player or upgrade existing one"""
	if not game_node:
		return false
	
	# Check if this is the first hourglass or an upgrade
	var inventory = hud.get_inventory()
	var has_hourglass = inventory and inventory.has_method("has_item") and inventory.has_item(GameText.ITEM_HOURGLASS)
	
	if has_hourglass:
		# Upgrade existing hourglass (if not at max level)
		if is_at_max_level():
			hud.show_message(GameText.HOURGLASS_MAX_POWER)
			return false
		else:
			if upgrade():
				hud.show_message(GameText.HOURGLASS_UPGRADED)
				# Update the hourglass display in inventory
				if inventory.has_method("update_item_level"):
					inventory.update_item_level(GameText.ITEM_HOURGLASS, level)
				return true
	else:
		# First hourglass - add to inventory
		var hourglass_texture = get_texture()
		if hud.has_method("add_item_to_inventory") and hourglass_texture:
			var success = hud.add_item_to_inventory(GameText.ITEM_HOURGLASS, hourglass_texture, 1)
			if success:
				# Hourglass added to inventory
				hud.show_message(GameText.FOUND_HOURGLASS)
				upgrade()  # Activate the effect
				return true
			else:
				# Failed to add hourglass
				return false
	
	return false

func check_player_has_hourglass(hud) -> bool:
	"""Check if player has hourglass in inventory"""
	if hud and hud.has_method("get_inventory"):
		var inventory = hud.get_inventory()
		if inventory and inventory.has_method("has_item"):
			return inventory.has_item(GameText.ITEM_HOURGLASS)
	return false
