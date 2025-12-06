extends CanvasLayer

signal start_game
signal toggle_pause
signal quit_game

var score = 0.0
var game_started = false
var best_score = 0.0

func update_score(new_score: float):
	score = new_score
	%ScoreLabel.text = str(int(score))

func show_message(text: String):
	%MessageLabel.text = text
	%MessageLabel.show()
	%MessageTimer.start()

func show_main_menu(best_score_param: float = 0.0):
	best_score = best_score_param
	%MessageLabel.text = "Project Template"
	%MessageLabel.show()
	%BestScoreLabel.text = "Best: " + str(int(best_score))
	%BestScoreLabel.show()
	%StartButton.show()
	%ScoreLabel.hide()
	%MenuOverlay.show()

func show_game_over(best_score_param: float = 0.0):
	%MenuOverlay.show()
	show_message("Game Over")
	await %MessageTimer.timeout
	await get_tree().create_timer(2.0).timeout  # Wait 2 seconds
	show_main_menu(best_score_param)

func show_game_won(best_score_param: float = 0.0):
	%MenuOverlay.show()
	show_message("You Won!")
	await %MessageTimer.timeout
	await get_tree().create_timer(2.0).timeout  # Wait 2 seconds
	show_main_menu(best_score_param)

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

func _input(event):
	if event.is_action_pressed("ui_cancel") and game_started:
		toggle_pause.emit()
	elif %StartButton.visible and event.is_action_pressed("confirm_action"):
		# Handle Enter and A button for Start button when main menu is visible
		_on_start_button_pressed()

func _on_message_timer_timeout() -> void:
	%MessageLabel.hide()
