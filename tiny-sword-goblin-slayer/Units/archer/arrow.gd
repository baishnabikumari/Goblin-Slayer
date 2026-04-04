extends Area2D
@onready var anim: AnimatedSprite2D = $anim


#vars
var velocity:Vector2=Vector2.ZERO
var stuck:bool=false
var stuck_body:Node2D=null
var stick_offset:Vector2=Vector2.ZERO

#var of the group affected by the arrows
@export var stick_groups:Array=["goblin","goblinbuildings"]

#arrow lifespan
@export var lifespan:float=0.35

func _ready() -> void:
	area_entered.connect(_on_area_entered)
	_start_lifespan_timer()


#launch arrow
func launch(target_position:Vector2,speed:float)->void:
	velocity=(target_position-global_position).normalized()*speed
	rotation=velocity.angle()

func _physics_process(delta: float) -> void:
	if stuck:
		if is_instance_valid(stuck_body):
			global_position=stuck_body.global_position+stick_offset
		return
	
	global_position+=velocity*delta
	rotation=velocity.angle()

func _on_area_entered(area: Area2D) -> void:
	print("HIT:", area.name)
	if stuck:
		return
	
	var can_stick:bool=false
	for group in stick_groups:
		if area.is_in_group(group) or area.name==group:
			can_stick=true
			break
	if not can_stick:
		return
	
	stuck=true
	velocity=Vector2.ZERO
	
	if area.is_in_group("goblin"):
		if area.has_method("take_damage"):
			area.take_damage(1,global_position)
	if area.is_in_group("goblinbuildings"):
		if area.has_method("take_damage"):
			area.take_damage(30, global_position)
	
	_fade_and_die()

func _start_lifespan_timer()->void:
	await get_tree().create_timer(lifespan).timeout
	if not stuck:
		_fade_and_die()

func _fade_and_die():
	await get_tree().create_timer(0.15).timeout
	var tween:=create_tween()
	tween.tween_property(self,"modulate.a",0.0,0.25)
	tween.finished.connect(queue_free)
