extends Node2D

# Player character animation controller for Let it Climb

func play_walk_animation():
	%AnimationPlayer.play("walk")

func play_idle_animation():
	%AnimationPlayer.play("idle")

func play_dead_animation():
	%AnimationPlayer.play("dead")

func play_dying_animation():
	# Alias for play_dead_animation for compatibility
	play_dead_animation()
