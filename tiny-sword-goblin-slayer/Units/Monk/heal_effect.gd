extends Area2D
@onready var anim: AnimatedSprite2D = $anim

func _ready() -> void:
	z_index=5
	anim.play("sp")
	
func _on_anim_animation_finished() -> void:
	queue_free()
