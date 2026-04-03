extends StaticBody2D
#-----------------------------
#States
#-----------------------------
enum TreeState{
	IDLE,
	CHOPPING,
	CHOPPED,
	GROWING
}
var state:TreeState=TreeState.IDLE
@export var life=3
#-----------------------------
#Nodes
#-----------------------------
@onready var anim: AnimatedSprite2D = $anim
@onready var chopped: CollisionShape2D = $chopped
@onready var body: CollisionShape2D = $shape
@onready var tree_trunk: Area2D = $tree_trunk
@onready var cut_audio: AudioStreamPlayer = $Sound_fx/cut_audio
#-----------------------------
#constants
#-----------------------------
const CHOP_TIME:=1.0
const REGROW_TIME:=10.0
const GROW_TIME:=1.5
const WOOD_SCENE:=preload("res://Units/material/wood/wood.tscn")
#-----------------------------
#ready
#-----------------------------
func _ready() -> void:
	scale=Vector2(1.5,1.5)
	#z_index=5
	z_index = int(global_position.y)
	add_to_group("trees")
	randomize()
	set_state(TreeState.IDLE)
	#tree_trunk.area_entered.connect(_on_tree_trunk_area_entered)

func _process(delta: float) -> void:
	z_index = int(global_position.y)
#-----------------------------
#Pawn interaction
#-----------------------------
func _on_tree_trunk_area_entered(area: Area2D) -> void:
	if area.is_in_group("attackeffect") and Global.pawn_tool == "axe":
		hit()

func hit() -> void:
	if state != TreeState.IDLE:
		return
	life -= 1
	red_flash()
	if not cut_audio.playing:
		cut_audio.play()
	try_chop()

func set_state(new_state:TreeState)->void:
	state=new_state
	match state:
		TreeState.IDLE:
			anim.play("idle")
			scale=Vector2(1.5,1.5)
			modulate.a=1.0
			body.disabled=false
			chopped.disabled=true
		TreeState.CHOPPING:
			anim.play("chop")
			body.disabled=false
			chopped.disabled=true
		TreeState.CHOPPED:
			anim.play("chopped")
			body.disabled=true
			chopped.disabled=false
		TreeState.GROWING:
			anim.play("idle")
			body.disabled=true
			chopped.disabled=true
func try_chop()->void:
	if state!=TreeState.IDLE:
		return
	if life<=0:
		set_state(TreeState.CHOPPING)
		await get_tree().create_timer(CHOP_TIME).timeout
		set_state(TreeState.CHOPPED)
		spawn_wood()
		start_regrow_timer()
#-----------------------------
#Spawn wood
#-----------------------------
func spawn_wood()->void:
	var wood_count:=randi_range(4,8)
	for i in range(wood_count):
		var wood=WOOD_SCENE.instantiate()
		get_parent().add_child(wood)
		var x_offset:=randf_range(-35,35)
		var y_offset:=randf_range(35,-35)
		wood.global_position=global_position+Vector2(x_offset,y_offset)
		wood.rotation = randf_range(-PI,PI)
func start_regrow_timer()->void:
	await get_tree().create_timer(REGROW_TIME).timeout
	start_growing()
func start_growing()->void:
	set_state(TreeState.GROWING)
	scale=Vector2(0.2,0.2)
	modulate.a=0.0
	var tween:=create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(self,"scale",Vector2(1.5,1.5),GROW_TIME)
	tween.parallel().tween_property(self,"modulate:a",1.0,GROW_TIME)
	await tween.finished
	life = 3
	set_state(TreeState.IDLE)
func red_flash()->void:
	anim.modulate=Color.RED
	await get_tree().create_timer(0.12).timeout
	anim.modulate=Color.WHITE
