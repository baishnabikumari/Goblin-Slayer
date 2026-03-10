extends CharacterBody2D

#-------------------------
#ENUM
#-------------------------
enum state{IDLE,RUN,USE,DEAD}

#-------------------------
#Exports
#-------------------------
@export var speed:=300.0
@export var max_life:=100
@export var knockback_force:=320.0
@export var use_duration:=0.5
@export var tool_cooldown:=0.5 #time btw each pressed btn

@export var repair_effect_scene := preload("res://Units/Monk/heal_effect.tscn")
@export var skull_scene := preload("res://materials_effects/skull/skull.tscn")

const INPUT_RIGHT:="move_right"
const INPUT_left:="move_left"
const INPUT_down:="move_down"
const INPUT_up:="move_up"

#-------------------------
#node
#-------------------------
@onready var anim: AnimatedSprite2D = $anim
@onready var detector_zone: Area2D = $detector_zone
@onready var hitbox: Area2D = $hitbox
@onready var progress_bar: ProgressBar = $ProgressBar
@onready var select_indicator: Label = $"select indicator"
@onready var marker_2d: Marker2D = $Marker2D
@onready var use_timer: Timer = $Use_timer

#-------------------------
#references for sound fx
#-------------------------
@onready var click_audio: AudioStreamPlayer = $soundfx/click_audio
@onready var death_audio: AudioStreamPlayer = $soundfx/death_audio
@onready var hit_audio: AudioStreamPlayer = $soundfx/hit_audio

#-------------------------
#state variable
#-------------------------
var Current_state:state=state.IDLE

var active:=false
var busy:=false
var action_lock:=false
var is_guarding:=false
var can_use_tool:=true

var life:int
var knockback_velocity:= Vector2.ZERO
var last_input_dir:= Vector2.DOWN

#-------------------------
#ui visibility (HP/sheild)
#-------------------------
var ui_visible:=false
var ui_hide_delay:=2.5
var ui_timer:=0.0

#-------------------------
#ready func
#-------------------------
func _ready() -> void:
	GlobalPlayer.register_pawn(self)
	progress_bar.visible=false
	z_index=4
	scale=Vector2(0.7,0.7)
	life=max_life
	progress_bar.max_value=max_life
	progress_bar.value=life
	use_timer.wait_time=use_duration
	use_timer.one_shot=true
	
	use_timer.timeout.connect(_on_use_timer_timeout)

#-------------------------
#Input ui
#-------------------------
func _input(event: InputEvent) -> void:
	if not active or Current_state==state.DEAD:
		return

#heal usage
	if event.is_action_pressed("use"):
		spawn_heal_effect()


#-------------------------
#physics process
#-------------------------
func _physics_process(delta: float) -> void:
	if active==true:
		GlobalPlayer.active_player_position=global_position
			
		#handle combat Ui auto hide
		if ui_visible:
			ui_timer+=delta
			if ui_timer>=ui_hide_delay:
				ui_visible=false
				var tween:=create_tween()
				tween.tween_property(progress_bar,"modulate:a",0.0,0.3)
				
		if Current_state==state.DEAD:
			return
			
			
		#knockback system
		if knockback_velocity.length()>1:
			velocity=knockback_velocity
			knockback_velocity=knockback_velocity.move_toward(Vector2.ZERO,delta*900)
			move_and_slide()
			update_animation()
			return
			
		if active and not busy:
			handle_movement()
			pass
		else:
			velocity=Vector2.ZERO
			if not busy:
				Current_state=state.IDLE

		move_and_slide()
		update_animation()
		
#-------------------------
#movement logic manual input(using arrow keys)
#-------------------------
func handle_movement():
	if action_lock or is_guarding:
		velocity=Vector2.ZERO
		Current_state=state.IDLE
		return
		
	var input_vector:=Vector2.ZERO
	
	if Input.is_key_pressed(KEY_RIGHT):
		input_vector.x+=1
	if Input.is_key_pressed(KEY_LEFT):
		input_vector.x-=1
	if Input.is_key_pressed(KEY_DOWN):
		input_vector.y+=1
	if Input.is_key_pressed(KEY_UP):
		input_vector.y-=1
		
	if input_vector==Vector2.ZERO:
		velocity=Vector2.ZERO
		Current_state=state.IDLE
		return
		
	#now all the pawn movement comes from this block
	last_input_dir=input_vector.normalized()
	velocity=last_input_dir*speed
	Current_state=state.RUN
	flip_sprites(last_input_dir)

#-------------------------
#flip the anim
#-------------------------
func flip_sprites(dir:Vector2)->void:
	if dir.x!=0:
		anim.flip_h=dir.x<0
		
#-------------------------
#hitbox and damage
#-------------------------
func _on_hitbox_area_entered(area: Area2D) -> void:
	if area.is_in_group("explo"):
		take_damage(10,area.global_position)
		hit_audio.play()
		
#-------------------------
#spawn attack effect
#-------------------------
func spawn_heal_effect()->void:
	var fx:=repair_effect_scene.instantiate()
	fx.global_position=marker_2d.global_position
	fx.scale=Vector2(1.0,1.0)
	get_parent().add_child(fx)
	fx.z_index=z_index-1

#-------------------------
#Damage feedback
#-------------------------
func take_damage(amount:int,from_pos:Vector2)->void:
	show_combat_ui()
	life-=amount
	if GlobalPlayer.camera_shake_func.is_valid():
		GlobalPlayer.camera_shake_func.call()
	progress_bar.value=life
	knockback_velocity=(global_position-from_pos).normalized()*knockback_force
	
	red_flash()
	
	if life<=0:
		die()
		
func red_flash():
	anim.modulate=Color.RED
	await get_tree().create_timer(0.12).timeout
	anim.modulate=Color.WHITE


#-------------------------
#DEATH
#-------------------------
signal died(pawn)

func die():
	if Current_state == state.DEAD:
		return
	emit_signal("died",self)
	
	Current_state=state.DEAD
	active=false
	busy=true
	
	if not death_audio.playing:
		death_audio.play()
		
	spawn_skull()
	await fade_out()
	queue_free()

func spawn_skull():
	var skull=skull_scene.instantiate()
	skull.global_position=global_position
	get_parent().add_child(skull)
	skull.scale=Vector2(0.5,0.5)
	
func fade_out():
	var tween:=create_tween()
	tween.tween_property(anim,"modulate:a",0.0,0.6)
	await tween.finished
	
#-------------------------
#animation handler
#-------------------------
func update_animation()->void:
	if  Current_state==state.USE:
			anim.play("heal")
	elif Current_state==state.IDLE:
		anim.play("idle")
	elif Current_state==state.RUN:
		anim.play("run")
	elif Current_state==state.DEAD:
		anim.play("dead")

#-------------------------
#activate/deactivate the pawn
#-------------------------
func activate_this_pawn():
	if GlobalPlayer.active_player and GlobalPlayer.active_player!=self:
		if GlobalPlayer.active_player.has_method("deactivate"):
			GlobalPlayer.active_player.deactivate()
	GlobalPlayer.active_player=self
	
	active=true
	GlobalPlayer.active_player_position=global_position
	set_process(true)
	update_selection_indicator()
	
func deactivate():
	active=false
	set_process(false) #---here(:)
	update_selection_indicator()
	select_indicator.visible=active
	
func update_selection_indicator():
	select_indicator.visible=active


#-------------------------
#dectector zone signals
#-------------------------
func _on_detector_zone_area_entered(area: Area2D) -> void:
	if area.is_in_group("heal"): #using for healing via monk
		show_combat_ui()
		life=max_life

#-------------------------
#button signal
#-------------------------
func _on_button_pressed() -> void:
	GlobalPlayer.set_active_pawn(self)
	click_audio.play()

func _on_use_timer_timeout() -> void:
	busy=false
	can_use_tool=true
	Current_state=state.IDLE
	update_animation()


#-------------------------
#healing detector
#-------------------------
func get_health_percentage()->float:
	return float(life)/float(max_life)
	
func get_health()->int:
	return life
	
func get_max_health()->int:
	return max_life
	
func show_combat_ui():
	ui_visible=true
	ui_timer=0.0
	progress_bar.visible=true
	progress_bar.modulate.a=1.0
	
func activate_from_global():
	active=true
	set_process(true)
	select_indicator.visible=true
	GlobalPlayer.active_player_position=global_position
