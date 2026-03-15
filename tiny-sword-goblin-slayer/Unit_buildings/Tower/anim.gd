extends AnimatedSprite2D

var image_black=preload("res://Tiny Swords (Free Pack)/Buildings/Black Buildings/Tower.png")
var image_blue=preload("res://Tiny Swords (Free Pack)/Buildings/Blue Buildings/Tower.png")
var image_purple=preload("res://Tiny Swords (Free Pack)/Buildings/Purple Buildings/Tower.png")
var image_red=preload("res://Tiny Swords (Free Pack)/Buildings/Red Buildings/Tower.png")
var image_yellow=preload("res://Tiny Swords (Free Pack)/Buildings/Yellow Buildings/Tower.png")

func _ready() -> void:
	Global.load_colour()
	if Global.choosed_colour=="black":
		sprite_frames.clear("idle")
		sprite_frames.add_frame("idle",image_black)
	if Global.choosed_colour=="blue":
		sprite_frames.clear("idle")
		sprite_frames.add_frame("idle",image_blue)
	if Global.choosed_colour=="red":
		sprite_frames.clear("idle")
		sprite_frames.add_frame("idle",image_red)
	if Global.choosed_colour=="purple":
		sprite_frames.clear("idle")
		sprite_frames.add_frame("idle",image_purple)
	if Global.choosed_colour=="yellow":
		sprite_frames.clear("idle")
		sprite_frames.add_frame("idle",image_yellow)
