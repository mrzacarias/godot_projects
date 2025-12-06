extends Area2D

const BULLET = preload("res://bullet.tscn")

@export var projectiles = 1
@export var bullet_damage_mult = 1.0


func _physics_process(delta: float) -> void:
	var enemies_in_range = get_overlapping_bodies()
	if enemies_in_range.size() > 0:
		var target_enemy = enemies_in_range.front()
		look_at(target_enemy.global_position)

func create_bullet(rotation_delta=0.0):
	var new_bullet = BULLET.instantiate()
	new_bullet.damage_mult = bullet_damage_mult
	new_bullet.global_position = %ShootingPoint.global_position
	new_bullet.global_rotation = %ShootingPoint.global_rotation + rotation_delta
	%ShootingPoint.add_child(new_bullet)

func single_shot():
	create_bullet()

func double_shot():
	create_bullet(-0.5)
	create_bullet(0.5)

func triple_shot():
	create_bullet(-0.5)
	create_bullet()
	create_bullet(0.5)

func quadruple_shot():
	create_bullet(-0.5)
	create_bullet(-0.25)
	create_bullet(0.25)
	create_bullet(0.5)

func quintuple_shot():
	create_bullet(-0.5)
	create_bullet(-0.25)
	create_bullet()
	create_bullet(0.25)
	create_bullet(0.5)

func shoot():
	if projectiles == 2:
		double_shot()
	elif projectiles == 3:
		triple_shot()
	elif projectiles == 4:
		quadruple_shot()
	elif projectiles == 5:
		quintuple_shot()
	else:
		single_shot()

func _on_timer_timeout() -> void:
	shoot()
