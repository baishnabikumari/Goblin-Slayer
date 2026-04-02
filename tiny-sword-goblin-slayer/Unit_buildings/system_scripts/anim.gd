extends AnimatedSprite2D

var current_index
func _ready() -> void:
	current_index=Global.choosed_colour

func _process(delta: float) -> void:
	play(current_index)
