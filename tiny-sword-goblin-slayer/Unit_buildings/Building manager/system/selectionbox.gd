extends Node2D

var dragging:=false
var drag_start:=Vector2.ZERO
var drag_end:=Vector2.ZERO
var selection_rect:=Rect2()

@onready var camera: Camera2D = $Camera2D

#use to call a camera shake function from anywhere in the units scripts
func _ready() -> void:
	GlobalPlayer.camera_shake_func=camera_shake
	z_index=10
	
func _physics_process(_delta: float) -> void:
	camera.make_current()
	if GlobalPlayer.active_player:
		camera.global_position=GlobalPlayer.active_player_position
	else:
		if GlobalPlayer.castle_position:
			camera.global_position=GlobalPlayer.castle_position

#--------------------------------
#Inputs
#--------------------------------
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_RIGHT:
		if event.pressed:
			start_drag()
		else:
			end_drag()
	if event is InputEventMouseMotion and dragging:
		drag_end=get_global_mouse_position()
		update_selection_rect()
		queue_redraw()
#--------------------------------
#Drag
#--------------------------------
func start_drag():
	dragging=true
	drag_start=get_global_mouse_position()
	drag_end=drag_start
func end_drag():
	dragging=false
	update_selection_rect()
	select_units()
	queue_redraw()


#--------------------------------
#rect update
#--------------------------------
func _draw():
	if not dragging:
		return
	var color=Color.WHITE
	draw_rect(selection_rect,color,false,2)
	draw_rect(selection_rect,Color(color.r,color.g,color.b,0.15),true)

#--------------------------------
#get color from the menu player
#--------------------------------
#func get_selection_color()->Color:
#	match Global.choosed_colour:
#		"black":
#			return Color.BLACK
#		"blue":
#			return Color.DEEP_SKY_BLUE
#		"red":
#			return Color.RED
#		"yellow":
#			return Color.YELLOW
#		"purple":
#			return Color.PURPLE
#		_:
#			return Color.WHITE

#--------------------------------
#Unit selection box
#--------------------------------
func select_units():
	for unit in get_tree().get_nodes_in_group("selectable"):
		unit.set_selected(false)
	for unit in get_tree().get_nodes_in_group("selectable"):
		if selection_rect.has_point(unit.global_position):
			unit.set_selected(true)

func camera_shake()->void:
	for i in range(6):
		camera.offset=Vector2(randf_range(-6.6, 6.6), randf_range(-6.6, 6.6))
		await get_tree().create_timer(0.02).timeout
	camera.offset=Vector2.ZERO

func update_selection_rect():
	selection_rect=Rect2(drag_start, drag_end-drag_start).abs()
