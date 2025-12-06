extends Node2D

@onready var animated_sprite = $AnimatedSprite2D

var current_animation = "idle"

func _ready():
	# Start with idle animation
	play_idle_animation()

func play_idle_animation():
	if current_animation == "idle":
		return
	
	current_animation = "idle"
	if animated_sprite:
		animated_sprite.play("idle")

func play_walk_animation():
	if current_animation == "walk":
		return
	
	current_animation = "walk"
	if animated_sprite:
		animated_sprite.play("walk")

func play_attack_animation():
	if current_animation == "attack":
		return
	
	current_animation = "attack"
	if animated_sprite:
		animated_sprite.play("attack")
