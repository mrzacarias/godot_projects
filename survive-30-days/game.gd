extends Node2D

# GameText is available globally via class_name

var score = 0.0
var best_score = 0.0
var best_day = 1
var game_started = false
var is_player_dying = false  # Hide everything when player is dying
var death_overlay: ColorRect  # Black background for death sequence
var player_start_position = Vector2(2160, 1640)  # Below campfire (center + 200px down) - updated for larger world
var win_day = GameConstants.WIN_DAY  # Need to reach day 30 to win

# Tree management variables
var tree_scene = preload("res://objects/tree.tscn")
var current_trees = []
var current_day = 0
var world_size = Vector2(4320, 2880)  # 50% bigger world size (was 2880x1920)
var min_tree_distance = GameConstants.MIN_TREE_DISTANCE

# Boulder management variables
var boulder_scene = preload("res://objects/boulder.tscn")
var current_boulders = []
var min_boulder_distance = GameConstants.MIN_BOULDER_DISTANCE
var min_boulder_tree_distance = GameConstants.MIN_BOULDER_TREE_DISTANCE  # Minimum distance from trees

# Chest management variables
var chest_scene = preload("res://objects/chest.tscn")
var current_chests: Array[Node2D] = []
var chests_per_day = GameConstants.CHESTS_PER_DAY
var chest_min_distance = GameConstants.CHEST_MIN_DISTANCE  # Minimum distance from campfire
var campfire_position = Vector2(2160, 1440)  # Campfire position (center of world)
var chest_min_distance_between = GameConstants.CHEST_MIN_DISTANCE_BETWEEN  # Minimum distance between chests
var chest_respawn_timer = 0.0
var chest_respawn_delay = GameConstants.CHEST_RESPAWN_DELAY  # Seconds to respawn a chest
var is_chest_timer_active = false

# Mob management variables
var mob_scene = preload("res://objects/mob.tscn")
var current_mobs: Array[Node2D] = []
var mob_spawn_timer = 0.0
var base_mob_spawn_interval = GameConstants.BASE_MOB_SPAWN_INTERVAL  # Base spawn rate
var current_mob_spawn_interval = GameConstants.BASE_MOB_SPAWN_INTERVAL  # Current spawn rate (gets faster each day)
var min_mob_spawn_interval = GameConstants.MIN_MOB_SPAWN_INTERVAL  # Minimum spawn rate
var max_mobs = GameConstants.MAX_MOBS  # Maximum number of mobs at once

# Boss management variables
var boss_scene = preload("res://objects/boss.tscn")
var current_boss: Node2D = null
var boss_target_days = GameConstants.BOSS_TARGET_DAYS  # Target days for boss appearances
var boss_defeated_count = 0  # How many bosses have been defeated
var last_boss_warning_day = -1  # Track last day we showed warning

# Day/Night cycle variables
var day_night_cycle_time = GameConstants.DAY_NIGHT_CYCLE_TIME  # Total cycle time
var day_duration = GameConstants.DAY_DURATION  # Day duration
var night_duration = GameConstants.NIGHT_DURATION  # Night duration
var cycle_timer = 0.0
var is_night = false

# Cached node references
var canvas_modulate_node
var night_overlay_node
var night_shader_material
var campfire_node
var bonfire_light_node
var player_node

# Audio system variables
var day_music_player: AudioStreamPlayer
var night_music_player: AudioStreamPlayer
var good_ending_music_player: AudioStreamPlayer
var is_transitioning_music = false
var fade_duration = 1.0  # 1 second fade
var current_fade_timer = 0.0

# Item preloads and instances
const FlashlightClass = preload("res://items/flashlight.gd")
const HourglassClass = preload("res://items/hourglass.gd")

var flashlight_item: FlashlightClass
var hourglass_item: HourglassClass


func _ready():
	# Cache node references for performance
	canvas_modulate_node = $CanvasModulate
	night_overlay_node = $NightLayer/NightOverlay
	night_shader_material = night_overlay_node.material as ShaderMaterial
	campfire_node = $Campfire
	bonfire_light_node = campfire_node.get_node("BonfireLight") if campfire_node else null
	player_node = $Player
	
	# Initialize item instances
	flashlight_item = FlashlightClass.new()
	hourglass_item = HourglassClass.new()
	add_child(flashlight_item)
	add_child(hourglass_item)
	
	# Initialize audio system
	setup_audio_system()
	
	# Load the new flashlight shader
	var flashlight_shader = load("res://shaders/flashlight_night.gdshader")
	if flashlight_shader and night_shader_material:
		night_shader_material.shader = flashlight_shader
	
	# Connect campfire signals
	if campfire_node:
		campfire_node.campfire_health_changed.connect(_on_campfire_health_changed)
		campfire_node.campfire_extinguished.connect(_on_campfire_extinguished)
		campfire_node.campfire_visuals_updated.connect(_on_campfire_visuals_updated)
	
	# Reset game state and start game directly
	# The title screen now handles the main menu, so we start the game immediately
	reset_game_state()
	new_game()

func _process(delta):
	if game_started and not is_player_dying:
		# Update day/night cycle (normal speed, not affected by hourglass)
		# On final boss day (30+), freeze the cycle until boss is defeated
		if not (is_final_boss_day() and current_boss):
			cycle_timer += delta
			if cycle_timer >= day_night_cycle_time:
				cycle_timer = 0.0
		
		# Determine if it's day or night
		var was_night = is_night
		# On final boss day (30+), stay in night mode until boss is defeated
		if is_final_boss_day() and current_boss:
			is_night = true
		else:
			is_night = cycle_timer >= day_duration
		
		# Update lighting when transitioning
		if was_night != is_night:
			update_lighting()
			
			# Start music transition
			start_music_transition(is_night)
			
			# Handle day/night transition effects
			if is_night:
				# Night just started - stop boss and mob daylight damage
				print("Game: Night started")
				if current_boss and current_boss.has_method("stop_daylight_damage"):
					current_boss.stop_daylight_damage()
				# Stop daylight damage for all mobs
				for mob in current_mobs:
					if mob and is_instance_valid(mob) and mob.has_method("stop_daylight_damage"):
						mob.stop_daylight_damage()
			else:
				# Day just started - start boss and mob daylight damage, destroy mobs
				print("Game: Day started")
				if current_mobs.size() > 0:
					# Start daylight damage for all mobs (they'll die from it)
					for mob in current_mobs:
						if mob and is_instance_valid(mob) and mob.has_method("start_daylight_damage"):
							mob.start_daylight_damage()
				if current_boss and not is_final_boss():
					if current_boss.has_method("start_daylight_damage"):
						current_boss.start_daylight_damage()
		
		# Handle music transitions
		handle_music_transitions(delta)
		
		# Update shader parameters every frame during night (for camera movement)
		if is_night and night_overlay_node and night_overlay_node.visible:
			update_shader_parameters()
		
		# Check for new day and manage trees (45-second days)
		# Only increment day when a full cycle completes (cycle_timer resets to 0)
		if cycle_timer == 0.0 and was_night and not is_night:
			# Calculate day increment (1 normally, more with hourglass)
			var day_increment = int(hourglass_item.get_time_multiplier()) if hourglass_item else 1
			current_day += day_increment
			
			# Update score to match current day (score now represents days survived)
			score = current_day
			
			# Update HUD with correct day number and score
			%HUD.update_day_display(current_day)
			%HUD.update_score(score)
			
			# Show special message for day 30+
			if current_day >= 30:
				%HUD.show_message(GameText.LAST_DAY_MESSAGE)
			
			# Damage campfire each morning (except day 1)
			if current_day > 1 and campfire_node:
				campfire_node.damage_campfire(1)
			
			cycle_trees()
			cycle_boulders()
			
			# Update mob spawn rate (gets faster each day)
			update_mob_spawn_rate()
			
			# Spawn new chests for the new day (cleans up old ones)
			spawn_daily_chests()
			
			# Reset chest timer for the new day
			chest_respawn_timer = 0.0
			is_chest_timer_active = false
		
		# Handle chest respawn timer (works during both day and night)
		if is_chest_timer_active:
			chest_respawn_timer += delta
			if chest_respawn_timer >= chest_respawn_delay:
				spawn_replacement_chest()
				chest_respawn_timer = 0.0
				is_chest_timer_active = false
		
		# Handle boss warnings and spawning
		handle_boss_logic()
		
		# Handle mob/boss spawning (only during night time)
		if is_night:
			if should_spawn_boss():
				spawn_boss()
			elif not current_boss:
				# Normal night - spawn mobs (only if no boss)
				mob_spawn_timer += delta
				if mob_spawn_timer >= current_mob_spawn_interval and current_mobs.size() < max_mobs:
					spawn_mob()
					mob_spawn_timer = 0.0
		
		# Check win condition (30 days) - use current_day counter, not score
		# For final boss, don't end until boss is defeated
		# Only win if we've defeated all 3 bosses (boss_defeated_count == 3)
		if current_day >= win_day and boss_defeated_count >= boss_target_days.size():
			game_won()

func reset_game_state():
	"""Reset all game state to initial values"""
	score = 0.0
	game_started = false
	is_player_dying = false  # Reset pause state
	current_day = 1  # Start on day 1
	cycle_timer = 0.0  # Start at beginning of day cycle
	is_night = false  # Start during day
	# Reset item states
	if hourglass_item:
		hourglass_item.reset()
	if flashlight_item:
		flashlight_item.deactivate()
	chest_respawn_timer = 0.0
	is_chest_timer_active = false
	mob_spawn_timer = 0.0
	current_mob_spawn_interval = base_mob_spawn_interval  # Reset spawn rate
	%HUD.set_game_started(false)
	
	# Reset player to initial state
	%Player.reset_position(player_start_position)
	%Player.health = %Player.max_health
	%Player.speed_mult = 1.0  # Reset speed multiplier
	%Player.reset_axe()  # Reset axe to level 1
	
	# Clear all existing trees
	clear_all_trees()
	
	# Clear all existing boulders
	clear_all_boulders()
	
	# Clear chests
	clear_chests()
	
	# Clear mobs
	clear_all_mobs()
	
	# Clear boss
	clear_boss()
	
	# Reset boss state
	boss_defeated_count = 0  # No bosses defeated yet
	last_boss_warning_day = -1
	
	# Reset lighting to day
	update_lighting()
	
	# Reset campfire to full health
	if campfire_node:
		campfire_node.current_health = campfire_node.max_health
		campfire_node.update_campfire_visuals()
	
	# Reset inventory
	var inventory = %HUD.get_inventory()
	if inventory and inventory.has_method("clear_inventory"):
		inventory.clear_inventory()
	
	# Reset material inventory
	var material_inventory = %HUD.get_material_inventory()
	if material_inventory and material_inventory.has_method("clear_materials"):
		material_inventory.clear_materials()
	
	# Ensure health bar is properly updated if it exists
	if %Player.has_node("%HealthBar"):
		%Player.get_node("%HealthBar").max_value = %Player.max_health
		%Player.get_node("%HealthBar").value = %Player.health

func new_game():
	reset_game_state()
	game_started = true
	# current_day is already set to 1 in reset_game_state()
	score = current_day  # Update score to match current day
	%HUD.set_game_started(true)
	%HUD.start_game_ui()
	get_tree().paused = false
	
	# Add starting items to player inventory
	%Player.add_starting_items()
	
	# Spawn initial trees for day 1
	cycle_trees()
	
	# Spawn initial boulders for day 1
	cycle_boulders()
	
	# Spawn initial chests for day 1
	spawn_daily_chests()
	
	# Show initial message
	%HUD.show_message(GameText.SURVIVE_MESSAGE)
	
	# Set initial day display and score
	%HUD.update_day_display(current_day)
	%HUD.update_score(score)
	
	# Update mob spawn rate for current day
	update_mob_spawn_rate()
	
	# Update lighting for current time of day
	update_lighting()

func game_over():
	game_started = false
	%HUD.set_game_started(false)
	
	# Update best score and day if current is higher
	if score > best_score:
		best_score = score
	if current_day > best_day:
		best_day = current_day
	
	# Keep everything hidden and show game over message on black background
	if death_overlay:
		death_overlay.visible = true  # Ensure black background stays
	
	# Create a simple white text label for game over message
	var game_over_label = Label.new()
	game_over_label.text = "Game Over!"
	game_over_label.add_theme_font_size_override("font_size", 72)
	game_over_label.add_theme_color_override("font_color", Color.WHITE)
	game_over_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	game_over_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	game_over_label.z_index = 1002  # Above everything including death overlay
	
	# Get viewport size and center the label properly
	var viewport_size = get_viewport().get_visible_rect().size
	game_over_label.size = viewport_size  # Full screen size
	game_over_label.position = Vector2.ZERO  # Start at origin
	
	# Add to a CanvasLayer to ensure it's always on top and properly positioned
	var canvas_layer = CanvasLayer.new()
	canvas_layer.layer = 100  # High layer to be on top
	canvas_layer.add_child(game_over_label)
	add_child(canvas_layer)
	
	# Game over label created
	
	await get_tree().create_timer(3.0).timeout  # Show message for 3 seconds
	
	# Fade out any remaining music before returning to title
	await fade_out_all_music()
	
	get_tree().paused = false
	get_tree().change_scene_to_file("res://title_screen.tscn")

func game_won():
	game_started = false
	%HUD.set_game_started(false)
	
	# Update best score and day (winning always means you got the max)
	best_score = score
	best_day = max(best_day, current_day)
	
	# Start dramatic victory sequence
	await start_victory_sequence()
	
	# Fade out good ending music before returning to title
	await fade_out_all_music()
	
	get_tree().paused = false
	get_tree().change_scene_to_file("res://title_screen.tscn")

func start_victory_sequence():
	"""Start the dramatic victory sequence when final boss is defeated"""
	print("Game: Starting victory sequence")
	is_player_dying = true  # Use this flag to pause game logic
	
	# Fade out day/night music and start good ending music
	await start_good_ending_music()
	
	# Disable player movement and input during victory sequence
	if %Player:
		%Player.velocity = Vector2.ZERO  # Stop current movement
		%Player.is_dying = true  # This prevents player movement processing
		%Player.is_touch_control = false  # Disable touch controls
		%Player.is_dragging = false  # Disable dragging
		
		# Immediately switch player to idle animation
		if %Player.player_character and %Player.player_character.has_method("play_idle_animation"):
			%Player.player_character.play_idle_animation()
	
	# Hide everything except player and boss with black background
	hide_everything_for_victory()
	
	# Get camera reference
	var camera = %Player.camera if %Player and %Player.camera else null
	if not camera:
		print("Warning: No camera found for victory sequence")
		return
	
	# Store original camera position (not needed for current implementation)
	# var original_camera_position = camera.global_position
	
	# Phase 1: Camera slowly moves to center on boss
	# Victory Phase 1: Moving camera to boss
	if current_boss and is_instance_valid(current_boss):
		var boss_position = current_boss.global_position
		var camera_tween = create_tween()
		camera_tween.tween_property(camera, "global_position", boss_position, 2.0)
		await camera_tween.finished
		
		# Boss death sequence is already running, wait for it to complete
		# Boss dying animation (2 seconds) + fadeout (1 second) = 3 seconds total
		# Victory Phase 2: Waiting for boss death sequence
		await get_tree().create_timer(3.0).timeout
	
	# Phase 2: Camera slowly moves back to center on player
	# Victory Phase 3: Moving camera back to player
	if %Player:
		var player_position = %Player.global_position
		var return_tween = create_tween()
		return_tween.tween_property(camera, "global_position", player_position, 2.0)
		await return_tween.finished
		
		# Ensure player is in idle animation
		if %Player.player_character and %Player.player_character.has_method("play_idle_animation"):
			%Player.player_character.play_idle_animation()
	
	# Phase 3: Show YOU_SURVIVED message
	# Victory Phase 4: Showing YOU_SURVIVED message
	show_victory_message()
	await get_tree().create_timer(2.0).timeout  # Show message for 2 seconds
	
	# Phase 4: Player character begins to fade out for 1 second
	# Victory Phase 5: Fading out player
	if %Player:
		var player_tween = create_tween()
		player_tween.tween_property(%Player, "modulate:a", 0.0, 1.0)
		await player_tween.finished
	
	# Phase 5: Wait another second after player faded out
	# Victory Phase 6: Final wait
	await get_tree().create_timer(1.0).timeout
	
	# Clean up the boss if it still exists
	if current_boss and is_instance_valid(current_boss):
		current_boss.queue_free()
	current_boss = null
	
	# Victory sequence complete

func hide_everything_for_victory():
	"""Hide all game elements except player and boss for victory sequence"""
	# Hiding everything for victory sequence
	
	# Create black background overlay (reuse death overlay)
	if not death_overlay:
		death_overlay = ColorRect.new()
		death_overlay.color = Color.BLACK
		death_overlay.z_index = 1000  # Above everything
		death_overlay.size = Vector2(10000, 10000)  # Large enough to cover everything
		death_overlay.position = Vector2(-5000, -5000)  # Center it
		add_child(death_overlay)
	death_overlay.visible = true
	
	# Hide all game elements except player and boss
	hide_all_game_elements_except_player_and_boss()
	
	# Ensure player and boss stay visible above the black background
	if %Player:
		%Player.z_index = 1001  # Above the black overlay
	if current_boss and is_instance_valid(current_boss):
		current_boss.z_index = 1001  # Above the black overlay

func hide_all_game_elements_except_player_and_boss():
	"""Hide all visual game elements except player and boss"""
	# Hide HUD
	if %HUD:
		%HUD.visible = false
	
	# Hide player health bar specifically
	if %Player and %Player.health_bar:
		%Player.health_bar.visible = false
	
	# Hide all mobs (but keep boss visible)
	for mob in current_mobs:
		if is_instance_valid(mob):
			mob.visible = false
	
	# Hide all trees
	for tree in current_trees:
		if is_instance_valid(tree):
			tree.visible = false
	
	# Hide all boulders
	for boulder in current_boulders:
		if is_instance_valid(boulder):
			boulder.visible = false
	
	# Hide all chests
	for chest in current_chests:
		if is_instance_valid(chest):
			chest.visible = false
	
	# Hide campfire
	if campfire_node:
		campfire_node.visible = false
	
	# Hide night overlay
	if night_overlay_node:
		night_overlay_node.visible = false

func show_victory_message():
	"""Show the YOU_SURVIVED message on screen"""
	# Create a victory message label
	var victory_label = Label.new()
	victory_label.text = GameText.YOU_SURVIVED
	victory_label.add_theme_font_size_override("font_size", 72)
	victory_label.add_theme_color_override("font_color", Color.WHITE)
	victory_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	victory_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	victory_label.z_index = 1002  # Above everything including death overlay
	
	# Get viewport size and center the label properly
	var viewport_size = get_viewport().get_visible_rect().size
	victory_label.size = viewport_size  # Full screen size
	victory_label.position = Vector2.ZERO  # Start at origin
	
	# Add to a CanvasLayer to ensure it's always on top and properly positioned
	var canvas_layer = CanvasLayer.new()
	canvas_layer.layer = 100  # High layer to be on top
	canvas_layer.add_child(victory_label)
	add_child(canvas_layer)
	
	# Victory message created

func _on_player_health_depleted() -> void:
	game_over()

func hide_everything_for_death():
	"""Hide all game elements except player for death sequence"""
	is_player_dying = true
	# Hiding everything for player death sequence
	
	# Create black background overlay
	if not death_overlay:
		death_overlay = ColorRect.new()
		death_overlay.color = Color.BLACK
		death_overlay.z_index = 1000  # Above everything
		death_overlay.size = Vector2(10000, 10000)  # Large enough to cover everything
		death_overlay.position = Vector2(-5000, -5000)  # Center it
		add_child(death_overlay)
	death_overlay.visible = true
	
	# Hide all game elements
	hide_all_game_elements()
	
	# Ensure player stays visible above the black background
	if %Player:
		%Player.z_index = 1001  # Above the black overlay

func show_everything_after_death():
	"""Show all game elements after death sequence"""
	is_player_dying = false
	# Showing everything after player death sequence
	
	# Hide black overlay
	if death_overlay:
		death_overlay.visible = false
	
	# Show all game elements
	show_all_game_elements()
	
	# Reset player z_index
	if %Player:
		%Player.z_index = 0

func hide_all_game_elements():
	"""Hide all visual game elements"""
	# Hide HUD
	if %HUD:
		%HUD.visible = false
	
	# Hide player health bar specifically
	if %Player and %Player.health_bar:
		%Player.health_bar.visible = false
	
	# Hide all enemies
	for mob in current_mobs:
		if is_instance_valid(mob):
			mob.visible = false
	
	if current_boss and is_instance_valid(current_boss):
		current_boss.visible = false
	
	# Hide all trees
	for tree in current_trees:
		if is_instance_valid(tree):
			tree.visible = false
	
	# Hide all boulders
	for boulder in current_boulders:
		if is_instance_valid(boulder):
			boulder.visible = false
	
	# Hide all chests
	for chest in current_chests:
		if is_instance_valid(chest):
			chest.visible = false
	
	# Hide campfire
	if campfire_node:
		campfire_node.visible = false
	
	# Hide night overlay
	if night_overlay_node:
		night_overlay_node.visible = false

func show_all_game_elements():
	"""Show all visual game elements"""
	# Show HUD
	if %HUD:
		%HUD.visible = true
	
	# Show all enemies
	for mob in current_mobs:
		if is_instance_valid(mob):
			mob.visible = true
	
	if current_boss and is_instance_valid(current_boss):
		current_boss.visible = true
	
	# Show all trees
	for tree in current_trees:
		if is_instance_valid(tree):
			tree.visible = true
	
	# Show all boulders
	for boulder in current_boulders:
		if is_instance_valid(boulder):
			boulder.visible = true
	
	# Show all chests
	for chest in current_chests:
		if is_instance_valid(chest):
			chest.visible = true
	
	# Show campfire
	if campfire_node:
		campfire_node.visible = true
	
	# Show night overlay if it should be visible
	if night_overlay_node and is_night:
		night_overlay_node.visible = true

func _on_hud_toggle_pause():
	if get_tree().paused:
		get_tree().paused = false
		%HUD.hide_pause_menu()
	else:
		get_tree().paused = true
		%HUD.show_pause_menu()

func _on_hud_quit_game() -> void:
	# Unpause the game before returning to title screen
	get_tree().paused = false
	# Return to title screen
	get_tree().change_scene_to_file("res://title_screen.tscn")


# Tree management functions
func cycle_trees():
	"""Remove cut trees and spawn new ones to maintain desired count"""
	# Remove only cut trees from the scene and tracking array
	clear_cut_trees()
	
	# Count remaining uncut trees
	var current_uncut_trees = count_uncut_trees()
	
	# Calculate how many new trees we need to spawn
	var target_trees = randi_range(GameConstants.MIN_TREES_PER_DAY, GameConstants.MAX_TREES_PER_DAY)
	var trees_to_spawn = max(0, target_trees - current_uncut_trees)
	
	if trees_to_spawn > 0:
		spawn_trees(trees_to_spawn)
	
	# Log final tree count
	var final_uncut_trees = count_uncut_trees()
	print("Day ", current_day, " - Trees: ", final_uncut_trees, " uncut trees (target: ", target_trees, ", spawned: ", trees_to_spawn, ")")

func clear_cut_trees():
	"""Remove only cut trees from the game world and tracking array"""
	var trees_to_remove = []
	
	for tree in current_trees:
		if is_instance_valid(tree):
			var is_cut = tree.get("is_cut") if tree.has_method("get") and "is_cut" in tree else false
			if is_cut:
				trees_to_remove.append(tree)
				tree.queue_free()
	
	# Remove cut trees from tracking array
	for tree in trees_to_remove:
		current_trees.erase(tree)

func count_uncut_trees() -> int:
	"""Count how many uncut trees remain"""
	var uncut_count = 0
	for tree in current_trees:
		if is_instance_valid(tree):
			var is_cut = tree.get("is_cut") if tree.has_method("get") and "is_cut" in tree else false
			if not is_cut:
				uncut_count += 1
	return uncut_count

func clear_all_trees():
	"""Remove all trees from the game world (legacy function for compatibility)"""
	for tree in current_trees:
		if is_instance_valid(tree):
			tree.queue_free()
	current_trees.clear()

func spawn_trees(count: int):
	"""Spawn the specified number of trees with distance constraints"""
	var spawn_attempts = 0
	var max_attempts = count * 20  # Prevent infinite loops
	var trees_spawned = 0
	
	print("Attempting to spawn ", count, " trees...")
	
	while trees_spawned < count and spawn_attempts < max_attempts:
		spawn_attempts += 1
		
		# Generate random position within game area, avoiding player start area
		var pos = generate_tree_position()
		
		# Check if position is valid (far enough from other trees and player)
		if is_valid_tree_position(pos):
			var tree = tree_scene.instantiate()
			tree.position = pos
			
			# Connect tree destruction signal
			if tree.has_signal("tree_destroyed"):
				tree.tree_destroyed.connect(_on_tree_destroyed)
			
			add_child(tree)
			current_trees.append(tree)
			trees_spawned += 1
			print("Tree spawned at ", pos, " (", trees_spawned, "/", count, ")")

func generate_tree_position() -> Vector2:
	"""Generate a random position for a tree within the game area"""
	# Define boundaries around the campfire to avoid
	var campfire_safe_zone = GameConstants.CAMPFIRE_SAFE_ZONE
	
	# Generate position across the entire world area
	for attempt in range(1000):  # Use a for loop with max attempts instead of while true
		var x = randf_range(GameConstants.WORLD_MARGIN, world_size.x - GameConstants.WORLD_MARGIN)  # Leave 100px margin from world edges
		var y = randf_range(GameConstants.WORLD_MARGIN, world_size.y - GameConstants.WORLD_MARGIN)
		
		var pos = Vector2(x, y)
		if pos.distance_to(campfire_position) > campfire_safe_zone:
			return pos
	
	# Fallback position if somehow no valid position is found (should never happen)
	return Vector2(campfire_position.x + campfire_safe_zone + 50, campfire_position.y)

func is_valid_tree_position(pos: Vector2) -> bool:
	"""Check if a tree position is valid (far enough from other trees)"""
	# Check distance from all existing trees
	for tree in current_trees:
		if is_instance_valid(tree) and pos.distance_to(tree.position) < min_tree_distance:
			return false
	
	# Check distance from campfire
	if pos.distance_to(campfire_position) < min_tree_distance:
		return false
	
	
	return true

func _on_tree_destroyed(_tree_node):
	"""Handle when a tree is cut down by the player"""
	# Note: We don't remove cut trees from current_trees list since they stay in the scene
	# They just change their sprite and become non-targetable by the axe
	
	# Add wood to material inventory
	%HUD.add_wood(1)

# Boulder management functions
func cycle_boulders():
	"""Clean up destroyed boulders and spawn new ones to maintain desired count"""
	# Clean up any destroyed boulder references from tracking array
	clean_destroyed_boulders()
	
	# Count remaining valid boulders
	var current_boulder_count = count_valid_boulders()
	
	# Calculate how many new boulders we need to spawn
	var target_boulders = randi_range(GameConstants.MIN_BOULDERS_PER_DAY, GameConstants.MAX_BOULDERS_PER_DAY)
	var boulders_to_spawn = max(0, target_boulders - current_boulder_count)
	
	if boulders_to_spawn > 0:
		spawn_boulders(boulders_to_spawn)
	
	# Log final boulder count
	var final_boulder_count = count_valid_boulders()
	print("Day ", current_day, " - Boulders: ", final_boulder_count, " valid boulders (target: ", target_boulders, ", spawned: ", boulders_to_spawn, ")")

func clean_destroyed_boulders():
	"""Remove destroyed boulder references from tracking array"""
	var valid_boulders = []
	
	for boulder in current_boulders:
		if is_instance_valid(boulder):
			valid_boulders.append(boulder)
	
	current_boulders = valid_boulders

func count_valid_boulders() -> int:
	"""Count how many valid (not destroyed) boulders remain"""
	var valid_count = 0
	for boulder in current_boulders:
		if is_instance_valid(boulder):
			valid_count += 1
	return valid_count

func clear_all_boulders():
	"""Remove all boulders from the game world (legacy function for compatibility)"""
	for boulder in current_boulders:
		if is_instance_valid(boulder):
			boulder.queue_free()
	current_boulders.clear()

func spawn_boulders(count: int):
	"""Spawn the specified number of boulders with distance constraints from trees and other boulders"""
	var spawn_attempts = 0
	var max_attempts = count * 30  # More attempts since we need to avoid trees too
	var boulders_spawned = 0
	
	print("Attempting to spawn ", count, " boulders...")
	
	while boulders_spawned < count and spawn_attempts < max_attempts:
		spawn_attempts += 1
		
		# Generate random position within game area, avoiding player start area
		var pos = generate_boulder_position()
		
		# Check if position is valid (far enough from trees, other boulders, and player)
		if is_valid_boulder_position(pos):
			var boulder = boulder_scene.instantiate()
			boulder.position = pos
			
			# Connect boulder destruction signal
			if boulder.has_signal("boulder_destroyed"):
				boulder.boulder_destroyed.connect(_on_boulder_destroyed)
			
			add_child(boulder)
			current_boulders.append(boulder)
			boulders_spawned += 1
			print("Boulder spawned at ", pos, " (", boulders_spawned, "/", count, ")")

func generate_boulder_position() -> Vector2:
	"""Generate a random position for a boulder within the game area"""
	# Define boundaries around the campfire to avoid
	var campfire_safe_zone = GameConstants.CAMPFIRE_SAFE_ZONE
	
	# Generate position across the entire world area
	for attempt in range(1000):  # Use a for loop with max attempts instead of while true
		var x = randf_range(GameConstants.WORLD_MARGIN, world_size.x - GameConstants.WORLD_MARGIN)  # Leave 100px margin from world edges
		var y = randf_range(GameConstants.WORLD_MARGIN, world_size.y - GameConstants.WORLD_MARGIN)
		
		var pos = Vector2(x, y)
		if pos.distance_to(campfire_position) > campfire_safe_zone:
			return pos
	
	# Fallback position if somehow no valid position is found (should never happen)
	return Vector2(campfire_position.x + campfire_safe_zone + 50, campfire_position.y)

func is_valid_boulder_position(pos: Vector2) -> bool:
	"""Check if a boulder position is valid (far enough from trees, other boulders, and player)"""
	# Check distance from all existing trees (must be at least 100px away)
	for tree in current_trees:
		if is_instance_valid(tree) and pos.distance_to(tree.position) < min_boulder_tree_distance:
			return false
	
	# Check distance from all existing boulders
	for boulder in current_boulders:
		if is_instance_valid(boulder) and pos.distance_to(boulder.position) < min_boulder_distance:
			return false
	
	# Check distance from campfire (use larger of the two distances)
	var campfire_distance = max(min_boulder_distance, 300.0)
	if pos.distance_to(campfire_position) < campfire_distance:
		return false
	
	return true

func _on_boulder_destroyed(boulder_node):
	"""Handle when a boulder is destroyed by the player"""
	# Remove boulder from tracking array since it will be deleted
	if boulder_node in current_boulders:
		current_boulders.erase(boulder_node)
	
	# Add rock to material inventory
	%HUD.add_rock(1)

# Day/Night cycle functions
func update_lighting():
	"""Update the lighting based on current day/night state"""
	if not canvas_modulate_node or not night_overlay_node:
		return
	
	# Keep canvas modulate neutral
	canvas_modulate_node.color = Color(1.0, 1.0, 1.0, 1.0)
	
	if is_night:
		# Night time - show shader-based night overlay with bonfire exclusion
		night_overlay_node.visible = true
		update_shader_parameters()
	else:
		# Day time - hide night overlay
		night_overlay_node.visible = false

func update_shader_parameters():
	"""Update shader parameters based on bonfire and flashlight positions"""
	if not night_shader_material:
		return
	
	var viewport_size = get_viewport().get_visible_rect().size
	var camera = get_viewport().get_camera_2d()
	
	# Update bonfire parameters
	if campfire_node and bonfire_light_node:
		var bonfire_screen_pos = campfire_node.global_position
		
		# Convert world position to screen coordinates if camera exists
		if camera:
			bonfire_screen_pos = camera.get_canvas_transform() * campfire_node.global_position
		
		# Calculate light radius to match the green circle (same calculation as in campfire)
		var light_radius: float
		if campfire_node.current_health == 0:
			light_radius = 0.0  # No hole in shader when campfire is out
		else:
			# Use the same calculation as the green circle: texture_scale * 24.2 * campfire_scale
			light_radius = bonfire_light_node.texture_scale * 24.2 * campfire_node.scale.x
		
		# Update bonfire shader parameters
		night_shader_material.set_shader_parameter("bonfire_position", bonfire_screen_pos)
		night_shader_material.set_shader_parameter("bonfire_radius", light_radius)
	
	# Check if player has flashlight and update flashlight parameters
	update_flashlight_status()
	
	if flashlight_item and flashlight_item.is_flashlight_active() and player_node:
		var flashlight_screen_pos = get_flashlight_position()
		
		# Convert world position to screen coordinates if camera exists
		if camera:
			flashlight_screen_pos = camera.get_canvas_transform() * flashlight_screen_pos
		
		# Get player facing direction
		var flashlight_direction = get_player_facing_direction()
		
		# Update shader parameters using flashlight item
		flashlight_item.update_shader_parameters(night_shader_material, flashlight_screen_pos, flashlight_direction)
	else:
		night_shader_material.set_shader_parameter("flashlight_active", false)
	
	# Update screen size
	night_shader_material.set_shader_parameter("screen_size", viewport_size)

func update_flashlight_status():
	"""Update flashlight status based on player inventory"""
	if not flashlight_item:
		return
		
	var hud = %HUD
	var was_active = flashlight_item.is_flashlight_active()
	var has_flashlight = flashlight_item.check_player_has_flashlight(hud)
	
	if has_flashlight and not was_active:
		flashlight_item.activate()
	elif not has_flashlight and was_active:
		flashlight_item.deactivate()

func get_player_facing_direction() -> Vector2:
	"""Get the direction the player is facing based on last movement"""
	if player_node and player_node.has_method("get") and player_node.get("last_movement_direction"):
		return player_node.last_movement_direction
	else:
		return Vector2.RIGHT  # Default facing right

func get_flashlight_position() -> Vector2:
	"""Get the flashlight position (same as axe position)"""
	if not player_node:
		return Vector2.ZERO
	
	var player_position = player_node.global_position
	var player_facing_direction = get_player_facing_direction()
	
	# Use same positioning logic as axe
	var vertical_offset = Vector2(0, -32)  # Move up by 32px
	var horizontal_offset = Vector2.ZERO
	
	# Determine horizontal offset based on facing direction
	if player_facing_direction.x > 0:  # Facing right
		horizontal_offset = Vector2(40, 0)
	elif player_facing_direction.x < 0:  # Facing left
		horizontal_offset = Vector2(-40, 0)
	elif player_facing_direction.y > 0:  # Facing down
		horizontal_offset = Vector2(40, 0)  # Default to right when facing down
	elif player_facing_direction.y < 0:  # Facing up
		horizontal_offset = Vector2(40, 0)  # Default to right when facing up
	
	return player_position + vertical_offset + horizontal_offset

func get_flashlight_item() -> FlashlightClass:
	"""Get the flashlight item instance"""
	return flashlight_item

# Chest management functions
func spawn_daily_chests():
	"""Remove opened chests and spawn new ones to maintain desired count"""
	# Remove only opened chests from the scene and tracking array
	clear_opened_chests()
	
	# Count remaining unopened chests
	var current_unopened_chests = count_unopened_chests()
	
	# Calculate how many new chests we need to spawn
	var chests_to_spawn = max(0, chests_per_day - current_unopened_chests)
	
	# Spawn new chests
	for i in range(chests_to_spawn):
		var chest_position = generate_chest_position()
		if chest_position != Vector2.ZERO:
			var chest = chest_scene.instantiate()
			chest.position = chest_position
			
			# Add chest to group for cleanup purposes
			chest.add_to_group("chests")
			
			# Connect chest signals if needed
			if chest.has_signal("chest_opened"):
				chest.chest_opened.connect(_on_chest_opened)
			
			add_child(chest)
			current_chests.append(chest)
	
	# Log final chest count
	var final_unopened_chests = count_unopened_chests()
	print("Day ", current_day, " - Chests: ", final_unopened_chests, " unopened chests (target: ", chests_per_day, ", spawned: ", chests_to_spawn, ")")

func clear_opened_chests():
	"""Remove only opened chests from the game world and tracking array"""
	var chests_to_remove = []
	
	for chest in current_chests:
		if is_instance_valid(chest):
			var is_opened = chest.get("is_opened") if chest.has_method("get") and "is_opened" in chest else false
			if is_opened:
				chests_to_remove.append(chest)
				chest.queue_free()
	
	# Remove opened chests from tracking array
	for chest in chests_to_remove:
		current_chests.erase(chest)
	
	# Also clean up any opened chests that might not be in our tracking array
	var all_chests = get_tree().get_nodes_in_group("chests")
	for chest in all_chests:
		if is_instance_valid(chest):
			var is_opened = chest.get("is_opened") if chest.has_method("get") and "is_opened" in chest else false
			if is_opened:
				chest.queue_free()

func count_unopened_chests() -> int:
	"""Count how many unopened chests remain"""
	var unopened_count = 0
	for chest in current_chests:
		if is_instance_valid(chest):
			var is_opened = chest.get("is_opened") if chest.has_method("get") and "is_opened" in chest else false
			if not is_opened:
				unopened_count += 1
	return unopened_count

func clear_chests():
	"""Remove all current chests from the game world (legacy function for compatibility)"""
	# Remove chests from our tracking array
	for chest in current_chests:
		if chest and is_instance_valid(chest):
			chest.queue_free()
	current_chests.clear()
	
	# Also find and remove any chest nodes that might not be in our array (opened chests)
	var all_chests = get_tree().get_nodes_in_group("chests")
	for chest in all_chests:
		if chest and is_instance_valid(chest):
			chest.queue_free()

func spawn_replacement_chest():
	"""Spawn a single replacement chest if there are less than 4 chests"""
	if current_chests.size() >= chests_per_day:
		return
	var chest_position = generate_chest_position()
	if chest_position != Vector2.ZERO:
		var chest = chest_scene.instantiate()
		chest.position = chest_position
		
		# Add chest to group for cleanup purposes
		chest.add_to_group("chests")
		
		# Connect chest signals
		if chest.has_signal("chest_opened"):
			chest.chest_opened.connect(_on_chest_opened)
		
		add_child(chest)
		current_chests.append(chest)

func generate_chest_position() -> Vector2:
	"""Generate a random position for a chest that's at least min distance from campfire and other chests"""
	var max_attempts = 200  # Increased attempts for multiple chests
	
	for attempt in range(max_attempts):
		# Generate random position within world bounds
		var x = randf_range(GameConstants.WORLD_MARGIN, world_size.x - GameConstants.WORLD_MARGIN)
		var y = randf_range(GameConstants.WORLD_MARGIN, world_size.y - GameConstants.WORLD_MARGIN)
		var pos = Vector2(x, y)
		
		# Check distance from campfire
		if pos.distance_to(campfire_position) >= chest_min_distance:
			# Also check it's not too close to trees, boulders, and other chests
			if is_valid_chest_position(pos):
				return pos
	
	# Fallback: place chest at a fixed distance from campfire in a random direction
	var max_fallback_attempts = 50
	for fallback_attempt in range(max_fallback_attempts):
		var angle = randf() * 2 * PI
		var direction = Vector2(cos(angle), sin(angle))
		var fallback_pos = campfire_position + direction * (chest_min_distance + fallback_attempt * 50)
		
		# Clamp to world bounds
		fallback_pos.x = clamp(fallback_pos.x, 100, world_size.x - 100)
		fallback_pos.y = clamp(fallback_pos.y, 100, world_size.y - 100)
		
		if is_valid_chest_position(fallback_pos):
			return fallback_pos
	
	# Last resort fallback
	return Vector2.ZERO

func is_valid_chest_position(pos: Vector2) -> bool:
	"""Check if a chest position is valid (not too close to trees, boulders, campfire, or other chests)"""
	var min_distance_from_trees = 200.0
	var min_distance_from_boulders = 200.0
	
	# Check distance from all existing trees
	for tree in current_trees:
		if is_instance_valid(tree) and pos.distance_to(tree.position) < min_distance_from_trees:
			return false
	
	# Check distance from all existing boulders
	for boulder in current_boulders:
		if is_instance_valid(boulder) and pos.distance_to(boulder.position) < min_distance_from_boulders:
			return false
	
	# Check distance from campfire
	if campfire_node and pos.distance_to(campfire_node.position) < 300.0:
		return false
	
	# Check distance from other existing chests
	for chest in current_chests:
		if is_instance_valid(chest) and pos.distance_to(chest.position) < chest_min_distance_between:
			return false
	
	return true

func _on_chest_opened(chest_node):
	"""Handle when a chest is opened by the player"""
	# Remove the opened chest from the current_chests array
	var chest_index = current_chests.find(chest_node)
	if chest_index != -1:
		current_chests.remove_at(chest_index)
	
	# Start respawn timer if we have less than 4 chests and timer is not already active
	if current_chests.size() < chests_per_day and not is_chest_timer_active:
		is_chest_timer_active = true
		chest_respawn_timer = 0.0

# Campfire management functions
func _on_campfire_health_changed(new_health: int):
	"""Handle campfire health changes"""
	%HUD.show_message(GameText.CAMPFIRE_HEALTH_FORMAT % new_health)

func _on_campfire_extinguished():
	"""Handle when campfire is completely extinguished"""
	%HUD.show_message(GameText.CAMPFIRE_EXTINGUISHED)

func try_fuel_campfire():
	"""Try to fuel the campfire with wood from player's inventory"""
	if not campfire_node:
		return false
	
	var wood_amount = %HUD.get_material_amount(GameText.MATERIAL_WOOD)
	if wood_amount < 3:
		%HUD.show_message(GameText.NEED_WOOD_TO_FUEL)
		return false
	
	# Calculate how much wood we can use
	var max_health_needed = campfire_node.max_health - campfire_node.current_health
	var max_wood_usable = max_health_needed * 3
	var wood_to_use = min(wood_amount, max_wood_usable)
	
	# Make sure we use a multiple of 3 wood
	wood_to_use = (wood_to_use / 3) * 3
	
	if wood_to_use == 0:
		%HUD.show_message(GameText.CAMPFIRE_FULL_HEALTH)
		return false
	
	# Remove wood from inventory and fuel campfire
	if %HUD.remove_material_from_inventory(GameText.MATERIAL_WOOD, wood_to_use):
		campfire_node.add_fuel(wood_to_use)
		return true
	
	return false

func _on_campfire_visuals_updated():
	"""Handle when campfire visuals are updated - update shader parameters"""
	if is_night and night_overlay_node and night_overlay_node.visible:
		update_shader_parameters()

func is_player_in_safe_zone() -> bool:
	"""Check if player is currently in the campfire's safe zone"""
	if not campfire_node or not %Player:
		return false
	
	return campfire_node.is_safe_zone(%Player.global_position)

func enable_hourglass_effect():
	"""Enable or upgrade the hourglass effect (max 5x speed)"""
	if hourglass_item:
		hourglass_item.upgrade()

# Mob management functions
func spawn_mob():
	"""Spawn a mob at a random position around the player (off-screen)"""
	if not %Player:
		return
	
	var mob = mob_scene.instantiate()
	
	# Use Path2D system like vampire survivors for consistent off-screen spawning
	var spawn_position = Vector2.ZERO
	if %Player.has_node("MobSpawnPath/%MobSpawnFollow"):
		var path_follow = %Player.get_node("MobSpawnPath/%MobSpawnFollow")
		path_follow.progress_ratio = randf()
		spawn_position = path_follow.global_position
	else:
		# Fallback to manual generation if Path2D not available
		spawn_position = generate_mob_spawn_position()
	
	mob.global_position = spawn_position
	
	# Connect mob signals
	if mob.has_signal("mob_destroyed"):
		mob.mob_destroyed.connect(_on_mob_destroyed)
	
	add_child(mob)
	current_mobs.append(mob)

func generate_mob_spawn_position() -> Vector2:
	"""Generate a spawn position around the player, off-screen"""
	var player_pos = %Player.global_position
	var camera = get_viewport().get_camera_2d()
	
	if not camera:
		# Fallback: spawn in a circle around player
		var angle = randf() * 2 * PI
		var distance = 800.0  # Spawn 800 pixels away from player
		return player_pos + Vector2(cos(angle), sin(angle)) * distance
	
	# Get viewport size to determine screen bounds
	var viewport_size = get_viewport().get_visible_rect().size
	var spawn_margin = 100.0  # Spawn 100 pixels outside screen
	
	# Choose a random side of the screen (0=top, 1=right, 2=bottom, 3=left)
	var side = randi() % 4
	var spawn_pos = Vector2.ZERO
	
	match side:
		0: # Top
			spawn_pos.x = player_pos.x + randf_range(-viewport_size.x/2 - spawn_margin, viewport_size.x/2 + spawn_margin)
			spawn_pos.y = player_pos.y - viewport_size.y/2 - spawn_margin
		1: # Right
			spawn_pos.x = player_pos.x + viewport_size.x/2 + spawn_margin
			spawn_pos.y = player_pos.y + randf_range(-viewport_size.y/2 - spawn_margin, viewport_size.y/2 + spawn_margin)
		2: # Bottom
			spawn_pos.x = player_pos.x + randf_range(-viewport_size.x/2 - spawn_margin, viewport_size.x/2 + spawn_margin)
			spawn_pos.y = player_pos.y + viewport_size.y/2 + spawn_margin
		3: # Left
			spawn_pos.x = player_pos.x - viewport_size.x/2 - spawn_margin
			spawn_pos.y = player_pos.y + randf_range(-viewport_size.y/2 - spawn_margin, viewport_size.y/2 + spawn_margin)
	
	# Clamp to world bounds
	spawn_pos.x = clamp(spawn_pos.x, 0, world_size.x)
	spawn_pos.y = clamp(spawn_pos.y, 0, world_size.y)
	
	return spawn_pos

func clear_all_mobs():
	"""Remove all mobs from the game world"""
	for mob in current_mobs:
		if is_instance_valid(mob):
			mob.queue_free()
	current_mobs.clear()

func _on_mob_destroyed(mob_node):
	"""Handle when a mob is destroyed"""
	# Remove mob from tracking array
	if mob_node in current_mobs:
		current_mobs.erase(mob_node)

func update_mob_spawn_rate():
	"""Update mob spawn rate based on current day (gets faster each day)"""
	# Start at 5 seconds, decrease by 1 second each day, minimum 1 second
	current_mob_spawn_interval = max(base_mob_spawn_interval - (current_day - 1), min_mob_spawn_interval)

	
	# Clear the array since mobs will destroy themselves
	current_mobs.clear()

# Boss management functions
func handle_boss_logic():
	"""Handle boss warnings and state management"""
	if boss_defeated_count >= boss_target_days.size():
		return  # All bosses defeated
	
	var next_boss_day = boss_target_days[boss_defeated_count]
	
	# Show warning message during the day of boss night
	if current_day == next_boss_day and not is_night and last_boss_warning_day != current_day:
		%HUD.show_message(GameText.BOSS_WARNING)
		last_boss_warning_day = current_day

func should_spawn_boss() -> bool:
	"""Check if we should spawn a boss right now"""
	if current_boss or boss_defeated_count >= boss_target_days.size():
		return false
	
	var next_boss_day = boss_target_days[boss_defeated_count]
	return current_day >= next_boss_day and is_night

func is_final_boss() -> bool:
	"""Check if current boss is the final boss"""
	return boss_defeated_count == 2  # Final boss (3rd boss, index 2)

func is_final_boss_day() -> bool:
	"""Check if we're on or past the final boss day"""
	return current_day >= boss_target_days[2]  # Day 30 or later

func spawn_boss():
	"""Spawn the boss at a random position around the player"""
	if not %Player or current_boss:
		return
	
	var boss = boss_scene.instantiate()
	
	# Set final boss properties if it's the final boss
	if is_final_boss():
		boss.set_final_boss(true)
		%HUD.show_message(GameText.DEFEAT_THE_BOSS)
	else:
		%HUD.show_message(GameText.BOSS_APPROACHES)
	
	# Use same spawn logic as mobs
	var spawn_position = Vector2.ZERO
	if %Player.has_node("MobSpawnPath/%MobSpawnFollow"):
		var path_follow = %Player.get_node("MobSpawnPath/%MobSpawnFollow")
		path_follow.progress_ratio = randf()
		spawn_position = path_follow.global_position
	else:
		spawn_position = generate_mob_spawn_position()
	
	boss.global_position = spawn_position
	
	# Connect boss signals
	if boss.has_signal("boss_destroyed"):
		boss.boss_destroyed.connect(_on_boss_destroyed)
	
	add_child(boss)
	current_boss = boss

func clear_boss():
	"""Remove boss from the game world"""
	if current_boss and is_instance_valid(current_boss):
		current_boss.queue_free()
	current_boss = null

func _on_boss_destroyed(_boss_node):
	"""Handle when the boss is destroyed"""
	var was_final_boss = is_final_boss()
	
	# Mark this boss as defeated
	boss_defeated_count += 1
	current_boss = _boss_node  # Keep reference for victory sequence
	
	if was_final_boss:
		# Final boss defeated - trigger game win (victory sequence will handle the boss)
		game_won()
	else:
		# Regular boss defeated - clear reference
		current_boss = null

# Audio System Functions
func setup_audio_system():
	"""Initialize the audio system with day and night music players"""
	# Create day music player
	day_music_player = AudioStreamPlayer.new()
	day_music_player.name = "DayMusicPlayer"
	day_music_player.volume_db = 0.0
	day_music_player.autoplay = false
	var day_stream = load("res://assets/sounds/day.mp3")
	if day_stream:
		day_stream.loop = true  # Enable looping
	day_music_player.stream = day_stream
	add_child(day_music_player)
	
	# Create night music player
	night_music_player = AudioStreamPlayer.new()
	night_music_player.name = "NightMusicPlayer"
	night_music_player.volume_db = 0.0
	night_music_player.autoplay = false
	var night_stream = load("res://assets/sounds/night.mp3")
	if night_stream:
		night_stream.loop = true  # Enable looping
	night_music_player.stream = night_stream
	add_child(night_music_player)
	
	# Create good ending music player
	good_ending_music_player = AudioStreamPlayer.new()
	good_ending_music_player.name = "GoodEndingMusicPlayer"
	good_ending_music_player.volume_db = 0.0
	good_ending_music_player.autoplay = false
	good_ending_music_player.stream = load("res://assets/sounds/good_ending.mp3")
	add_child(good_ending_music_player)
	
	# Start with day music if game starts during day (with small delay to allow title music to fade)
	if not is_night:
		await get_tree().create_timer(0.1).timeout  # Small delay to ensure title music has faded
		if day_music_player:  # Check if still valid after delay
			day_music_player.play()

func handle_music_transitions(delta):
	"""Handle smooth music transitions during day/night changes"""
	if not is_transitioning_music:
		return
	
	current_fade_timer += delta
	var fade_progress = current_fade_timer / fade_duration
	
	if fade_progress >= 1.0:
		# Transition complete
		fade_progress = 1.0
		is_transitioning_music = false
		current_fade_timer = 0.0
	
	# Calculate volumes for fade in/out
	var fade_out_volume = lerp(0.0, -80.0, fade_progress)  # Current music fades out
	var fade_in_volume = lerp(-80.0, 0.0, fade_progress)   # New music fades in
	
	if is_night:
		# Transitioning to night
		day_music_player.volume_db = fade_out_volume
		night_music_player.volume_db = fade_in_volume
		
		if fade_progress >= 1.0:
			day_music_player.stop()
	else:
		# Transitioning to day
		night_music_player.volume_db = fade_out_volume
		day_music_player.volume_db = fade_in_volume
		
		if fade_progress >= 1.0:
			night_music_player.stop()

func start_music_transition(to_night: bool):
	"""Start a smooth transition between day and night music"""
	if not day_music_player or not night_music_player:
		return
	
	is_transitioning_music = true
	current_fade_timer = 0.0
	
	if to_night:
		# Starting night music
		night_music_player.volume_db = -80.0  # Start silent
		night_music_player.play()
	else:
		# Starting day music
		day_music_player.volume_db = -80.0  # Start silent
		day_music_player.play()

func fade_out_game_music():
	"""Fade out day/night music when game over starts"""
	if not day_music_player or not night_music_player:
		return
	
	# Check if any music is actually playing before creating tween
	var has_playing_music = day_music_player.playing or night_music_player.playing
	if not has_playing_music:
		return
	
	# Create tween to fade out both music players
	var tween = create_tween()
	tween.set_parallel(true)  # Allow multiple tweens to run simultaneously
	
	# Fade out day music if playing
	if day_music_player.playing:
		tween.tween_property(day_music_player, "volume_db", -80.0, 1.0)
		tween.tween_callback(day_music_player.stop).set_delay(1.0)
	
	# Fade out night music if playing
	if night_music_player.playing:
		tween.tween_property(night_music_player, "volume_db", -80.0, 1.0)
		tween.tween_callback(night_music_player.stop).set_delay(1.0)

func fade_out_all_music():
	"""Fade out all currently playing music before scene transition"""
	if not day_music_player or not night_music_player or not good_ending_music_player:
		return
	
	# Check if any music is actually playing before creating tween
	var has_playing_music = day_music_player.playing or night_music_player.playing or good_ending_music_player.playing
	if not has_playing_music:
		return
	
	# Create tween to fade out all music players
	var fade_tween = create_tween()
	fade_tween.set_parallel(true)  # Allow multiple tweens to run simultaneously
	
	# Fade out day music if playing
	if day_music_player.playing:
		fade_tween.tween_property(day_music_player, "volume_db", -80.0, 1.0)
		fade_tween.tween_callback(day_music_player.stop).set_delay(1.0)
	
	# Fade out night music if playing
	if night_music_player.playing:
		fade_tween.tween_property(night_music_player, "volume_db", -80.0, 1.0)
		fade_tween.tween_callback(night_music_player.stop).set_delay(1.0)
	
	# Fade out good ending music if playing
	if good_ending_music_player.playing:
		fade_tween.tween_property(good_ending_music_player, "volume_db", -80.0, 1.0)
		fade_tween.tween_callback(good_ending_music_player.stop).set_delay(1.0)
	
	# Wait for fade out to complete
	await get_tree().create_timer(1.0).timeout

func start_good_ending_music():
	"""Fade out day/night music and start good ending music"""
	if not day_music_player or not night_music_player or not good_ending_music_player:
		return
	
	# Check if any music is actually playing before creating tween
	var has_playing_music = day_music_player.playing or night_music_player.playing
	if has_playing_music:
		# Create tween to fade out current music
		var fade_tween = create_tween()
		fade_tween.set_parallel(true)  # Allow multiple tweens to run simultaneously
		
		# Fade out day music if playing
		if day_music_player.playing:
			fade_tween.tween_property(day_music_player, "volume_db", -80.0, 1.0)
			fade_tween.tween_callback(day_music_player.stop).set_delay(1.0)
		
		# Fade out night music if playing
		if night_music_player.playing:
			fade_tween.tween_property(night_music_player, "volume_db", -80.0, 1.0)
			fade_tween.tween_callback(night_music_player.stop).set_delay(1.0)
		
		# Wait for fade out to complete
		await get_tree().create_timer(1.0).timeout
	
	# Start good ending music
	if good_ending_music_player:
		good_ending_music_player.play()
