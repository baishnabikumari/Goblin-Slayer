extends AnimatedSprite2D

@onready var repair: AnimatedSprite2D = $"."

func _ready() -> void:
	z_index=4
	repair.play("sp")

func _on_animation_finished() -> void:
	queue_free()
