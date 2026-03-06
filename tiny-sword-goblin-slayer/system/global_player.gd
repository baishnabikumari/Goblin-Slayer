extends Node

var pawn:Array=[]
var active_player:Node=null
var active_player_position: Vector2

var castle_position=Vector2.ZERO
var camera_shake_func: Callable=Callable()

#----------------------------
#Register the pawn
#----------------------------
func register_pawn(pawn:Node)->void:
	if pawn in pawns:
		return
	pawns.append(pawn)
	
	if pawn.has_signal("died"):
		pawn.died.connect(_on_pawn_died)
		
	_update_pawn_state()
	if pawn.size()==1:
		set_active_pawn(pawn)


#----------------------------
#signal callback
#----------------------------
func _on_pawn_died(pawn:Node)->void:
	unregister_pawn(pawn)

func unregister_pawn(pawn:Node)->void:
	if pawn not in pawns:
		return
	var was_active:=pawn==active_player
	pawns.erase(pawn) #here-----
	
	_update_pawn_state()
	if was_active:
		activate_next_pawn()
		
#----------------------------
#active pawn
#----------------------------
func set_active_pawn(pawn:Node)->void:
	if active_player and active_player!=pawn:
		if active_player.has_method("deactivate"):
			active_player.deactivate()
		active_player.deactivate()
	active_player=pawn
	if active_player and active_player.has_method("activate_from_global"):
		active_player.activate_from_global()

func activate_next_pawn()->void:
	if pawns.is_empty():
		active_player=null
		return
	set_active_pawn(pawns[0])

func _update_pawn_state()->void:
	pawn_all_dead=pawns.is_empty()
	
func get_pawn_count()->int:
	return pawns.size()
