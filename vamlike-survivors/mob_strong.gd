extends CharacterBody2D

@export var speed = 300.0
@export var health = 5
@export var damage = 15.0

@onready var player = get_node("/root/Game/Player")

const SMOKE_SCENE = preload("res://smoke_explosion/smoke_explosion.tscn")
const BUBBLE_POP_SOUND = preload("res://sounds/bubble-pop.mp3")

func _ready():
	%Slime.play_walk()

func _physics_process(delta: float) -> void:
	var direction = global_position.direction_to(player.global_position)
	velocity = direction * speed
	move_and_slide()

func take_damage(dmg):
	health -= dmg
	%Slime.play_hurt()
	
	if health <= 0:
		# Play the bubble pop sound
		var audio_player = AudioStreamPlayer2D.new()
		audio_player.stream = BUBBLE_POP_SOUND
		get_parent().add_child(audio_player)
		audio_player.global_position = global_position
		audio_player.play()
		
		# Create smoke explosion
		var smoke = SMOKE_SCENE.instantiate()
		get_parent().add_child(smoke)
		smoke.global_position = global_position
		
		# Remove the audio player after the sound finishes
		audio_player.finished.connect(func(): audio_player.queue_free())
		
		queue_free()
		
