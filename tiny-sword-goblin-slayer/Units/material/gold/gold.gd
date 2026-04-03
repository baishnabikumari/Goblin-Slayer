extends Area2D

@export var resource_type:="gold"
var reserved:=false
var collected:=false

#----------------------------
#nodes
#----------------------------
@onready var anim: AnimatedSprite2D = $anim
@onready var collision_shape_2d: CollisionShape2D = $shape
@onready var collect_audio: AudioStreamPlayer = $collect_audio

func _ready() -> void:
	z_index=6
	anim.play("sp")
	await anim.animation_finished
	anim.play("idle")

func _on_body_entered(body: Node2D) -> void:
	if collected:
		return
	if body.is_in_group("pawn"):
		collected=true
		collect()

func _on_area_entered(area: Area2D) -> void:
	if collected:
		return
	if area.is_in_group("attackeffect"):
		return
	var parent = area.get_parent()
	if parent.is_in_group("pawn"):
		collected=true
		collect()
	
func collect():
	if not collect_audio.playing:
		collect_audio.play()
	Global.add_gold(1)
	collision_shape_2d.set_deferred("disabled",true)
	
	var tween:=create_tween()
	tween.set_parallel(true)
	tween.set_ease(tween.EASE_OUT)
	tween.set_trans(tween.TRANS_BACK)
	
	#fade
	tween.tween_property(self,"modulate:a",0.0,0.5)
	
	#scale
	tween.tween_property(self,"scale",Vector2(2.5,2.5),0.5)
	
	#remove
	tween.finished.connect(queue_free)
