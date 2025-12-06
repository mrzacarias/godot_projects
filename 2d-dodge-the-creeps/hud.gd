extends CanvasLayer

signal start_game

func update_score(score):
	$ScoreLabel.text = str(score)

func show_message(text):
	$MessageLabel.text = text
	$MessageLabel.show()
	$MessageTimer.start()

func show_game_over():
	show_message("Game Over")
	await $MessageTimer.timeout
	$MessageLabel.text = "Dodge the creeps"
	$MessageLabel.show()
	await get_tree().create_timer(1.0).timeout # basically a sleep
	$Button.show()

func _on_button_pressed() -> void:
	$Button.hide()
	emit_signal("start_game")

func _input(event):
	if $Button.visible and event.is_action_pressed("confirm_action"):
		# Handle Enter and A button for Start button when main menu is visible
		_on_button_pressed()

func _on_message_timer_timeout() -> void:
	$MessageLabel.hide()
