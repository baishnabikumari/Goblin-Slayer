extends AnimatedSprite2D

@onready var attackeffect: AnimatedSprite2D = $"."

func _ready() -> void:
	z_index=4
	attackeffect.play("sp")

func die():
	queue_free()

func _on_animation_finished() -> void:
	die()
