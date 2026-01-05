extends StaticBody2D

# Chest object for Let it Climb - contains resources and blueprints

signal chest_opened(chest_node)

@export var is_opened: bool = false
@export var interaction_distance: float = 150.0

var closed_texture: Texture2D
var opened_texture: Texture2D
var player_nearby: bool = false
var player_node: Node2D = null
var prompt_label: Label = null

func _ready():
	# Load chest textures
	closed_texture = load("res://assets/items/closed.png")
	opened_texture = load("res://assets/items/open.png")
	
	# Set initial sprite
	if has_node("Sprite2D"):
		$Sprite2D.texture = closed_texture
	
	# Create interaction area
	setup_interaction_area()
	
	# Create prompt label
	setup_prompt_label()
	
	# Find player reference
	call_deferred("find_player")

func setup_interaction_area():
	"""Set up area for detecting player proximity"""
	var area = Area2D.new()
	area.name = "InteractionArea"
	
	var area_collision = CollisionShape2D.new()
	var circle_shape = CircleShape2D.new()
	circle_shape.radius = interaction_distance
	area_collision.shape = circle_shape
	
	area.add_child(area_collision)
	add_child(area)
	
	# Connect area signals
	area.body_entered.connect(_on_interaction_area_body_entered)
	area.body_exited.connect(_on_interaction_area_body_exited)

func setup_prompt_label():
	"""Create the 'open' prompt label"""
	prompt_label = Label.new()
	prompt_label.text = "Press ENTER or Click to Open"
	prompt_label.add_theme_font_size_override("font_size", 24)
	prompt_label.add_theme_color_override("font_color", Color.WHITE)
	prompt_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	prompt_label.add_theme_constant_override("shadow_offset_x", 2)
	prompt_label.add_theme_constant_override("shadow_offset_y", 2)
	
	# Position above the chest
	prompt_label.size = Vector2(200, 30)
	prompt_label.position = Vector2(-100, -80)
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.visible = false
	
	add_child(prompt_label)

func find_player():
	"""Find the player node"""
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player_node = players[0]

func _process(_delta):
	"""Update prompt visibility based on player proximity and chest state"""
	if prompt_label:
		prompt_label.visible = player_nearby and not is_opened

func _input(event):
	"""Handle input for chest interaction"""
	if player_nearby and not is_opened:
		if event.is_action_pressed("ui_accept"):
			open_chest()
		elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			# Check if mouse click is on the chest (50% bigger hit area for touch screens)
			var mouse_pos = get_global_mouse_position()
			var chest_rect = Rect2(global_position - Vector2(45, 30), Vector2(90, 60))
			if chest_rect.has_point(mouse_pos):
				open_chest()
				# Consume the input event to prevent player movement
				get_viewport().set_input_as_handled()

func _on_interaction_area_body_entered(body):
	"""Called when something enters the interaction area"""
	if body == player_node:
		player_nearby = true

func _on_interaction_area_body_exited(body):
	"""Called when something exits the interaction area"""
	if body == player_node:
		player_nearby = false

func open_chest():
	"""Open the chest and give items to player"""
	if is_opened:
		return
	
	is_opened = true
	
	# Change sprite to opened chest
	if has_node("Sprite2D"):
		$Sprite2D.texture = opened_texture
	
	# Give items to player
	give_items_to_player()
	
	# Hide prompt
	if prompt_label:
		prompt_label.visible = false
	
	# Emit signal
	chest_opened.emit(self)

func give_items_to_player():
	"""Give random resources and possibly blueprints to the player"""
	if not player_node:
		return
	
	print("Chest opened! Giving items to player...")
	
	# For now, just print what would be given
	# This will be expanded when we implement the inventory system
	
	# Determine what to give based on floor level and luck
	var floor_level = get_floor_level()
	var luck_multiplier = get_player_luck_multiplier()
	
	# Give resources
	give_resources(floor_level, luck_multiplier)
	
	# Chance for blueprints (higher on higher floors)
	var blueprint_chance = 0.1 + (floor_level - 1) * 0.05  # 10% base, +5% per floor
	if randf() < blueprint_chance * luck_multiplier:
		give_blueprint(floor_level)

func give_resources(floor_level: int, luck_multiplier: float):
	"""Give resources to player"""
	# Number of resource stacks (1-3, higher floors give more)
	var num_stacks = randi_range(1, min(3, 1 + floor_level / 5.0))
	
	for i in range(num_stacks):
		var resource_type = get_random_resource_type(floor_level)
		var amount = get_resource_amount(resource_type, floor_level, luck_multiplier)
		
		print("Giving %d x %s" % [amount, GameConstants.RESOURCES[resource_type].name])
		
		# TODO: Actually give to player inventory when implemented
		# player_node.add_resource(resource_type, amount)

func give_blueprint(floor_level: int):
	"""Give a random blueprint to player"""
	# Determine blueprint type based on floor
	var blueprint_type = get_random_blueprint_type(floor_level)
	
	print("Giving blueprint: %s" % get_blueprint_name(blueprint_type))
	
	# TODO: Actually give to player inventory when implemented
	# player_node.add_blueprint(blueprint_type)

func get_random_resource_type(floor_level: int) -> GameConstants.ResourceType:
	"""Get a random resource type weighted by floor level"""
	var weights = []
	
	# Common resources (always available)
	weights.append({"type": GameConstants.ResourceType.SIMPLE_WOOD, "weight": 30})
	weights.append({"type": GameConstants.ResourceType.IRON, "weight": 30})
	
	# Uncommon resources (floor 3+)
	if floor_level >= 3:
		weights.append({"type": GameConstants.ResourceType.RED_WOOD, "weight": 20})
		weights.append({"type": GameConstants.ResourceType.STEEL, "weight": 20})
	
	# Rare resources (floor 5+)
	if floor_level >= 5:
		weights.append({"type": GameConstants.ResourceType.DARK_WOOD, "weight": 10})
		weights.append({"type": GameConstants.ResourceType.DARK_STEEL, "weight": 10})
	
	# Elemental stones (floor 7+)
	if floor_level >= 7:
		weights.append({"type": GameConstants.ResourceType.FIRE_STONE, "weight": 5})
		weights.append({"type": GameConstants.ResourceType.ICE_STONE, "weight": 5})
		weights.append({"type": GameConstants.ResourceType.LIGHTNING_STONE, "weight": 5})
	
	# Select weighted random
	var total_weight = 0
	for item in weights:
		total_weight += item.weight
	
	var random_value = randi_range(1, total_weight)
	var current_weight = 0
	
	for item in weights:
		current_weight += item.weight
		if random_value <= current_weight:
			return item.type
	
	# Fallback
	return GameConstants.ResourceType.SIMPLE_WOOD

func get_resource_amount(resource_type: GameConstants.ResourceType, floor_level: int, luck_multiplier: float) -> int:
	"""Get amount of resource to give"""
	var base_amount = 0
	var resource_data = GameConstants.RESOURCES[resource_type]
	
	match resource_data.rarity:
		GameConstants.ResourceRarity.COMMON:
			base_amount = randi_range(3, 7)
		GameConstants.ResourceRarity.UNCOMMON:
			base_amount = randi_range(2, 5)
		GameConstants.ResourceRarity.RARE:
			base_amount = randi_range(1, 3)
	
	# Apply floor and luck bonuses
	var floor_bonus = floor_level * 0.2
	var final_amount = int(base_amount * (1.0 + floor_bonus) * luck_multiplier)
	
	return max(1, min(final_amount, GameConstants.MAX_STACK_SIZE))

func get_random_blueprint_type(floor_level: int):
	"""Get a random blueprint type based on floor level"""
	# For now, return a placeholder
	# This will be expanded when we implement the full blueprint system
	if floor_level <= 5:
		return "weapon_upgrade"
	else:
		return "accessory_blueprint"

func get_blueprint_name(blueprint_type) -> String:
	"""Get display name for blueprint"""
	match blueprint_type:
		"weapon_upgrade":
			return "Weapon Upgrade Blueprint"
		"accessory_blueprint":
			return "Accessory Blueprint"
		_:
			return "Unknown Blueprint"

func get_floor_level() -> int:
	"""Get current floor level from tower scene"""
	var tower_scene = get_tree().get_first_node_in_group("tower")
	if tower_scene and tower_scene.has_method("get") and "current_floor" in tower_scene:
		return tower_scene.current_floor
	return 1

func get_player_luck_multiplier() -> float:
	"""Get player's luck multiplier"""
	if player_node and player_node.has_method("get") and "character" in player_node:
		var character = player_node.character
		if character and character.has_method("get_luck_multiplier"):
			return character.get_luck_multiplier()
	return 1.0

func can_be_opened() -> bool:
	"""Check if chest can be opened"""
	return not is_opened and player_nearby
