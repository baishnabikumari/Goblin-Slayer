extends Node2D

@export var move_time:=0.15
@export var stop_time:=0.2
@export var explosion_delay:=0.3
@onready var anim: AnimatedSprite2D = $anim
@onready var fire_audio: AudioStreamPlayer = $anim/fire_audio

var target_position:Vector2
var direction:Vector2

func _ready() -> void:
	z_index=5
	fire_audio.play()

func throw(from_pos:Vector2,to_pos:Vector2)->void:
	global_position=from_pos
	target_position=to_pos
	direction=(to_pos-from_pos).normalized()

	if direction!=Vector2.ZERO:
		rotation=direction.angle()

	start_throw()

func start_throw()->void:
	var tween:=create_tween()

	tween.tween_property(
		self,
		"global_position",
		target_position,
		move_time
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	tween.tween_interval(stop_time)

	tween.tween_property(self,"scale",Vector2(1.1,1.1),0.05)
	tween.tween_property(self,"scale",Vector2.ONE,0.05)

	tween.tween_callback(spawn_explosion)

func spawn_explosion()->void:
	await get_tree().create_timer(explosion_delay).timeout

	var explo:=preload("res://Units/effect fx/explo/min_explo1.tscn").instantiate()
	get_parent().add_child(explo)
	explo.global_position=global_position
	explo.z_index=5
	fire_audio.stop()
	queue_free()
