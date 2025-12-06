extends Node2D
class_name Flashlight

signal flashlight_status_changed(active: bool)

# GameText is available globally via class_name

@export var light_range: float = 300.0  # 50% bigger: was 200px, now 300px
@export var cone_angle: float = 90.0  # degrees - wider cone for better gameplay
@export var texture_path: String = "res://assets/items/flashlight/flashlight.png"

var is_active: bool = false

func _ready():
	# Initialize flashlight
	pass

func activate():
	"""Activate the flashlight"""
	if not is_active:
		is_active = true
		flashlight_status_changed.emit(true)
		# Flashlight activated

func deactivate():
	"""Deactivate the flashlight"""
	if is_active:
		is_active = false
		flashlight_status_changed.emit(false)
		# Flashlight deactivated

func is_flashlight_active() -> bool:
	"""Check if flashlight is currently active"""
	return is_active

func get_range() -> float:
	"""Get flashlight range"""
	return light_range

func get_cone_angle() -> float:
	"""Get flashlight cone angle"""
	return cone_angle

func get_texture() -> Texture2D:
	"""Get flashlight texture for inventory"""
	return load(texture_path)

func give_to_player(hud) -> bool:
	"""Give flashlight to player inventory"""
	var flashlight_texture = get_texture()
	if hud.has_method("add_item_to_inventory") and flashlight_texture:
		var success = hud.add_item_to_inventory(GameText.ITEM_FLASHLIGHT, flashlight_texture, 1)
		if success:
			# Flashlight added to inventory
			hud.show_message(GameText.FOUND_FLASHLIGHT)
			return true
		else:
			# Failed to add flashlight
			return false
	return false

func check_player_has_flashlight(hud) -> bool:
	"""Check if player has flashlight in inventory"""
	if hud and hud.has_method("get_inventory"):
		var inventory = hud.get_inventory()
		if inventory and inventory.has_method("has_item"):
			return inventory.has_item(GameText.ITEM_FLASHLIGHT)
	return false

func update_shader_parameters(shader_material, flashlight_position: Vector2, flashlight_direction: Vector2):
	"""Update shader parameters for flashlight effect"""
	if not shader_material:
		return
		
	shader_material.set_shader_parameter("flashlight_position", flashlight_position)
	shader_material.set_shader_parameter("flashlight_direction", flashlight_direction)
	shader_material.set_shader_parameter("flashlight_range", light_range)
	shader_material.set_shader_parameter("flashlight_cone_angle", cone_angle)
	shader_material.set_shader_parameter("flashlight_active", is_active)

func is_mob_in_flashlight_cone(mob_position: Vector2, flashlight_position: Vector2, player_facing: Vector2) -> bool:
	"""Check if a mob is within the flashlight cone"""
	if not is_active:
		return false
	
	# Check distance to flashlight
	var distance_to_flashlight = mob_position.distance_to(flashlight_position)
	if distance_to_flashlight > light_range:
		return false
	
	# Check if within cone angle
	var to_mob = (mob_position - flashlight_position).normalized()
	var dot_product = player_facing.dot(to_mob)
	var angle_to_mob = acos(dot_product) * 180.0 / PI
	
	return angle_to_mob <= cone_angle / 2.0
