extends RigidBody2D
class_name RockProjectile

signal rock_hit(target_node)

@export var damage: float = 3.0
@export var speed: float = 800.0
@export var rotation_speed: float = 5.0  # Radians per second for slow rotation
@export var lifetime: float = 3.0  # Auto-destroy after 3 seconds

var target_position: Vector2
var direction: Vector2
var has_hit_target: bool = false

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var area: Area2D = $Area2D

func _ready():
	# Set up the rock sprite
	if sprite:
		sprite.texture = load("res://assets/items/materials/rock.png")
		sprite.scale = Vector2(0.05, 0.05)  # 10x smaller (was 0.5, now 0.05)
	
	# Set up collision detection
	if area and not area.body_entered.is_connected(_on_area_body_entered):
		area.body_entered.connect(_on_area_body_entered)
	
	# Set up physics
	gravity_scale = 0  # No gravity for thrown rocks
	linear_damp = 0    # No air resistance
	
	# Auto-destroy after lifetime
	var timer = Timer.new()
	timer.wait_time = lifetime
	timer.one_shot = true
	timer.timeout.connect(_on_lifetime_expired)
	add_child(timer)
	timer.start()

func _physics_process(delta):
	if has_hit_target:
		return
	
	# Rotate the sprite slowly
	if sprite:
		sprite.rotation += rotation_speed * delta
	
	# Move toward target
	if direction != Vector2.ZERO:
		linear_velocity = direction * speed

func launch_at_target(start_pos: Vector2, target_pos: Vector2):
	"""Launch the rock from start position toward target position"""
	global_position = start_pos
	target_position = target_pos
	direction = (target_pos - start_pos).normalized()
	
	# Set initial velocity
	linear_velocity = direction * speed

func _on_area_body_entered(body):
	"""Handle collision with targets"""
	if has_hit_target:
		return
	
	# Ignore the player
	if body.name == "Player":
		return
	
	# Check if it's specifically a mob or boss
	var is_mob = body.get_script() and body.get_script().get_path().ends_with("mob.gd")
	var is_boss = body.get_script() and body.get_script().get_path().ends_with("boss.gd")
	var is_mob_by_name = body.name.begins_with("Mob")
	var is_boss_by_name = body.name.begins_with("Boss")
	
	if (is_mob or is_boss or is_mob_by_name or is_boss_by_name) and body.has_method("take_damage"):
		has_hit_target = true
		
		# Debug output
		print("Rock hit enemy: ", body.name, " (is_boss: ", is_boss or is_boss_by_name, ")")
		
		# Deal damage
		body.take_damage(damage)
		
		# Play appropriate damage sound
		play_damage_sound(is_boss or is_boss_by_name)
		
		# Emit signal
		rock_hit.emit(body)
		
		# Stop movement
		linear_velocity = Vector2.ZERO
		
		# Start destruction sequence
		destroy_rock()

func _on_lifetime_expired():
	"""Called when rock reaches its lifetime limit"""
	destroy_rock()

func play_damage_sound(is_boss: bool):
	"""Play appropriate damage sound based on enemy type"""
	var sound_path = "res://assets/sounds/enemy_hurt.mp3" if not is_boss else "res://assets/sounds/boss_damage.mp3"
	
	print("Playing damage sound: ", sound_path)
	
	# Create and configure audio player - add to the main scene instead of the rock
	var audio_player = AudioStreamPlayer2D.new()
	var sound_resource = load(sound_path)
	
	if sound_resource == null:
		print("ERROR: Could not load sound file: ", sound_path)
		return
	
	audio_player.stream = sound_resource
	audio_player.volume_db = -2.5  # Increased volume by 50%
	audio_player.global_position = global_position
	
	# Add to the main scene tree so it persists after rock is destroyed
	get_tree().current_scene.add_child(audio_player)
	audio_player.play()
	
	print("Sound should be playing now")
	
	# Remove audio player after sound finishes
	audio_player.finished.connect(func(): 
		if is_instance_valid(audio_player):
			audio_player.queue_free()
	)

func destroy_rock():
	"""Destroy the rock projectile"""
	# Fade out effect
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	await tween.finished
	
	# Remove from scene
	queue_free()
