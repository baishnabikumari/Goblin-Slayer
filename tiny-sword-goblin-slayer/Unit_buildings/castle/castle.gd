extends StaticBody2D

#nodes
@onready var anim: AnimatedSprite2D = $anim
@onready var shape: CollisionShape2D = $shape
@onready var marker_1: Marker2D = $Marker1
@onready var marker_2: Marker2D = $Marker2
@onready var marker_3: Marker2D = $Marker3
@onready var explore_detector: Area2D = $ExploreDetector
@onready var placement_checker: Area2D = $PlacementChecker

#val collision
var collision_disabled:bool=false

#sound
@onready var destroyed_fx: AudioStreamPlayer = $"Sound fx/destroyed_fx"
@onready var construct_fx: AudioStreamPlayer = $"Sound fx/construct_fx"

#------------------------------
#variables
#------------------------------
@export var construction_time:= 0.2
@export var max_life:int=10

#------------------------------
#contants
#------------------------------
const FINAL_SCALE:=Vector2(0.8,0.8)
const DOUBLE_CLICK_TIME:=0.3

#------------------------------
#States
#------------------------------
enum {
	STATE_CONSTRUCT,
	STATE_IDLE,
	STATE_DESTROYED
}
var state:=STATE_CONSTRUCT

#------------------------------
#Life/hit
#------------------------------
var life:int
var is_hit:=false
var hit_flash_timer:=0.0
var hit_flash_time:=0.15

#------------------------------
#Knights scenes "not moving knight
#------------------------------
var archer_black=preload("res://Units/archer/archer_black.tscn")
var archer_blue=preload("res://Units/archer/archer_blue.tscn")
var archer_purple=preload("res://Units/archer/archer_purple.tscn")
var archer_red=preload("res://Units/archer/archer_red.tscn")
var archer_yellow=preload("res://Units/archer/archer_yellow.tscn")
var spawned_archer1:Node2D=null
var spawned_archer2:Node2D=null
#pawn
var pawn_black=preload("res://Units/Pawns/pawn_black.tscn")
var pawn_blue=preload("res://Units/Pawns/pawn_blue.tscn")
var pawn_purple=preload("res://Units/Pawns/pawn_purple.tscn")
var pawn_red=preload("res://Units/Pawns/pawn_red.tscn")
var pawn_yellow=preload("res://Units/Pawns/pawn_yellow.tscn")
var spawned_pawn:Node2D=null

#------------------------------
#timer and tweens
#------------------------------
var tween:Tween
var construction_timer:Timer
var spawn_timer:Timer

#------------------------------
#Drag and drop movement logic
#------------------------------
var is_moving:=false
var is_awaiting_placement:=false
var movement_colliding:=false
var movement_collision_timer:=0.0
var movement_valid:=true
var drag_offset:=Vector2.ZERO
var original_position:Vector2=Vector2.ZERO
var overlapping_objects_count:=0

#------------------------------
#the double click
#------------------------------
var last_click_time:=0.0
var is_selected:=false

#------------------------------
#ready func
#------------------------------
func _ready() -> void:
	state=STATE_CONSTRUCT
	GlobalPlayer.castle_position=global_position
	z_index=6
	scale=Vector2(0.8,0.8)
	Global.load_colour()
	life=max_life
	add_to_group("building")
	input_pickable=true
	shape.disabled=true
	
	placement_checker.monitoring=false
	placement_checker.monitorable=true
	
	placement_checker.area_entered.connect(_on_placement_area_entered)
	placement_checker.area_exited.connect(_on_placement_area_exited)
	placement_checker.body_entered.connect(_on_placement_body_entered)
	placement_checker.body_exited.connect(_on_placement_body_exited)
	
	if not explore_detector.area_entered.is_connected(_on_explore_detector_area_entered):
		explore_detector.area_entered.connect(_on_explore_detector_area_entered)
	
	enter_construct_state()

#------------------------------
#Process
#------------------------------
func _process(delta: float) -> void:
	if is_hit:
		hit_flash_timer-=delta
		if hit_flash_timer<=0:
			is_hit=false
			anim.modulate=Color.WHITE
	if movement_colliding:
		movement_collision_timer-=delta
		if  movement_collision_timer<=0:
			movement_colliding=false
			_update_movement_color()
	if is_moving and not is_awaiting_placement:
		var mouse_pos=get_global_mouse_position()
		global_position=mouse_pos-drag_offset
		_check_movement_collisions()

#------------------------------
#Input from mouse
#------------------------------
@warning_ignore("unused_parameter")
func _input_event(viewport: Viewport, event: InputEvent, shape_idx: int) -> void:
	if not event is InputEventMouseButton:
		return
	var mouse_event := event as InputEventMouseButton
	
	if mouse_event.button_index == MOUSE_BUTTON_LEFT:
		if mouse_event.pressed:
			var now=Time.get_ticks_msec()/1000.0 #added now never was decleareed
			if now-last_click_time<=DOUBLE_CLICK_TIME:
				_on_double_click()
			else:
				_on_single_click()
			last_click_time=now
		else:
			pass
	elif mouse_event.button_index==MOUSE_BUTTON_RIGHT and mouse_event.pressed:
		_cancel_movement()

func _on_single_click()->void:
	is_selected=true
	if anim:
		anim.modulate=Color.WHITE

func _on_double_click()->void:
	if state != STATE_IDLE:
		return
	start_moving()

func _update_movement_color()->void:
	if not is_moving:
		return
	
	movement_valid=overlapping_objects_count==0
	anim.modulate=Color.GREEN if movement_valid else Color.RED

#------------------------------
#Movement
#------------------------------
func start_moving()->void:
	update_collision_logic()
	is_moving=true
	original_position=global_position
	drag_offset=get_global_mouse_position()-global_position
	overlapping_objects_count=0
	movement_valid=true
	is_awaiting_placement=false
	movement_colliding=false
	
	shape.disabled=true
	
	placement_checker.monitoring=true
	if anim:
		anim.modulate=Color.WHITE

func finilize_movement()->void:
	if !movement_valid:
		var return_tween=create_tween()
		return_tween.tween_property(self,"global_position",original_position,0.2)
		return_tween.finished.connect(_reset_after_movement)
	else:
		_reset_after_movement()

func _reset_after_movement():
	update_collision_logic()
	is_moving=false
	is_awaiting_placement=false
	overlapping_objects_count=0
	movement_valid=true
	#if not drop_fx.playing:
		#drop_fx.play()
	movement_colliding=false
	input_pickable=true
	
	placement_checker.monitoring=false
	shape.disabled=false
	anim.modulate=Color.WHITE

func _cancel_movement()->void:
	var return_tween=create_tween()
	return_tween.tween_property(self,"global_position",original_position,0.2)
	return_tween.finished.connect(_reset_after_movement)

#------------------------------
#Placement checker
#------------------------------
func _handle_overlap(node:Node,entered:bool)->void:
	if not is_moving:
		return
	if node==self or is_ancestor_of(node):
		return
	
	if node.is_in_group("building") or node.is_in_group("block_building"):
		overlapping_objects_count+=1 if entered else -1
		overlapping_objects_count=max(0,overlapping_objects_count)

func _on_placement_area_entered(area:Area2D)->void:
	if not is_moving:return
	var parent=area.get_parent()
	if parent and parent!=self:
		if parent.is_in_group("building") or parent.is_in_group("block_building"):
			overlapping_objects_count+=1
			_update_collision_state()


func _on_placement_area_exited(area:Area2D)->void:
	if not is_moving:return
	var parent=area.get_parent()
	if parent and parent!=self:
		if parent.is_in_group("building") or parent.is_in_group("block_building"):
			overlapping_objects_count=max(0,overlapping_objects_count-1)
			_update_collision_state()


func _on_placement_body_entered(body:Node)->void:
	if not is_moving:return
	if body!=self:
		if body.is_in_group("building") or body.is_in_group("block_building") or body is TileMapLayer:
			overlapping_objects_count+=1
			_update_collision_state()

func _on_placement_body_exited(body:Node)->void:
	if not is_moving:return
	if body!=self:
		if body.is_in_group("building") or body.is_in_group("block_building") or body is TileMapLayer:
			overlapping_objects_count=max(0,overlapping_objects_count-1)
			_update_collision_state()

func _update_collision_state():
	if not is_moving:return
	movement_valid=(overlapping_objects_count==0)
	_update_movement_color()
	if not movement_valid and not movement_colliding:
		movement_colliding=true
		movement_collision_timer=0.2
		if anim:
			anim.modulate=Color.RED


func _check_movement_collisions()->void:
	if not is_moving or is_awaiting_placement:return
	
	# check if on water/collider tilemap
	var space_state=get_world_2d().direct_space_state
	var query=PhysicsPointQueryParameters2D.new()
	query.position=global_position
	query.collision_mask=1
	var results=space_state.intersect_point(query)
	
	var on_water=false
	for r in results:
		if r.collider is TileMapLayer:
			on_water=true
			break
	
	if on_water:
		movement_valid=false
	else:
		movement_valid=overlapping_objects_count==0
	
	if anim:
		anim.modulate=Color.GREEN if movement_valid else Color.RED

func _unhandled_input(event: InputEvent) -> void:
	if not is_moving:
		return
	if event is InputEventMouseButton:
		var mouse_event = event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and not mouse_event.pressed:
			finilize_movement()
		elif mouse_event.button_index == MOUSE_BUTTON_RIGHT and mouse_event.pressed:
			_cancel_movement()

#func _update_movement_color()->void:
	#if not is_moving:
		#return
	#
	#movement_valid=overlapping_objects_count==0
	#anim.modulate=Color.GREEN if movement_valid else Color.RED

func clear_timer_and_tweens()->void:
	if tween and tween.is_running():
		tween.kill()
	tween=null
	
	if construction_timer:
		construction_timer.queue_free()
		construction_timer=null
	if spawn_timer:
		spawn_timer.queue_free()
		spawn_timer=null

#------------------------------
#States
#------------------------------
func enter_construct_state()->void:
	state=STATE_CONSTRUCT
	anim.play("construct")
	construct_fx.stop()
	construct_fx.play()
	scale=Vector2.ZERO
	shape.disabled=true
	update_collision_logic()
	input_pickable=false
	
	tween=create_tween()
	tween.tween_property(self,"scale",FINAL_SCALE,construction_time)
	
	construction_timer=Timer.new()
	construction_timer.wait_time=construction_time
	construction_timer.one_shot=true
	add_child(construction_timer)
	construction_timer.timeout.connect(enter_idle_state)
	construction_timer.start()

func _on_contruct_finished():
	enter_idle_state()
	construct_fx.stop()
	update_collision_logic()

func enter_idle_state()->void:
	clear_timer_and_tweens()
	state=STATE_IDLE
	life=max_life
	anim.play("idle")
	construct_fx.stop()
	scale=FINAL_SCALE
	shape.disabled=false
	input_pickable=true
	is_moving=false
	is_awaiting_placement=false
	movement_valid=true
	movement_colliding=false
	overlapping_objects_count=0
	placement_checker.monitoring=false
	if anim:
		anim.modulate=Color.WHITE

	spawn_archer()
	spawn_pawn()

func enter_destroyed_state()->void:
	if state==STATE_DESTROYED:
		return
	
	shape.disabled=true
	explore_detector.monitoring=false
	placement_checker.monitoring=false
	placement_checker.monitorable=false
	input_pickable=false
	is_moving=false
	
	emit_signal("died",self)
	clear_timer_and_tweens()
	
	state=STATE_DESTROYED
	anim.play("destroyed")
	if not destroyed_fx.playing:
		destroyed_fx.play()
	
	remove_from_group("castle")
	
	if spawned_archer1 and spawned_archer1.has_node("CollisionShape2D"):
		spawned_archer1.get_node("CollisionShape2D").disabled=true
	if spawned_archer2 and spawned_archer2.has_node("CollisionShape2D"):
		spawned_archer2.get_node("CollisionShape2D").disabled=true

	#kill the archer on top of the castle when its destroyed
	if spawned_archer1:
		spawned_archer1.queue_free()
		spawned_archer1=null
	if spawned_archer2:
		spawned_archer2.queue_free()
		spawned_archer2=null
	
	is_moving=false
	is_awaiting_placement=false
	overlapping_objects_count=0


func _on_explore_detector_area_entered(area: Area2D) -> void:
	if state!=STATE_IDLE:
		return
	if area.is_in_group("explo"):
		take_damage(1)

func take_damage(amount:int)->void:
	if state!=STATE_IDLE:
		return
	life-=amount
	life=max(life,0)
	
	is_hit=true
	flash_red_once()
	if life<=0:
		enter_destroyed_state()

var hit_tween:Tween
func flash_red_once():
	if hit_tween and hit_tween.is_running():
		hit_tween.kill()
	hit_tween=create_tween()
	hit_tween.tween_property(anim,"modulate", Color.RED,0.05)
	hit_tween.tween_property(anim,"modulate", Color.WHITE,0.08)

func spawn_archer()->void:
	if spawned_archer1!=null:
		return
	if spawned_archer2!=null:
		return
	
	var archer_scene:PackedScene
	match Global.choosed_colour.to_lower():
		"black":archer_scene=archer_black
		"blue":archer_scene=archer_blue
		"purple":archer_scene=archer_purple
		"red":archer_scene=archer_red
		"yellow":archer_scene=archer_yellow
		_: return
	
	spawned_archer1=archer_scene.instantiate()
	spawned_archer2=archer_scene.instantiate()
	add_child(spawned_archer1)
	add_child(spawned_archer2)
	spawned_archer1.global_position=marker_1.global_position
	spawned_archer2.global_position=marker_2.global_position
	spawned_archer1.z_index=5
	spawned_archer2.z_index=5
	spawned_archer1.scale=Vector2(0.7,0.7)
	spawned_archer2.scale=Vector2(0.7,0.7)

func spawn_pawn()->void:
	if spawned_pawn != null:
		return

	var pawn_scene: PackedScene
	match Global.choosed_colour.to_lower():
		"black": pawn_scene = pawn_black
		"blue": pawn_scene = pawn_blue
		"purple": pawn_scene = pawn_purple
		"red": pawn_scene = pawn_red
		"yellow": pawn_scene = pawn_yellow
		_: return
	
	spawned_pawn=pawn_scene.instantiate()
	add_child(spawned_pawn)
	spawned_pawn.global_position=marker_3.global_position
	spawned_pawn.z_index=5
	#spawned_pawn.scale=Vector2(0.7,0.7)
	Global.consume_meat(1)

func update_collision_logic() -> void:
	var new_disabled := (state == STATE_CONSTRUCT) or (state == STATE_DESTROYED) or is_moving
	if shape.disabled != new_disabled:
		shape.disabled = new_disabled
