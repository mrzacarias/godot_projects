extends Node2D

# Tower climbing scene for Let it Climb

signal floor_completed(floor: int, continue_climbing: bool)
signal player_died
signal return_to_base

var current_floor: int = 1
var player_data: PlayerData
var player: Node2D
var enemy_spawner: Node2D
var floor_generator: Node2D

# UI references
@onready var floor_info = %FloorInfo
@onready var continue_button = %ContinueButton
@onready var return_button = %ReturnButton
@onready var player_stats = %PlayerStats

# Floor state
var floor_cleared: bool = false
var enemies_defeated: int = 0
var enemies_total: int = 10
var player_death_handled: bool = false

func _ready():
	# Get references
	player = $Player
	enemy_spawner = %EnemySpawner
	floor_generator = %FloorGenerator
	
	# Connect signals
	continue_button.pressed.connect(_on_continue_pressed)
	return_button.pressed.connect(_on_return_pressed)
	
	if player:
		player.health_depleted.connect(_on_player_died)
		if player.has_signal("experience_gained"):
			player.experience_gained.connect(_on_experience_gained)
	
	if enemy_spawner:
		if enemy_spawner.has_signal("wave_completed"):
			enemy_spawner.wave_completed.connect(_on_wave_completed)
	
	if floor_generator:
		if floor_generator.has_signal("floor_generated"):
			floor_generator.floor_generated.connect(_on_floor_generated)

func setup_tower(data: PlayerData, floor_number: int):
	"""Setup tower with player data and floor"""
	player_data = data
	current_floor = floor_number
	player_death_handled = false  # Reset death handling state
	
	# Setup player character (simplified for now)
	if player:
		# Set world size for proper bounds checking
		if player.has_method("set_world_size"):
			player.set_world_size(Vector2(2880, 1920))
		
		if player.has_method("reset_for_new_run"):
			player.reset_for_new_run()
		elif player.has_method("heal_to_full"):
			player.heal_to_full()
		print("Player setup complete")
	
	# Generate floor layout
	if floor_generator:
		if floor_generator.has_method("generate_floor"):
			floor_generator.generate_floor(current_floor)
		else:
			print("FloorGenerator ready")
	
	# Setup enemy spawner
	if enemy_spawner:
		if enemy_spawner.has_method("set_floor_level"):
			enemy_spawner.set_floor_level(current_floor)
		
		# Calculate enemies for this floor
		enemies_total = 10 + (current_floor - 1) * 2
		enemies_defeated = 0
		
		# Start spawning (if method exists)
		if enemy_spawner.has_method("start_wave"):
			enemy_spawner.start_wave()
		else:
			print("EnemySpawner ready")
	
	# Update UI
	update_ui()
	
	print("Tower setup complete - Floor %d" % current_floor)

func advance_to_next_floor(floor_number: int):
	"""Advance to the next floor"""
	current_floor = floor_number
	floor_cleared = false
	enemies_defeated = 0
	
	# Generate new floor layout
	if floor_generator:
		floor_generator.generate_floor(current_floor)
	
	# Clear existing enemies
	if enemy_spawner:
		enemy_spawner.clear_all_enemies()
		enemy_spawner.set_floor_level(current_floor)
		enemies_total = 10 + (current_floor - 1) * 2
		enemy_spawner.start_wave()
	
	# Reset player position
	if player:
		player.reset_position(Vector2(1440, 960))  # Center of world
		player.heal_to_full()  # Heal between floors
	
	# Update UI
	update_ui()
	continue_button.disabled = true
	
	print("Advanced to floor %d" % current_floor)

func update_ui():
	"""Update UI elements"""
	if floor_info:
		var enemies_remaining = 0
		if enemy_spawner and enemy_spawner.has_method("get_enemies_remaining"):
			enemies_remaining = enemy_spawner.get_enemies_remaining()
		
		var chests_remaining = 0
		if floor_generator and floor_generator.has_method("get_remaining_chests"):
			chests_remaining = floor_generator.get_remaining_chests()
		
		floor_info.text = "Floor: %d\nEnemies: %d remaining\nChests: %d remaining" % [current_floor, enemies_remaining, chests_remaining]
	
	if player_stats and player:
		var hp_current = int(player.health) if player.has_method("get") and "health" in player else 100
		var hp_max = int(player.max_health) if player.has_method("get") and "max_health" in player else 100
		player_stats.text = "HP: %d/%d\nFloor: %d\nEXP: %d" % [
			hp_current, hp_max, current_floor, player_data.total_experience if player_data else 0
		]

func _process(_delta):
	# Update UI regularly
	update_ui()

func _on_wave_completed():
	"""Handle wave completion"""
	floor_cleared = true
	continue_button.disabled = false
	
	print("Floor %d cleared!" % current_floor)
	
	# Award floor completion bonus
	var floor_bonus = current_floor * 50
	if player_data:
		player_data.total_experience += floor_bonus
	
	# Show completion message
	show_floor_completion_dialog()

func show_floor_completion_dialog():
	"""Show floor completion dialog"""
	var dialog = AcceptDialog.new()
	dialog.title = "Floor Cleared!"
	
	var vbox = VBoxContainer.new()
	
	var message = Label.new()
	message.text = "Floor %d completed!\n\nBonus EXP: %d\nTotal EXP: %d" % [
		current_floor, current_floor * 50, player_data.total_experience if player_data else 0
	]
	vbox.add_child(message)
	
	var choice_label = Label.new()
	choice_label.text = "\nWhat would you like to do?"
	vbox.add_child(choice_label)
	
	var button_container = HBoxContainer.new()
	
	var continue_btn = Button.new()
	continue_btn.text = "Continue Climbing"
	continue_btn.pressed.connect(func(): _handle_floor_choice(true, dialog))
	button_container.add_child(continue_btn)
	
	var return_btn = Button.new()
	return_btn.text = "Return to Base"
	return_btn.pressed.connect(func(): _handle_floor_choice(false, dialog))
	button_container.add_child(return_btn)
	
	vbox.add_child(button_container)
	dialog.add_child(vbox)
	add_child(dialog)
	dialog.popup_centered()

func _handle_floor_choice(continue_climbing: bool, dialog: AcceptDialog):
	"""Handle player choice after floor completion"""
	dialog.queue_free()
	floor_completed.emit(current_floor, continue_climbing)

func _on_continue_pressed():
	"""Handle continue button press"""
	if floor_cleared:
		floor_completed.emit(current_floor, true)

func _on_return_pressed():
	"""Handle return button press"""
	return_to_base.emit()

func _on_player_died():
	"""Handle player death"""
	# Prevent multiple death handling
	if player_death_handled:
		return
		
	player_death_handled = true
	print("Player died on floor %d" % current_floor)
	
	# Stop enemy spawning
	if enemy_spawner:
		enemy_spawner.stop_spawning()
	
	# Show death message
	show_death_dialog()

func show_death_dialog():
	"""Show death dialog"""
	var main_scene = get_node("/root/Main")
	if main_scene and main_scene.has_method("show_global_dialog"):
		var dialog_text = "You died on floor %d!\n\nAll carried items are lost, but your character progress and R&D remain." % current_floor
		main_scene.show_global_dialog("Game Over", dialog_text, _handle_death)
	else:
		# Fallback to local dialog
		_handle_death()

func _handle_death():
	"""Handle death confirmation"""
	player_died.emit()

func _on_experience_gained(amount: int):
	"""Handle experience gained"""
	if player_data:
		player_data.total_experience += amount
	update_ui()

func _on_floor_generated():
	"""Handle floor generation completion"""
	print("Floor %d layout generated" % current_floor)
	
	# Update UI to show floor objects
	update_ui()

# Debug functions
func debug_clear_floor():
	"""Debug function to instantly clear floor"""
	if enemy_spawner:
		enemy_spawner.clear_all_enemies()
	_on_wave_completed()

func debug_spawn_enemy():
	"""Debug function to spawn an enemy"""
	if enemy_spawner:
		enemy_spawner.force_spawn_enemy()

func get_tower_info() -> Dictionary:
	"""Get current tower information"""
	return {
		"current_floor": current_floor,
		"floor_cleared": floor_cleared,
		"enemies_defeated": enemies_defeated,
		"enemies_total": enemies_total,
		"player_hp": player.character.current_hp if player and player.character else 0,
		"spawner_info": enemy_spawner.get_spawn_info() if enemy_spawner else {}
	}
