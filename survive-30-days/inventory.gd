extends Control

signal item_added(item_name: String)
signal item_removed(item_name: String)

@export var slot_size: int = 64
@export var slot_spacing: int = 20
@export var max_slots: int = 3
@export var border_width: int = 10

var items: Array[String] = []
var item_levels: Dictionary = {}  # Track item levels
var slot_containers: Array[Control] = []

func _ready():
	# Initialize with no slots visible
	update_inventory_display()

func add_item(item_name: String, texture: Texture2D, level: int = 1) -> bool:
	"""Add an item to the inventory. Returns true if successful."""
	if items.size() >= max_slots:
		return false
	
	items.append(item_name)
	item_levels[item_name] = level
	
	# Apply specific cropping for certain items
	var processed_texture = process_item_texture(item_name, texture, level)
	create_slot(processed_texture, item_name, level)
	
	update_inventory_display()
	item_added.emit(item_name)
	return true

func remove_item(item_name: String) -> bool:
	"""Remove an item from the inventory. Returns true if successful."""
	var index = items.find(item_name)
	if index == -1:
		return false
	
	items.remove_at(index)
	if index < slot_containers.size():
		slot_containers[index].queue_free()
		slot_containers.remove_at(index)
	
	update_inventory_display()
	item_removed.emit(item_name)
	return true

func create_slot(texture: Texture2D, item_name: String = "", level: int = 1):
	"""Create a new inventory slot with the given texture."""
	var slot_container = Control.new()
	var total_slot_size = slot_size + border_width * 2
	slot_container.custom_minimum_size = Vector2(total_slot_size, total_slot_size)
	slot_container.size = Vector2(total_slot_size, total_slot_size)
	
	# Create individual slot background with white border
	var slot_background = ColorRect.new()
	slot_background.position = Vector2(0, 0)
	slot_background.size = Vector2(total_slot_size, total_slot_size)
	slot_background.color = Color(1.0, 1.0, 1.0, 1.0)  # White border
	slot_container.add_child(slot_background)
	
	# Create inner background (black with alpha)
	var inner_bg = ColorRect.new()
	inner_bg.position = Vector2(border_width, border_width)
	inner_bg.size = Vector2(slot_size, slot_size)
	inner_bg.color = Color(0.0, 0.0, 0.0, 0.1)  # Black with 10% alpha
	slot_container.add_child(inner_bg)
	
	# Create the item icon with padding
	var texture_rect = TextureRect.new()
	texture_rect.texture = texture
	texture_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	
	# Add padding to the texture (10% on each side)
	var padding = slot_size * 0.1
	texture_rect.position = Vector2(border_width + padding, border_width + padding)
	texture_rect.size = Vector2(slot_size - padding * 2, slot_size - padding * 2)
	
	slot_container.add_child(texture_rect)
	
	# Add level indicator for items with levels > 1 (except axe which shows level through sprite)
	if level > 1 and item_name != "axe":
		var level_label = Label.new()
		level_label.text = str(level)
		level_label.add_theme_font_size_override("font_size", 16)
		level_label.add_theme_color_override("font_color", Color.YELLOW)
		level_label.add_theme_color_override("font_shadow_color", Color.BLACK)
		level_label.add_theme_constant_override("shadow_offset_x", 1)
		level_label.add_theme_constant_override("shadow_offset_y", 1)
		
		# Position level indicator in bottom-right corner
		level_label.position = Vector2(slot_size - 20, slot_size - 20)
		level_label.size = Vector2(20, 20)
		slot_container.add_child(level_label)
	
	# Add speed indicator for hourglass
	if item_name == "hourglass":
		var speed_label = Label.new()
		speed_label.text = str(level + 1) + "x"  # Speed is level + 1 (2x, 3x, etc.)
		var font_size = int(slot_size * 1.0)  # 100% of slot size (4x bigger than before)
		speed_label.add_theme_font_size_override("font_size", font_size)
		speed_label.add_theme_color_override("font_color", Color(0.0, 0.0, 0.0, 0.15))  # Black with 15% opacity (85% transparency)
		speed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		speed_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		
		# Position speed indicator centered both horizontally and vertically in the slot
		speed_label.position = Vector2(0, 0)
		speed_label.size = Vector2(total_slot_size, total_slot_size)
		slot_container.add_child(speed_label)
	
	add_child(slot_container)
	slot_containers.append(slot_container)

func update_inventory_display():
	"""Update the visual layout of inventory slots to keep them centered."""
	if slot_containers.size() == 0:
		return
	
	# Calculate total width needed for all slots (including their borders)
	var slot_total_size = slot_size + border_width * 2
	var total_width = slot_containers.size() * slot_total_size + (slot_containers.size() - 1) * slot_spacing
	
	# Get screen width from viewport
	var screen_width = get_viewport().get_visible_rect().size.x
	
	# Calculate starting X position to center the inventory
	var start_x = (screen_width - total_width) / 2
	
	# Position each slot
	for i in range(slot_containers.size()):
		var slot = slot_containers[i]
		var x_pos = start_x + i * (slot_total_size + slot_spacing)
		slot.position = Vector2(x_pos, 0)
		slot.size = Vector2(slot_total_size, slot_total_size)

func has_item(item_name: String) -> bool:
	"""Check if the inventory contains a specific item."""
	return items.has(item_name)

func get_item_count() -> int:
	"""Get the current number of items in the inventory."""
	return items.size()

func is_full() -> bool:
	"""Check if the inventory is full."""
	return items.size() >= max_slots

func clear_inventory():
	"""Remove all items from the inventory."""
	items.clear()
	for slot in slot_containers:
		slot.queue_free()
	slot_containers.clear()
	update_inventory_display()

func process_item_texture(item_name: String, texture: Texture2D, level: int = 1) -> Texture2D:
	"""Process item textures for specific items (e.g., crop axe to focus on blade)."""
	if item_name == "axe":
		# Load the correct texture based on level
		var axe_texture = load("res://assets/items/axe/" + str(level) + ".png")
		if axe_texture:
			return crop_texture_window(axe_texture, 0.4, 0.4)  # Crop 40% window starting at 40% from left
		else:
			return crop_texture_window(texture, 0.4, 0.4)
	elif item_name == "hourglass":
		# Center the hourglass by cropping some transparent space and shifting down slightly
		return crop_texture_window_with_vertical_offset(texture, 0.8, 0.1, 3)  # Crop 80% window starting at 10% from left, 3px down
	
	return texture  # Return original texture for other items

func crop_texture_window(texture: Texture2D, width_percentage: float, start_percentage: float) -> Texture2D:
	"""Crop a texture to show a window of specified width starting at specified position."""
	if not texture:
		return texture
	
	# Get the original image
	var image = texture.get_image()
	if not image:
		return texture
	
	var original_width = image.get_width()
	var original_height = image.get_height()
	
	# Calculate crop dimensions
	var crop_width = int(original_width * width_percentage)
	var crop_start_x = int(original_width * start_percentage)
	
	# Ensure we don't go beyond image bounds
	crop_start_x = clamp(crop_start_x, 0, original_width - crop_width)
	crop_width = clamp(crop_width, 1, original_width - crop_start_x)
	
	# Create new image with cropped dimensions
	var cropped_image = Image.create(crop_width, original_height, false, image.get_format())
	
	# Copy the specified window of the original image
	cropped_image.blit_rect(image, Rect2i(crop_start_x, 0, crop_width, original_height), Vector2i(0, 0))
	
	# Create new texture from cropped image
	var cropped_texture = ImageTexture.new()
	cropped_texture.set_image(cropped_image)
	
	return cropped_texture

func crop_texture_window_with_vertical_offset(texture: Texture2D, width_percentage: float, start_percentage: float, vertical_offset: int) -> Texture2D:
	"""Crop a texture to show a window of specified width starting at specified position with vertical offset."""
	if not texture:
		return texture
	
	# Get the original image
	var image = texture.get_image()
	if not image:
		return texture
	
	var original_width = image.get_width()
	var original_height = image.get_height()
	
	# Calculate crop dimensions for horizontal
	var crop_width = int(original_width * width_percentage)
	var crop_start_x = int(original_width * start_percentage)
	
	# Ensure we don't go beyond image bounds horizontally
	crop_start_x = clamp(crop_start_x, 0, original_width - crop_width)
	crop_width = clamp(crop_width, 1, original_width - crop_start_x)
	
	# Apply vertical offset
	var crop_start_y = clamp(vertical_offset, 0, original_height - 1)
	var crop_height = original_height - crop_start_y
	
	# Create new image with cropped dimensions
	var cropped_image = Image.create(crop_width, crop_height, false, image.get_format())
	
	# Copy the specified window of the original image
	cropped_image.blit_rect(image, Rect2i(crop_start_x, crop_start_y, crop_width, crop_height), Vector2i(0, 0))
	
	# Create new texture from cropped image
	var cropped_texture = ImageTexture.new()
	cropped_texture.set_image(cropped_image)
	
	return cropped_texture

func level_up_item(item_name: String) -> bool:
	"""Level up an item if it exists in inventory and can be leveled up."""
	var index = items.find(item_name)
	if index == -1:
		return false
	
	var current_level = item_levels.get(item_name, 1)
	var max_level = 5  # Default max level
	
	if current_level >= max_level:
		# Item already at max level
		return false
	
	# Increase level
	item_levels[item_name] = current_level + 1
	
	# Update the visual representation
	update_item_slot(index, item_name, item_levels[item_name])
	
	# Item leveled up
	return true

func update_item_slot(slot_index: int, item_name: String, level: int):
	"""Update a specific inventory slot with new level information."""
	if slot_index >= slot_containers.size():
		return
	
	# Remove old slot
	var old_slot = slot_containers[slot_index]
	old_slot.queue_free()
	
	# Create new slot with updated level
	var texture: Texture2D
	if item_name == "hourglass":
		# Hourglass uses the same texture for all levels
		texture = load("res://assets/items/hourglass/hourglass.png")
	else:
		# Other items have level-specific textures
		texture = load("res://assets/items/" + item_name + "/" + str(level) + ".png")
	
	if texture:
		var processed_texture = process_item_texture(item_name, texture, level)
		var new_slot = create_new_slot(processed_texture, item_name, level)
		
		# Replace in array
		slot_containers[slot_index] = new_slot
		
		# Update display
		update_inventory_display()

func create_new_slot(texture: Texture2D, item_name: String = "", level: int = 1) -> Control:
	"""Create a new inventory slot and return it (without adding to scene)."""
	var slot_container = Control.new()
	var total_slot_size = slot_size + border_width * 2
	slot_container.custom_minimum_size = Vector2(total_slot_size, total_slot_size)
	slot_container.size = Vector2(total_slot_size, total_slot_size)
	
	# Create individual slot background with white border
	var slot_background = ColorRect.new()
	slot_background.position = Vector2(0, 0)
	slot_background.size = Vector2(total_slot_size, total_slot_size)
	slot_background.color = Color(1.0, 1.0, 1.0, 1.0)  # White border
	slot_container.add_child(slot_background)
	
	# Create inner background (black with alpha)
	var inner_bg = ColorRect.new()
	inner_bg.position = Vector2(border_width, border_width)
	inner_bg.size = Vector2(slot_size, slot_size)
	inner_bg.color = Color(0.0, 0.0, 0.0, 0.1)  # Black with 10% alpha
	slot_container.add_child(inner_bg)
	
	# Create the item icon with padding
	var texture_rect = TextureRect.new()
	texture_rect.texture = texture
	texture_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	
	# Add padding to the texture (10% on each side)
	var padding = slot_size * 0.1
	texture_rect.position = Vector2(border_width + padding, border_width + padding)
	texture_rect.size = Vector2(slot_size - padding * 2, slot_size - padding * 2)
	
	slot_container.add_child(texture_rect)
	
	# Add level indicator for items with levels > 1 (except axe which shows level through sprite)
	if level > 1 and item_name != "axe":
		var level_label = Label.new()
		level_label.text = str(level)
		level_label.add_theme_font_size_override("font_size", 16)
		level_label.add_theme_color_override("font_color", Color.YELLOW)
		level_label.add_theme_color_override("font_shadow_color", Color.BLACK)
		level_label.add_theme_constant_override("shadow_offset_x", 1)
		level_label.add_theme_constant_override("shadow_offset_y", 1)
		
		# Position level indicator in bottom-right corner
		level_label.position = Vector2(slot_size - 20, slot_size - 20)
		level_label.size = Vector2(20, 20)
		slot_container.add_child(level_label)
	
	# Add speed indicator for hourglass
	if item_name == "hourglass":
		var speed_label = Label.new()
		speed_label.text = str(level + 1) + "x"  # Speed is level + 1 (2x, 3x, etc.)
		var font_size = int(slot_size * 1.0)  # 100% of slot size (4x bigger than before)
		speed_label.add_theme_font_size_override("font_size", font_size)
		speed_label.add_theme_color_override("font_color", Color(0.0, 0.0, 0.0, 0.15))  # Black with 15% opacity (85% transparency)
		speed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		speed_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		
		# Position speed indicator centered both horizontally and vertically in the slot
		speed_label.position = Vector2(0, 0)
		speed_label.size = Vector2(total_slot_size, total_slot_size)
		slot_container.add_child(speed_label)
	
	add_child(slot_container)
	return slot_container

func get_item_level(item_name: String) -> int:
	"""Get the current level of an item."""
	return item_levels.get(item_name, 1)

func update_item_level(item_name: String, new_level: int):
	"""Update an item's level and visual representation."""
	var index = items.find(item_name)
	if index == -1:
		return
	
	# Update the level
	item_levels[item_name] = new_level
	
	# Update the visual representation
	update_item_slot(index, item_name, new_level)
	
	# Item level updated in inventory

	
