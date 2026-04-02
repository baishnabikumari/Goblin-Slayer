extends Button

@export var building_id:String
@export var building_manager:Node

func _pressed() -> void:
	if building_manager:
		building_manager.select_building(building_id)
