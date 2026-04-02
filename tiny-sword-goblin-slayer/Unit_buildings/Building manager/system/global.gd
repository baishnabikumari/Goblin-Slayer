extends Node

#----------------------------
#LEVEL VARIABLE
#----------------------------
var level=1
var current_level_id: int=2
var Goblin_house =0

#----------------------------
#Player state/resources
#----------------------------
var pawn_tool:String="hand"
var choosed_colour: String="black"
const SAVE_COLOR: String="user://levels.save"

#variables
var gold:int=5
var wood:int=5
var meat:int=10

var max_gold:int=1000
var max_wood:int=1000
var max_meat:int=1000

const LEVEL_SCENE:={
	1: "res://Levels/level.tscn",
	2: "res://Levels/level.tscn",
}

#----------------------------
#global goblin wave system
#----------------------------


#will code it later



#----------------------------
#Ready func
#----------------------------
func _ready() -> void:
	Global.Goblin_house=0
	load_colour()
	clamp_resources()
	#game_over=false

#----------------------------
#Save/load colour
#----------------------------
func save_colour():
	#var file:FileAccess=FileAccess.open(SAVE_COLOR,FileAccess.WRITE)
	#file.store_string(choosed_colour)
	#file.close()
	pass
func load_colour():
	#var file:FileAccess=FileAccess.open(SAVE_COLOR,FileAccess.READ)
	#choosed_colour=file.get_as_text()
	#file.close()
	pass


#----------------------------
#resource clamping
#----------------------------
func clamp_resources():
	gold=clamp(gold,0,max_gold)
	wood=clamp(wood,0,max_wood)
	wood=clamp(meat,0,max_meat)
	
func add_gold(amount:int):
	gold=min(gold+amount,max_gold)
func add_wood(amount:int):
	wood=min(wood+amount,max_wood)
func add_meat(amount:int):
	meat=min(meat+amount,max_meat)

func consume_gold(amount:int):
	if gold<amount:
		return false
	gold-=amount
	return true
func consume_wood(amount:int):
	if wood<amount:
		return false
	wood-=amount
	return true
func consume_meat(amount:int):
	if meat<amount:
		return false
	meat-=amount
	return true
	
func can_spawn_spawn()->bool:
	return meat>0


#----------------------------
#process
#----------------------------
@warning_ignore("unused_parameter")
func _process(delta: float) -> void:
	pass

#----------------------------
#wave control
#----------------------------
