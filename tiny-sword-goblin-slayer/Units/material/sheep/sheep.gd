extends CharacterBody2D

#---------------------------
#Nodes
#---------------------------
@onready var anim: AnimatedSprite2D = $anim
@onready var shape: CollisionShape2D = $shape
@onready var zone: Area2D = $zone
@onready var danger_zone: Area2D = $"Danger zone"
@onready var marker_2d: Marker2D = $Marker2D
@onready var navigation_agent_2d: NavigationAgent2D = $NavigationAgent2D

#sound
@onready var sheep_audio: AudioStreamPlayer = $Node2D/sheep_audio
@onready var hit_audio: AudioStreamPlayer = $Node2D/hit_audio

#---------------------------
#scene
#---------------------------
@export var meat_scene=preload("res://Units/material/wood/wood.tscn")#temporary
var baby_sheep_scene=null

#---------------------------
#Genes
#---------------------------
@export_range(0.6,1.5) var body_size:=1.0
@export_range(0.6,1.5) var agility:=1.0
@export_range(0.6,1.5) var courage:=1.0
@export_range(0.6,1.5) var fertility:=1.0
@export_range(0.6,1.5) var growth_rate:=1.0

#---------------------------
#stats
#---------------------------
const BASE_LIFE:=1
const BASE_WALK:=80.0
const BASE_FLEE:=120.0
const BASE_MEAT:=1

#---------------------------
#FINAL STATS
#---------------------------
var life:int
var walk_speed:float
var flee_speed:float
var meat_amount:int

#---------------------------
#Ai states
#---------------------------
enum {GRAZE,WANDER,FLEE,DEAD}
var state=GRAZE

var target_position:Vector2
var panic_time:=0.0
var flee_dir:=Vector2.ZERO

#---------------------------
#Graze and wander/ Timers
#---------------------------
var graze_time:=0.0
var wander_time:=0.0

#---------------------------
#Growth
#---------------------------
var is_bady:=false
var age:=0.0
@export var adult_age:=18.0

#---------------------------
#pack system
#---------------------------
var pack_id:=1
var is_leader:=false
var pack_center:=Vector2.ZERO
var pack_members:Array=[]

@export var pack_radius:=120.0
@export var pack_pull_strength:=0.5

#---------------------------
#ready func
#---------------------------
func _ready() -> void:
	z_index=4
	add_to_group("sheep")
	_apply_genes()
	_assign_pack()
	
	if is_bady:
		scale*=0.5
		life=1
	target_position=global_position
	_enter_graze()

#---------------------------
#pack assignment
#---------------------------
func _assign_pack():
	var nearby:=[]
	for sheep in get_tree().get_nodes_in_group("sheep"):
		if sheep!=self and sheep.global_position.distance_to(global_position)<pack_radius:
			nearby.append(sheep)
		if nearby.is_empty():
			pack_id=get_instance_id()
			is_leader=true
			pack_members=[self]
		else:
			var leader=nearby[0]
			pack_id=leader.pack_id
			leader.pack_members.append(self)
#---------------------------
#apply genes
#---------------------------
func _apply_genes():
	life=int(BASE_LIFE*body_size)
	walk_speed=BASE_WALK*agility/body_size
	flee_speed=BASE_FLEE*agility
	meat_amount=max(1,int(BASE_MEAT*body_size*2))
	scale*=body_size

#---------------------------
#physics process
#---------------------------
func _physics_process(delta: float) -> void:
	if state==DEAD:
		return
	if is_bady:
		_grow(delta)
	_update_pack_center()
	
	match state:
		GRAZE:
			graze_time-=delta
			velocity=Vector2.ZERO
			if graze_time<=0:
				_enter_wander()
		WANDER:
			wander_time-=delta
			var dir = target_position-global_position
			if dir.length()<6 or wander_time<=0:
				_enter_graze()
			else:
				dir=dir.normalized()
				dir+=_pack_pull()
				velocity=dir.normalized()*walk_speed
		FLEE:
			panic_time-=delta
			if panic_time<=0:
				_enter_graze()
			else:
				velocity=flee_dir*flee_speed
	move_and_slide()
	_update_flip_direction()

#---------------------------
#pack logic
#---------------------------
func _update_pack_center():
	if not is_leader:
		return
	var sum:=Vector2.ZERO
	for s in pack_members:
		sum+=s.global_position
	pack_center=sum/pack_members.size()

func _pack_pull()->Vector2:
	if pack_center==Vector2.ZERO:
		return Vector2.ZERO
	var d = global_position.distance_to(pack_center)
	if d>pack_radius*0.5:
		return(pack_center-global_position).normalized()*pack_pull_strength
	return Vector2.ZERO

#---------------------------
#Growth
#---------------------------
func _grow(delta):
	age+=delta*growth_rate
	var t = clamp(age/adult_age,0.0, 0.1)
	scale=Vector2.ONE*lerp(0.5,body_size,t)
	if age>=adult_age:
		is_bady=false

#---------------------------
#reproduction
#---------------------------
func try_spawn_baby():
	if is_bady or baby_sheep_scene==null:
		return
	if randf()>0.15*fertility:
		return
	var baby=baby_sheep_scene.instantiate()
	baby.global_position=global_position+Vector2(randf_range(-10,10),randf_range(-10,10))
	
	baby.body_size=clamp(body_size*randf_range(-0.1,0.1),0.7,1.5)
	baby.agility=clamp(agility*randf_range(-0.1,0.1),0.5,1.5)
	baby.courage=clamp(courage*randf_range(-0.1,0.1),0.6,1.5)
	baby.fertility=clamp(fertility*randf_range(-0.1,0.1),0.6,1.5)
	baby.growth_rate=clamp(growth_rate*randf_range(-0.1,0.1),0.7,1.5)
	
	baby.is_bady=true
	get_parent().add_child(baby)

#---------------------------
#DAMAGE and PANIC
#---------------------------
func _on_zone_area_entered(area: Area2D) -> void:
	print("zone hit by ", area.get_groups())
	if state==DEAD:
		return
	
	if area.is_in_group("explo") or area.is_in_group("arrow"):
		take_damage(area.global_position)
	if area.is_in_group("attackeffect") or area.is_in_group("knife"):
		take_damage(area.global_position)

func take_damage(attack_pos:Vector2):
	life-=1
	if not hit_audio.playing:
		hit_audio.play()
	_flash_red()
	if life<=0:
		die()
	else:
		_panic(attack_pos)

func _panic(threat_pos: Vector2):
	state = FLEE
	flee_dir = (global_position - threat_pos).normalized()
	panic_time = randf_range(3.0, 6.0)
	anim.play("move")

#---------------------------
#Death
#---------------------------
func die():
	state=DEAD
	anim.play("idle")
	await get_tree().create_timer(0.2).timeout
	for i in meat_amount:
		spawn_meat()
	queue_free()

#---------------------------
#spawn meat
#---------------------------
func spawn_meat():
	var meat=meat_scene.instantiate()
	meat.global_position=global_position+Vector2(randf_range(-3,3),randf_range(-3,3))
	get_parent().add_child(meat)

func _update_flip_direction():
	if velocity.x<-0.2:
		anim.flip_h=true
	elif velocity.x>0.2:
		anim.flip_h=false

#---------------------------
#visual
#---------------------------
func _flash_red():
	modulate=Color.RED
	await get_tree().create_timer(0.10).timeout
	modulate=Color.WHITE

#---------------------------
#AI State entering
#---------------------------
func _enter_graze():
	state=GRAZE
	anim.play("grass")
	if not sheep_audio.playing:
		sheep_audio.play()
	graze_time=randf_range(1.5,3.5)

func _enter_wander():
	state=WANDER
	anim.play("move")
	
	var radius:=randf_range(50,100)
	var angle:=randf()*TAU
	target_position=global_position+Vector2(cos(angle),sin(angle))*radius
	wander_time=randf_range(1.5,3.5)
