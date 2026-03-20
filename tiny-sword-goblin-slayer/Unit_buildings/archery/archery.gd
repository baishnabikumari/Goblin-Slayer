extends StaticBody2D

#nodes
@onready var anim: AnimatedSprite2D = $anim
@onready var collision: CollisionShape2D = $shape
@onready var marker_1: Marker2D = $Marker1
@onready var marker_2: Marker2D = $Marker2
#@onready var tower: Area2D = $tower
@onready var explore_detector: Area2D = $ExploreDetector
@onready var repair_detector: Area2D = $RepairDetector
@onready var placement_checker: Area2D = $PlacementChecker

#val collision
var collision_disabled:bool=false

#sound
@onready var destroyed_fx: AudioStreamPlayer = $"Sound fx/destroyed_fx"
@onready var construct_fx: AudioStreamPlayer = $"Sound fx/construct_fx"
@onready var drop_fx: AudioStreamPlayer = $"Sound fx/drop_fx"
@onready var place_fx: AudioStreamPlayer = $"Sound fx/place_fx"

#------------------------------
#variables
#------------------------------
@export var construction_time:float=2.0
@export var max_life:int=6
@export var repair_time:float=4.0
@export var lancer_capacity:int=2
@export var spawn_radius:float=40.0
@export var repair_gold_cost:=30
@export var repair_wood_cost:=20
@export var repair_health_amount:int=2
var is_dead:bool=false

#------------------------------
#contants
#------------------------------
const FINAL_SCALE:=Vector2(0.7,0.7)
const DOUBLE_CLICK_TIME:=0.3
const SPAWN_INTERVAL:=2.0

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
var is_being_repaired:=false
var spawn_cooldown:=0.0

#------------------------------
#Knights scenes "not moving knight
#------------------------------
var archer_black=preload("res://Units/archer/archer_black.tscn")
var knight_blue=preload("res://Units/archer/archer_blue.tscn")
var knight_purple=preload("res://Units/archer/archer_purple.tscn")
var knight_red=preload("res://Units/archer/archer_red.tscn")
var knight_yellow=preload("res://Units/archer/archer_yellow.tscn")

var spawned_knight=[]

#------------------------------
#timer and tweens
#------------------------------
var tween:Tween
var pulse_tween:Tween
#var construct_timer:Timer
var construction_timer:Timer
var repair_timer:Timer
var hit_tween:Tween
var repair_tween:Tween

#------------------------------
#Drag and drop movement logic
#------------------------------
var is_moving:=false
var is_awaiting_placement:=false
var movement_colliding:=false
var movement_collision:=false
var movement_valid:=true
var drag_offset:=Vector2.ZERO
var original_position:Vector2=Vector2.ZERO
var overlapping_objects_count:=0
var movement_collision_timer:=0.0

#------------------------------
#the double click
#------------------------------
var last_click_time:=0.0
var is_selected:=false

#------------------------------
#ready func
#------------------------------
func _ready() -> void:
	z_index=4
	scale=Vector2(0.8,0.8)
	Global.load_colour()
	life=max_life
	add_to_group("building")
	input_pickable=true
	collision_disabled=true
	
	placement_checker.monitoring=false
	placement_checker.monitorable=true
	
	placement_checker.area_entered.connect(_on_placement_area_entered)
	placement_checker.area_exited.connect(_on_placement_area_exited)
	placement_checker.area_entered.connect(_on_placement_body_entered)
	placement_checker.area_exited.connect(_on_placement_body_exited)
	
	explore_detector.area_entered.connect(_on_explo_area_entered)
	repair_detector.area_entered.connect(_on_repair_detector_area_entered)
	
	enter_idle_state()

#------------------------------
#Process
#------------------------------
func _process(delta: float) -> void:
	spawn_cooldown-=delta
	if state==STATE_IDLE and spawned_knight.size()<lancer_capacity and Global.can_spawn():
		if spawn_cooldown<=0.0:
			spawn_lancer()
			spawn_cooldown=SPAWN_INTERVAL
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
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		if event.pressed:
			var now=Time.get_ticks_msec()/1000.0 #added now never was decleareed
			if now-last_click_time<=DOUBLE_CLICK_TIME:
				_on_double_click()
			else:
				_on_single_click()
			last_click_time=now
	else:
		if is_awaiting_placement:
			finilize_movement()
		elif is_moving:
			_cancel_movement()

func _on_single_click()->void:
	is_selected=true
	if anim:
		anim.modulate=Color(1,1,1,1)

func _on_double_click()->void:
	if state!=STATE_IDLE:
		return
	start_moving()

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
	
	collision.disabled=true
	
	if not place_fx.playing:
		place_fx.play()
	
	placement_checker.monitoring=true
	if anim:
		anim.modulate=Color.WHITE

func finilize_movement()->void:
	# check if building is on water/collider
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
	
	if on_water or !movement_valid:
		# send back to original position
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
	if not drop_fx.playing:
		drop_fx.play()
	movement_colliding=false
	input_pickable=true
	
	placement_checker.monitoring=false
	collision.disabled=false
	anim.modulate=Color.WHITE
	
	if state==STATE_IDLE:
		spawn_lancer()

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
	if is_moving and event is InputEventMouseButton:
		var mouse_event=event as InputEventMouseButton
		if mouse_event.button_index==MOUSE_BUTTON_LEFT and not mouse_event.pressed:
			if is_awaiting_placement:
				finilize_movement()
			else:
				is_awaiting_placement=true
				_update_movement_color()
		#press right click to cancle the placement or Event ESC
		elif mouse_event.button_index==MOUSE_BUTTON_RIGHT and mouse_event.pressed:
			_cancel_movement()

func _update_movement_color()->void:
	if not is_moving:
		return
	
	movement_valid=overlapping_objects_count==0
	anim.modulate=Color.GREEN if movement_valid else Color.RED

func clear_timer_and_tweens()->void:
	if tween and tween.is_running():tween.kill()
	tween=null
	if construction_timer:construction_timer.queue_free();construction_timer=null
	if repair_timer:repair_timer.queue_free();repair_timer=null

#------------------------------
#States
#------------------------------
func enter_construct_state()->void:
	state=STATE_CONSTRUCT
	anim.play("construct")
	if not construct_fx.playing:
		construct_fx.play()
	scale=Vector2.ZERO
	collision.disabled=true
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
	update_collision_logic()
	state=STATE_IDLE
	life=max_life
	anim.play("idle")
	construct_fx.stop()
	scale=FINAL_SCALE
	collision.disabled=false
	input_pickable=true
	is_moving=false
	is_awaiting_placement=false
	movement_valid=true
	movement_colliding=false
	overlapping_objects_count=0
	placement_checker.monitoring=false
	if anim:
		anim.modulate=Color.WHITE
	spawned_knight.clear()
	spawn_lancer()

signal died(building:Node2D)
func enter_destroyed_state()->void:
	if state==STATE_DESTROYED:
		return
	
	input_pickable=false
	is_moving=false
	is_awaiting_placement=false
	overlapping_objects_count=0
	remove_from_group("building")
	add_to_group("damaged_buildings")
	
	state=STATE_DESTROYED
	update_collision_logic()
	is_dead=true
	#emit_signal("dead")  
	emit_signal("died",self)
	
	anim.play("destroyed")
	if not destroyed_fx.playing:
		destroyed_fx.play()

#------------------------------
#damage logic
#------------------------------
func _on_explo_area_entered(area:Area2D)->void:
	if state==STATE_IDLE and area.is_in_group("explo"):
		take_damage(1)

func take_damage(amount:int)->void:
	life-=amount
	is_hit=true
	hit_flash_timer=0.15
	flash_red_once()
	if life<=0:
		enter_destroyed_state()

func flash_red_once():
	if hit_tween and hit_tween.is_running():
		hit_tween.kill()
	hit_tween=create_tween()
	hit_tween.tween_property(anim,"modulate",Color.RED,0.05)
	hit_tween.tween_property(anim,"modulate",Color.WHITE,0.08)

#------------------------------
#Repair logic
#------------------------------
func _on_repair_detector_area_entered(area:Area2D)->void:
	if area.is_in_group("repair_effect"):
		if state==STATE_DESTROYED:
			start_repair()

func start_repair()->void:
	if is_being_repaired:
		return
	if state!=STATE_DESTROYED and life>=max_life:
		return
	is_being_repaired=true
	if state==STATE_DESTROYED:
		_repair_destroyed()
	else:
		_repair_damaged()

func _repair_damaged()->void:
	life=min(life+repair_health_amount,max_life)
	flash_green_once()
	show_repair_pulse()
	if not construct_fx.playing:
		construct_fx.play()
	is_being_repaired=false
	if life==max_life and state!=STATE_IDLE:
		enter_idle_state()

func _repair_destroyed():
	flash_green_once()
	show_repair_pulse()
	state=STATE_CONSTRUCT
	anim.play("construct")
	if not construct_fx.playing:
		construct_fx.play()
	
	scale=Vector2.ZERO
	input_pickable=false
	if tween and tween.is_running():
		tween.kill()
	tween=create_tween()
	tween.tween_property(self,"scale",FINAL_SCALE,repair_time)
	
	repair_timer=Timer.new()
	repair_timer.wait_time=repair_time
	repair_timer.one_shot=true
	add_child(repair_timer)
	repair_timer.timeout.connect(_on_destroyed_repair_finished)
	repair_timer.start()

func _on_destroyed_repair_finished():
	is_dead=false
	flash_green_once()
	show_repair_pulse()
	life=max_life
	is_being_repaired=false
	enter_idle_state()
	collision.disabled=false

func finish_repair()->void:
	is_dead=false
	
	flash_green_once()
	
	if repair_timer:
		repair_timer.queue_free()
	
	enter_idle_state()
	
	collision.disabled=false
	
	add_to_group("building")
	add_to_group("block_building")
	remove_from_group("damaged_buildings")

func flash_green_once():
	if repair_tween and repair_tween.is_running():
		repair_tween.kill()
	repair_tween=create_tween()
	repair_tween.tween_property(anim,"modulate",Color.GREEN,0.1)
	repair_tween.tween_property(anim,"modulate",Color.WHITE,0.15)

func show_repair_pulse()->void:
	if pulse_tween and pulse_tween.is_running():
		pulse_tween.kill()
	pulse_tween=create_tween()
	pulse_tween.tween_property(anim,"modulate",Color(0.6,1.0,0.6,1.0),0.3)
	pulse_tween.tween_property(anim,"modulate",Color.GREEN,0.3)

#------------------------------
#Death handler
#------------------------------
func _on_lancer_died(lancer)->void:
	if spawned_knight.has(lancer):
		spawned_knight.erase(lancer)
		

#------------------------------
#spawn archer
#------------------------------
func spawn_lancer()->void:
	if spawned_knight.size()>=lancer_capacity:
		return
	
	#meat availability
	var meat_available=Global.meat
	if meat_available<=0:
		return
	
	#count max lancer capacity
	var remaining_capacity=lancer_capacity-spawned_knight.size()
	var spawn_count=min(remaining_capacity,meat_available)
	if spawn_count<=0:
		return
	
	var lancer_scene:PackedScene
	match Global.choosed_colour.to_lower():
		"black":lancer_scene=archer_black
		"blue":lancer_scene=knight_blue
		"purple":lancer_scene=knight_purple
		"red":lancer_scene=knight_red
		"yellow":lancer_scene=knight_yellow
		_: return
	
	var half=int(ceil(spawn_count/2.0))
	_spawn_lancer_around_marker(marker_1.global_position,half,lancer_scene)
	_spawn_lancer_around_marker(marker_2.global_position,spawn_count-half,lancer_scene)

func _spawn_lancer_around_marker(center:Vector2,count:int,lancer_scene:PackedScene)->void:
	for i in count:
		var new_lancer=lancer_scene.instantiate()
		get_parent().call_deferred("add_child", new_lancer)
		new_lancer.z_index=4
		new_lancer.scale=Vector2(0.7,0.7)
		
		var pos:Vector2
		var tries=0
		while true:
			var angle=randf()*TAU
			var radius=randf()*spawn_radius
			pos=center+Vector2(cos(angle),sin(angle))*radius
			var overlapping=false
			for other in spawned_knight:
				if pos.distance_to(other.global_position)<16.0:
					overlapping=true
					break
			if not overlapping or tries>10:
				break
			tries+=1
		new_lancer.global_position=pos
		spawned_knight.append(new_lancer)
		
		#death signal connected
		new_lancer.died.connect(_on_lancer_died.bind(new_lancer))
		
		#consume meat
		Global.consume_meat(1)
var last_collision_state:bool=false
func update_collision_logic():
	var new_disabled=(state==STATE_CONSTRUCT) or (state==STATE_DESTROYED) or is_moving
	if new_disabled!=collision_disabled:
		collision_disabled=new_disabled
		if collision:
			collision.disabled=collision_disabled
