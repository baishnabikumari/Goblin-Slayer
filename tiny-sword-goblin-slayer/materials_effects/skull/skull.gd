extends AnimatedSprite2D

@onready var skull: AnimatedSprite2D = $"."

func _ready() -> void:
	z_index=4
	skull.play("sp")


@warning_ignore("unused_parameter")
func _process(delta: float) -> void:
	await get_tree().create_timer(2.5).timeout
	fade()

func fade():
	skull.play("sp")
	await skull.animation_finished
	die()

func die():
	queue_free()
