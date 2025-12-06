extends Node2D

var score = 0.0
var best_score = 0.0
var game_started = false
var player_start_position = Vector2(573, 364)
var win_score = 60.0  # 60 seconds for template game

func _ready():
	# Reset game state and start with main menu
	reset_game_state()
	%HUD.show_main_menu(best_score)
	get_tree().paused = true

func _process(delta):
	if game_started:
		score += delta
		%HUD.update_score(score)
		
		# Check win condition (60 seconds)
		if score >= win_score:
			game_won()

func reset_game_state():
	"""Reset all game state to initial values"""
	score = 0.0
	game_started = false
	%HUD.set_game_started(false)
	
	# Reset player to initial state
	%Player.reset_position(player_start_position)
	%Player.health = %Player.max_health
	%Player.speed_mult = 1.0  # Reset speed multiplier
	
	# Ensure health bar is properly updated if it exists
	if %Player.has_node("%ProgressBar"):
		%Player.get_node("%ProgressBar").max_value = %Player.max_health
		%Player.get_node("%ProgressBar").value = %Player.health

func new_game():
	reset_game_state()
	game_started = true
	%HUD.set_game_started(true)
	get_tree().paused = false
	
	# Show initial message
	%HUD.show_message("Game Started!")

func game_over():
	game_started = false
	%HUD.set_game_started(false)
	
	# Update best score if current score is higher
	if score > best_score:
		best_score = score
	
	# Pause the game
	get_tree().paused = true
	%HUD.show_game_over(best_score)

func game_won():
	game_started = false
	%HUD.set_game_started(false)
	
	# Update best score (winning always means you got the max score)
	best_score = score
	
	# Pause the game
	get_tree().paused = true
	%HUD.show_game_won(best_score)

func _on_player_health_depleted() -> void:
	game_over()

func _on_hud_toggle_pause():
	if get_tree().paused:
		get_tree().paused = false
		%HUD.hide_pause_menu()
	else:
		get_tree().paused = true
		%HUD.show_pause_menu()

func _on_hud_quit_game() -> void:
	# Reset game state and return to main menu
	reset_game_state()
	
	# Show main menu (same as initial state)
	get_tree().paused = true
	%HUD.show_main_menu(best_score)

func _on_hud_start_game() -> void:
	print("HUD start_game signal received!")
	new_game()
