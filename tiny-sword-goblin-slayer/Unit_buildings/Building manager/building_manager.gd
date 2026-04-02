extends Node2D

@onready var ghost_parents: Node2D = get_or_create_ghost_parent()
@export var ground_tilemap_group := "ground_tilemap"
@export var building_parent: Node2D
var moving_building: StaticBody2D = null
var moving_original_position: Vector2

@export var ghost_scene := {
	"house1": preload("res://Unit_buildings/Building manager/Ghosts/house1_ghost.tscn"),
	"house2": preload("res://Unit_buildings/Building manager/Ghosts/house2_ghost.tscn"),
	"house3": preload("res://Unit_buildings/Building manager/Ghosts/house3_ghost.tscn"),
	"archery_tower": preload("res://Unit_buildings/Building manager/Ghosts/archery_ghost.tscn"),
	"barracks": preload("res://Unit_buildings/Building manager/Ghosts/barrack_ghost.tscn"),
	"tower": preload("res://Unit_buildings/Building manager/Ghosts/tower_ghost.tscn"),
	"monastery": preload("res://Unit_buildings/Building manager/Ghosts/monastery_ghost.tscn")
}

#building scene
@export var building_scenes := {
	"house1": preload("res://Unit_buildings/house1/house1.tscn"),
	"house2": preload("res://Unit_buildings/house2/house2.tscn"),
	"house3": preload("res://Unit_buildings/house3/house3.tscn"),
	"archery_tower": preload("res://Unit_buildings/archery/archery.tscn"),
	"barracks": preload("res://Unit_buildings/barrack/barrack.tscn"),
	"tower": preload("res://Unit_buildings/Tower/tower.tscn"),
	"monastery": preload("res://Unit_buildings/monastery/monastery.tscn")
}

var ghost: Node2D = null
var current_id := ""
var can_place := false

#cost mapping
var cost_map := {
	"house1": {"wood": 1, "gold": 1},
	"house2": {"wood": 3, "gold": 3},
	"house3": {"wood": 2, "gold": 2},
	"archery_tower": {"wood": 10, "gold": 6},
	"barracks": {"wood": 10, "gold": 5},
	"tower": {"wood": 6, "gold": 3},
	"monastery": {"wood": 10, "gold": 5}
}

#--------------------------------
#Process
#--------------------------------
func _process(delta: float) -> void:
	if ghost == null:
		return

	var ground := get_ground_under_mouse()
	if ground == null:
		can_place = false
		return

	var mouse_pos := get_global_mouse_position()
	var tile_pos := ground.local_to_map(ground.to_local(mouse_pos))
	var world_pos := ground.to_global(ground.map_to_local(tile_pos)) + Vector2(ground.tile_set.tile_size) / 2.0

	ghost.visible = true
	ghost.global_position = world_pos

	if _mouse_over_ui():
		can_place = false
		return

	_validate_placement()

#--------------------------------
#build selection
#--------------------------------
func select_building(id: String) -> void:
	if ghost:
		ghost.queue_free()
		ghost = null

	if not ghost_scene.has(id):
		push_error("Invalid building id: %s" % id)
		return

	current_id = id
	ghost = ghost_scene[id].instantiate()
	ghost.visible = true
	ghost_parents.add_child(ghost)

	if not _has_enoungh_resourches(id):
		_feedback_insufficient_ghosts()

#--------------------------------
#placement validation
#--------------------------------
func _validate_placement() -> void:
	can_place = true

	if ghost == null:
		can_place = false
		return

	if not _has_enoungh_resourches(current_id):
		can_place = false

	var shape_node: CollisionShape2D = ghost.get_node_or_null("CollisionShape2D")
	if shape_node == null or shape_node.shape == null:
		can_place = false
		return

	var space_state = get_world_2d().direct_space_state
	var query = PhysicsShapeQueryParameters2D.new()

	query.shape = shape_node.shape
	query.transform = shape_node.global_transform
	query.collide_with_bodies = true
	query.collide_with_areas = true

	var result = space_state.intersect_shape(query)

	if result.size() > 0:
		can_place = false

	var sprite := ghost.get_node_or_null("anim") as CanvasItem
	if sprite:
		sprite.modulate = Color(0, 1, 0, 0.6) if can_place else Color(1, 0, 0, 0.6)

#--------------------------------
#Input
#--------------------------------
func _input(event: InputEvent) -> void:
	if ghost == null:
		return
	if _mouse_over_ui():
		return
	if event.is_action_pressed("confirm_building") and can_place:
		_place_building()
	if event.is_action_pressed("cancel_building"):
		_cancel_building()

#--------------------------------
#place building
#--------------------------------
func _place_building() -> void:
	if current_id != "" and moving_building == null:
		if not _substract_resources(current_id):
			return

	if moving_building:
		moving_building.global_position = ghost.global_position
		moving_building.visible = true
		moving_building.set_physics_process(true)

		var tween = moving_building.create_tween()
		tween.tween_property(
			moving_building,
			"ghost_position",
			ghost.global_position,
			0.25
		).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

		moving_building = null
	else:
		if not building_scenes.has(current_id):
			return

		var building = building_scenes[current_id].instantiate()
		building.global_position = ghost.global_position

		var parent := building_parent
		if parent == null:
			parent = get_tree().current_scene as Node2D

		if parent == null:
			push_error("building_parent is not assigned")
			return

		parent.add_child(building)

		if building.has_method("play_building_animation"):
			building.play_building_animation()

	if ghost:
		ghost.queue_free()
	ghost = null
	current_id = ""

#--------------------------------
#cancle building
#--------------------------------
func _cancel_building() -> void:
	if moving_building:
		moving_building.global_position = moving_original_position
		moving_building.set_physics_process(true)
		moving_building.visible = true
		moving_building = null
	if ghost:
		ghost.queue_free()
	ghost = null
	current_id = ""

#--------------------------------
#ground tile detection for placement
#--------------------------------
func get_ground_under_mouse() -> TileMapLayer:
	var mouse_pos: Vector2 = get_global_mouse_position()

	for node in get_tree().get_nodes_in_group(ground_tilemap_group):
		if not node is TileMapLayer:
			continue

		var local_pos: Vector2 = node.to_local(mouse_pos)
		var cell: Vector2i = node.local_to_map(local_pos)

		if node.get_cell_source_id(cell) != -1:
			return node
	return null

#--------------------------------
#moves
#--------------------------------
func request_move(building: StaticBody2D) -> void:
	building.set_physics_process(false)
	building.visible = false

	moving_building = building
	moving_original_position = building.global_position

	var id := _get_building_id_from_scene(building)
	if id == "":
		building.visible = true
		building.set_physics_process(true)
		moving_building = null
		return

	current_id = id
	if not ghost_scene.has(id):
		return

	ghost = ghost_scene[id].instantiate()
	ghost.visible = true
	ghost.global_position = building.global_position
	ghost_parents.add_child(ghost)

func _get_building_id_from_scene(building: Node) -> String:
	for id in building_scenes.keys():
		if building.scene_file_path == building_scenes[id].resource_path:
			return id
	return ""

func get_or_create_ghost_parent() -> Node2D:
	var current_scene = get_tree().current_scene
	if not current_scene:
		push_error("no scenes")
		var new_node = Node2D.new()
		new_node.name = "Ghosts"
		get_tree().root.call_deferred("add_child", new_node)
		return new_node
	var node = current_scene.get_node_or_null("Ghosts")
	if node:
		return node as Node2D
	var new_node = Node2D.new()
	new_node.name = "Ghosts"
	current_scene.call_deferred("add_child", new_node)
	return new_node

func _has_enoungh_resourches(id: String) -> bool:
	var cost = cost_map.get(id)
	if not cost:
		return false

	return Global.gold >= cost["gold"] and Global.wood >= cost["wood"]

func _substract_resources(id: String) -> bool:
	var cost = cost_map.get(id)
	if not cost:
		return false

	if Global.gold < cost["gold"] or Global.wood < cost["wood"]:
		return false
	Global.consume_gold(cost["gold"])
	Global.consume_wood(cost["wood"])
	return true

func _feedback_insufficient_ghosts() -> void:
	if not ghost:
		return

	var sprite := ghost.get_node_or_null("anim") as CanvasItem
	if sprite == null:
		return

	var original_position = ghost.position
	var original_modulate = sprite.modulate

	sprite.modulate = Color(1, 0, 0, 0.8)

	var tween = ghost.create_tween()
	tween.tween_property(ghost, "position:x", original_position.x + 10, 0.05)
	tween.tween_property(ghost, "position:x", original_position.x - 10, 0.1)
	tween.tween_property(ghost, "position:x", original_position.x, 0.05)
	tween.tween_property(sprite, "modulate", original_modulate, 0.15)
	await tween.finished

func _mouse_over_ui() -> bool:
	return get_viewport().gui_get_hovered_control() != null
