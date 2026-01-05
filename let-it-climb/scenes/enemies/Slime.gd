extends Node2D

# Slime character animation controller for Let it Climb

func play_walk():
	%AnimationPlayer.play("walk")

func play_hurt():
	%AnimationPlayer.play("hurt")
	%AnimationPlayer.queue("walk")

func play_idle():
	%AnimationPlayer.play("idle")
