extends Node2D

func play_idle_animation():
	%AnimationPlayer.play("idle")

func play_walk_animation():
	%AnimationPlayer.play("walk")

func play_dead_animation():
	# PlayerCharacter: Playing dead animation
	if has_node("%AnimationPlayer"):
		%AnimationPlayer.play("dead")
		# PlayerCharacter: Dead animation started
	else:
		print("PlayerCharacter: ERROR - AnimationPlayer not found!")

func set_facing_direction(direction_x: float):
	# Setting facing direction
	if direction_x > 0:
		# Moving right - face right (normal)
		# Setting scale.x to positive (facing right)
		scale.x = abs(scale.x)
	elif direction_x < 0:
		# Moving left - face left (flipped)
		# Setting scale.x to negative (facing left)
		scale.x = -abs(scale.x)
	# Current scale.x value logged
