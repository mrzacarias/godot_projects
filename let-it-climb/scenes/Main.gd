extends Node

# Main game controller for Let it Climb

signal game_state_changed(new_state: GameState)

enum GameState {
	MAIN_MENU,
	BASE_HUB,
	TOWER_CLIMBING,
	GAME_OVER,
	VICTORY
}

var current_state: GameState = GameState.MAIN_MENU
var player_data: PlayerData
var current_floor: int = 1
var highest_floor_reached: int = 1

# Dialog management
var active_dialog: AcceptDialog = null

# Scene references (now direct node references)
@onready var main_menu_scene = %MainMenu
@onready var base_scene = %Base
@onready var tower_scene = %Tower

func _ready():
	# Initialize player data
	player_data = PlayerData.new()
	
	# Load save data if it exists
	load_game_data()
	
	# Connect scene signals
	connect_scene_signals()
	
	# Initialize all scenes to be hidden
	hide_all_scenes()
	
	# Start with main menu
	change_state(GameState.MAIN_MENU)

func close_active_dialog():
	"""Close any active dialog to prevent overlaps"""
	if active_dialog and is_instance_valid(active_dialog):
		active_dialog.queue_free()
		active_dialog = null

func show_global_dialog(title: String, text: String, callback: Callable = Callable()):
	"""Show a global dialog, ensuring no overlaps"""
	# Close any existing dialog first
	close_active_dialog()
	
	# Create new dialog
	active_dialog = AcceptDialog.new()
	active_dialog.title = title
	active_dialog.dialog_text = text
	
	# Connect callback if provided
	if callback.is_valid():
		active_dialog.confirmed.connect(callback)
	
	# Clean up when dialog closes
	active_dialog.confirmed.connect(func(): active_dialog = null)
	
	add_child(active_dialog)
	active_dialog.popup_centered()

func hide_all_scenes():
	"""Hide all scenes and their UI layers"""
	# Close any active dialogs first
	close_active_dialog()
	
	# Hide main menu
	main_menu_scene.visible = false
	
	# Hide base scene and its UI
	base_scene.visible = false
	if base_scene.has_node("UI"):
		base_scene.get_node("UI").visible = false
	
	# Hide tower scene and its UI
	tower_scene.visible = false
	if tower_scene.has_node("UI"):
		tower_scene.get_node("UI").visible = false

func connect_scene_signals():
	"""Connect signals from all scenes"""
	# Main Menu signals
	if main_menu_scene.has_signal("start_game"):
		main_menu_scene.start_game.connect(_on_start_game)
	if main_menu_scene.has_signal("quit_game"):
		main_menu_scene.quit_game.connect(_on_quit_game)
	
	# Base signals
	if base_scene.has_signal("enter_tower"):
		base_scene.enter_tower.connect(_on_enter_tower)
	if base_scene.has_signal("character_upgraded"):
		base_scene.character_upgraded.connect(_on_character_upgraded)
	
	# Tower signals
	if tower_scene.has_signal("floor_completed"):
		tower_scene.floor_completed.connect(_on_floor_completed)
	if tower_scene.has_signal("player_died"):
		tower_scene.player_died.connect(_on_player_died)
	if tower_scene.has_signal("return_to_base"):
		tower_scene.return_to_base.connect(_on_return_to_base)

func change_state(new_state: GameState):
	"""Change game state and show appropriate scene"""
	print("Changing game state from %s to %s" % [GameState.keys()[current_state], GameState.keys()[new_state]])
	
	current_state = new_state
	game_state_changed.emit(new_state)
	
	# Hide all scenes and their UI layers
	hide_all_scenes()
	
	# Show the appropriate scene
	match new_state:
		GameState.MAIN_MENU:
			show_main_menu()
		GameState.BASE_HUB:
			show_base_hub()
		GameState.TOWER_CLIMBING:
			show_tower()
		GameState.GAME_OVER:
			handle_game_over()
		GameState.VICTORY:
			handle_victory()

func show_main_menu():
	"""Show main menu scene"""
	main_menu_scene.visible = true
	print("Main menu displayed")

func show_base_hub():
	"""Show base hub scene"""
	base_scene.visible = true
	
	# Show base UI
	if base_scene.has_node("UI"):
		base_scene.get_node("UI").visible = true
	
	# Setup base with player data
	if base_scene.has_method("setup_base"):
		base_scene.setup_base(player_data)
	
	print("Base hub displayed")

func show_tower():
	"""Show tower climbing scene"""
	tower_scene.visible = true
	
	# Show tower UI
	if tower_scene.has_node("UI"):
		tower_scene.get_node("UI").visible = true
	
	# Setup tower with player data and floor
	if tower_scene.has_method("setup_tower"):
		tower_scene.setup_tower(player_data, current_floor)
	
	print("Tower scene displayed - Floor %d" % current_floor)

func handle_game_over():
	"""Handle game over state"""
	print("Game Over! Returning to base...")
	
	# Reset player to base with loss of carried items
	if player_data:
		player_data.handle_death()
	current_floor = 1
	
	# Wait a moment, then return to base (Tower.gd handles the dialog)
	await get_tree().create_timer(1.0).timeout
	change_state(GameState.BASE_HUB)

func show_game_over_dialog():
	"""Show game over dialog"""
	var dialog = AcceptDialog.new()
	dialog.title = "Game Over"
	dialog.dialog_text = "You died on floor %d!\n\nAll carried items are lost, but your character progress and R&D remain.\n\nReturning to base..." % current_floor
	
	dialog.confirmed.connect(func(): _handle_game_over_confirmed(dialog))
	add_child(dialog)
	dialog.popup_centered()

func _handle_game_over_confirmed(dialog: AcceptDialog):
	"""Handle game over confirmation"""
	dialog.queue_free()
	change_state(GameState.BASE_HUB)

func handle_victory():
	"""Handle victory state"""
	print("Victory! Tower completed!")
	
	# Award victory bonuses
	if player_data:
		player_data.handle_victory()
	
	# Show victory dialog
	show_victory_dialog()

func show_victory_dialog():
	"""Show victory dialog"""
	var dialog = AcceptDialog.new()
	dialog.title = "Victory!"
	dialog.dialog_text = "Congratulations! You've completed the tower!\n\nVictory bonuses have been awarded.\n\nReturning to base..."
	
	dialog.confirmed.connect(func(): _handle_victory_confirmed(dialog))
	add_child(dialog)
	dialog.popup_centered()

func _handle_victory_confirmed(dialog: AcceptDialog):
	"""Handle victory confirmation"""
	dialog.queue_free()
	change_state(GameState.BASE_HUB)

# Signal handlers
func _on_start_game():
	"""Handle start game from main menu"""
	change_state(GameState.BASE_HUB)

func _on_quit_game():
	"""Handle quit game"""
	save_game_data()
	get_tree().quit()

func _on_enter_tower(target_floor: int = 1):
	"""Handle entering tower from base"""
	current_floor = target_floor
	change_state(GameState.TOWER_CLIMBING)

func _on_floor_completed(floor_number: int, continue_climbing: bool):
	"""Handle floor completion"""
	current_floor = floor_number + 1
	highest_floor_reached = max(highest_floor_reached, current_floor)
	
	# Update player data
	if player_data:
		player_data.highest_floor = highest_floor_reached
	
	if continue_climbing:
		# Continue to next floor
		if tower_scene and tower_scene.has_method("advance_to_next_floor"):
			tower_scene.advance_to_next_floor(current_floor)
	else:
		# Return to base
		change_state(GameState.BASE_HUB)

func _on_player_died():
	"""Handle player death"""
	change_state(GameState.GAME_OVER)

func _on_return_to_base():
	"""Handle returning to base from tower"""
	change_state(GameState.BASE_HUB)

func _on_character_upgraded():
	"""Handle character upgrade in base"""
	save_game_data()  # Save progress

# Save/Load system
func save_game_data():
	"""Save game data to file"""
	var save_data = {
		"player_data": player_data.to_save_data() if player_data else {},
		"highest_floor": highest_floor_reached,
		"current_floor": current_floor
	}
	
	var save_file = FileAccess.open("user://let_it_climb_save.dat", FileAccess.WRITE)
	if save_file:
		save_file.store_string(JSON.stringify(save_data))
		save_file.close()
		print("Game saved successfully")

func load_game_data():
	"""Load game data from file"""
	var save_file = FileAccess.open("user://let_it_climb_save.dat", FileAccess.READ)
	if save_file:
		var save_data_text = save_file.get_as_text()
		save_file.close()
		
		var json = JSON.new()
		var parse_result = json.parse(save_data_text)
		
		if parse_result == OK:
			var save_data = json.data
			
			# Load player data
			if player_data and "player_data" in save_data:
				player_data.from_save_data(save_data.player_data)
			
			# Load progress
			highest_floor_reached = save_data.get("highest_floor", 1)
			current_floor = save_data.get("current_floor", 1)
			
			print("Game loaded successfully")
		else:
			print("Failed to parse save data")
	else:
		print("No save file found, starting new game")

func _notification(what):
	"""Handle application notifications"""
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game_data()
		get_tree().quit()

# Debug functions
func debug_advance_floor():
	"""Debug function to advance floor"""
	current_floor += 1
	highest_floor_reached = max(highest_floor_reached, current_floor)

func debug_reset_progress():
	"""Debug function to reset all progress"""
	player_data = PlayerData.new()
	current_floor = 1
	highest_floor_reached = 1
	save_game_data()

func get_game_info() -> Dictionary:
	"""Get current game information"""
	return {
		"current_state": GameState.keys()[current_state],
		"current_floor": current_floor,
		"highest_floor": highest_floor_reached,
		"player_data": player_data.to_save_data() if player_data else {}
	}
