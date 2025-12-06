extends StaticBody2D

signal chest_opened(chest_node)

# GameText is available globally via class_name
const HealthClass = preload("res://items/health.gd")
const SpeedClass = preload("res://items/speed.gd")

@export var is_opened: bool = false
@export var interaction_distance: float = GameConstants.INTERACTION_DISTANCE  # Interaction distance

var closed_texture: Texture2D
var opened_texture: Texture2D
var player_nearby: bool = false
var player_node: Node2D = null
var prompt_label: Label = null

# Audio system
var item_pickup_sound: AudioStreamPlayer

func _ready():
	# Load chest textures
	closed_texture = load("res://assets/items/chest/closed.png")
	opened_texture = load("res://assets/items/chest/open.png")
	
	# Setup chest sound
	setup_chest_sound()
	
	# Set initial sprite
	if has_node("Sprite2D"):
		$Sprite2D.texture = closed_texture
	
	# Create collision shape
	setup_collision()
	
	# Create interaction area
	setup_interaction_area()
	
	# Create prompt label (initially hidden)
	setup_prompt_label()
	
	# Find player reference
	call_deferred("find_player")

func setup_collision():
	"""Set up collision shape for the chest"""
	if not has_node("CollisionShape2D"):
		var collision_shape = CollisionShape2D.new()
		var rect_shape = RectangleShape2D.new()
		rect_shape.size = Vector2(36, 24)  # 60% of original size (60x40 -> 36x24)
		collision_shape.shape = rect_shape
		add_child(collision_shape)

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
	prompt_label.text = GameText.CHEST_OPEN
	prompt_label.add_theme_font_size_override("font_size", 45)  # 50% bigger (was 30)
	prompt_label.add_theme_color_override("font_color", Color.WHITE)
	prompt_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	prompt_label.add_theme_constant_override("shadow_offset_x", 2)
	prompt_label.add_theme_constant_override("shadow_offset_y", 2)
	
	# Position above the chest (40px higher total, centered based on size)
	# With font size 45, need wider label to fit text properly
	prompt_label.size = Vector2(100, 50)
	prompt_label.position = Vector2(-58, -110)
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.visible = false
	
	add_child(prompt_label)

func find_player():
	"""Find the player node in the scene"""
	var game_node = get_parent()
	if game_node and game_node.has_node("%Player"):
		player_node = game_node.get_node("%Player")

func _process(_delta):
	# Update prompt visibility based on player proximity and chest state
	if prompt_label:
		prompt_label.visible = player_nearby and not is_opened

func _input(event):
	# Handle interaction input when player is nearby
	if player_nearby and not is_opened:
		if event.is_action_pressed("confirm_action"):
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
	"""Open the chest and give item to player"""
	if is_opened:
		return
	
	is_opened = true
	
	# Change sprite to opened chest
	if has_node("Sprite2D"):
		$Sprite2D.texture = opened_texture
	
	# Give flashlight to player
	give_item_to_player()
	
	# Hide prompt
	if prompt_label:
		prompt_label.visible = false
	
	# Emit signal
	chest_opened.emit(self)

func give_item_to_player():
	"""Give a random item to the player"""
	if not player_node:
		return
	
	# Ensure random seed is different each time
	randomize()
	
	# Get the HUD
	var game_node = get_parent()
	if not game_node or not game_node.has_node("%HUD"):
		return
		
	var hud = game_node.get_node("%HUD")
	var inventory = hud.get_inventory()
	
	# Define available items with equal probability
	var available_items = []
	
	# Check if flashlight is already in inventory
	var has_flashlight = inventory and inventory.has_method("has_item") and inventory.has_item(GameText.ITEM_FLASHLIGHT)
	if not has_flashlight:
		available_items.append(GameText.ITEM_FLASHLIGHT)
	
	# Check if hourglass is at max level before adding it
	if game_node and game_node.hourglass_item and not game_node.hourglass_item.is_at_max_level():
		available_items.append(GameText.ITEM_HOURGLASS)
	
	# Check if player can benefit from wood (under wood cap)
	if hud and hud.has_method("get_material_amount"):
		var current_wood = hud.get_material_amount(GameText.MATERIAL_WOOD)
		if current_wood < GameConstants.MAX_WOOD_CAP:
			available_items.append(GameText.MATERIAL_WOOD)
	
	# Check if player can benefit from rock (under rock cap)
	if hud and hud.has_method("get_material_amount"):
		var current_rock = hud.get_material_amount(GameText.MATERIAL_ROCK)
		if current_rock < GameConstants.MAX_ROCK_CAP:
			available_items.append(GameText.MATERIAL_ROCK)
	
	# Check if player can benefit from health item (under health cap or needs healing)
	if player_node:
		var health_item = HealthClass.new()
		if health_item.can_give_to_player(player_node):
			available_items.append(GameText.ITEM_HEALTH)
		health_item.queue_free()
	
	# Check if player can benefit from speed item (under speed cap)
	if player_node:
		var speed_item = SpeedClass.new()
		if speed_item.can_give_to_player(player_node):
			available_items.append(GameText.ITEM_SPEED)
		speed_item.queue_free()
	
	available_items.append(GameText.ITEM_AXE_UPGRADE)
	
	# Select random item
	if available_items.size() == 0:
		return
	
	var random_index = randi() % available_items.size()
	var selected_item = available_items[random_index]
	match selected_item:
		GameText.ITEM_FLASHLIGHT:
			give_flashlight(hud, game_node)
		GameText.ITEM_HOURGLASS:
			give_hourglass(hud, game_node)
		GameText.MATERIAL_WOOD:
			give_wood_bundle(hud)
		GameText.MATERIAL_ROCK:
			give_rock_bundle(hud)
		GameText.ITEM_HEALTH:
			give_health(hud, game_node)
		GameText.ITEM_SPEED:
			give_speed(hud, game_node)
		GameText.ITEM_AXE_UPGRADE:
			give_axe_upgrade(hud)

func give_flashlight(hud, game_node):
	"""Give flashlight to player"""
	if game_node and game_node.flashlight_item:
		game_node.flashlight_item.give_to_player(hud)
		# Play item pickup sound
		if item_pickup_sound:
			item_pickup_sound.play()

func give_hourglass(hud, game_node):
	"""Give hourglass to player"""
	if game_node and game_node.hourglass_item:
		game_node.hourglass_item.give_to_player(hud, game_node)
		# Play item pickup sound
		if item_pickup_sound:
			item_pickup_sound.play()

func give_wood_bundle(hud):
	"""Give wood bundle to player (5 wood)"""
	if hud.has_method("add_material_to_inventory"):
		var current_wood = hud.get_material_amount(GameText.MATERIAL_WOOD)
		if current_wood >= GameConstants.MAX_WOOD_CAP:
			hud.show_message("Wood storage full! (%d/%d)" % [current_wood, GameConstants.MAX_WOOD_CAP])
		else:
			hud.add_material_to_inventory(GameText.MATERIAL_WOOD, 5)
			hud.show_message(GameText.FOUND_WOOD)
			# Play item pickup sound
			if item_pickup_sound:
				item_pickup_sound.play()

func give_rock_bundle(hud):
	"""Give rock bundle to player (3 rocks)"""
	if hud.has_method("add_material_to_inventory"):
		var current_rock = hud.get_material_amount(GameText.MATERIAL_ROCK)
		if current_rock >= GameConstants.MAX_ROCK_CAP:
			hud.show_message("Rock storage full! (%d/%d)" % [current_rock, GameConstants.MAX_ROCK_CAP])
		else:
			hud.add_material_to_inventory(GameText.MATERIAL_ROCK, 3)
			hud.show_message(GameText.FOUND_ROCKS)
			# Play item pickup sound
			if item_pickup_sound:
				item_pickup_sound.play()

func give_health(hud, game_node):
	"""Give health to player (restore health)"""
	var player = game_node.get_node("%Player") if game_node else null
	if not player:
		return
	
	# Create health item instance and use it
	var health_item = HealthClass.new()
	health_item.give_to_player(hud, player)
	health_item.queue_free()  # Clean up temporary instance
	
	# Play item pickup sound
	if item_pickup_sound:
		item_pickup_sound.play()

func give_speed(hud, game_node):
	"""Give speed to player (increase speed)"""
	var player = game_node.get_node("%Player") if game_node else null
	if not player:
		return
	
	# Create speed item instance and use it
	var speed_item = SpeedClass.new()
	speed_item.give_to_player(hud, player)
	speed_item.queue_free()  # Clean up temporary instance
	
	# Play item pickup sound
	if item_pickup_sound:
		item_pickup_sound.play()

func give_axe_upgrade(hud):
	"""Give axe upgrade to player (level up axe by 1)"""
	var player = get_parent().get_node("%Player") if get_parent() else null
	if player and player.has_method("level_up_axe"):
		var success = player.level_up_axe()
		if success:
			hud.show_message(GameText.FOUND_BETTER_AXE)
		else:
			# Axe might be at max level, give wood instead as fallback
			hud.show_message(GameText.FOUND_WOOD)
			hud.add_material_to_inventory(GameText.MATERIAL_WOOD, 3)
	else:
		# Fallback if level_up_axe doesn't exist - give wood
		hud.show_message(GameText.FOUND_WOOD)
		if hud.has_method("add_material_to_inventory"):
			hud.add_material_to_inventory(GameText.MATERIAL_WOOD, 3)
	
	# Play item pickup sound
	if item_pickup_sound:
		item_pickup_sound.play()

func reset_chest():
	"""Reset the chest to closed state for a new day"""
	is_opened = false
	player_nearby = false
	
	# Reset sprite to closed
	if has_node("Sprite2D"):
		$Sprite2D.texture = closed_texture
	
	# Hide prompt
	if prompt_label:
		prompt_label.visible = false

func set_position_safe(new_position: Vector2, player_position: Vector2, min_distance: float = 700.0):
	"""Set chest position ensuring it's at least min_distance away from player"""
	var distance = new_position.distance_to(player_position)
	if distance >= min_distance:
		global_position = new_position
		return true
	else:
		# Position is too close, need to find a new one
		return false

func setup_chest_sound():
	"""Setup the item pickup sound effect"""
	item_pickup_sound = AudioStreamPlayer.new()
	item_pickup_sound.name = "ItemPickupSound"
	item_pickup_sound.volume_db = 0.0
	item_pickup_sound.stream = load("res://assets/sounds/item_pickup.mp3")
	add_child(item_pickup_sound)
