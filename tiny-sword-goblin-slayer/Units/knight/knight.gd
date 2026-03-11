extends CharacterBody2D

#-----------------------
#Nodes
#-----------------------
@onready var anim: AnimatedSprite2D = $anim
@onready var shape: CollisionShape2D = $shape
@onready var detector_zone: Area2D = $"detector zone"
@onready var hitbox: Area2D = $hitbox
@onready var shieldbar: ProgressBar = $shieldbar
@onready var progress_bar: ProgressBar = $ProgressBar
@onready var button: Button = $Button
@onready var select_indicator: Label = $"select indicator"
@onready var marker_2d: Marker2D = $Marker2D
@onready var camera_2d: Camera2D = $Camera2D
@onready var navigation_agent_2d: NavigationAgent2D = $NavigationAgent2D
@onready var predict_cast: ShapeCast2D = $PredictCast

#-----------------------
#Soundfx
#-----------------------
@onready var click_audio: AudioStreamPlayer2D = $soundfx/click_audio
@onready var death_audio: AudioStreamPlayer2D = $soundfx/death_audio
@onready var hit_audio: AudioStreamPlayer2D = $soundfx/hit_audio
@onready var sword_audio: AudioStreamPlayer2D = $soundfx/sword_audio
@onready var shield_audio: AudioStreamPlayer2D = $soundfx/shield_audio

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

@export var speed:=700.0
@export var attack_damage:=10
@export var attack_cooldown:=1.0

#-----------------------
#Control
#-----------------------
var selected:=false
var stop_distance:=5

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
	hitbox.area_zone.body_entered.connect(_on_hitbox_area_entered)
	
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
	if not selected pr state==State.DEAD:
		return
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.prsssed:
		issue_move(get_global_mouse_position())

func issue_move(pos:Vector2):
	reset_combat()
	target=null
	movement_priority=true
	manual_mode=true
	resume_navigation()
	
	#destination
	var offset:Vector2(
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
		update_facing((target.global_position-global_position).narmalized())
	if state==State.RUN:
		check.stuck(delta)
	
	#update random shield
	if random_shield_enabled and not guard_locked and state!=State.GUARD and state !=State.DEAD:
		random
