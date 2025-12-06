extends Area2D

@export var speed = 1000.0
@export var range = 1200.0
@export var damage = 1

@export var damage_mult = 1.0

var travelled_distance = 0

func _physics_process(delta: float) -> void:
	var direction = Vector2.RIGHT.rotated(rotation)
	position += direction * speed * delta
	
	travelled_distance += speed * delta
	
	if travelled_distance > range:
		queue_free()

func _on_body_entered(body: Node2D) -> void:
	queue_free()
	if body.has_method("take_damage"):
		body.take_damage(damage * damage_mult)
