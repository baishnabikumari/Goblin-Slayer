extends AnimatedSprite2D

@onready var fire: AnimatedSprite2D = $"."
@onready var fire_audio: AudioStreamPlayer = $fire_audio


func _ready() -> void:
	z_index=10
	fire.play("sp")
	#if not fire_audio.playing:
	fire_audio.play()
	await get_tree().create_timer(3.5).timeout
	fade()
	fire_audio.stop()

func fade():
	var tween:=create_tween()
	tween.set_parallel(true)
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)

	tween.tween_property(self,"modulate:a",0.0,0.5)

	tween.tween_property(self,"scale",Vector2(1.5,1.5),0.5)

	tween.finished.connect(queue_free)
