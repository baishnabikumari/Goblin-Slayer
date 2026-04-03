extends AnimatedSprite2D

#@onready var attackeffect: AnimatedSprite2D = $"."

func _ready() -> void:
	z_index = 4
	play("sp")
	for child in get_children():
		print("attackeffect child: ", child.name, " type: ", child.get_class())
		if child is Area2D:
			child.add_to_group("attackeffect")
			print("group added to: ", child.name)

func die():
	queue_free()

func _on_animation_finished() -> void:
	die()
