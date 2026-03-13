extends CharacterBody2D

#-----------------------
#Nodes
#-----------------------
@onready var anim: AnimatedSprite2D = $anim
@onready var shape: CollisionShape2D = $shape
@onready var detector_zone: Area2D = $"detector zone"
@onready var hitbox: Area2D = $hitbox
@onready var shieldbar: ProgressBar = $shieldbar
@onready var hp_bar: ProgressBar = $ProgressBar
@onready var button: Button = $Button
@onready var select_indicator: Label = $"select indicator"
@onready var marker_2d: Marker2D = $Marker2D
@onready var camera_2d: Camera2D = $Camera2D
@onready var nav: NavigationAgent2D = $NavigationAgent2D
@onready var predict_cast: ShapeCast2D = $PredictCast

#-----------------------
#Soundfx
#-----------------------
@onready var click_audio: AudioStreamPlayer2D = $soundfx/click_audio
@onready var death_audio: AudioStreamPlayer2D = $soundfx/death_audio
@onready var hit_audio: AudioStreamPlayer2D = $soundfx/hit_audio
@onready var sword_audio: AudioStreamPlayer2D = $soundfx/sword_audio
@onready var shield_audio: AudioStreamPlayer2D = $soundfx/shield_audio
@onready var spear_audio_1: AudioStreamPlayer2D = $soundfx/spear_audio1
@onready var spear_audio_2: AudioStreamPlayer2D = $soundfx/spear_audio2

var attack_effect_active := false #here i used this to prevent from muliple spawnning

#-----------------------
#Hp/Shield
#-----------------------
var ui_visible:=false
var ui_hide_delay:=1.5 #when no attack
var ui_timer:=0.0

#-----------------------
#Random shielding
#-----------------------
var random_shield_enabled:=true
const MIN_RANDOM_SHIELD_TIME:=5.0
const MAX_RANDOM_SHIELD_TIME:=10.0
var random_shield_timer:=0.0
var next_shield_time:=0.0

#damage constant when the knight is using the shield
const LOW_HP_SHIELD_THRESHOLD:=0.2

#-----------------------
#State
#-----------------------
enum State{IDLE,RUN,ATTACK,GUARD,DEAD}
var state:State=State.IDLE

const ATTACK_RANGE:=10.0

#-----------------------
#stuck and avoidance system
#-----------------------
var last_position:Vector2
var stuck_timer:=0.0

const STUCK_TIME:=0.18
const MIN_MOVE_DIST:=5.0

var avoiding:=false
var avoid_dir:=Vector2.ZERO
const AVOID_FORCE:=1.4

const ALLY_PUSH_RADIUS:=20.0
const ALLY_PUSH_FORCE:=950.0
const STUCK_PULSE_FORCE:=1500.0

#-----------------------
#target locker
#-----------------------
var target_lock_time:=0.0
const TARGET_LOCK_DURATION:=0.5

#-----------------------
#STATS
#-----------------------
@export var max_life:=300
@export var life:=300

@export var max_guard:=200
@export var guard_stamina:=200

@export var speed:=500.0
@export var attack_damage:=10
@export var attack_cooldown:=1.0

#-----------------------
#Control
#-----------------------
var selected:=false
var stop_distance:=10

#-----------------------
#combat
#-----------------------
var target:Node2D=null
var action_locked:=false
var facing_dir:=Vector2.RIGHT

#-----------------------
#guard
#-----------------------
const GUARD_DURATION:=2.5
var guard_timer:=0.0
var guard_locked:=false
var knockback_force:=250.0
var guard_knockback_multiplier:=0.4
var guard_cooldown:=false
var GUARD_COOLDOWN_TIME:=2.5

var manual_mode:=false

#-----------------------
#ready
#-----------------------
func _ready() -> void:
	z_index=4
	scale=Vector2(0.7,0.7)
	add_to_group("selectable")
	hp_bar.visible=false
	shieldbar.visible=false
	
	hp_bar.max_value=max_life
	shieldbar.max_value=max_guard
	update_bars()
	
	select_indicator.visible=false
	
	button.pressed.connect(_on_button_pressed)
	#hitbox.area_entered.connect(_on_hitbox_area_entered)
	
	nav.avoidance_enabled=true
	nav.max_speed=speed
	nav.velocity_computed.connect(_on_nav_velocity)
	last_position=global_position
	
	#avoidance prediction
	nav.path_desired_distance=6.0
	nav.target_desired_distance=stop_distance
	nav.avoidance_enabled=true
	nav.radius=10
	nav.neighbor_distance=40
	nav.max_neighbors=20
	
	#random shield timer
	reset_random_shield_timer()

func reset_random_shield_timer():
	random_shield_timer=0.0
	next_shield_time=randf_range(MIN_RANDOM_SHIELD_TIME,MAX_RANDOM_SHIELD_TIME)

#-----------------------
#Change in states
#-----------------------
func change_state(new_state:State)->void:
	if state==State.DEAD:
		return
	if state==new_state:
		return
	state=new_state

#-----------------------
#Mouse input click
#-----------------------
func _unhandled_input(event: InputEvent) -> void:
	if not selected or state==State.DEAD:
		return
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed:
		issue_move(get_global_mouse_position())

func issue_move(pos:Vector2):
	reset_combat()
	target=null
	movement_priority=true
	manual_mode=true
	resume_navigation()
	
	#destination
	var offset:=Vector2(
		randf_range(-20,20),
		randf_range(-20,20)
	)
	nav.target_position=pos+offset
	change_state(State.RUN)
	set_selected(false)

#-----------------------
#process
#-----------------------
func _physics_process(delta: float) -> void:
	if state==State.ATTACK and is_instance_valid(target):
		update_facing((target.global_position-global_position).normalized())
	if state==State.RUN:
		check_stuck(delta)
	
	#update random shield
	if random_shield_enabled and not guard_locked and state!=State.GUARD and state !=State.DEAD:
		random_shield_timer+=delta
		if random_shield_timer>=next_shield_time:
			try_activate_random_shield()
	
	
	#ui auto hide
	if ui_visible:
		ui_timer+=delta
		if ui_timer>=ui_hide_delay:
			ui_visible=false
			
			var tween :=create_tween()
			tween.tween_property(hp_bar, "modulate.a",0.0,0.3)
			tween.tween_property(shieldbar,"modulate.a",0.0,0.3)
	
	if guard_locked:
		return
	
	match state:
		State.IDLE:
			state_idle()
		State.RUN:
			state_run()
		State.ATTACK:
			pass
		State.GUARD:
			state_guard(delta)
func try_activate_random_shield():
	if action_locked or guard_cooldown or guard_stamina<20:
		return
	if randf()<0.7:
		start_guard()
		reset_random_shield_timer()

#-----------------------
#states
#-----------------------
func state_idle():
	anim.play("idle")
	acquire_target()
	if target:
		start_attack()

func state_run():
	anim.play("run")
	
	if is_instance_valid(target):
		nav.target_position=target.global_position
		var dist:=global_position.distance_to(target.global_position)
		if dist<= ATTACK_RANGE:
			stop_navigation()
			velocity=Vector2.ZERO
			change_state(State.ATTACK)
			start_attack()
			return
	if nav.distance_to_target()<=stop_distance:
		velocity=Vector2.ZERO
		manual_mode=false
		movement_priority=false
		change_state(State.IDLE)
		return
	var dir:=(nav.get_next_path_position()-global_position).normalized()
	update_facing(dir)
	nav.set_velocity(dir*speed)

#-----------------------
#Attack lock action
#-----------------------
func start_attack():
	if action_locked or not is_instance_valid(target):
		return
	action_locked=true
	change_state(State.ATTACK)
	stop_navigation()
	facing_dir=(target.global_position-global_position).normalized()
	attack_loop()

func attack_loop()-> void:
	if not (target.is_in_group("goblin") or target.is_in_group("goblinbuildings")):
		return
	attack_effect_active=true
	while is_instance_valid(target):
		if not (target.is_in_group("goblin") or target.is_in_group("goblinbuildings")):
			break
		var dir:=(target.global_position-global_position).normalized()
		update_facing(dir)
		
		#animation
		anim.play(pick_attack_anim())
		if not sword_audio.playing:
			sword_audio.play()
		#spawn damage/ attackeffect
		if target.is_in_group("goblin"):
			apply_damage(target)
		else:
			apply_damage_building(target)
		
		#cooldown
		await get_tree().create_timer(attack_cooldown).timeout
	#attack finished
	reset_combat()
	change_state(State.IDLE)
	attack_effect_active=false

#-----------------------
#Guard
#-----------------------
func start_guard():
	if action_locked:
		return
	action_locked=true
	guard_timer=0.0
	change_state(State.GUARD)
	stop_navigation()
	anim.play("guard")

func state_guard(delta):
	guard_timer+=delta
	guard_stamina=min(guard_stamina+int(25*delta),max_guard)
	update_bars()
	
	face_closest_goblin()
	
	if guard_timer>=GUARD_DURATION:
		reset_combat()
		reset_random_shield_timer()
		change_state(State.IDLE)

#-----------------------
#Targeting
#-----------------------
func acquire_target(delta:=0.0):
	if is_instance_valid(target):
		target_lock_time+=delta
		if target_lock_time<TARGET_LOCK_DURATION:
			return
	else :
		target_lock_time=0.0
	var closest:Node2D=null
	var dist:=INF
	for body in detector_zone.get_overlapping_bodies():
		if (body.is_in_group("goblin") or body.is_in_group("goblinbuildings")):
			var d=global_position.distance_to(body.global_position)
			if d<dist:
				dist=d
				closest=body
	target=closest
	target_lock_time=0.0

func face_closest_goblin():
	var closest:Node2D=null
	var dist:=INF
	for body in detector_zone.get_overlapping_bodies():
		if (body.is_in_group("goblin") or body.is_in_group("goblinbuildings")):
			var d=global_position.distance_to(body.global_position)
			if d<dist:
				dist=d
				closest=body
	if closest:
		update_facing((closest.global_position-global_position).normalized())

#-----------------------
#Navigation
#-----------------------
func stop_navigation():
	if nav==null:
		return
	nav.set_velocity(Vector2.ZERO)
	nav.avoidance_enabled=false

func resume_navigation():
	nav.avoidance_enabled=true

func _on_nav_velocity(v:Vector2):
	if state!=State.RUN:
		return
	var final_velocity:=v
	#avoidance
	if predict_cast.is_colliding():
		var normal:=predict_cast.get_collision_normal(0)
		var side:=Vector2(-normal.y,normal.x)
		final_velocity+=side*speed*AVOID_FORCE
	
	#sepration
	final_velocity+=apply_ally_separation()
	velocity=final_velocity.limit_length(speed*1.2)
	move_and_slide()

#-----------------------
#Damage
#-----------------------
func take_damage(amount:int,dir:Vector2):
	show_combat_ui()
	if state==State.DEAD:
		return
	
	#-----------------------
	#shield absorbs damages
	#-----------------------
	if state==State.GUARD and guard_stamina>0:
		guard_stamina-=amount
		if not shield_audio.playing:
			shield_audio.play()
		update_bars()
		velocity=-dir.normalized()*knockback_force*guard_knockback_multiplier
		update_facing(-dir)
		move_and_slide()
		reset_random_shield_timer()
		if guard_stamina<=0:
			guard_stamina=0
			guard_timer=GUARD_DURATION
		return

#-----------------------
#low hp guard sequence faster
#-----------------------
	if life <=max_life*LOW_HP_SHIELD_THRESHOLD and not action_locked and not guard_cooldown and guard_stamina>20:
		start_guard()
		start_guard_cooldown()
		return
	life-=amount
	if GlobalPlayer.camera_shake_func.is_valid():
		GlobalPlayer.camera_shake_func.call()
	update_facing(-dir)
	flash_red()
	
	velocity=-dir.normalized()*knockback_force
	update_facing(-dir)
	move_and_slide()
	
	if life<=0:
		die()

func start_guard_cooldown():
	guard_cooldown=true
	await get_tree().create_timer(GUARD_COOLDOWN_TIME).timeout
	guard_cooldown=false

#-----------------------
#Attack/Effects
#-----------------------
func apply_damage(enemy:Node2D):
	if enemy.has_method("take_damage"):
		enemy.take_damage(attack_damage,enemy.global_position-global_position)
func apply_damage_building(enemy:Node2D):
	if enemy.has_method("take_damage"):
		enemy.take_damage(attack_damage)

func pick_attack_anim()->String:
	return "attack" if randf()<0.5 else "attack2"


#-----------------------
#Targeting
#-----------------------
func reset_combat():
	action_locked=false
	target=null
	guard_timer=0.0
	resume_navigation()
	
#visual effects
func update_facing(dir:Vector2):
	if abs(dir.x)>0.01:
		anim.flip_h=dir.x<0

func flash_red():
	anim.modulate=Color(1,0.2,0.2)
	await get_tree().create_timer(0.1).timeout
	anim.modulate=Color.WHITE

func update_bars():
	hp_bar.value=life
	shieldbar.value=guard_stamina

#-----------------------
#selection
#-----------------------
func set_selected(v:bool):
	selected=v
	select_indicator.visible=v

func _on_button_pressed() -> void:
	set_selected(!selected)
	click_audio.play()
	if selected:
		manual_mode=true

#-----------------------
#Hitbox
#-----------------------
func _on_hitbox_area_entered(area: Area2D) -> void:
	if area.is_in_group("explo"):
		take_damage(30,area.global_position-global_position)
		if not hit_audio.playing:
			hit_audio.play()
		if area.is_in_group("heal"):
			life=max_life
			show_combat_ui()

#-----------------------
#death
#-----------------------
signal died(knight:Node2D)

func die():
	emit_signal("died", self)
	stop_navigation()
	shape.disabled=true
	hitbox.monitoring=false
	set_selected(false)
	
	var skull:=preload("res://materials_effects/skull/skull.tscn").instantiate()
	get_parent().add_child(skull)
	skull.global_position=global_position
	skull.scale=Vector2(0.5,0.5)
	
	if not death_audio.playing:
		death_audio.play()
	
	var tween:=create_tween()
	tween.tween_property(self,"modulate.a",0.0,0.1)
	await tween.finished
	queue_free()

func can_use_navigation()->bool:
	return(
		nav!=null and
		is_instance_valid(nav) and
		state==State.RUN
	)

func check_stuck(delta):
	var move_dist:=global_position.distance_to(last_position)
	
	if move_dist<MIN_MOVE_DIST and state==State.RUN:
		stuck_timer+=delta
	else:
		stuck_timer=0.0
		last_position=global_position
	if stuck_timer>=STUCK_TIME:
		resolve_stuck()
		stuck_timer=0.0

func resolve_stuck():
	var axis:=Vector2.ZERO
	if randf()<0.5:
		axis.x=-1 if randf()<0.5 else 1
	else:
		axis.y=-1 if randf()<0.5 else 1
	
	velocity=axis*STUCK_PULSE_FORCE
	move_and_slide()
	nav.target_position+= axis * randf_range(24,48)

var movement_priority:=false
func _on_detector_zone_body_entered(body: Node2D) -> void:
	if movement_priority or action_locked or state==State.DEAD:
		return
	if body.is_in_group("goblin") or body.is_in_group("goblinbuildings"):
		target=body
		manual_mode=false
		
		#start chasing the body
		nav.target_position=body.global_position
		change_state(State.RUN)

#-----------------------------
#check for the life below 80% before healing
#-----------------------------
func get_health_percentage()->float:
	return float(life)/float(max_life)
	
func get_health()->int:
	return life
	
func get_max_health()->int:
	return max_life

func apply_ally_separation() -> Vector2:
	var push:=Vector2.ZERO
	for body in detector_zone.get_overlapping_bodies():
		if body ==self:
			continue
		if body.is_in_group("selectable"):
			var diff:=global_position-body.global_position
			var dist :=diff.length()
			if dist>0 and dist<ALLY_PUSH_RADIUS:
				push+= diff.normalized()*(ALLY_PUSH_FORCE/max(dist,4))
	return push

func show_combat_ui():
	ui_visible=true
	ui_timer=0.0
	hp_bar.visible=true
	shieldbar.visible=true
	
	hp_bar.modulate.a=1.0
	shieldbar.modulate.a=1.0
