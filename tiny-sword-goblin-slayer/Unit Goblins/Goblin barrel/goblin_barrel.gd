extends CharacterBody2D

#============================================
#Pack system(global/shared)
#============================================

static var reserved_targets:Dictionary={}
static var goblins:Array[CharacterBody2D]

const MAX_GOBLINS_PER_TARGET:int=4
const STEAL_DISTANCE:float=80.0
const SEPARATION_RADIUS:float=120.0
const SEPARATION_FORCE:float=140.0

#============================================
#NOdes
#============================================
@onready var anim: AnimatedSprite2D = $anim
@onready var collision_shape_2d: CollisionShape2D = $CollisionShape2D
@onready var hurtbox: Area2D = $hurtbox
@onready var detect_area: Area2D = $detector_area
@onready var nav: NavigationAgent2D = $NavigationAgent2D
@onready var hurt_timer: Timer = $hurt
@onready var flash_timer: Timer = $flash
@onready var target_area: Area2D = $target_area
@onready var predictcast: ShapeCast2D = $PredictCast
#fx sound
@onready var throw_audio: AudioStreamPlayer = $"sound fx/throw_audio"
@onready var hit_attack_audio: AudioStreamPlayer = $"sound fx/hit_attack_audio"

#============
#CONSTANTS
#============

const ATTACK_DISTANCE:float=40.0
const KNOCKBACK_FORCE:float=1000.0
const KNOCKBACK_DECAY:float=0.85
const DETOUR_DISTANCE:float=60.0

#====================================
# STATE MACHINE
#====================================

enum State{IDLE,CHASE,ATTACK,HIT,DEAD} # S state with capital 'S'
var state:State=State.IDLE  # small state

#====================
# variables
#====================

@export var SPEED:float=200.0
@export var health:int=3
var knockback_velocity:Vector2=Vector2.ZERO
var is_flashing:bool=false

var targets:Array[Node2D]=[]
var current_target:Node2D=null
var exploded:bool=false # checker

#====================
# STUCK AND AVOIDANCE
#====================

var stuck_timer:float=0.0
var stuck_threshold:float=0.3
var last_position:Vector2=Vector2.ZERO

#============
#Ready
#============

func _ready() -> void:
	z_index=4
	goblins.append(self)

	nav.path_desired_distance=6.0
	nav.target_desired_distance=6.0

	# add all target initially
	for p in get_tree().get_nodes_in_group("player"):
		add_target(p)

func _exit_tree() -> void:
	goblins.erase(self)
	release_target()
	rebalance_pack()

#====================================
# TARGET / PACK LOGIC
#====================================

func add_target(t:Node2D)->void:
	if not is_instance_valid(t):
		return
	if not targets.has(t):
		targets.append(t)
		choose_best_target()

func remove_target(t:Node2D)->void:
	targets.erase(t)
	if current_target==t:
		release_target()
		choose_best_target()

func choose_best_target()->void:
	var best_target:Node2D=null
	var best_dist:float=INF

	# step : try the player target "human unit as target"
	for t in targets:
		if not is_instance_valid(t):
			continue
		var attackers:Array=reserved_targets.get(t,[])
		var d:float=global_position.distance_to(t.global_position)

		if attackers.size()<MAX_GOBLINS_PER_TARGET:
			if d<best_dist:
				best_dist=d
				best_target=t
		else:
			for g in attackers:
				if not is_instance_valid(g):
					continue
				if d+STEAL_DISTANCE<g.global_position.distance_to(t.global_position):
					best_dist=d
					best_target=t
					break

	# step 2 : attack the castle if the players are all killed
	if best_target==null or targets.is_empty():
		var castle:Array=get_tree().get_nodes_in_group("castle")
		if castle.size()>0:
			best_target=castle[-1]
			if not targets.has(best_target):
				targets.append(best_target)
	#step 3 : for barrel if no targets explode
	if best_target==null:
		explode()
		return
	assign_target(best_target)

func assign_target(t:Node2D)->void:
	if current_target==t:
		return
	release_target()

	if t !=null:
		if not reserved_targets.has(t):
			reserved_targets[t]=[]
		var arr:Array=reserved_targets[t] as Array
		arr.append(self)
		reserved_targets[t]=arr

		current_target=t
		state=State.CHASE
	else:
		state=State.IDLE

func release_target()->void:
	if current_target==null:
		return
	if reserved_targets.has(current_target):
		var arr:Array=reserved_targets[current_target] as Array
		arr.erase(self)
		if arr.is_empty():
			reserved_targets.erase(current_target)
		else:
			reserved_targets[current_target]=arr

func rebalance_pack()->void:
	for g in goblins:
		if g==self:
			continue
		if is_instance_valid(g) and g.state!=State.DEAD:
			g.choose_best_target()

func validate_target()->bool:
	if current_target==null:
		state=State.IDLE
		return false
	if not is_instance_valid(current_target):
		release_target()
		state=State.IDLE
		return false
	return true

#==============================
# MAIN LOOP
#==============================

func _physics_process(delta: float) -> void:
	if state==State.DEAD:
		return

	# knock back decay
	if knockback_velocity.length()>1:
		velocity=knockback_velocity
		knockback_velocity*=KNOCKBACK_DECAY

	validate_target()

	match state:
		State.IDLE:
			if targets.is_empty():
				anim.play("idle")
				await get_tree().create_timer(0.2).timeout
				explode()
				return

		State.CHASE:
			chase_state()

		State.ATTACK:
			attack_state()

		State.HIT:
			chase_state()

	# combine separation and movement with knockback system
	if state in [State.IDLE,State.CHASE]:
		velocity+=separation_vector()*SEPARATION_FORCE
	avoid_obstacles()
	if state == State.ATTACK:
		velocity = Vector2.ZERO
	move_and_slide()

#==============================
# stuck detection
#==============================

	if state in [State.CHASE,State.IDLE]:
		detect_stuck(delta)
	move_and_slide()

#==============================
# STATES
#==============================

func idle_state()->void:
	anim.play("idle")

func chase_state()->void:
	if not validate_target():
		return

	nav.target_position = current_target.global_position
	
	var next_point:Vector2 = nav.get_next_path_position()
	var dir:Vector2 = (next_point - global_position).normalized()

	velocity = dir * SPEED
	anim.flip_h = dir.x < 0
	anim.play("run")

	var dist:float = global_position.distance_to(current_target.global_position)

	if dist < 40.0:
		state = State.ATTACK
		return

	if velocity.length() < 5.0 and dist < 80.0:
		state = State.ATTACK
		return

var is_attacking:=false
func attack_state()->void:
	if state==State.DEAD or is_attacking:
		return
	is_attacking=true
	velocity=Vector2.ZERO
	anim.play("explode")
	await get_tree().create_timer(0.2).timeout
	explode()
func _on_attack_finished()->void:
	anim.play("explode" if anim.sprite_frames.has_animation("explode") else "hide")
	hurt_timer.start()

	if health<=0:
		explode()
	else:
		state=State.CHASE if current_target else State.IDLE

#====================================
# SEPARATION  "set dist btw the barrels"
#====================================

func separation_vector()->Vector2:
	var force:Vector2=Vector2.ZERO
	for g in goblins:
		if g==self or not is_instance_valid(g):
			continue
		var dist:float=global_position.distance_to(g.global_position)
		if dist>0 and dist< SEPARATION_RADIUS:
			force+=(global_position-g.global_position).normalized()*(1.0-dist/SEPARATION_RADIUS)
	return force.normalized() if force.length()>0 else Vector2.ZERO

#====================================
# DAMAGE SYSTEM
#====================================

func take_damage(damage:int,source_pos:Vector2)->void:
	if state==State.DEAD:
		return
	health-=damage
	if not hit_attack_audio.playing:
		hit_attack_audio.play()
	knockback_velocity=(global_position-source_pos).normalized()*KNOCKBACK_FORCE
	state=State.HIT
	start_flashing()
	hurt_timer.start(0.3)

func start_flashing()->void:
	if is_flashing:
		return
	is_flashing=true
	flash_timer.start(0.1)

	var t=create_tween()
	t.tween_property(anim,"modulate",Color.RED,0.05)
	t.tween_property(anim,"modulate",Color.WHITE,0.05)
	t.set_loops(4)

#====================
# Hurt box
#====================
func _on_hurtbox_area_entered(area: Area2D) -> void:
	print("HIT:", area.name)
	if not area.is_in_group("arrow"):
		return
	take_damage(1, area.global_position)
	area.queue_free()

#===============
# Timers
#===============
func _on_hurt_timeout() -> void:
	knockback_velocity = Vector2.ZERO

	if state != State.DEAD:
		if is_instance_valid(current_target):
			state = State.CHASE
		else:
			state = State.IDLE

func _on_flash_timeout() -> void:
	is_flashing=false
	anim.modulate=Color.WHITE

#===============
# signals for detectors
#===============
func _on_detect_area_body_entered(body: Node2D) -> void:
	if exploded:
		return
	if body.is_in_group("player"):
		add_target(body)

func _on_detect_area_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		remove_target(body)

#===============
# target area signals
#===============
func _on_target_area_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	if current_target==null:
		add_target(body)
		return
	var current_dist:float=global_position.distance_to(current_target.global_position)
	var new_dist:float=global_position.distance_to(body.global_position)

	if new_dist+STEAL_DISTANCE<current_dist:
		add_target(body)
func _on_target_area_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		remove_target(body)

#================================
# Obstacles avoidance system
#================================

func avoid_obstacles():
	if not predictcast.is_enabled():
		predictcast.enabled=true

	if velocity.length()>0:
		predictcast.global_rotation=velocity.angle()
		predictcast.force_update_transform()

		if predictcast.is_colliding():
			var n :Vector2=predictcast.get_collision_normal(0)
			var slide_dir:Vector2=velocity-n*velocity.dot(n)

			if slide_dir.length()<0.1:
				slide_dir=Vector2(-n.y,n.x)*DETOUR_DISTANCE
			velocity=slide_dir.normalized()*SPEED


#================================
# DEATH/EXPLOSION
#================================

func explode():
	if state==State.DEAD or exploded:
		return
	is_attacking = false
	exploded=true
	state=State.DEAD
	if is_instance_valid(current_target):
		if current_target.has_method("take_damage"):
			current_target.take_damage(1, global_position)
	release_target()
	rebalance_pack()

	var e=preload("res://Units/effect fx/explo/explosion.tscn").instantiate()
	get_parent().add_child(e)
	e.global_position=global_position
	e.scale=Vector2(1.5,1.5)
	e.z_index=6

	queue_free()


func detect_stuck(delta:float)->void:
	if last_position.distance_to(global_position)<1.0:
		stuck_timer+=delta
	else:
		stuck_timer=0.0

	last_position=global_position

	if stuck_timer>stuck_threshold:
		unstuck()

func unstuck():
	velocity=Vector2(-velocity.y,velocity.x).normalized()*SPEED
	stuck_timer=0.0

var _attackers:Array=[]

func can_accept_attacker()->bool:
	return _attackers.size()<2

func add_attacker(knight):
	if knight not in _attackers:
		_attackers.append(knight)

func remove_attacker(knight):
	_attackers.erase(knight)
