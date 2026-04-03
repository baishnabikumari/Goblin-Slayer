extends StaticBody2D

@onready var anim: AnimatedSprite2D = $anim
@onready var collision_shape_2d: CollisionShape2D = $CollisionShape2D
@onready var mine_zone: Area2D = $"mine zone"
@onready var marker_2d: Marker2D = $Marker2D
@onready var health_bar: ProgressBar = $health_bar
@onready var rock_audio: AudioStreamPlayer = $rock_audio

#====================
# CONSTANTS
#====================
const GOLD_SCENE:=preload("res://Units/material/gold/gold.tscn")
const RESTORE_TIME:=20.0
const HIT_COOLDOWN:=0.5

#====================
# Variables
#====================
@export var Mine_level:=1
@export var min_gold=2
@export var max_gold=4

var max_life:=5
var current_life:=max_life
var is_regenerating:=false
var can_take_damage:=true

#====================
# Ready
#====================
func _ready() -> void:
	print("mine zone position: ", $"mine zone".global_position)
	z_index=4
	add_to_group("block_building")
	setup_restore_timer()
	setup_hit_cooldown()
	health_bar.max_value=max_life
	health_bar.value=current_life
	health_bar.visible=false

func setup_restore_timer()->void:
	restore_timer=Timer.new()
	restore_timer.one_shot=true
	restore_timer.wait_time=RESTORE_TIME
	add_child(restore_timer)
	restore_timer.timeout.connect(_on_restore_timer_timeout)

func setup_hit_cooldown()->void:
	hit_cooldown_timer=Timer.new()
	hit_cooldown_timer.one_shot=true
	hit_cooldown_timer.wait_time=HIT_COOLDOWN
	add_child(hit_cooldown_timer)
	hit_cooldown_timer.timeout.connect(func():can_take_damage=true)

var restore_timer:Timer
var hit_cooldown_timer:Timer

#====================
# damage system
#====================
func take_damage():
	if is_regenerating or not can_take_damage:
		return
	
	can_take_damage=false
	hit_cooldown_timer.start()
	current_life-=1
	
	health_bar.visible=true
	health_bar.value=current_life
	
	if not rock_audio.playing:
		rock_audio.play()
	
	spawn_gold()
	play_hit_feedback()
	update_transparency()
	
	if current_life<=0:
		health_bar.visible=false
		handle_depletion()
	else:
		_hide_health_bar_after_delay()

func _hide_health_bar_after_delay():
	await get_tree().create_timer(2.0).timeout
	if not is_regenerating and current_life>0:
		health_bar.visible=false

#func _on_mine_zone_area_entered(area: Area2D) -> void:
	#if can_take_damage:
		#return
	#if area.is_in_group("attackeffect") and Global.pawn_tool=="pickaxe":
		#take_damage()

func play_hit_feedback()->void:
	anim.modulate=Color.RED
	anim.create_tween().tween_property(anim,"modulate",Color.WHITE,0.25)

func handle_depletion():
	is_regenerating=true
	health_bar.visible=false
	collision_shape_2d.set_deferred("disabled",true)
	mine_zone.set_deferred("monitoring",false)
	anim.visible=false
	restore_timer.start()

func _on_restore_timer_timeout()->void:
	current_life=max_life
	is_regenerating=false
	can_take_damage=true

	health_bar.value=current_life

	collision_shape_2d.set_deferred("disabled",false)
	mine_zone.set_deferred("monitoring",true)
	anim.visible=true

	anim.modulate=Color.GREEN
	anim.create_tween().tween_property(anim,"modulate",Color.WHITE,0.5)

	update_transparency()

func spawn_gold()->void:
	var gold_count:=randi_range(min_gold,max_gold)
	for i in range(gold_count):
		var gold=GOLD_SCENE.instantiate()
		get_tree().current_scene.add_child.call_deferred(gold)
		var offset:=Vector2(
			randf_range(-35,35),
			randf_range(75,105)
		)
		await get_tree().process_frame
		gold.global_position=marker_2d.global_position+offset
		gold.z_index=6

func update_transparency():
	if current_life<max_life:
		anim.modulate.a=0.5
	else:
		anim.modulate.a=1.0

func _exit_tree() -> void:
	if restore_timer:
		restore_timer.queue_free()
	if hit_cooldown_timer:
		hit_cooldown_timer.queue_free()

func _on_mine_zone_area_entered(area: Area2D) -> void:
	if not can_take_damage:
		return
	if area.is_in_group("attackeffect") and Global.pawn_tool=="pickaxe":
		take_damage()

func update_to_level():
	if Mine_level==1:
		min_gold=2
		max_gold=4
		anim.play("level1")
	if Mine_level==2:
		min_gold=2
		max_gold=4
		anim.play("level2")
	if Mine_level==3:
		min_gold=2
		max_gold=4
		anim.play("level3")
	if Mine_level==4:
		min_gold=2
		max_gold=4
		anim.play("level4")
	if Mine_level==5:
		min_gold=2
		max_gold=4
		anim.play("level5")
	if Mine_level==6:
		min_gold=2
		max_gold=4
		anim.play("level6")
