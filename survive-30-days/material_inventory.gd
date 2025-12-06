extends Control

signal material_added(material_name: String, amount: int)
signal material_removed(material_name: String, amount: int)

@export var icon_size: int = 72  # 50% bigger (was 48)
@export var icon_spacing: int = 15  # 50% bigger (was 10)
@export var padding_from_top: int = 15  # 50% bigger (was 10)

# Dictionary to store material amounts
var materials: Dictionary = {}
# Array to store material display containers
var material_containers: Array[Control] = []
# Dictionary to store material textures
var material_textures: Dictionary = {}

func _ready():
	# Initialize with wood and rock materials (starting at 0)
	add_material("wood", 0)
	add_material("rock", 0)
	# Use call_deferred to ensure positioning happens after the scene is fully ready
	call_deferred("update_material_display")

func add_material(material_name: String, amount: int = 1):
	"""Add a material to the inventory or increase its amount."""
	# Adding material to inventory
	# Current materials state logged
	
	# Check caps for specific materials
	var max_cap = get_material_cap(material_name)
	var current_amount = materials.get(material_name, 0)
	
	if max_cap > 0 and current_amount >= max_cap:
		# Material at capacity limit
		return
	
	# Limit amount to not exceed cap
	if max_cap > 0:
		amount = min(amount, max_cap - current_amount)
		if amount <= 0:
			# No amount to add after cap check
			return
	
	if materials.has(material_name):
		materials[material_name] += amount
		# Updated existing material
	else:
		materials[material_name] = amount
		# Added new material
		# Load texture for new material
		load_material_texture(material_name)
		# Create display container for new material
		create_material_container(material_name)
	
	# Updating container for material
	update_material_container(material_name)
	update_material_display()  # Ensure positioning is updated
	material_added.emit(material_name, amount)
	# Material added to inventory

func remove_material(material_name: String, amount: int = 1) -> bool:
	"""Remove a material from the inventory. Returns true if successful."""
	if not materials.has(material_name) or materials[material_name] < amount:
		# Insufficient material to remove
		return false
	
	materials[material_name] -= amount
	update_material_container(material_name)
	material_removed.emit(material_name, amount)
	# Material removed from inventory
	return true

func get_material_amount(material_name: String) -> int:
	"""Get the current amount of a specific material."""
	return materials.get(material_name, 0)

func has_material(material_name: String, amount: int = 1) -> bool:
	"""Check if the inventory has at least the specified amount of a material."""
	return materials.get(material_name, 0) >= amount

func get_material_cap(material_name: String) -> int:
	"""Get the maximum cap for a specific material."""
	match material_name:
		GameText.MATERIAL_WOOD:
			return GameConstants.MAX_WOOD_CAP
		GameText.MATERIAL_ROCK:
			return GameConstants.MAX_ROCK_CAP
		_:
			return 0  # No cap for other materials

func load_material_texture(material_name: String):
	"""Load the texture for a material."""
	var texture_path = "res://assets/items/materials/" + material_name + ".png"
	var texture = load(texture_path)
	if texture:
		material_textures[material_name] = texture
		# Texture loaded for material
	else:
		print("Warning: Could not load texture for ", material_name, " at ", texture_path)

func create_material_container(material_name: String):
	"""Create a visual container for a material."""
	# Creating material container
	var container = Control.new()
	container.name = material_name + "_container"
	# Container created
	container.custom_minimum_size = Vector2(icon_size + 200, icon_size)  # Include space for larger text label
	container.size = Vector2(icon_size + 170, icon_size)  # More space for 36px text
	
	# Create material icon
	var icon = TextureRect.new()
	icon.name = "icon"
	icon.size = Vector2(icon_size, icon_size)
	icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	
	if material_textures.has(material_name):
		icon.texture = material_textures[material_name]
	
	container.add_child(icon)
	
	# Create amount label
	var label = Label.new()
	label.name = "amount_label"
	label.text = "x 0"
	label.add_theme_font_size_override("font_size", 36)  # Another 50% bigger (was 24)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", 3)  # Another 50% bigger (was 2)
	label.add_theme_constant_override("shadow_offset_y", 3)  # Another 50% bigger (was 2)
	
	# Position label to the right of the icon (15px more to the right, was 20px but proportionally 30px)
	label.position = Vector2(icon_size + 30, (icon_size - 36) / 2.0)  # Center vertically, adjusted for new font size (36)
	label.size = Vector2(135, 45)  # Give enough space for "x 999" - 50% bigger again (was 90x30)
	
	container.add_child(label)
	
	add_child(container)
	material_containers.append(container)
	# Container added to scene
	# Container positioned in scene

func update_material_container(material_name: String):
	"""Update the visual representation of a material."""
	# Updating material container
	
	# Find the container by looking through our tracked containers
	var container = null
	var material_keys = materials.keys()
	var material_index = -1
	
	for i in range(material_keys.size()):
		if material_keys[i] == material_name:
			material_index = i
			break
	
	if material_index >= 0 and material_index < material_containers.size():
		container = material_containers[material_index]
		# Found container at index
	else:
		print("ERROR: Container not found for ", material_name, " at index ", material_index)
		# Available containers logged
		# Material keys logged
		return
	
	if not container or not is_instance_valid(container):
		print("ERROR: Container is null or invalid")
		return
	
	var label = container.get_node("amount_label")
	if label:
		var new_text = "x " + str(materials[material_name])
		# Setting label text
		label.text = new_text
	else:
		print("ERROR: Label not found in container for ", material_name)

func update_material_display():
	"""Update the position of all material containers."""
	# Since the Control node is now anchored to top-right, we position relative to it
	var start_y = padding_from_top
	# Calculating material display positioning
	
	for i in range(material_containers.size()):
		var container = material_containers[i]
		if container and is_instance_valid(container):
			# Position relative to the anchored control (which is already in top-right)
			var x_pos = -40
			var y_pos = start_y + i * (icon_size + icon_spacing)
			container.position = Vector2(x_pos, y_pos)
			# Positioning material container

func clear_materials():
	"""Clear all materials from the inventory."""
	materials.clear()
	for container in material_containers:
		if container and is_instance_valid(container):
			container.queue_free()
	material_containers.clear()
	material_textures.clear()
	
	# Re-initialize with wood and rock
	add_material("wood", 0)
	add_material("rock", 0)

func _on_viewport_size_changed():
	"""Handle viewport size changes to reposition materials."""
	update_material_display()

# Connect to viewport size changes
func _enter_tree():
	get_viewport().size_changed.connect(_on_viewport_size_changed)

func _exit_tree():
	if get_viewport().size_changed.is_connected(_on_viewport_size_changed):
		get_viewport().size_changed.disconnect(_on_viewport_size_changed)
