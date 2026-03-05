extends CharacterBody2D

enum tool {HAND,HAMMER,PICKAXE,AXE,KNIFE}
enum state{IDLE,RUN,USE,DEAD}

#-------------------------
#exported variables
#-------------------------
@export var speed:=300.0
@export var max_life:=100
@export var knockback_force:=320.0
@export var use_duration:=0.5
@export var tool_cooldown:=0.5 #time btw each pressed btn

@export var attack_effect_scene= PackedScene
@export var attack_repair_scene= PackedScene
@export var skull_scene= PackedScene

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
@onready var toolbox_panel: Control = $Control

#-------------------------
#references for sound fx
#-------------------------
@onready var hammer_audio: AudioStreamPlayer = $soundfx/hammer_audio
@onready var knife_audio: AudioStreamPlayer = $soundfx/knife_audio
@onready var pickaxe_audio: AudioStreamPlayer = $soundfx/pickaxe_audio
@onready var axe_audio: AudioStreamPlayer = $soundfx/axe_audio
@onready var equip_audio: AudioStreamPlayer = $soundfx/equip_audio
@onready var click_audio: AudioStreamPlayer = $soundfx/click_audio
@onready var death_audio: AudioStreamPlayer = $soundfx/death_audio
@onready var hit_audio: AudioStreamPlayer = $soundfx/hit_audio

#-------------------------
#state variable
#-------------------------
var Current_state:state=state.IDLE
var current_tool:tool=tool.HAND

var active:=false
var busy:=false
var action_lock:=false
var is_guarding:=false
var can_use_tool:=true

var life:int
var knockback_velocity:= Vector2.ZERO
var last_input_dir:= Vector2.DOWN

#inventory
var collected:={
	"wood":0,
	"stone":0,
	"meat":0,
}

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
	#global player
	progress_bar.visible=false
	
	toolbox_panel.z_index=7
	z_index=4
	scale=Vector2(0.7,0.7)
	life=max_life
	progress_bar.max_value=max_life
	progress_bar.value=life
	
	toolbox_panel.hide()
	use_timer.wait_time=use_duration
	use_timer.one_shot=true
	
	use_timer.timeout.connect(_on_use_timer_timeout)
	
	#connet detector zone signals
	if detector_zone!=null:
		detector_zone.area_entered.connect(_on_resource_entered)

func _on_use_timer_timeout() -> void:
	pass # Replace with function body.

#-------------------------
#pickup function
#-------------------------
func pickup_resource(resource_node)->void:
	var resource_type=resource_node.resource_type
	if resource_type in collected:
		collected[resource_type]+=1
		#calling the func
		if resource_node.has_methode("collect"):
			resource_node.collect()
		else:
			resource_node.queue_free()
			
#-------------------------
#auto pick up func
#-------------------------
func _on_resource_entered(area:Area2D)->void:
	#check if it is a resource
	if area.has_method("collect") and area.has_property("resource_type"):
		if not area.collected:
			var resource_type=area.resource_type
			#check
			if (resource_type=="wood" and current_tool==tool.AXE) or \
			(resource_type=="stone" and current_tool==tool.PICKAXE) or \
			(resource_type=="meat" and current_tool==tool.AXE):
				pickup_resource(area)
			
			
#-------------------------
#Input ui
#-------------------------
func _input(event: InputEvent) -> void:
	if not active or current_tool==state.DEAD:
		return
	
	#toggle toobox with input key "T"
	if event.is_action_pressed("tools"):
		toolbox_panel.visible=!toolbox_panel.visible
		get_viewport().set_input_as_handled()
		
#tool usage
	if event.is_action_pressed("use"):
		#use_current_tool()
		hide_toolbox_if_visible()
		pass

#-------------------------
#hide toolbox in case of any input
#-------------------------
func hide_toolbox_if_visible():
	if toolbox_panel.visible:
		toolbox_panel.hide()
		
#-------------------------
#physics process
#-------------------------
func _physics_process(delta: float) -> void:
	if active==true:
		pass
		#GlobalPlayer.active_player_position=global_position
	if active and not busy:
		if Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_LEFT) or \
		Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_UP):
			hide_toolbox_if_visible()
			
			
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
			#update_animation()
			return
			
		if active and not busy:
			handle_movement()
			pass
		else:
			velocity=Vector2.ZERO
			if not busy:
				Current_state=state.IDLE

		move_and_slide()
		#update_animation()
		
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
	#flip_sprite(last_input_dir)
	
#-------------------------
# USE CURRENT TOOL BY PRESSING USE "SPACE"
#-------------------------
func use_current_tool():
	if busy or Current_state==state.DEAD or not active or not can_use_tool:
		return
	
	#start tool action based on the var current tool
	match current_tool:
		tool.HAMMER:
			repeat_tool_action(tool.HAMMER,"","HAMMER",3)
		tool.PICKAXE:
			repeat_tool_action(tool.PICKAXE,"stone","pickaxe",4)
		tool.AXE:
			repeat_tool_action(tool.AXE,"wood","axe",4)
		tool.KNIFE:
			repeat_tool_action(tool.KNIFE,"meat","knife",2)
		tool.HAND:
			repeat_tool_action(tool.HAND,"","hand",1)
			

#-------------------------
#func to use tool
#-------------------------
func repeat_tool_action(tool:tool,collect_type:String,tool_name:String,times:int)->void:
	busy=true
	can_use_tool=false
	Current_state=state.USE
	current_tool=Tool
	
	for i in range(times):
		spawn_tool_effect()
		if collect_type!="" and detector_zone!=null:
			collect_nearby_resources(collect_type)
			
	update_animation()
	
	await get_tree().create_timer(tool_cooldown).timeout
	
	#reset after using x times
	can_use_tool=true
	busy=false
	Current_state=state.IDLE
	update_animation()
	
func spawn_tool_effect()->void:
	if current_tool==tool.HAMMER:
		pass
		#spawn_repair_effect()
	else:
		pass
		#spawn_attack_effect()


#-------------------------
#func to pick nearby resources
#-------------------------
func collect_nearby_resources(resource_type:String)->void:
	if detector_zone==null:
		return
		
	var overlapping_area=detector_zone.get_overlapping_areas()
	for area in overlapping_area:
		if area.has_method("collect") and area.has_property("resource_type"):
			pickup_resource(area)
			return
			

#-------------------------
#pickup func
#-------------------------
func pick_nearby_items()->void:
	if detector_zone==null:
		return
		
		var overlapping_area=detector_zone.get_overlapping_areas()
		for area in overlapping_area:
			if area.has_method("collect") and area.has_property("resource_type"):
				if not area.collected:
					var resource_type=area.resource_type
				return
