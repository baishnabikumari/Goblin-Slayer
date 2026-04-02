extends Node2D

@onready var ghost_parents:Node2D=get_or_create_ghost_parent()

@export var ground_tilemap_group:="ground_tilemap"
@export var building_parent:Node2D

@export var ghost_scene:={
	"house1":preload("res://Unit_buildings/Building manager/Ghosts/house1_ghost.tscn"),
	"house2":preload("res://Unit_buildings/Building manager/Ghosts/house2_ghost.tscn"),
	"house3":preload("res://Unit_buildings/Building manager/Ghosts/house3_ghost.tscn"),
	"archery_tower":preload("res://Unit_buildings/Building manager/Ghosts/archery_ghost.tscn"),
	"barracks":preload("res://Unit_buildings/Building manager/Ghosts/barrack_ghost.tscn"),
	"tower":preload("res://Unit_buildings/Building manager/Ghosts/tower_ghost.tscn"),
	"monastery":preload("res://Unit_buildings/Building manager/Ghosts/monastery_ghost.tscn")
}

#building scene
@export var building_scenes:={
	"house1":preload("res://Unit_buildings/house1/house1.tscn"),
	"house2":preload("res://Unit_buildings/house2/house2.gd"),
	"house3":preload("res://Unit_buildings/house3/house3.tscn"),
	"archery_tower":preload("res://Unit_buildings/archery/archery.tscn"),
	"barracks":preload("res://Unit_buildings/barrack/barrack.tscn"),
	"tower":preload("res://Unit_buildings/Tower/tower.tscn"),
	"monastery":preload("res://Unit_buildings/monastery/monastery.tscn")
}

var ghost:Area2D=null
var current_id:=""
var can_place:=false

#cost mapping
var cost_map:={
	"house1":
}
