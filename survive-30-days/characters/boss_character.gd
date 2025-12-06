extends Node2D

@onready var animated_sprite = $AnimatedSprite2D

var current_animation = "idle"

func _ready():
	# Start with idle animation
	play_idle_animation()

func play_idle_animation():
	if current_animation == "idle":
		return
	
	# Don't play idle animation if dying
	if current_animation == "dying":
		# Boss Character: Ignoring idle animation - currently dying
		return
	
	current_animation = "idle"
	if animated_sprite:
		animated_sprite.play("idle")

func play_walk_animation():
	if current_animation == "walk":
		return
	
	# Don't play walk animation if dying
	if current_animation == "dying":
		# Boss Character: Ignoring walk animation - currently dying
		return
	
	current_animation = "walk"
	if animated_sprite:
		animated_sprite.play("walk")

func play_attack_animation():
	# Don't play attack animation if dying
	if current_animation == "dying":
		# Boss Character: Ignoring attack animation - currently dying
		return
		
	current_animation = "attack"
	if animated_sprite:
		# Always play attack animation to ensure it continues/restarts
		animated_sprite.play("attack")

func play_dying_animation():
	# Boss Character: play_dying_animation called
	current_animation = "dying"
	if animated_sprite:
		# Boss Character: AnimatedSprite2D found
		# Force stop any current animation first
		animated_sprite.stop()
		# Now play the dying animation
		animated_sprite.play("dying")
			# Boss Character: Playing 'dying' animation
		if animated_sprite.sprite_frames:
			# Boss Character: Dying animation frame count logged
			# Boss Character: Current animation logged
			pass
		else:
			print("Boss Character: No sprite_frames found!")
	else:
		print("Boss Character: No AnimatedSprite2D found!")

func play_hurt_animation():
	if current_animation == "hurt":
		return
	
	# Don't play hurt animation if dying
	if current_animation == "dying":
		# Boss Character: Ignoring hurt animation - currently dying
		return
	
	current_animation = "hurt"
	if animated_sprite:
		animated_sprite.play("hurt")
