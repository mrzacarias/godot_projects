extends StaticBody2D

signal campfire_health_changed(new_health: int)
signal campfire_extinguished
signal campfire_visuals_updated

# GameText is available globally via class_name

@onready var circle_outline = $SafeAreaCircle/CircleOutline
@onready var bonfire_light = $BonfireLight
@onready var fire_animation = $Fire
@onready var log_pile = $LogPile
@onready var animation_player = $AnimationPlayer
@onready var mob_collision_area = $MobCollisionArea
@onready var mob_collision_shape = $MobCollisionArea/CollisionShape2D

# Campfire health system
var max_health: int = 3
var current_health: int = 3
var base_light_scale: float = 54.0  # 50% bigger than current (36.0 * 1.5)

# Interaction system
@export var interaction_distance: float = 200.0  # Adjusted for optimal QoL (was 150.0 originally)
var player_nearby: bool = false
var player_node: Node2D = null
var prompt_label: Label = null

# Audio system
var light_fire_sound: AudioStreamPlayer

func _ready():
	update_campfire_visuals()
	
	# Setup campfire sound
	setup_campfire_sound()
	
	# Set up interaction system
	setup_interaction_area()
	setup_prompt_label()
	
	# Connect mob collision area signals
	if mob_collision_area:
		mob_collision_area.body_entered.connect(_on_mob_entered_safezone)
		mob_collision_area.body_exited.connect(_on_mob_exited_safezone)
	
	# Find player reference
	call_deferred("find_player")

func update_campfire_visuals():
	"""Update all campfire visuals based on current health"""
	update_light_size()
	update_circle_to_match_light()
	update_fire_animation()
	update_mob_collision_area()
	
	# Emit signal so game can update shader parameters
	campfire_visuals_updated.emit()

func update_light_size():
	"""Update the light size based on current health"""
	if not bonfire_light:
		return
	
	# Health scaling: 3hp=100%, 2hp=67%, 1hp=33%, 0hp=0%
	var scale_percentage: float
	if current_health == 0:
		scale_percentage = 0.0
	elif current_health == 1:
		scale_percentage = 0.33
	elif current_health == 2:
		scale_percentage = 0.67
	else:  # current_health == 3 (full health)
		scale_percentage = 1.0
	
	
	# Store the scale percentage for use in animation
	bonfire_light.set_meta("health_scale", scale_percentage)
	
	# Stop animation and set base values, then restart if needed
	if animation_player:
		animation_player.stop()
		if current_health == 0:
			bonfire_light.texture_scale = 0.0
			bonfire_light.energy = 0.0
		else:
			# Set base values and restart animation
			var target_texture_scale = base_light_scale * scale_percentage
			var target_energy = 0.768 * scale_percentage
			bonfire_light.texture_scale = target_texture_scale
			bonfire_light.energy = target_energy
			# Create a scaled flicker animation
			create_scaled_flicker_animation(scale_percentage)
			animation_player.play("scaled_flicker")
	else:
		# Fallback if no animation player
		bonfire_light.texture_scale = base_light_scale * scale_percentage
		bonfire_light.energy = 0.768 * scale_percentage
	
	bonfire_light.visible = current_health > 0

func update_fire_animation():
	"""Show/hide fire animation based on health"""
	if fire_animation:
		fire_animation.visible = current_health > 0
		if current_health > 0:
			fire_animation.play("burn")
		else:
			fire_animation.stop()

func update_circle_to_match_light():
	"""Update the safe zone circle to match the light coverage"""
	if not circle_outline or not bonfire_light:
		return
	
	if current_health == 0:
		circle_outline.points = PackedVector2Array()  # No safe zone when campfire is out
		return
	
	# Calculate radius to match the bonfire light's actual coverage
	var light_radius = bonfire_light.texture_scale * 24.2
	
	# Generate circle points
	var points = PackedVector2Array()
	var segments = 64
	
	for i in range(segments + 1):  # +1 to close the circle
		var angle = (i * 2.0 * PI) / segments
		var x = cos(angle) * light_radius
		var y = sin(angle) * light_radius
		points.append(Vector2(x, y))
	
	circle_outline.points = points

func damage_campfire(amount: int = 1):
	"""Reduce campfire health by specified amount"""
	current_health = max(0, current_health - amount)
	update_campfire_visuals()
	campfire_health_changed.emit(current_health)
	
	if current_health == 0:
		campfire_extinguished.emit()
		# Campfire has been extinguished

func add_fuel(wood_amount: int) -> bool:
	"""Add wood fuel to the campfire. 3 wood = 1 health point"""
	if wood_amount < 3:
		return false  # Need at least 3 wood
	
	var health_to_add = int(wood_amount / 3.0)  # Explicit integer division
	var _wood_consumed = health_to_add * 3  # Unused but kept for clarity
	
	# Don't exceed max health
	var actual_health_added = min(health_to_add, max_health - current_health)
	var _actual_wood_consumed = actual_health_added * 3
	
	if actual_health_added > 0:
		# Play light fire sound when wood is added
		if light_fire_sound:
			light_fire_sound.play()
		
		current_health += actual_health_added
		update_campfire_visuals()
		campfire_health_changed.emit(current_health)
		# Health added to campfire
		return true
	
	return false

func get_health() -> int:
	"""Get current campfire health"""
	return current_health

func is_safe_zone(pos: Vector2) -> bool:
	"""Check if a position is within the campfire's safe zone"""
	if current_health == 0:
		return false
	
	var distance = global_position.distance_to(pos)
	var safe_radius = bonfire_light.texture_scale * 24.2
	return distance <= safe_radius

func setup_interaction_area():
	"""Set up area for detecting player proximity"""
	var area = Area2D.new()
	area.name = "InteractionArea"
	area.collision_layer = 0  # Don't collide with anything
	area.collision_mask = 1   # Detect bodies on layer 1 (player)
	
	var area_collision = CollisionShape2D.new()
	var circle_shape = CircleShape2D.new()
	circle_shape.radius = interaction_distance
	area_collision.shape = circle_shape
	
	area.add_child(area_collision)
	add_child(area)
	
	# Connect area signals
	area.body_entered.connect(_on_interaction_area_body_entered)
	area.body_exited.connect(_on_interaction_area_body_exited)
	
	# Campfire interaction area set up

func setup_prompt_label():
	"""Create the 'add 5x wood' prompt label"""
	prompt_label = Label.new()
	prompt_label.add_theme_font_size_override("font_size", 120)  # 50% bigger (was 80)
	prompt_label.add_theme_color_override("font_color", Color.WHITE)
	prompt_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	prompt_label.add_theme_constant_override("shadow_offset_x", 8)  # Scaled shadow offset
	prompt_label.add_theme_constant_override("shadow_offset_y", 8)
	
	# Position above the campfire - will be dynamically centered based on text
	prompt_label.size = Vector2(400, 120)  # Give enough space for any text
	prompt_label.position = Vector2(-200, -410)  # Initial position, will be adjusted
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.visible = false
	
	add_child(prompt_label)

func find_player():
	"""Find the player node in the scene"""
	var game_node = get_parent()
	if game_node and game_node.has_node("%Player"):
		player_node = game_node.get_node("%Player")
		# Campfire found player node
	else:
		# Campfire could not find player node
		pass

func _process(_delta):
	# Update prompt visibility and text based on player proximity and campfire state
	# Also check direct distance as backup in case Area2D signals aren't working
	var should_show_prompt = false
	
	if prompt_label and player_node:
		var distance_to_player = global_position.distance_to(player_node.global_position)
		should_show_prompt = distance_to_player <= interaction_distance
		
		# Use either the Area2D detection or direct distance check
		if should_show_prompt or player_nearby:
			update_prompt_text()
			prompt_label.visible = true
		else:
			prompt_label.visible = false
	elif prompt_label:
		prompt_label.visible = false

func update_prompt_text():
	"""Update the prompt text based on campfire state and available wood"""
	if not prompt_label:
		return
	
	# Get wood amount from player's inventory
	var game_node = get_parent()
	var wood_amount = 0
	if game_node and game_node.has_node("%HUD"):
		var hud = game_node.get_node("%HUD")
		if hud.has_method("get_material_amount"):
			wood_amount = hud.get_material_amount(GameText.MATERIAL_WOOD)
	
	# Set the text first
	if current_health >= max_health:
		prompt_label.text = GameText.CAMPFIRE_FULL
	elif wood_amount < 3:
		prompt_label.text = GameText.NEED_WOOD
	else:
		prompt_label.text = GameText.ADD_WOOD
	
	# Calculate the actual text size and center the label
	center_label_with_text()

func _input(event):
	# Handle interaction input when player is nearby
	var player_in_range = false
	if player_node:
		var distance_to_player = global_position.distance_to(player_node.global_position)
		player_in_range = distance_to_player <= interaction_distance
	
	if (player_in_range or player_nearby) and current_health < max_health:
		if event.is_action_pressed("confirm_action"):
			try_add_fuel()
		elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			# Check if mouse click is on the campfire (50% bigger hit area for touch screens)
			var mouse_pos = get_global_mouse_position()
			var campfire_rect = Rect2(global_position - Vector2(90, 90), Vector2(180, 180))
			if campfire_rect.has_point(mouse_pos):
				try_add_fuel()

func _on_interaction_area_body_entered(body):
	"""Called when something enters the interaction area"""
	# Body entered interaction area
	# Player node reference logged
	if body == player_node:
		player_nearby = true
		# Player entered campfire area
	else:
		# Body is not the player node
		pass

func _on_interaction_area_body_exited(body):
	"""Called when something exits the interaction area"""
	if body == player_node:
		player_nearby = false
		# Player exited campfire area

func create_scaled_flicker_animation(scale_percentage: float):
	"""Create a flicker animation scaled to the current health"""
	if not animation_player:
		return
	
	# Get the animation library
	var library = animation_player.get_animation_library("")
	if not library:
		return
	
	# Create a new scaled animation or modify existing one
	var scaled_animation = Animation.new()
	scaled_animation.resource_name = "scaled_flicker"
	scaled_animation.length = 2.0
	scaled_animation.loop_mode = Animation.LOOP_LINEAR
	
	# Base values scaled by health
	var base_energy = 0.768 * scale_percentage
	var base_texture_scale = base_light_scale * scale_percentage
	
	# Energy track
	var energy_track = scaled_animation.add_track(Animation.TYPE_VALUE)
	scaled_animation.track_set_path(energy_track, NodePath("BonfireLight:energy"))
	
	# Texture scale track
	var texture_track = scaled_animation.add_track(Animation.TYPE_VALUE)
	scaled_animation.track_set_path(texture_track, NodePath("BonfireLight:texture_scale"))
	
	# Add keyframes with scaled values (same pattern as original but scaled)
	var times = [0.0, 0.1, 0.3, 0.5, 0.7, 0.9, 1.2, 1.5, 1.8, 2.0]
	var energy_multipliers = [1.0, 0.9, 1.1, 0.95, 1.05, 0.85, 1.15, 0.975, 1.0, 0.925]
	var texture_multipliers = [1.0, 0.967, 1.033, 0.983, 1.017, 0.95, 1.05, 0.992, 1.0, 0.975]
	
	for i in range(times.size()):
		scaled_animation.track_insert_key(energy_track, times[i], base_energy * energy_multipliers[i])
		scaled_animation.track_insert_key(texture_track, times[i], base_texture_scale * texture_multipliers[i])
	
	# Add the animation to the library
	library.add_animation("scaled_flicker", scaled_animation)

func center_label_with_text():
	"""Center the label based on the actual text size"""
	if not prompt_label:
		return
	
	# Get the theme font to calculate text size
	var font = prompt_label.get_theme_font("font")
	if not font:
		# Fallback to default font
		font = ThemeDB.fallback_font
	
	var font_size = prompt_label.get_theme_font_size("font_size")
	if font_size <= 0:
		font_size = 80  # Our set font size
	
	# Calculate the actual text width
	var text_size = font.get_string_size(prompt_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	
	# Center the label based on actual text width
	var centered_x = -text_size.x / 2.0
	prompt_label.position.x = centered_x
	
	# Keep the Y position the same
	prompt_label.position.y = -410

func try_add_fuel():
	"""Try to add fuel to the campfire"""
	var game_node = get_parent()
	if not game_node:
		return
	
	# Use the game's fuel function
	if game_node.has_method("try_fuel_campfire"):
		game_node.try_fuel_campfire()

# Call this function if the light size changes to update the circle
func refresh_circle():
	update_circle_to_match_light()

func update_mob_collision_area():
	"""Update the mob collision area to match the safezone size"""
	if not mob_collision_area or not mob_collision_shape:
		return
	
	if current_health == 0:
		# Disable monitoring when campfire is extinguished
		mob_collision_area.monitoring = false
	else:
		# Enable monitoring and resize to match safezone
		mob_collision_area.monitoring = true
		
		# Calculate safe radius (same as is_safe_zone function)
		var safe_radius = bonfire_light.texture_scale * 24.2
		
		# Update collision shape radius
		if mob_collision_shape.shape is CircleShape2D:
			var circle_shape = mob_collision_shape.shape as CircleShape2D
			circle_shape.radius = safe_radius

func _on_mob_entered_safezone(body):
	"""Handle when a mob enters the safezone - mark it as blocked"""
	if current_health == 0:
		return  # No safezone when campfire is extinguished
	
	# Check if it's a mob (has the mob script or is in mobs group) - but NOT a boss
	if body.has_method("take_damage") and body.get_script():
		var script_path = str(body.get_script().get_path())
		# Only affect mobs, not bosses
		if "mob.gd" in script_path and "boss.gd" not in script_path:
			# Mark mob as being in safezone (it will handle the blocking itself)
			if body.has_method("set_in_safezone"):
				body.set_in_safezone(true, global_position, bonfire_light.texture_scale * 24.2)

func _on_mob_exited_safezone(body):
	"""Handle when a mob exits the safezone"""
	# Check if it's a mob and unmark it - but NOT a boss
	if body.has_method("take_damage") and body.get_script():
		var script_path = str(body.get_script().get_path())
		# Only affect mobs, not bosses
		if "mob.gd" in script_path and "boss.gd" not in script_path:
			if body.has_method("set_in_safezone"):
				body.set_in_safezone(false, Vector2.ZERO, 0.0)

func setup_campfire_sound():
	"""Setup the light fire sound effect"""
	light_fire_sound = AudioStreamPlayer.new()
	light_fire_sound.name = "LightFireSound"
	light_fire_sound.volume_db = 0.0
	light_fire_sound.stream = load("res://assets/sounds/light_fire.mp3")
	add_child(light_fire_sound)
