extends CharacterBody2D

#-----------------------
#Nodes
#-----------------------
@onready var anim: AnimatedSprite2D = $anim
@onready var shape: CollisionShape2D = $shape
@onready var detector_zone: Area2D = $"detector zone"
@onready var hitbox: Area2D = $hitbox
@onready var shieldbar: ProgressBar = $shieldbar
@onready var progress_bar: ProgressBar = $ProgressBar
@onready var button: Button = $Button
@onready var select_indicator: Label = $"select indicator"
@onready var marker_2d: Marker2D = $Marker2D
@onready var camera_2d: Camera2D = $Camera2D
@onready var navigation_agent_2d: NavigationAgent2D = $NavigationAgent2D
@onready var predict_cast: ShapeCast2D = $PredictCast

#-----------------------
#Soundfx
#-----------------------
@onready var click_audio: AudioStreamPlayer2D = $soundfx/click_audio
@onready var death_audio: AudioStreamPlayer2D = $soundfx/death_audio
@onready var hit_audio: AudioStreamPlayer2D = $soundfx/hit_audio
@onready var sword_audio: AudioStreamPlayer2D = $soundfx/sword_audio
@onready var shield_audio: AudioStreamPlayer2D = $soundfx/shield_audio

var attack_effect_active := false #
