extends Node2D

const MOB_SCENE = preload("res://mob.tscn")
const MOB_STRONG_SCENE = preload("res://mob_strong.tscn")
const MOB_SUPER_STRONG_SCENE = preload("res://mob_super_strong.tscn")

var score = 0.0
var best_score = 0.0
var game_started = false
var player_start_position = Vector2(940, 550)
var win_score = 150

var power_ups = [ "health", "inc_char_speed", "inc_gun_proj", "inc_bullet_damage", "inc_bullet_fire_rate"]

var last_powerup_time = 0.0
var powerup_interval = 10.0

func _ready():
	# Reset game state and start with main menu
	reset_game_state()
	%HUD.show_main_menu(best_score)
	get_tree().paused = true

func _process(delta):
	if game_started:
		score += delta
		%HUD.update_score(score)
		handle_powerups(score)
		
		# Check win condition (240 seconds = 4 minutes)
		if score >= win_score:
			game_won()

func handle_powerups(score):
	# Check if it's time for a power-up (every 10 seconds)
	if score >= last_powerup_time + powerup_interval:
		last_powerup_time = score
		powerup_interval += 1.0
		show_powerup_screen()

func show_powerup_screen():
	get_tree().paused = true
	%HUD.show_powerup_screen(power_ups)

func apply_powerup(choice: String):
	var gun = %Player.get_node("%Gun")
	
	if choice == "health":
		%Player.health = %Player.max_health
		%Player.get_node("%ProgressBar").value = %Player.health
	elif choice == "inc_char_speed":
		%Player.speed_mult += 0.5
		if %Player.speed_mult >= 2.0:
			power_ups.erase("inc_char_speed")
	elif choice == "inc_gun_proj":
		gun.projectiles += 1
		if gun.projectiles >= 5:
			power_ups.erase("inc_gun_proj")
	elif choice == "inc_bullet_damage":
		gun.bullet_damage_mult += 0.5
		if gun.bullet_damage_mult >= 3.0:
			power_ups.erase("inc_bullet_damage")
	elif choice == "inc_bullet_fire_rate":
		gun.get_node("%ShootTimer").wait_time -= 0.1
		if gun.get_node("%ShootTimer").wait_time <= 0.2:
			power_ups.erase("inc_bullet_fire_rate")
	else:
		print("Power up choice is not available")
	
	# Resume game after applying power-up
	get_tree().paused = false

func reset_game_state():
	"""Reset all game state to initial values"""
	score = 0.0
	last_powerup_time = 0.0
	game_started = false
	%HUD.set_game_started(false)
	%MobTimer.stop()
	%Music.stop()
	
	# Reset power-ups array to initial state
	power_ups = [ "health", "inc_char_speed", "inc_gun_proj", "inc_bullet_damage", "inc_bullet_fire_rate"]
	
	# Clear existing mobs
	get_tree().call_group("mobs", "queue_free")
	
	# Reset player to initial state
	%Player.reset_position(player_start_position)
	%Player.health = %Player.max_health
	%Player.speed_mult = 1.0  # Reset speed multiplier
	# Ensure health bar is properly updated
	%Player.get_node("%ProgressBar").max_value = %Player.max_health
	%Player.get_node("%ProgressBar").value = %Player.health
	
	# Reset gun power-ups to initial values
	var gun = %Player.get_node("%Gun")
	gun.projectiles = 1
	gun.bullet_damage_mult = 1.0
	gun.get_node("%ShootTimer").wait_time = 0.5  # Reset to initial fire rate

func new_game():
	reset_game_state()
	game_started = true
	%HUD.set_game_started(true)
	get_tree().paused = false
	
	# Start music
	%Music.play()
	
	# Start spawning mobs
	spawn_initial_mobs()
	%MobTimer.start()

func spawn_initial_mobs():
	spawn_mob()
	spawn_mob()
	spawn_mob()
	spawn_mob()

func spawn_mob():
	# Stronger mobs after 30s
	var mob_type = MOB_SCENE
	if score >= 30:
		mob_type = MOB_STRONG_SCENE
	if score >= 90:
		mob_type = MOB_SUPER_STRONG_SCENE
	var new_mob = mob_type.instantiate()
	new_mob.add_to_group("mobs")
	%PathFollow2D.progress_ratio = randf()
	new_mob.global_position = %PathFollow2D.global_position
	add_child(new_mob)

func game_over():
	game_started = false
	%HUD.set_game_started(false)
	%MobTimer.stop()
	
	# Update best score if current score is higher
	if score > best_score:
		best_score = score
	
	# Stop music and play death sound
	%Music.stop()
	%DeathSound.play()
	
	# Pause the game but allow the death sound to continue playing
	get_tree().paused = true
	%HUD.show_game_over(best_score)

func game_won():
	game_started = false
	%HUD.set_game_started(false)
	%MobTimer.stop()
	
	# Update best score (winning always means you got the max score)
	best_score = score
	
	# Stop music
	%Music.stop()
	
	# Pause the game
	get_tree().paused = true
	%HUD.show_game_won(best_score)


func _on_mob_timer_timeout() -> void:
	if game_started:
		spawn_mob()

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

func _on_hud_powerup_selected(powerup: String) -> void:
	apply_powerup(powerup)
