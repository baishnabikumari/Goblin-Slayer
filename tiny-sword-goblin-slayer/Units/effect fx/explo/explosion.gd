extends AnimatedSprite2D

@onready var explosion: AnimatedSprite2D = $"."
@onready var explo: Area2D = $explo
@onready var explo_audio: AudioStreamPlayer = $explo_audio
@onready var shape: CollisionShape2D = $explo/shape

var pos

func _ready() -> void:
	if not explo_audio.playing:
		explo_audio.play()
		explosion.play("sp")
		scale=Vector2(2,2)

func _on_animation_finished() -> void:
	queue_free()

func _on_explo_body_entered(body: Node2D) -> void:
	if body.is_in_group("building"):
		pos=body.global_position
		fire()
	if body.is_in_group("player"):
		pos=body.global_position
		flame()

func fire():
	var scene=preload("res://Units/effect fx/fire/fire.tscn")
	var _scene=scene.instantiate()
	get_parent().add_child(_scene)
	_scene.global_position=pos
	_scene.z_index=10

func flame():
	var scene=preload("res://Units/effect fx/fire/flame1.tscn")
	var _scene=scene.instantiate()
	get_parent().add_child(_scene)
	_scene.global_position=pos
	_scene.z_index=10
