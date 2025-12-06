extends CanvasLayer

signal start_game
signal toggle_pause
signal quit_game
signal powerup_selected(powerup: String)

var score = 0.0
var game_started = false
var current_powerup_options = []
var selected_powerup_index = 0

func update_score(new_score: float):
	score = new_score
	%ScoreLabel.text = str(int(score))

func show_message(text: String):
	%MessageLabel.text = text
	%MessageLabel.show()
	%MessageTimer.start()

func show_main_menu(best_score: float = 0.0):
	%MessageLabel.text = "Vamlike Survivors"
	%MessageLabel.show()
	%BestScoreLabel.text = "Best: " + str(int(best_score))
	%BestScoreLabel.show()
	%StartButton.show()
	%ScoreLabel.hide()
	%MenuOverlay.show()

func show_game_over(best_score: float = 0.0):
	%MenuOverlay.show()
	show_message("Game Over")
	await %MessageTimer.timeout
	await get_tree().create_timer(2.0).timeout  # Wait 2 seconds
	show_main_menu(best_score)

func show_game_won(best_score: float = 0.0):
	%MenuOverlay.show()
	show_message("You Won!")
	await %MessageTimer.timeout
	await get_tree().create_timer(2.0).timeout  # Wait 2 seconds
	show_main_menu(best_score)

func start_game_ui():
	%StartButton.hide()
	%MessageLabel.hide()
	%BestScoreLabel.hide()
	%MenuOverlay.hide()
	%ScoreLabel.show()
	%ScoreLabel.text = "0"

func _on_start_button_pressed() -> void:
	print("Start button pressed!")
	start_game_ui()
	start_game.emit()

func _on_quit_button_pressed() -> void:
	hide_pause_menu()
	quit_game.emit()

func show_pause_menu():
	%PauseMenu.show()

func hide_pause_menu():
	%PauseMenu.hide()

func set_game_started(started: bool):
	game_started = started

func show_powerup_screen(available_powerups: Array):
	# Select 3 random power-ups
	current_powerup_options = []
	var shuffled_powerups = available_powerups.duplicate()
	shuffled_powerups.shuffle()
	
	for i in range(min(3, shuffled_powerups.size())):
		current_powerup_options.append(shuffled_powerups[i])
	
	selected_powerup_index = 0
	update_powerup_display()
	%PowerupScreen.show()

func update_powerup_display():
	var powerup_names = {
		"health": "Full Health",
		"inc_char_speed": "Speed Boost",
		"inc_gun_proj": "Extra Projectile",
		"inc_bullet_damage": "Bullet Damage",
		"inc_bullet_range": "Bullet Range",
		"inc_bullet_fire_rate": "Fire Rate"
	}
	
	for i in range(3):
		var button = %PowerupScreen.get_node("PowerupOption" + str(i + 1))
		if i < current_powerup_options.size():
			var powerup_key = current_powerup_options[i]
			button.text = powerup_names.get(powerup_key, powerup_key)
			button.show()
			
			# Highlight selected option
			if i == selected_powerup_index:
				button.modulate = Color(1.2, 1.2, 0.8)  # Slight yellow tint
			else:
				button.modulate = Color.WHITE
		else:
			button.hide()

func hide_powerup_screen():
	%PowerupScreen.hide()

func select_powerup(index: int):
	if index >= 0 and index < current_powerup_options.size():
		var selected_powerup = current_powerup_options[index]
		hide_powerup_screen()
		powerup_selected.emit(selected_powerup)

func _input(event):
	if event.is_action_pressed("ui_cancel") and game_started:
		toggle_pause.emit()
	elif %PowerupScreen.visible:
		if event.is_action_pressed("ui_left"):
			selected_powerup_index = (selected_powerup_index - 1) % current_powerup_options.size()
			update_powerup_display()
		elif event.is_action_pressed("ui_right"):
			selected_powerup_index = (selected_powerup_index + 1) % current_powerup_options.size()
			update_powerup_display()
		elif event.is_action_pressed("ui_accept"):
			select_powerup(selected_powerup_index)
	elif %StartButton.visible and event.is_action_pressed("confirm_action"):
		# Handle Enter and A button for Start button when main menu is visible
		_on_start_button_pressed()

func _on_message_timer_timeout() -> void:
	%MessageLabel.hide()

func _on_powerup_option_1_pressed() -> void:
	select_powerup(0)

func _on_powerup_option_2_pressed() -> void:
	select_powerup(1)

func _on_powerup_option_3_pressed() -> void:
	select_powerup(2)
