extends Node2D

func play_idle_animation():
	%AnimationPlayer.play("idle")

func play_walk_animation():
	%AnimationPlayer.play("walk")

func set_facing_direction(direction_x: float):
	print("Setting facing direction: ", direction_x)
	if direction_x > 0:
		# Moving right - face right (normal)
		print("Setting scale.x to positive (facing right)")
		scale.x = abs(scale.x)
	elif direction_x < 0:
		# Moving left - face left (flipped)
		print("Setting scale.x to negative (facing left)")
		scale.x = -abs(scale.x)
	print("Current scale.x value: ", scale.x)
