extends Node

var  assigned_targets:=[]

func is_taken(goblin:Node2D)->bool:
	return assigned_targets.has(goblin)

func assign(goblin:Node2D, archer:Node2D)->void:
	assigned_targets[goblin]=archer

func release(goblin:Node2D)->void:
	if assigned_targets.has(goblin):
		assigned_targets.erase(goblin)

#func get_archer(goblin:Node2D)->Node2D:
	#return assigned_targets.get(goblin,null)
