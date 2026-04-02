extends Panel
@onready var selector: Sprite2D = $Selector
#buttons
@onready var buttons=[
	$Build_House1_btn, $Build_House2_btn, $Build_House3_btn, $Build_Tower_btn, $Build_barrack_btn, $Build_monastery_btn, $Build_archery_btn
]
#marker nodes
@onready var markers=[
	$Build_House1_btn/Marker2D, $Build_House2_btn/Marker2D, $Build_House3_btn/Marker2D, $Build_Tower_btn/Marker2D, $Build_barrack_btn/Marker2D, $Build_monastery_btn/Marker2D, $Build_archery_btn/Marker2D
]
#icons
@onready var icons=[
	$Build_House1_btn/anim, $Build_House2_btn/anim, $Build_House3_btn/anim, $Build_Tower_btn/anim, $Build_barrack_btn/anim, $Build_monastery_btn/anim, $Build_archery_btn/anim
]
var cost=[
	{"gold":20,"wood":30},
	{"gold":25,"wood":35},
	{"gold":30,"wood":40},
	{"gold":40,"wood":60},
	{"gold":35,"wood":50},
	{"gold":45,"wood":70},
	{"gold":50,"wood":80}
]
signal build_requested(building_name:String)
func _ready() -> void:
	for i in range(buttons.size()):
		buttons[i].pressed.connect(_on_any_button_pressed.bind(i))
func _on_any_button_pressed(index:int) -> void:
	var icon = icons[index]
	var building_cost = cost[index]
	selector.global_position = markers[index].global_position
	_scale_bump(icon)
	if Global.gold >= building_cost["gold"] and Global.wood >= building_cost["wood"]:
		var building = buttons[index].name.to_lower().replace("build_", "").replace("_btn", "")
		if building == "archery":
			building = "archery_tower"
		Global.pawn_tool = building
		emit_signal("build_requested", building)
		_flash_green(icon)
	else:
		_flash_red(icon)
func _scale_bump(node)->void:
	var tween=create_tween()
	var original_scale = node.scale
	var original_modulate = node.modulate
	tween.tween_property(node, "scale", original_scale * 1.55, 0.08)
	tween.tween_property(node, "scale", original_scale, 0.12)
	tween.tween_property(node, "modulate", original_modulate, 0.12)
func _flash_green(node)->void:
	var tween=create_tween()
	var original=node.modulate
	tween.tween_property(node, "modulate", Color.GREEN, 0.15)
	tween.tween_property(node, "modulate",original,0.15)
	await tween.finished
func _flash_red(node)->void:
	var tween=create_tween()
	var original=node.modulate
	tween.tween_property(node, "modulate", Color.RED, 0.15)
	tween.tween_property(node, "modulate",original,0.15)
	await tween.finished
